extends SceneTree

const SaveManagerScript = preload("res://scripts/managers/save_manager.gd")
const AchievementScript = preload("res://scripts/managers/achievement_manager.gd")
var _pass := 0
var _fail := 0
var _suite := "pre_audio_save_stats_test"

func _initialize() -> void:
	if OS.get_cmdline_user_args().has("--failure-probe"):
		_failure_probe()
	else:
		_run()

func _check(ok: bool, label: String) -> void:
	if ok:
		_pass += 1
		print("✅ %s" % label)
	else:
		_fail += 1
		print("❌ %s" % label)

func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()

func _fresh_save(path: String):
	var mgr = SaveManagerScript.new()
	mgr.save_path = path
	mgr.is_tool_run = true
	mgr.load_game()
	return mgr

func _run() -> void:
	await process_frame
	var owner = root.get_node("SaveManager")
	_check(owner.is_tool_run and String(owner.save_path).begins_with("user://test_"), "save test is isolated")
	var path := String(owner.use_test_save_path(_suite))
	_check(owner.try_save_game(), "isolated baseline persisted")
	root.get_node("AchievementManager").free()
	var world := Node2D.new()
	root.add_child(world)
	current_scene = world
	for run in 2:
		var mgr = _fresh_save(path)
		var ach = AchievementScript.new()
		ach.name = "AchievementManager"
		root.add_child(ach)
		ach.save_mgr = mgr
		ach.set_process(false)
		ach.start_new_run()
		if run == 1:
			_check(int(mgr.save_data.total_kills) == 60 and int(mgr.save_data.kill_categories.get("vampire", 0)) == 60, "new managers read first run 60 real deaths")
			_check(ach.is_achievement_unlocked("first_blood"), "saved achievement survives fresh managers")
		for i in 60:
			var enemy = load("res://scenes/enemies/vampire.tscn").instantiate()
			world.add_child(enemy)
			enemy.set_physics_process(false)
			enemy.take_damage(1000000.0)
			_check(enemy.is_dead, "run %d enemy %d dies through take_damage" % [run + 1, i + 1])
			if run == 1 and i in [38, 39]:
				_check(ach.is_achievement_unlocked("novice_hunter") == (i == 39), "total 100 achievement exact second-run threshold %d" % (i + 1))
				_check(ach.is_achievement_unlocked("vampire_slayer") == (i == 39), "vampire 100 achievement exact second-run threshold %d" % (i + 1))
			await process_frame
		_check(int(ach.run_stats.kills) == 60 and int(ach.run_stats.kill_categories.get("vampire", 0)) == 60, "production death hookup records 60 local kills/categories")
		mgr.end_run(ach.get_run_stats())
		_check(int(mgr.save_data.total_kills) == (run + 1) * 60, "real run_stats settle cumulative kills")
		ach.free()
		mgr.free()
	var final_save = _fresh_save(path)
	_check(int(final_save.save_data.total_kills) == 120 and int(final_save.save_data.kill_categories.get("vampire", 0)) == 120, "disk stores 120 real kills and vampire categories")
	final_save.free()
	var legacy = AchievementScript.new()
	legacy.record_kill("vampire")
	_check(int(legacy.run_stats.get("kill_categories", {}).get("vampire", 0)) == 1, "uninitialized legacy run dictionary retains category")
	legacy.free()
	var legacy_path := String(owner.use_test_save_path(_suite + "_legacy"))
	_write(legacy_path, JSON.stringify({"version": 1, "total_kills": 321}))
	var old = _fresh_save(legacy_path)
	_check(int(old.save_data.total_kills) == 321 and old.save_data.kill_categories.is_empty(), "legacy total preserved without invented categories")
	old.free()
	for suffix in [".bak", ".tmp"]:
		var recovery_path := String(owner.use_test_save_path(_suite + "_recover"))
		_write(recovery_path + suffix, JSON.stringify({"version": 2, "total_kills": 42}))
		var recovered = _fresh_save(recovery_path)
		_check(int(recovered.save_data.total_kills) == 42, "missing primary recovers " + suffix)
		_check(recovered.try_save_game() and int(recovered._read_valid_save(recovery_path).get("total_kills", 0)) == 42, "recovery does not silently overwrite progress " + suffix)
		recovered.free()
	var corrupt_path := String(owner.use_test_save_path(_suite + "_recover"))
	_write(corrupt_path, "{broken")
	_write(corrupt_path + ".bak", JSON.stringify({"version": 2, "total_kills": 73}))
	var recovered = _fresh_save(corrupt_path)
	_check(int(recovered.save_data.total_kills) == 73, "corrupt primary recovers valid backup")
	recovered.free()
	_check(_failure_subprocess(), "expected failures validate exact diagnostics, return values, recovery and path reset")
	var daily = SaveManagerScript.new()
	daily.use_test_save_path(_suite + "_rank")
	for i in 9:
		daily.record_daily_run("2099-01-01", {"wave": i, "kills": i, "survival_time": i})
	var worst: Dictionary = daily.record_daily_run("2099-01-01", {"wave": -1, "survival_time": 999})
	_check(int(worst.rank) == 0 and String(worst.summary).contains("未上榜"), "truncated daily score reports not ranked")
	daily.free()
	for name in [_suite, _suite + "_legacy", _suite + "_recover", _suite + "_rank"]:
		owner.clear_test_save(name)
	world.queue_free()
	await process_frame
	print("RESULT save_stats pass=%d fail=%d" % [_pass, _fail])
	quit(1 if _fail else 0)

func _failure_subprocess() -> bool:
	var output: Array = []
	var log_path := "user://test_pre_audio_save_stats_failure_probe.log"
	var code := OS.execute(OS.get_executable_path(), PackedStringArray([
		"--headless", "--path", ProjectSettings.globalize_path("res://"),
		"--log-file", ProjectSettings.globalize_path(log_path),
		"--script", "res://tools/pre_audio_save_stats_test.gd", "--", "--failure-probe"
	]), output, true)
	# OS.execute uses the Windows codepage; Godot file logs are UTF-8.
	var text := FileAccess.get_file_as_string(log_path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(log_path))
	var expected := ["主存档损坏且无有效备份", "存档损坏且无可用备份", "存档替换失败"]
	var found := [0, 0, 0]
	for line in text.split("\n"):
		if line.contains("SCRIPT ERROR:") or line.contains("Parse Error:") or line.contains("❌"):
			return false
		if line.begins_with("ERROR:"):
			var known := false
			for i in expected.size():
				if line.contains(expected[i]):
					found[i] += 1
					known = true
			if not known:
				print("Unexpected child diagnostic: " + line)
				return false
	print("Failure probe exit=%d expected_diagnostics=%s marker=%s" % [code, found, text.contains("FAILURE_PROBE_OK")])
	return code == 0 and text.contains("FAILURE_PROBE_OK") and found == [3, 3, 1]

func _failure_probe() -> void:
	await process_frame
	var mgr = root.get_node("SaveManager")
	var ok := true
	# Invalid primary and orphan sidecars must all protect evidence.
	for suffix in ["", ".bak", ".tmp"]:
		var path := String(mgr.use_test_save_path(_suite + "_blocked"))
		_write(path + suffix, "{broken")
		mgr.load_game()
		ok = not mgr.try_save_game() and FileAccess.get_file_as_string(path + suffix) == "{broken" and ok
		mgr.use_test_save_path(_suite + "_reset")
		ok = not mgr._load_blocked and ok
		if not mgr._load_blocked:
			mgr.save_game() # Existing void wrapper remains callable.
			ok = FileAccess.file_exists(mgr.save_path) and ok
	# A directory occupying the target forces rename failure after tmp is flushed.
	var occupied := String(mgr.use_test_save_path(_suite + "_occupied"))
	DirAccess.make_dir_absolute(ProjectSettings.globalize_path(occupied))
	mgr.save_data.total_kills = 88
	ok = not mgr.try_save_game() and ok
	ok = int(mgr._read_valid_save(occupied + ".tmp").get("total_kills", 0)) == 88 and ok
	DirAccess.remove_absolute(ProjectSettings.globalize_path(occupied))
	var recovered = _fresh_save(occupied)
	ok = int(recovered.save_data.total_kills) == 88 and ok
	recovered.free()
	for suffix in ["_blocked", "_reset", "_occupied"]:
		mgr.clear_test_save(_suite + suffix)
	if ok:
		print("FAILURE_PROBE_OK")
	quit(0 if ok else 1)
