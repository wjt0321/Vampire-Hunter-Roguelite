extends Resource
## 武器数据资源
## 定义武器的基础属性（不使用 class_name 避免解析顺序问题）

@export var weapon_name: String = "手枪"
@export var weapon_id: String = "pistol"
@export var description: String = "基础手枪"
@export var icon_emoji: String = "🔫"

@export var base_damage: float = 10.0
@export var fire_rate: float = 0.3
@export var bullet_speed: float = 500.0
@export var bullet_range: float = 800.0
@export var projectile_count: int = 1
@export var spread_angle: float = 0.0
@export var auto_aim: bool = false

@export var max_level: int = 5
var current_level: int = 1

# 飞刀特有属性
@export var pierce_count: int = 0  # 0 表示不穿透

func get_scaled_damage() -> float:
	return base_damage * (1.0 + (current_level - 1) * 0.3)

func get_scaled_fire_rate() -> float:
	return fire_rate * (1.0 - (current_level - 1) * 0.08)

func get_scaled_projectile_count() -> int:
	return projectile_count + (current_level - 1) / 2

func get_scaled_pierce_count() -> int:
	# 飞刀每升1级增加1个穿透
	if pierce_count > 0:
		return pierce_count + (current_level - 1)
	return 0

func level_up() -> bool:
	if current_level >= max_level:
		return false
	current_level += 1
	return true

func is_max_level() -> bool:
	return current_level >= max_level
