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
		print("✅ %s" % label)
	else:
		_fail += 1
		print("❌ %s" % label)

func _wait(test: Callable, seconds: float = 6.0) -> bool:
	var end := Time.get_ticks_msec() + int(seconds * 1000)
	while Time.get_ticks_msec() < end:
		if test.call():
			return true
		await create_timer(0.03, true).timeout
	return bool(test.call())

func _game():
	var game = load("res://scenes/main.tscn").instantiate()
	game.debug_force_character = "hunter"
	game.debug_loot_grace_seconds = 1
	root.add_child(game)
	current_scene = game
	_check(await _wait(func(): return game.wave_manager.is_active), "real initial intro completes")
	game.wave_manager.stop()
	game.weapon_manager.set_process(false)
	game.player.set_physics_process(false)
	game.player.xp_to_next_level = 1000000
	for enemy in get_nodes_in_group("enemies"):
		enemy.queue_free()
	await process_frame
	return game

func _dispose(game) -> void:
	Pause.reset_for_scene_change()
	game.queue_free()
	await process_frame
	await process_frame

func _run() -> void:
	await process_frame
	save = root.get_node("SaveManager")
	ach = root.get_node("AchievementManager")
	_check(save.is_tool_run and String(save.save_path).begins_with("user://test_"), "integration storage isolated")
	save.use_test_save_path("pre_audio_stats_integration_test")
	GameConfig.abyss_level = 0
	GameConfig.daily_active = false
	# Observe the first real weapon event while main._ready is still executing.
	ach.run_stats.kills = 999
	ach.run_stats.crystals_earned = 999
	ach.run_stats.weapon_types_used = ["stale"]
	var game = load("res://scenes/main.tscn").instantiate()
	game.debug_force_character = "hunter"
	var opening := [false]
	game.get_node("WeaponManager").weapon_added.connect(func(_weapon):
		opening[0] = ach.run_stats.kills == 0 and ach.run_stats.crystals_earned == 0 and ach.run_stats.weapon_types_used == ["pistol"]
	, CONNECT_ONE_SHOT)
	root.add_child(game)
	current_scene = game
	_check(opening[0], "reset precedes first real opening weapon event")
	_check(await _wait(func(): return game.wave_manager.is_active), "opening intro completes")
	game.wave_manager.stop()
	game.weapon_manager.set_process(false)
	game.player.set_physics_process(false)
	for enemy in get_nodes_in_group("enemies"):
		enemy.queue_free()
	await process_frame
	# Real add/upgrade path: no direct level assignment and no evolution.
	for id in ["pistol", "shotgun", "magic_book"]:
		while game.weapon_manager.can_add_weapon(id):
			_check(game.weapon_manager.add_weapon(ItemCatalog.create_weapon(id)), "normal add/upgrade accepted " + id)
		_check(ach.run_stats.weapons_maxed.size() == ["pistol", "shotgun", "magic_book"].find(id) + 1, "first max level recorded immediately " + id)
		_check(not game.weapon_manager.add_weapon(ItemCatalog.create_weapon(id)), "duplicate max upgrade rejected " + id)
	_check(ach.is_achievement_unlocked("weapon_master") and ach.run_stats.evolved_weapons == 0, "existing three-max weapon achievement unlocks before evolution")
	# Observe current time in the unlock signal itself: update must precede check.
	ach._effective_game_time = 899.99
	ach.run_stats.survival_time = 899
	var survivor_time := [-1]
	ach.achievement_unlocked.connect(func(id, _label):
		if id == "survivor":
			survivor_time[0] = ach.run_stats.survival_time
	)
	_check(await _wait(func(): return ach.is_achievement_unlocked("survivor"), 1.0), "survival threshold reached by real process tick")
	_check(survivor_time[0] == 900, "survival time synchronized before threshold notification")
	await _dispose(game)
	await _damage_boss_income_and_clock()
	await _normal_settlement()
	await _projectile_transition_and_death()
	await _boss_loot()
	await _banner_pause()
	save.clear_test_save("pre_audio_stats_integration_test")
	print("RESULT stats_integration pass=%d fail=%d" % [_pass, _fail])
	quit(1 if _fail else 0)

func _damage_boss_income_and_clock() -> void:
	var game = await _game()
	var player = game.player
	player.max_hp = 100.0
	player.current_hp = 100.0
	player.armor = 0.0
	player.dodge_chance = 0.0
	player.has_shield = false
	player.is_invincible = false
	player.take_damage(10.0)
	_check(player.current_hp == 90.0, "real first damage 100 to 90")
	player.is_invincible = false
	player.take_damage(10.0)
	_check(player.current_hp == 80.0, "real second damage 90 to 80")
	player.heal(5.0)
	_check(player.current_hp == 85.0 and ach.run_stats.damage_taken == 20.0, "HP100-90-80-85 counts actual 20 damage through main hookup")
	for i in 4:
		game.upgrade_ui.show_upgrade(player, game.weapon_manager)
		game.upgrade_ui._on_option_selected({"type": "basic", "id": "gold"})
		game.upgrade_ui._on_option_selected({"type": "basic", "id": "gold"})
	_check(ach.run_stats.crystals_earned == 400, "four real supply submissions each record once")
	var balance_before: int = save.get_blood_crystals()
	game.dungeon.current_floor = 2
	game._enter_boss_room()
	var boss = get_first_node_in_group("boss")
	boss.set_physics_process(false)
	_check(await _wait(func(): return not boss.intro_invulnerable), "real Boss intro finishes")
	_spawn_projectiles(game, boss)
	boss.take_damage(float(boss.current_hp) + 1.0)
	_check(ach.run_stats.flawless_boss_kill and ach.is_achievement_unlocked("flawless_victory"), "ordinary-room damage does not spoil real flawless Boss kill")
	_check(ach.run_stats.damage_taken == 20.0 and ach.run_stats.crystals_earned == 460 and save.get_blood_crystals() == balance_before + 60, "Boss income adds once while prior damage remains")
	await process_frame
	_check(get_nodes_in_group("enemy_projectiles").is_empty(), "real Boss victory clears normal and dynamic projectiles")
	# Hold the pending inter-floor continuation; freeze the common clock during pause.
	paused = true
	var time_before: float = ach.get_effective_time()
	var hud_before: String = game.hud.time_label.text
	await create_timer(2.0, true, false, true).timeout
	_check(is_equal_approx(ach.get_effective_time(), time_before) and game.hud.time_label.text == hud_before, "pause excludes two seconds from achievement and HUD clock")
	paused = false
	# A real death interrupts the pending transition and routes time to UI and daily board.
	GameConfig.daily_active = true
	GameConfig.daily_date = "2099-02-03"
	ach._effective_game_time = 125.2
	game.hud._process(0.0)
	_check(game.hud.time_label.text == "02:05", "HUD consumes effective clock")
	player.is_invincible = false
	player.take_damage(1000000.0)
	_check(await _wait(func(): return game.game_over_ui.visible, 2.0), "real death reaches settlement UI")
	var rows: Array = save.get_daily_runs("2099-02-03")
	_check(rows.size() == 1 and int(rows[0].time) == 125 and game.game_over_ui.stats_label.text.contains("生存时间: 2:05"), "daily board and settlement consume same 125 effective seconds")
	_check(int(ach.get_effective_time()) == 125 and game.hud.time_label.text == "02:05", "terminal delay does not advance HUD beyond settled effective time")
	_check(ach.run_stats.crystals_earned == save.get_blood_crystals() - (balance_before - 400), "all supply Boss settlement daily income matches actual balance delta")
	_check(ach.is_achievement_unlocked("rich_hunter") and _shows_rich(game.game_over_ui), "daily settlement crosses 500 and displays rich_hunter immediately")
	var state := [save.get_blood_crystals(), save.save_data.total_runs, ach.run_stats.crystals_earned, ach.get_unlocked_count(), rows.size()]
	game.game_over_ui.show_game_over(ach.get_run_stats(), true)
	_check(state == [save.get_blood_crystals(), save.save_data.total_runs, ach.run_stats.crystals_earned, ach.get_unlocked_count(), save.get_daily_runs("2099-02-03").size()], "duplicate UI settlement cannot add balance runs achievements income or board entries")
	GameConfig.daily_active = false
	await _dispose(game)

func _shows_rich(ui) -> bool:
	for label in ui.achievement_list.find_children("", "Label", true, false):
		if label.text == "富有的猎人":
			return true
	return false

func _normal_settlement() -> void:
	save.save_data.achievements.erase("rich_hunter")
	ach.start_new_run()
	# Boundary fixture: earlier income already received; UI must account only its own +5.
	save.add_blood_crystals(495)
	ach.record_crystals_earned(495)
	var ui = load("res://scenes/ui/game_over_ui.tscn").instantiate()
	root.add_child(ui)
	var before: int = save.get_blood_crystals()
	ui.show_game_over(ach.get_run_stats())
	_check(save.get_blood_crystals() == before + 5 and ach.run_stats.crystals_earned == 500, "normal settlement records actual five crystal payout")
	_check(_shows_rich(ui), "normal payout achievement is visible in same UI call")
	var state := [save.get_blood_crystals(), save.save_data.total_runs, ach.run_stats.crystals_earned, ach.get_unlocked_count()]
	ui.show_game_over(ach.get_run_stats())
	_check(state == [save.get_blood_crystals(), save.save_data.total_runs, ach.run_stats.crystals_earned, ach.get_unlocked_count()], "normal duplicate show is idempotent")
	await _dispose(ui)

func _spawn_projectiles(game, boss) -> void:
	var normal = load("res://scenes/enemies/enemy_projectile.tscn").instantiate()
	normal.position = game.current_room.get_center() + Vector2(-150, 0)
	normal.speed = 0.0
	game.add_child(normal)
	boss._spawn_boss_projectile(Vector2.RIGHT)
	_check(get_nodes_in_group("enemy_projectiles").size() == 2, "real normal projectile plus Boss dynamic barrage spawned")

func _projectile_transition_and_death() -> void:
	var game = await _game()
	var source = load("res://scenes/enemies/vampire_lord.tscn").instantiate()
	game.add_child(source)
	source.set_physics_process(false)
	source.position = game.current_room.get_center() + Vector2(0, -150)
	_spawn_projectiles(game, source)
	# Deterministic next room, still enter through the connected production portal handler.
	game.dungeon._room_plan[game.dungeon.room_in_floor] = "combat"
	game.dungeon._forks.clear()
	var token: int = game._room_token
	game.current_room._on_portal_entered(game.player)
	await process_frame
	_check(get_nodes_in_group("enemy_projectiles").is_empty(), "formal portal transition clears both projectile forms immediately")
	_check(await _wait(func(): return game._room_token > token and not game._room_transitioning, 2.0), "formal portal transition reaches new room")
	game.wave_manager.stop()
	for enemy in get_nodes_in_group("enemies"):
		enemy.queue_free()
	await process_frame
	source = load("res://scenes/enemies/vampire_lord.tscn").instantiate()
	game.add_child(source)
	source.set_physics_process(false)
	source.position = game.current_room.get_center() + Vector2(0, -150)
	_spawn_projectiles(game, source)
	game.player.is_invincible = false
	game.player.has_shield = false
	game.player.take_damage(1000000.0)
	await process_frame
	_check(get_nodes_in_group("enemy_projectiles").is_empty(), "real death terminal entry clears both projectile forms immediately")
	_check(await _wait(func(): return game.game_over_ui.visible, 2.0), "projectile fixture death settles")
	await _dispose(game)

func _boss_loot() -> void:
	var game = await _game()
	game.player.position = Vector2(-10000, -10000)
	for mult in [1.0, 1.5, 2.0]:
		game.wave_manager.loot_mult = mult
		game._enter_boss_room()
		var boss = get_first_node_in_group("boss")
		boss.set_physics_process(false)
		# Suppress only floor progression to inspect the real assets before pickup.
		boss.boss_defeated.disconnect(game._on_boss_defeated)
		_check(await _wait(func(): return not boss.intro_invulnerable), "drop fixture real Boss intro finishes")
		_check(is_equal_approx(boss.loot_mult, mult), "main effective loot multiplier survives Boss ready %.1f" % mult)
		boss.take_damage(float(boss.current_hp) + 1.0)
		await process_frame
		await process_frame
		var values: Array[int] = []
		for gem in get_nodes_in_group("xp_gems"):
			values.append(gem.xp_value)
		var total_xp := 0
		for value in values:
			total_xp += value
		_check(total_xp == int(200 * mult), "Boss base and five extra XP assets (including merged gems) scale %.1f" % mult)
		var silver := 0
		for coin in get_nodes_in_group("silver_coins"):
			silver += coin.value
		_check(silver == int(12 * mult), "Boss actual silver assets scale %.1f" % mult)
		for group in ["xp_gems", "silver_coins", "enemies"]:
			for node in get_nodes_in_group(group):
				node.queue_free()
		await process_frame
	await _dispose(game)

func _banner_pause() -> void:
	var banner = load("res://scripts/ui/floor_banner.gd").new()
	root.add_child(banner)
	banner.show_card("test", "test", "", "", Color.WHITE, 0.5)
	await create_timer(0.45, true).timeout
	paused = true
	var alpha: float = banner._root.modulate.a
	await create_timer(1.3, true, false, true).timeout
	_check(banner.visible and is_equal_approx(banner._root.modulate.a, alpha), "banner paused mid-hold does not fade or finish")
	paused = false
	_check(await _wait(func(): return not banner.visible, 1.5), "banner completes remaining hold and fade after resume")
	banner.queue_free()
	await process_frame
