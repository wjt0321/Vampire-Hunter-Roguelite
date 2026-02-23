extends "res://scripts/enemies/enemy_base.gd"
class_name WerewolfEnemy
## 狼人 — 冲刺型，高血量，间歇性加速

var charge_timer: float = 0.0
var is_charging: bool = false
@export var charge_speed: float = 250.0
@export var charge_interval: float = 3.0
@export var charge_duration: float = 0.5
var charge_elapsed: float = 0.0

func _ready() -> void:
	max_hp = 80.0
	move_speed = 60.0
	contact_damage = 20.0
	xp_value = 15
	super._ready()

func _physics_process(delta: float) -> void:
	if is_dead or player == null or not is_instance_valid(player):
		return
	# 冲刺计时
	charge_timer += delta
	if is_charging:
		charge_elapsed += delta
		if charge_elapsed >= charge_duration:
			is_charging = false
			charge_elapsed = 0.0
			sprite.modulate = Color.WHITE
	elif charge_timer >= charge_interval:
		charge_timer = 0.0
		is_charging = true
		sprite.modulate = Color(1.5, 0.5, 0.5, 1.0)  # 冲刺变红
	_move_towards_player(delta)

func _move_towards_player(_delta: float) -> void:
	var direction := (player.global_position - global_position).normalized()
	var current_speed := charge_speed if is_charging else move_speed
	velocity = direction * current_speed
	move_and_slide()
	if direction.x < 0:
		sprite.flip_h = true
	else:
		sprite.flip_h = false
