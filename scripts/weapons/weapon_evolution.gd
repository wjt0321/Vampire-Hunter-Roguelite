extends Resource
## 武器进化数据
## 进化从"击杀数自动触发"改成"事件触发"：武器满级 + 指定被动 + 打开宝箱。
## 原因：击杀数阈值是隐形的，玩家永远不知道自己离进化还有多远，
## 也无法为一个"看得见的目标"做取舍（比如为了进化去拿某个被动）。

class_name WeaponEvolution

@export var evolution_name: String = "进化武器"
@export var evolution_description: String = "终极形态"
@export var evolution_icon: String = "✨"

# 进化条件
## 需要的被动道具 ID（至少 Lv1 即可）
var required_passive_items: Array = []
## 兼容旧配置保留，不再参与判定
@export var required_kill_count: int = 0

# 进化后效果
@export var damage_multiplier: float = 2.0  # 伤害倍率
@export var fire_rate_multiplier: float = 0.5  # 射击间隔倍率（越小越快）
@export var size_multiplier: float = 1.5  # 子弹/效果大小倍率
@export var special_effect: String = ""  # 特殊效果描述
## 行为级差异标识："double_barrel" / "orbit" / "radial" / ""（仅数值强化）
var behavior: String = ""

# 是否为进化形态
var is_evolved: bool = false

func can_evolve(owned_passives: Array) -> bool:
	## 是否满足被动条件（满级判定由 WeaponManager 负责）
	if is_evolved:
		return false
	for item in required_passive_items:
		if item not in owned_passives:
			return false
	return true

func get_missing_passives(owned_passives: Array) -> Array:
	## 还缺哪些被动（HUD 用来告诉玩家"差什么"）
	var missing: Array = []
	for item in required_passive_items:
		if item not in owned_passives:
			missing.append(item)
	return missing

func evolve() -> void:
	is_evolved = true

func get_evolved_damage(base_damage: float) -> float:
	return base_damage * damage_multiplier

func get_evolved_fire_rate(base_fire_rate: float) -> float:
	return base_fire_rate * fire_rate_multiplier

func get_evolved_size(base_size: float) -> float:
	return base_size * size_multiplier
