extends RefCounted
class_name ItemCatalog
## 物品目录：升级三选一与局内商店共用同一份数据
##
## 为什么要单拎出来：升级 UI（`upgrade_ui.gd`）和商店（`room_shop.gd`）都要
## "列出所有武器/被动 + 按 id 造出实例"。早期这段数据只写在升级 UI 里，
## 加商店时如果复制一份，以后加武器就得改两处、还容易忘。所以收在这里。

const WEAPONS: Array = [
	{"id": "pistol", "name": "手枪", "desc": "可靠的基础武器", "type": "weapon", "price": 28, "upgrade_only": true},
	{"id": "shotgun", "name": "散弹枪", "desc": "近距离扇形射击", "type": "weapon", "price": 30},
	{"id": "magic_book", "name": "魔法书", "desc": "自动追踪敌人", "type": "weapon", "price": 32},
	{"id": "throwing_knife", "name": "飞刀", "desc": "穿透多个敌人", "type": "weapon", "price": 28},
	{"id": "poison_cloud", "name": "毒雾瓶", "desc": "持续伤害区域", "type": "weapon", "price": 30},
	{"id": "lightning_chain", "name": "闪电法杖", "desc": "闪电链跳跃", "type": "weapon", "price": 34},
	{"id": "crossbow", "name": "十字弩", "desc": "高伤害穿透弩箭", "type": "weapon", "price": 32},
	{"id": "holy_wand", "name": "圣光魔杖", "desc": "自动追踪的圣光弹", "type": "weapon", "price": 30},
	{"id": "kunai", "name": "苦无", "desc": "极高速连投暗器", "type": "weapon", "price": 28},
	{"id": "flame_thrower", "name": "火焰喷射器", "desc": "近距离持续灼烧", "type": "weapon", "price": 26},
	{"id": "blood_burst", "name": "血爆", "desc": "自动在最近的敌群中引爆血海（无敌人不发射）", "type": "weapon", "price": 34},
]

const PASSIVES: Array = [
	{"id": "magnet", "name": "经验磁铁", "desc": "经验吸附范围 +30%", "type": "passive", "price": 20},
	{"id": "shield", "name": "能量护盾", "desc": "定期生成护盾", "type": "passive", "price": 24},
	{"id": "regeneration", "name": "生命恢复", "desc": "每5秒恢复生命", "type": "passive", "price": 22},
	{"id": "greed_ring", "name": "贪婪戒指", "desc": "经验获取 +20%", "type": "passive", "price": 20},
	{"id": "berserker_blood", "name": "狂战士之血", "desc": "低血量时伤害 +50%", "type": "passive", "price": 26},
	{"id": "frozen_heart", "name": "冰冻之心", "desc": "10%几率冻结敌人", "type": "passive", "price": 24},
	{"id": "lightning_shield", "name": "闪电护符", "desc": "受击时闪电反击", "type": "passive", "price": 22},
	{"id": "shadow_cloak", "name": "影子披风", "desc": "闪避几率 +5%", "type": "passive", "price": 24},
	{"id": "vampiric_fang", "name": "吸血獠牙", "desc": "击杀时概率回血", "type": "passive", "price": 26},
	{"id": "swift_boots", "name": "疾风靴", "desc": "移动速度 +10%", "type": "passive", "price": 20},
	{"id": "lucky_clover", "name": "幸运四叶草", "desc": "暴击几率 +8%", "type": "passive", "price": 24},
	# 17.13 状态修饰器：三个词条对"任意武器"生效，不需要逐把接线
	{"id": "blood_edge", "name": "血刃", "desc": "命中 25% 几率使敌人流血", "type": "passive", "price": 26},
	{"id": "frost_bind", "name": "霜缚", "desc": "命中 30% 几率使敌人减速", "type": "passive", "price": 24},
	{"id": "blood_drain", "name": "汲取", "desc": "造成伤害的 2% 转为生命", "type": "passive", "price": 28},
]

const STATS: Array = [
	{"id": "damage", "name": "攻击强化", "desc": "攻击力 +20%", "type": "stat"},
	{"id": "speed", "name": "疾风步", "desc": "移动速度 +15%", "type": "stat"},
	{"id": "shoot_speed", "name": "连射精通", "desc": "射击速度 +20%", "type": "stat"},
	{"id": "max_hp", "name": "生命之泉", "desc": "最大生命 +20", "type": "stat"},
	{"id": "armor", "name": "铁壁防御", "desc": "护甲 +5", "type": "stat"},
	{"id": "pickup_range", "name": "磁力吸引", "desc": "拾取范围 +30", "type": "stat"},
]

## 商店里的消耗品（不占装备槽）
const CONSUMABLES: Array = [
	{"id": "heal", "name": "血瓶", "desc": "恢复 40% 最大生命", "type": "consumable", "price": 10},
	{"id": "max_hp", "name": "血之容器", "desc": "最大生命 +15", "type": "consumable", "price": 16},
	{"id": "damage", "name": "猎手磨刀石", "desc": "攻击力 +12%（本局）", "type": "consumable", "price": 22},
	{"id": "speed", "name": "疾风药剂", "desc": "移动速度 +10%（本局）", "type": "consumable", "price": 14},
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

## 物品 → 图标贴图统一映射（单一数据源）。
## 2026-11-09 试玩反馈"升级/商店里只有字没有图"：图标 key 散落在
## upgrade_ui._get_option_icon 里且只覆盖了一半物品，商店/HUD 根本没接。
## 现在所有 UI（升级三选一 / 房间商店 / 元进度商店 / HUD 列表）都走这里，
## 拿不到贴图时调用方回退显示 catalog 里的单字。
static func get_icon_texture(item_id: String, item_type: String = "") -> Texture2D:
	var key := ""
	match item_type:
		"weapon":
			match item_id:
				"pistol": key = "pistol"
				"shotgun": key = "shotgun"
				"magic_book": key = "magic_book"
				"throwing_knife": key = "knife"
				"poison_cloud": key = "poison"
				"lightning_chain": key = "lightning"
				"crossbow": key = "crossbow"
				"holy_wand": key = "holy_wand"
				"kunai": key = "kunai"
				"flame_thrower": key = "flame_thrower"
				"blood_burst": key = "blood_burst"
		"passive":
			match item_id:
				"magnet": key = "magnet"
				"shield": key = "shield"
				"regeneration": key = "regen"
				"greed_ring": key = "greed"
				"berserker_blood": key = "berserker"
				"frozen_heart": key = "frozen"
				"lightning_shield": key = "lightning_shield"
				"shadow_cloak": key = "shadow"
				"vampiric_fang": key = "vampiric"
				"swift_boots": key = "swift_boots"
				"lucky_clover": key = "clover"
				"blood_edge": key = "blood_edge"
				"frost_bind": key = "frost_bind"
				"blood_drain": key = "blood_drain"
		_:
			# stat / consumable / basic 共用一套语义图标
			match item_id:
				"damage", "damage_boost": key = "mightstone"
				"speed": key = "swift_boots"
				"shoot_speed": key = "kunai"
				"max_hp": key = "blood_crystal_icon"
				"heal": key = "heal_potion_icon"
				"armor": key = "shield"
				"pickup_range": key = "magnet"
				# 元进度商店的"经验加成"用的是 magnet 这个语义 id，
				# 但它走的是无类型的 _ 分支（不带 "passive" 前缀），这里必须单独给一条，
				# 否则该行拿不到贴图（2026-11-09 第五轮验证脚本抓到的漏网之鱼）。
				"magnet": key = "magnet"
				"gold": key = "blood_crystal_icon"
	if key.is_empty():
		return null
	# TextureManager 是普通 autoload（无 class_name），static 函数里按节点路径取
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var inst: Node = tree.root.get_node_or_null("TextureManager")
	if inst == null or not inst.has_method("get_weapon_icon"):
		return null
	return inst.get_weapon_icon(key)

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
	var W = load("res://scripts/weapons/weapon_manager.gd")
	match id:
		"pistol":
			return W._create_pistol()
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
