extends CharacterBody2D
## 玩家角色脚本
## 处理移动、生命值、经验升级等核心逻辑
## 射击由 WeaponManager 独立处理

# === 移动属性 ===
@export var move_speed: float = 200.0

# === 生命属性 ===
@export var max_hp: float = 100.0
var current_hp: float = max_hp
var is_invincible: bool = false
@export var invincible_duration: float = 0.5

# === 经验与升级 ===
var current_xp: int = 0
var current_level: int = 1
var xp_to_next_level: int = 20

# === 战斗属性（可被升级修改） ===
var damage_multiplier: float = 1.0
var speed_multiplier: float = 1.0
var shoot_speed_multiplier: float = 1.0
var pickup_range_bonus: float = 0.0
var armor: float = 0.0

# === 信号 ===
signal hp_changed(current: float, maximum: float)
signal xp_changed(current_xp: int, xp_needed: int, level: int)
signal level_up(new_level: int)
signal player_died

# === 节点引用 ===
@onready var sprite: Sprite2D = $Sprite2D
@onready var invincible_timer: Timer = $InvincibleTimer
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	add_to_group("player")
	current_hp = max_hp
	# 自动创建纹理（如果 sprite 没有 texture）
	if sprite and sprite.texture == null:
		var img := Image.create(16, 24, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		sprite.texture = ImageTexture.create_from_image(img)
	invincible_timer.wait_time = invincible_duration
	invincible_timer.one_shot = true
	invincible_timer.timeout.connect(_on_invincible_timer_timeout)
	hp_changed.emit(current_hp, max_hp)
	xp_changed.emit(current_xp, xp_to_next_level, current_level)

func _physics_process(_delta: float) -> void:
	_handle_movement()
	_handle_rotation()

func _handle_movement() -> void:
	var input_dir := Vector2.ZERO
	input_dir.x = Input.get_axis("move_left", "move_right")
	input_dir.y = Input.get_axis("move_up", "move_down")
	input_dir = input_dir.normalized()
	velocity = input_dir * move_speed * speed_multiplier
	move_and_slide()

func _handle_rotation() -> void:
	var mouse_pos := get_global_mouse_position()
	var direction := mouse_pos - global_position
	if direction.x < 0:
		sprite.flip_h = true
	else:
		sprite.flip_h = false

# === 经验值相关 ===
func gain_xp(amount: int) -> void:
	current_xp += amount
	while current_xp >= xp_to_next_level:
		current_xp -= xp_to_next_level
		_level_up()
	xp_changed.emit(current_xp, xp_to_next_level, current_level)

func _level_up() -> void:
	current_level += 1
	xp_to_next_level = 20 + (current_level - 1) * 10
	level_up.emit(current_level)
	# 升级光效
	var vfx := get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.spawn_levelup_particles(global_position)
	# 播放升级音效
	var audio_lib := AudioLibrary.new()
	AudioManager.play_sfx(audio_lib.get_sound("level_up"))

# === 升级效果应用 ===
func apply_upgrade(upgrade_type: String) -> void:
	match upgrade_type:
		"damage":
			damage_multiplier += 0.2
		"speed":
			speed_multiplier += 0.15
		"shoot_speed":
			shoot_speed_multiplier += 0.2
		"max_hp":
			max_hp += 20.0
			current_hp += 20.0
			hp_changed.emit(current_hp, max_hp)
		"armor":
			armor += 5.0
		"pickup_range":
			pickup_range_bonus += 30.0

# === 生命值相关 ===
func take_damage(amount: float) -> void:
	if is_invincible:
		return
	var actual_damage := maxf(amount - armor, 1.0)
	current_hp = clampf(current_hp - actual_damage, 0.0, max_hp)
	hp_changed.emit(current_hp, max_hp)
	_start_invincibility()
	_flash_damage()
	# 受击屏幕震动
	var vfx := get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.screen_shake(3.0, 0.1)
	if current_hp <= 0:
		_die()

func heal(amount: float) -> void:
	current_hp = clampf(current_hp + amount, 0.0, max_hp)
	hp_changed.emit(current_hp, max_hp)

func _start_invincibility() -> void:
	is_invincible = true
	invincible_timer.start()

func _on_invincible_timer_timeout() -> void:
	is_invincible = false
	sprite.modulate = Color.WHITE

func _flash_damage() -> void:
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color(1.0, 0.3, 0.3, 1.0), 0.05)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.05)
	tween.tween_property(sprite, "modulate", Color(1.0, 0.3, 0.3, 0.7), 0.05)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.05)

func _die() -> void:
	player_died.emit()
	set_physics_process(false)
	collision_shape.set_deferred("disabled", true)
	var tween := create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)
