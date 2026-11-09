extends SceneTree
## 截图取证：把"有物品图标"的四个界面全截出来，肉眼确认哪些是字、哪些是图。
## 用法: godot --path . --script res://tools/icon_evidence_shots.gd   （必须带窗口）
##
## 为什么必须截图：无头跑不出"看上去像没有图标"这种问题。
## 映射表全命中 ≠ 屏幕上有图 —— 贴图可能是废图、尺寸不对、或者被容器压成 0 高度。

const OUT_DIR := "res://tools/evidence/"

var _fail: int = 0

func _initialize() -> void:
	_run()

func _shot(name: String) -> void:
	await process_frame
	await process_frame
	var img: Image = root.get_texture().get_image()
	if img == null:
		printerr("[shot] 取图失败 %s" % name)
		_fail += 1
		return
	var path := OUT_DIR + name + ".png"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var err := img.save_png(path)
	if err != OK:
		printerr("[shot] 保存失败 %s err=%d" % [name, err])
		_fail += 1
		return
	print("[shot] OK %-16s %s" % [name, str(img.get_size())])

func _run() -> void:
	await process_frame
	DisplayServer.window_set_size(Vector2i(1280, 720))
	await process_frame
	var cat = load("res://scripts/core/item_catalog.gd")

	# ============ 主菜单：选角（角色被动技能） ============
	var menu = load("res://scenes/ui/main_menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await create_timer(1.2).timeout
	menu.character_select.show_selection()
	await create_timer(0.9).timeout
	await _shot("01_character_select")
	menu.character_select.visible = false
	await create_timer(0.3).timeout

	# ============ 元进度商店 ============
	menu.upgrade_shop.show_shop()
	await create_timer(0.9).timeout
	await _shot("02_meta_shop")
	menu.upgrade_shop.visible = false
	menu.queue_free()
	await process_frame
	await create_timer(0.3).timeout

	# ============ 局内 ============
	var main = load("res://scenes/main.tscn").instantiate()
	main.debug_force_character = "hunter"
	root.add_child(main)
	current_scene = main
	await create_timer(2.5).timeout

	# 塞满武器和被动，让 HUD 的 build 面板把全部图标都列出来
	for wid in ["shotgun", "magic_book", "kunai", "flame_thrower", "blood_burst", "crossbow"]:
		main.weapon_manager.add_weapon(cat.create_weapon(wid))
	for pid in ["magnet", "shield", "regeneration", "greed_ring", "berserker_blood",
			"frozen_heart", "lightning_shield", "shadow_cloak", "vampiric_fang",
			"swift_boots", "lucky_clover", "blood_edge", "frost_bind", "blood_drain"]:
		main.player.add_passive_item(cat.create_passive(pid))
	await create_timer(1.0).timeout
	await _shot("03_hud_build_panel")

	# ============ 升级三选一 ============
	main.upgrade_ui.show_upgrade(main.player, main.weapon_manager)
	await create_timer(0.9).timeout
	await _shot("04_upgrade_cards")
	main.upgrade_ui.visible = false
	paused = false
	await create_timer(0.4).timeout

	# ============ 基础补给卡（_get_basic_rewards 的三张） ============
	# 这三张卡的 "icon" 字段是空的，靠 _get_option_icon 回退到语义图标。
	# 单独摆出来核对：到底有没有图。
	var basic_layer := CanvasLayer.new()
	root.add_child(basic_layer)
	var basic_box := HBoxContainer.new()
	basic_box.alignment = BoxContainer.ALIGNMENT_CENTER
	basic_box.add_theme_constant_override("separation", 16)
	basic_layer.add_child(basic_box)
	for opt in main.upgrade_ui._get_basic_rewards():
		var btn: Button = main.upgrade_ui._create_option_button(opt)
		basic_box.add_child(btn)
	await create_timer(0.8).timeout
	await _shot("09_basic_reward_cards")
	basic_layer.queue_free()
	await create_timer(0.3).timeout

	# ============ 房间商店 ============
	var room_shop = main.get_node_or_null("RoomShop")
	if room_shop == null:
		room_shop = main.room_shop
	if room_shop != null:
		room_shop.open(main.player, main.weapon_manager)
		await create_timer(0.9).timeout
		await _shot("05_room_shop")
		room_shop.close()
		await create_timer(0.3).timeout

	# ============ 战斗画面（看地面掉落物） ============
	await create_timer(1.2).timeout
	await _shot("06_battle_drops")

	# ============ 战场地面掉落物：逐个摆出来看 ============
	# 2026-11-09 第四轮：经验宝石/银币/增益/受诅宝箱原来全是程序化菱形、圆点
	# 或中文字，这张图专门核对它们现在有没有真图标。
	#
	# ⚠ 必须摆到玩家拾取半径之外（>250px），否则当场被吸走，截不到东西。
	var room = main.current_room
	if room != null:
		var ppos: Vector2 = main.player.global_position
		var drop_specs: Array = [
			["gem_small", "res://scenes/player/xp_gem.tscn", 4],
			["gem_mid", "res://scenes/player/xp_gem.tscn", 12],
			["gem_big", "res://scenes/player/xp_gem.tscn", 30],
		]
		var offsets: Array = [
			Vector2(-320, -150), Vector2(-260, -150), Vector2(-200, -150),
			Vector2(-140, -150), Vector2(-100, -150), Vector2(-60, -150),
		]
		for i in drop_specs.size():
			var node = load(String(drop_specs[i][1])).instantiate()
			node.set("xp_value", int(drop_specs[i][2]))
			room.add_child(node)
			node.global_position = ppos + offsets[i]
		for i in 3:
			var coin = load("res://scenes/player/silver_coin.tscn").instantiate()
			room.add_child(coin)
			coin.global_position = ppos + Vector2(-20 + i * 30, -150)
		var kinds: Array = ["heal", "frenzy", "magnet"]
		for i in kinds.size():
			var pu := Node2D.new()
			pu.set_script(load("res://scripts/player/powerup.gd"))
			pu.kind = String(kinds[i])
			room.add_child(pu)
			pu.global_position = ppos + Vector2(-320 + i * 90, -60)
		var chest := Node2D.new()
		chest.set_script(load("res://scripts/managers/cursed_chest.gd"))
		room.add_child(chest)
		chest.global_position = ppos + Vector2(60, -60)
		# 摆完立刻截：吸力半径是 120~160px，晚一点就被吃掉了
		await create_timer(0.25).timeout
		await _shot("07_world_drops_icons")

	# ============ 结算界面：成就列表 ============
	# 25 个成就原本共用一个 "★" 字符，这里逐个解锁几个看徽章。
	var ach_mgr = root.get_node_or_null("AchievementManager")
	if ach_mgr != null:
		for ach_id in ["first_blood", "boss_killer", "vampire_slayer",
				"rich_hunter", "throne_breaker", "weapon_master"]:
			ach_mgr.call("_unlock_achievement", String(ach_id))
	if main.game_over_ui != null:
		main.game_over_ui.show_game_over({
			"floor": 3, "rooms": 12, "wave": 24, "kills": 148,
			"level": 9, "survival_time": 742, "damage_taken": 231,
			"floors_cleared": 2,
		}, false)
		await create_timer(1.0).timeout
		await _shot("08_game_over_achievements")
		paused = false

	print("")
	if _fail == 0:
		print("✅ 截图全部完成")
	else:
		print("❌ 失败 %d" % _fail)
	quit(0 if _fail == 0 else 1)
