extends SceneTree
## 战斗规则回归测试（2026-11-10 玩法迭代 Task 2）
## 用法: godot --headless --path . --script res://tools/combat_rules_test.gd
##
## 覆盖设计文档 2026-11-10-gameplay-iteration-design.md 第 1~4 条：
##   ① 碰撞层/掩码分组：墙/柱/道具统一物理层 5，玩家/敌人/双方弹丸与墙碰撞
##   ② 接触中的敌人按既有无敌帧持续结算伤害
##   ③ 玩家受击使用独立击退速度并衰减
##   ④ shoot_speed_multiplier 影响真实冷却
##   ⑤ 非 auto_aim 武器需按住 shoot 才开火，auto_aim 保持自动
##   ⑥ 普通传送门落在远离玩家且无障碍的安全点
##   ⑦ 射速倍率作用在真实开火节奏上（不是只读配置值）
##   ⑧ 传送门落点四周留出间隙，房间塞满时兜底也不卡进障碍
##   ⑨ 敌方弹丸与玩家子弹相撞：敌方弹丸销毁、玩家子弹存活
##   ⑩ shoot 键位同时支持空格与鼠标左键
##   ⑪ 玩家死亡后不再结算伤害；暂停期间不结算接触伤害
##   ⑫ DPS 估算跟随射速倍率

const PLAYER_LAYER: int = 1    # 2d_physics/layer_1 = "player"
const ENEMY_LAYER: int = 2     # 2d_physics/layer_2 = "enemies"
const BULLET_LAYER: int = 4    # 2d_physics/layer_3 = "bullets"
const WALL_LAYER: int = 16     # 2d_physics/layer_5 = "walls"
const ENEMY_BULLET_LAYER: int = 32  # 2d_physics/layer_6 = "enemy_bullets"
## 传送门门体半径 24px，再留 16px 安全边距
const PORTAL_CLEAR_RADIUS: float = 40.0

var _fail: int = 0
var _pass: int = 0
## 子弹生成计数（用 child_entered_tree 抓，子弹被回收也不会漏计）
var _shots_fired: int = 0
## 射速节奏对照：两个武器管理器各自的出弹数
var _shots_slow: int = 0
var _shots_fast: int = 0
## 玩家掉血事件计数
var _hp_events: int = 0
var _hp_prev: float = -1.0
## 玩家血量变化次数（含数值不变的广播）
var _hp_total: int = 0
## 玩家死亡次数
var _deaths: int = 0
## 本测试建出来的场景根节点，收尾时统一释放
var _roots: Array = []

func _initialize() -> void:
	_run()

func _check(cond: bool, msg: String) -> void:
	if cond:
		_pass += 1
		print("  ✅ %s" % msg)
	else:
		_fail += 1
		print("  ❌ %s" % msg)

func _finish() -> void:
	print("")
	print("通过 %d / 失败 %d" % [_pass, _fail])
	if _fail == 0:
		print("✅ 全部通过")
	else:
		print("❌ 失败 %d 项" % _fail)
	quit(0 if _fail == 0 else 1)

func _run() -> void:
	await process_frame
	print("\n====== 战斗规则回归测试 ======")
	await _test_collision_layers()
	await _test_contact_damage()
	await _test_player_knockback()
	await _test_shoot_speed_multiplier()
	await _test_manual_fire()
	await _test_portal_placement()
	await _test_fire_cadence()
	await _test_enemy_projectile_vs_bullet()
	await _test_shoot_input()
	await _test_death_and_pause_guard()
	await _test_dps_estimate()
	await process_frame
	# 等最后一声受击音效播完：音效还在播放时退出会报"资源仍在使用"
	await create_timer(0.8).timeout
	_cleanup()
	await process_frame
	_finish()

# ==================== 工具 ====================

func _make_scene_root() -> Node2D:
	var node := Node2D.new()
	root.add_child(node)
	current_scene = node
	_roots.append(node)
	return node

func _cleanup() -> void:
	## 收尾：把本测试建出来的场景节点全部释放，避免退出时报泄漏
	for node in _roots:
		if is_instance_valid(node):
			node.free()
	_roots.clear()
	_clear_object_pool()
	_stop_all_sfx()

func _stop_all_sfx() -> void:
	## 停下音效并清掉 stream 引用。
	## 受击音效会在 AudioManager 的播放池里一直挂着音频资源，
	## 进程退出时就会报"资源仍在使用"。
	var mgr := root.get_node_or_null("AudioManager")
	if mgr == null:
		return
	var players = mgr.get("_sfx_players")
	if players == null:
		return
	for p in players:
		if p is AudioStreamPlayer:
			(p as AudioStreamPlayer).stop()
			(p as AudioStreamPlayer).stream = null

func _clear_object_pool() -> void:
	## 对象池里还存着这一轮射出去的子弹，孤儿节点会在退出时报泄漏
	var pool := root.get_node_or_null("ObjectPool")
	if pool != null and pool.has_method("clear_all"):
		pool.clear_all()

func _clear_roots() -> void:
	## 分段之间清场：残留的墙/玩家会串到下一段（例如玩家出生在旧墙里会被推走）
	current_scene = null
	for node in _roots:
		if is_instance_valid(node):
			node.free()
	_roots.clear()
	_clear_object_pool()

func _make_room(width: float, height: float) -> Node2D:
	var room := Node2D.new()
	room.set_script(load("res://scripts/map/game_room.gd"))
	room.room_width = width
	room.room_height = height
	room.name = "GameRoom"
	return room

func _make_wall_body(pos: Vector2, size: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = WALL_LAYER
	body.collision_mask = 0
	body.add_to_group("walls")
	body.position = pos
	var shape_node := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape_node.shape = rect
	body.add_child(shape_node)
	return body

func _is_blocked_at(world_pos: Vector2, radius: float) -> bool:
	## 独立物理查询：这个点周围有没有墙/柱子/道具（只看物理层 5）。
	## 刻意不调用被测实现自己的判定函数：否则"落点安全"就是自己证明自己。
	var space := root.get_world_2d().direct_space_state
	if space == null:
		return false
	var r: float = maxf(radius, 1.0)
	var params := PhysicsShapeQueryParameters2D.new()
	var circle := CircleShape2D.new()
	circle.radius = r
	params.shape = circle
	params.transform = Transform2D(0.0, world_pos)
	params.collision_mask = WALL_LAYER
	params.collide_with_areas = false
	params.collide_with_bodies = true
	return not space.intersect_shape(params, 1).is_empty()

func _instantiate(scene_path: String) -> Node:
	var packed: PackedScene = load(scene_path)
	if packed == null:
		return null
	return packed.instantiate()

# ==================== ① 碰撞层 / 掩码分组 ====================

func _test_collision_layers() -> void:
	print("\n=== ① 碰撞层/掩码分组 ===")

	# --- 1.1 墙、柱、道具统一用物理层 5 ---
	var scene_root := _make_scene_root()
	var room := _make_room(1280.0, 768.0)
	scene_root.add_child(room)
	room.add_pillars(3)
	room.add_props(2)
	await process_frame

	var wall_bodies: Array = []
	for child in room.get_children():
		if child is StaticBody2D and child.is_in_group("walls"):
			wall_bodies.append(child)
	_check(wall_bodies.size() >= 4,
		"房间里生成 %d 个墙体/柱子/道具碰撞体" % wall_bodies.size())

	var wrong_layer: int = 0
	var layers_seen: Array = []
	for body in wall_bodies:
		var layer: int = body.collision_layer
		if layer != WALL_LAYER:
			wrong_layer += 1
		if not layers_seen.has(layer):
			layers_seen.append(layer)
	_check(wrong_layer == 0,
		"墙/柱/道具统一使用物理层 5（越界 %d 个，用到的层：%s）" % [wrong_layer, str(layers_seen)])

	# --- 1.2 各角色按职责与墙碰撞，且不丢原有职责 ---
	var player := _instantiate("res://scenes/player/player.tscn")
	_check(player != null, "玩家场景可加载")
	if player:
		_check((player.collision_mask & WALL_LAYER) != 0,
			"玩家掩码包含墙层（当前 %d）" % player.collision_mask)
		_check((player.collision_mask & ENEMY_LAYER) != 0,
			"玩家仍然撞敌人（当前 %d）" % player.collision_mask)
		player.free()

	var enemy := _instantiate("res://scenes/enemies/bat.tscn")
	_check(enemy != null, "敌人场景可加载")
	if enemy:
		_check((enemy.collision_mask & WALL_LAYER) != 0,
			"敌人掩码包含墙层（当前 %d）" % enemy.collision_mask)
		_check((enemy.collision_mask & PLAYER_LAYER) != 0,
			"敌人仍然撞玩家（当前 %d）" % enemy.collision_mask)
		enemy.free()

	var bullet := _instantiate("res://scenes/player/bullet.tscn")
	_check(bullet != null, "玩家子弹场景可加载")
	if bullet:
		_check((bullet.collision_mask & WALL_LAYER) != 0,
			"玩家子弹掩码包含墙层（当前 %d）" % bullet.collision_mask)
		_check((bullet.collision_mask & ENEMY_LAYER) != 0,
			"玩家子弹仍然打敌人（当前 %d）" % bullet.collision_mask)
		bullet.free()

	var eproj := _instantiate("res://scenes/enemies/enemy_projectile.tscn")
	_check(eproj != null, "敌方弹丸场景可加载")
	if eproj:
		_check((eproj.collision_mask & WALL_LAYER) != 0,
			"敌方弹丸掩码包含墙层（当前 %d）" % eproj.collision_mask)
		_check((eproj.collision_mask & PLAYER_LAYER) != 0,
			"敌方弹丸仍然打玩家（当前 %d）" % eproj.collision_mask)
		eproj.free()

	# --- 1.3 功能：墙真的挡得住玩家 ---
	var wall_scene := _make_scene_root()
	var wall := _make_wall_body(Vector2(400, 300), Vector2(64, 600))
	wall_scene.add_child(wall)
	var p2 := _instantiate("res://scenes/player/player.tscn")
	p2.position = Vector2(200, 300)
	wall_scene.add_child(p2)
	await physics_frame
	await physics_frame
	Input.action_press("move_right")
	await create_timer(1.0).timeout
	Input.action_release("move_right")
	_check(p2.global_position.x < 368.0,
		"墙挡住了玩家（x=%.0f，墙左边缘 368）" % p2.global_position.x)
	p2.queue_free()

	# --- 1.4 功能：墙真的挡得住敌人 ---
	var enemy_scene := _make_scene_root()
	var wall2 := _make_wall_body(Vector2(400, 300), Vector2(64, 600))
	enemy_scene.add_child(wall2)
	var p3 := _instantiate("res://scenes/player/player.tscn")
	p3.position = Vector2(700, 300)
	enemy_scene.add_child(p3)
	var bat := _instantiate("res://scenes/enemies/bat.tscn")
	bat.position = Vector2(250, 300)
	enemy_scene.add_child(bat)
	await physics_frame
	await physics_frame
	await create_timer(1.5).timeout
	_check(bat.global_position.x < 368.0,
		"墙挡住了敌人（x=%.0f，墙左边缘 368）" % bat.global_position.x)

	# 清理：后面的用例会按 "player" 组找玩家，残留节点会串场
	_clear_roots()
	await process_frame

# ==================== ② 持续接触伤害 ====================

func _test_contact_damage() -> void:
	print("\n=== ② 持续接触伤害 ===")
	var scene_root := _make_scene_root()
	var player := _instantiate("res://scenes/player/player.tscn")
	player.position = Vector2(300, 300)
	scene_root.add_child(player)
	await process_frame

	# 记录掉血次数（按信号计数，不受伤害倍率影响）
	_hp_events = 0
	_hp_prev = player.current_hp
	player.hp_changed.connect(func(cur: float, _mx: float) -> void:
		if cur < _hp_prev:
			_hp_events += 1
		_hp_prev = cur
	)

	var bat := _instantiate("res://scenes/enemies/bat.tscn")
	bat.position = Vector2(300, 300)
	# 关掉实体碰撞、只保留接触感应区：让两者稳定重叠，
	# 这样测到的是"持续结算"而不是"被推开"（击退另有专项测试）
	bat.collision_layer = 0
	bat.collision_mask = 0
	scene_root.add_child(bat)
	await process_frame
	await physics_frame

	var dmg: float = bat.contact_damage
	_check(dmg > 0.0, "蝙蝠接触伤害 %.1f" % dmg)
	# 玩家物理冻结：避免受击击退把两者分开，影响的是节奏而不是结算逻辑
	player.set_physics_process(false)

	await create_timer(1.3).timeout
	_check(_hp_events >= 2,
		"贴住 1.3 秒结算了 %d 次接触伤害（期望 ≥2 次，单次 %.1f）" % [_hp_events, dmg])
	_check(_hp_events <= 4,
		"接触伤害按无敌帧节奏结算，没有一帧多次（%d 次）" % _hp_events)
	bat.queue_free()
	player.queue_free()
	_clear_roots()
	await process_frame

# ==================== ③ 玩家独立击退 ====================

func _test_player_knockback() -> void:
	print("\n=== ③ 玩家独立击退 ===")
	var scene_root := _make_scene_root()
	var player := _instantiate("res://scenes/player/player.tscn")
	player.position = Vector2(400, 400)
	scene_root.add_child(player)
	await physics_frame
	await physics_frame

	var has_kb: bool = "knockback_velocity" in player
	_check(has_kb, "玩家有独立的击退速度字段（不与移动速度混用）")

	var x0: float = player.global_position.x
	player.take_damage(5.0, Vector2(300, 400))  # 伤害来源在左边 → 应该把玩家推向右边
	await create_timer(0.2).timeout
	var x1: float = player.global_position.x
	_check(x1 > x0 + 5.0,
		"受击后玩家真的被推开（x %.1f → %.1f）" % [x0, x1])

	if has_kb:
		var kb: Vector2 = player.get("knockback_velocity")
		_check(kb.length() > 0.0, "击退用的是独立速度（%.0f）" % kb.length())

	await create_timer(1.5).timeout
	if has_kb:
		var kb2: Vector2 = player.get("knockback_velocity")
		_check(kb2.length() < 1.0, "击退速度会衰减到 0（当前 %.1f）" % kb2.length())
	var x2: float = player.global_position.x
	_check(absf(x2 - x1) < 12.0,
		"击退结束后玩家停下来（x %.1f → %.1f）" % [x1, x2])
	_clear_roots()
	await process_frame

# ==================== ④ 射速倍率真实生效 ====================

func _test_shoot_speed_multiplier() -> void:
	print("\n=== ④ 射速倍率真实生效 ===")
	var scene_root := _make_scene_root()
	var wm_script = load("res://scripts/weapons/weapon_manager.gd")

	# 基准：倍率 1.0
	var p1 := _instantiate("res://scenes/player/player.tscn")
	p1.position = Vector2(640, 360)
	scene_root.add_child(p1)
	var wm1 = wm_script.new()
	scene_root.add_child(wm1)
	p1.shoot_speed_multiplier = 1.0
	wm1.setup(p1, "pistol")
	var t1: float = wm1.shoot_timers["pistol"].wait_time

	# 倍率 2.0
	var p2 := _instantiate("res://scenes/player/player.tscn")
	p2.position = Vector2(300, 360)
	scene_root.add_child(p2)
	var wm2 = wm_script.new()
	scene_root.add_child(wm2)
	p2.shoot_speed_multiplier = 2.0
	wm2.setup(p2, "pistol")
	var t2: float = wm2.shoot_timers["pistol"].wait_time

	_check(t1 > 0.0, "手枪基础冷却 %.3f 秒" % t1)
	_check(is_equal_approx(t2, t1 * 0.5),
		"射速倍率 ×2 → 冷却 %.3f 秒（基准 %.3f，应为一半）" % [t2, t1])
	_check(wm2.has_method("get_fire_interval"),
		"武器管理器提供按玩家射速倍率计算冷却的接口")

	# 升级路径：+20% 射速（UPGRADE_SHOOT_SPEED_MULT）必须落到真实冷却上
	if wm2.has_method("get_fire_interval"):
		var w = wm2.weapons[0]
		var before: float = wm2.get_fire_interval(w)
		p2.apply_upgrade("shoot_speed")
		var after: float = wm2.get_fire_interval(w)
		_check(after < before,
			"拿射速升级后冷却变短（%.3f → %.3f）" % [before, after])
	_clear_roots()
	await process_frame

# ==================== ⑤ 手动开火 / 自动瞄准 ====================

func _test_manual_fire() -> void:
	print("\n=== ⑤ 手动开火 / 自动瞄准 ===")
	var scene_root := _make_scene_root()
	var wm_script = load("res://scripts/weapons/weapon_manager.gd")

	# 数子弹：用 child_entered_tree 抓，子弹被对象池回收也不会漏计
	_shots_fired = 0
	scene_root.child_entered_tree.connect(func(n: Node) -> void:
		if n.has_method("get_damage"):
			_shots_fired += 1
	)

	# --- 5.1 非 auto_aim（手枪）：不按 shoot 就不开火 ---
	var p1 := _instantiate("res://scenes/player/player.tscn")
	p1.position = Vector2(640, 360)
	scene_root.add_child(p1)
	var wm1 = wm_script.new()
	scene_root.add_child(wm1)
	wm1.setup(p1, "pistol")
	await create_timer(1.0).timeout
	_check(_shots_fired == 0,
		"没按住 shoot 时手枪不开火（实际 %d 发）" % _shots_fired)

	Input.action_press("shoot")
	await create_timer(0.6).timeout
	Input.action_release("shoot")
	var shots_held: int = _shots_fired
	_check(shots_held > 0, "按住 shoot 后手枪开火（%d 发）" % shots_held)
	_check(wm1.shoot_timers["pistol"].wait_time > 0.0,
		"开火后计时器按真实冷却 %.3f 秒计时" % wm1.shoot_timers["pistol"].wait_time)

	# --- 5.2 auto_aim（魔法书）：不按 shoot 也保持自动开火 ---
	var p2 := _instantiate("res://scenes/player/player.tscn")
	p2.position = Vector2(300, 300)
	scene_root.add_child(p2)
	var wm2 = wm_script.new()
	scene_root.add_child(wm2)
	wm2.setup(p2, "magic_book")
	var bat := _instantiate("res://scenes/enemies/bat.tscn")
	bat.position = Vector2(800, 300)
	scene_root.add_child(bat)
	await process_frame
	bat.set_physics_process(false)  # 别让它乱动，保持靶子位置稳定
	_shots_fired = 0
	await create_timer(1.2).timeout
	_check(_shots_fired > 0,
		"自动瞄准武器不按 shoot 也自动开火（%d 发）" % _shots_fired)
	_clear_roots()
	await process_frame

# ==================== ⑧ 普通传送门安全落点 ====================

func _test_portal_placement() -> void:
	print("\n=== ⑧ 传送门落点：间隙与兜底 ===")
	var scene_root := _make_scene_root()
	var room := _make_room(1280.0, 768.0)
	scene_root.add_child(room)
	room.add_pillars(4)
	room.add_props(2)
	# 一块位置固定的墙，用来验证"间隙判定"契约
	scene_root.add_child(_make_wall_body(Vector2(200, 200), Vector2(100, 100)))
	var player := _instantiate("res://scenes/player/player.tscn")
	player.position = Vector2(640, 384)  # 站在房间正中
	scene_root.add_child(player)
	await physics_frame
	await physics_frame

	room.spawn_portal()
	var portal := room.get_node_or_null("Portal")
	_check(portal != null, "普通传送门已生成")
	if portal != null:
		var dist: float = portal.global_position.distance_to(player.global_position)
		_check(dist >= 300.0,
			"传送门离玩家 %.0f 像素（期望 ≥300，避免清波后原地换房）" % dist)
		# 落点验证走独立物理查询，不依赖被测实现自己的判定函数
		_check(not _is_blocked_at(portal.global_position, PORTAL_CLEAR_RADIUS),
			"传送门四周留出 %d 像素间隙（独立物理查询验证）" % int(PORTAL_CLEAR_RADIUS))
		var local_pos: Vector2 = room.to_local(portal.global_position)
		var bounds: Rect2 = room.get_room_bounds()
		_check(bounds.grow(-40.0).has_point(local_pos),
			"传送门落在房间内部（%.0f, %.0f）" % [local_pos.x, local_pos.y])

	# 等传送门的协程收尾（它延迟 0.5 秒才启用碰撞），否则房间被释放时会漏对象
	await create_timer(0.6).timeout
	_clear_roots()
	await process_frame

	# --- ⑧a 间隙判定契约：40px 半径（确定性场景，不吃随机柱子/道具） ---
	# 之前这两条断言直接跑在上面那间随机房间上：add_pillars/add_props 用
	# pick_random 摆件，(500,200) 偶尔正好压在柱子上，"空旷"那条就偶发假红。
	# 契约本身和随机摆放无关，所以单独搭一间只有固定墙的干净房间：
	# 用"贴墙 10px 必判不安全、45px 必判空旷"把半径夹在 (10, 45) 之间，
	# 比原来只说"250px 处空旷"更强——原来没有上界，半径写成 200 也能过。
	var clear_root := _make_scene_root()
	var clear_room := _make_room(1280.0, 768.0)
	clear_root.add_child(clear_room)
	# 固定墙：局部 (200,200)、100×100 → 占据 x∈[150,250], y∈[150,250]
	clear_root.add_child(_make_wall_body(Vector2(200, 200), Vector2(100, 100)))
	await physics_frame
	await physics_frame
	_check(not clear_room.is_position_clear(Vector2(260, 200)),
		"落点判定考虑门体半径（离墙 10px 判为不安全）")
	_check(clear_room.is_position_clear(Vector2(295, 200)),
		"落点判定：离墙 45px 判为空旷（半径不超过 45）")
	# 半径必须是真 40：独立物理查询复核同一条边界，防止判定函数被写成常数
	_check(_is_blocked_at(Vector2(260, 200), PORTAL_CLEAR_RADIUS),
		"独立查询复核：离墙 10px 在 40px 半径内（被挡）")
	_check(not _is_blocked_at(Vector2(295, 200), PORTAL_CLEAR_RADIUS),
		"独立查询复核：离墙 45px 在 40px 半径外（空旷）")
	_clear_roots()
	await process_frame

	# --- ⑧b 兜底顺序：房间几乎被墙填满时，落点也不能卡进障碍 ---
	var dense_root := _make_scene_root()
	var dense := _make_room(1280.0, 768.0)
	dense_root.add_child(dense)
	# 大块墙把房间内部盖满：只留四周一圈窄边和中心一个小坑
	dense.add_child(_make_wall_body(Vector2(640, 228), Vector2(1088, 264)))
	dense.add_child(_make_wall_body(Vector2(640, 540), Vector2(1088, 264)))
	dense.add_child(_make_wall_body(Vector2(356, 384), Vector2(520, 48)))
	dense.add_child(_make_wall_body(Vector2(924, 384), Vector2(520, 48)))
	await physics_frame
	await physics_frame

	seed(20261110)  # 固定随机序列，让"随机采样全军覆没"这条分支可复现
	var fallback_pos: Vector2 = dense.get_safe_portal_position()
	var fb_dist: float = fallback_pos.distance_to(dense.to_global(dense.get_center()))
	_check(not _is_blocked_at(fallback_pos, 0.0),
		"兜底落点不在障碍里（独立物理查询验证）")
	_check(fb_dist >= 100.0,
		"兜底落点离玩家参考点 %.0f 像素（期望 ≥100）" % fb_dist)
	_clear_roots()
	await process_frame

# ==================== ⑦ 射速真实节奏 ====================

func _test_fire_cadence() -> void:
	print("\n=== ⑦ 射速真实节奏（计时器节拍） ===")
	var wm_script = load("res://scripts/weapons/weapon_manager.gd")

	# 两个武器管理器并跑同一个窗口：一个倍率 1.0、一个倍率 2.0。
	# 各自挂在不同场景根上，子弹分别落在两个根里，
	# 这样能分别数出"真的开了几枪"，而不是只读 wait_time 配置值。
	var slow_root := Node2D.new()
	slow_root.name = "SlowRoot"
	root.add_child(slow_root)
	_roots.append(slow_root)
	var fast_root := Node2D.new()
	fast_root.name = "FastRoot"
	root.add_child(fast_root)
	_roots.append(fast_root)

	_shots_slow = 0
	_shots_fast = 0
	slow_root.child_entered_tree.connect(func(n: Node) -> void:
		if n.has_method("get_damage"):
			_shots_slow += 1
	)
	fast_root.child_entered_tree.connect(func(n: Node) -> void:
		if n.has_method("get_damage"):
			_shots_fast += 1
	)

	current_scene = slow_root
	var p_slow := _instantiate("res://scenes/player/player.tscn")
	p_slow.position = Vector2(640, 360)
	slow_root.add_child(p_slow)
	var wm_slow = wm_script.new()
	slow_root.add_child(wm_slow)
	p_slow.shoot_speed_multiplier = 1.0
	wm_slow.setup(p_slow, "pistol")

	current_scene = fast_root
	var p_fast := _instantiate("res://scenes/player/player.tscn")
	p_fast.position = Vector2(320, 180)
	fast_root.add_child(p_fast)
	var wm_fast = wm_script.new()
	fast_root.add_child(wm_fast)
	p_fast.shoot_speed_multiplier = 2.0
	wm_fast.setup(p_fast, "pistol")

	await process_frame
	await physics_frame

	var slow_timer: Timer = wm_slow.shoot_timers["pistol"]
	var fast_timer: Timer = wm_fast.shoot_timers["pistol"]
	_check(fast_timer.wait_time < slow_timer.wait_time,
		"倍率 ×2 的武器计时器冷却更短（%.3f < %.3f 秒）"
		% [fast_timer.wait_time, slow_timer.wait_time])

	# 采样窗口：逐帧记录计时器剩余时间，确认开火节奏真的按倍率走。
	# 窗口用**真实时间**计：按物理帧数计的话，机器越快、主循环帧率越高，
	# 帧数上限会先把窗口截断，1.2 秒的窗口被砍成 0.3 秒，
	# 两组武器都没来得及开几枪 → 假红。
	Input.action_press("shoot")
	var deadline: int = Time.get_ticks_msec() + 1200
	var frames: int = 0
	var max_time_left: float = 0.0
	while Time.get_ticks_msec() < deadline and frames < 100000:
		await process_frame
		frames += 1
		max_time_left = maxf(max_time_left, fast_timer.time_left)
	Input.action_release("shoot")

	_check(_shots_fast >= _shots_slow + 2,
		"射速 ×2 的武器 1.2 秒里多开了 %d 发（慢 %d 发 / 快 %d 发）"
		% [_shots_fast - _shots_slow, _shots_slow, _shots_fast])
	_check(max_time_left <= 0.15,
		"计时器按倍率后的真实冷却走（窗口内最大剩余 %.3f 秒，应 ≤0.15）" % max_time_left)
	_clear_roots()
	await process_frame

# ==================== ⑨ 敌方弹丸 vs 玩家子弹 ====================

func _test_enemy_projectile_vs_bullet() -> void:
	print("\n=== ⑨ 敌方弹丸与玩家子弹 ===")
	var scene_root := _make_scene_root()

	var eproj := _instantiate("res://scenes/enemies/enemy_projectile.tscn")
	_check(eproj != null, "敌方弹丸场景可加载")
	if eproj == null:
		_clear_roots()
		await process_frame
		return
	_check(eproj.has_method("_on_area_entered"),
		"敌方弹丸实现了 area_entered（场景里连的就是这个信号）")
	_check((eproj.collision_layer & BULLET_LAYER) == 0,
		"敌方弹丸不在玩家子弹层上（layer=%d）" % eproj.collision_layer)
	_check((eproj.collision_layer & ENEMY_BULLET_LAYER) != 0,
		"敌方弹丸在独立的敌方弹幕层上（layer=%d）" % eproj.collision_layer)
	_check((eproj.collision_mask & BULLET_LAYER) != 0,
		"敌方弹丸会检测玩家子弹（mask=%d）" % eproj.collision_mask)
	_check((eproj.collision_mask & PLAYER_LAYER) != 0,
		"敌方弹丸仍然打玩家（mask=%d）" % eproj.collision_mask)
	scene_root.add_child(eproj)
	eproj.global_position = Vector2(400, 300)

	var bullet := _instantiate("res://scenes/player/bullet.tscn")
	scene_root.add_child(bullet)
	bullet.global_position = Vector2(400, 300)
	await physics_frame
	await physics_frame
	await physics_frame

	var eproj_gone: bool = not is_instance_valid(eproj) or eproj.is_queued_for_deletion()
	_check(eproj_gone, "敌方弹丸撞上玩家子弹后自我销毁")
	_check(is_instance_valid(bullet), "玩家子弹存活（不会被敌方弹丸换掉）")
	_clear_roots()
	await process_frame

	# --- ⑨b 毒雾/血爆不是"玩家弹丸"，不能吞掉敌方弹幕 ---
	# 毒雾和血爆都挂在物理层 4（LAYER_BULLET）上，但它们是范围效果不是弹丸。
	# 用层去判断"谁抵消谁"，毒雾就会把射向玩家的敌方弹幕一只只吃掉，
	# 玩家一圈毒雾等于对面弹幕全废——玩家和敌人都没察觉。
	var scene_root2 := _make_scene_root()
	var eproj2 := _instantiate("res://scenes/enemies/enemy_projectile.tscn")
	scene_root2.add_child(eproj2)
	eproj2.global_position = Vector2(400, 300)
	eproj2.speed = 0.0  # 停住，保证和毒雾稳定重叠
	var cloud := _instantiate("res://scenes/player/poison_cloud.tscn")
	scene_root2.add_child(cloud)
	cloud.global_position = Vector2(400, 300)
	cloud.set_size(2.0)
	await physics_frame
	await physics_frame
	await physics_frame
	var eproj_alive: bool = is_instance_valid(eproj2) and not eproj2.is_queued_for_deletion()
	_check(eproj_alive, "毒雾不会吞掉敌方弹幕（敌方弹丸仍在场上）")
	_check(cloud.has_method("get_damage") == false,
		"毒雾不是玩家弹丸（没有 get_damage 接口）")
	_clear_roots()
	await process_frame

# ==================== ⑩ shoot 键位 ====================

func _test_shoot_input() -> void:
	print("\n=== ⑩ shoot 键位 ===")
	_check(InputMap.has_action("shoot"), "shoot 动作存在")
	var events := InputMap.action_get_events("shoot")
	_check(events.size() >= 2, "shoot 绑定了 %d 个事件" % events.size())

	var has_space: bool = false
	var has_mouse: bool = false
	for ev in events:
		if ev is InputEventKey:
			if ev.physical_keycode == KEY_SPACE or ev.keycode == KEY_SPACE:
				has_space = true
		elif ev is InputEventMouseButton:
			if ev.button_index == MOUSE_BUTTON_LEFT:
				has_mouse = true
	_check(has_space, "shoot 可以用空格键触发")
	_check(has_mouse, "shoot 仍然保留鼠标左键")

	# 真按一次空格，看动作是不是真的被触发
	var key_ev := InputEventKey.new()
	key_ev.physical_keycode = KEY_SPACE
	key_ev.keycode = KEY_SPACE
	key_ev.pressed = true
	Input.parse_input_event(key_ev)
	await process_frame
	_check(Input.is_action_pressed("shoot"), "按下空格后 shoot 动作真的被触发")
	key_ev.pressed = false
	Input.parse_input_event(key_ev)
	await process_frame
	_check(not Input.is_action_pressed("shoot"), "松开空格后 shoot 动作被释放")

# ==================== ⑪ 死亡 / 暂停保护 ====================

func _test_death_and_pause_guard() -> void:
	print("\n=== ⑪ 死亡 / 暂停保护 ===")
	var scene_root := _make_scene_root()
	var player := _instantiate("res://scenes/player/player.tscn")
	player.position = Vector2(300, 300)
	scene_root.add_child(player)
	await process_frame
	await physics_frame

	_deaths = 0
	player.player_died.connect(func() -> void: _deaths += 1)

	# --- ⑪.1 玩家已经死了，再受击不能再触发一次死亡 ---
	player.current_hp = 1.0
	player.take_damage(9999.0)
	await process_frame
	_check(_deaths == 1, "致命一击触发一次死亡（%d 次）" % _deaths)
	player.is_invincible = false  # 模拟"死亡后又被补了一发"
	player.take_damage(10.0)
	await process_frame
	_check(_deaths == 1, "玩家已死亡后再次受击不会重复触发死亡（%d 次）" % _deaths)

	# --- ⑪.1b 血量归零但没走死亡流程的边界情况 ---
	var p_zero := _instantiate("res://scenes/player/player.tscn")
	scene_root.add_child(p_zero)
	await process_frame
	_deaths = 0
	p_zero.player_died.connect(func() -> void: _deaths += 1)
	p_zero.current_hp = 0.0
	p_zero.take_damage(10.0)
	await process_frame
	_check(_deaths == 0, "血量已归零的玩家再受击不会触发死亡（%d 次）" % _deaths)

	# --- ⑪.2 敌人接触伤害不再结算给血量归零的玩家 ---
	# 单独一个玩家：只把血量归零，不走死亡流程，
	# 这样碰撞体还在，敌人确实贴上来了，测的才是"结算"而不是"没碰到"。
	var p_hp0 := _instantiate("res://scenes/player/player.tscn")
	p_hp0.position = Vector2(300, 300)
	scene_root.add_child(p_hp0)
	await process_frame
	p_hp0.current_hp = 0.0
	_hp_total = 0
	p_hp0.hp_changed.connect(func(_cur: float, _mx: float) -> void: _hp_total += 1)
	var bat := _instantiate("res://scenes/enemies/bat.tscn")
	bat.position = Vector2(300, 300)
	bat.collision_layer = 0
	bat.collision_mask = 0
	scene_root.add_child(bat)
	await process_frame
	await physics_frame
	p_hp0.set_physics_process(false)
	await create_timer(1.3).timeout
	_check(_hp_total == 0,
		"玩家血量归零后接触伤害不再结算（hp_changed 广播 %d 次）" % _hp_total)
	bat.queue_free()
	_clear_roots()
	await process_frame

	# --- ⑪.3 暂停期间不结算接触伤害 ---
	var pause_root := _make_scene_root()
	var p_pause := _instantiate("res://scenes/player/player.tscn")
	p_pause.position = Vector2(300, 300)
	pause_root.add_child(p_pause)
	await process_frame
	var bat2 := _instantiate("res://scenes/enemies/bat.tscn")
	bat2.position = Vector2(300, 300)
	bat2.collision_layer = 0
	bat2.collision_mask = 0
	pause_root.add_child(bat2)
	await physics_frame
	await physics_frame
	p_pause.set_physics_process(false)

	var hp_before: float = p_pause.current_hp
	paused = true
	# 暂停时物理帧不再推进，游戏时间会"停住"，所以这里用真实时间计窗口：
	# 接触伤害的冷却是按帧间隔走的，窗口太短根本等不到下一次结算。
	var pause_deadline: int = Time.get_ticks_msec() + 1500
	var paused_frames: int = 0
	while Time.get_ticks_msec() < pause_deadline and paused_frames < 5000:
		await process_frame
		paused_frames += 1
	_check(is_equal_approx(p_pause.current_hp, hp_before),
		"暂停期间没有结算接触伤害（HP %.1f → %.1f，暂停 %d 帧）"
		% [hp_before, p_pause.current_hp, paused_frames])
	paused = false

	var resume_deadline: int = Time.get_ticks_msec() + 1000
	var resume_frames: int = 0
	while Time.get_ticks_msec() < resume_deadline and resume_frames < 5000:
		await process_frame
		resume_frames += 1
	_check(p_pause.current_hp < hp_before,
		"解除暂停后接触伤害恢复结算（HP %.1f → %.1f）" % [hp_before, p_pause.current_hp])
	_clear_roots()
	await process_frame

# ==================== ⑫ DPS 估算接入射速倍率 ====================

func _test_dps_estimate() -> void:
	print("\n=== ⑫ DPS 估算接入射速倍率 ===")
	var scene_root := _make_scene_root()
	var wm_script = load("res://scripts/weapons/weapon_manager.gd")

	var p1 := _instantiate("res://scenes/player/player.tscn")
	scene_root.add_child(p1)
	var wm1 = wm_script.new()
	scene_root.add_child(wm1)
	p1.shoot_speed_multiplier = 1.0
	wm1.setup(p1, "pistol")
	var dps1: float = wm1.estimate_run_dps()

	var p2 := _instantiate("res://scenes/player/player.tscn")
	scene_root.add_child(p2)
	var wm2 = wm_script.new()
	scene_root.add_child(wm2)
	p2.shoot_speed_multiplier = 2.0
	wm2.setup(p2, "pistol")
	var dps2: float = wm2.estimate_run_dps()

	_check(dps1 > 0.0, "手枪构筑估算 DPS %.1f" % dps1)
	_check(dps2 > dps1 * 1.8,
		"射速 ×2 时估算 DPS 同步提高（%.1f → %.1f）" % [dps1, dps2])
	_clear_roots()
	await process_frame
