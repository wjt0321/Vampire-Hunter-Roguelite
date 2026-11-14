extends SceneTree
## 机器平衡模拟：真实刷怪/真实房间/真实升级面板 + "典型 DPS + 风筝走位"自动驾驶。
## 不是真人试玩，只用于平衡证据：单局时长、死亡层、融合触发率、属性卡触顶、房间耗时。
## 用法：godot --headless --path . --script res://tools/run_balance_sim.gd -- --runs 3 --scale 4 --label sim1
## 输出：.tools/qa/balance-sim-<label>/runs.json 与汇总表。

var _runs := 3
var _scale := 4.0
var _label := "sim"
var _fail := 0

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--runs="):
			_runs = maxi(1, int(arg.trim_prefix("--runs=")))
		elif arg.begins_with("--scale="):
			_scale = clampf(float(arg.trim_prefix("--scale=")), 1.0, 8.0)
		elif arg.begins_with("--label="):
			_label = arg.trim_prefix("--label=")
	Engine.time_scale = _scale
	_run()

func _wait(test: Callable, seconds: float) -> bool:
	var elapsed := 0.0
	while elapsed < seconds:
		if test.call():
			return true
		await create_timer(0.05, true).timeout
		elapsed += 0.05
	return bool(test.call())

func _live_enemies(game: Node) -> Array:
	var out: Array = []
	for e in get_nodes_in_group("enemies"):
		if is_instance_valid(e) and not e.get("is_dead"):
			out.append(e)
	return out

func _nearest(enemies: Array, pos: Vector2) -> Node:
	var best: Node = null
	var best_d := INF
	for e in enemies:
		var d: float = e.global_position.distance_to(pos)
		if d < best_d:
			best_d = d
			best = e
	return best

func _pick_option(options: Array, game: Node) -> Dictionary:
	var owned: Array = []
	for w in game.weapon_manager.weapons:
		owned.append(w.weapon_id)
	for opt in options:
		if String(opt.get("type", "")) == "fusion":
			return opt
	# 模拟"会看图鉴凑配方"的玩家：优先拿能与已有武器凑融合对的新武器，
	# 再优先升配方内武器。随机政策测不出融合可达性。
	var recipes: Dictionary = preload("res://scripts/weapons/weapon_fusion.gd").RECIPES
	for opt in options:
		if String(opt.get("type", "")) != "weapon" or String(opt.get("id", "")) in owned:
			continue
		for recipe in recipes.values():
			var a := String(recipe["primary"])
			var b := String(recipe["secondary"])
			if String(opt.get("id", "")) == a and b in owned:
				return opt
			if String(opt.get("id", "")) == b and a in owned:
				return opt
	for opt in options:
		if String(opt.get("type", "")) != "weapon" or not String(opt.get("id", "")) in owned:
			continue
		for recipe in recipes.values():
			var a := String(recipe["primary"])
			var b := String(recipe["secondary"])
			if String(opt.get("id", "")) == a and b in owned:
				return opt
			if String(opt.get("id", "")) == b and a in owned:
				return opt
	for opt in options:
		if String(opt.get("type", "")) == "weapon" and String(opt.get("id", "")) in owned:
			return opt
	for opt in options:
		if String(opt.get("type", "")) == "weapon":
			return opt
	for opt in options:
		if String(opt.get("type", "")) == "passive":
			return opt
	for opt in options:
		if String(opt.get("type", "")) == "basic":
			return opt
	return {}

func _run() -> void:
	await process_frame
	var save: Node = root.get_node("SaveManager")
	save.use_test_save_path("balance_sim")
	var results: Array = []
	for r in _runs:
		var run_seed := 20261115 + r
		seed(run_seed)
		var game: Node = load("res://scenes/main.tscn").instantiate()
		game.debug_force_character = "hunter"
		root.add_child(game)
		current_scene = game
		if not await _wait(func(): return game.wave_manager.is_active, 15.0):
			print("❌ run %d 开局失败" % r)
			_fail += 1
			game.queue_free()
			await process_frame
			continue
		var m := {
			"seed": run_seed, "upgrades": 0, "hands": 0, "fusion_offers": 0, "fusion_taken": 0,
			"stat_levels": 0, "shop_visits": 0, "pacts": 0, "evolutions": 0,
			"seconds": 0.0, "victory": false,
		}
		if game.weapon_manager.has_signal("weapon_evolved"):
			game.weapon_manager.weapon_evolved.connect(func(_w, _e): m.evolutions += 1)
		var pending_fusion := false
		game.upgrade_ui.upgrade_selected.connect(func():
			m.upgrades += 1
			if pending_fusion:
				m.fusion_taken += 1
			pending_fusion = false)
		var was_visible := false
		var dps_timer := 0.0
		var clock := 0.0
		while clock < 2400.0:
			await process_frame
			var dt: float = root.get_process_delta_time()
			clock += dt
			if game.game_over_ui.visible:
				break
			# 平衡模拟测系统节奏而非bot技术：无敌，避免"bot走位差"污染时长/触发率数据。
			game.player.is_invincible = true
			if game.upgrade_ui.visible:
				if not was_visible:
					m.hands += 1
					pending_fusion = false
					for o in game.upgrade_ui.current_options:
						if String(o.get("type", "")) == "fusion":
							m.fusion_offers += 1
							pending_fusion = true
				was_visible = true
				var opt := _pick_option(game.upgrade_ui.current_options, game)
				if opt.is_empty():
					game.upgrade_ui._on_skip()
				else:
					var tk := "pick_" + String(opt.get("type", "?"))
					m[tk] = int(m.get(tk, 0)) + 1
					game.upgrade_ui._on_option_selected(opt)
				continue
			was_visible = false
			if game.room_shop != null and game.room_shop.visible:
				m.shop_visits += 1
				game.room_shop.close()
				continue
			if game.blood_pact != null and game.blood_pact.visible:
				m.pacts += 1
				game.blood_pact._choose("rest")
				continue
			if game.mutation_ui != null and game.mutation_ui.visible:
				game.mutation_ui._choose("leave")
				continue
			var room: Node = game.current_room
			var player: Node = game.player
			if room == null or not is_instance_valid(player):
				break
			var enemies := _live_enemies(game)
			var nearest := _nearest(enemies, player.global_position)
			var bounds: Rect2 = room.get_room_bounds().grow(-48.0)
			var target: Vector2 = room.get_center()
			if nearest != null and nearest.global_position.distance_to(player.global_position) < 240.0:
				target = player.global_position + (player.global_position - nearest.global_position).normalized() * 120.0
			target.x = clampf(target.x, bounds.position.x, bounds.end.x)
			target.y = clampf(target.y, bounds.position.y, bounds.end.y)
			player.global_position = player.global_position.move_toward(target, 200.0 * dt)
			dps_timer += dt
			if dps_timer >= 0.25:
				var victim := _nearest(enemies, player.global_position)
				if victim != null and victim.has_method("take_damage") and not victim.get("intro_invulnerable"):
					victim.take_damage(GameConfig.get_expected_dps(player.current_level) * dps_timer)
				dps_timer = 0.0
			if room.get("portal_spawned"):
				var portal: Node = room.get_node_or_null("Portal")
				if portal == null:
					for c in room.get_children():
						if String(c.name).begins_with("Portal_"):
							portal = c
							break
				if portal != null:
					player.global_position = portal.global_position
		m.seconds = clock
		m.victory = String(game.get("_terminal_state")) == "victory"
		m.floor = game.dungeon.current_floor
		m.kills = game.wave_manager.total_kills
		m.level = game.player.current_level if is_instance_valid(game.player) else 0
		m.stat_levels = game.player.get_total_stat_level() if is_instance_valid(game.player) else 0
		var levels := {}
		for w in game.weapon_manager.weapons:
			levels[String(w.weapon_id)] = int(w.current_level)
		m.weapon_levels = levels
		var log: Node = get_first_node_in_group("run_log")
		if log != null:
			m.room_times = log.rooms.duplicate()
			m.peaks = log.peaks.duplicate()
			m.review = log.summary()
		results.append(m)
		print("RUN seed=%d victory=%s floor=%d time=%.0fs hands=%d picked=%d fusion_offer=%d taken=%d evo=%d stat=%d" % [
			run_seed, str(m.victory), m.floor, m.seconds, m.hands, m.upgrades,
			m.fusion_offers, m.fusion_taken, m.evolutions, m.stat_levels])
		print("  picks weapon=%d passive=%d basic=%d levels=%s" % [
			int(m.get("pick_weapon", 0)), int(m.get("pick_passive", 0)),
			int(m.get("pick_basic", 0)), str(m.weapon_levels)])
		PauseController.reset_for_scene_change()
		game.queue_free()
		await process_frame
		await process_frame
	var dir := "res://.tools/qa/balance-sim-%s" % _label
	DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(dir + "/runs.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(results, "\t"))
	f.close()
	_summary(results)
	quit(1 if _fail else 0)

func _summary(results: Array) -> void:
	if results.is_empty():
		return
	var times: Array = []
	var victories := 0
	var fusions := 0
	var stat_capped := 0
	for m in results:
		times.append(m.seconds)
		victories += 1 if m.victory else 0
		fusions += 1 if m.fusion_offers > 0 else 0
		stat_capped += 1 if m.stat_levels >= GameConfig.MAX_TOTAL_STAT_LEVEL else 0
	times.sort()
	print("\n=== 机器模拟汇总（%d 局，非真人数据）===" % results.size())
	print("单局时长中位 %.1f 分钟（最短 %.1f / 最长 %.1f）" % [
		float(times[times.size() / 2]) / 60.0, float(times[0]) / 60.0, float(times[-1]) / 60.0])
	print("通关率 %d/%d；融合出现率 %d/%d；属性卡触顶率 %d/%d" % [
		victories, results.size(), fusions, results.size(), stat_capped, results.size()])
	print("（无敌bot：测系统节奏与触发率，不代表真人难度）")