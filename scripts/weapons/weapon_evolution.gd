extends Resource
## 武器进化数据
## 定义武器从满级进化到终极形态的条件和效果

class_name WeaponEvolution

@export var evolution_name: String = "进化武器"
@export var evolution_description: String = "终极形态"
@export var evolution_icon: String = "✨"

# 进化条件
var required_passive_items: Array = []  # 需要的被动道具ID
@export var required_kill_count: int = 0  # 需要的击杀数

# 进化后效果
@export var damage_multiplier: float = 2.0  # 伤害倍率
@export var fire_rate_multiplier: float = 0.5  # 射击间隔倍率（越小越快）
@export var size_multiplier: float = 1.5  # 子弹/效果大小倍率
@export var special_effect: String = ""  # 特殊效果描述

# 是否为进化形态
var is_evolved: bool = false

func can_evolve(current_kills: int, owned_passives: Array) -> bool:
	## 检查是否满足进化条件
	if is_evolved:
		return false
	
	# 检查击杀数
	if current_kills < required_kill_count:
		return false
	
	# 检查被动道具
	for item in required_passive_items:
		if item not in owned_passives:
			return false
	
	return true

func evolve() -> void:
	is_evolved = true

func get_evolved_damage(base_damage: float) -> float:
	return base_damage * damage_multiplier

func get_evolved_fire_rate(base_fire_rate: float) -> float:
	return base_fire_rate * fire_rate_multiplier

func get_evolved_size(base_size: float) -> float:
	return base_size * size_multiplier
