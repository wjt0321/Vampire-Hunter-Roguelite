extends Resource
## 被动道具数据
## 定义被动道具的属性和效果

@export var item_id: String = ""
@export var item_name: String = ""
@export var description: String = ""
@export var icon_emoji: String = "📦"

# 效果类型
enum EffectType { MAGNET, SHIELD, REGENERATION, GREED, BERSERKER, FROZEN, LIGHTNING_SHIELD, SHADOW }
@export var effect_type: EffectType = EffectType.MAGNET

# 基础数值
@export var base_value: float = 1.0
@export var value_per_level: float = 0.3

var current_level: int = 1
const MAX_LEVEL: int = 5

func get_scaled_value() -> float:
	return base_value + (current_level - 1) * value_per_level

func level_up() -> bool:
	if current_level >= MAX_LEVEL:
		return false
	current_level += 1
	return true

func is_max_level() -> bool:
	return current_level >= MAX_LEVEL

static func create_magnet() -> Resource:
	var script = preload("res://scripts/player/passive_item_data.gd")
	var item = script.new()
	item.item_id = "magnet"
	item.item_name = "经验磁铁"
	item.description = "增加经验宝石吸附范围"
	item.icon_emoji = "🧲"
	item.effect_type = EffectType.MAGNET
	item.base_value = 1.0  # 基础吸附范围倍数
	item.value_per_level = 0.3  # 每级增加30%
	return item

static func create_shield() -> Resource:
	var script = preload("res://scripts/player/passive_item_data.gd")
	var item = script.new()
	item.item_id = "shield"
	item.item_name = "能量护盾"
	item.description = "定期生成抵挡伤害的护盾"
	item.icon_emoji = "🛡️"
	item.effect_type = EffectType.SHIELD
	item.base_value = 30.0  # 基础冷却30秒
	item.value_per_level = -5.0  # 每级减少5秒
	return item

static func create_regeneration() -> Resource:
	var script = preload("res://scripts/player/passive_item_data.gd")
	var item = script.new()
	item.item_id = "regeneration"
	item.item_name = "生命恢复"
	item.description = "定期恢复生命值"
	item.icon_emoji = "💚"
	item.effect_type = EffectType.REGENERATION
	item.base_value = 0.01  # 基础1%生命恢复
	item.value_per_level = 0.01  # 每级增加1%
	return item

static func create_greed_ring() -> Resource:
	var script = preload("res://scripts/player/passive_item_data.gd")
	var item = script.new()
	item.item_id = "greed_ring"
	item.item_name = "贪婪戒指"
	item.description = "增加经验获取量"
	item.icon_emoji = "💍"
	item.effect_type = EffectType.GREED
	item.base_value = 0.2  # 基础20%经验加成
	item.value_per_level = 0.1  # 每级增加10%
	return item

static func create_berserker_blood() -> Resource:
	var script = preload("res://scripts/player/passive_item_data.gd")
	var item = script.new()
	item.item_id = "berserker_blood"
	item.item_name = "狂战士之血"
	item.description = "生命值低于30%时攻击力大幅提升"
	item.icon_emoji = "🩸"
	item.effect_type = EffectType.BERSERKER
	item.base_value = 0.5  # 基础50%伤害加成
	item.value_per_level = 0.1  # 每级增加10%
	return item

static func create_frozen_heart() -> Resource:
	var script = preload("res://scripts/player/passive_item_data.gd")
	var item = script.new()
	item.item_id = "frozen_heart"
	item.item_name = "冰冻之心"
	item.description = "攻击有几率冻结敌人"
	item.icon_emoji = "❄️"
	item.effect_type = EffectType.FROZEN
	item.base_value = 0.1  # 基础10%冻结几率
	item.value_per_level = 0.05  # 每级增加5%
	return item

static func create_lightning_shield() -> Resource:
	var script = preload("res://scripts/player/passive_item_data.gd")
	var item = script.new()
	item.item_id = "lightning_shield"
	item.item_name = "闪电护符"
	item.description = "受到伤害时释放闪电反击"
	item.icon_emoji = "⚡"
	item.effect_type = EffectType.LIGHTNING_SHIELD
	item.base_value = 20.0  # 基础20点伤害
	item.value_per_level = 10.0  # 每级增加10点
	return item

static func create_shadow_cloak() -> Resource:
	var script = preload("res://scripts/player/passive_item_data.gd")
	var item = script.new()
	item.item_id = "shadow_cloak"
	item.item_name = "影子披风"
	item.description = "增加闪避几率"
	item.icon_emoji = "🌑"
	item.effect_type = EffectType.SHADOW
	item.base_value = 0.05  # 基础5%闪避
	item.value_per_level = 0.03  # 每级增加3%
	return item
