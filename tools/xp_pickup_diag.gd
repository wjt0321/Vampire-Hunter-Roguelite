extends SceneTree
## 经验宝石拾取诊断：找出"躺在地上捡不到"的真实原因
## 用法: godot --headless --path . --script res://tools/xp_pickup_diag.gd
##
## 做法：走真实掉落链路（敌人 _die → _drop_xp_gem → 对象池），
## 把敌人分散到房间各处打死，再逐枚走到宝石旁边（40px）看能不能捡起来。
## 捡不到的打印它的状态：物理帧、process_mode、是否被吸引、玩家引用、坐标。

var _fail: int = 0

func _initialize() -> void:
	_run()

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ✅ %s" % msg)
	else:
		print("  ❌ %s" % msg)
		_fail += 1

func _find_room(node: Node) -> Node:
	if node.has_method("get_room_bounds"):
		return node
	for c in node.get_children():
		var r := _find_room(c)
		if r != null:
			return r
	return null

func _run() -> void:
	await process_frame
	print("\n====== 经验宝石拾取诊断 ======")

	var pool = root.get_node("/root/ObjectPool")
	var main_scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	current_scene = main_scene
	await create_timer(3.4).timeout

	var player = main_scene.player
	var room := _find_room(main_scene)
	var bounds: Rect2 = room.get_room_bounds() if room != null else Rect2(800, 400, 480, 260)
	print("房间节点: %s  边界: %s" % [("null" if room == null else str(room.name)), str(bounds)])
	print("玩家坐标: %s" % str(player.global_position))

	# 关掉升级打断：升级会 pause 整棵树，宝石就不动了，会污染诊断
	player.xp_to_next_level = 999999
	player.current_xp = 0

	for e in get_nodes_in_group("enemies"):
		if is_instance_valid(e):
			e.queue_free()
	for g in get_nodes_in_group("xp_gems"):
		if is_instance_valid(g):
			g.queue_free()
	await create_timer(0.4).timeout

	# ---- 24 只敌人均匀铺在房间内，逐只打死 ----
	var enemy_scene = load("res://scenes/enemies/zombie.tscn")
	var spawn_parent: Node = (room if room != null else current_scene)
	var spots: Array = []
	for i in range(24):
		var col: int = i % 6
		var row: int = i / 6
		var pos := Vector2(
			lerpf(bounds.position.x + 60.0, bounds.end.x - 60.0, float(col) / 5.0),
			lerpf(bounds.position.y + 50.0, bounds.end.y - 50.0, float(row) / 3.0)
		)
		spots.append(pos)

	for i in range(spots.size()):
		var e = enemy_scene.instantiate()
		spawn_parent.add_child(e)
		e.global_position = spots[i]
		await process_frame
		if e.has_method("take_damage"):
			e.take_damage(99999.0)
		await process_frame

	# 停掉刷怪并清空场上残余敌人：否则玩家自动开火打死的新敌人会复用池里的宝石节点，
	# 迭代到一半节点变成别处的坐标，诊断结果会被污染的
	main_scene.wave_manager.is_active = false
	for e in get_nodes_in_group("enemies"):
		if is_instance_valid(e):
			e.queue_free()
	await create_timer(0.9).timeout
	paused = false

	var gems: Array = []
	for g in get_nodes_in_group("xp_gems"):
		if is_instance_valid(g) and g.is_inside_tree() and int(g.get("xp_value")) > 0:
			gems.append(g)

	print("\n掉落宝石：%d 枚（24 只敌人，30px 内会合并）" % gems.size())
	print("玩家坐标: %s" % str(player.global_position))

	# ---- 逐枚靠近 ----
	print("\n-- 逐枚靠近拾取（站到宝石 100px 外，等 0.5s；旧半径 88 时会失败）--")
	var failed: int = 0
	for g in gems:
		if not is_instance_valid(g) or not g.is_inside_tree():
			continue
		if int(g.get("xp_value")) <= 0:
			continue
		var gp: Vector2 = g.global_position
		player.global_position = gp + Vector2(100, 0)
		await process_frame
		await create_timer(0.5).timeout
		var still: bool = is_instance_valid(g) and g.is_inside_tree() and int(g.get("xp_value")) > 0
		if still:
			failed += 1
			print("  捡不到 val=%d pos=%s 玩家=%s 距离=%.0f 吸附范围=%s phys=%s mode=%d attracted=%s parent=%s" % [
				int(g.get("xp_value")), str(g.global_position), str(player.global_position),
				g.global_position.distance_to(player.global_position),
				str(g.get("attraction_range")),
				str(g.is_physics_processing()), int(g.process_mode),
				str(g.get("is_attracted")),
				(str(g.get_parent().name) if g.get_parent() != null else "<无父>")])
	print("")
	_check(failed == 0, "%d 枚宝石全部可拾取（失败 %d）" % [gems.size(), failed])

	# ---- 池化复用专项 ----
	print("\n-- 池化复用专项（捡过又回池的宝石，能不能再捡）--")
	paused = false
	var gem_scene = load("res://scenes/player/xp_gem.tscn")
	for round_i in range(4):
		var gem = pool.acquire(gem_scene) as Area2D
		var gem_pos: Vector2 = player.global_position + Vector2(45, 0)
		gem.global_position = gem_pos
		gem.xp_value = 5
		current_scene.call_deferred("add_child", gem)
		await create_timer(0.6).timeout
		paused = false
		var still: bool = is_instance_valid(gem) and gem.is_inside_tree() and int(gem.get("xp_value")) > 0
		if still:
			print("      状态 paused=%s phys=%s mode=%d attracted=%s player=%s d=%.0f" % [
				str(paused), str(gem.is_physics_processing()), int(gem.process_mode),
				str(gem.get("is_attracted")), str(gem.get("player")),
				gem.global_position.distance_to(player.global_position)])
		_check(not still, "第 %d 次复用宝石可被拾取" % (round_i + 1))
		paused = false
		await create_timer(0.3).timeout

	print("")
	if _fail == 0:
		print("✅ 诊断完成：未发现捡不到的宝石")
	else:
		print("❌ 诊断发现 %d 处问题" % _fail)
	quit(0 if _fail == 0 else 1)
