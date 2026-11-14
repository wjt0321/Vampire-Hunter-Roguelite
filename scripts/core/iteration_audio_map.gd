## 迭代新增内容（12 种新敌人 + 7 把新武器 + 5 张融合卡 + 3 个新被动）的专属音效映射。
##
## 设计原则：
## 1. 表里有就用专属音，表里没有就退回通用音（hit_enemy / enemy_death / shoot_pistol 等）。
##    这样旧敌人与旧武器完全不受影响，新增内容才有辨识度。
## 2. 键名必须与 scripts/managers/audio_library.gd 的 SFX_PATHS 对得上，
##    缺文件时 AudioLib 会明确报错而不是静默。
##
## 敌人按 _get_enemy_type() 返回的 id 匹配；武器按 weapon_id 匹配。
class_name IterationAudioMap
extends RefCounted

## 敌人 id -> {受击音, 死亡音}
const ENEMY_SFX: Dictionary = {
	"shield_guard": {"hit": "hit_shield_guard", "death": "death_shield_guard"},
	"blood_priest": {"hit": "hit_blood_priest", "death": "death_blood_priest"},
	"web_weaver": {"hit": "hit_web_weaver", "death": "death_web_weaver"},
	"coffin_guard": {"hit": "hit_coffin_guard", "death": "death_coffin_guard"},
	"blood_hound": {"hit": "hit_blood_hound", "death": "death_blood_hound"},
	"furnace_golem": {"hit": "hit_furnace_golem", "death": "death_furnace_golem"},
	"burrower": {"hit": "hit_burrower", "death": "death_burrower"},
	"gem_leech": {"hit": "hit_gem_leech", "death": "death_gem_leech"},
	"lantern_wraith": {"hit": "hit_lantern_wraith", "death": "death_lantern_wraith"},
	"alchemist_pitcher": {"hit": "hit_alchemist_pitcher", "death": "death_alchemist_pitcher"},
	"resonance_mage": {"hit": "hit_resonance_mage", "death": "death_resonance_mage"},
	"moon_wing": {"hit": "hit_moon_wing", "death": "death_moon_wing"},
}

## 武器 id -> 发射音
const WEAPON_SFX: Dictionary = {
	"scythe": "shot_scythe",
	"thorn_whip": "shot_thorn_whip",
	"frost_bell": "shot_frost_bell",
	"repeater": "shot_repeater",
	"soul_lantern": "shot_soul_lantern",
	"spike_tome": "shot_spike_tome",
	"chain_gun": "shot_chain_gun",
}

## 融合卡 kind -> 发射音。
## 融合卡不换主武器，主武器仍是原来的 id，只是武器上多了一个 fusion_kind，
## 所以这里按 fusion_kind 匹配，不能按 weapon_id 匹配。
const FUSION_SFX: Dictionary = {
	"thunder": "shot_thunder_bolt",
	"miasma": "shot_miasma",
	"returning": "shot_returning_blade",
	"split": "shot_twin_chant",
	"burning": "shot_burning_blood",
}

## 新被动 id -> 触发音
const PASSIVE_SFX: Dictionary = {
	"execution_mark": "passive_execution_mark",
	"time_gear": "passive_time_gear",
	"cold_blood": "passive_cold_blood",
}


## 敌人受击音；没有专属音时返回空串表示走通用音。
static func enemy_hit_sound(enemy_type: String) -> String:
	if not ENEMY_SFX.has(enemy_type):
		return ""
	return String(ENEMY_SFX[enemy_type].get("hit", ""))


## 敌人死亡音；没有专属音时返回空串表示走通用音。
static func enemy_death_sound(enemy_type: String) -> String:
	if not ENEMY_SFX.has(enemy_type):
		return ""
	return String(ENEMY_SFX[enemy_type].get("death", ""))


## 武器发射音；没有专属音时返回空串表示走 weapon_manager 的原有映射。
static func weapon_sound(weapon_id: String) -> String:
	return String(WEAPON_SFX.get(weapon_id, ""))

## 融合卡发射音；按武器上的 fusion_kind 匹配，没有专属音时返回空串。
static func fusion_sound(fusion_kind: String) -> String:
	if fusion_kind.is_empty():
		return ""
	return String(FUSION_SFX.get(fusion_kind, ""))


## 被动触发音；没有专属音时返回空串。
static func passive_sound(passive_id: String) -> String:
	return String(PASSIVE_SFX.get(passive_id, ""))
