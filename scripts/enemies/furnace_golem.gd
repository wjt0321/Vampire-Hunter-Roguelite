extends "res://scripts/enemies/enemy_base.gd"
## 炉心傀儡。外甲在的时候又慢又硬，甲破了就冲上来。

var armor_hp: float = 36.0

func _ready() -> void:
	base_hp = 30.0
	move_speed = 32.0
	base_contact_damage = 16.0
	xp_value = 10
	super._ready()

func _load_sprite_texture() -> void:
	use_placeholder_sprite("furnace_golem", "idle", Color(0.55, 0.42, 0.32))

func _get_enemy_type() -> String:
	return "furnace_golem"

func _direct_damage(amount: float) -> float:
	amount = super._direct_damage(amount)
	if armor_hp <= 0.0:
		return amount
	var soaked := minf(armor_hp, amount)
	armor_hp -= soaked
	amount = maxf(amount - soaked * 0.7, amount * 0.25)
	if armor_hp <= 0.0:
		move_speed = 150.0
		armor_hp = 0.0
	return amount
