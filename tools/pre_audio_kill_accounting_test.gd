extends SceneTree

const Pause = preload("res://scripts/ui/pause_controller.gd")
const SaveScript = preload("res://scripts/managers/save_manager.gd")
const SUITE := "pre_audio_kill_accounting_test"
var _pass := 0
var _fail := 0
var save
var ach

func _initialize() -> void:
	_run()

func _check(ok: bool, label: String) -> void:
	if ok:
		_pass += 1
		print("✅ " + label)
	else:
		_fail += 1
		print("❌ " + label)

func _wait(test: Callable, seconds: float = 6.0) -> bool:
	var end := Time.get_ticks_msec() + int(seconds * 1000)
	while Time.get_ticks_msec() < end:
		if test.call():
			return true
		await create_timer(0.02, true).timeout
	return bool(test.call())

func _game():
	var game = load("res://scenes/main.tscn").instantiate()
	game.debug_force_character = "hunter"
	game.debug_loot_grace_seconds = 1
	root.add_child(game)
	current_scene = game
	_check(await _wait(func(): return game.wave_manager.is_active), "real opening completes")
	game.wave_manager.stop()
	game.weapon_manager.set_process(false)
	game.player.set_physics_process(false)
	game.player.xp_to_next_level = 1000000
	game.player.max_hp = 1000000.0
	game.player.current_hp = 1000000.0
	# Only setup cleanup. Never remove enemies or disable process in the DoT window.
	for enemy in get_nodes_in_group("enemies"):
		enemy.queue_free()
	await process_frame
	return game

func _dispose(game) -> void:
	Pause.reset_for_scene_change()
	game.queue_free()
	await process_frame
	await process_frame

func _fresh_save():
	# Stay off-tree so SaveManager._ready cannot clear the existing tool save.
	var fresh = SaveScript.new()
	fresh.is_tool_run = true
	fresh.save_path = save.save_path
	fresh.load_game()
	return fresh

func _category(kind: String) -> int:
	return int(ach.run_stats.get("kill_categories", {}).get(kind, 0))

func _kill_player(game) -> void:
	game.player.armor = 0.0
	game.player.dodge_chance = 0.0
	game.player.has_shield = false
	game.player.is_invincible = false
	game.player.take_damage(2000000.0)

func _death_cutoff() -> void:
	# Historical fixture: a legitimate preterminal kill reaches 99, late DoT must not reach 100.
	save.save_data.total_kills = 98
	save.save_data.kill_categories = {"vampire": 98}
	save.save_game()
	var game = await _game()
	var before = game.wave_manager.spawn_special_enemy("vampire", game.player.global_position + Vector2(200, 0))
	before.set_physics_process(false)
	before.take_damage(1000000.0)
	before.take_damage(1000000.0)
	_check(before.is_dead and game.wave_manager.total_kills == 1 and ach.run_stats.kills == 1 and _category("vampire") == 1, "preterminal real death and repeated damage count once")
	_check(not ach.is_achievement_unlocked("novice_hunter") and not ach.is_achievement_unlocked("vampire_slayer"), "99 cumulative kills stay below both thresholds")
	var late = game.wave_manager.spawn_special_enemy("vampire", game.player.global_position + Vector2(-200, 0))
	late.set_physics_process(false)
	late.take_damage(float(late.current_hp) - 1.0)
	late.apply_bleed(100.0, 2.0)
	var deaths := [0]
	late.enemy_died.connect(func(_enemy): deaths[0] += 1)
	_check(late.current_hp == 1.0 and late.is_processing() and late.bleed_remaining > 0.0, "real wounded enemy retains active bleed process")
	_kill_player(game)
	_check(game._terminal_state == "death" and not game.game_over_ui.visible and not late.is_dead, "player death precedes live bleed tick and delayed settlement")
	_check(await _wait(func(): return deaths[0] == 1, 0.65), "real bleed tick kills enemy during death presentation")
	_check(not game.game_over_ui.visible, "late bleed death occurs before settlement snapshot consumption")
	_check(game.wave_manager.total_kills == 1, "death cutoff freezes wave kill total")
	_check(ach.run_stats.kills == 1 and _category("vampire") == 1, "death cutoff freezes achievement count and category")
	_check(not ach.is_achievement_unlocked("novice_hunter") and not ach.is_achievement_unlocked("vampire_slayer"), "postterminal real kill cannot unlock kill achievements")
	_check(await _wait(func(): return game.game_over_ui.visible, 2.0), "real death settles after presentation")
	_check(game.game_over_ui.stats_label.text.contains("击杀数: 1"), "death UI consumes the preterminal total")
	_check(int(save.save_data.total_runs) == 1 and int(save.save_data.total_kills) == 99 and int(save.save_data.kill_categories.get("vampire", 0)) == 99, "real settlement saves matching total and category 99")
	var fresh = _fresh_save()
	_check(int(fresh.save_data.total_kills) == 99 and int(fresh.save_data.kill_categories.get("vampire", 0)) == 99, "new SaveManager reloads consistent death settlement")
	_check(not "novice_hunter" in fresh.save_data.achievements and not "vampire_slayer" in fresh.save_data.achievements, "new SaveManager has no postterminal kill unlocks")
	fresh.free()
	await _dispose(game)
	# Restart must reopen accounting; a real next-run kill is the legitimate 100th.
	game = await _game()
	var next = game.wave_manager.spawn_special_enemy("vampire", game.player.global_position + Vector2(200, 0))
	next.set_physics_process(false)
	next.take_damage(1000000.0)
	_check(game.wave_manager.total_kills == 1 and ach.run_stats.kills == 1 and _category("vampire") == 1, "new run reopens kill accounting with fresh local categories")
	_check(ach.is_achievement_unlocked("novice_hunter") and ach.is_achievement_unlocked("vampire_slayer"), "legitimate next-run 100th kill unlocks both milestones")
	_kill_player(game)
	_check(await _wait(func(): return game.game_over_ui.visible, 2.0), "second real death settles")
	fresh = _fresh_save()
	_check(int(fresh.save_data.total_runs) == 2 and int(fresh.save_data.total_kills) == 100 and int(fresh.save_data.kill_categories.get("vampire", 0)) == 100, "new SaveManager reloads two settled runs with cumulative category 100")
	fresh.free()
	await _dispose(game)

func _summon_and_final_boss() -> void:
	save.use_test_save_path(SUITE + "_summon")
	var game = await _game()
	game.dungeon.current_floor = GameConfig.DUNGEON_FLOOR_COUNT
	game._enter_boss_room()
	var boss = get_first_node_in_group("boss")
	boss.set_physics_process(false)
	_check(await _wait(func(): return not boss.intro_invulnerable), "real final Boss intro completes")
	boss.summon_count = 2
	boss._attack_summon()
	var bats: Array = []
	for enemy in get_nodes_in_group("enemies"):
		if enemy != boss and enemy._get_enemy_type() == "bat":
			bats.append(enemy)
			enemy.set_physics_process(false)
	_check(bats.size() == 2, "real Boss attack summons two wired bats")
	if bats.size() != 2:
		await _dispose(game)
		return
	var bat = bats[0]
	bat.take_damage(1000000.0)
	_check(bat.is_dead and game.wave_manager.total_kills == 1, "one summoned bat death adds exactly one wave kill")
	_check(ach.run_stats.kills == 1 and _category("bat") == 1, "one summoned bat death adds exactly one achievement kill and category")
	bat.take_damage(1000000.0)
	_check(game.wave_manager.total_kills == 1 and ach.run_stats.kills == 1 and _category("bat") == 1, "repeat lethal damage cannot recount summoned bat")
	var events: Array[String] = []
	boss.enemy_died.connect(func(_enemy): events.append("enemy_died"))
	boss.boss_defeated.connect(func(): events.append("boss_defeated"))
	var balance_before: int = save.get_blood_crystals()
	boss.take_damage(float(boss.current_hp) + 1.0)
	_check(events == ["enemy_died", "boss_defeated"] and game._terminal_state == "victory", "real final lethal hit emits enemy death then claims victory")
	_check(ach.run_stats.boss_killed and ach.run_stats.floors_cleared == 3 and ach.is_achievement_unlocked("boss_killer"), "terminal cutoff preserves legitimate final Boss achievement event")
	_check(ach.run_stats.crystals_earned == 120 and save.get_blood_crystals() == balance_before + 120, "terminal cutoff preserves final Boss reward income once")
	_check(game.wave_manager.total_kills == 1, "Boss retains separate accounting from ordinary kill total")
	boss.take_damage(1000000.0)
	_check(events.size() == 2 and save.get_blood_crystals() == balance_before + 120, "repeat Boss damage cannot duplicate events or rewards")
	# Boss cleanup is deferred. A real pending bat death before it frees still must be excluded.
	bats[1].take_damage(1000000.0)
	_check(bats[1].is_dead and game.wave_manager.total_kills == 1 and ach.run_stats.kills == 1 and _category("bat") == 1, "victory cutoff excludes late summoned death from both ledgers")
	_check(await _wait(func(): return game.game_over_ui.visible, 9.0), "real final Boss victory completes settlement")
	_check(ach.run_stats.dungeon_cleared == 1 and ach.is_achievement_unlocked("throne_breaker"), "final dungeon achievement remains valid after cutoff")
	_check(int(ach.run_stats.crystals_earned) > 120 and int(ach.run_stats.crystals_earned) == save.get_blood_crystals() - balance_before, "postterminal settlement income still enters run achievements")
	var fresh = _fresh_save()
	_check(int(fresh.save_data.total_runs) == 1 and int(fresh.save_data.total_kills) == 1 and int(fresh.save_data.kill_categories.get("bat", 0)) == 1, "new SaveManager reloads one bat from real victory settlement")
	_check("boss_killer" in fresh.save_data.achievements and "throne_breaker" in fresh.save_data.achievements, "new SaveManager retains final Boss and dungeon achievements")
	fresh.free()
	await _dispose(game)

func _run() -> void:
	await process_frame
	save = root.get_node("SaveManager")
	ach = root.get_node("AchievementManager")
	var isolated: bool = save.is_tool_run and String(save.save_path).begins_with("user://test_")
	_check(isolated, "kill accounting storage isolated")
	if not isolated:
		quit(1)
		return
	save.use_test_save_path(SUITE)
	GameConfig.abyss_level = 0
	GameConfig.daily_active = false
	await _death_cutoff()
	await _summon_and_final_boss()
	for name in [SUITE, SUITE + "_summon"]:
		save.clear_test_save(name)
		for suffix in ["", ".tmp", ".bak"]:
			_check(not FileAccess.file_exists("user://test_" + name + ".json" + suffix), "isolated file cleaned " + name + suffix)
	print("RESULT kill_accounting pass=%d fail=%d" % [_pass, _fail])
	quit(1 if _fail else 0)
