extends SceneTree
## 墓穴守望者真实 Boss 房动作展示。脚本安排站位与状态，不是无辅助实况。
## 复用织血母皇预览的 SceneTree 脚手架：真实 Main 进第 3 层 Boss 房、
## 每状态首帧存 scene_<state>.png、结尾清理 BGM/SFX 播放流。
## 运行（仓库根目录，不加 --headless）：
## ./.tools/godot/Godot_v4.7.2-stable_win64_console.exe --verbose --path . \
##   --rendering-method gl_compatibility --audio-driver Dummy --disable-vsync --fixed-fps 30 \
##   --write-movie artifacts/tomb_warden/tomb_warden_preview.avi \
##   --script res://tools/tomb_warden_preview.gd
const OUT := "res://artifacts/tomb_warden/"
var game: Node
var boss: Node2D
var caption: Label
var detail_caption: Label
var frame_number := 0
var captured: Dictionary = {}
var failures := 0
var sweep_shown := false
var zombie_spawned := false
var revive_shown := false
var ward_break_shown := false
var death_shown := false

func _initialize() -> void:
	_run()

func _run() -> void:
	await process_frame
	seed(14112026)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	root.get_node("SaveManager").use_test_save_path("tomb_warden_preview")
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
	# 墓穴守望者是第 3 层 Boss（FLOOR_BLUEPRINT index 3 → floors_data[2]，0 基第 3 条）
	game.dungeon.current_floor = 3
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
	# 展示期间冻结自动决策节拍（扫击计时/复苏冷却），由脚本直接喂动作
	boss._sweep_timer = 9999.0
	boss._revive_cd = 9999.0
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
	# 登场 + 待机（含 Boss 登场血条 1.9s）
	_place(Vector2(-150, 0), Vector2(430, 0))
	await _capture(60, "墓穴守望者  /  登场与待机", "真实第 3 层 Boss 房 · 脚本安排站位与状态 · 30 fps")
	# 移动：玩家放远，守望者提灯逼近（结界未破 0.7 倍速）
	await _capture(60, "提灯逼近", "真实追击逻辑 · 结界加持 0.7 倍速 · 远距离拉近")
	# 扫击：玩家站进 260px/0.35rad 判定扇区，脚本置 _sweep_dir/_sweep_left，
	# 伤害窗与 lantern_sweep 条带同帧起播，真实吃一发 9 伤害
	game.player.global_position = boss.global_position + Vector2(150, 0)
	var hp_before: float = game.player.current_hp
	boss._sweep_dir = (game.player.global_position - boss.global_position).normalized()
	boss._sweep_left = 0.55
	await _capture(24, "提灯扫击", "260px / 0.35rad 判定 · 伤害窗 0.55s 与条带同帧 · 真实命中 9 伤害")
	sweep_shown = captured.has("lantern_sweep") and game.player.current_hp < hp_before
	if not sweep_shown:
		failures += 1
		printerr("PREVIEW: sweep never shown or never hit the player")
	game.player.global_position = boss.global_position + Vector2(430, 0)
	# 复苏：脚本直接调 _raise_one，等真实僵尸入组（房内 enemies ≤12 才拉得动）
	var enemies_before: int = get_nodes_in_group("enemies").size()
	boss._raise_one()
	await process_frame
	zombie_spawned = get_nodes_in_group("enemies").size() > enemies_before
	if not zombie_spawned:
		failures += 1
		printerr("PREVIEW: _raise_one did not add a zombie to enemies group")
	await _capture(24, "亡者复苏", "结界未破才能拉人 · 真实僵尸入组 · 0.6s 复苏条带")
	revive_shown = zombie_spawned and captured.has("revive")
	if not revive_shown:
		failures += 1
		printerr("PREVIEW: revive state never shown")
	# 结界破碎：脚本直接打爆结界核心，ward_broken 同帧起播 ward_break 条带
	if boss.ward == null:
		failures += 1
		printerr("PREVIEW: ward missing before ward_break segment")
	else:
		boss.ward.take_damage(99.0)
	await _capture(24, "结界破碎", "ward.take_damage(99) 打爆 · 0.6s 破碎条带 · 此后不再复苏")
	ward_break_shown = captured.has("ward_break") and boss.ward == null
	if not ward_break_shown:
		failures += 1
		printerr("PREVIEW: ward_break state never shown")
	# 死亡：脚本伤害直接打死。不做任何 remove_from_group workaround——
	# 守望者 _die 自己退组保命（死亡演出自救是本次验收点），
	# 死亡条带 0.6s 后自回收，结界经 linked_nodes 连带清理。
	boss.take_damage(boss.current_hp + 1.0)
	await _capture(45, "守墓人长眠", "死亡条带 0→6 帧 0.6s 自回收 · 奖励立即结算")
	death_shown = (not is_instance_valid(boss)) and captured.has("death")
	if not death_shown:
		failures += 1
		printerr("PREVIEW: boss survived death animation")
	await _capture(20, "房间归于寂静", "Boss 房保留 · 战斗结束")
	if captured.size() != 6:
		failures += 1
		printerr("PREVIEW: expected all 6 animation states, saw ", captured.keys())
	var report := FileAccess.open(OUT + "preview_capture.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({"fps":30,"frames":frame_number,"states":captured.keys(),"sweep_shown":sweep_shown,"zombie_spawned":zombie_spawned,"revive_shown":revive_shown,"ward_break_shown":ward_break_shown,"death_shown":death_shown,"failures":failures,"kind":"scripted real-room action showcase"}, "  "))
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
	root.get_node("SaveManager").clear_test_save("tomb_warden_preview")
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
	for index in range(count):
		game.player._tick_player_sprite(1.0 / 30.0)
		await RenderingServer.frame_post_draw
		if is_instance_valid(boss):
			var state: String = boss._animation_state
			if state != "" and not captured.has(state):
				captured[state] = frame_number
				var image := root.get_texture().get_image()
				if image.save_png(OUT + "scene_" + state + ".png") != OK:
					failures += 1
		frame_number += 1
