extends "res://scripts/enemies/enemy_base.gd"
class_name VampireEnemy
## 普通吸血鬼 — 中速近战，中等血量

func _ready() -> void:
	max_hp = 33.0  # 增加10% (原30.0)
	move_speed = 90.0
	contact_damage = 10.0
	xp_value = 5
	super._ready()

func _load_sprite_texture() -> void:
	if sprite:
		var texture := TextureManager.instance.get_enemy_texture("vampire", "idle")
		if texture:
			sprite.texture = texture
			sprite.modulate = Color.WHITE
			_adjust_sprite_scale()
		else:
			_ensure_default_texture()
			_adjust_sprite_scale()

func _get_enemy_type() -> String:
	return "vampire"
