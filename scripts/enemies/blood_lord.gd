extends "res://scripts/enemies/boss_stage.gd"
## 血铠领主。正面盾挡，剑击连段，冲锋撞墙后眩晕。
## 盾破了才进入猛攻，不靠血量百分比变身。
## 外观先用旧 Boss 待机图染成铁灰，正式动作表以后替换。

enum Phase { GUARD, BROKEN }
enum Motion { IDLE, WINDUP, CHARGE, STUN, SWING }

const SHIELD_HP := 90.0
const STUN_TIME := 1.35
const CHARGE_SPEED := 460.0
const CHARGE_TIME := 0.42
const WINDUP_TIME := 0.45

var phase: Phase = Phase.GUARD
var motion: Motion = Motion.IDLE
var shield_hp: float = SHIELD_HP
var _hit_dir: Vector2 = Vector2.ZERO
var _motion_timer: float = 0.8
var _charge_dir: Vector2 = Vector2.RIGHT
var _swings_left: int = 0

func _ready() -> void:
	boss_title = "血铠领主"
	asset_id = "blood_lord"
	boss_tier = 1
	move_speed = 70.0
	base_contact_damage = 16.0
	sprite_tint = Color(0.68, 0.74, 0.86)
	_boot_boss()

func _get_enemy_type() -> String:
	return "blood_lord"

func facing() -> Vector2:
	if player != null and is_instance_valid(player):
		var toward := player.global_position - global_position
		if toward.length_squared() > 1.0:
			return toward.normalized()
	return _charge_dir

func is_frontal_hit(incoming: Vector2) -> bool:
	if phase == Phase.BROKEN or incoming.length_squared() < 0.001:
		return false
	return facing().dot(incoming.normalized()) < -0.35

func take_damage_with_knockback(amount: float, knockback_dir: Vector2, _knockback_force: float = 120.0, _stun_duration: float = 0.08) -> void:
	_hit_dir = knockback_dir
	take_damage(amount)
	_hit_dir = Vector2.ZERO

func _direct_damage(amount: float) -> float:
	amount = super._direct_damage(amount)
	if phase == Phase.BROKEN:
		return amount
	var frontal := is_frontal_hit(_hit_dir)
	if frontal:
		shield_hp -= amount * 0.45
		amount *= 0.3
	else:
		shield_hp -= amount
	if shield_hp <= 0.0:
		_break_shield()
	return amount

func _break_shield() -> void:
	if phase == Phase.BROKEN:
		return
	phase = Phase.BROKEN
	shield_hp = 0.0
	boss_phase_changed.emit(1)

func notify_wall_contact() -> void:
	if motion != Motion.CHARGE:
		return
	motion = Motion.STUN
	_motion_timer = STUN_TIME
	velocity = Vector2.ZERO

func _physics_process(delta: float) -> void:
	if is_dead or intro_invulnerable:
		return
	if player == null or not is_instance_valid(player):
		return
	_motion_timer -= delta
	match motion:
		Motion.STUN:
			velocity = Vector2.ZERO
			if _motion_timer <= 0.0:
				motion = Motion.IDLE
				_motion_timer = 0.45
		Motion.WINDUP:
			velocity = Vector2.ZERO
			if _motion_timer <= 0.0:
				motion = Motion.CHARGE
				_motion_timer = CHARGE_TIME
				_charge_dir = facing()
		Motion.CHARGE:
			velocity = _charge_dir * CHARGE_SPEED
			move_and_slide()
			if get_slide_collision_count() > 0:
				notify_wall_contact()
			elif _motion_timer <= 0.0:
				motion = Motion.IDLE
				_motion_timer = 0.55
		Motion.SWING:
			velocity = Vector2.ZERO
			if _motion_timer <= 0.0:
				_strike()
				_swings_left -= 1
				if _swings_left > 0:
					_motion_timer = 0.28
				else:
					motion = Motion.IDLE
					_motion_timer = 0.7 if phase == Phase.GUARD else 0.35
		_:
			var to_player := player.global_position - global_position
			velocity = to_player.normalized() * move_speed * (1.25 if phase == Phase.BROKEN else 0.75)
			move_and_slide()
			if _motion_timer > 0.0:
				return
			if to_player.length() > 160.0 and phase == Phase.GUARD:
				motion = Motion.WINDUP
				_motion_timer = WINDUP_TIME
				_charge_dir = to_player.normalized()
			else:
				motion = Motion.SWING
				_swings_left = 3 if phase == Phase.BROKEN else 2
				_motion_timer = 0.22

func _strike() -> void:
	var forward := facing()
	for enemy in get_tree().get_nodes_in_group("player"):
		if not (enemy is Node2D):
			continue
		var offset: Vector2 = (enemy as Node2D).global_position - global_position
		if offset.length() > 96.0:
			continue
		if absf(forward.angle_to(offset)) > 0.7:
			continue
		if enemy.has_method("take_damage"):
			enemy.take_damage(14.0 if phase == Phase.GUARD else 18.0)
