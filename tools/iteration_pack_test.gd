extends SceneTree
## 资产槽、遭遇小队、房间预告。
## godot --headless --path . --script res://tools/iteration_pack_test.gd

const Slots = preload("res://scripts/core/asset_slots.gd")
const Director = preload("res://scripts/map/encounter_director.gd")
const DungeonScript = preload("res://scripts/map/dungeon_manager.gd")

var _pass: int = 0
var _fail: int = 0


func _initialize() -> void:
	_run()


func _check(ok: bool, label: String) -> void:
	if ok:
		_pass += 1
		print("✅ %s" % label)
	else:
		_fail += 1
		print("❌ %s" % label)


func _run() -> void:
	_test_slots()
	_test_encounters()
	_test_preview()
	print("通过 %d / 失败 %d" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)


func _test_slots() -> void:
	_check(Slots.enemy_path("shield_guard") == "res://assets/sprites/enemies/shield_guard/idle.png",
		"盾卫正式图路径固定")
	_check(Slots.boss_path("blood_lord", "charge") == "res://assets/sprites/boss/blood_lord/charge.png",
		"血铠领主冲锋图路径固定")
	_check(Slots.weapon_icon_path("scythe") == "res://assets/weapons/icons/scythe.png", "回旋镰图标路径固定")
	var missing_tex: Texture2D = Slots.texture_at(Slots.enemy_path("shield_guard"))
	_check(missing_tex == null, "还没放进去的图不会假装已经有了")
	var missing: Array = []
	for enemy_id in ["shield_guard", "blood_hound", "blood_priest", "web_weaver", "burrower", "gem_leech", "coffin_guard", "lantern_wraith", "alchemist_pitcher", "furnace_golem", "resonance_mage", "moon_wing"]:
		if not Director.covers_enemy(enemy_id):
			missing.append(enemy_id)
	_check(missing.is_empty(), "十二种新敌人都进了至少一个遭遇模板")


func _test_encounters() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var first: Dictionary = Director.plan(1, "", rng)
	_check(first["id"] == "shield_wall" and String(first["second"]) == "", "第 1 层只有盾墙，不衔接第二队")
	var again: Dictionary = Director.plan(1, "shield_wall", rng)
	_check(again["id"] == "shield_wall", "第 1 层没有别的模板时仍给出盾墙")
	var linked: Dictionary = Director.plan(2, "", rng)
	_check(String(linked["second"]) != "" and linked["spawns"].size() > 3, "第 2 层可以把两队接在同一间")
	var follow: Dictionary = Director.plan(2, String(linked["id"]), rng)
	_check(follow["id"] != linked["id"], "连续两间不重复同一主模板")
	_check("elite_guard" in Director.template_ids_for_floor(4), "第 4 层会出护卫精英")
	var kept := false
	for _n in 12:
		for entry in Director.plan(4, "", rng)["spawns"]:
			if bool(entry.get("elite", false)):
				kept = true
	_check(kept, "第 4 层精英标记会留在护卫身上")
	var early: Dictionary = Director.plan(2, "", rng)
	var early_elite := false
	for entry in early["spawns"]:
		if bool(entry.get("elite", false)):
			early_elite = true
	_check(not early_elite, "第 2 层的小队不带精英")


func _test_preview() -> void:
	var dungeon = DungeonScript.new()
	dungeon.start_dungeon()
	var saw := false
	for _i in 6:
		var choices: Array = dungeon.peek_room_choices()
		if not choices.is_empty() and String(choices[0].get("variant", "")) != "":
			saw = true
			_check(String(choices[0]["detail"]) != "", "变体房的门口写了风险和收益")
			break
		dungeon.consume_room()
	_check(saw, "一层里能看到下一间的变体预告")
	dungeon.free()
