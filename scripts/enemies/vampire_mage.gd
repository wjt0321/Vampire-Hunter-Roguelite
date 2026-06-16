extends "res://scripts/enemies/enemy_base.gd"
class_name VampireMageEnemy
## 吸血鬼法师 — 远程法术攻击，会瞬移

@export var teleport_interval: float = 4.0  # 瞬移间隔
@export var teleport_range: float = 200.0  # 瞬移距离
@export var cast_range: float = 250.0  # 施法距离
@export var cast_cooldown: float = 2.0  # 施法冷却

var teleport_timer: float = 0.0
var cast_timer: float = 0.0
var is_teleporting: bool = false

# 法术投射物场景
var spell_scene: PackedScene = preload("res://scenes/enemies/enemy_projectile.tscn")

func _ready() -> void:
	max_hp = 45.0
	move_speed = 50.0
	contact_damage = 5.0
	xp_value = 25
	super._ready()

func _physics_process(delta: float) -> void:
	if is_dead or player == null or not is_instance_valid(player):
		return
	
	# 处理冻结状态
	if is_frozen:
		freeze_timer -= delta
		if freeze_timer <= 0:
			_unfreeze()
		return
	
	# 处理瞬移
	teleport_timer -= delta
	if teleport_timer <= 0 and not is_teleporting:
		_teleport()
		teleport_timer = teleport_interval
	
	# 处理施法
	cast_timer -= delta
	var distance_to_player := global_position.distance_to(player.global_position)
	if cast_timer <= 0 and distance_to_player <= cast_range and not is_teleporting:
		_cast_spell()
		cast_timer = cast_cooldown
	
	# 移动逻辑：保持距离
	_move_maintain_distance(delta, distance_to_player)

func _move_maintain_distance(_delta: float, distance: float) -> void:
	if is_teleporting:
		return
	
	var direction := (player.global_position - global_position).normalized()
	
	if distance < 100.0:
		# 太近，后退
		velocity = -direction * move_speed * 1.5
	elif distance > cast_range:
		# 太远，靠近
		velocity = direction * move_speed
	else:
		# 距离合适，停止移动
		velocity = Vector2.ZERO
	
	move_and_slide()
	
	# 翻转
	if direction.x < 0:
		sprite.flip_h = true
	else:
		sprite.flip_h = false

func _teleport() -> void:
	## 瞬移到玩家周围的随机位置
	if player == null or not is_instance_valid(player):
		return
	
	is_teleporting = true
	
	# 瞬移特效
	_teleport_effect()
	
	# 计算目标位置（玩家周围随机位置）
	var angle := randf() * TAU
	var target_pos := player.global_position + Vector2(cos(angle), sin(angle)) * teleport_range
	
	# 确保在房间范围内
	var room := get_parent()
	if room and room.has_method("get_center"):
		var room_center: Vector2 = room.get_center()
		var room_width: float = room.get("room_width")
		var room_height: float = room.get("room_height")
		var room_size := Vector2(room_width, room_height)
		target_pos.x = clampf(target_pos.x, room_center.x - room_size.x / 2 + 50, room_center.x + room_size.x / 2 - 50)
		target_pos.y = clampf(target_pos.y, room_center.y - room_size.y / 2 + 50, room_center.y + room_size.y / 2 - 50)
	
	# 延迟瞬移
	await get_tree().create_timer(0.3).timeout
	
	if is_dead:
		return
	
	global_position = target_pos
	
	# 瞬移到达特效
	_teleport_arrive_effect()
	
	is_teleporting = false

func _teleport_effect() -> void:
	## 瞬移离开特效
	var vfx := get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.spawn_death_particles(global_position, Color(0.5, 0.0, 0.8, 0.8), 8)
	
	# 播放瞬移音效
	var audio_lib := AudioLib
	AudioManager.play_sfx(audio_lib.get_sound("teleport"))

func _teleport_arrive_effect() -> void:
	## 瞬移到达特效
	var vfx := get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.spawn_death_particles(global_position, Color(0.8, 0.0, 0.5, 0.8), 8)
	
	# 播放瞬移到达音效
	var audio_lib := AudioLib
	AudioManager.play_sfx(audio_lib.get_sound("teleport"))
	
	# 淡入
	if sprite:
		var tween := create_tween()
		tween.tween_property(sprite, "modulate:a", 1.0, 0.2)

func _cast_spell() -> void:
	## 施放法术投射物
	if player == null or not is_instance_valid(player):
		return
	
	print("🔮 吸血鬼法师施放法术!")
	
	# 创建法术投射物
	var spell := spell_scene.instantiate()
	spell.global_position = global_position
	
	# 计算方向
	var direction := (player.global_position - global_position).normalized()
	spell.direction = direction
	spell.speed = 200.0
	spell.damage = 15.0
	spell.lifetime = 3.0
	
	# 设置颜色（紫色魔法）
	spell.modulate = Color(0.8, 0.2, 0.9, 1.0)
	
	get_tree().current_scene.add_child(spell)
	
	# 播放音效
	var audio_lib := AudioLib
	AudioManager.play_sfx(audio_lib.get_sound("shoot_magic"))

func _get_enemy_type() -> String:
	return "vampire_mage"

func _load_sprite_texture() -> void:
	if sprite:
		var texture := TextureManager.instance.get_enemy_texture("vampire_mage", "cast")
		if texture:
			sprite.texture = texture
			sprite.modulate = Color.WHITE
			_adjust_sprite_scale()
		else:
			_ensure_default_texture()
			_adjust_sprite_scale()
