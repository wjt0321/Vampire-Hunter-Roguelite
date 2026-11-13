extends SceneTree
## 月蚀女王真实 Boss 房动作展示。脚本安排站位与状态，不是无辅助实况。
## 复用墓穴守望者预览的 SceneTree 脚手架：真实 Main 进第 5 层 Boss 房（floors_data[4]）、
## 每状态首帧存 scene_<state>.png、结尾清理 BGM/SFX 播放流。
## 演示顺序：idle → move → blink（脚本置 _timer=0 触发真实闪烁：前摇 0.45s→瞬移）→ appear（落点凝聚）
## → phase_change（脚本打掉祭坛 40HP→moon_phase=1→0.6s 月相演出；再压血 <40% 触发月相 2）
## → death（death 条带播完 0.8s 内自回收）→ 收尾。
## 女王 _timer 语义不动，脚本只写值触发；不做任何 remove_from_group workaround——
## 女王 _die 自己退组保命（死亡演出自救是本次验收点）。
## 运行（仓库根目录，不加 --headless）：
## ./.tools/godot/Godot_v4.7.2-stable_win64_console.exe --verbose --path . \
##   --rendering-method gl_compatibility --audio-driver Dummy --disable-vsync --fixed-fps 30 \
##   --write-movie artifacts/eclipse_queen/eclipse_queen_preview.avi \
##   --script res://tools/eclipse_queen_preview.gd
const OUT := "res://artifacts/eclipse_queen/"
var game: Node
var boss: Node2D
var caption: Label
var detail_caption: Label
var frame_number := 0
var captured: Dictionary = {}
var failures := 0
var blink_shown := false
var appear_shown := false
var phase_change_shown := false
var phase_two_reached := false
var death_shown := false

func _initialize() -> void:
	_run()

func _run() -> void:
	await process_frame
	seed(14112026)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	root.get_node("SaveManager").use_test_save_path("eclipse_queen_preview")
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
	# 月蚀女王是第 5 层 Boss（FLOOR_BLUEPRINT index 5 → floors_data[4]，0 基第 5 条）
	game.dungeon.current_floor = 5
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
	await process_frame
	boss = get_nodes_in_group("boss")[0]
	if boss == null or not is_instance_valid(boss):
		failures += 1
		printerr("PREVIEW: boss missing after boss spawn")
	if boss._get_enemy_type() != "eclipse_queen":
		failures += 1
		printerr("PREVIEW: floors_data[4] is not eclipse_queen, saw ", boss._get_enemy_type())
	# 展示期间冻结自动闪烁节拍（1.4s 冷却），blink 段由脚本置 _timer=0 喂
	boss._timer = 9999.0
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
	# 登场 + 待机（纯 idle 站姿由脚本冻结节拍喂出：站位与状态由脚本安排，
	# 与炼金亲王预览同一约定；sprite 浮动走 _process 不受冻结影响）
	_place(Vector2(-150, 0), Vector2(430, 0))
	_set_boss_frozen(true)
	await _capture(60, "月蚀女王  /  登场与待机", "真实第 5 层 Boss 房 · 脚本安排站位与状态 · 30 fps")
	# 移动：解冻真实追击逻辑，玩家放远，女王 80 移速逼近；自动闪烁节拍仍冻结
	_set_boss_frozen(false)
	await _capture(50, "月影逼近", "真实追击逻辑 · 移速 80 · 远距离拉近")
	# 闪烁：脚本把女王冷却清零（置 _timer=0），下一物理帧真实 _physics_process
	# 进入 0.45s 前摇（blink 条带全程），随后瞬移到玩家位置（appear 落点凝聚 0.35s）
	game.player.global_position = boss.global_position + Vector2(370, -60)
	var blink_origin: Vector2 = boss.global_position
	var blink_target: Vector2 = game.player.global_position
	boss._timer = 0.0
	await _capture(45, "月影闪烁 · 落点凝聚", "真实闪烁：_timer=0 触发 · 前摇 0.45s → 瞬移 · appear 0.35s")
	# 容差 48px：女王瞬移到玩家坐标后与玩家碰撞体推挤会滑开十几像素（实测 17px），
	# 落点正确性由 origin→落点 >100px 位移与两个条带截图共同佐证
	var landed := boss.global_position.distance_to(blink_target) < 48.0
	blink_shown = captured.has("blink") and landed
	appear_shown = captured.has("appear") and landed
	if not blink_shown:
		failures += 1
		printerr("PREVIEW: blink never shown or boss did not teleport (dist=", boss.global_position.distance_to(blink_target), ")")
	if not appear_shown:
		failures += 1
		printerr("PREVIEW: appear state never shown after teleport")
	if blink_origin.distance_to(boss.global_position) < 100.0:
		failures += 1
		printerr("PREVIEW: boss barely moved during blink")
	# 月相一：脚本直接打掉祭坛（40HP），altar_destroyed 同帧起播 phase_change 条带
	# （0.6s 月相演出），moon_phase=1，安全圈 150→90
	game.player.global_position = boss.global_position + Vector2(430, 60)
	if boss.altar == null:
		failures += 1
		printerr("PREVIEW: altar missing before phase_change segment")
	else:
		boss.altar.take_damage(40.0)
	await _capture(30, "祭坛破碎 · 月相一", "打掉祭坛 40HP · phase_change 条带 0.6s · 安全圈 150→90")
	phase_change_shown = captured.has("phase_change") and boss.moon_phase == 1 and boss.altar == null
	if not phase_change_shown:
		failures += 1
		printerr("PREVIEW: phase_change state never shown or moon_phase stayed ", boss.moon_phase)
	# 月相二：真实 take_damage 压血到 35%（<40% 判定线），月相 2 判定帧同帧重播月相条带
	game.player.global_position = boss.global_position + Vector2(-430, 60)
	boss.take_damage(boss.current_hp - boss.max_hp * 0.35)
	await _capture(30, "血月低垂 · 月相二", "真实压血 <40% · moon_phase=2 · 月相条带重播 · 安全圈 90")
	phase_two_reached = boss.moon_phase == 2
	if not phase_two_reached:
		failures += 1
		printerr("PREVIEW: moon_phase 2 never reached, saw ", boss.moon_phase)
	# 死亡：脚本伤害直接打死。女王 _die 自己退组保命（不做 remove_from_group workaround），
	# death 条带 tween_method 推 0→6 帧 0.6s 后自回收（<0.8s 契约）；第 5 层 Boss 倒下
	# 会真实触发五层通关结算，收尾帧如实展示。拾取窗口用 debug 字段归零，不在倒计时上耗 10s。
	game.player.global_position = boss.global_position + Vector2(400, 0)
	game.debug_loot_grace_seconds = 0
	boss.take_damage(boss.current_hp + 1.0)
	await _capture(45, "女王谢幕", "death 条带 0→6 帧 0.6s · 0.8s 内自回收 · 五层通关结算先行")
	death_shown = captured.has("death") and not is_instance_valid(boss)
	if not death_shown:
		failures += 1
		printerr("PREVIEW: boss survived death animation")
	await _capture(20, "月蚀王座告破", "Boss 房保留 · 五层通关结算 · 战斗结束")
	if captured.size() != 6:
		failures += 1
		printerr("PREVIEW: expected all 6 animation states, saw ", captured.keys())
	var report := FileAccess.open(OUT + "preview_capture.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({"fps":30,"frames":frame_number,"states":captured.keys(),"blink_shown":blink_shown,"appear_shown":appear_shown,"phase_change_shown":phase_change_shown,"phase_two_reached":phase_two_reached,"death_shown":death_shown,"failures":failures,"kind":"scripted real-room action showcase"}, "  "))
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
	root.get_node("SaveManager").clear_test_save("eclipse_queen_preview")
	print("PREVIEW frames=%d states=%d failures=%d" % [frame_number, captured.size(), failures])
	quit(1 if failures else 0)

func _set_boss_frozen(frozen: bool) -> void:
	if boss != null and is_instance_valid(boss):
		boss.set_physics_process(not frozen)
		if frozen:
			boss.velocity = Vector2.ZERO
			boss._tick_sprite(0.0)

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
