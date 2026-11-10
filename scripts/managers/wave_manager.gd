extends Node
class_name WaveManager
## 波次管理器
## 控制敌人按波次生成，逐渐增加难度

## 房间解析的唯一入口（preload 而非 class_name：无头跑不刷新全局类缓存）
const RoomLookupScript = preload("res://scripts/core/room_lookup.gd")

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
@export var spawn_distance: float = 600.0       # 生成距离（屏幕外）

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
## 本层已清房间数（从 0 开始）。远程敌人按这个数逐间解禁，见 GameConfig.RANGED_UNLOCK_ROOM_BY_FLOOR
var floor_rooms_cleared: int = 0

# === 外部修正（深渊契约用） ===
## 每批敌人的数量倍率。用"理论总量对齐"而不是 ceil，长期平均才真的是 +20%
var spawn_count_mult: float = 1.0
## 掉落（银币/经验）倍率，生成时传给敌人
var loot_mult: float = 1.0
## 每日赏金这类“整局都在”的掉落倍率。契约的 set_run_modifiers 会改写 loot_mult，
## 所以赏金不能写进 loot_mult，否则一间休息房就把每日加成清掉。
var loot_bonus_mult: float = 1.0
## 迷雾房这一间的掉落倍率。换房时由 main 归 1。
var room_loot_mult: float = 1.0
## 镜像房：刷怪点绕房间中心左右翻转。
var mirror_spawns: bool = false
## 每日挑战的敌人种类/词缀随机流。为空时走全局 randf。
var combat_rng: RandomNumberGenerator = null
## 难度软因子：由外部 dps_provider 提供的实际 DPS 与等级期望值比出来
var _soft_hp_scale: float = 1.0
## 提供玩家当前 DPS 的回调（main 注入）。为空则不做软修正
var dps_provider: Callable = Callable()

## 战斗内增益的刷新计时
var _powerup_timer: float = 0.0
## 清场后等多久开始回收地上的宝石（秒）。
## 留一点余量是给玩家"自己走过去捡"的机会——立即吸走会让走位失去意义，
## 1.5 秒刚好看得见宝石落地、还没来得及决定要不要过去，它就自己飞过来了。
const CLEAR_MAGNET_DELAY: float = 1.5
var _cleared_grace: float = 0.0

## 同屏存活数的取样缓存。
## enemies_alive 这个计数器在换房时会对不上——残留敌人是被 main 直接
## queue_free 的，不走 _die，计数只增不减；一旦虚高到同屏上限就再也不刷怪。
## 所以"能不能再刷"一律以场上真实节点数为准，每 0.5 秒取一次样（不逐帧扫组）。
var _alive_probe_timer: float = 0.0
var _alive_probe_cache: int = 0

func _alive_enemies() -> int:
	_alive_probe_timer -= get_process_delta_time()
	if _alive_probe_timer <= 0.0:
		_alive_probe_timer = 0.5
		_alive_probe_cache = get_tree().get_nodes_in_group("enemies").size()
	return _alive_probe_cache

func _can_spawn_more() -> bool:
	## 同屏上限判定的唯一入口（测试也走这里断言，别在两处写两份条件）
	return _alive_enemies() < GameConfig.get_enemy_alive_cap(floor_index)
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
	# 换房时残留敌人是被 main 直接释放的，不走 _die，计数只会多不会少。
	# 这里清一次，避免上一间的余额带到下一间（同屏上限以真实节点数为准，这是第二道保险）。
	enemies_alive = 0
	_alive_probe_timer = 0.0
	_alive_probe_cache = 0
	_start_next_wave()

func set_floor(index: int, pool: Array = [], rooms_cleared_in_floor: int = 0) -> void:
	## 切换当前楼层：影响敌人池与属性倍率
	floor_index = maxi(index, 1)
	enemy_pool = pool.duplicate()
	floor_rooms_cleared = maxi(rooms_cleared_in_floor, 0)

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

func set_room_loot_mult(mult: float) -> void:
	room_loot_mult = maxf(mult, 0.1)

func effective_loot_mult() -> float:
	## 契约 × 每日赏金 × 本房间（迷雾）× 深渊。四段分开，谁被清掉都不连坐。
	return loot_mult * loot_bonus_mult * room_loot_mult * GameConfig.get_abyss_loot_mult()

func _roll01() -> float:
	if combat_rng != null:
		return combat_rng.randf()
	return randf()

func reflect_spawn(spawn_pos: Vector2, center: Vector2) -> Vector2:
	return Vector2(GameConfig.mirror_x(spawn_pos.x, center.x), spawn_pos.y)

func _ensure_current_scene() -> void:
	if _current_scene == null or not is_instance_valid(_current_scene):
		_current_scene = get_tree().current_scene

func _process(delta: float) -> void:
	if not is_active or player == null:
		return
	
	wave_timer += delta
	spawn_timer += delta
	
	# 生成敌人。同屏上限优先于刷新节奏：
	# 满了就不再补，掉一只才补一只（压力持续，但不会越堆越多）。
	var current_interval := _get_spawn_interval()
	if spawn_timer >= current_interval:
		spawn_timer = 0.0
		if _can_spawn_more():
			_spawn_enemy()

	# 战斗内增益：按房间计时，不跟着波次走（波次结束到下一波之间也要有机会）
	if GameConfig.POWERUP_ENABLED:
		_powerup_timer += delta
		if _powerup_timer >= GameConfig.POWERUP_INTERVAL:
			_powerup_timer = 0.0
			_spawn_powerup()

	# 清场即回收：怪已经打光、但波次计时还没走完时，先把地上的宝石吸回来。
	# 之前只在 30 秒到点那一刻才磁吸，导致"前 10 秒就清完场，剩下 20 秒
	# 宝石躺在地上没人敢去捡"——这正是"来不及捡经验"的体感来源之一。
	if _alive_enemies() <= 0 and get_tree().get_nodes_in_group("xp_gems").size() > 0:
		_cleared_grace += delta
		if _cleared_grace >= CLEAR_MAGNET_DELAY:
			_cleared_grace = 0.0
			magnetize_xp_gems()
	else:
		_cleared_grace = 0.0
	
	# 检查波次结束
	if wave_timer >= wave_duration:
		_end_current_wave()

func _start_next_wave() -> void:
	current_wave += 1
	wave_timer = 0.0
	spawn_timer = 0.0
	_cleared_grace = 0.0
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
	## 波次切换时清场：把还没捡的宝石**结算成经验**再回收，
	## 而不是 queue_free 掉。否则玩家打了一屋子怪，最后两秒掉的宝石
	## 会在换波那一瞬间白丢——这正是"经验点有时候捡不到"的另一半。
	settle_xp_gems()

## 把场上所有未拾取的经验宝石直接折算给玩家（供换波 / 换房调用）。
## 返回结算掉的 XP 总量，方便测试断言。
func settle_xp_gems() -> int:
	var gems := get_tree().get_nodes_in_group("xp_gems")
	var saved: int = 0
	for gem in gems:
		if not is_instance_valid(gem):
			continue
		if gem.has_method("auto_collect"):
			saved += int(gem.get("xp_value"))
			gem.call("auto_collect")
		else:
			gem.queue_free()
	if saved > 0:
		print("经验结算：自动收取 %d 点未拾取经验（换波/换房）" % saved)
	return saved

func magnetize_xp_gems() -> void:
	## 波次结束时把地上剩下的宝石吸到玩家身上。
	## 跟 settle_xp_gems() 的区别：这个不直接入账，宝石真的会飞过来——
	## 玩家打完一波能看见"战利品自己回来了"，而不是地上的东西凭空消失。
	for gem in get_tree().get_nodes_in_group("xp_gems"):
		if is_instance_valid(gem) and gem.has_method("magnetize"):
			gem.call("magnetize")

func _end_current_wave() -> void:
	wave_completed.emit(current_wave)
	is_active = false
	# 打完一波先把地上的经验收干净，否则玩家要么回头捡、要么白丢
	magnetize_xp_gems()
	print("=== Wave %d 完成! ===" % current_wave)

func _get_spawn_interval() -> float:
	# 每波生成速度加快
	var interval := base_spawn_interval - (current_wave - 1) * GameConfig.WAVE_SPAWN_INTERVAL_DECREASE
	interval = maxf(interval, min_spawn_interval)
	# 接近同屏上限时把补怪节奏放慢一倍。
	# 不限速的话，场上将满时每一批都在"填缝"，玩家刚清出的一条退路
	# 会被立刻补上，体感就是"没地方跑"。
	var cap: int = GameConfig.get_enemy_alive_cap(floor_index)
	if _alive_enemies() >= cap - GameConfig.ENEMY_ALIVE_CAP_SOFT_RANGE:
		interval *= 2.0
	return interval

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

func spawn_special_enemy(enemy_type: String, position: Vector2,
		affixes: Array = [], hp_mult: float = 1.0, extra_hp_scale: float = 1.0) -> Node:
	## 局内目标事件用：按指定类型与位置刷一只"剧情怪"（猎物 / 守卫）。
	## 与 _spawn_enemy 的区别：位置和数值都由调用方指定，不吃同屏上限
	## （上限的语义是"限制氛围怪"，不该拦住事件目标——猎物被上限卡住
	## 不出场，玩家对着倒计时干着急，这是最差的一种 bug）。
	if not enemy_scenes.has(enemy_type):
		return null
	_ensure_current_scene()
	if _current_scene == null:
		return null
	var enemy: Node = enemy_scenes[enemy_type].instantiate()
	enemy.spawn_wave = maxi(current_wave, 1)
	enemy.floor_index = floor_index
	if "loot_mult" in enemy:
		enemy.loot_mult = effective_loot_mult()
	if "hp_scale" in enemy:
		enemy.hp_scale *= hp_mult * extra_hp_scale
	if "suppress_affix" in enemy:
		enemy.suppress_affix = true
	# 多词缀装配：主词缀写 enemy.elite_affix（既有词缀管线与测试都认它），
	# 第二词缀写 secondary_affix。非法与重复 id 在这里就丢掉，
	# EnemyBase 只负责"合法且去重后"的结算，两边不会各丢一次。
	if "elite_affix" in enemy:
		enemy.elite_affix = ""
		if "secondary_affix" in enemy:
			enemy.secondary_affix = ""
		var installed: Array = []
		for id in affixes:
			# 规格是"双词缀"：第三及后续合法 id 不能再顶掉第二词缀
			if installed.size() >= 2:
				break
			var affix_id := String(id)
			if affix_id.is_empty() or affix_id in installed:
				continue
			if EliteAffix.get_data(affix_id).is_empty():
				continue
			if String(enemy.elite_affix).is_empty():
				enemy.elite_affix = affix_id
			elif "secondary_affix" in enemy:
				enemy.secondary_affix = affix_id
			installed.append(affix_id)
	enemy.global_position = position
	enemy.enemy_died.connect(_on_enemy_died)
	if player and player.has_method("_on_enemy_died"):
		enemy.enemy_died.connect(player._on_enemy_died)
	enemies_alive += 1
	_current_scene.add_child(enemy)
	return enemy

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
			# 深渊掉落加成乘在 effective_loot_mult 里，不在 enemy 里 round：
			# 掉落链有概率进位，直接 round base 值会复刻"1 银 ×1.1 永远 1"。
			enemy.loot_mult = effective_loot_mult()
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
	var pos: Vector2 = player.global_position + Vector2(cos(angle), sin(angle)) * radius
	# 增益不能刷进墙里（与 _get_spawn_position 同一套钳制）
	# 旧写法 player.get_parent() 拿到的是 Main 不是房间 → 钳制被跳过 → 增益掉在墙外
	pos = _clamp_into_room(pos, 60.0)
	node.global_position = pos

func _maybe_assign_affix(enemy: Node) -> void:
	## 精英词缀：逐层提升概率。Boss 不参与（Boss 自己有三形态），
	## 已经自带词缀的（精英吸血鬼）也不再覆盖。
	if not GameConfig.ELITE_AFFIX_ENABLED:
		return
	if not ("elite_affix" in enemy):
		return
	if not String(enemy.elite_affix).is_empty():
		apply_abyss_dual(enemy)
		return
	if bool(enemy.get("suppress_affix")):
		return
	if _roll01() >= GameConfig.get_elite_affix_chance(floor_index):
		return
	# 第 1 层只放「急速」：不加血量，只是把周围小怪催快，
	# 让"词缀"这个概念先以教学身份出场（试玩反馈：第一关就撞带盾肉墙）
	var pool: Array = GameConfig.get_elite_affix_pool(floor_index)
	var affix := EliteAffix.roll([], pool, combat_rng)
	if affix.is_empty():
		return
	enemy.elite_affix = affix
	apply_abyss_dual(enemy)

func apply_abyss_dual(enemy: Node) -> void:
	## 深渊 3 级起，已经是精英的敌人再带一条不同的词缀。
	## 第二词缀走完整词缀表，不走本层池：第 1 层池里只有急速，
	## 再从本层池抽一次，这条规则在第一层等于没写。
	if not GameConfig.abyss_forces_dual_affix():
		return
	if enemy == null or not ("secondary_affix" in enemy):
		return
	if bool(enemy.get("suppress_affix")):
		return
	if not String(enemy.secondary_affix).is_empty():
		return
	var primary := String(enemy.get("elite_affix"))
	if primary.is_empty() or EliteAffix.get_data(primary).is_empty():
		return
	var second := EliteAffix.roll([primary], EliteAffix.all_ids(), combat_rng)
	if second.is_empty() or second == primary:
		return
	enemy.secondary_affix = second

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
	# 远程敌人按"本层第几间房"逐间解禁：第 1 层前几间房纯近战，
	# 避免开局就被三四条弹道追着跑（见 GameConfig 里那一段说明）
	var allow_ranged: bool = GameConfig.is_ranged_allowed(floor_index, floor_rooms_cleared)
	for type in source:
		if not enemy_scenes.has(type):
			continue
		if not allow_ranged and type in GameConfig.RANGED_ENEMY_TYPES:
			continue
		candidates.append(type)
	if candidates.is_empty():
		return "vampire"

	var total_weight: float = 0.0
	for type in candidates:
		total_weight += float(ENEMY_WEIGHTS.get(type, 1.0))

	var roll := _roll01() * total_weight
	var cumulative: float = 0.0
	for type in candidates:
		cumulative += float(ENEMY_WEIGHTS.get(type, 1.0))
		if roll <= cumulative:
			return type

	return candidates[0]

func _find_room_node() -> Node:
	## 找当前房间节点（带 get_room_bounds 的那个）。
	##
	## 历史坑（"怪刷在地图边界外"的根因）：
	## player 的父节点是 Main（主场景），不是房间。旧代码用
	## `var room := player.get_parent()` 当房间，于是 `has_method("get_room_bounds")`
	## 恒为 false → 整段边界钳制被静默跳过 → 刷怪点完全不受房间约束。
	##
	## 统一走 RoomLookup（scripts/core/room_lookup.gd），全工程只有这一个入口。
	return RoomLookupScript.find_room(player)

func _room_bounds_global() -> Rect2:
	## 房间内部的全局矩形（已扣掉墙厚）。找不到房间时返回空矩形。
	return RoomLookupScript.bounds_global(_find_room_node())

func _clamp_into_room(pos: Vector2, margin: float) -> Vector2:
	## 把全局坐标钳回房间内部。找不到房间时原样返回（不猜边界）。
	return RoomLookupScript.clamp_into_bounds(pos, margin, _room_bounds_global())

func _get_spawn_position() -> Vector2:
	## 在玩家周围的圆圈外随机位置生成，但限制在房间范围内。
	##
	## 边界钳制只保证"在房间里"，不保证"不在柱子里"：柱子/道具生成后，
	## 圆环上的落点可能正好落在它们内部，怪会卡在障碍里出不来。
	## 所以钳制之后再做一次**有界**空旷重采样（见 _escape_into_clear_space）：
	## 先重摇几轮角度，还不行就沿落点四周找最近的空地。
	## 只改落点，不动碰撞规则、不动刷怪节奏。
	var angle := randf() * TAU
	var spawn_pos := _spawn_from_angle(angle, 0.0)
	for attempt in 3:
		if _is_spawn_point_clear(spawn_pos):
			return spawn_pos
		# 重摇角度，顺便把半径抖一点，避免总是同一个圆周
		angle += randf_range(0.6, 2.1)
		spawn_pos = _spawn_from_angle(angle, attempt)
	return _escape_into_clear_space(spawn_pos)

func _spawn_from_angle(angle: float, attempt: int) -> Vector2:
	## 单次落点计算：玩家周围 spawn_distance 的圆上，钳进房间，镜像房再反射一次。
	## attempt 只用来做轻微半径抖动，不改变"屏幕外刷怪"这个基本语义。
	var radius: float = spawn_distance * (1.0 + 0.08 * float(attempt))
	var offset := Vector2(cos(angle), sin(angle)) * radius
	var spawn_pos := player.global_position + offset

	# 90 = 墙厚 32 + 怪碰撞半径 + 视觉余量：贴着钳制线刷出的怪看起来在墙上
	var margin := 90.0
	spawn_pos = _clamp_into_room(spawn_pos, margin)

	# 镜像房：反射后再钳一次（反射会把点甩到另一侧）
	if mirror_spawns:
		var room := _find_room_node()
		if room != null and room is Node2D and room.has_method("get_center"):
			var center_global: Vector2 = (room as Node2D).to_global(room.get_center())
			spawn_pos = reflect_spawn(spawn_pos, center_global)
			spawn_pos = _clamp_into_room(spawn_pos, margin)

	return spawn_pos

func _is_spawn_point_clear(pos: Vector2) -> bool:
	## 落点四周有没有墙/柱子/道具。
	## 半径用怪的碰撞半径（约 14px）+ 一点余量：只要怪的圆心不贴在障碍上就够了。
	## 房间节点缺失时返回 true（不猜，保持旧行为而不是随机吞掉刷怪）。
	var room := _find_room_node()
	if room == null or not room.has_method("is_position_clear_at"):
		return true
	return bool(room.is_position_clear_at(pos, 22.0))

func _escape_into_clear_space(pos: Vector2) -> Vector2:
	## 有界逃逸：以原落点为圆心，由近及远扫几圈同心圆，取第一个空地。
	## 找不到就原样返回——宁可怪刷得难看一点，也不能因为房间被塞满就完全不刷怪。
	const RING_STEPS: int = 12
	const RADII: Array[float] = [40.0, 72.0, 110.0, 150.0, 200.0]
	for radius in RADII:
		for i in RING_STEPS:
			var a: float = TAU * float(i) / float(RING_STEPS)
			var candidate := pos + Vector2(cos(a), sin(a)) * radius
			candidate = _clamp_into_room(candidate, 90.0)
			if _is_spawn_point_clear(candidate):
				return candidate
	return pos

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
