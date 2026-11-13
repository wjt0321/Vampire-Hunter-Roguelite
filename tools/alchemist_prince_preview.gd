extends SceneTree
## 炼金亲王真实 Boss 房双单位动作展示。脚本安排站位与状态，不是无辅助实况。
## 复用墓穴守望者预览的 SceneTree 脚手架：真实 Main 进第 4 层 Boss 房（floors_data[3]）、
## 每状态首帧存 scene_<unit>_<state>.png、结尾清理 BGM/SFX 播放流。
## 演示顺序只走「巨像先倒」：pair idle → move → cast（玩家吃一瓶 puddle）→ slam（巨像砸地）
## → 打爆巨像（亲王 solo_shift）→ 打爆亲王（death 条带播完才倒下）→ 收尾。
## 亲王先倒→enrage 路线由 alchemist_prince_animation_test 覆盖，不在此演示。
## 运行（仓库根目录，不加 --headless）：
## ./.tools/godot/Godot_v4.7.2-stable_win64_console.exe --verbose --path . \
##   --rendering-method gl_compatibility --audio-driver Dummy --disable-vsync --fixed-fps 30 \
##   --write-movie artifacts/alchemist_prince/alchemist_prince_preview.avi \
##   --script res://tools/alchemist_prince_preview.gd
const OUT := "res://artifacts/alchemist_prince/"
var game: Node
var prince: Node
var colossus: Node
var caption: Label
var detail_caption: Label
var frame_number := 0
var captured: Dictionary = {}
var failures := 0
var cast_shown := false
var slam_shown := false
var solo_shift_shown := false
var prince_death_shown := false
var colossus_death_shown := false

func _initialize() -> void:
	_run()

func _run() -> void:
	await process_frame
	seed(14112026)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	root.get_node("SaveManager").use_test_save_path("alchemist_prince_preview")
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
	# 炼金亲王是第 4 层 Boss（floors_data[3]；current_floor=4 → _show_floor_intro 取第 4 条）
	game.dungeon.current_floor = 4
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
	prince = get_nodes_in_group("boss")[0]
	colossus = prince.colossus
	if colossus == null or not is_instance_valid(colossus):
		failures += 1
		printerr("PREVIEW: colossus missing after boss spawn")
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
	# 登场 + 双人待机（含 Boss 登场血条 1.9s）。亲王/巨像 AI 一有人就恒为追击，
	# 纯 idle 站姿由脚本冻结节拍喂出（站位与状态由脚本安排，与守望者预览同一约定）。
	_set_units_frozen(true)
	_place(Vector2(-140, -20), Vector2(430, 0))
	await _capture(60, "炼金亲王与炼金巨像  /  登场与双人待机", "真实第 4 层 Boss 房 · 脚本安排站位与状态 · 30 fps")
	# 移动：解冻真实追击逻辑，玩家放远，亲王 78 / 巨像 36 双双逼近
	_set_units_frozen(false)
	prince._timer = 9999.0  # 冻结自动掷瓶节拍，cast 段由脚本定时喂
	await _capture(45, "双人逼近", "真实追击逻辑 · 亲王 78 / 巨像 36 移速 · 远距离拉近")
	# 掷瓶：脚本把亲王冷却清零，下一物理帧真实 _toss 在玩家脚下生成药液，
	# 玩家站定吃一跳 puddle 10 伤害（药液 0.5s tick，敌我都会伤）
	var hp_before_cast: float = game.player.current_hp
	prince._timer = 0.001
	await _capture(48, "掷瓶泼药", "真实 _toss 命中脚下 · 药液 0.5s tick · 玩家真实吃一瓶 10 伤害")
	cast_shown = captured.has("prince:cast") and game.player.current_hp < hp_before_cast
	if not cast_shown:
		failures += 1
		printerr("PREVIEW: cast never shown or puddle never hit the player")
	# 过渡：把玩家带离药液并等 0.5s 受击无敌帧过期——否则砸地伤害会被无敌帧吞掉
	game.player.global_position = prince.global_position + Vector2(-260, 80)
	await _capture(21, "拉开距离", "走出药液 · 无敌帧过期 · 巨像即将进入狂怒")
	# 砸地：巨像仅在 enraged 后才会砸地。脚本直接调真实 enrage()（公开入口），
	# 玩家放进 90px 判定圈，等真实 _physics_process 砸地：16 伤害 + slam 条带同帧起播
	_set_units_frozen(true, false)  # 只冻亲王，巨像 physics 必须保持启用才会真实砸地
	game.player.global_position = colossus.global_position + Vector2(70, 0)
	var hp_before_slam: float = game.player.current_hp
	colossus.enrage()
	await _capture(48, "巨像砸地", "真实 enrage() 入口 · <90px 判定 · 16 伤害与 slam 条带同帧 · 狂怒移速 70")
	slam_shown = captured.has("colossus:slam") and game.player.current_hp < hp_before_slam
	if not slam_shown:
		failures += 1
		printerr("PREVIEW: slam never shown or never hit the player")
	# 打爆巨像：真实 take_damage 打死。不做任何 remove_from_group workaround——
	# 巨像 _die 自己退组保命（死亡演出自救是本次验收点），death 条带 0.6s 后自回收；
	# colossus_fell 同帧把亲王切 solo（移速 140 / 冷却 1.3）并起播 solo_shift 条带。
	colossus.take_damage(colossus.current_hp + 1.0)
	await _capture(60, "巨像崩解 · 亲王换位", "巨像 death 条带 0→6 帧 0.6s 自回收 · 亲王 solo_shift 同帧起播")
	solo_shift_shown = captured.has("prince:solo_shift")
	colossus_death_shown = captured.has("colossus:death") and not is_instance_valid(colossus)
	if not solo_shift_shown:
		failures += 1
		printerr("PREVIEW: solo_shift state never shown")
	if not colossus_death_shown:
		failures += 1
		printerr("PREVIEW: colossus survived death animation")
	# 打爆亲王：巨像已倒，_die 直接 _finish_fight 发 boss_defeated，
	# death 条带 0.6s 播完才倒下（visible=false）并自行回收——条带播完才倒，不做假摔。
	game.player.global_position = prince.global_position + Vector2(430, 0)
	prince.take_damage(prince.current_hp + 1.0)
	await _capture(55, "亲王谢幕", "death 条带播完才倒下 · 战斗结算先行 · 0.8s 内自回收")
	prince_death_shown = captured.has("prince:death") and not is_instance_valid(prince)
	if not prince_death_shown:
		failures += 1
		printerr("PREVIEW: prince survived death animation")
	await _capture(20, "房间归于寂静", "Boss 房保留 · 战斗结束 · 药液残留敌我都会伤")
	if captured.size() != 10:
		failures += 1
		printerr("PREVIEW: expected 10 animation states (5 prince + 5 colossus), saw ", captured.keys())
	var report := FileAccess.open(OUT + "preview_capture.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({"fps":30,"frames":frame_number,"states":captured.keys(),"cast_shown":cast_shown,"slam_shown":slam_shown,"solo_shift_shown":solo_shift_shown,"prince_death_shown":prince_death_shown,"colossus_death_shown":colossus_death_shown,"failures":failures,"kind":"scripted real-room action showcase"}, "  "))
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
	root.get_node("SaveManager").clear_test_save("alchemist_prince_preview")
	print("PREVIEW frames=%d states=%d failures=%d" % [frame_number, captured.size(), failures])
	quit(1 if failures else 0)

func _set_units_frozen(frozen: bool, include_colossus := true) -> void:
	var units: Array = [prince]
	if include_colossus:
		units.append(colossus)
	for unit in units:
		if unit != null and is_instance_valid(unit):
			unit.set_physics_process(not frozen)
			if frozen:
				unit.velocity = Vector2.ZERO
				unit._tick_sprite(0.0)

func _place(offset: Vector2, player_offset: Vector2) -> void:
	game.camera.limit_right = int(game.current_room.room_width)
	prince.global_position = game.current_room.get_center() + offset
	colossus.global_position = prince.global_position + Vector2(170, 40)
	game.player.global_position = prince.global_position + player_offset
	game.camera.global_position = game.current_room.get_center()
	prince.velocity = Vector2.ZERO
	colossus.velocity = Vector2.ZERO

func _capture(count: int, title: String, detail: String) -> void:
	caption.text = title
	detail_caption.text = detail
	for index in range(count):
		game.player._tick_player_sprite(1.0 / 30.0)
		await RenderingServer.frame_post_draw
		_track_states()
		frame_number += 1

func _track_states() -> void:
	for pair in [["prince", prince], ["colossus", colossus]]:
		if pair[1] == null or not is_instance_valid(pair[1]):
			continue  # 已自回收的单位：先判存活再取值，避免给已释放实例赋值
		var unit: Node = pair[1]
		var state: String = unit._animation_state
		if state != "" and not captured.has(pair[0] + ":" + state):
			captured[pair[0] + ":" + state] = frame_number
			var image := root.get_texture().get_image()
			if image.save_png(OUT + "scene_" + pair[0] + "_" + state + ".png") != OK:
				failures += 1
