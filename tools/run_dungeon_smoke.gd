extends SceneTree
## 三层流程 smoke：经房间出口回调推进，并通过 Boss 伤害入口完成战斗。

var _fail := 0
var _save_mgr: Node = null
var _initial_runs := 0

func _initialize() -> void:
	_run()

func _check(ok: bool, label: String) -> void:
	if ok:
		print("✅ %s" % label)
	else:
		_fail += 1
		print("❌ %s" % label)

func _wait_until(test: Callable, seconds: float) -> bool:
	var elapsed := 0.0
	while elapsed < seconds:
		if test.call():
			return true
		await create_timer(0.1, true).timeout
		elapsed += 0.1
	return bool(test.call())

func _wait_game_until(game: Node, test: Callable, seconds: float) -> bool:
	var elapsed := 0.0
	while elapsed < seconds:
		if game.upgrade_ui != null and game.upgrade_ui.visible:
			game.upgrade_ui._on_skip()
		if test.call():
			return true
		await create_timer(0.1, true).timeout
		elapsed += 0.1
	return bool(test.call())

func _portal_diagnostic(game: Node, room: Node, portal: Node, stage: String) -> void:
	var player: Node = game.player
	var connected: bool = portal.body_entered.is_connected(room._on_portal_entered)
	print("PORTAL_DIAG stage=%s floor=%d room=%d type=%s opened=%s monitor=%s connected=%s used=%s transitioning=%s player_valid=%s player_group=%s player_pos=%s portal_pos=%s distance=%.1f" % [
		stage, game.dungeon.current_floor, game.dungeon.room_in_floor, game._current_room_type,
		str(room.portal_spawned), str(portal.monitoring), str(connected), str(room._portal_used),
		str(game._room_transitioning), str(is_instance_valid(player)),
		str(player.is_in_group("player")) if is_instance_valid(player) else "false",
		str(player.global_position) if is_instance_valid(player) else "invalid",
		str(portal.global_position),
		player.global_position.distance_to(portal.global_position) if is_instance_valid(player) else INF
	])

func _run() -> void:
	await process_frame
	_save_mgr = root.get_node_or_null("SaveManager")
	if _save_mgr:
		_save_mgr.use_test_save_path("run_dungeon_smoke")
		_initial_runs = int(_save_mgr.save_data.get("total_runs", 0))
	var packed := load("res://scenes/main.tscn")
	if packed == null:
		_check(false, "main scene loads")
		_finish()
		return
	var game = packed.instantiate()
	game.debug_loot_grace_seconds = 1
	root.add_child(game)
	current_scene = game
	_check(await _wait_until(func(): return game.dungeon != null and game.current_room != null, 8.0), "main creates first room")
	game.player.max_hp = 1000000.0
	game.player.current_hp = game.player.max_hp
	for floor_index in range(1, GameConfig.DUNGEON_FLOOR_COUNT + 1):
		_check(game.dungeon.current_floor == floor_index, "entered floor %d" % floor_index)
		var guard := 0
		while game._current_room_type != "boss" and guard < 24:
			guard += 1
			var room = game.current_room
			if room == null:
				break
			if game._current_room_type == "combat" or game._current_room_type == "fog" or game._current_room_type == "mirror":
				game.wave_manager.wave_duration = 0.25
				var timed_wave_ended := await _wait_until(func(): return room.portal_spawned, 8.0)
				_check(timed_wave_ended, "floor %d room %d opens its exit from normal wave timing" % [floor_index, guard])
			if game._current_room_type == "shop":
				await _wait_until(func(): return game.room_shop != null and game.room_shop.visible, 2.0)
				if game.room_shop and game.room_shop.visible:
					game.room_shop.close()
			if game._current_room_type == "rest":
				await _wait_until(func(): return game.blood_pact != null and game.blood_pact.visible, 2.0)
				if game.blood_pact and game.blood_pact.visible:
					game.blood_pact._choose("rest")
					_check(not game.blood_pact.visible, "rest choice closes its modal before exit")
			if game._current_room_type == "mutation":
				await _wait_until(func(): return game.mutation_ui != null and game.mutation_ui.visible, 2.0)
				if game.mutation_ui and game.mutation_ui.visible:
					game.mutation_ui._choose("leave")
					_check(not game.mutation_ui.visible, "altar choice closes its modal before exit")
			if not room.portal_spawned:
				await _wait_until(func(): return room.portal_spawned, 12.0)
			_check(room.portal_spawned, "floor %d room %d opens its exit" % [floor_index, guard])
			if not room.portal_spawned:
				break
			var portal: Node = room.get_node_or_null("Portal")
			if portal == null:
				var portals: Array[Node] = room.find_children("Portal_*", "Area2D", true, false)
				if portals.size() > 0:
					portal = portals[0]
			if portal == null:
				_check(false, "floor %d room %d creates a portal node" % [floor_index, guard])
				break
			var portal_ready := await _wait_until(func(): return portal.monitoring and (portal.body_entered.is_connected(room._on_portal_entered) or portal.name.begins_with("Portal_")), 3.0)
			_check(portal_ready, "floor %d room %d portal collision is ready" % [floor_index, guard])
			if not portal_ready:
				_portal_diagnostic(game, room, portal, "collision-not-ready")
				break
			var old_room_id: int = room.get_instance_id()
			_portal_diagnostic(game, room, portal, "before-player-enters")
			game.player.global_position = portal.global_position
			await physics_frame
			await physics_frame
			_portal_diagnostic(game, room, portal, "after-physics-overlap")
			var entered := await _wait_game_until(game, func(): return game.current_room != null and game.current_room.get_instance_id() != old_room_id and not game._room_transitioning, 6.0)
			if not entered:
				_portal_diagnostic(game, room, portal, "handler-timeout")
			_check(entered, "floor %d room %d portal handler enters next room" % [floor_index, guard])
			if not entered:
				break
		if guard >= 24 or not game.dungeon.is_boss_room():
			_check(false, "floor %d reaches its real Boss room" % floor_index)
			break
		var bosses := get_nodes_in_group("boss")
		_check(bosses.size() == 1, "floor %d has one Boss" % floor_index)
		if bosses.size() != 1:
			break
		var boss = bosses[0]
		_check(await _wait_until(func(): return not boss.intro_invulnerable, 8.0), "Boss intro vulnerability ends")
		var crystals_before_boss: int = int(_save_mgr.save_data.get("blood_crystals", 0)) if _save_mgr else 0
		boss.take_damage(float(boss.current_hp) + 1.0)
		_check(await _wait_until(func(): return game._boss_defeat_handled, 2.0), "real Boss damage reaches defeat callback")
		var expected_boss_crystals: int = [30, 60, 120][floor_index - 1]
		_check(_save_mgr == null or int(_save_mgr.save_data.get("blood_crystals", 0)) - crystals_before_boss == expected_boss_crystals, "floor %d Boss reward is applied once (+%d)" % [floor_index, expected_boss_crystals])
		if floor_index < GameConfig.DUNGEON_FLOOR_COUNT:
			_check(await _wait_game_until(game, func(): return game.dungeon.current_floor == floor_index + 1 and game.dungeon.room_in_floor == 1, 28.0), "Boss reward flow enters next floor")
		else:
			_check(await _wait_game_until(game, func(): return game.game_over_ui.visible, 40.0), "real victory flow opens settlement UI")
			_check(_save_mgr == null or int(_save_mgr.save_data.get("total_runs", 0)) == _initial_runs + 1, "terminal settlement is submitted once")
	game.queue_free()
	await process_frame
	_finish()

func _finish() -> void:
	if _save_mgr:
		_save_mgr.clear_test_save("run_dungeon_smoke")
	print("RESULT dungeon_smoke fail=%d" % _fail)
	quit(1 if _fail > 0 else 0)
