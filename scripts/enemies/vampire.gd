extends "res://scripts/enemies/enemy_base.gd"
class_name VampireEnemy
## 普通吸血鬼 — 中速近战，中等血量

func _ready() -> void:
	max_hp = 30.0
	move_speed = 90.0
	contact_damage = 10.0
	xp_value = 5
	super._ready()
