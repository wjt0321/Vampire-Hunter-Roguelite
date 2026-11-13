extends Resource
class_name PassiveItemData
## 被动道具数据
## 定义被动道具的属性和效果

@export var item_id: String = ""
@export var item_name: String = ""
@export var description: String = ""

# 效果类型
enum EffectType { MAGNET, SHIELD, REGENERATION, GREED, BERSERKER, FROZEN, LIGHTNING_SHIELD, SHADOW, VAMPIRIC, SWIFT, CLOVER, BLEED, SLOW, DRAIN, EXECUTION, TIME_GEAR, COLD_BLOOD }
@export var effect_type: EffectType = EffectType.MAGNET

# 基础数值
@export var base_value: float = 1.0
@export var value_per_level: float = 0.3

var current_level: int = 1
const MAX_LEVEL: int = 5

## 每级增益递减系数：第 n 级只吃到 0.85^(n-1) 的增量
const LEVEL_DECAY: float = 0.85

func get_scaled_value() -> float:
	return get_scaled_value_at(current_level)

func get_scaled_value_at(level: int) -> float:
	## 指定等级的数值（升级卡要显示 "当前 → 下一级"，不能靠临时改等级去试算）
	var lv: int = maxi(level, 1)
	# 负增长（如护盾冷却缩减）保持线性，避免递减后反而变弱
	if value_per_level < 0.0:
		return base_value + (lv - 1) * value_per_level
	var total := base_value
	for i in range(1, lv):
		total += value_per_level * pow(LEVEL_DECAY, i - 1)
	return total

func level_up() -> bool:
	if current_level >= MAX_LEVEL:
		return false
	current_level += 1
	return true

func is_max_level() -> bool:
	return current_level >= MAX_LEVEL

## 实际生效数值：套上 GameConfig 里的真实上限。
## 冰冻之心满级 raw 25.9% 实际只给 25%，吸血獠牙 raw 29.1% 只给 28%。
func effective_value_at(level: int) -> float:
	return GameConfig.cap_passive_value(item_id, get_scaled_value_at(level))

func effective_value() -> float:
	return effective_value_at(current_level)

func has_gain_at_next_level() -> bool:
	## 再投一级到底涨不涨。上限截断之后存在"等级还能升、数值不动"的情况，
	## 这时把卡留在选池里等于让玩家拿一次升级换一个数字没变的提示。
	if is_max_level():
		return false
	var now: float = effective_value_at(current_level)
	var next: float = effective_value_at(current_level + 1)
	return absf(next - now) > GameConfig.PASSIVE_GAIN_EPSILON

func is_effectively_maxed() -> bool:
	## 池子/商店过滤用这个，而不是 is_max_level()：
	## 只认 5 级的话，"撞了上限但没到 5 级"的道具会一直占着升级位。
	return not has_gain_at_next_level()

static func create_magnet() -> Resource:
	var item := PassiveItemData.new()
	item.item_id = "magnet"
	item.item_name = "经验磁铁"
	item.description = "增加经验宝石吸附范围"
	item.effect_type = EffectType.MAGNET
	item.base_value = 1.0  # 基础吸附范围倍数
	item.value_per_level = 0.3  # 每级增加30%
	return item

static func create_shield() -> Resource:
	var item := PassiveItemData.new()
	item.item_id = "shield"
	item.item_name = "能量护盾"
	item.description = "定期生成抵挡伤害的护盾"
	item.effect_type = EffectType.SHIELD
	item.base_value = 30.0  # 基础冷却30秒
	item.value_per_level = -5.0  # 每级减少5秒
	return item

static func create_regeneration() -> Resource:
	var item := PassiveItemData.new()
	item.item_id = "regeneration"
	item.item_name = "生命恢复"
	item.description = "定期恢复生命值"
	item.effect_type = EffectType.REGENERATION
	item.base_value = 0.01  # 基础1%生命恢复
	item.value_per_level = 0.01  # 每级增加1%
	return item

static func create_greed_ring() -> Resource:
	var item := PassiveItemData.new()
	item.item_id = "greed_ring"
	item.item_name = "贪婪戒指"
	item.description = "增加经验获取量"
	item.effect_type = EffectType.GREED
	item.base_value = 0.2  # 基础20%经验加成
	item.value_per_level = 0.1  # 每级增加10%
	return item

static func create_berserker_blood() -> Resource:
	var item := PassiveItemData.new()
	item.item_id = "berserker_blood"
	item.item_name = "狂战士之血"
	item.description = "生命值低于30%时攻击力大幅提升"
	item.effect_type = EffectType.BERSERKER
	item.base_value = 0.5  # 基础50%伤害加成
	item.value_per_level = 0.1  # 每级增加10%
	return item

static func create_frozen_heart() -> Resource:
	var item := PassiveItemData.new()
	item.item_id = "frozen_heart"
	item.item_name = "冰冻之心"
	item.description = "攻击有几率冻结敌人"
	item.effect_type = EffectType.FROZEN
	item.base_value = 0.1  # 基础10%冻结几率
	item.value_per_level = 0.05  # 每级增加5%
	return item

static func create_lightning_shield() -> Resource:
	var item := PassiveItemData.new()
	item.item_id = "lightning_shield"
	item.item_name = "闪电护符"
	item.description = "受到伤害时释放闪电反击"
	item.effect_type = EffectType.LIGHTNING_SHIELD
	item.base_value = 20.0  # 基础20点伤害
	item.value_per_level = 10.0  # 每级增加10点
	return item

static func create_shadow_cloak() -> Resource:
	var item := PassiveItemData.new()
	item.item_id = "shadow_cloak"
	item.item_name = "影子披风"
	item.description = "增加闪避几率"
	item.effect_type = EffectType.SHADOW
	item.base_value = 0.05  # 基础5%闪避
	item.value_per_level = 0.03  # 每级增加3%
	return item

static func create_vampiric_fang() -> Resource:
	var item := PassiveItemData.new()
	item.item_id = "vampiric_fang"
	item.item_name = "吸血獠牙"
	item.description = "击杀敌人时概率吸血"
	item.effect_type = EffectType.VAMPIRIC
	item.base_value = 0.1  # 基础10%触发几率
	item.value_per_level = 0.06  # 每级增加6%
	return item

static func create_swift_boots() -> Resource:
	var item := PassiveItemData.new()
	item.item_id = "swift_boots"
	item.item_name = "疾风靴"
	item.description = "增加移动速度"
	item.effect_type = EffectType.SWIFT
	item.base_value = 0.1  # 基础10%移速
	item.value_per_level = 0.05  # 每级增加5%
	return item

static func create_lucky_clover() -> Resource:
	var item := PassiveItemData.new()
	item.item_id = "lucky_clover"
	item.item_name = "幸运四叶草"
	item.description = "增加暴击几率"
	item.effect_type = EffectType.CLOVER
	item.base_value = 0.08  # 基础8%暴击
	item.value_per_level = 0.04  # 每级增加4%
	return item

# === 17.13 状态修饰器：挂在任意武器上的三个词条 ===

static func create_blood_edge() -> Resource:
	## 血刃 —— 命中时概率让敌人流血。伤害按"触发的那一下"折算，
	## 所以它天生偏爱单发高伤的武器（十字弩 / 散弹），而不是高频小弹。
	var item := PassiveItemData.new()
	item.item_id = "blood_edge"
	item.item_name = "血刃"
	item.description = "命中时概率使敌人流血"
	item.effect_type = EffectType.BLEED
	item.base_value = 0.25  # 基础25%触发
	item.value_per_level = 0.08
	return item

static func create_frost_bind() -> Resource:
	## 霜缚 —— 命中时概率减速。唯一能"改变敌人到位时间"的修饰器，
	## 对冲锋怪和围上来的近战最有用。
	var item := PassiveItemData.new()
	item.item_id = "frost_bind"
	item.item_name = "霜缚"
	item.description = "命中时概率使敌人减速"
	item.effect_type = EffectType.SLOW
	item.base_value = 0.30
	item.value_per_level = 0.07
	return item

static func create_blood_drain() -> Resource:
	## 汲取 —— 造成的伤害按比例回血。和"吸血獠牙"（击杀概率回血）不重复：
	## 那个奖励的是清场，这个奖励的是持续输出（打 Boss / 打高血量精英）。
	var item := PassiveItemData.new()
	item.item_id = "blood_drain"
	item.item_name = "汲取"
	item.description = "造成的伤害按比例转为生命"
	item.effect_type = EffectType.DRAIN
	item.base_value = 0.02  # 基础 2% 伤害转治疗
	item.value_per_level = 0.008
	return item

static func create_execution_mark() -> Resource:
	var item := PassiveItemData.new()
	item.item_id = "execution_mark"
	item.item_name = "处刑印记"
	item.description = "连续命中同一精英或 Boss 会叠伤害，换目标清空"
	item.effect_type = EffectType.EXECUTION
	item.base_value = 0.08
	item.value_per_level = 0.02
	return item

static func create_time_gear() -> Resource:
	var item := PassiveItemData.new()
	item.item_id = "time_gear"
	item.item_name = "时滞齿轮"
	item.description = "弹丸变大并多穿透 1，飞行变慢"
	item.effect_type = EffectType.TIME_GEAR
	item.base_value = 1.25
	item.value_per_level = 0.05
	return item

static func create_cold_blood() -> Resource:
	var item := PassiveItemData.new()
	item.item_id = "cold_blood"
	item.item_name = "寒血反应"
	item.description = "流血且被霜缚的目标会额外崩开一次"
	item.effect_type = EffectType.COLD_BLOOD
	item.base_value = 6.0
	item.value_per_level = 2.0
	return item
