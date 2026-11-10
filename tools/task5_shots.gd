extends SceneTree
## Task 5 可视化验收：1280×720 战斗与 Boss
##
## 用法：godot --path . --script res://tools/task5_shots.gd   （必须带窗口，不能 --headless）
##
## 为什么要单独一个脚本而不是塞进 readability_test：
## 那个是 --headless 的，无渲染器时 root.get_texture() 拿不到真画面。
## 断言和图分开跑，"断言绿了但东西看不见"这类问题才有人发现。
##
## 每张图都刻意制造"混战"：多敌人 + 敌方弹丸 + 玩家弹丸 + 掉落物 + HUD 同时在屏，
## 因为可读性问题只在拥挤时暴露。

const OUT_DIR := "res://tools/evidence/iteration/"
const SHOT_SIZE := Vector2i(1280, 720)

var _fail: int = 0

func _initialize() -> void:
	_run()

func _shot(name: String) -> void:
	await process_frame
	await process_frame
	var img: Image = root.get_texture().get_image()
	if img == null:
		printerr("[task5_shots] %s 取图失败" % name)
		_fail += 1
		return
	if img.get_size() != SHOT_SIZE:
		printerr("[task5_shots] %s 尺寸异常 %s" % [name, str(img.get_size())])
		_fail += 1
	var path := OUT_DIR + "task5_" + name + ".png"
	if img.save_png(path) != OK:
		printerr("[task5_shots] %s 保存失败" % name)
		_fail += 1
		return
	print("[task5_shots] OK %-18s %s" % [name, str(img.get_size())])

func _run() -> void:
	await process_frame
	DisplayServer.window_set_size(SHOT_SIZE)
	await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))

	var cat = load("res://scripts/core/item_catalog.gd")

	var main = load("res://scenes/main.tscn").instantiate()
	main.debug_force_character = "hunter"
	root.add_child(main)
	current_scene = main
	# 等开场演出与第一波进场
	await create_timer(3.0).timeout

	main.weapon_manager.add_weapon(cat.create_weapon("shotgun"))
	main.player.add_passive_item(cat.create_passive("shield"))
	main.player.add_silver(80)
	await create_timer(6.0).timeout
	await _shot("combat_start")

	# 混战：把玩家挪到房间中部，撒一圈敌人和弹丸，
	# 让"玩家 / 敌人 / 危险弹丸 / HUD"四者同时出现在一屏里。
	await _build_mixed_fight(main)
	await _shot("combat_mixed")

	# 同一个镜头的 2 倍放大裁切区域，专门看弹丸与敌人剪影
	await _shot("combat_mixed_zoom_src")

	# 暗角战斗：把房间主题切到 boss 背景 + 大量弹幕，检验暗背景下的亮芯
	await _clear_spawned(main)
	main.current_room.room_theme = "cave"
	await _spawn_barrage(main, 26)
	await create_timer(0.4).timeout
	await _shot("combat_barrage")

	# Boss 战：必须走真实入口 _enter_next_room()，不能直接调 _enter_boss_room()。
	# 后者只生成 Boss，不建 Boss 房——房间仍是上一间普通战斗房（主题/尺寸/背景全不对），
	# 截出来就是"吸血鬼领主站在普通石砖房里"，容易误判成背景主题失效。
	await _clear_spawned(main)
	# is_boss_room() 问的是"下一间是不是 Boss"，不是"当前是不是 Boss 房"。
	# 所以循环停在"门口就是 Boss"的那一刻，还得再迈一步才真的进去。
	var guard: int = 0
	while not main.dungeon.is_boss_room() and guard < 12:
		guard += 1
		main._enter_next_room(false)
		await create_timer(0.45).timeout
	if main.dungeon.is_boss_room():
		main._enter_next_room(false)
		await create_timer(0.6).timeout
	_check_room_theme(main)
	await create_timer(3.6).timeout
	# Boss 开一波弹幕再截，避免"Boss 一个人站在空房间里"这种没信息量的图
	await _spawn_barrage(main, 18, main.current_room.get_center() + Vector2(0.0, -80.0))
	await create_timer(0.3).timeout
	await _shot("boss_fight")

	print("[task5_shots] DONE fail=%d" % _fail)
	quit(1 if _fail > 0 else 0)

func _check_room_theme(main) -> void:
	## 记一笔"这张图确实在 Boss 房里"，否则看图的人无法判断背景对不对
	var room = main.current_room
	var floor_sprite := room.get_node_or_null("FloorSprite") as Sprite2D
	print("[task5_shots] boss room theme=%s size=%.0fx%.0f bg=%s grid=%s" % [
		room.room_theme, room.room_width, room.room_height,
		"yes" if floor_sprite != null else "no",
		"yes" if room.get_node_or_null("GridOverlay") != null else "no"])
	if room.room_theme != "boss" or floor_sprite == null:
		printerr("[task5_shots] Boss 房主题/背景不对，截图不具代表性")
		_fail += 1

func _clear_spawned(main) -> void:
	for e in get_nodes_in_group("enemies"):
		if is_instance_valid(e) and not e.is_in_group("boss"):
			e.queue_free()
	for p in get_nodes_in_group("enemy_projectiles"):
		if is_instance_valid(p):
			p.queue_free()
	await create_timer(0.3).timeout

func _build_mixed_fight(main) -> void:
	## 一圈敌人 + 玩家侧子弹 + 敌方弹丸，全部围绕玩家正面铺开
	var center: Vector2 = main.player.global_position
	var enemy_scenes: Array = [
		"res://scenes/enemies/vampire.tscn",
		"res://scenes/enemies/skeleton_archer.tscn",
		"res://scenes/enemies/zombie.tscn",
		"res://scenes/enemies/bat.tscn",
	]
	for i in 8:
		var scene_path: String = enemy_scenes[i % enemy_scenes.size()]
		var enemy = load(scene_path).instantiate()
		var angle: float = TAU * float(i) / 8.0
		enemy.global_position = center + Vector2(cos(angle), sin(angle)) * (150.0 + 40.0 * float(i % 3))
		main.current_room.add_child(enemy)
	await create_timer(0.25).timeout

	var proj_scene = load("res://scenes/enemies/enemy_projectile.tscn")
	for i in 10:
		var proj = proj_scene.instantiate()
		var angle: float = TAU * float(i) / 10.0
		var dir := Vector2(cos(angle), sin(angle))
		proj.global_position = center + dir * 210.0
		proj.direction = -dir
		proj.damage = 0.0
		proj.max_range = 420.0
		main.current_room.add_child(proj)
	await create_timer(0.35).timeout
	# 让玩家真的开一枪：玩家侧弹道也要在图里
	main.weapon_manager._fire_weapon(main.weapon_manager.weapons[0])
	await create_timer(0.1).timeout

func _spawn_barrage(main, count: int, origin = null) -> void:
	var center: Vector2 = origin if origin != null else main.current_room.get_center()
	var proj_scene = load("res://scenes/enemies/enemy_projectile.tscn")
	for i in count:
		var proj = proj_scene.instantiate()
		var angle: float = TAU * float(i) / float(count)
		var dir := Vector2(cos(angle), sin(angle))
		proj.global_position = center + dir * 60.0
		proj.direction = dir
		proj.damage = 0.0
		proj.speed = 40.0
		proj.max_range = 900.0
		proj.global_position += dir * (18.0 * float(i % 4))
		main.current_room.add_child(proj)
	await create_timer(0.2).timeout
