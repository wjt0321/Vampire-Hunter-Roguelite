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
	_start_next_wave()

func set_floor(index: int, pool: Array = []) -> void:
	## 切换当前楼层：影响敌人池与属性倍率
	floor_index = maxi(index, 1)
	enemy_pool = pool.duplicate()

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
	
	# 检查波次结束
	if wave_timer >= wave_duration:
		_end_current_wave()

func _start_next_wave() -> void:
	current_wave += 1
	wave_timer = 0.0
	spawn_timer = 0.0
	
	# 清除所有经验宝石
	_clear_xp_gems()
	
	wave_started.emit(current_wave)
	print("=== Wave %d 开始! ===" % current_wave)

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
	return mini(2 + current_wave / 4, GameConfig.WAVE_MAX_SPAWN_COUNT)

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
