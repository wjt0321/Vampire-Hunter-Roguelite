extends SceneTree
## 刺客改的是槽位和融合，血晶规则改的是开局问题。
## 用法: godot --headless --path . --script res://tools/meta_rules_test.gd

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
	GameConfig.configure_run(GameConfig.MAX_WEAPON_SLOTS, 5, 1, false, false)
	print("")
	if _fail == 0:
		print("✅ 全部通过")
	else:
		print("❌ 失败 %d 项" % _fail)
	quit(0 if _fail == 0 else 1)


func _run() -> void:
	await process_frame
	print("\n====== 角色规则与血晶规则 ======")
	_test_character()
	await _test_slots_and_fusion()
	_test_rules()
	_finish()


func _test_character() -> void:
	print("\n=== 刺客 ===")
	var chars: Array = load("res://scripts/player/character_data.gd").get_all_characters()
	var ids: PackedStringArray = PackedStringArray()
	var assassin = null
	for c in chars:
		ids.append(String(c.char_id))
		if c.char_id == "assassin":
			assassin = c
	_check(ids == PackedStringArray(["hunter", "priestess", "assassin"]), "可选角色是猎人、牧师、刺客")
	_check(assassin != null and int(assassin.weapon_slots) == 3 and int(assassin.fusion_level) == 4,
		"刺客是 3 槽、4 级融合")
	_check(assassin != null and String(assassin.initial_weapon) == "kunai" and int(assassin.unlock_cost) == 1500,
		"刺客从苦无开始，价格 1500")
	_check(not GameConfig.CHARACTER_UNLOCK_COSTS.has("mage") and not GameConfig.CHARACTER_UNLOCK_COSTS.has("knight"),
		"没有角色数据的法师和骑士不再标价")


func _test_slots_and_fusion() -> void:
	print("\n=== 槽位与融合 ===")
	var player = load("res://scenes/player/player.tscn").instantiate()
	root.add_child(player)
	var wm = load("res://scripts/weapons/weapon_manager.gd").new()
	root.add_child(wm)
	wm.set_process(false)
	GameConfig.configure_run(3, 4, 1, false, false)
	wm.setup(player, "kunai")
	var catalog = load("res://scripts/core/item_catalog.gd")
	_check(wm.add_weapon(catalog.create_weapon("crossbow")), "第 2 把可以进槽")
	_check(wm.add_weapon(catalog.create_weapon("lightning_chain")), "第 3 把可以进槽")
	_check(not wm.add_weapon(catalog.create_weapon("shotgun")), "第 4 把被 3 槽拦住")
	_boost(wm, "crossbow", 4)
	_boost(wm, "lightning_chain", 4)
	var early: Dictionary = wm.get_fusion_offer()
	_check(String(early.get("id", "")) == "thunder_bolt", "4 级就能融出雷矢：%s" % str(early.get("id", "")))
	GameConfig.configure_run(4, 5, 2, false, false)
	_check(wm.get_fusion_offer().is_empty(), "要求 5 级时，4 级还不能融合")
	_boost(wm, "crossbow", 5)
	_boost(wm, "lightning_chain", 5)
	_check(wm.apply_fusion("thunder_bolt"), "第一次融合成功")
	_check(wm.add_weapon(catalog.create_weapon("shotgun")), "融合空出槽位后可以再拿散弹")
	_check(wm.add_weapon(catalog.create_weapon("poison_cloud")), "再拿毒雾")
	_boost(wm, "shotgun", 5)
	_boost(wm, "poison_cloud", 5)
	var second: Dictionary = wm.get_fusion_offer()
	_check(String(second.get("id", "")) == "miasma_shot", "第二次融合仍然出现：%s" % str(second.get("id", "")))
	_check(wm.apply_fusion("miasma_shot"), "第二次融合成功")
	_check(wm.get_fusion_offer().is_empty(), "两次之后不再给融合")
	wm.free()
	player.free()
	GameConfig.configure_run(4, 5, 1, false, false)


func _test_rules() -> void:
	print("\n=== 血晶规则 ===")
	var saves := root.get_node("SaveManager")
	saves.add_blood_crystals(2000)
	_check(not saves.purchase_rule("no_such"), "不存在的规则买不了")
	_check(saves.purchase_rule("early_arms"), "买下提前武装")
	_check(saves.has_rule("early_arms") and not saves.purchase_rule("early_arms"), "同一条规则不能买第二次")
	GameConfig.configure_run(4, 5, 1, true, true)
	_check(GameConfig.effective_unlock_floor(4) == 3 and GameConfig.effective_unlock_floor(0) == 0,
		"提前武装把第 4 层武器挪到第 3 层，普通武器不动")
	_check(GameConfig.banish_count() == 4, "多一次放逐后是 4 次")
	saves.unlock_weapons_for_floor(2)
	_check(saves.is_weapon_unlocked("repeater") and not saves.is_weapon_unlocked("spike_tome"),
		"第 2 层提前拿到连珠火铳，地刺法典还要等到第 3 层")
	_check(saves.purchase_rule("second_fusion") and saves.purchase_rule("extra_banish"), "另外两条规则也能买")
	GameConfig.configure_run(4, 5, 1, false, false)


func _boost(wm, weapon_id: String, target: int) -> void:
	for weapon in wm.weapons:
		if String(weapon.weapon_id) != weapon_id:
			continue
		while int(weapon.current_level) < target:
			if not weapon.level_up():
				break
