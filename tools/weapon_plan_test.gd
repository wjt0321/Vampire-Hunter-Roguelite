extends SceneTree
## 构筑能不能提前计划：图鉴写出两条结局，解锁层给满级机会。
## 用法: godot --headless --path . --script res://tools/weapon_plan_test.gd

var _fail: int = 0
var _roots: Array = []


func _initialize() -> void:
	_run()


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ✅ %s" % msg)
	else:
		print("  ❌ %s" % msg)
		_fail += 1


func _finish() -> void:
	print("")
	if _fail == 0:
		print("✅ 全部通过")
	else:
		print("❌ 失败 %d 项" % _fail)
	quit(0 if _fail == 0 else 1)


func _run() -> void:
	await process_frame
	print("\n====== 构筑计划：图鉴结局 + 解锁层养满 ======")
	var saves := root.get_node_or_null("SaveManager")
	_check(saves != null and "test_" in String(saves.save_path), "写入的是测试存档，不是玩家存档")
	if saves == null:
		_finish()
		return

	_test_endings(saves)
	await _test_codex_panel(saves)
	await _test_debut_floor(saves)
	for node in _roots:
		if is_instance_valid(node):
			node.free()
	_finish()


func _test_endings(saves: Node) -> void:
	print("\n=== 结局文案 ===")
	var script = load("res://scripts/weapons/weapon_manager.gd")
	if not script.has_method("codex_endings"):
		_check(false, "WeaponManager.codex_endings 提供图鉴用的两条结局")
		return
	var crossbow := String(script.codex_endings("crossbow"))
	_check("圣光弩" in crossbow and "幸运四叶草" in crossbow, "十字弩写明宝箱进化和需要的被动：%s" % crossbow)
	_check("雷矢" in crossbow and "闪电法杖" in crossbow, "十字弩写明融合搭档和融合名：%s" % crossbow)
	var pistol := String(script.codex_endings("pistol"))
	_check("神圣双管" in pistol and "没有融合" in pistol, "手枪只有宝箱进化，并写明没有融合：%s" % pistol)
	var chain := String(script.codex_endings("lightning_chain"))
	_check("雷神之怒" in chain and "十字弩" in chain and "雷矢" in chain, "闪电法杖同时写进化和被谁融合：%s" % chain)
	var spike := String(script.codex_endings("spike_tome"))
	_check("连刺法典" in spike and "没有融合" in spike, "后层武器也写自己的唯一结局：%s" % spike)
	saves.discover_codex("weapon", "crossbow")


func _test_codex_panel(saves: Node) -> void:
	print("\n=== 暂停图鉴 ===")
	saves.discover_codex("weapon", "crossbow")
	saves.discover_codex("weapon", "pistol")
	var pause = load("res://scenes/ui/pause_menu.tscn").instantiate()
	root.add_child(pause)
	_roots.append(pause)
	await process_frame
	pause._show_codex()
	var texts := _label_texts(pause.codex_list)
	var joined := "\n".join(texts)
	_check("雷矢" in joined and "圣光弩" in joined, "已发现的十字弩在图鉴里看得到两条结局")
	_check("神圣双管" in joined and "没有融合" in joined, "已发现的手枪在图鉴里写明没有融合")
	_check("连刺法典" not in joined, "没遇到过的地刺法典不提前泄露结局")


func _test_debut_floor(saves: Node) -> void:
	print("\n=== 解锁层可以养满 ===")
	var floor := _FloorStub.new()
	floor.current_floor = 4
	floor.add_to_group("dungeon_manager")
	root.add_child(floor)
	_roots.append(floor)

	var player = load("res://scenes/player/player.tscn").instantiate()
	root.add_child(player)
	_roots.append(player)
	var wm = load("res://scripts/weapons/weapon_manager.gd").new()
	root.add_child(wm)
	_roots.append(wm)
	wm.setup(player, "pistol")
	wm.set_process(false)
	var catalog = load("res://scripts/core/item_catalog.gd")
	for wid in ["shotgun", "kunai", "magic_book"]:
		wm.add_weapon(catalog.create_weapon(wid))
	_boost(_find(wm, "pistol"), 4)
	_boost(_find(wm, "shotgun"), 2)
	_boost(_find(wm, "kunai"), 3)
	_boost(_find(wm, "magic_book"), 3)
	_check(wm.weapons.size() == 4, "四个武器槽已满")

	var ui = load("res://scenes/ui/upgrade_ui.tscn").instantiate()
	root.add_child(ui)
	_roots.append(ui)
	_check(ui.has_method("_shape_hand"), "升级界面脚本能加载")
	if not ui.has_method("_shape_hand"):
		return
	ui.player = player
	ui.weapon_manager = wm
	await process_frame

	var filler := [
		{"id": "damage", "name": "攻击强化", "desc": "攻击", "type": "stat"},
		{"id": "speed", "name": "疾风步", "desc": "移速", "type": "stat"},
		{"id": "armor", "name": "铁壁防御", "desc": "护甲", "type": "stat"},
	]
	var locked_hand: Array = ui._shape_hand(filler.duplicate(true))
	_check(not _has_weapon(locked_hand, "spike_tome"), "还没解锁时，第 4 层不会把地刺法典塞进升级")

	saves.unlock_weapons_for_floor(4)
	_check(saves.is_weapon_unlocked("spike_tome") and not saves.is_weapon_unlocked("chain_gun"),
		"到达第 4 层解锁地刺法典，锁链枪仍锁着")
	var hand: Array = ui._shape_hand(filler.duplicate(true))
	var debut := _weapon_option(hand, "spike_tome")
	_check(not debut.is_empty(), "槽满的第 4 层，升级三选一里仍有地刺法典")
	_check(bool(debut.get("replace_lowest", false)), "槽满时这张卡会换下现有武器，而不是偷偷加第五把")
	_check("散弹枪" in String(debut.get("desc", "")), "卡面写明换下的是当前最低级的散弹枪：%s" % debut.get("desc", ""))

	if not debut.is_empty():
		ui._on_option_selected(debut)
	_check(_find(wm, "shotgun") == null and _find(wm, "spike_tome") != null, "选了之后散弹枪离槽，地刺法典进槽")
	var tome = _find(wm, "spike_tome")
	_check(tome != null and int(tome.current_level) == 1, "换下来的新武器从 Lv.1 开始（散弹枪是 Lv.2）")
	_check(wm.weapons.size() == 4, "换武器之后仍然是 4 个槽")

	var climb: Array = ui._shape_hand(filler.duplicate(true))
	var upgrade := _weapon_option(climb, "spike_tome")
	_check(not upgrade.is_empty() and not bool(upgrade.get("replace_lowest", false)),
		"拿到之后，同一层的下一手仍然给它升级，不再要求换槽")
	if not upgrade.is_empty():
		ui._submitted = false
		ui._on_option_selected(upgrade)
	var climbed = _find(wm, "spike_tome")
	_check(climbed != null and int(climbed.current_level) == 2, "选升级卡之后地刺法典升到 Lv.2")

	_boost(_find(wm, "spike_tome"), 5)
	var done: Array = ui._shape_hand(filler.duplicate(true))
	_check(not _has_weapon(done, "spike_tome"), "满级之后不再占着三选一")

	ui.banished_keys.append("weapon:chain_gun")
	floor.current_floor = 5
	saves.unlock_weapons_for_floor(5)
	var banned: Array = ui._shape_hand(filler.duplicate(true))
	_check(not _has_weapon(banned, "chain_gun"), "放逐过的解锁武器不再被塞回来")

	ui.banished_keys.clear()
	var floor_five: Array = ui._shape_hand(filler.duplicate(true))
	_check(_has_weapon(floor_five, "chain_gun"), "第 5 层同样把锁链枪放进升级")
	floor.current_floor = 2
	var early: Array = ui._shape_hand(filler.duplicate(true))
	_check(not _has_weapon(early, "chain_gun") and not _has_weapon(early, "spike_tome"),
		"离开解锁层之后，不再强制出现这两把")


func _boost(weapon, target: int) -> void:
	if weapon == null:
		return
	while int(weapon.current_level) < target:
		if not weapon.level_up():
			break


func _find(wm, weapon_id: String):
	for weapon in wm.weapons:
		if String(weapon.weapon_id) == weapon_id:
			return weapon
	return null


func _has_weapon(hand: Array, weapon_id: String) -> bool:
	return not _weapon_option(hand, weapon_id).is_empty()


func _weapon_option(hand: Array, weapon_id: String) -> Dictionary:
	for opt in hand:
		if String(opt.get("type", "")) == "weapon" and String(opt.get("id", "")) == weapon_id:
			return opt
	return {}


func _label_texts(node: Node) -> PackedStringArray:
	var out := PackedStringArray()
	if node is Label:
		out.append(node.text)
	for child in node.get_children():
		out.append_array(_label_texts(child))
	return out


class _FloorStub:
	extends Node
	var current_floor: int = 1
