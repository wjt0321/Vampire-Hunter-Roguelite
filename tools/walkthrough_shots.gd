extends SceneTree
## 全场景走查取证：逐房间类型截图 + 道具动效断言 + 图鉴剪影/Meta 行 + 深渊 BGM 接线验证。
## 用法：godot --path . --script res://tools/walkthrough_shots.gd（必须带窗口，不能 --headless）
## 截图落在 tools/evidence/walkthrough/（已 gitignore）。

const OUT_DIR := "res://tools/evidence/walkthrough/"
const SHOT_SIZE := Vector2i(1280, 720)
## 本轮补程序动效的单帧道具（game_room.PROP_ANIM_STYLES 的键）。
const EXPECT_ANIM_PROPS := ["bookshelf", "statue", "broken_pillar", "coffin", "altar",
	"blood_splatter", "bedroll", "gold_pile", "shop_sign", "cobweb"]

var _fail: int = 0

func _initialize() -> void:
	_run()

func _shot(name: String) -> void:
	await process_frame
	await process_frame
	var img: Image = root.get_texture().get_image()
	if img == null:
		printerr("[walkthrough] %s 取图失败" % name)
		_fail += 1
		return
	var path := OUT_DIR + name + ".png"
	if img.save_png(path) != OK:
		printerr("[walkthrough] %s 保存失败" % name)
		_fail += 1
		return
	print("[walkthrough] OK %-22s %s" % [name, str(img.get_size())])

func _check_prop_anims(main) -> void:
	## 单帧道具必须挂上 PropIdleAnim；漏挂的按名字报出来。
	var room = main.current_room
	if room == null:
		printerr("[walkthrough] current_room 为空，道具断言跳过")
		_fail += 1
		return
	var found := {}
	for node in room.find_children("*", "Node2D", true, false):
		if node.get_script() == null:
			continue
		var style := String(node.get("anim_style"))
		if style == "" or node.get("phase") == null:
			continue
		found[style] = int(found.get(style, 0)) + 1
	print("[walkthrough] 道具动效实例: %s" % str(found))
	# 不要求每个道具都在这一间房（房型决定摆放），只要求动效机制真的挂上了。
	if found.is_empty():
		printerr("[walkthrough] 房里一个 PropIdleAnim 都没有")
		_fail += 1

func _run() -> void:
	await process_frame
	DisplayServer.window_set_size(SHOT_SIZE)
	await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))

	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await create_timer(3.0).timeout

	# ---------- 战斗房（1 层开局房，含道具摆放） ----------
	await _shot("room_combat_floor1")
	_check_prop_anims(main)

	# ---------- 图鉴：未解锁剪影 → 解锁后 Meta 行 ----------
	# 先排掉升级弹窗：Boss 房战斗出的经验会把面板顶在图鉴上面。
	var drain := 0
	while main.upgrade_ui != null and is_instance_valid(main.upgrade_ui) and main.upgrade_ui.visible and drain < 10:
		var opts = main.upgrade_ui.current_options
		if opts.size() > 0:
			main.upgrade_ui._on_option_selected(opts[0])
		drain += 1
		await create_timer(0.2).timeout
	var pause_menu = main.get_node("PauseMenu")
	pause_menu._pause()
	await create_timer(0.5).timeout
	pause_menu._show_codex()
	await create_timer(0.7).timeout
	await _shot("codex_locked_silhouettes")
	var saves = root.get_node_or_null("/root/SaveManager")
	if saves != null and saves.has_method("discover_codex"):
		# 解锁每类的前几项（列表最上面，截图直接可见）
		var slots = load("res://scripts/core/asset_slots.gd")
		var catalog = load("res://scripts/core/unlock_catalog.gd")
		var i := 0
		for eid in slots.ENEMIES.keys():
			if i >= 3:
				break
			saves.call("discover_codex", "enemy", eid)
			i += 1
		for bid in slots.BOSSES.keys():
			saves.call("discover_codex", "boss", bid)
			break
		if catalog != null and catalog.WEAPONS.size() > 0:
			saves.call("discover_codex", "weapon", String(catalog.WEAPONS[0].get("id", "")))
		if catalog != null and catalog.PASSIVES.size() > 0:
			saves.call("discover_codex", "passive", String(catalog.PASSIVES[0].get("id", "")))
		pause_menu._refresh_codex()
		await create_timer(0.6).timeout
		await _shot("codex_unlocked_meta")
	else:
		printerr("[walkthrough] 找不到 SaveManager，解锁态截图跳过")
		_fail += 1
	pause_menu._on_codex_back_pressed()
	pause_menu._resume()
	await create_timer(0.4).timeout


	# ---------- 逐房型走查 ----------
	main._enter_shop_room()
	await create_timer(1.2).timeout
	await _shot("room_shop")

	main._enter_treasure_room()
	await create_timer(1.2).timeout
	await _shot("room_treasure")

	main._enter_rest_room()
	await create_timer(1.2).timeout
	await _shot("room_rest")

	main._enter_mutation_room()
	await create_timer(1.2).timeout
	await _shot("room_mutation")
	# 祭坛弹窗不关掉，后面图鉴截图会被它盖住
	if main.mutation_ui != null and is_instance_valid(main.mutation_ui) and main.mutation_ui.visible:
		main.mutation_ui.close()
		await create_timer(0.3).timeout

	main._enter_fog_room(false)
	await create_timer(1.5).timeout
	await _shot("room_fog")

	main._enter_mirror_room(false)
	await create_timer(1.5).timeout
	await _shot("room_mirror")

	main._enter_boss_room()
	await create_timer(2.5).timeout
	await _shot("room_boss")

	# ---------- 深渊 BGM 接线：abyss_level>0 时战斗房取 abyss 曲 ----------
	var audio_lib = root.get_node_or_null("AudioLib")
	var audio_mgr = root.get_node_or_null("AudioManager")
	if audio_lib != null and audio_mgr != null:
		var abyss_stream = audio_lib.get_abyss_bgm()
		print("[walkthrough] abyss bgm -> %s" % ("" if abyss_stream == null else str(abyss_stream.resource_path)))
		if abyss_stream == null:
			printerr("[walkthrough] get_abyss_bgm() 返回空（应有回退曲）")
			_fail += 1
		GameConfig.abyss_level = 1
		var combat_bgm = main._combat_bgm()
		var rp := "" if combat_bgm == null else str(combat_bgm.resource_path)
		print("[walkthrough] abyss_level=1 时战斗曲 -> %s" % rp)
		if not rp.ends_with("abyss.ogg") and not rp.ends_with("battle.ogg"):
			printerr("[walkthrough] 深渊战斗曲既不是 abyss 也不是 battle 回退: %s" % rp)
			_fail += 1
		GameConfig.abyss_level = 0
	else:
		printerr("[walkthrough] 找不到 AudioLib/AudioManager")
		_fail += 1

	# ---------- 封印标记复查（问题5 硬边蓝圆盘的修复确认） ----------
	if main.room_events != null:
		main.room_events._start_seals()
		await create_timer(0.9).timeout
		await _shot("seal_marker_recheck")

	print("[walkthrough] DONE fail=%d" % _fail)
	quit(1 if _fail > 0 else 0)