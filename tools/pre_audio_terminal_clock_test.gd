extends SceneTree

const Pause = preload("res://scripts/ui/pause_controller.gd")
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
		await create_timer(0.03, true).timeout
	return bool(test.call())

func _menu_idle(label: String) -> void:
	var before: float = ach.get_effective_time()
	await create_timer(0.2, true).timeout
	_check(is_equal_approx(ach.get_effective_time(), before), label + " menu clock stays stopped")
	# Near-threshold fixture exercises real process ticks, never calls _process.
	save.save_data.achievements.erase("survivor")
	save.save_game()
	ach._effective_game_time = 899.99
	ach.run_stats.survival_time = 899
	await create_timer(0.15, true).timeout
	_check(is_equal_approx(ach.get_effective_time(), 899.99) and ach.run_stats.survival_time == 899, label + " menu cannot cross survival threshold")
	_check(not ach.is_achievement_unlocked("survivor") and not "survivor" in save.save_data.achievements, label + " menu cannot save survivor achievement")
	var persisted: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(save.save_path))
	_check(not "survivor" in persisted.get("achievements", []), label + " isolated disk save contains no menu survivor unlock")

func _start_from_menu():
	current_scene._on_start_pressed()
	_check(await _wait(func(): return current_scene != null and current_scene.scene_file_path == "res://scenes/main.tscn"), "real menu starts game")
	var game = current_scene
	game.debug_loot_grace_seconds = 1
	_check(ach.get_effective_time() < 1.0 and ach.run_stats.survival_time == 0, "new run resets previous clock")
	_check(await _wait(func(): return game.wave_manager.is_active), "real opening intro completes")
	game.wave_manager.stop()
	game.weapon_manager.set_process(false)
	game.player.set_physics_process(false)
	game.player.max_hp = 1000000.0
	game.player.current_hp = 1000000.0
	for enemy in get_nodes_in_group("enemies"):
		enemy.queue_free()
	await process_frame
	var before: float = ach.get_effective_time()
	await create_timer(0.15, true).timeout
	_check(ach.get_effective_time() > before, "active run clock advances")
	return game

func _return_menu(game) -> void:
	game._on_return_to_menu()
	_check(await _wait(func(): return current_scene != null and current_scene.scene_file_path == "res://scenes/ui/main_menu.tscn"), "real return reaches menu")
	_check(not paused, "scene exit releases modal pause")

func _victory(queued: bool, deferred_queue: bool = false) -> void:
	var game = await _start_from_menu()
	game.dungeon.current_floor = GameConfig.DUNGEON_FLOOR_COUNT
	game._enter_boss_room()
	var boss = get_first_node_in_group("boss")
	boss.set_physics_process(false)
	_check(await _wait(func(): return not boss.intro_invulnerable), "final Boss real intro ends")
	if queued:
		game.player.gain_xp(game.player.xp_to_next_level)
		game.player.gain_xp(game.player.xp_to_next_level)
		_check(game.upgrade_ui.visible and game._pending_upgrades == 1 and paused, "real preterminal XP opens upgrade and queues another")
		# Start the real close tween; terminal entry must cancel it and its queued successor.
		game.upgrade_ui._on_skip()
		if deferred_queue:
			await game.upgrade_ui.upgrade_selected
			_check(not game._upgrade_open and game._pending_upgrades == 1, "real upgrade callback waits before opening queued successor")
	game.player.global_position = boss.global_position
	game.player.current_xp = game.player.xp_to_next_level - 1
	var level_before: int = game.player.current_level
	var runs_before: int = save.save_data.total_runs
	boss.take_damage(float(boss.current_hp) + 1.0)
	var stopped: float = ach.get_effective_time()
	_check(game._terminal_state == "victory", "real final Boss claims victory")
	await create_timer(1.0, true).timeout
	_check(game.player.current_level > level_before, "real final Boss XP assets are picked up and level player")
	_check(not game.upgrade_ui.visible and not game._upgrade_open and game._pending_upgrades == 0, "victory rejects XP upgrades and clears queued upgrades")
	_check(not paused, "victory presentation needs no upgrade dismissal")
	_check(await _wait(func(): return game.game_over_ui.visible, 8.0), "victory settles without test skipping upgrades")
	_check(is_equal_approx(ach.get_effective_time(), stopped), "victory clock stays stopped through presentation")
	_check(int(save.save_data.total_runs) == runs_before + 1, "victory settles exactly once")
	game._on_boss_defeated()
	await create_timer(0.15, true).timeout
	_check(int(save.save_data.total_runs) == runs_before + 1 and not game.upgrade_ui.visible, "duplicate victory cannot settle or reopen upgrades")
	await _return_menu(game)
	await _menu_idle("after victory")

func _run() -> void:
	await process_frame
	save = root.get_node("SaveManager")
	ach = root.get_node("AchievementManager")
	_check(save.is_tool_run and String(save.save_path).begins_with("user://test_"), "terminal clock storage isolated")
	if not save.is_tool_run or not String(save.save_path).begins_with("user://test_"):
		quit(1)
		return
	save.use_test_save_path("pre_audio_terminal_clock_test")
	GameConfig.abyss_level = 0
	GameConfig.daily_active = false
	var menu = load("res://scenes/ui/main_menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	_check(ach.run_stats.start_time == 0, "initial menu has never started a run")
	await _menu_idle("initial")
	var game = await _start_from_menu()
	var pause_menu = game.get_node("PauseMenu")
	pause_menu._pause()
	var before: float = ach.get_effective_time()
	await create_timer(0.2, true).timeout
	_check(is_equal_approx(ach.get_effective_time(), before), "real pause menu freezes run clock")
	pause_menu._resume()
	game.player.gain_xp(game.player.xp_to_next_level)
	_check(game.upgrade_ui.visible and paused, "normal active-run XP still opens upgrade")
	game.player.gain_xp(game.player.xp_to_next_level)
	_check(game._pending_upgrades == 1, "normal active-run XP queues another upgrade")
	game.upgrade_ui._on_skip()
	_check(await _wait(func(): return game.upgrade_ui.visible and not game.upgrade_ui._submitted and game._pending_upgrades == 0), "normal queued upgrade opens after first choice closes")
	game.upgrade_ui._on_skip()
	_check(await _wait(func(): return not game.upgrade_ui.visible and not paused), "normal upgrade completes and releases pause")
	await create_timer(0.1, true).timeout
	pause_menu._pause()
	pause_menu._on_abandon_pressed()
	pause_menu._on_abandon_pressed()
	_check(await _wait(func(): return current_scene != null and current_scene.scene_file_path == "res://scenes/ui/main_menu.tscn"), "real pause abandon navigates to menu")
	await _menu_idle("after abandon")
	await _victory(false)
	await _victory(true)
	await _victory(true, true)
	game = await _start_from_menu()
	game.player.armor = 0.0
	game.player.dodge_chance = 0.0
	game.player.has_shield = false
	game.player.is_invincible = false
	game.player.take_damage(2000000.0)
	before = ach.get_effective_time()
	_check(await _wait(func(): return game.game_over_ui.visible, 2.0), "real death settles")
	_check(is_equal_approx(ach.get_effective_time(), before), "death clock stops before settlement delay")
	await _return_menu(game)
	await _menu_idle("after death")
	game = await _start_from_menu()
	_check(not ach.is_achievement_unlocked("survivor"), "new run does not inherit menu survivor unlock")
	await _return_menu(game)
	await _menu_idle("after active-run return")
	Pause.reset_for_scene_change()
	current_scene.queue_free()
	await process_frame
	save.clear_test_save("pre_audio_terminal_clock_test")
	print("RESULT terminal_clock pass=%d fail=%d" % [_pass, _fail])
	quit(1 if _fail else 0)
