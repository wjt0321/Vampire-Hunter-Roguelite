extends CharacterBody2D
class_name EnemyBase
## 敌人基类脚本
## 所有敌人类型继承此类

# === 属性 ===
@export var max_hp: float = 30.0
@export var move_speed: float = 80.0
@export var contact_damage: float = 10.0
@export var xp_value: int = 5

var current_hp: float
var player: CharacterBody2D = null
var is_dead: bool = false

# === 信号 ===
signal enemy_died(enemy: Node2D)

# === 节点引用 ===
@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	current_hp = max_hp
	add_to_group("enemies")
	# 自动创建纹理（如果 sprite 没有 texture）
	_ensure_sprite_texture()
	# 查找玩家节点
	_find_player()

func _ensure_sprite_texture() -> void:
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

func _flash_hit() -> void:
	## 受击闪白效果
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color(10.0, 10.0, 10.0, 1.0), 0.03)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.07)
	# 受击粒子
	var vfx := get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.spawn_hit_particles(global_position, sprite.modulate, 4)
	# 播放受击音效
	var audio_lib := AudioLibrary.new()
	AudioManager.play_sfx(audio_lib.get_sound("hit_enemy"))

func _die() -> void:
	if is_dead:
		return
	is_dead = true
	enemy_died.emit(self)
	# 死亡粒子
	var vfx := get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.spawn_death_particles(global_position, sprite.modulate, 10)
	# 播放死亡音效
	var audio_lib := AudioLibrary.new()
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

func _drop_xp_gem() -> void:
	var gem_scene := preload("res://scenes/player/xp_gem.tscn")
	var gem := gem_scene.instantiate() as Area2D
	gem.global_position = global_position
	gem.xp_value = xp_value
	get_tree().current_scene.call_deferred("add_child", gem)

func _on_contact_area_body_entered(body: Node2D) -> void:
	## 碰到玩家时造成伤害
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(contact_damage)
