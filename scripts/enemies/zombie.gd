extends "res://scripts/enemies/enemy_base.gd"
class_name ZombieEnemy
## 僵尸 — 慢速，高血量，高伤害

func _ready() -> void:
	max_hp = 132.0  # 增加10% (原120.0)
	move_speed = 35.0
	contact_damage = 25.0
	xp_value = 10
	super._ready()

func _load_sprite_texture() -> void:
	if sprite:
		var texture := TextureManager.instance.get_enemy_texture("zombie", "walk")
		if texture:
			sprite.texture = texture
			sprite.modulate = Color.WHITE
			_adjust_sprite_scale()
		else:
			_ensure_default_texture()
			_adjust_sprite_scale()

func _get_enemy_type() -> String:
	return "zombie"
