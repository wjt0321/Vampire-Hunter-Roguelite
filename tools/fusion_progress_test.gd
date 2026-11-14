extends SceneTree
## 融合可见目标回归：进度文案随等级走、满级双持报"可融合"、升级手牌里出现融合卡、
## 升级界面 footer 常驻进度线。证据来源：机器模拟随机政策 3 整局融合 0 触发。

var _pass := 0
var _fail := 0

func _check(ok: bool, label: String) -> void:
	if ok:
		_pass += 1
		print("✅ %s" % label)
	else:
		_fail += 1
		print("❌ %s" % label)

func _wait(test: Callable, seconds: float) -> bool:
	var elapsed := 0.0
	while elapsed < seconds:
		if test.call():
			return true
		await create_timer(0.05, true).timeout
		elapsed += 0.05
	return bool(test.call())

func _initialize() -> void:
	_run()

func _run() -> void:
	await process_frame
	var save: Node = root.get_node("SaveManager")
	save.use_test_save_path("fusion_progress_test")
	var game: Node = load("res://scenes/main.tscn").instantiate()
	game.debug_force_character = "hunter"
	root.add_child(game)
	current_scene = game
	_check(await _wait(func(): return game.wave_manager.is_active, 20.0), "局正常开起来")
	game.wave_manager.stop()
	var wm: Node = game.weapon_manager
	# 清掉开局手枪以外的干扰：只留配方两把
	for w in wm.weapons.duplicate():
		if String(w.weapon_id) != "pistol":
			wm.weapons.erase(w)
	_check(wm.add_weapon(ItemCatalog.create_weapon("crossbow")), "加入十字弩")
	_check(wm.add_weapon(ItemCatalog.create_weapon("lightning_chain")), "加入闪电法杖")
	var crossbow = null
	var lightning = null
	for w in wm.weapons:
		if String(w.weapon_id) == "crossbow":
			crossbow = w
		elif String(w.weapon_id) == "lightning_chain":
			lightning = w
	crossbow.current_level = 3
	lightning.current_level = 2
	var progress: String = wm.get_fusion_progress()
	_check(progress.contains("雷矢") and progress.contains("Lv.3/5") and progress.contains("Lv.2/5"),
		"进度文案报最接近配方与双方等级：%s" % progress)
	game.upgrade_ui.show_upgrade(game.player, wm)
	await process_frame
	_check(String(game.upgrade_ui._hint_label.text).contains("雷矢"), "升级界面 footer 常驻融合进度")
	game.upgrade_ui._on_skip()
	_check(await _wait(func(): return not game.upgrade_ui.visible, 2.0), "跳过关闭")
	crossbow.current_level = 5
	lightning.current_level = 5
	_check(wm.get_fusion_progress().contains("可融合"), "双满级报可融合：%s" % wm.get_fusion_progress())
	game.upgrade_ui.show_upgrade(game.player, wm)
	await process_frame
	var has_fusion_card := false
	for opt in game.upgrade_ui.current_options:
		if String(opt.get("type", "")) == "fusion":
			has_fusion_card = true
	_check(has_fusion_card, "满级双持时手牌里出现融合卡")
	game.upgrade_ui._on_skip()
	_check(await _wait(func(): return not game.upgrade_ui.visible, 2.0), "跳过关闭")

	# --- 换槽保护：凑对中的武器不被解锁层插卡拆掉 ---
	for w in wm.weapons.duplicate():
		wm.weapons.erase(w)
	for id in ["crossbow", "lightning_chain", "scythe", "repeater"]:
		wm.add_weapon(ItemCatalog.create_weapon(id))
	for w in wm.weapons:
		match String(w.weapon_id):
			"crossbow", "lightning_chain":
				w.current_level = 2
			_:
				w.current_level = 4
	_check(wm.replace_lowest_with("chain_gun"), "满槽换槽成功")
	var ids: Array = []
	for w in wm.weapons:
		ids.append(String(w.weapon_id))
	_check("crossbow" in ids and "lightning_chain" in ids and "chain_gun" in ids,
		"换下的是非配方武器，凑对中的两把保住：%s" % str(ids))
	# 四槽全在凑对时回退旧规则，不能白丢卡
	for w in wm.weapons.duplicate():
		wm.weapons.erase(w)
	for id in ["crossbow", "lightning_chain", "shotgun", "poison_cloud"]:
		wm.add_weapon(ItemCatalog.create_weapon(id))
	_check(wm.replace_lowest_with("chain_gun"), "全凑对时仍换得动（回退旧规则）")
	print("\nRESULT fusion_progress pass=%d fail=%d" % [_pass, _fail])
	game.queue_free()
	await process_frame
	quit(1 if _fail else 0)