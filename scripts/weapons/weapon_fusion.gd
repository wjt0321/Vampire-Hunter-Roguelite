extends RefCounted
class_name WeaponFusion
## 双武器融合。一局一次。和宝箱进化互斥。
## 主武器留下并改行为，副武器离槽。不给数十倍伤害。

const RECIPES := {
	"thunder_bolt": {
		"name": "雷矢",
		"primary": "crossbow",
		"secondary": "lightning_chain",
		"damage_mult": 1.7,
		"card": "弩箭伤害 ×1.7。命中后向房间内 200 像素再跳 1 次",
		"kind": "thunder",
	},
	"miasma_shot": {
		"name": "瘴弹",
		"primary": "shotgun",
		"secondary": "poison_cloud",
		"damage_mult": 1.6,
		"card": "弹丸伤害 ×1.6。消失时留下 0.6 倍毒雾，持续 2 秒",
		"kind": "miasma",
	},
	"returning_blade": {
		"name": "回旋刃",
		"primary": "throwing_knife",
		"secondary": "kunai",
		"damage_mult": 1.6,
		"interval": 0.25,
		"card": "伤害 ×1.6。保留满级穿透和 1 次弹射，间隔 0.25",
		"kind": "returning",
	},
	"twin_chant": {
		"name": "双咏",
		"primary": "holy_wand",
		"secondary": "magic_book",
		"damage_mult": 1.6,
		"card": "本体伤害 ×1.6。飞到射程末端分成 2 枚，每枚一半伤害",
		"kind": "split",
	},
	"burning_blood": {
		"name": "燃血",
		"primary": "flame_thrower",
		"secondary": "blood_burst",
		"damage_mult": 1.0,
		"card": "火舌保持满级伤害。每 4 次命中，在命中点爆开半伤血爆",
		"kind": "burning",
	},
}

## 瘴弹留下的毒雾用毒雾满级伤害，不跟散弹的伤害走。
const POISON_MAX_DAMAGE := 4.0
const MIASMA_CLOUD_SCALE := 0.6
const MIASMA_CLOUD_DURATION := 2.0
## 雷矢那一下跳：闪电满级伤害的 0.7，半径锁在房间内 200。
const LIGHTNING_MAX_DAMAGE := 12.0
const THUNDER_JUMP_RANGE := 200.0
const THUNDER_JUMP_DAMAGE_MULT := 0.7
## 燃血：血爆满级伤害的一半，范围 0.5。
const BLOOD_MAX_DAMAGE := 14.4
const BURNING_SCALE := 0.5
const BURNING_DAMAGE_MULT := 0.5
const BURNING_HITS := 4

static func thunder_jump_damage() -> float:
	return LIGHTNING_MAX_DAMAGE * THUNDER_JUMP_DAMAGE_MULT

static func burning_damage() -> float:
	return BLOOD_MAX_DAMAGE * BURNING_DAMAGE_MULT

static func offer(weapons: Array, evolved_ids: Array, already_fused: bool) -> Dictionary:
	if already_fused:
		return {}
	var owned := {}
	for weapon in weapons:
		if weapon == null:
			continue
		if bool(weapon.get("fused")):
			return {}
		owned[String(weapon.weapon_id)] = weapon
	for recipe_id in RECIPES.keys():
		var recipe: Dictionary = RECIPES[recipe_id]
		var primary_id := String(recipe["primary"])
		var secondary_id := String(recipe["secondary"])
		if not owned.has(primary_id) or not owned.has(secondary_id):
			continue
		if primary_id in evolved_ids or secondary_id in evolved_ids:
			continue
		var primary = owned[primary_id]
		var secondary = owned[secondary_id]
		if int(primary.current_level) < int(primary.max_level):
			continue
		if int(secondary.current_level) < int(secondary.max_level):
			continue
		if bool(primary.get("fused")) or bool(secondary.get("fused")):
			continue
		return {
			"id": recipe_id,
			"name": recipe["name"],
			"desc": recipe["card"],
			"type": "fusion",
			"primary": primary_id,
			"secondary": secondary_id,
		}
	return {}

static func recipe(recipe_id: String) -> Dictionary:
	return RECIPES.get(recipe_id, {})
