extends CharacterBody2D
class_name EnemyBase
## 敌人基类脚本
## 所有敌人类型继承此类


# === 属性 ===
@export var max_hp: float = 39.0
@export var move_speed: float = 80.0
@export var contact_damage: float = 10.0
@export var xp_value: int = 5

var current_hp: float
var player: CharacterBody2D = null
var is_dead: bool = false

# 冻结状态
var is_frozen: bool = false
var freeze_timer: float = 0.0

# 受击硬直与击退
var hit_stun_timer: float = 0.0
var knockback_velocity: Vector2 = Vector2.ZERO
const KNOCKBACK_FRICTION: float = 800.0

# === 信号 ===
signal enemy_died(enemy: Node2D)

# === 节点引用 ===
@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

# 缓存 VFXManager，避免每次受击/死亡都查询
var _vfx_manager: Node = null

func _ready() -> void:
	current_hp = max_hp
	add_to_group("enemies")
	_vfx_manager = get_node_or_null("/root/VFXManager")
	# 加载精灵图纹理
	_load_sprite_texture()
	# 查找玩家节点
	_find_player()

func _get_vfx() -> Node:
	if _vfx_manager == null or not is_instance_valid(_vfx_manager):
		_vfx_manager = get_node_or_null("/root/VFXManager")
	return _vfx_manager

func _load_sprite_texture() -> void:
	## 子类覆写此方法加载特定纹理
	_ensure_default_texture()
	# 根据碰撞体大小调整精灵缩放
	_adjust_sprite_scale()

func _adjust_sprite_scale() -> void:
	## 根据目标大小调整精灵缩放，所有敌人统一大小
	if sprite and sprite.texture:
		var texture_size: Vector2 = sprite.texture.get_size()
		if texture_size.x > 0 and texture_size.y > 0:
			# 目标精灵大小
			var target_size: float = 56.0
			# 计算缩放比例
			var scale_factor: float = target_size / max(texture_size.x, texture_size.y)
			sprite.scale = Vector2(scale_factor, scale_factor)

func _ensure_default_texture() -> void:
	if sprite and sprite.texture == null:
		var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		sprite.texture = ImageTexture.create_from_image(img)

func _find_player() -> void:
	# 延迟一帧确保场景树已就绪
	await get_tree().process_frame
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0] as CharacterBody2D

func _physics_process(delta: float) -> void:
	if is_dead or player == null or not is_instance_valid(player):
		return

	# 处理冻结状态
	if is_frozen:
		freeze_timer -= delta
		if freeze_timer <= 0:
			_unfreeze()
		return  # 冻结时不能移动

	# 处理受击硬直与击退
	if hit_stun_timer > 0:
		hit_stun_timer -= delta
		velocity = knockback_velocity
		move_and_slide()
		# 击退速度衰减
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, KNOCKBACK_FRICTION * delta)
		if hit_stun_timer <= 0 and knockback_velocity.length() < 10.0:
			knockback_velocity = Vector2.ZERO
		return

	_move_towards_player(delta)

func _move_towards_player(_delta: float) -> void:
	## 子类可以覆写此方法实现不同移动方式
	var direction := (player.global_position - global_position).normalized()
	velocity = direction * move_speed
	move_and_slide()
	# 翻转 Sprite 朝向玩家
	if direction.x < 0:
		sprite.flip_h = true
	else:
		sprite.flip_h = false

func take_damage(amount: float) -> void:
	if is_dead:
		return
	current_hp -= amount
	_flash_hit()
	if current_hp <= 0:
		_die()

func take_damage_with_knockback(amount: float, knockback_dir: Vector2, knockback_force: float = 120.0, stun_duration: float = 0.08) -> void:
	if is_dead:
		return
	current_hp -= amount
	hit_stun_timer = maxf(hit_stun_timer, stun_duration)
	knockback_velocity += knockback_dir.normalized() * knockback_force
	_flash_hit()
	if current_hp <= 0:
		_die()

func _flash_hit() -> void:
	## 受击闪白效果
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color(10.0, 10.0, 10.0, 1.0), 0.03)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.07)
	# 受击粒子
	var vfx := _get_vfx()
	if vfx:
		vfx.spawn_hit_particles(global_position, sprite.modulate, 4)
	# 播放受击音效
	var audio_lib := AudioLib
	AudioManager.play_sfx(audio_lib.get_sound("hit_enemy"))

func _die() -> void:
	if is_dead:
		return
	is_dead = true
	enemy_died.emit(self)
	# 记录击杀成就
	_record_kill_for_achievement()
	# 死亡粒子
	var vfx := _get_vfx()
	if vfx:
		vfx.spawn_death_particles(global_position, sprite.modulate, 10)
	# 播放死亡音效
	var audio_lib := AudioLib
	AudioManager.play_sfx(audio_lib.get_sound("enemy_death"))
	# 掉落经验宝石
	_drop_xp_gem()
	# 禁用碰撞
	collision_shape.set_deferred("disabled", true)
	set_physics_process(false)
	# 死亡动画
	var tween := create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.2)
	tween.tween_property(sprite, "scale", Vector2.ZERO, 0.2)
	tween.tween_callback(queue_free)

func _record_kill_for_achievement() -> void:
	## 子类覆写此方法返回敌人类型
	var enemy_type := _get_enemy_type()
	var ach_mgr := get_node_or_null("/root/AchievementManager")
	if ach_mgr:
		ach_mgr.record_kill(enemy_type)

func _get_enemy_type() -> String:
	## 子类覆写此方法返回敌人类型
	return "unknown"

func freeze(duration: float) -> void:
	## 冻结敌人
	if is_frozen:
		# 如果已经在冻结中，延长冻结时间
		freeze_timer = maxf(freeze_timer, duration)
		return
	
	is_frozen = true
	freeze_timer = duration
	
	# 视觉冻结效果
	if sprite:
		sprite.modulate = Color(0.5, 0.8, 1.0, 1.0)  # 蓝色调
		# 冻结粒子效果
		var vfx := get_node_or_null("/root/VFXManager")
		if vfx:
			vfx.spawn_freeze_particles(global_position)

func _unfreeze() -> void:
	## 解除冻结
	is_frozen = false
	freeze_timer = 0.0
	if sprite:
		sprite.modulate = Color.WHITE

func _drop_xp_gem() -> void:
	var gem_scene := preload("res://scenes/player/xp_gem.tscn")
	var gem := gem_scene.instantiate() as Area2D
	gem.global_position = global_position
	gem.xp_value = xp_value
	get_tree().current_scene.call_deferred("add_child", gem)

func _on_contact_area_body_entered(body: Node2D) -> void:
	## 碰到玩家时造成伤害
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(contact_damage, global_position)
