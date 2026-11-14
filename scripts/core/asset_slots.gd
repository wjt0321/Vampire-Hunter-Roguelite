extends RefCounted
## 正式资产的预留位置。
## 把同名 PNG 放到下面的路径后，游戏会自动改用它，不用再改脚本。
## 文件还不存在时，调用方继续用现有的染色图或色块。

const ENEMY_ROOT := "res://assets/sprites/enemies"
const BOSS_ROOT := "res://assets/sprites/boss"
const WEAPON_ICON_ROOT := "res://assets/weapons/icons"
const PASSIVE_ICON_ROOT := "res://assets/ui/passives"

## 敌人：每个状态一张横向精灵表，单格 56×56。
const ENEMIES := {
	"shield_guard": {"name": "盾卫", "states": ["idle", "guard", "death", "hurt"], "blurb": "正面护盾减伤，绕到侧面或背后再打"},
	"blood_hound": {"name": "血猎犬", "states": ["idle", "pounce", "death", "hurt"], "blurb": "先绕行，再沿直线扑击，横向躲开"},
	"blood_priest": {"name": "血祭司", "states": ["idle", "cast", "death", "hurt"], "blurb": "给视线内的伤员治疗，墙能挡住"},
	"web_weaver": {"name": "蛛网编织者", "states": ["idle", "cast", "death", "hurt"], "blurb": "在地上留可打掉的减速网"},
	"burrower": {"name": "地行尸", "states": ["idle", "burrow", "death", "hurt"], "blurb": "钻地时打不中，落地前会标出落点"},
	"gem_leech": {"name": "噬宝虫", "states": ["idle", "steal", "death", "hurt"], "blurb": "吞经验后逃跑，打死能把经验吐出来"},
	"coffin_guard": {"name": "棺卫", "states": ["idle", "revive", "death", "hurt"], "blurb": "倒下后留下棺材，不打就会爬起来一次"},
	"lantern_wraith": {"name": "提灯幽魂", "states": ["idle", "beam", "death", "hurt"], "blurb": "直线光束持续伤血，离开或用墙挡住"},
	"alchemist_pitcher": {"name": "炼金投手", "states": ["idle", "throw", "death", "hurt"], "blurb": "药瓶落地后敌我都会受伤"},
	"furnace_golem": {"name": "熔炉石像", "states": ["idle", "charge", "death", "hurt"], "blurb": "外甲在时又慢又硬，甲碎了就冲上来"},
	"resonance_mage": {"name": "共鸣术士", "states": ["idle", "cast", "death", "hurt"], "blurb": "把同伴连起来分摊伤害，先杀术士"},
	"moon_wing": {"name": "月翼", "states": ["idle", "dive", "death", "hurt"], "blurb": "弧线换位后俯冲，并留下短风刃"},
	"bat": {"name": "血蝠", "states": ["fly", "death"], "blurb": "飞得快，优先清掉以免被缠住"},
	"blood_larva": {"name": "血铠幼虫", "states": ["idle", "pounce", "death", "hurt"], "blurb": "绕母皇巡逻，靠近就扑咬"},
	"vampire": {"name": "吸血鬼", "states": ["idle", "run", "death"], "blurb": "近身追击，别让它贴住"},
	"zombie": {"name": "腐尸", "states": ["walk", "death"], "blurb": "慢，血厚，用来挡路"},
	"skeleton_archer": {"name": "骷髅射手", "states": ["idle", "shoot", "death"], "blurb": "远处点射，用墙或近身打断"},
	"werewolf": {"name": "狼人", "states": ["idle", "charge", "death"], "blurb": "冲得快，横向躲开再打"},
	"exploder": {"name": "自爆鬼", "states": ["walk", "explode", "death"], "blurb": "靠近会炸，自己也会伤到同伴"},
	"summoner": {"name": "召唤者", "states": ["idle", "cast", "death"], "blurb": "先杀召唤者，再清它叫出来的东西"},
	"vampire_mage": {"name": "血法师", "states": ["idle", "cast", "teleport", "death"], "blurb": "远程施法，不要站在弹道上"},
	"gargoyle": {"name": "石像鬼", "states": ["idle", "petrify", "wake", "death"], "blurb": "会石化停住，等它落地再打"},
	"elite_vampire": {"name": "精英吸血鬼", "states": ["idle", "death"], "blurb": "比普通血族更硬的近战"},
	"vampire_prince": {"name": "血族亲王", "states": ["idle", "dash", "rage", "death"], "blurb": "高层近战，会把人逼进角落"},
}

## Boss：单格 128×128。先备 idle，其余动作有文件才会被读到。
const BOSSES := {
	"blood_lord": {"name": "血铠领主", "states": ["idle", "move", "guard", "sword_combo", "charge", "shield_break", "stunned", "enraged", "death", "broken_move", "broken_sword_combo", "guarded_stunned"], "blurb": "正面盾挡，冲锋撞墙会眩晕"},
	"blood_matriarch": {"name": "织血母皇", "states": ["idle", "move", "lay_egg", "summon", "web_cast", "melee", "phase_change", "death"], "blurb": "产卵铺网召唤幼虫，清掉卵巢后改近身"},
	"tomb_warden": {"name": "墓穴守望者", "states": ["idle", "move", "lantern_sweep", "revive", "ward_break", "death"], "blurb": "结界在就能复苏，打掉结界就停"},
	"alchemist_prince": {"name": "炼金亲王", "states": ["idle", "move", "cast", "solo_shift", "death"], "blurb": "和巨像互改招式，药液敌我都伤"},
	"alchemist_colossus": {"name": "炼金巨像", "states": ["idle", "move", "slam", "enrage", "death"], "blurb": "炼金巨像，亲王倒下后改砸地"},
	"eclipse_queen": {"name": "月蚀女王", "states": ["idle", "move", "blink", "appear", "phase_change", "death"], "blurb": "换位前标落点，毁掉祭坛会缩小安全圈"},
}

const WEAPONS := {
	"scythe": "沿弧线飞出再折返",
	"thorn_whip": "抽击身前扇形并击退",
	"frost_bell": "周期霜环，挂上霜缚",
	"repeater": "短点射后有一段长停顿",
	"soul_lantern": "魂火飞向敌人再返回",
	"spike_tome": "脚下预警结束后扎出地刺",
	"chain_gun": "命中后用链带连向第二个目标",
	"thunder_bolt": "弩箭命中后在房间内再跳一次",
	"miasma_shot": "弹丸消失时留下一小团毒雾",
	"returning_blade": "保留穿透和弹墙，间隔取两把武器中间",
	"twin_chant": "飞到尽头分成两枚",
	"burning_blood": "每四次命中爆开一小团血",
}

const PASSIVES := {
	"execution_mark": "持续打同一个精英或 Boss 会越来越疼，换目标就清空",
	"time_gear": "弹丸变大、穿透加一，飞得更慢",
	"cold_blood": "流血又被霜缚的目标会崩开一下，每个目标单独冷却",
}

## 特效序列帧：矩形单格，必须显式给帧数和单格尺寸。
## 路径不存在时，游戏侧自动退回单帧贴图，不会有硬报错。
const EFFECT_SHEETS := {
	"hit": {"path": "res://assets/effects/hit_effect_sheet.png", "frames": 4, "cell": [64, 64], "mode": "once"},
	"explosion": {"path": "res://assets/effects/death_explosion_sheet.png", "frames": 6, "cell": [128, 128], "mode": "once"},
	"portal": {"path": "res://assets/effects/portal_sheet.png", "frames": 6, "cell": [96, 96], "mode": "loop"},
	"shield_break": {"path": "res://assets/effects/shield_break_sheet.png", "frames": 6, "cell": [64, 64], "mode": "once"},
	"poison_spread": {"path": "res://assets/effects/poison_spread_sheet.png", "frames": 6, "cell": [128, 128], "mode": "loop"},
	"levelup_aura": {"path": "res://assets/effects/levelup_aura_sheet.png", "frames": 6, "cell": [128, 128], "mode": "once"},
	"freeze_effect": {"path": "res://assets/effects/freeze_effect_sheet.png", "frames": 6, "cell": [48, 48], "mode": "once"},
	"petrify_effect": {"path": "res://assets/effects/petrify_effect_sheet.png", "frames": 6, "cell": [48, 48], "mode": "once"},
	"holy_light": {"path": "res://assets/effects/holy_light_sheet.png", "frames": 6, "cell": [128, 128], "mode": "once"},
	"chain_lightning": {"path": "res://assets/effects/chain_lightning_sheet.png", "frames": 4, "cell": [128, 128], "mode": "once"},
	"thunder_wrath": {"path": "res://assets/effects/thunder_wrath_sheet.png", "frames": 6, "cell": [128, 128], "mode": "once"},
}

## 环境道具的序列帧：火把/营火循环，宝箱/受诅宝箱是一次性开箱。
const PROP_SHEETS := {
	"torch": {"path": "res://assets/tiles/props/torch_sheet.png", "frames": 4, "cell": [24, 48], "mode": "loop"},
	"campfire": {"path": "res://assets/tiles/props/campfire_sheet.png", "frames": 4, "cell": [40, 48], "mode": "loop"},
	"chest": {"path": "res://assets/tiles/props/chest_sheet.png", "frames": 6, "cell": [48, 40], "mode": "once"},
	"cursed_chest": {"path": "res://assets/items/cursed_chest_sheet.png", "frames": 6, "cell": [48, 40], "mode": "once"},
	"merchant": {"path": "res://assets/ui/merchant_sheet.png", "frames": 4, "cell": [128, 128], "mode": "loop"},
}

## 敌人内部类型 → 图鉴条目 id。
## 骷髅射手的 _get_enemy_type() 返回 "skeleton"，精英吸血鬼返回 "elite"，
## 和图鉴条目名（skeleton_archer / elite_vampire）对不上：
## 解锁记录会记到不存在的 id 上，图鉴里永远显示 ???。
const ENEMY_TYPE_ALIASES: Dictionary = {
	"skeleton": "skeleton_archer",
	"elite": "elite_vampire",
}

## 图鉴条目 id → 精灵目录名。骷髅射手的贴图放在 skeleton/ 目录下。
const ENEMY_ASSET_DIR_ALIASES: Dictionary = {
	"skeleton_archer": "skeleton",
}

## 把敌人内部类型翻成图鉴 id。解锁与展示都走这一个口径。
static func codex_enemy_id(enemy_type: String) -> String:
	return String(ENEMY_TYPE_ALIASES.get(enemy_type, enemy_type))

static func enemy_asset_dir(enemy_id: String) -> String:
	return String(ENEMY_ASSET_DIR_ALIASES.get(enemy_id, enemy_id))

static func enemy_path(enemy_id: String, state: String = "idle") -> String:
	return "%s/%s/%s.png" % [ENEMY_ROOT, enemy_asset_dir(enemy_id), state]

static func boss_path(boss_id: String, state: String = "idle") -> String:
	return "%s/%s/%s.png" % [BOSS_ROOT, boss_id, state]

static func weapon_icon_path(weapon_id: String) -> String:
	return "%s/%s.png" % [WEAPON_ICON_ROOT, weapon_id]

static func passive_icon_path(passive_id: String) -> String:
	return "%s/%s.png" % [PASSIVE_ICON_ROOT, passive_id]

static func texture_at(path: String) -> Texture2D:
	if path == "" or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D

static func enemy_texture(enemy_id: String, state: String) -> Texture2D:
	return texture_at(enemy_path(enemy_id, state))

static func boss_texture(boss_id: String, state: String) -> Texture2D:
	return texture_at(boss_path(boss_id, state))

static func weapon_icon(weapon_id: String) -> Texture2D:
	return texture_at(weapon_icon_path(weapon_id))

static func passive_icon(passive_id: String) -> Texture2D:
	return texture_at(passive_icon_path(passive_id))

## 特效序列帧的登记项；没有登记返回空字典。
static func effect_sheet(effect_name: String) -> Dictionary:
	return EFFECT_SHEETS.get(effect_name, {})

## 道具序列帧的登记项；没有登记返回空字典。
static func prop_sheet(prop_name: String) -> Dictionary:
	return PROP_SHEETS.get(prop_name, {})

static func blurb(kind: String, entry_id: String) -> String:
	match kind:
		"enemy":
			return String(ENEMIES.get(entry_id, {}).get("blurb", ""))
		"boss":
			return String(BOSSES.get(entry_id, {}).get("blurb", ""))
		"weapon":
			return String(WEAPONS.get(entry_id, ""))
		"passive":
			return String(PASSIVES.get(entry_id, ""))
	return ""
