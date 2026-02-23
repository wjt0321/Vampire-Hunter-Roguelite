extends Resource
## 武器数据资源
## 定义武器的基础属性（不使用 class_name 避免解析顺序问题）

@export var weapon_name: String = "手枪"
@export var weapon_id: String = "pistol"
@export var description: String = "基础手枪"
@export var icon_emoji: String = "🔫"

@export var base_damage: float = 7.2  # 降低10% (原8.0)
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

# 毒雾特有属性
@export var cloud_duration: float = 5.0
@export var cloud_size: float = 1.0

# 闪电链特有属性
@export var lightning_jumps: int = 3

func get_scaled_damage() -> float:
	# 每级提升20% (原30%)，降低10%
	return base_damage * (1.0 + (current_level - 1) * 0.2)

func get_scaled_fire_rate() -> float:
	return fire_rate * (1.0 - (current_level - 1) * 0.08)

func get_scaled_projectile_count() -> int:
	return projectile_count + (current_level - 1) / 2

func get_scaled_pierce_count() -> int:
	# 飞刀每升1级增加1个穿透
	if pierce_count > 0:
		return pierce_count + (current_level - 1)
	return 0

func get_scaled_cloud_duration() -> float:
	# 毒雾每升1级增加1秒持续时间
	if cloud_duration > 0:
		return cloud_duration + (current_level - 1) * 1.0
	return 0.0

func get_scaled_cloud_size() -> float:
	# 毒雾每升1级增加20%范围
	if cloud_size > 0:
		return cloud_size * (1.0 + (current_level - 1) * 0.2)
	return 1.0

func get_scaled_lightning_jumps() -> int:
	# 闪电每升1级增加1次跳跃
	if lightning_jumps > 0:
		return lightning_jumps + (current_level - 1)
	return 0

func level_up() -> bool:
	if current_level >= max_level:
		return false
	current_level += 1
	return true

func is_max_level() -> bool:
	return current_level >= max_level
