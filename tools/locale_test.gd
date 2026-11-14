extends SceneTree
## 中英本地化回归：CSV 覆盖、tr 行为、en 下各面板无中文残留。
var passed := 0
var failed := 0
var host: Node2D
var cjk := RegEx.new()

func _initialize() -> void:
	cjk.compile("[\\x{4e00}-\\x{9fff}]")
	_run()

func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("PASS ", label)
	else:
		failed += 1
		print("FAIL ", label)

func scan(node: Node, label: String) -> void:
	var bad: Array = []
	for n in node.find_children("*", "", true, false):
		var t := ""
		if n is Label or n is Button or n is OptionButton or n is CheckButton:
			t = String(n.text)
		elif n is RichTextLabel:
			t = n.get_parsed_text()
		if t != "" and cjk.search(t) != null:
			bad.append(t)
	check(bad.is_empty(), label + ("" if bad.is_empty() else " bad=" + str(bad.slice(0, 3))))

func _run() -> void:
	await process_frame
	host = Node2D.new()
	root.add_child(host)
	current_scene = host
	var save = root.get_node("SaveManager")

	# CSV 覆盖：每行 en 非空，zh_CN 与键一致。
	var f := FileAccess.open("res://i18n/game.csv", FileAccess.READ)
	check(f != null, "csv opens")
	var rows := 0
	var empty_en := 0
	var zh_mismatch := 0
	if f != null:
		f.get_csv_line()  # header
		while not f.eof_reached():
			var line := f.get_csv_line()
			if line.size() < 3:
				continue
			rows += 1
			if line[2] == "":
				empty_en += 1
			if line[0] != line[1]:
				zh_mismatch += 1
	check(rows >= 600, "csv rows >= 600 (%d)" % rows)
	check(empty_en == 0, "csv en column complete (%d empty)" % empty_en)
	check(zh_mismatch == 0, "csv zh_CN equals key (%d mismatch)" % zh_mismatch)

	# zh_CN：键即原文。
	TranslationServer.set_locale("zh_CN")
	check(tr("手枪") == "手枪", "zh weapon name passthrough")
	check(tr("银币 %d") % 7 == "银币 7", "zh format template")
	check(tr("not_a_key") == "not_a_key", "unknown key passthrough")

	# en：模板与数据键都翻。
	TranslationServer.set_locale("en")
	check(tr("手枪") == "Pistol", "en weapon name")
	check(tr("第 %d 层") % 3 == "Floor 3", "en format template")
	check(tr("月蚀女王") == "Eclipse Queen", "en boss title")
	check(tr("第一滴血") == "First Blood", "en achievement name")
	check(tr("经验宝石、银币") == "XP gems, silver", "en codex drops")
	check(tr("操作说明\n走位：WASD / 左摇杆 · 瞄准：鼠标 / 右摇杆\n键盘：R 重抽 · B 放逐 · Tab 跳过 · ESC 暂停\n手柄：X 重抽 · Y 放逐 · B 跳过 · A 确认 · Start 暂停\n武器默认自动开火").begins_with("Controls"), "en multiline controls card")

	# 语言设置持久化。
	save.set_language("en")
	check(String(save.save_data["settings"]["language"]) == "en" and TranslationServer.get_locale() == "en", "set_language persists en")
	save.set_language("xx")
	check(String(save.save_data["settings"]["language"]) == "zh_CN", "set_language rejects unknown")
	save.set_language("en")

	# en 下逐面板扫描。
	var player = load("res://scenes/player/player.tscn").instantiate()
	host.add_child(player)
	player.set_physics_process(false)
	var weapons = load("res://scripts/weapons/weapon_manager.gd").new()
	host.add_child(weapons)
	weapons.setup(player)
	weapons.set_process(false)

	var menu = load("res://scenes/ui/main_menu.tscn").instantiate()
	host.add_child(menu)
	await process_frame
	scan(menu, "en main_menu")

	var chars = load("res://scenes/ui/character_select.tscn").instantiate()
	host.add_child(chars)
	chars.show_selection()
	await process_frame
	scan(chars, "en character_select")

	var meta_shop = load("res://scenes/ui/upgrade_shop.tscn").instantiate()
	host.add_child(meta_shop)
	meta_shop.show_shop()
	await process_frame
	scan(meta_shop, "en upgrade_shop")

	var hud = load("res://scenes/ui/hud.tscn").instantiate()
	host.add_child(hud)
	hud.update_silver(12)
	hud.update_wave(2)
	hud.update_kills(3)
	hud.update_room(4)
	hud.update_dungeon(1, 2, 5, "血月回廊")
	await process_frame
	scan(hud, "en hud")

	var upgrade = load("res://scenes/ui/upgrade_ui.tscn").instantiate()
	host.add_child(upgrade)
	upgrade.show_upgrade(player, weapons)
	await process_frame
	scan(upgrade, "en upgrade_ui")
	PauseController.release(upgrade)

	var shop = load("res://scripts/ui/room_shop.gd").new()
	host.add_child(shop)
	shop.open(player)
	await process_frame
	scan(shop, "en room_shop")
	shop.close()

	var pause = load("res://scenes/ui/pause_menu.tscn").instantiate()
	host.add_child(pause)
	await process_frame
	scan(pause, "en pause_menu")
	pause.retranslate()
	await process_frame
	scan(pause, "en pause_menu after retranslate")

	var pact = load("res://scripts/ui/blood_pact_ui.gd").new()
	host.add_child(pact)
	pact.open(player, 1)
	await process_frame
	scan(pact, "en blood_pact_ui")
	pact.close()

	var daily = load("res://scripts/ui/daily_challenge_panel.gd").new()
	host.add_child(daily)
	daily.open_today(save)
	await process_frame
	scan(daily, "en daily_challenge_panel")

	var banner = load("res://scripts/ui/floor_banner.gd").new()
	host.add_child(banner)
	banner.show_card("每日 · ", "血月回廊", "第1层", "地上的网会拖慢脚步，绕开或打掉。盾卫挡正面", Color.RED, 0.1)
	await process_frame
	scan(banner, "en floor_banner")

	var boss_bar = load("res://scenes/ui/boss_hp_bar.tscn").instantiate()
	host.add_child(boss_bar)
	boss_bar.show_boss_bar("月蚀女王")
	await process_frame
	scan(boss_bar, "en boss_hp_bar")

	var notify = load("res://scenes/ui/achievement_notification.tscn").instantiate()
	host.add_child(notify)
	notify._on_achievement_unlocked("first_blood", "第一滴血")
	await process_frame
	scan(notify, "en achievement_notification")

	var over = load("res://scenes/ui/game_over_ui.tscn").instantiate()
	host.add_child(over)
	over.show_game_over({"kills": 5, "floor": 2, "rooms": 3, "wave": 4, "level": 6, "time": 130, "damage_taken": 40.0, "crystals": 12}, false)
	await process_frame
	scan(over, "en game_over_ui")
	PauseController.release(over)

	# 切回中文：场景与 tr 都回到原文。
	save.set_language("zh_CN")
	check(tr("手枪") == "手枪", "zh restored after set_language")
	menu.queue_free()
	await process_frame
	var menu2 = load("res://scenes/ui/main_menu.tscn").instantiate()
	host.add_child(menu2)
	await process_frame
	var start_label: Label = null
	for l in menu2.find_children("", "Label", true, false):
		if String(l.text) == "开始游戏":
			start_label = l
			break
	check(start_label != null, "zh scene text on load")

	host.queue_free()
	await process_frame
	print("RESULT locale: %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)