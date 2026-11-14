extends "res://scripts/enemies/enemy_base.gd"
## 潜伏者。钻地时打不中，落地前会在落点亮一下。

var blocks_random_affix: bool = true
var buried: bool = true
var _emerge_at: Vector2 = Vector2.ZERO
var _timer: float = 0.2

func _ready() -> void:
	base_hp = 18.0
	move_speed = 90.0
	base_contact_damage = 14.0
	xp_value = 8
	super._ready()

func _load_sprite_texture() -> void:
	use_dedicated_sprite("burrower", "idle", Color(0.45, 0.32, 0.22))

func _get_enemy_type() -> String:
	return "burrower"

func take_damage(amount: float) -> void:
	if buried:
		return
	super.take_damage(amount)

func _move_towards_player(delta: float) -> void:
	if player == null:
		return
	_timer -= delta
	if buried:
		if sprite:
			sprite.modulate.a = 0.35
		_emerge_at = player.global_position
		global_position = global_position.move_toward(_emerge_at, move_speed * delta)
		if global_position.distance_to(_emerge_at) < 24.0 and _timer <= 0.0:
			buried = false
			_timer = 0.45
			if sprite:
				sprite.modulate = placeholder_tint
	elif _timer > 0.0:
		velocity = Vector2.ZERO
	else:
		super._move_towards_player(delta)
		if _timer < -2.2:
			buried = true
			_timer = 0.4
			# 再次钻回地下：播下潜动作条
			play_action_strip("burrower", "burrow", "once")
