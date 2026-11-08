extends RefCounted
class_name ItemCatalog
## 物品目录：升级三选一与局内商店共用同一份数据
##
## 为什么要单拎出来：升级 UI（`upgrade_ui.gd`）和商店（`room_shop.gd`）都要
## "列出所有武器/被动 + 按 id 造出实例"。早期这段数据只写在升级 UI 里，
## 加商店时如果复制一份，以后加武器就得改两处、还容易忘。所以收在这里。

const WEAPONS: Array = [
	{"id": "shotgun", "name": "散弹枪", "desc": "近距离扇形射击", "icon": "💥", "type": "weapon", "price": 30},
	{"id": "magic_book", "name": "魔法书", "desc": "自动追踪敌人", "icon": "📖", "type": "weapon", "price": 32},
	{"id": "throwing_knife", "name": "飞刀", "desc": "穿透多个敌人", "icon": "🔪", "type": "weapon", "price": 28},
	{"id": "poison_cloud", "name": "毒雾瓶", "desc": "持续伤害区域", "icon": "☠️", "type": "weapon", "price": 30},
	{"id": "lightning_chain", "name": "闪电法杖", "desc": "闪电链跳跃", "icon": "⚡", "type": "weapon", "price": 34},
	{"id": "crossbow", "name": "十字弩", "desc": "高伤害穿透弩箭", "icon": "🏹", "type": "weapon", "price": 32},
	{"id": "holy_wand", "name": "圣光魔杖", "desc": "自动追踪的圣光弹", "icon": "✨", "type": "weapon", "price": 30},
	{"id": "kunai", "name": "苦无", "desc": "极高速连投暗器", "icon": "🗡️", "type": "weapon", "price": 28},
	{"id": "flame_thrower", "name": "火焰喷射器", "desc": "近距离持续灼烧", "icon": "🔥", "type": "weapon", "price": 26},
	{"id": "blood_burst", "name": "血爆", "desc": "在敌群中炸开血海", "icon": "🩸", "type": "weapon", "price": 34},
]

const PASSIVES: Array = [
	{"id": "magnet", "name": "经验磁铁", "desc": "经验吸附范围 +30%", "icon": "🧲", "type": "passive", "price": 20},
	{"id": "shield", "name": "能量护盾", "desc": "定期生成护盾", "icon": "🛡️", "type": "passive", "price": 24},
	{"id": "regeneration", "name": "生命恢复", "desc": "每5秒恢复生命", "icon": "💚", "type": "passive", "price": 22},
	{"id": "greed_ring", "name": "贪婪戒指", "desc": "经验获取 +20%", "icon": "💍", "type": "passive", "price": 20},
	{"id": "berserker_blood", "name": "狂战士之血", "desc": "低血量时伤害 +50%", "icon": "🩸", "type": "passive", "price": 26},
	{"id": "frozen_heart", "name": "冰冻之心", "desc": "10%几率冻结敌人", "icon": "❄️", "type": "passive", "price": 24},
	{"id": "lightning_shield", "name": "闪电护符", "desc": "受击时闪电反击", "icon": "⚡", "type": "passive", "price": 22},
	{"id": "shadow_cloak", "name": "影子披风", "desc": "闪避几率 +5%", "icon": "🌑", "type": "passive", "price": 24},
	{"id": "vampiric_fang", "name": "吸血獠牙", "desc": "击杀时概率回血", "icon": "🦷", "type": "passive", "price": 26},
	{"id": "swift_boots", "name": "疾风靴", "desc": "移动速度 +10%", "icon": "👟", "type": "passive", "price": 20},
	{"id": "lucky_clover", "name": "幸运四叶草", "desc": "暴击几率 +8%", "icon": "🍀", "type": "passive", "price": 24},
	# 17.13 状态修饰器：三个词条对"任意武器"生效，不需要逐把接线
	{"id": "blood_edge", "name": "血刃", "desc": "命中 25% 几率使敌人流血", "icon": "刃", "type": "passive", "price": 26},
	{"id": "frost_bind", "name": "霜缚", "desc": "命中 30% 几率使敌人减速", "icon": "霜", "type": "passive", "price": 24},
	{"id": "blood_drain", "name": "汲取", "desc": "造成伤害的 2% 转为生命", "icon": "汲", "type": "passive", "price": 28},
]

const STATS: Array = [
	{"id": "damage", "name": "攻击强化", "desc": "攻击力 +20%", "icon": "⚔️", "type": "stat"},
	{"id": "speed", "name": "疾风步", "desc": "移动速度 +15%", "icon": "💨", "type": "stat"},
	{"id": "shoot_speed", "name": "连射精通", "desc": "射击速度 +20%", "icon": "🔫", "type": "stat"},
	{"id": "max_hp", "name": "生命之泉", "desc": "最大生命 +20", "icon": "❤️", "type": "stat"},
	{"id": "armor", "name": "铁壁防御", "desc": "护甲 +5", "icon": "🛡️", "type": "stat"},
	{"id": "pickup_range", "name": "磁力吸引", "desc": "拾取范围 +30", "icon": "🧲", "type": "stat"},
]

## 商店里的消耗品（不占装备槽）
const CONSUMABLES: Array = [
	{"id": "heal", "name": "血瓶", "desc": "恢复 40% 最大生命", "icon": "❤️", "type": "consumable", "price": 10},
	{"id": "max_hp", "name": "血之容器", "desc": "最大生命 +15", "icon": "🩸", "type": "consumable", "price": 16},
	{"id": "damage", "name": "猎手磨刀石", "desc": "攻击力 +12%（本局）", "icon": "⚔️", "type": "consumable", "price": 22},
	{"id": "speed", "name": "疾风药剂", "desc": "移动速度 +10%（本局）", "icon": "💨", "type": "consumable", "price": 14},
]

static func find_weapon(id: String) -> Dictionary:
	for w in WEAPONS:
		if w["id"] == id:
			return w
	return {}

static func find_passive(id: String) -> Dictionary:
	for p in PASSIVES:
		if p["id"] == id:
			return p
	return {}

static func find_consumable(id: String) -> Dictionary:
	for c in CONSUMABLES:
		if c["id"] == id:
			return c
	return {}

static func get_display_name(id: String) -> String:
	## 按 id 取中文名，供 HUD"还差什么被动"这类提示使用
	var passive := find_passive(id)
	if not passive.is_empty():
		return String(passive["name"])
	var weapon := find_weapon(id)
	if not weapon.is_empty():
		return String(weapon["name"])
	return id

static func create_weapon(id: String):
	var W = preload("res://scripts/weapons/weapon_manager.gd")
	match id:
		"shotgun":
			return W.create_shotgun()
		"magic_book":
			return W.create_magic_book()
		"throwing_knife":
			return W.create_throwing_knife()
		"poison_cloud":
			return W.create_poison_cloud()
		"lightning_chain":
			return W.create_lightning_chain()
		"crossbow":
			return W.create_crossbow()
		"holy_wand":
			return W.create_holy_wand()
		"kunai":
			return W.create_kunai()
		"flame_thrower":
			return W.create_flame_thrower()
		"blood_burst":
			return W.create_blood_burst()
	return null

static func create_passive(id: String):
	var P = preload("res://scripts/player/passive_item_data.gd")
	match id:
		"magnet":
			return P.create_magnet()
		"shield":
			return P.create_shield()
		"regeneration":
			return P.create_regeneration()
		"greed_ring":
			return P.create_greed_ring()
		"berserker_blood":
			return P.create_berserker_blood()
		"frozen_heart":
			return P.create_frozen_heart()
		"lightning_shield":
			return P.create_lightning_shield()
		"shadow_cloak":
			return P.create_shadow_cloak()
		"vampiric_fang":
			return P.create_vampiric_fang()
		"swift_boots":
			return P.create_swift_boots()
		"lucky_clover":
			return P.create_lucky_clover()
		"blood_edge":
			return P.create_blood_edge()
		"frost_bind":
			return P.create_frost_bind()
		"blood_drain":
			return P.create_blood_drain()
	return null
