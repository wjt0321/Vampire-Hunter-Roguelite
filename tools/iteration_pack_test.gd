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


func _run() -> void:
	_test_slots()
	_test_encounters()
	_test_preview()
	await _test_build_and_shop()
	print("通过 %d / 失败 %d" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)


func _check(ok: bool, label: String) -> void:
	if ok:
		_pass += 1
		print("✅ %s" % label)
	else:
		_fail += 1
		print("❌ %s" % label)


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
		var danger := ""
		var plain_door := false
		for choice in choices:
			if String(choice.get("variant", "")) != "":
				danger = String(choice.get("detail", ""))
			if String(choice.get("choice_id", "")) == "combat":
				plain_door = true
		if danger != "":
			saw = true
			_check(danger != "" and choices.size() >= 2 and plain_door, "变体房同时有普通门和写明风险的凶险门")
			break
		dungeon.consume_room()
	_check(saw, "一层里能看到下一间的变体预告")
	dungeon.free()
	var routed = DungeonScript.new()
	routed.start_dungeon()
	var declined := false
	for _j in 8:
		var door_choices: Array = routed.peek_room_choices()
		var has_danger := false
		for door in door_choices:
			if String(door.get("choice_id", "")).begins_with("variant:"):
				has_danger = true
		if has_danger:
			_check(routed.choose_next("combat"), "可以选择普通门")
			routed.consume_room()
			_check(routed.current_variant() == "", "选普通门后这一间没有凶险修饰")
			declined = true
			break
		routed.consume_room()
	_check(declined, "普通门能拒绝凶险房")
	var config = load("res://scripts/core/game_config.gd")
	_check(config.room_variant_for_floor(4) == "armored_patrol", "第 4 层凶险房是重甲巡行")
	_check(config.room_variant_for_floor(5) == "hunter_hall", "第 5 层凶险房是猎手走廊")
	_check(config.room_safe_variant_for_floor(5) == "quiet_antechamber", "第 5 层安全门是寂静前厅")
	routed.free()


func _test_build_and_shop() -> void:
	var host := Node2D.new()
	root.add_child(host)
	current_scene = host
	var player = load("res://scenes/player/player.tscn").instantiate()
	host.add_child(player)
	await process_frame
	var mark = load("res://scripts/player/passive_item_data.gd").create_execution_mark()
	player.add_passive_item(mark)
	var elite = load("res://scenes/enemies/zombie.tscn").instantiate()
	elite.elite_affix = "haster"
	elite.player = player
	host.add_child(elite)
	await process_frame
	elite.max_hp = 200.0
	elite.current_hp = 200.0
	elite.take_damage(10.0)
	var after_first: float = elite.current_hp
	elite.take_damage(10.0)
	_check(elite.current_hp < after_first - 10.0, "处刑印记打同一个精英会越来越疼")
	var other = load("res://scenes/enemies/zombie.tscn").instantiate()
	other.elite_affix = "haster"
	other.player = player
	host.add_child(other)
	await process_frame
	other.max_hp = 200.0
	other.current_hp = 200.0
	other.take_damage(10.0)
	_check(player.execution_stacks == 1, "换目标后印记清空重计")

	var chilled = load("res://scenes/enemies/zombie.tscn").instantiate()
	chilled.player = player
	host.add_child(chilled)
	await process_frame
	chilled.max_hp = 100.0
	chilled.current_hp = 100.0
	chilled.bleed_remaining = 2.0
	chilled.bleed_dps = 1.0
	chilled._slow_remaining = 2.0
	player.has_cold_blood = true
	player.cold_blood_damage = 8.0
	chilled.take_damage(10.0)
	_check(chilled.current_hp <= 82.0, "寒血反应在流血又霜缚时额外崩开")

	var weapons = load("res://scripts/weapons/weapon_manager.gd").new()
	host.add_child(weapons)
	weapons.set_process(false)
	weapons.setup(player, "pistol")
	weapons.add_weapon(weapons._create_weapon_by_id("pistol"))
	weapons.add_weapon(weapons._create_weapon_by_id("pistol"))
	_check(weapons.apply_recast("pistol", "shotgun"), "重铸把未进化的手枪换成散弹")
	_check(String(weapons.weapons[0].weapon_id) == "shotgun" and int(weapons.weapons[0].current_level) == 2,
		"重铸后的武器低一级")
	weapons.weapons[0].fused = true
	_check(not weapons.apply_recast("shotgun", "pistol"), "融合后的武器不能再重铸")
	weapons.weapons[0].fused = false
	player.has_time_gear = true
	player.time_gear_scale = 1.25
	var knife = weapons._create_weapon_by_id("throwing_knife")
	var base_speed: float = knife.get_scaled_bullet_speed()
	var base_pierce: int = knife.get_scaled_pierce_count()
	weapons._spawn_bullet(player.global_position, Vector2.RIGHT, knife)
	await process_frame
	var slowed: Node = null
	for node in host.get_children():
		if node.has_method("set_pierce_count") and node.get("direction") == Vector2.RIGHT:
			slowed = node
	_check(slowed != null and is_equal_approx(float(slowed.speed), base_speed * 0.72)
		and int(slowed.max_pierce) == base_pierce + 1, "时滞齿轮让飞刀变慢并多穿一层")

	var shop = load("res://scripts/ui/room_shop.gd").new()
	host.add_child(shop)
	shop.carried_offer = {"id": "heal", "name": "血瓶", "type": "consumable", "price": 10, "desc": "恢复"}
	player.silver = 100
	shop.open(player, weapons, 2)
	_check(String(shop._offers[0].get("id", "")) == "heal" and shop._locked[0], "锁定的商品会进下一间商店")
	shop._locked[0] = true
	shop.close()
	_check(String(shop.carried_offer.get("id", "")) == "heal", "离开时只带走这一件")
	shop.carried_offer = {}
	shop.open(player, weapons, 3)
	var heal_price := -1
	for offer in shop._offers:
		if String(offer.get("id", "")) == "heal":
			heal_price = int(offer.get("price", -1))
	_check(heal_price == 10, "没锁货时血瓶也在，价格是 10")
	_check(String(weapons.dismantle_warning("berserker_blood")).contains("毁灭者"), "拆解会写明哪条进化会失效")
	var silver_before: int = player.silver
	shop._confirm_dismantle("execution_mark")
	_check(player.passive_items.is_empty() and player.silver == silver_before + 8, "拆掉一级被动并退 8 银")
	_check(is_equal_approx(player.execution_bonus_per_stack, 0.0), "拆掉后处刑印记不再叠伤")
	var events = load("res://scripts/managers/room_event_manager.gd").new()
	host.add_child(events)
	events.player = player
	events._start_seals()
	player.global_position = events._seals[0].global_position
	events._process_seals(0.4, false)
	var kept_seal: float = float(events._seal_time[0])
	player.global_position += Vector2(500, 0)
	events._process_seals(0.3, false)
	_check(is_equal_approx(float(events._seal_time[0]), kept_seal) and float(events._seal_time[1]) < 0.05,
		"离开封印圈不会把进度清掉")
	shop.close()

	var warden = load("res://scenes/enemies/tomb_warden.tscn").instantiate()
	warden.skip_intro = true
	host.add_child(warden)
	await process_frame
	var ward: Node = warden.ward
	paused = true
	_check(is_instance_valid(warden) and is_instance_valid(ward), "暂停时守望者和结界都还在")
	paused = false
	warden.queue_free()
	await process_frame
	_check(not is_instance_valid(ward), "守望者离场时结界一起清掉")
	var log = load("res://scripts/managers/run_log.gd").new()
	host.add_child(log)
	log.note_room(2, "combat", "blood_tide", "shield_wall")
	log.note_shop("reroll", 8)
	log.note_dealt("手枪", 40.0)
	log.note_dealt("飞刀", 15.0)
	log.note_kill("手枪", "zombie")
	var text := String(log.summary())
	_check(text.contains("第 2 层") and text.contains("重抽 1 次"), "结算复盘写得出本层和商店")
	_check(text.contains("主要输出：手枪") and text.contains("最后一击：手枪 打死 zombie"), "复盘写得出主要输出和最后一击")
	var saves := root.get_node_or_null("SaveManager")
	if saves != null and saves.has_method("discover_codex"):
		saves.discover_codex("enemy", "shield_bearer")
		_check(saves.codex_known("enemy", "shield_bearer") and not saves.codex_known("enemy", "moon_hunter"),
			"图鉴记下见过的敌人，没见过的保持未知")
	else:
		_check(false, "图鉴记下见过的敌人，没见过的保持未知")
	_check(shop.REROLL_COSTS[0] == 8 and shop.REROLL_COSTS[1] == 14, "重抽价格从 8 涨到 14")
