extends Resource
## 武器数据资源
## 2–5 级不再走全局伤害/攻速公式，每把武器一张分轴表。
## 没有这张表的武器不能进升级池。

@export var weapon_name: String = "手枪"
@export var weapon_id: String = "pistol"
@export var description: String = "基础手枪"

@export var base_damage: float = 6.0
@export var fire_rate: float = 0.3
@export var bullet_speed: float = 500.0
@export var bullet_range: float = 800.0
@export var projectile_count: int = 1
@export var spread_angle: float = 0.0
@export var auto_aim: bool = false

@export var max_level: int = 5
var current_level: int = 1

# 飞刀 / 弩 / 苦无
@export var pierce_count: int = 0
var bounce_count: int = 0

# 毒雾 / 血爆。默认 0：没有这套属性的武器不要跟着长持续时间。
@export var cloud_duration: float = 0.0
@export var cloud_size: float = 1.0

# 闪电。默认 0，只有闪电法杖在创建时写上基础跳跃。
@export var lightning_jumps: int = 0

# 回旋镰 / 长鞭 / 圣铃。表里没写的等级沿用这些基础值。
var arc_width: float = 64.0
var return_damage_mult: float = 0.6
var cone_angle: float = 0.9
var whip_reach: float = 130.0
var knockback_force: float = 90.0
var swing_count: int = 1
var ring_radius: float = 120.0
var slow_duration: float = 1.6
var burst_gap: float = 0.12

## 进化或融合叠在「表里已经结算好的满级值」上，不再改写 base_damage。
## 这样满级终点和变种表保持同一份数字。
var bonus_damage_mult: float = 1.0
var bonus_interval_mult: float = 1.0
## 融合指定的绝对间隔。大于 0 时盖过表里的间隔。
var interval_override: float = -1.0

## 融合后换掉 weapon_id，数值表和开火形态仍认原来的武器。
var stat_id: String = ""
var attack_profile: String = ""
var fusion_kind: String = ""
var fused: bool = false
## 燃血：命中计数，每 4 次爆一次。
var fusion_hits: int = 0

const LEVEL_STEPS := {
	"pistol": {
		2: {"projectile_count": 2, "card": "弹道 1 → 2"},
		3: {"fire_rate": 0.19, "card": "间隔 0.25 → 0.19"},
		4: {"projectile_count": 3, "card": "弹道 2 → 3"},
		5: {"damage": 6.4, "card": "伤害 4.0 → 6.4"},
	},
	"shotgun": {
		2: {"projectile_count": 4, "card": "弹道 3 → 4"},
		3: {"projectile_count": 5, "card": "弹道 4 → 5"},
		4: {"fire_rate": 0.57, "card": "间隔 0.75 → 0.57"},
		5: {"damage": 6.4, "card": "伤害 4.0 → 6.4"},
	},
	"magic_book": {
		2: {"projectile_count": 2, "card": "弹道 1 → 2"},
		3: {"projectile_count": 3, "card": "弹道 2 → 3"},
		4: {"fire_rate": 0.46, "card": "间隔 0.60 → 0.46"},
		5: {"damage": 6.4, "card": "伤害 4.0 → 6.4"},
	},
	"throwing_knife": {
		2: {"pierce_count": 5, "card": "穿透 3 → 5"},
		3: {"projectile_count": 3, "card": "弹道 1 → 3"},
		4: {"bounce_count": 1, "card": "弹射 1 次，穿透保持 5"},
		5: {"damage": 9.6, "fire_rate": 0.38, "card": "伤害 6.0 → 9.6，间隔 0.50 → 0.38"},
	},
	"poison_cloud": {
		2: {"cloud_size": 1.3, "card": "范围 1.0 → 1.3"},
		3: {"cloud_duration": 6.0, "card": "持续 5s → 6s"},
		4: {"fire_rate": 1.35, "card": "间隔 1.5 → 1.35"},
		5: {"damage": 4.6, "card": "伤害 2.5 → 4.6"},
	},
	"lightning_chain": {
		2: {"lightning_jumps": 5, "card": "跳跃 3 → 5"},
		3: {"lightning_jumps": 7, "card": "跳跃 5 → 7"},
		4: {"fire_rate": 0.61, "card": "间隔 0.80 → 0.61"},
		5: {"damage": 12.0, "card": "伤害 7.5 → 12.0"},
	},
	"crossbow": {
		2: {"pierce_count": 6, "card": "穿透 2 → 6"},
		3: {"projectile_count": 3, "card": "弹道 1 → 3"},
		4: {"fire_rate": 0.68, "card": "间隔 0.90 → 0.68"},
		5: {"damage": 22.4, "card": "伤害 14 → 22.4"},
	},
	"holy_wand": {
		2: {"projectile_count": 2, "card": "弹道 1 → 2"},
		3: {"projectile_count": 3, "card": "弹道 2 → 3"},
		4: {"fire_rate": 0.38, "card": "间隔 0.50 → 0.38"},
		5: {"damage": 8.0, "card": "伤害 5.0 → 8.0"},
	},
	"kunai": {
		2: {"projectile_count": 2, "card": "弹道 1 → 2"},
		3: {"projectile_count": 3, "card": "弹道 2 → 3"},
		4: {"fire_rate": 0.12, "card": "间隔 0.16 → 0.12"},
		5: {"damage": 5.12, "pierce_count": 5, "card": "伤害 3.2 → 5.12，穿透 1 → 5"},
	},
	"flame_thrower": {
		2: {"projectile_count": 2, "card": "弹道 1 → 2"},
		3: {"projectile_count": 3, "card": "弹道 2 → 3"},
		4: {"spread_angle": 0.40, "card": "张角 0.26 → 0.40"},
		5: {"damage": 1.76, "card": "伤害 1.1 → 1.76"},
	},
	"blood_burst": {
		2: {"cloud_size": 2.7, "card": "范围 1.5 → 2.7"},
		3: {"cloud_duration": 5.0, "card": "持续 1s → 5s"},
		4: {"fire_rate": 0.99, "card": "间隔 1.3 → 0.99"},
		5: {"damage": 14.4, "card": "伤害 9.0 → 14.4"},
	},
	"scythe": {
		2: {"return_damage_mult": 1.0, "card": "回程伤害 0.6 → 1.0"},
		3: {"projectile_count": 2, "card": "弹道 1 → 2"},
		4: {"arc_width": 110.0, "card": "弧线偏幅 64 → 110"},
		5: {"damage": 8.8, "card": "伤害 5.5 → 8.8"},
	},
	"thorn_whip": {
		2: {"knockback_force": 160.0, "card": "击退 90 → 160"},
		3: {"cone_angle": 1.35, "card": "扇形 0.90 → 1.35"},
		4: {"swing_count": 2, "card": "连击 1 → 2"},
		5: {"damage": 5.44, "card": "伤害 3.4 → 5.44"},
	},
	"frost_bell": {
		2: {"ring_radius": 180.0, "card": "霜环半径 120 → 180"},
		3: {"slow_duration": 2.8, "card": "霜缚 1.6s → 2.8s"},
		4: {"fire_rate": 0.95, "card": "间隔 1.25 → 0.95"},
		5: {"damage": 3.52, "card": "伤害 2.2 → 3.52"},
	},
	"repeater": {
		2: {"projectile_count": 4, "card": "点射 3 → 4"},
		3: {"burst_gap": 0.08, "card": "点射间隔 0.12 → 0.08"},
		4: {"fire_rate": 0.72, "card": "停顿 0.95 → 0.72"},
		5: {"damage": 5.76, "card": "伤害 3.6 → 5.76"},
	},
	"soul_lantern": {
		2: {"projectile_count": 2, "card": "魂火 1 → 2"},
		3: {"return_damage_mult": 1.0, "card": "回程伤害 0.5 → 1.0"},
		4: {"fire_rate": 0.62, "card": "间隔 0.80 → 0.62"},
		5: {"damage": 6.72, "card": "伤害 4.2 → 6.72"},
	},
	"spike_tome": {
		2: {"cloud_size": 1.45, "card": "地刺范围 1.0 → 1.45"},
		3: {"projectile_count": 2, "card": "地刺 1 → 2"},
		4: {"cloud_duration": 0.35, "card": "预警 0.55s → 0.35s"},
		5: {"damage": 11.2, "card": "伤害 7.0 → 11.2"},
	},
	"chain_gun": {
		2: {"whip_reach": 220.0, "card": "连锁距离 150 → 220"},
		3: {"return_damage_mult": 0.8, "card": "连锁伤害 0.55 → 0.80"},
		4: {"fire_rate": 0.42, "card": "间隔 0.55 → 0.42"},
		5: {"damage": 10.4, "card": "伤害 6.5 → 10.4"},
	},
}

func profile() -> String:
	if attack_profile != "":
		return attack_profile
	return weapon_id

func table_id() -> String:
	if stat_id != "":
		return stat_id
	return weapon_id

func has_level_table() -> bool:
	return LEVEL_STEPS.has(table_id())

func describe_next_level() -> String:
	if fused or is_max_level() or not has_level_table():
		return ""
	var step: Dictionary = _step(current_level + 1)
	return String(step.get("card", ""))

func step_keys(level: int) -> Array:
	## 这一级真正改掉的字段。card 只是文案，不算数值轴。
	var keys: Array = []
	for key in _step(level).keys():
		if String(key) == "card":
			continue
		keys.append(String(key))
	return keys

func get_scaled_damage() -> float:
	return float(_value_at("damage", base_damage)) * bonus_damage_mult

func get_scaled_fire_rate() -> float:
	if interval_override > 0.0:
		return interval_override
	var interval := float(_value_at("fire_rate", fire_rate)) * bonus_interval_mult
	return maxf(interval, 0.08)

func get_scaled_projectile_count() -> int:
	return int(_value_at("projectile_count", projectile_count))

func get_scaled_pierce_count() -> int:
	if pierce_count <= 0 and not _table_touches("pierce_count"):
		return 0
	return int(_value_at("pierce_count", pierce_count))

func get_scaled_bounce_count() -> int:
	return int(_value_at("bounce_count", bounce_count))

func get_scaled_cloud_duration() -> float:
	if cloud_duration <= 0.0 and not _table_touches("cloud_duration"):
		return 0.0
	return float(_value_at("cloud_duration", cloud_duration))

func get_scaled_cloud_size() -> float:
	if cloud_size <= 0.0 and not _table_touches("cloud_size"):
		return 1.0
	return float(_value_at("cloud_size", cloud_size))

func get_scaled_lightning_jumps() -> int:
	if lightning_jumps <= 0 and not _table_touches("lightning_jumps"):
		return 0
	return int(_value_at("lightning_jumps", lightning_jumps))

func get_scaled_spread() -> float:
	return float(_value_at("spread_angle", spread_angle))

func get_scaled_arc_width() -> float:
	return float(_value_at("arc_width", arc_width))

func get_scaled_return_mult() -> float:
	return float(_value_at("return_damage_mult", return_damage_mult))

func get_scaled_cone() -> float:
	return float(_value_at("cone_angle", cone_angle))

func get_scaled_whip_reach() -> float:
	return float(_value_at("whip_reach", whip_reach))

func get_scaled_knockback() -> float:
	return float(_value_at("knockback_force", knockback_force))

func get_scaled_swings() -> int:
	return int(_value_at("swing_count", swing_count))

func get_scaled_ring_radius() -> float:
	return float(_value_at("ring_radius", ring_radius))

func get_scaled_slow_duration() -> float:
	return float(_value_at("slow_duration", slow_duration))

func get_scaled_burst_gap() -> float:
	return float(_value_at("burst_gap", burst_gap))

func get_scaled_bullet_range() -> float:
	return float(_value_at("bullet_range", bullet_range))

func get_scaled_bullet_speed() -> float:
	return float(_value_at("bullet_speed", bullet_speed))

func level_up() -> bool:
	if fused or current_level >= max_level:
		return false
	if not has_level_table():
		return false
	current_level += 1
	return true

func is_max_level() -> bool:
	return fused or current_level >= max_level

func _step(level: int) -> Dictionary:
	var table: Dictionary = LEVEL_STEPS.get(table_id(), {})
	return table.get(level, {})

func _table_touches(key: String) -> bool:
	var table: Dictionary = LEVEL_STEPS.get(table_id(), {})
	for level in table.keys():
		if table[level].has(key):
			return true
	return false

func _value_at(key: String, fallback) -> Variant:
	var value = fallback
	for level in range(2, current_level + 1):
		var step := _step(level)
		if step.has(key):
			value = step[key]
	return value
