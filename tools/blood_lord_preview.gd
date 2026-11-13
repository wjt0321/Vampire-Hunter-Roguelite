extends SceneTree
## Deterministic action showcase in the real Boss room, not an unassisted playthrough.
## Run without --headless, with --fixed-fps 30 --write-movie <file>. Saves one still per state.
const OUT := "res://artifacts/blood_lord/"
var game: Node
var boss: Node2D
var caption: Label
var detail_caption: Label
var frame_number := 0
var captured: Dictionary = {}
var failures := 0
var wall_stun_seen := false

func _initialize() -> void:
	_run()

func _run() -> void:
	await process_frame
	seed(13112026)
	root.get_node("SaveManager").use_test_save_path("blood_lord_preview")
	DisplayServer.window_set_size(Vector2i(1280, 720))
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await create_timer(3.0).timeout
	game.wave_manager.stop()
	game.weapon_manager.process_mode = Node.PROCESS_MODE_DISABLED
	if game.room_events:
		game.room_events.cancel()
	for enemy in get_nodes_in_group("enemies"):
		enemy.queue_free()
	game._create_room(2080.0, 1248.0, "boss")
	game._setup_camera_limits()
	game._current_room_type = "boss"
	game.player.set_physics_process(false)
	game.player.max_hp = 10000.0
	game.player.current_hp = 10000.0
	game.player.hp_changed.emit(10000.0, 10000.0)
	game.player.xp_to_next_level = 100000
	game.camera.top_level = true
	game.camera.position_smoothing_enabled = false
	game.camera.global_position = game.current_room.get_center()
	game._enter_boss_room()
	boss = get_nodes_in_group("boss")[0]
	var layer := CanvasLayer.new()
	layer.layer = 110
	game.add_child(layer)
	var backing := ColorRect.new()
	backing.color = Color(0.025, 0.03, 0.04, 0.94)
	backing.position = Vector2(20, 614)
	backing.size = Vector2(1240, 84)
	layer.add_child(backing)
	caption = Label.new()
	caption.position = Vector2(38, 622)
	caption.add_theme_font_size_override("font_size", 22)
	layer.add_child(caption)
	detail_caption = Label.new()
	detail_caption.position = Vector2(38, 659)
	detail_caption.add_theme_font_size_override("font_size", 18)
	detail_caption.modulate = Color(0.78, 0.79, 0.82)
	layer.add_child(detail_caption)
	await _capture(60, "血铠领主  /  登场与待机", "真实房间动作展示 · 脚本安排站位与状态 · 30 fps")
	_place(Vector2(-130, -20), Vector2(260, 0))
	boss.motion = boss.Motion.IDLE
	boss._motion_timer = 10.0
	await _capture(60, "持盾推进", "正式六帧横条 · 使用真实移动逻辑")
	_place(Vector2(-70, -20), Vector2(75, 0))
	boss._motion_timer = 0.0
	await _capture(66, "持盾双连斩", "首击前摇 0.22 秒 · 后续命中间隔 0.28 秒")
	_place(Vector2(70, -20), Vector2(-75, 0))
	boss.motion = boss.Motion.IDLE
	boss._motion_timer = 0.0
	boss._swing_recovery_remaining = 0.0
	await _capture(60, "左向连斩", "左右翻转 · 伤害范围与现有逻辑保持一致")
	boss.global_position = Vector2(game.current_room.room_width - 225.0, 620.0)
	game.player.global_position = boss.global_position + Vector2(300, 0)
	game.camera.limit_right = int(game.current_room.room_width) + 120
	game.camera.global_position = boss.global_position - Vector2(250, 0)
	boss.motion = boss.Motion.WINDUP
	boss._motion_timer = boss.WINDUP_TIME
	boss._swing_recovery_remaining = 0.0
	await _capture(75, "举盾蓄力 → 冲锋撞墙 → 持盾眩晕", "真实墙体碰撞触发眩晕 · 冲锋期间锁定朝向")
	if not wall_stun_seen:
		failures += 1
		printerr("PREVIEW: charge did not reach guarded stun")
	_place(Vector2(-70, -20), Vector2(220, 0))
	boss.motion = boss.Motion.IDLE
	boss.velocity = Vector2.ZERO
	boss.set_physics_process(false)
	boss.take_damage(95.0)
	await _capture(36, "破盾 → 猛攻姿态", "通过真实伤害入口破盾 · 护盾减伤立即失效")
	boss.set_physics_process(true)
	boss._motion_timer = 10.0
	await _capture(54, "无盾推进", "破盾之后移动不再复现盾牌")
	_place(Vector2(-70, -20), Vector2(75, 0))
	boss.motion = boss.Motion.IDLE
	boss._motion_timer = 0.0
	await _capture(66, "无盾三连斩", "保留原连击节奏 · 无盾专属攻击横条")
	boss.motion = boss.Motion.STUN
	boss._motion_timer = boss.STUN_TIME
	boss._swing_recovery_remaining = 0.0
	await _capture(33, "无盾眩晕", "状态覆盖展示 · 持盾与破盾眩晕使用不同素材")
	paused = true
	await _capture(24, "暂停检查", "动画与战斗逻辑同时冻结")
	paused = false
	_place(Vector2(-70, -20), Vector2(300, 0))
	boss.take_damage(boss.current_hp + 1.0)
	await _capture(45, "倒地与死亡回收", "奖励立即结算 · 死亡横条播放 0.60 秒后释放")
	if is_instance_valid(boss):
		failures += 1
		printerr("PREVIEW: boss survived death animation")
	if captured.size() != 12:
		failures += 1
		printerr("PREVIEW: expected all 12 animation states, saw ", captured.keys())
	var report := FileAccess.open(OUT + "preview_capture.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({"fps":30,"frames":frame_number,"states":captured.keys(),"wall_stun_seen":wall_stun_seen,"failures":failures,"kind":"scripted real-room action showcase"}, "  "))
	report.close()
	game.queue_free()
	await process_frame
	await process_frame
	var audio_manager: Node = root.get_node("AudioManager")
	audio_manager.stop_bgm(false)
	audio_manager._bgm_player.stream = null
	for player in audio_manager._sfx_players:
		player.stop()
		player.stream = null
	OS.delay_msec(100)
	root.get_node("SaveManager").clear_test_save("blood_lord_preview")
	print("PREVIEW frames=%d states=%d failures=%d" % [frame_number, captured.size(), failures])
	quit(1 if failures else 0)

func _place(offset: Vector2, player_offset: Vector2) -> void:
	game.camera.limit_right = int(game.current_room.room_width)
	boss.global_position = game.current_room.get_center() + offset
	game.player.global_position = boss.global_position + player_offset
	game.camera.global_position = game.current_room.get_center()
	boss.velocity = Vector2.ZERO

func _capture(count: int, title: String, detail: String) -> void:
	caption.text = title
	detail_caption.text = detail
	var charge_player_repositioned := false
	for index in range(count):
		if not paused:
			game.player._tick_player_sprite(1.0 / 30.0)
		await RenderingServer.frame_post_draw
		if is_instance_valid(boss):
			if boss.motion == boss.Motion.CHARGE and not charge_player_repositioned:
				game.player.global_position = boss.global_position + Vector2(-260, 0)
				charge_player_repositioned = true
			if boss.motion == boss.Motion.STUN and boss.phase == boss.Phase.GUARD:
				wall_stun_seen = true
			var state: String = boss._animation_state
			if not captured.has(state):
				captured[state] = frame_number
				var image := root.get_texture().get_image()
				if image.save_png(OUT + "scene_" + state + ".png") != OK:
					failures += 1
		frame_number += 1
