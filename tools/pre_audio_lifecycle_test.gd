extends SceneTree

var _pass := 0
var _fail := 0

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
	await process_frame
	var save = root.get_node("SaveManager")
	_check(save.is_tool_run and save.save_path.begins_with("user://test_"), "lifecycle uses isolated test save before gameplay")
	if not save.is_tool_run or not save.save_path.begins_with("user://test_"):
		quit(1)
		return
	save.use_test_save_path("pre_audio_lifecycle_test")
	var ach = root.get_node_or_null("AchievementManager")
	_check(ach != null, "AchievementManager exists")
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await create_timer(4.0, true).timeout
	_check(scene.has_method("_begin_terminal_state"), "main synchronizes terminal-state entry")
	_check(scene.has_method("_lifecycle_token_valid"), "main validates run/room lifecycle tokens")
	_check(scene.has_method("_on_portal_entered"), "portal callback remains real room-transition entry")
	_check(ach != null and ach.has_method("get_effective_time"), "AchievementManager exposes pause-aware run clock")
	_check(scene.current_room != null, "main scene creates first actual room")
	_check(scene.current_room != null and scene.current_room.has_method("_on_portal_entered"), "portal collision handler is present")
	_check(scene.current_room != null and scene.current_room.has_method("find_free_position"), "room placement API is available")
	var game_over = scene.get_node_or_null("GameOverUI")
	var props: Array = game_over.get_property_list() if game_over else []
	var one_shot := false
	for prop in props:
		if String(prop.get("name", "")) == "_run_settlement_submitted":
			one_shot = true
	_check(one_shot, "game-over UI guards per-run settlement")
	if ach:
		ach.start_new_run()
		var time_before := int(ach.get_effective_time()) if ach.has_method("get_effective_time") else 0
		paused = true
		await create_timer(2.0, true, false, true).timeout
		paused = false
		_check(not ach.has_method("get_effective_time") or int(ach.get_effective_time()) - time_before <= 1, "effective time excludes pause")

	var main_script = load("res://scripts/managers/main.gd")
	var victory_first: Node = main_script.new()
	_check(victory_first._begin_terminal_state("victory"), "victory claims an open terminal state")
	var victory_token: int = victory_first._run_token
	_check(victory_first._begin_terminal_state("death"), "death takes priority over pending victory")
	_check(victory_first._terminal_state == "death" and victory_first._run_token == victory_token + 1, "death invalidates suspended run continuations")
	_check(not victory_first._begin_terminal_state("victory"), "victory cannot reclaim terminal state after death")
	victory_first.free()
	var death_first: Node = main_script.new()
	_check(death_first._begin_terminal_state("death"), "death claims an open terminal state")
	var death_token: int = death_first._run_token
	_check(not death_first._begin_terminal_state("victory"), "pending victory loses when death arrives first")
	_check(not death_first._begin_terminal_state("death") and death_first._run_token == death_token, "duplicate death does not invalidate the run twice")
	death_first.free()

	var player = scene.player
	var range_before: float = player.pickup_range_bonus
	paused = true
	var pause_probe := create_timer(1.2, true, false, true)
	pause_probe.timeout.connect(func():
		_check(is_equal_approx(player.pickup_range_bonus, range_before + 260.0), "paused loot countdown preserves its temporary pickup contribution")
		player.apply_upgrade("pickup_range")
		_check(is_equal_approx(player.pickup_range_bonus, range_before + 260.0 + GameConfig.UPGRADE_PICKUP_RANGE), "pickup growth can accrue during loot grace")
		paused = false
	)
	await scene._loot_grace_countdown(1)
	_check(is_equal_approx(player.pickup_range_bonus, range_before + GameConfig.UPGRADE_PICKUP_RANGE), "loot grace restores only its own range contribution")


	scene.wave_manager.stop()
	scene.weapon_manager.set_process(false)
	for enemy in get_nodes_in_group("enemies"):
		enemy.queue_free()
	await process_frame
	var room_script = load("res://scripts/map/game_room.gd")
	var room: Node2D = Node2D.new()
	room.set_script(room_script)
	root.add_child(room)
	var portal_player: CharacterBody2D = CharacterBody2D.new()
	portal_player.add_to_group("player")
	room.add_child(portal_player)
	var portal_entries := [0]
	room.portal_entered.connect(func(): portal_entries[0] += 1)
	room._on_portal_entered(portal_player)
	room._on_portal_entered(portal_player)
	_check(portal_entries[0] == 1 and room._portal_used, "repeated portal entry emits a single transition signal")
	for setup_method in ["setup_mutation_room", "setup_treasure_room"]:
		var special: Node2D = room_script.new()
		root.add_child(special)
		special.call(setup_method)
		var placements_clear := true
		for i in range(special._occupied_rects.size()):
			var rect: Rect2 = special._occupied_rects[i]
			placements_clear = placements_clear and not rect.grow(special.PLACEMENT_PADDING + special.PLAYER_SPAWN_CLEAR).has_point(special.get_center())
			for j in range(i):
				placements_clear = placements_clear and not rect.grow(special.PLACEMENT_PADDING).intersects(special._occupied_rects[j])
		_check(not special._occupied_rects.is_empty(), setup_method + " placed real occupied props")
		_check(placements_clear, setup_method + " props avoid spawn clearance and one another")
		special.free()
	var wave_manager = scene.wave_manager
	var enemy_cap: int = GameConfig.get_enemy_alive_cap(wave_manager.floor_index)
	var capacity_fill: Array[Node] = []
	while get_nodes_in_group("enemies").size() < enemy_cap:
		var blocker := Node.new()
		blocker.add_to_group("enemies")
		room.add_child(blocker)
		capacity_fill.append(blocker)
	wave_manager._alive_probe_timer = 0.0
	_check(not wave_manager._can_spawn_more(), "wave manager blocks new spawns at the live enemy cap")
	capacity_fill.pop_back().free()
	wave_manager._spawn_enemy()
	_check(get_nodes_in_group("enemies").size() == enemy_cap, "batch spawn fills only one remaining capacity slot")
	wave_manager._spawn_enemy()
	_check(get_nodes_in_group("enemies").size() == enemy_cap, "second batch respects live cap without waiting for cache refresh")
	for blocker in capacity_fill:
		blocker.free()
	room.free()
	scene.queue_free()
	await process_frame
	for floor_index in [1, GameConfig.DUNGEON_FLOOR_COUNT]:
		await _test_terminal_race(floor_index, true)
		await _test_terminal_race(floor_index, false)
	save.clear_test_save("pre_audio_lifecycle_test")
	print("RESULT lifecycle pass=%d fail=%d" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)

func _wait_until(test: Callable, seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if test.call():
			return true
		await create_timer(0.05, true).timeout
	return bool(test.call())

func _test_terminal_race(floor_index: int, death_first: bool) -> void:
	# Focused race fixture: create a real Boss through main's hookup; full room
	# traversal belongs to run_dungeon_smoke. Both deaths use real damage APIs.
	var game = load("res://scenes/main.tscn").instantiate()
	game.debug_loot_grace_seconds = 1
	root.add_child(game)
	current_scene = game
	var started := await _wait_until(func(): return game.wave_manager.is_active, 6.0)
	_check(started, "race fixture initial intro finishes")
	if not started:
		game.queue_free()
		await process_frame
		return
	game.wave_manager.stop()
	game.weapon_manager.set_process(false)
	game.player.set_physics_process(false)
	game.player.xp_to_next_level = 1000000
	for enemy in get_nodes_in_group("enemies"):
		enemy.queue_free()
	await process_frame
	game.dungeon.current_floor = floor_index
	game._enter_boss_room()
	var bosses := get_nodes_in_group("boss")
	_check(bosses.size() == 1, "race fixture contains one real Boss")
	if bosses.size() != 1:
		game.queue_free()
		await process_frame
		return
	var boss = bosses[0]
	boss.set_physics_process(false)
	var vulnerable := await _wait_until(func(): return not boss.intro_invulnerable, 6.0)
	_check(vulnerable, "race fixture Boss finishes real intro")
	if not vulnerable:
		game.queue_free()
		await process_frame
		return
	var save = root.get_node("SaveManager")
	var ach = root.get_node("AchievementManager")
	var runs_before: int = save.save_data.total_runs
	var earned_before: int = ach.run_stats.crystals_earned
	var room_token: int = game._room_token
	var pickup_before: float = game.player.pickup_range_bonus
	game.player.is_invincible = false
	game.player.has_shield = false
	var label := "floor %d %s" % [floor_index, "death-before-Boss" if death_first else "Boss-before-death"]
	if death_first:
		game.player.take_damage(10000000.0)
		boss.take_damage(float(boss.current_hp) + 1.0)
	else:
		boss.take_damage(float(boss.current_hp) + 1.0)
		await create_timer(0.1, true).timeout
		game.player.take_damage(10000000.0)
	var expected_reward: int = 0 if death_first else game._floor_clear_crystals(floor_index)
	_check(int(ach.run_stats.crystals_earned) - earned_before == expected_reward, label + " awards Boss income once, only before death")
	var settled := await _wait_until(func(): return game.game_over_ui.visible, 3.0)
	_check(settled, label + " reaches real death settlement")
	# Release only the settlement owner so the suspended loot timer can resume.
	load("res://scripts/ui/pause_controller.gd").release(game.game_over_ui)
	await create_timer(1.3, true).timeout
	_check(game._terminal_state == "death" and game.game_over_ui.title_label.text == "游戏结束", label + " retains one death outcome after await resumes")
	_check(game.dungeon.current_floor == floor_index and game._room_token == room_token, label + " cannot advance floor or replace room after await")
	_check(not is_instance_valid(game.player) or is_equal_approx(game.player.pickup_range_bonus, pickup_before), label + " releases dead player or unwinds temporary pickup range")
	_check(int(save.save_data.total_runs) == runs_before + 1, label + " submits exactly one run settlement")
	var balance_after: int = save.get_blood_crystals()
	await game._on_boss_defeated()
	await game._on_player_died()
	_check(save.get_blood_crystals() == balance_after and int(save.save_data.total_runs) == runs_before + 1, label + " duplicate terminal callbacks cannot reward or settle again")
	game.queue_free()
	await process_frame
	await process_frame
