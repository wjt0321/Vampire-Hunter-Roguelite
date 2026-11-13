extends SceneTree
## 织血母皇真实 Boss 房动作展示。脚本安排站位与状态，不是无辅助实况。
## 复用血铠领主预览的 SceneTree 脚手架：真实 Main 进第 2 层 Boss 房、
## 每状态首帧存 scene_<state>.png、结尾清理 BGM/SFX 播放流。
## 运行（仓库根目录，不加 --headless）：
## ./.tools/godot/Godot_v4.7.2-stable_win64_console.exe --verbose --path . \
##   --rendering-method gl_compatibility --audio-driver Dummy --disable-vsync --fixed-fps 30 \
##   --write-movie artifacts/blood_matriarch/blood_matriarch_preview.avi \
##   --script res://tools/blood_matriarch_preview.gd
const OUT := "res://artifacts/blood_matriarch/"
var game: Node
var boss: Node2D
var caption: Label
var detail_caption: Label
var frame_number := 0
var captured: Dictionary = {}
var failures := 0
var larva_spawned := false
var larva_orbit_seen := false
var larva_pounce_seen := false
var phase_change_shown := false
var death_shown := false

func _initialize() -> void:
	_run()

func _run() -> void:
	await process_frame
	seed(13112026)
	root.get_node("SaveManager").use_test_save_path("blood_matriarch_preview")
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
	# 织血母皇是第 2 层 Boss（FLOOR_BLUEPRINT index 2 → floors_data[1]）
	game.dungeon.current_floor = 2
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
	# 展示期间由脚本直接喂动作，冻结自动决策节拍
	boss._action_timer = 9999.0
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
	await _capture(60, "织血母皇  /  登场与待机", "真实第 2 层 Boss 房 · 脚本安排站位与状态 · 30 fps")
	# 移动：玩家放远，母皇追击（未暴露 0.7 倍速）
	await _capture(60, "逼近猎物", "真实追击逻辑 · 远距离拉近")
	# 召唤：脚本喂 summon 动作，等到幼虫实体出现且进入巡逻
	_trigger_action("summon")
	await _capture(48, "召唤幼虫", "接触帧落地生成 · 上限 3 只")
	var larva: Node2D = _first_living_larva()
	if larva == null:
		failures += 1
		printerr("PREVIEW: larva did not spawn after summon")
	else:
		larva_spawned = true
	# 玩家先贴着远离幼虫的安全位，展示 ORBIT 巡逻；再贴近触发 WINDUP→POUNCE
	if larva != null and is_instance_valid(larva):
		game.player.global_position = larva.global_position + Vector2(420, 0)
		await _capture(24, "幼虫巡逻", "绕母皇 90px 轨道巡逻 · 玩家处于警戒半径外")
		game.player.global_position = larva.global_position + Vector2(60, 0)
		await _capture(30, "幼虫预警 → 扑咬", "0.35s 预警后 260px/s 扑咬 · 真实警戒半径 160")
		if larva_pounce_seen:
			pass
		else:
			failures += 1
			printerr("PREVIEW: larva never showed POUNCE")
		game.player.global_position = boss.global_position + Vector2(430, 0)
	# 产卵：脚本喂 egg 动作
	_trigger_action("egg")
	await _capture(40, "产下血卵", "卵巢上限 3 颗 · 接触帧后 0.25s 落地")
	# 铺网：脚本喂 web 动作
	_trigger_action("web")
	await _capture(40, "织网封锁", "地面网 patch · 减速区域上限 3 块")
	# 清掉全部卵 → 触发破卵变身（0.6s 视觉）
	for egg_node in boss._eggs.duplicate():
		if is_instance_valid(egg_node) and egg_node.get("is_dead") != true:
			egg_node.take_damage(9999.0)
	await process_frame
	if not boss.exposed:
		failures += 1
		printerr("PREVIEW: destroying eggs did not expose the queen")
	else:
		phase_change_shown = true
	_place(Vector2(-100, 0), Vector2(300, 0))
	await _capture(30, "破卵变身", "卵巢清空 → 0.6s 变身表现 · 之后改高机动近身")
	# 近身挥击：暴露后贴近（<=96px 判定）脚本喂 melee
	game.player.global_position = boss.global_position + Vector2(60, 0)
	_trigger_action("melee")
	await _capture(36, "暴露近身挥击", "96px / 0.7rad 判定 · 18 伤害真实结算")
	game.player.global_position = boss.global_position + Vector2(430, 0)
	# 死亡：脚本伤害直接打死，死亡条带 0.6s 后自回收
	# main._on_boss_defeated 会同步 queue_free enemies 组全部成员；
	# 血铠领主在自己的 _die 里 remove_from_group("enemies") 自救。
	# 不改游戏脚本，由预览脚本在致死伤害前代为摘除，保住死亡演出。
	boss.remove_from_group("enemies")
	boss.take_damage(boss.current_hp + 1.0)
	await _capture(45, "倒地与死亡回收", "奖励立即结算 · 死亡横条 0.60 秒后释放并连带清理幼虫")
	if is_instance_valid(boss):
		failures += 1
		printerr("PREVIEW: boss survived death animation")
	else:
		death_shown = true
	await _capture(20, "房间归于寂静", "Boss 房保留 · 战斗结束")
	if captured.size() != 8:
		failures += 1
		printerr("PREVIEW: expected all 8 animation states, saw ", captured.keys())
	var report := FileAccess.open(OUT + "preview_capture.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({"fps":30,"frames":frame_number,"states":captured.keys(),"larva_spawned":larva_spawned,"phase_change_shown":phase_change_shown,"death_shown":death_shown,"failures":failures,"kind":"scripted real-room action showcase"}, "  "))
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
	root.get_node("SaveManager").clear_test_save("blood_matriarch_preview")
	print("PREVIEW frames=%d states=%d failures=%d" % [frame_number, captured.size(), failures])
	quit(1 if failures else 0)

func _place(offset: Vector2, player_offset: Vector2) -> void:
	game.camera.limit_right = int(game.current_room.room_width)
	boss.global_position = game.current_room.get_center() + offset
	game.player.global_position = boss.global_position + player_offset
	game.camera.global_position = game.current_room.get_center()
	boss.velocity = Vector2.ZERO

func _trigger_action(kind: String) -> void:
	boss._pending_kind = kind
	boss._pending_timer = boss.CONTACT_DELAY
	boss._action_timer = 9999.0
	boss._tick_sprite(0.0)

func _first_living_larva() -> Node2D:
	for larva in boss._larvae:
		if is_instance_valid(larva) and larva.get("is_dead") != true:
			return larva
	return null

func _capture(count: int, title: String, detail: String) -> void:
	caption.text = title
	detail_caption.text = detail
	for index in range(count):
		game.player._tick_player_sprite(1.0 / 30.0)
		await RenderingServer.frame_post_draw
		if is_instance_valid(boss):
			for larva in boss._larvae:
				if is_instance_valid(larva):
					if larva.motion == larva.Motion.ORBIT:
						larva_orbit_seen = true
					elif larva.motion == larva.Motion.POUNCE:
						larva_pounce_seen = true
			var state: String = boss._animation_state
			if state != "" and not captured.has(state):
				captured[state] = frame_number
				var image := root.get_texture().get_image()
				if image.save_png(OUT + "scene_" + state + ".png") != OK:
					failures += 1
		frame_number += 1
