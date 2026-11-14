extends "res://scripts/enemies/enemy_base.gd"
## 血猎犬。先绕到侧翼，再沿锁定的直线扑过去。横向躲开就扑空。

var _phase: String = "circle"
var _timer: float = 1.1
var _lunge_dir: Vector2 = Vector2.RIGHT

func _ready() -> void:
	base_hp = 16.0
	move_speed = 110.0
	base_contact_damage = 12.0
	xp_value = 7
	super._ready()

func _load_sprite_texture() -> void:
	use_dedicated_sprite("blood_hound", "idle", Color(0.72, 0.22, 0.22))

func _get_enemy_type() -> String:
	return "blood_hound"

func _move_towards_player(delta: float) -> void:
	if player == null:
		return
	_timer -= delta
	var to_player := player.global_position - global_position
	if _phase == "circle":
		velocity = to_player.normalized().orthogonal() * move_speed
		move_and_slide()
		if _timer <= 0.0:
			_phase = "windup"
			_timer = 0.35
			_lunge_dir = to_player.normalized()
	elif _phase == "windup":
		velocity = Vector2.ZERO
		if _timer <= 0.0:
			_phase = "lunge"
			_timer = 0.38
	else:
		velocity = _lunge_dir * 280.0
		move_and_slide()
		if _timer <= 0.0:
			_phase = "circle"
			_timer = 1.2
