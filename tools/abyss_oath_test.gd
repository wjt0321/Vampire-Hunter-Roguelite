extends SceneTree
## 中段缩短、深渊誓约、结算提示。
## 用法: godot --headless --path . --script res://tools/abyss_oath_test.gd

var _fail: int = 0


func _initialize() -> void:
	_run()


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ✅ %s" % msg)
	else:
		print("  ❌ %s" % msg)
		_fail += 1


func _finish() -> void:
	GameConfig.abyss_level = 0
	print("")
	if _fail == 0:
		print("✅ 全部通过")
	else:
		print("❌ 失败 %d 项" % _fail)
	quit(0 if _fail == 0 else 1)


func _run() -> void:
	await process_frame
	print("\n====== 深渊誓约与中段节奏 ======")
	_test_room_counts()
	_test_oaths()
	await _test_victory_copy()
	await _test_build_hint()
	_test_dodge_line()
	_finish()


func _test_room_counts() -> void:
	print("\n=== 房间数 ===")
	var dm = load("res://scripts/map/dungeon_manager.gd").new()
	root.add_child(dm)
	GameConfig.abyss_level = 0
	dm.start_dungeon()
	_check(dm.current_floor == 1 and dm.get_room_count() == 7, "普通局从第 1 层 7 间开始")
	dm.current_floor = 2
	_check(dm.get_room_count() == 5, "第 2 层 5 间")
	dm.current_floor = 3
	_check(dm.get_room_count() == 5, "第 3 层 5 间")
	dm.current_floor = 4
	_check(dm.get_room_count() == 5, "第 4 层 5 间")
	dm.current_floor = 5
	_check(dm.get_room_count() == 7, "第 5 层仍是 7 间")
	_check(String(dm.floors_data[0].get("rule", "")) == "halls", "第 1 层规则仍是 halls")
	GameConfig.abyss_level = 1
	dm.start_dungeon()
	_check(dm.current_floor == 2, "深渊从第 2 层开局")
	dm.free()
	GameConfig.abyss_level = 0


func _test_oaths() -> void:
	print("\n=== 誓约 ===")
	GameConfig.abyss_level = 0
	_check(GameConfig.abyss_oath().is_empty() and not GameConfig.abyss_blocks_new_weapon("magic_book"),
		"普通局不禁武器")
	GameConfig.abyss_level = 1
	_check(String(GameConfig.abyss_oath().get("id", "")) == "ban_auto", "深渊 1 禁自动索敌")
	_check(GameConfig.abyss_blocks_new_weapon("magic_book") and not GameConfig.abyss_blocks_new_weapon("pistol"),
		"禁自动时魔法书进不了池，手枪可以")
	GameConfig.abyss_level = 2
	_check(String(GameConfig.abyss_oath().get("id", "")) == "ban_aimed", "深渊 2 禁鼠标瞄准")
	_check(GameConfig.abyss_blocks_new_weapon("flame_thrower") and not GameConfig.abyss_blocks_new_weapon("kunai"),
		"禁瞄准时喷火器进不了池，苦无可以")
	GameConfig.abyss_level = 3
	_check(GameConfig.abyss_spills_puddle(), "深渊 3 是药潮")
	GameConfig.abyss_level = 4
	_check(String(GameConfig.abyss_oath().get("id", "")) == "ban_auto", "深渊 4 回到禁自动")
	_check(GameConfig.abyss_rule_text().contains("禁自动") and GameConfig.abyss_rule_text().contains("第 2 层"),
		"楼层横幅能读到誓约和开局层：%s" % GameConfig.abyss_rule_text())
	GameConfig.abyss_level = 0


func _test_victory_copy() -> void:
	print("\n=== 胜利文案 ===")
	var ui = load("res://scenes/ui/game_over_ui.tscn").instantiate()
	root.add_child(ui)
	await process_frame
	ui.save_mgr = null
	GameConfig.abyss_level = 0
	ui.show_game_over({
		"floors_cleared": 5, "rooms": 20, "wave": 12, "kills": 40,
		"level": 10, "survival_time": 200, "damage_taken": 30, "abyss_level": 0,
	}, true)
	_check(ui.title_label.text.contains("月蚀女王"), "胜利标题是月蚀女王：%s" % ui.title_label.text)
	_check(ui.abyss_button != null and ui.abyss_button.text.contains("深入深渊 1"),
		"按钮仍指向深渊 1")
	_check(ui.abyss_button.text.contains("下一轮总计") and ui.abyss_button.text.contains("血 +15%"),
		"百分比口径还在：%s" % ui.abyss_button.text)
	_check(ui.abyss_button.text.contains("禁自动") and ui.abyss_button.text.contains("从第 2 层起"),
		"按钮写明下一轮誓约和开局层：%s" % ui.abyss_button.text)
	ui.free()


func _test_build_hint() -> void:
	print("\n=== 构筑提示 ===")
	var player = load("res://scenes/player/player.tscn").instantiate()
	root.add_child(player)
	var wm = load("res://scripts/weapons/weapon_manager.gd").new()
	root.add_child(wm)
	wm.setup(player, "pistol")
	wm.set_process(false)
	_check(wm.next_build_hint() == "", "手枪还是 1 级时不催进化")
	var pistol = wm.weapons[0]
	while int(pistol.current_level) < 4:
		pistol.level_up()
	var hint := String(wm.next_build_hint())
	_check(hint.contains("幸运四叶草") and hint.contains("神圣双管"), "差一级时写明被动和进化名：%s" % hint)
	pistol.level_up()
	var ready := String(wm.next_build_hint())
	_check(ready.contains("还差幸运四叶草") and ready.contains("神圣双管"), "满级缺被动时直接说还差什么：%s" % ready)
	wm.free()
	player.free()


func _test_dodge_line() -> void:
	print("\n=== 走位提示 ===")
	var log = load("res://scripts/managers/run_log.gd").new()
	root.add_child(log)
	log.note_hit("skeleton_archer", 12.0)
	var text := String(log.summary())
	_check(text.contains("横向走开"), "远程来源会告诉你横向走开：%s" % text)
	log.free()
