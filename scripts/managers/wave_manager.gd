extends Node
class_name WaveManager
## 波次管理器
## 控制敌人按波次生成，逐渐增加难度

# === 敌人场景 ===
var enemy_scenes: Dictionary = {
	"vampire": preload("res://scenes/enemies/vampire.tscn"),
	"werewolf": preload("res://scenes/enemies/werewolf.tscn"),
	"bat": preload("res://scenes/enemies/bat.tscn"),
	"zombie": preload("res://scenes/enemies/zombie.tscn"),
	"skeleton_archer": preload("res://scenes/enemies/skeleton_archer.tscn"),
	"exploder": preload("res://scenes/enemies/exploder.tscn"),
	"elite_vampire": preload("res://scenes/enemies/elite_vampire.tscn"),
	"summoner": preload("res://scenes/enemies/summoner.tscn"),
	"vampire_mage": preload("res://scenes/enemies/vampire_mage.tscn"),
	"gargoyle": preload("res://scenes/enemies/gargoyle.tscn"),
	"vampire_prince": preload("res://scenes/enemies/vampire_prince.tscn"),
}

# === 波次配置（从 GameConfig 读取） ===
@export var wave_duration: float = GameConfig.WAVE_DURATION
@export var base_spawn_interval: float = GameConfig.WAVE_BASE_SPAWN_INTERVAL
@export var min_spawn_interval: float = GameConfig.WAVE_MIN_SPAWN_INTERVAL
@export var spawn_distance: float = 500.0       # 生成距离（屏幕外）

# === 状态 ===
var current_wave: int = 0
var wave_timer: float = 0.0
var spawn_timer: float = 0.0
var is_active: bool = false
var enemies_alive: int = 0
var total_kills: int = 0
var player: Node2D = null

# === 地下城楼层 ===
var floor_index: int = 1
var enemy_pool: Array = []   # 当前层允许出现的敌人类型；空则回退到按波次解锁

# === 外部修正（深渊契约用） ===
## 每批敌人的数量倍率。用"理论总量对齐"而不是 ceil，长期平均才真的是 +20%
var spawn_count_mult: float = 1.0
## 掉落（银币/经验）倍率，生成时传给敌人
var loot_mult: float = 1.0
## 难度软因子：由外部 dps_provider 提供的实际 DPS 与等级期望值比出来
var _soft_hp_scale: float = 1.0
## 提供玩家当前 DPS 的回调（main 注入）。为空则不做软修正
var dps_provider: Callable = Callable()

## 战斗内增益的刷新计时
var _powerup_timer: float = 0.0
## 数量倍率的小数累积：按"应发总量 vs 实发总量"对齐。
## 早期写法是每次留小数余量再相加，浮点误差会累积（10 批本该 24 只，实测 23）。
## 对齐总量后误差不会跨批累积，且每批与理论值最多差 1 只。
var _spawn_want_total: float = 0.0
var _spawn_given_total: int = 0

var _current_scene: Node = null

# === 信号 ===
signal wave_started(wave_number: int)
signal wave_completed(wave_number: int)
signal enemy_killed(total_kills: int)

func _ready() -> void:
	add_to_group("wave_manager")

func start(player_node: Node2D) -> void:
	player = player_node
	_ensure_current_scene()
	is_active = true
	# 每间战斗房重新计时：开局先给 FIRST_DELAY 的缓冲，别让第一波就地上躺一个
	_powerup_timer = GameConfig.POWERUP_INTERVAL - GameConfig.POWERUP_FIRST_DELAY
	_start_next_wave()

func set_floor(index: int, pool: Array = []) -> void:
	## 切换当前楼层：影响敌人池与属性倍率
	floor_index = maxi(index, 1)
	enemy_pool = pool.duplicate()

func set_run_modifiers(count_mult: float = 1.0, loot: float = 1.0) -> void:
	## 深渊契约这类"本层生效"的修正从这里注入。
	## 数量倍率与掉落倍率分开传，是因为契约只改数量不改强度；
	## 以后要加"敌人更多但更脆"的契约，也只需要在这里多一个参数。
	# 倍率一旦变化就重置累计，避免上一层的余量串到下一层
	if not is_equal_approx(count_mult, spawn_count_mult) or not is_equal_approx(loot, loot_mult):
		_spawn_want_total = 0.0
		_spawn_given_total = 0
	spawn_count_mult = maxf(count_mult, 0.1)
	loot_mult = maxf(loot, 0.1)

func _ensure_current_scene() -> void:
	if _current_scene == null or not is_instance_valid(_current_scene):
		_current_scene = get_tree().current_scene

func _process(delta: float) -> void:
	if not is_active or player == null:
		return
	
	wave_timer += delta
	spawn_timer += delta
	
	# 生成敌人
	var current_interval := _get_spawn_interval()
	if spawn_timer >= current_interval:
		spawn_timer = 0.0
		_spawn_enemy()

	# 战斗内增益：按房间计时，不跟着波次走（波次结束到下一波之间也要有机会）
	if GameConfig.POWERUP_ENABLED:
		_powerup_timer += delta
		if _powerup_timer >= GameConfig.POWERUP_INTERVAL:
			_powerup_timer = 0.0
			_spawn_powerup()
	
	# 检查波次结束
	if wave_timer >= wave_duration:
		_end_current_wave()

func _start_next_wave() -> void:
	current_wave += 1
	wave_timer = 0.0
	spawn_timer = 0.0
	_update_soft_hp_scale()

	# 清除所有经验宝石
	_clear_xp_gems()
	
	wave_started.emit(current_wave)
	print("=== Wave %d 开始! ===" % current_wave)

func _update_soft_hp_scale() -> void:
	## 每波开始时重算一次"难度软因子"。放在波次边界而不是每次生成：
	## 同一波内所有敌人血量一致，玩家不会看到"同一种怪血量忽高忽低"。
	if not GameConfig.DPS_SOFT_ENABLED or dps_provider.is_null():
		_soft_hp_scale = 1.0
		return
	var actual: float = float(dps_provider.call())
	var level: int = 1
	if player != null and is_instance_valid(player) and "current_level" in player:
		level = int(player.current_level)
	var target: float = GameConfig.get_dps_soft_scale(actual, level)
	# 逐波靠拢，避免突然一波血条翻倍（突变比不准更伤体验）
	var prev: float = _soft_hp_scale
	_soft_hp_scale = lerpf(_soft_hp_scale, target, GameConfig.DPS_SOFT_LERP) if prev > 0.0 else target
	if not is_equal_approx(prev, _soft_hp_scale):
		print("⚖️ 难度软因子 %.2f（实际 DPS %.0f / 该等级期望 %.0f，Lv.%d）" % [
			_soft_hp_scale, actual, GameConfig.get_expected_dps(level), level])

func _clear_xp_gems() -> void:
	## 清除所有经验宝石
	var gems := get_tree().get_nodes_in_group("xp_gems")
	for gem in gems:
		if is_instance_valid(gem):
			gem.queue_free()
	if gems.size() > 0:
		print("💎 清除了 %d 个经验宝石" % gems.size())

func _end_current_wave() -> void:
	wave_completed.emit(current_wave)
	is_active = false
	print("=== Wave %d 完成! ===" % current_wave)

func _get_spawn_interval() -> float:
	# 每波生成速度加快
	var interval := base_spawn_interval - (current_wave - 1) * GameConfig.WAVE_SPAWN_INTERVAL_DECREASE
	return maxf(interval, min_spawn_interval)

func _get_enemies_per_spawn() -> int:
	# 每波同时生成更多敌人。
	# 初版是 mini(1 + wave/3, 5)，第 1 波每次只有 1 只，配合 2 秒间隔等于 0.5 只/秒，
	# 玩家随手就清空全场。现在第 1 波每次 2 只，第 12 波以后每次 5 只。
	var base := mini(2 + current_wave / 4, GameConfig.WAVE_MAX_SPAWN_COUNT)
	if is_equal_approx(spawn_count_mult, 1.0):
		return base
	# 总量对齐：倍率 1.2 时按 2→3→2→3… 发放，长期严格等于 ×1.2。
	# 不能用 ceil（那是 +50%），也不能用"每次留余量"（浮点误差会跨批累积）。
	_spawn_want_total += float(base) * spawn_count_mult
	var count: int = roundi(_spawn_want_total) - _spawn_given_total
	count = maxi(count, 1)
	_spawn_given_total += count
	return count

func _spawn_enemy() -> void:
	if player == null or not is_instance_valid(player):
		is_active = false
		return
	
	var count := _get_enemies_per_spawn()
	for i in range(count):
		var enemy_type := _pick_enemy_type()
		var enemy_scene: PackedScene = enemy_scenes[enemy_type]
		var enemy := enemy_scene.instantiate()
		# 传入当前波次与楼层用于数值缩放
		enemy.spawn_wave = current_wave
		enemy.floor_index = floor_index
		if "loot_mult" in enemy:
			enemy.loot_mult = loot_mult
		# 软因子走 hp_scale：enemy_base 在 _ready → _apply_wave_scaling 里乘它，
		# 必须在 add_child 之前设好（这里正好是 instantiate 之后）
		if "hp_scale" in enemy and not is_equal_approx(_soft_hp_scale, 1.0):
			enemy.hp_scale *= _soft_hp_scale
		_maybe_assign_affix(enemy)

		# 在屏幕外随机位置生成
		enemy.global_position = _get_spawn_position()
		
		# 连接死亡信号
		enemy.enemy_died.connect(_on_enemy_died)
		if player and player.has_method("_on_enemy_died"):
			enemy.enemy_died.connect(player._on_enemy_died)

		enemies_alive += 1
		_ensure_current_scene()
		if _current_scene:
			_current_scene.add_child(enemy)

func _spawn_powerup() -> void:
	## 在玩家四周随机方位刷一个临时增益。
	## 位置刻意放 200~360px（约半个屏幕）：太近等于白送，太远玩家懒得去。
	if player == null or not is_instance_valid(player):
		return
	_ensure_current_scene()
	if _current_scene == null:
		return

	var node := Node2D.new()
	node.set_script(preload("res://scripts/player/powerup.gd"))
	node.kind = String(GameConfig.POWERUP_KINDS.pick_random())
	node.lifetime = GameConfig.POWERUP_LIFETIME
	_current_scene.add_child(node)

	var angle: float = randf() * TAU
	var radius: float = randf_range(200.0, 360.0)
	node.global_position = player.global_position + Vector2(cos(angle), sin(angle)) * radius

func _maybe_assign_affix(enemy: Node) -> void:
	## 精英词缀：逐层提升概率。Boss 不参与（Boss 自己有三形态），
	## 已经自带词缀的（精英吸血鬼）也不再覆盖。
	if not GameConfig.ELITE_AFFIX_ENABLED:
		return
	if not ("elite_affix" in enemy):
		return
	if not String(enemy.elite_affix).is_empty():
		return
	if bool(enemy.get("suppress_affix")):
		return
	if randf() >= GameConfig.get_elite_affix_chance(floor_index):
		return
	enemy.elite_affix = EliteAffix.roll()

# 各敌人类型的生成权重（越大越常见）
const ENEMY_WEIGHTS: Dictionary = {
	"vampire": 10.0,
	"bat": 8.0,
	"zombie": 5.0,
	"skeleton_archer": 4.0,
	"werewolf": 3.0,
	"exploder": 2.0,
	"elite_vampire": 1.0,
	"summoner": 1.5,
	"vampire_mage": 1.2,
	"gargoyle": 0.8,
	"vampire_prince": 0.3,
}

func _get_wave_based_pool() -> Array:
	## 无楼层池时的回退逻辑：按波次逐步解锁敌人
	var pool: Array = ["vampire"]
	if current_wave >= 2:
		pool.append("bat")
	if current_wave >= 3:
		pool.append("zombie")
	if current_wave >= 4:
		pool.append("skeleton_archer")
	if current_wave >= 5:
		pool.append("werewolf")
	if current_wave >= 6:
		pool.append("exploder")
	if current_wave >= 8:
		pool.append("elite_vampire")
	if current_wave >= 10:
		pool.append("summoner")
	if current_wave >= 12:
		pool.append("vampire_mage")
	if current_wave >= 15:
		pool.append("gargoyle")
	if current_wave >= 18:
		pool.append("vampire_prince")
	return pool

func _pick_enemy_type() -> String:
	## 从当前楼层的敌人池中加权随机；池为空则回退到波次解锁表
	var candidates: Array = []
	var source: Array = enemy_pool if not enemy_pool.is_empty() else _get_wave_based_pool()
	for type in source:
		if enemy_scenes.has(type):
			candidates.append(type)
	if candidates.is_empty():
		return "vampire"

	var total_weight: float = 0.0
	for type in candidates:
		total_weight += float(ENEMY_WEIGHTS.get(type, 1.0))

	var roll := randf() * total_weight
	var cumulative: float = 0.0
	for type in candidates:
		cumulative += float(ENEMY_WEIGHTS.get(type, 1.0))
		if roll <= cumulative:
			return type

	return candidates[0]

func _get_spawn_position() -> Vector2:
	## 在玩家周围的圆圈外随机位置生成，但限制在房间范围内
	var angle := randf() * TAU
	var offset := Vector2(cos(angle), sin(angle)) * spawn_distance
	var spawn_pos := player.global_position + offset
	
	# 获取房间边界并限制生成位置
	var room := player.get_parent()
	if room and room.has_method("get_room_bounds"):
		var bounds: Rect2 = room.get_room_bounds()
		var margin := 50.0
		spawn_pos.x = clampf(spawn_pos.x, bounds.position.x + margin, bounds.end.x - margin)
		spawn_pos.y = clampf(spawn_pos.y, bounds.position.y + margin, bounds.end.y - margin)
	
	return spawn_pos

func _on_enemy_died(enemy: Node2D) -> void:
	enemies_alive -= 1
	total_kills += 1
	enemy_killed.emit(total_kills)

func record_external_kill(enemy_type: String = "bat") -> void:
	## 记录非波次生成的敌人击杀（如 Boss 召唤的小怪）
	total_kills += 1
	enemy_killed.emit(total_kills)
	var ach_mgr := get_node_or_null("/root/AchievementManager")
	if ach_mgr:
		ach_mgr.record_kill(enemy_type)

func stop() -> void:
	is_active = false
