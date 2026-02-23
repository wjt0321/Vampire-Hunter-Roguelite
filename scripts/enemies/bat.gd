extends "res://scripts/enemies/enemy_base.gd"
class_name BatEnemy
## 蝙蝠 — 飞行型，快速，低血量，蛇形移动

var sine_offset: float = 0.0
var sine_amplitude: float = 50.0
var sine_frequency: float = 4.0

func _ready() -> void:
	max_hp = 16.5  # 增加10% (原15.0)
	move_speed = 140.0
	contact_damage = 5.0
	xp_value = 3
	# 随机偏移，避免所有蝙蝠同步
	sine_offset = randf() * TAU
	super._ready()

func _move_towards_player(_delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	var direction := (player.global_position - global_position).normalized()
	# 垂直于移动方向的蛇形偏移
	var perpendicular := Vector2(-direction.y, direction.x)
	sine_offset += _delta * sine_frequency
	var offset := perpendicular * sin(sine_offset) * sine_amplitude * _delta
	velocity = direction * move_speed + offset * move_speed
	move_and_slide()
	if direction.x < 0:
		sprite.flip_h = true
	else:
		sprite.flip_h = false

func _get_enemy_type() -> String:
	return "bat"
