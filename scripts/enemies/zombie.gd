extends "res://scripts/enemies/enemy_base.gd"
class_name ZombieEnemy
## 僵尸 — 慢速，高血量，高伤害

func _ready() -> void:
	max_hp = 120.0
	move_speed = 35.0
	contact_damage = 25.0
	xp_value = 10
	super._ready()
