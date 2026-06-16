extends "res://scripts/enemies/enemy_base.gd"
class_name VampireEnemy
## 普通吸血鬼 — 中速近战，中等血量
## 特性：玩家贴身时会后撤步，保持中距离缠斗

@export var backstep_distance: float = 80.0   # 触发后撤的距离
@export var backstep_speed: float = 180.0     # 后撤速度
@export var backstep_cooldown: float = 2.0    # 后撤冷却

var backstep_timer: float = 0.0
var is_backstepping: bool = false

func _ready() -> void:
	max_hp = 33.0  # 增加10% (原30.0)
	move_speed = 90.0
	contact_damage = 10.0
	xp_value = 5
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

	backstep_timer -= delta
	var distance_to_player := global_position.distance_to(player.global_position)

	# 进入后撤：玩家太近且冷却完毕
	if distance_to_player < backstep_distance and backstep_timer <= 0 and not is_backstepping:
		_start_backstep()

	if is_backstepping:
		# 后撤期间继续远离玩家
		var direction := (global_position - player.global_position).normalized()
		velocity = direction * backstep_speed
		move_and_slide()
		# 后撤结束由 _finish_backstep 处理
	else:
		_move_towards_player(delta)

func _start_backstep() -> void:
	is_backstepping = true
	backstep_timer = backstep_cooldown
	# 短暂后撤 0.25 秒
	await get_tree().create_timer(0.25).timeout
	is_backstepping = false
	# 后撤结束音效/粒子（可选）
	if sprite:
		var tween := create_tween()
		tween.tween_property(sprite, "modulate", Color(1.3, 1.3, 1.3, 1.0), 0.05)
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)

func _load_sprite_texture() -> void:
	if sprite:
		var texture := TextureManager.instance.get_enemy_texture("vampire", "idle")
		if texture:
			sprite.texture = texture
			sprite.modulate = Color.WHITE
			_adjust_sprite_scale()
		else:
			_ensure_default_texture()
			_adjust_sprite_scale()

func _get_enemy_type() -> String:
	return "vampire"
