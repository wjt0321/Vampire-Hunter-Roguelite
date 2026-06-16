extends "res://scripts/enemies/enemy_base.gd"
class_name ZombieEnemy
## 僵尸 — 慢速，高血量，高伤害
## 特性：偶尔会向前扑击（短距离冲刺）

@export var lunge_range: float = 120.0       # 扑击触发距离
@export var lunge_speed: float = 160.0       # 扑击速度
@export var lunge_duration: float = 0.4      # 扑击持续时间
@export var lunge_cooldown: float = 4.0      # 扑击冷却

var lunge_timer: float = 0.0
var is_lunging: bool = false
var lunge_direction: Vector2 = Vector2.ZERO

func _ready() -> void:
	max_hp = 132.0  # 增加10% (原120.0)
	move_speed = 35.0
	contact_damage = 25.0
	xp_value = 10
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

	lunge_timer -= delta

	if is_lunging:
		# 扑击中：沿固定方向冲刺
		velocity = lunge_direction * lunge_speed
		move_and_slide()
		return

	var distance_to_player := global_position.distance_to(player.global_position)
	# 进入扑击范围且冷却完毕
	if distance_to_player <= lunge_range and lunge_timer <= 0:
		_start_lunge()
		return

	_move_towards_player(delta)

func _start_lunge() -> void:
	is_lunging = true
	lunge_timer = lunge_cooldown
	lunge_direction = (player.global_position - global_position).normalized()

	# 扑击预警：变红
	if sprite:
		var tween := create_tween()
		tween.tween_property(sprite, "modulate", Color(1.5, 0.4, 0.4, 1.0), 0.15)
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.15)

	# 延迟后结束扑击
	await get_tree().create_timer(lunge_duration).timeout
	is_lunging = false

func _load_sprite_texture() -> void:
	if sprite:
		var texture := TextureManager.instance.get_enemy_texture("zombie", "walk")
		if texture:
			sprite.texture = texture
			sprite.modulate = Color.WHITE
			_adjust_sprite_scale()
		else:
			_ensure_default_texture()
			_adjust_sprite_scale()

func _get_enemy_type() -> String:
	return "zombie"
