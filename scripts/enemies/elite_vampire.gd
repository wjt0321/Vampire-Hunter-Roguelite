extends "res://scripts/enemies/enemy_base.gd"
class_name EliteVampire
## 精英吸血鬼 —— 高体质敌人，必带一个精英词缀
##
## 词缀已统一到 `EliteAffix` / `EliteAffixController`：
## 早期这里有一套私有 enum（速度/护甲/分裂）和自绘的 modulate 循环，
## 与通用系统并存会变成"两套精英规则"，而且那个永不停歇的 modulate 循环
## 会和受击闪白抢同一个属性（玩家盾那次踩的就是同一个坑）。

var is_elite: bool = true

func _ready() -> void:
	# 词缀必须在 super._ready() 之前定好：加成与表现形式都依赖它
	if not suppress_affix and elite_affix.is_empty():
		elite_affix = EliteAffix.roll()

	base_hp = 35.0
	move_speed = 80.0
	base_contact_damage = 15.0
	xp_value = 25
	silver_value = 5

	# 体型走倍率，交给归一化统一相乘（直接写 sprite.scale 会被归一化覆盖，曾导致 333px 巨图）
	sprite_scale_mult *= 1.12

	super._ready()

	# 一点点冷色提亮，和普通吸血鬼区分开；用 self_modulate 而不是 modulate，
	# 这样受击闪白（改 modulate）不会和它打架
	if sprite:
		sprite.self_modulate = Color(1.0, 0.88, 0.94, 1.0)

func get_affix_name() -> String:
	return EliteAffix.display_name(elite_affix)

func _get_enemy_type() -> String:
	return "elite"

func _load_sprite_texture() -> void:
	if sprite:
		var texture := TextureManager.instance.get_enemy_texture("elite_vampire", "idle")
		if texture:
			sprite.texture = texture
			sprite.modulate = Color.WHITE
			_adjust_sprite_scale()
		else:
			_ensure_default_texture()
			_adjust_sprite_scale()
