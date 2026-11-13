extends "res://scripts/enemies/enemy_base.gd"
## 织血母皇的幼虫。绕母皇巡逻，玩家靠近就预警后扑咬，不替母皇挡远程弹道。

enum Motion { ORBIT, WINDUP, POUNCE }

const ORBIT_RADIUS := 90.0
const ALERT_RADIUS := 160.0
const WINDUP_TIME := 0.35
const POUNCE_SPEED := 260.0
const POUNCE_TIME := 0.3

var queen: Node = null
var motion: Motion = Motion.ORBIT
var _motion_timer: float = 0.0
var _pounce_dir: Vector2 = Vector2.RIGHT
var _orbit_angle: float = 0.0

func _ready() -> void:
	base_hp = 30.0
	base_contact_damage = 8.0
	move_speed = 90.0
	xp_value = 5
	silver_value = 1
	_orbit_angle = randf() * TAU
	super._ready()

func _get_enemy_type() -> String:
	return "blood_larva"

func _load_sprite_texture() -> void:
	# 专属幼虫表还没做；借蝙蝠飞帧染绛红，登记在 asset_slots 后可 drop-in 替换。
	use_placeholder_sprite("bat", "fly", Color(0.78, 0.22, 0.42))
	_adjust_sprite_scale()

func _move_towards_player(delta: float) -> void:
	if queen == null or not is_instance_valid(queen):
		return
	var to_player := player.global_position - global_position if player != null and is_instance_valid(player) else Vector2.ZERO
	match motion:
		Motion.ORBIT:
			_orbit_angle += delta * move_speed / ORBIT_RADIUS
			var target: Vector2 = queen.global_position + Vector2(cos(_orbit_angle), sin(_orbit_angle)) * ORBIT_RADIUS
			var to_target := target - global_position
			velocity = to_target.normalized() * move_speed if to_target.length() > 8.0 else Vector2.ZERO
			if to_player.length() <= ALERT_RADIUS:
				motion = Motion.WINDUP
				_motion_timer = WINDUP_TIME
				velocity = Vector2.ZERO
		Motion.WINDUP:
			velocity = Vector2.ZERO
			_motion_timer -= delta
			if _motion_timer <= 0.0:
				motion = Motion.POUNCE
				_motion_timer = POUNCE_TIME
				_pounce_dir = to_player.normalized() if to_player.length_squared() > 1.0 else Vector2.RIGHT
		Motion.POUNCE:
			velocity = _pounce_dir * POUNCE_SPEED
			_motion_timer -= delta
			if _motion_timer <= 0.0:
				motion = Motion.ORBIT
	move_and_slide()
	if velocity.length_squared() > 1.0 and sprite != null:
		sprite.flip_h = velocity.x < 0.0
