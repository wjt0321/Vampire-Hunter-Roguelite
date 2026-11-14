extends "res://scripts/enemies/enemy_base.gd"
## 月翼兽。沿弧线换位，然后朝锁定的落点俯冲，并留下一道短风刃。

var _phase: String = "arc"
var _timer: float = 0.8
var _dive_to: Vector2 = Vector2.ZERO

func _ready() -> void:
	base_hp = 14.0
	move_speed = 120.0
	base_contact_damage = 9.0
	xp_value = 8
	super._ready()

func _load_sprite_texture() -> void:
	use_dedicated_sprite("moon_wing", "idle", Color(0.62, 0.58, 0.95))

func _get_enemy_type() -> String:
	return "moon_wing"

func _move_towards_player(delta: float) -> void:
	if player == null:
		return
	_timer -= delta
	if _phase == "arc":
		var around := (player.global_position - global_position).normalized().orthogonal()
		velocity = around * move_speed
		move_and_slide()
		if _timer <= 0.0:
			_phase = "dive"
			_timer = 0.35
			_dive_to = player.global_position
			# 收翼俯冲：播俯冲动作条
			play_action_strip("moon_wing", "dive", "once")
	else:
		velocity = (_dive_to - global_position).normalized() * 260.0
		move_and_slide()
		if global_position.distance_to(_dive_to) < 16.0 or _timer <= 0.0:
			_leave_blade()
			_phase = "arc"
			_timer = 1.1

func _leave_blade() -> void:
	var blade := Node2D.new()
	blade.set_script(preload("res://scripts/enemies/wind_blade.gd"))
	blade.global_position = global_position
	var parent := get_parent()
	if parent:
		parent.add_child(blade)
