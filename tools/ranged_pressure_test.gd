extends SceneTree
## 远程火力压制 + 经验拾取回归测试
## 用法: godot --headless --path . --script res://tools/ranged_pressure_test.gd
##
## 覆盖两条试玩反馈：
##   「小怪投射物太多了，需要到后期慢慢增多才合理」
##   「经验依旧有捡不到的」
##
## 注意：--script 模式下 autoload 在编译期未注册，脚本里不能直接写单例名。

var _fail: int = 0

func _initialize() -> void:
	_run()

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ✅ %s" % msg)
	else:
		print("  ❌ %s" % msg)
		_fail += 1

func _wait_until(pred: Callable, timeout: float = 2.0) -> bool:
	## 轮询等待条件成立，而不是写死 await create_timer(0.5)。
	## headless 下"0.5 秒"里到底推进了几个物理帧并不稳定，
	## 写死秒数会让同一份代码有时绿有时红（这条曾经误报过一次）。
	## 用真实时钟计时——SceneTree 没有帧 delta 可读，别拿帧数当秒数。
	var deadline: int = Time.get_ticks_msec() + int(timeout * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if bool(pred.call()):
			return true
		await process_frame
	return bool(pred.call())

func _finish() -> void:
	paused = false
	print("")
	if _fail == 0:
		print("✅ 全部通过")
	else:
		print("❌ 失败 %d 项" % _fail)
	quit(0 if _fail == 0 else 1)

func _run() -> void:
	await process_frame
	print("\n====== 远程火力 / 经验拾取回归测试 ======")
	var gc = load("res://scripts/core/game_config.gd")

	# ==================== ① 逐层解禁 ====================
	print("\n=== ① 远程敌人逐层解禁 ===")
	_check(not gc.is_ranged_allowed(1, 0), "第 1 层第 1 间房：不刷远程")
	_check(not gc.is_ranged_allowed(1, 3), "第 1 层第 4 间房（已清 3）：仍不刷远程")
	_check(gc.is_ranged_allowed(1, 4), "第 1 层第 5 间房（已清 4）：开始刷远程")
	_check(not gc.is_ranged_allowed(2, 1), "第 2 层已清 1 间：不刷远程")
	_check(gc.is_ranged_allowed(2, 2), "第 2 层已清 2 间：开始刷远程")
	_check(not gc.is_ranged_allowed(3, 0), "第 3 层第 1 间房：不刷远程")
	_check(gc.is_ranged_allowed(3, 1), "第 3 层已清 1 间：开始刷远程")

	print("\n=== ② 开火节奏与弹道上限 ===")
	_check(gc.get_enemy_fire_cooldown_mult(1) > gc.get_enemy_fire_cooldown_mult(2),
		"第 1 层冷却倍率(%.2f) > 第 2 层(%.2f)" % [
			gc.get_enemy_fire_cooldown_mult(1), gc.get_enemy_fire_cooldown_mult(2)])
	_check(gc.get_enemy_fire_cooldown_mult(2) >= gc.get_enemy_fire_cooldown_mult(3),
		"第 2 层冷却倍率不低于第 3 层（越深越快）")
	_check(is_equal_approx(gc.get_enemy_fire_cooldown_mult(3), 1.0), "第 3 层不额外放慢")
	_check(gc.get_enemy_projectile_cap(1) < gc.get_enemy_projectile_cap(2),
		"第 1 层弹道上限(%d) < 第 2 层(%d)" % [
			gc.get_enemy_projectile_cap(1), gc.get_enemy_projectile_cap(2)])
	_check(gc.get_enemy_projectile_cap(2) < gc.get_enemy_projectile_cap(3),
		"第 2 层弹道上限 < 第 3 层(%d)" % gc.get_enemy_projectile_cap(3))
	_check(is_zero_approx(gc.get_ranged_triple_chance(1)), "第 1 层没有三连发")
	_check(gc.get_ranged_triple_chance(3) > 0.0, "第 3 层有三连发")

	# ==================== ③ 类型选取 ====================
	print("\n=== ③ 敌人类型选取 ===")
	var wm = load("res://scripts/managers/wave_manager.gd").new()
	root.add_child(wm)
	var floor1_pool: Array = ["vampire", "bat", "zombie", "skeleton_archer", "werewolf"]
	wm.set_floor(1, floor1_pool, 0)
	var ranged_seen: int = 0
	for i in range(400):
		if wm._pick_enemy_type() == "skeleton_archer":
			ranged_seen += 1
	_check(ranged_seen == 0, "第 1 层前期 400 次抽取没有骷髅射手（实际 %d）" % ranged_seen)

	wm.set_floor(1, floor1_pool, 4)
	ranged_seen = 0
	for i in range(400):
		if wm._pick_enemy_type() == "skeleton_archer":
			ranged_seen += 1
	_check(ranged_seen > 0, "第 1 层后期 400 次抽取出现骷髅射手（%d 次）" % ranged_seen)

	var floor3_pool: Array = ["vampire", "bat", "zombie", "skeleton_archer",
		"werewolf", "exploder", "elite_vampire", "vampire_mage", "summoner",
		"gargoyle", "vampire_prince"]
	wm.set_floor(3, floor3_pool, 1)
	ranged_seen = 0
	for i in range(600):
		var t: String = wm._pick_enemy_type()
		if t == "skeleton_archer" or t == "vampire_mage":
			ranged_seen += 1
	_check(ranged_seen > 20, "第 3 层远程敌人正常出现（%d / 600）" % ranged_seen)
	wm.queue_free()

	# ==================== ④ 实机部分 ====================
	var main_scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	current_scene = main_scene
	await create_timer(3.4).timeout
	paused = false

	var player = main_scene.player
	var wm2 = main_scene.wave_manager
	wm2.is_active = false
	for e in get_nodes_in_group("enemies"):
		if is_instance_valid(e):
			e.queue_free()
	player.xp_to_next_level = 999999
	player.current_xp = 0
	await create_timer(0.4).timeout
	paused = false

	print("\n=== ④ 弹道上限真的拦得住 ===")
	var cap: int = gc.get_enemy_projectile_cap(1)
	var proj_scene = load("res://scenes/enemies/enemy_projectile.tscn")
	for i in range(cap):
		var pj = proj_scene.instantiate()
		current_scene.add_child(pj)
		pj.global_position = Vector2(300 + i * 20, 300)
	await process_frame
	var live: int = get_nodes_in_group("enemy_projectiles").size()
	_check(live >= cap, "场上弹道数达到上限（%d / cap=%d）" % [live, cap])

	# 招一个射手出来，手动调用 _attack，看它会不会再吐弹
	var archer = load("res://scenes/enemies/skeleton_archer.tscn").instantiate()
	current_scene.add_child(archer)
	archer.global_position = Vector2(400, 300)
	archer.floor_index = 1
	archer.player = player
	archer.set_physics_process(false)
	await process_frame
	var before: int = get_nodes_in_group("enemy_projectiles").size()
	archer._attack()
	await process_frame
	var after: int = get_nodes_in_group("enemy_projectiles").size()
	_check(after == before, "弹道上限已满时射手不开火（%d → %d）" % [before, after])
	_check(archer.attack_timer < 0.5, "被上限拦下后只等 0.35s 重试（实际 %.2f）" % archer.attack_timer)

	print("\n=== ⑤ 冷却倍率作用到射手 ===")
	for pj in get_nodes_in_group("enemy_projectiles"):
		if is_instance_valid(pj):
			pj.queue_free()
	await process_frame
	await process_frame
	archer.floor_index = 1
	archer.attack_timer = 0.0
	archer._attack()
	await process_frame
	var t1: float = archer.attack_timer
	_check(t1 > 2.0, "第 1 层射手冷却被放长到 %.2f 秒（基础 2.0s）" % t1)
	for pj in get_nodes_in_group("enemy_projectiles"):
		if is_instance_valid(pj):
			pj.queue_free()
	await process_frame
	await process_frame
	archer.floor_index = 3
	archer.attack_timer = 0.0
	archer._attack()
	await process_frame
	var t3: float = archer.attack_timer
	_check(t3 < t1, "第 3 层冷却回到 %.2f 秒，比第 1 层短" % t3)
	archer.queue_free()
	for pj in get_nodes_in_group("enemy_projectiles"):
		if is_instance_valid(pj):
			pj.queue_free()
	await process_frame

	print("\n=== ⑥ 经验拾取：吸附半径与磁力字段 ===")
	var gem_scene = load("res://scenes/player/xp_gem.tscn")

	# 6.1 基础半径：120px 外一点点不该吸，内侧应该吸
	# ⚠ 必须先设坐标再 add_child：宝石 _enter_tree 里的掉落弹跳 tween 会以
	# "当前 position" 为目标持续写 position，add_child 之后再赋值会被它拽回原点附近
	var g1 = gem_scene.instantiate()
	g1.global_position = player.global_position + Vector2(110, 0)
	current_scene.add_child(g1)
	paused = false
	var g1_pulled := func() -> bool:
		if not is_instance_valid(g1) or not g1.is_inside_tree():
			return true
		if int(g1.get("xp_value")) <= 0:
			return true
		return g1.global_position.distance_to(player.global_position) < 60.0
	await _wait_until(g1_pulled, 3.0)
	_check(not is_instance_valid(g1) or not g1.is_inside_tree() or int(g1.get("xp_value")) <= 0
		or g1.global_position.distance_to(player.global_position) < 60.0,
		"110px 处的宝石被吸附并贴近玩家")

	# 6.2 pickup_range_bonus 生效：+200 之后 260px 外也该被吸
	var g2 = gem_scene.instantiate()
	g2.global_position = player.global_position + Vector2(260, 0)
	current_scene.add_child(g2)
	await create_timer(0.3).timeout
	var before_dist: float = 260.0
	if is_instance_valid(g2) and g2.is_inside_tree():
		before_dist = g2.global_position.distance_to(player.global_position)
	# 默认半径 120 吸不到 260，所以先确认它没动
	var not_attracted: bool = (not is_instance_valid(g2)) or bool(g2.get("is_attracted")) == false
	_check(not_attracted, "260px 处（超出默认 120 半径）的宝石没有被吸附")

	player.pickup_range_bonus += 200.0
	await create_timer(0.5).timeout
	paused = false
	var got2: bool = (not is_instance_valid(g2)) or (not g2.is_inside_tree()) or int(g2.get("xp_value")) <= 0
	var dist2: float = 9999.0
	if is_instance_valid(g2) and g2.is_inside_tree():
		dist2 = g2.global_position.distance_to(player.global_position)
	_check(got2 or dist2 < before_dist - 20.0,
		"拾取范围 +200 之后同一枚宝石被吸过来（距离 %.0f → %.0f）" % [before_dist, dist2])
	player.pickup_range_bonus -= 200.0
	if is_instance_valid(g2) and g2.is_inside_tree():
		g2.queue_free()

	print("\n=== ⑦ 波次结束磁力回收 ===")
	var g3 = gem_scene.instantiate()
	g3.xp_value = 7
	g3.global_position = player.global_position + Vector2(420, 0)
	current_scene.add_child(g3)
	await create_timer(0.3).timeout
	paused = false
	var far_dist: float = 420.0
	if is_instance_valid(g3) and g3.is_inside_tree():
		far_dist = g3.global_position.distance_to(player.global_position)
	_check(far_dist > 300.0, "远处置入一枚宝石（%.0f px，远超吸附半径）" % far_dist)
	wm2.magnetize_xp_gems()
	await create_timer(0.8).timeout
	paused = false
	var gone: bool = (not is_instance_valid(g3)) or (not g3.is_inside_tree()) or int(g3.get("xp_value")) <= 0
	var d3: float = 9999.0
	if is_instance_valid(g3) and g3.is_inside_tree():
		d3 = g3.global_position.distance_to(player.global_position)
	_check(gone or d3 < 120.0, "磁力回收把远处的宝石拉到玩家身上（剩余距离 %.0f）" % d3)

	_finish()
