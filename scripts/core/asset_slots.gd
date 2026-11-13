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
	"shield_guard": {"states": ["idle"], "blurb": "正面护盾减伤，绕到侧面或背后再打"},
	"blood_hound": {"states": ["idle"], "blurb": "先绕行，再沿直线扑击，横向躲开"},
	"blood_priest": {"states": ["idle"], "blurb": "给视线内的伤员治疗，墙能挡住"},
	"web_weaver": {"states": ["idle"], "blurb": "在地上留可打掉的减速网"},
	"burrower": {"states": ["idle"], "blurb": "钻地时打不中，落地前会标出落点"},
	"gem_leech": {"states": ["idle"], "blurb": "吞经验后逃跑，打死能把经验吐出来"},
	"coffin_guard": {"states": ["idle"], "blurb": "倒下后留下棺材，不打就会爬起来一次"},
	"lantern_wraith": {"states": ["idle"], "blurb": "直线光束持续伤血，离开或用墙挡住"},
	"alchemist_pitcher": {"states": ["idle"], "blurb": "药瓶落地后敌我都会受伤"},
	"furnace_golem": {"states": ["idle"], "blurb": "外甲在时又慢又硬，甲碎了就冲上来"},
	"resonance_mage": {"states": ["idle"], "blurb": "把同伴连起来分摊伤害，先杀术士"},
	"moon_wing": {"states": ["idle"], "blurb": "弧线换位后俯冲，并留下短风刃"},
	"bat": {"states": ["idle"], "blurb": "飞得快，优先清掉以免被缠住"},
	"vampire": {"states": ["idle"], "blurb": "近身追击，别让它贴住"},
	"zombie": {"states": ["idle"], "blurb": "慢，血厚，用来挡路"},
	"skeleton_archer": {"states": ["idle"], "blurb": "远处点射，用墙或近身打断"},
	"werewolf": {"states": ["idle"], "blurb": "冲得快，横向躲开再打"},
	"exploder": {"states": ["idle"], "blurb": "靠近会炸，自己也会伤到同伴"},
	"summoner": {"states": ["idle"], "blurb": "先杀召唤者，再清它叫出来的东西"},
	"vampire_mage": {"states": ["idle"], "blurb": "远程施法，不要站在弹道上"},
	"gargoyle": {"states": ["idle"], "blurb": "会石化停住，等它落地再打"},
	"elite_vampire": {"states": ["idle"], "blurb": "比普通血族更硬的近战"},
	"vampire_prince": {"states": ["idle"], "blurb": "高层近战，会把人逼进角落"},
}

## Boss：单格 128×128。先备 idle，其余动作有文件才会被读到。
const BOSSES := {
	"blood_lord": {"states": ["idle", "move", "guard", "charge", "stunned", "death"], "blurb": "正面盾挡，冲锋撞墙会眩晕"},
	"blood_matriarch": {"states": ["idle", "move", "lay_egg", "death"], "blurb": "产卵铺网，清掉卵巢后改近身"},
	"tomb_warden": {"states": ["idle", "move", "lantern_sweep", "death"], "blurb": "结界在就能复苏，打掉结界就停"},
	"alchemist_prince": {"states": ["idle", "move", "cast", "death"], "blurb": "和巨像互改招式，药液敌我都伤"},
	"alchemist_colossus": {"states": ["idle", "move", "slam", "death"], "blurb": "炼金巨像，亲王倒下后改砸地"},
	"eclipse_queen": {"states": ["idle", "move", "blink", "death"], "blurb": "换位前标落点，毁掉祭坛会缩小安全圈"},
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

static func enemy_path(enemy_id: String, state: String = "idle") -> String:
	return "%s/%s/%s.png" % [ENEMY_ROOT, enemy_id, state]

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
