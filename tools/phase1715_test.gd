extends SceneTree
## 17.15 回归：地图事件房、每日挑战、深渊词缀
## 用法: godot --headless --path . --script res://tools/phase1715_test.gd

const DUNGEON_SCRIPT := "res://scripts/map/dungeon_manager.gd"
const DAILY_SCRIPT = preload("res://scripts/core/daily_challenge.gd")

var _fail: int = 0
var _pass: int = 0


class FakeSave extends "res://scripts/managers/save_manager.gd":
	var save_calls: int = 0

	func save_game() -> void:
		save_calls += 1


func _initialize() -> void:
	_run()


func _check(ok: bool, label: String) -> void:
	if ok:
		_pass += 1
		print("✅ %s" % label)
	else:
		_fail += 1
		print("❌ %s" % label)


func _finish() -> void:
	GameConfig.abyss_level = 0
	GameConfig.clear_daily()
	print("")
	print("通过 %d / 失败 %d" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)


func _new_dungeon(seed_value: int = -1):
	var dm = load(DUNGEON_SCRIPT).new()
	if seed_value >= 0:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		dm.use_rng(rng)
	dm.start_dungeon()
	return dm


func _plan_ok(dm) -> bool:
	var plan: Array = dm.get_room_plan()
	if plan.is_empty() or plan[0] != "combat" or plan[plan.size() - 1] != "boss":
		return false
	if plan.size() != dm.get_room_count():
		return false
	var specials := 0
	for room in plan:
		if room in ["shop", "treasure", "rest"]:
			specials += 1
		elif room != "combat" and room != "boss":
			return false
	return specials == dm.get_special_count()


func _fork_ok(dm) -> bool:
	var plan: Array = dm.get_room_plan()
	var forks: Dictionary = dm.get_forks()
	if forks.size() != GameConfig.map_event_forks(dm.current_floor):
		return false
	var seen: Dictionary = {}
	for key in forks.keys():
		var idx := int(key)
		if idx <= 0 or idx >= plan.size() - 1:
			return false
		if String(plan[idx]) != "combat":
			return false
		var event_type := String(forks[key])
		if event_type not in GameConfig.MAP_EVENT_TYPES:
			return false
		if seen.has(event_type):
			return false
		seen[event_type] = true
	return true


func _signature(dm) -> String:
	var text := ""
	for room in dm.get_room_plan():
		text += String(room) + ","
	var forks: Dictionary = dm.get_forks()
	var keys: Array = forks.keys()
	keys.sort()
	for key in keys:
		text += "|%s=%s" % [str(key), str(forks[key])]
	return text


func _run() -> void:
	print("\n====== 17.15 地图事件房 / 每日 / 深渊词缀 ======")
	_test_forks()
	_test_choice()
	_test_mutation_and_mirror()
	_test_loot_parts()
	_test_daily()
	_test_daily_board()
	_test_abyss_rules()
	await _test_speed_heal_and_shots()
	_finish()


func _test_forks() -> void:
	print("\n--- 岔路结构 ---")
	var bad := 0
	for i in 40:
		var dm = _new_dungeon()
		for _floor in 3:
			if not _plan_ok(dm) or not _fork_ok(dm):
				bad += 1
			if not dm.advance_floor():
				break
		dm.free()
	_check(bad == 0, "40 局三层：原计划合法，岔路只挂在战斗房上（问题 %d）" % bad)

	var a = _new_dungeon(4242)
	var b = _new_dungeon(4242)
	_check(_signature(a) == _signature(b), "同一地图种子，房间序列和岔路相同")
	var c = _new_dungeon(4243)
	_check(a.get_room_plan().size() == b.get_room_plan().size(), "同种子的房间数一致")
	_check(c.get_room_plan().size() > 0, "另一颗种子也能生成房间")
	a.free()
	b.free()
	c.free()


func _test_choice() -> void:
	print("\n--- 选路 ---")
	var dm = _new_dungeon(7)
	var found := false
	var plan_before: Array = dm.get_room_plan()
	while dm.room_in_floor < dm.get_room_count():
		var choices: Array = dm.peek_room_choices()
		if choices.size() >= 2:
			var event_type := String(choices[1].get("type", ""))
			_check(event_type in GameConfig.MAP_EVENT_TYPES, "右门是事件房（%s）" % event_type)
			_check(String(choices[0].get("type", "")) == "combat", "左门仍是原计划的战斗房")
			_check(not dm.choose_next("boss"), "不能把岔路选成 Boss 跳关")
			_check(dm.choose_next(event_type), "可以选择事件房")
			var got := String(dm.consume_room())
			_check(got == event_type, "consume 返回选中的事件房（%s）" % got)
			_check(dm.get_room_plan() == plan_before, "选择不改写原计划表")
			found = true
			break
		else:
			dm.consume_room()
	_check(found, "这颗种子的第一层确实有岔路")

	var plain = _new_dungeon(11)
	# 走到第一个岔路，拒绝非法选择后应得到战斗房
	var saw_default := false
	while plain.room_in_floor < plain.get_room_count():
		if plain.peek_room_choices().size() >= 2:
			_check(not plain.choose_next("shop"), "岔路上没有商店门时不能选商店")
			_check(plain.consume_room() == "combat", "不选事件房就进原计划的战斗房")
			saw_default = true
			break
		plain.consume_room()
	_check(saw_default, "默认路径覆盖到了岔路")
	dm.free()
	plain.free()


func _test_mutation_and_mirror() -> void:
	print("\n--- 变异与镜像 ---")
	_check(is_equal_approx(GameConfig.mutation_cost(100.0), 25.0), "100 血的献血代价是 25")
	_check(GameConfig.can_mutation_gamble(100.0, 100.0), "满血可以豪赌")
	_check(GameConfig.can_mutation_gamble(26.0, 100.0), "扣完还剩 1 点时可以豪赌")
	_check(not GameConfig.can_mutation_gamble(25.0, 100.0), "扣完会落到 0 的残血不能豪赌")
	var win: Dictionary = GameConfig.roll_mutation(0.0)
	var lose: Dictionary = GameConfig.roll_mutation(0.55)
	_check(bool(win.get("win")) and int(win.get("xp")) == GameConfig.MUTATION_WIN_XP, "0 点是赢")
	_check(not bool(lose.get("win")) and int(lose.get("xp")) == 0, "刚好等于胜率的点数是输")
	_check(is_equal_approx(GameConfig.mirror_x(200.0, 640.0), 1080.0), "镜像把 200 翻到 1080")
	_check(is_equal_approx(GameConfig.mirror_x(640.0, 640.0), 640.0), "中线上的点不动")


func _test_loot_parts() -> void:
	print("\n--- 掉落四段 ---")
	var wm = load("res://scripts/managers/wave_manager.gd").new()
	GameConfig.abyss_level = 0
	_check(is_equal_approx(wm.effective_loot_mult(), 1.0), "默认掉落倍率是 1")
	wm.loot_mult = 1.3
	wm.loot_bonus_mult = GameConfig.DAILY_BOUNTY_MULT
	wm.set_room_loot_mult(GameConfig.FOG_LOOT_MULT)
	GameConfig.abyss_level = 2
	var expect: float = 1.3 * GameConfig.DAILY_BOUNTY_MULT * GameConfig.FOG_LOOT_MULT * 1.2
	_check(is_equal_approx(wm.effective_loot_mult(), expect),
		"契约 × 赏金 × 迷雾 × 深渊 = %.3f" % wm.effective_loot_mult())
	GameConfig.abyss_level = 0
	wm.free()


func _test_daily() -> void:
	print("\n--- 每日词缀 ---")
	var one: Dictionary = DAILY_SCRIPT.build("2026-11-08")
	var two: Dictionary = DAILY_SCRIPT.build("2026-11-08")
	_check(one.get("seed") == two.get("seed"), "同一天种子相同")
	var ids_a: Array = []
	var ids_b: Array = []
	for entry in one.get("modifiers", []):
		ids_a.append(String(entry.get("id", "")))
	for entry in two.get("modifiers", []):
		ids_b.append(String(entry.get("id", "")))
	_check(ids_a == ids_b and ids_a.size() == 2, "同一天抽出两条相同词缀（%s）" % str(ids_a))
	_check(ids_a[0] != ids_a[1], "两条词缀不重复")
	var known := true
	for id in ids_a:
		if GameConfig.daily_def(String(id)).is_empty():
			known = false
	_check(known, "抽出的词缀都在表里")
	var haste_pct := str(roundi((GameConfig.DAILY_HASTE_MULT - 1.0) * 100.0))
	_check(String(GameConfig.daily_def("haste").get("desc", "")).contains(haste_pct),
		"狂奔文案里的百分比跟倍率一致")
	var other: Dictionary = DAILY_SCRIPT.build("2026-11-09")
	_check(other.get("date") == "2026-11-09", "build 保留传入的日期")


func _test_daily_board() -> void:
	print("\n--- 本地榜 ---")
	var save := FakeSave.new()
	var first: Dictionary = save.record_daily_run("2026-11-08", {
		"wave": 4, "kills": 10, "survival_time": 80, "rooms": 3, "level": 2,
	})
	_check(int(first.get("crystals")) == GameConfig.DAILY_PARTICIPATION_CRYSTALS, "第一局只有参与奖")
	_check(int(first.get("rank")) == 1, "第一局排第 1")
	var worse: Dictionary = save.record_daily_run("2026-11-08", {
		"wave": 2, "kills": 4, "survival_time": 40, "rooms": 2, "level": 1,
	})
	_check(int(worse.get("crystals")) == 0, "更差的一局不再发血晶")
	_check(int(worse.get("rank")) == 2, "更差的一局排第 2")
	var better: Dictionary = save.record_daily_run("2026-11-08", {
		"wave": 6, "kills": 20, "survival_time": 90, "rooms": 5, "level": 4,
	})
	_check(int(better.get("crystals")) == GameConfig.DAILY_BEST_BONUS_CRYSTALS, "刷新最佳才有一次额外奖")
	_check(int(better.get("rank")) == 1, "更好的一局回到第 1")
	var again: Dictionary = save.record_daily_run("2026-11-08", {
		"wave": 8, "kills": 30, "survival_time": 70, "rooms": 6, "level": 5,
	})
	_check(int(again.get("crystals")) == 0, "最佳奖不会发第二次")
	var next_day: Dictionary = save.record_daily_run("2026-11-09", {
		"wave": 1, "kills": 1, "survival_time": 10, "rooms": 1, "level": 1,
	})
	_check(int(next_day.get("crystals")) == GameConfig.DAILY_PARTICIPATION_CRYSTALS, "换日重新发参与奖")
	_check(save.get_daily_runs("2026-11-08").is_empty(), "看昨天的榜不会把今天的记录读出来")
	_check(save.get_daily_runs("2026-11-09").size() == 1, "今天的榜还在")
	_check(save.save_calls >= 5, "记榜会落盘（%d 次）" % save.save_calls)
	save.free()


func _test_abyss_rules() -> void:
	print("\n--- 深渊词缀 ---")
	GameConfig.abyss_level = 0
	_check(GameConfig.get_abyss_extra_projectiles() == 0 and not GameConfig.abyss_forces_dual_affix(),
		"深渊 0 没有规则词缀")
	GameConfig.abyss_level = 1
	_check(GameConfig.get_abyss_extra_projectiles() == 0 and not GameConfig.abyss_forces_dual_affix(),
		"深渊 1 仍只有数值")
	GameConfig.abyss_level = 2
	_check(GameConfig.get_abyss_extra_projectiles() == 1 and not GameConfig.abyss_forces_dual_affix(),
		"深渊 2 远程 +1，还没有双词缀")
	_check(GameConfig.abyss_rule_tags().has("弹+1"), "HUD 短标签有弹+1")
	GameConfig.abyss_level = 3
	_check(GameConfig.abyss_forces_dual_affix() and GameConfig.abyss_rule_text().contains("双词缀"),
		"深渊 3 精英必带双词缀")

	var wm = load("res://scripts/managers/wave_manager.gd").new()
	wm.floor_index = 1
	var elite = load("res://scripts/enemies/enemy_base.gd").new()
	elite.elite_affix = "haster"
	elite.secondary_affix = ""
	wm.apply_abyss_dual(elite)
	_check(String(elite.secondary_affix) != "" and String(elite.secondary_affix) != "haster",
		"第 1 层池只有急速时，第二词缀仍来自完整表（%s）" % String(elite.secondary_affix))

	var suppressed = load("res://scripts/enemies/enemy_base.gd").new()
	suppressed.elite_affix = "haster"
	suppressed.secondary_affix = ""
	suppressed.suppress_affix = true
	wm.apply_abyss_dual(suppressed)
	_check(String(suppressed.secondary_affix) == "", "裂变体不会再被补上第二词缀")

	var kept = load("res://scripts/enemies/enemy_base.gd").new()
	kept.elite_affix = "haster"
	kept.secondary_affix = "charger"
	wm.apply_abyss_dual(kept)
	_check(String(kept.secondary_affix) == "charger", "已经有第二词缀的不再覆盖")

	GameConfig.abyss_level = 0
	var quiet = load("res://scripts/enemies/enemy_base.gd").new()
	quiet.elite_affix = "haster"
	quiet.secondary_affix = ""
	wm.apply_abyss_dual(quiet)
	_check(String(quiet.secondary_affix) == "", "深渊 0 不补第二词缀")
	elite.free()
	suppressed.free()
	kept.free()
	quiet.free()
	wm.free()


func _test_speed_heal_and_shots() -> void:
	print("\n--- 词缀接到人和子弹上 ---")
	var base_chance: float = GameConfig.get_elite_affix_chance(1)
	GameConfig.start_daily({"date": "t", "seed": 1, "modifiers": [{"id": "elite"}]})
	_check(is_equal_approx(GameConfig.get_elite_affix_chance(1), base_chance * 2.0),
		"精英之夜把第 1 层概率翻倍")
	GameConfig.clear_daily()
	_check(is_equal_approx(GameConfig.get_elite_affix_chance(1), base_chance),
		"退出每日后概率回到表上的值")

	GameConfig.start_daily({"date": "t", "seed": 1, "modifiers": [{"id": "glass"}]})
	_check(is_equal_approx(GameConfig.scale_incoming_damage(20.0), 25.0), "脆骨把 20 伤害变成 25")
	GameConfig.clear_daily()
	_check(is_equal_approx(GameConfig.scale_incoming_damage(20.0), 20.0), "没有脆骨时伤害原样")

	var player = load("res://scripts/player/player.gd").new()
	player.max_hp = 100.0
	player.current_hp = 80.0
	GameConfig.start_daily({"date": "t", "seed": 1, "modifiers": [{"id": "no_heal"}]})
	player.heal(30.0)
	_check(is_equal_approx(player.current_hp, 80.0), "枯井时治疗无效")
	GameConfig.clear_daily()
	player.heal(10.0)
	_check(is_equal_approx(player.current_hp, 90.0), "退出枯井后治疗恢复")
	_check(player.spend_hp(40.0), "献血 40 成功")
	_check(is_equal_approx(player.current_hp, 50.0), "献血后是 50")
	_check(not player.spend_hp(50.0), "再献 50 会扣死，拒绝")
	_check(is_equal_approx(player.current_hp, 50.0), "被拒绝的献血不改血量")
	player.free()

	var host := Node2D.new()
	root.add_child(host)
	current_scene = host
	GameConfig.abyss_level = 0
	var player_node := CharacterBody2D.new()
	# 放在攻击距离外，避免物理帧自己开一枪，把“手动打一发”数成两发。
	player_node.position = Vector2(2000, 0)
	host.add_child(player_node)
	var archer = load("res://scenes/enemies/skeleton_archer.tscn").instantiate()
	host.add_child(archer)
	archer.player = player_node
	archer.floor_index = 1
	archer.attack_timer = 99.0
	archer.set_physics_process(false)
	await process_frame
	archer._attack()
	_check(get_nodes_in_group("enemy_projectiles").size() == 1, "深渊 0 的射手仍是单发")
	for node in get_nodes_in_group("enemy_projectiles"):
		node.free()
	GameConfig.abyss_level = 2
	archer._attack()
	_check(get_nodes_in_group("enemy_projectiles").size() == 2, "深渊 2 的射手多 1 发")
	GameConfig.abyss_level = 0

	GameConfig.start_daily({"date": "t", "seed": 1, "modifiers": [{"id": "haste"}]})
	var bat = load("res://scenes/enemies/bat.tscn").instantiate()
	host.add_child(bat)
	await process_frame
	_check(is_equal_approx(bat.move_speed, 128.0 * GameConfig.DAILY_HASTE_MULT),
		"狂奔后蝙蝠移速 ×1.40（实际 %.1f）" % bat.move_speed)
	GameConfig.clear_daily()
	host.queue_free()
