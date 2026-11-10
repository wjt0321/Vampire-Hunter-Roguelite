extends SceneTree
## 存档隔离测试：工具测试绝不能写玩家真实存档
## 用法: godot --headless --path . --script res://tools/save_isolation_test.gd
##
## 覆盖：
##   工具运行时 SaveManager 的写入目标是 user://test_<suite>.json，不是 user://save_data.json
##   命令行识别：--script / -s / res://tools/*.tscn 场景工具都算工具运行，普通游戏场景不误判
##   解锁成就（内部会调 save_game）后，玩家真实存档逐字节不变
##   端到端：真的拉起一个 res://tools/*.tscn 场景工具，它也必须写测试存档
##   测试存档写在独立文件里，跑完能单独清理，不留垃圾
##
## 重要：本测试自身绝不写玩家真实存档。
##       所有写入类断言都排在"确认写入目标已是测试存档"之后；
##       没确认到就只判失败并跳过写入，绝不碰 user://save_data.json。

const SaveManagerScript := preload("res://scripts/managers/save_manager.gd")

const REAL_SAVE: String = "user://save_data.json"
const SUITE: String = "save_isolation_test"
## 端到端用的场景工具：它会实例化主菜单，主菜单初始化会写一次存档。
const TOOL_SCENE: String = "res://tools/_shot_menu_flow.tscn"

var _fail: int = 0
var _pass: int = 0


func _initialize() -> void:
	_run()


func _check(ok: bool, label: String) -> void:
	if ok:
		_pass += 1
		print("✅ %s" % label)
	else:
		_fail += 1
		print("❌ %s" % label)


func _digest(path: String) -> String:
	## 文件内容的 sha256；文件不存在时返回固定标记，方便对比"有没有被写过"
	if not FileAccess.file_exists(path):
		return "<missing>"
	return FileAccess.get_sha256(path)


func _finish() -> void:
	print("")
	print("通过 %d / 失败 %d" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)


func _run() -> void:
	await process_frame
	print("\n====== 存档隔离测试 ======")

	var mgr = root.get_node_or_null("SaveManager")
	_check(mgr != null, "SaveManager 单例存在")
	if mgr == null:
		_finish()
		return

	_check(String(SaveManagerScript.SAVE_PATH) == REAL_SAVE, "真实存档路径常量就是 %s" % REAL_SAVE)

	var real_before := _digest(REAL_SAVE)
	print("   玩家真实存档基线: %s" % real_before)

	# ---------- 写入目标：先确认隔离，再决定要不要写 ----------
	var default_path := str(mgr.get("save_path"))
	var isolated := default_path.begins_with("user://test_") and default_path != REAL_SAVE
	_check(isolated, "工具运行默认写入目标是测试存档（当前 %s）" % default_path)

	# ---------- 隔离入口 ----------
	var has_switch: bool = mgr.has_method("use_test_save_path")
	var has_clear: bool = mgr.has_method("clear_test_save")
	_check(has_switch, "SaveManager 提供 use_test_save_path() 切换入口")
	_check(has_clear, "SaveManager 提供 clear_test_save() 清理入口")

	var test_path := ""
	if has_switch:
		test_path = str(mgr.call("use_test_save_path", SUITE))
		_check(test_path != REAL_SAVE, "隔离路径不是玩家真实存档: %s" % test_path)
		_check(test_path.begins_with("user://test_"), "隔离路径带 test_ 前缀: %s" % test_path)
		isolated = isolated and test_path.begins_with("user://test_") and test_path != REAL_SAVE

	# ---------- 命令行识别（--script / 场景工具） ----------
	var detect_ok := false
	if mgr.has_method("detect_tool_run"):
		detect_ok = _check_tool_args(mgr)
	else:
		_check(false, "SaveManager 提供 detect_tool_run() 命令行识别入口")

	if not isolated:
		print("⚠️ 写入目标未隔离：跳过全部写入类断言（本测试绝不写玩家真实存档）")
		_finish()
		return

	# ---------- 写入不落到真实存档（写入目标已确认是测试存档） ----------
	mgr.save_data["__isolation_probe__"] = "probe-%d" % Time.get_ticks_msec()
	mgr.call("save_game")
	_check(_digest(REAL_SAVE) == real_before, "save_game() 没有改写玩家真实存档")
	_check(FileAccess.file_exists(test_path), "写入落到测试存档文件: %s" % test_path)

	# ---------- 解锁成就也不会落到真实存档 ----------
	var ach = root.get_node_or_null("AchievementManager")
	if ach != null:
		ach.call("start_new_run")
		ach.call("record_kill", "vampire")  # first_blood 成就 → 内部会 save_game()
		_check(_digest(REAL_SAVE) == real_before, "解锁成就后玩家真实存档仍未被改写")
	else:
		print("⚠️ AchievementManager 不存在，跳过成就检查")

	# ---------- 端到端：场景工具启动也必须隔离 ----------
	if detect_ok:
		_check_scene_tool(mgr, real_before)
	else:
		print("⚠️ 命令行识别不可用，跳过场景工具端到端检查")

	# ---------- 清理测试数据 ----------
	if has_clear:
		mgr.call("clear_test_save", SUITE)
		_check(not FileAccess.file_exists(test_path), "测试专属存档已清理: %s" % test_path)
	_check(_digest(REAL_SAVE) == real_before, "整个测试过程没有碰玩家真实存档")

	print("")
	_finish()


func _check_tool_args(mgr) -> bool:
	## 命令行识别：--script/-s 与 res://tools/*.tscn 都要判成工具运行，
	## 普通游戏场景（res://scenes/...）不能误判。
	var project_root := ProjectSettings.globalize_path("res://").replace("\\", "/")
	if not project_root.ends_with("/"):
		project_root += "/"
	var cases: Array = [
		{
			"label": "--script 工具脚本",
			"args": ["--headless", "--path", ".", "--script", "res://tools/foo_test.gd"],
			"tool": true,
			"suite": "foo_test",
		},
		{
			"label": "-s 短参数工具脚本",
			"args": ["-s", "res://tools/foo_test.gd"],
			"tool": true,
			"suite": "foo_test",
		},
		{
			"label": "场景工具 res://tools/*.tscn",
			"args": ["--headless", "--path", ".", "res://tools/foo_scene.tscn"],
			"tool": true,
			"suite": "foo_scene",
		},
		{
			"label": "绝对路径场景工具",
			"args": ["--headless", project_root + "tools/foo_scene.tscn"],
			"tool": true,
			"suite": "foo_scene",
		},
		{
			"label": "普通游戏主场景不误判",
			"args": ["--headless", "--path", ".", "res://scenes/ui/main_menu.tscn"],
			"tool": false,
			"suite": "",
		},
		{
			"label": "只有 --path 没有场景",
			"args": ["--headless", "--path", "."],
			"tool": false,
			"suite": "",
		},
		{
			"label": "--script 后面没跟路径时兜底套件名",
			"args": ["--headless", "--script"],
			"tool": true,
			"suite": "tool",
		},
		{
			"label": "套件名里的非法文件名字符被替换",
			"args": ["--script", "res://tools/bad:name.gd"],
			"tool": true,
			"suite": "bad_name",
		},
	]
	var all_ok := true
	for c in cases:
		var res: Dictionary = mgr.call("detect_tool_run", PackedStringArray(c["args"]))
		var is_tool := bool(res.get("is_tool", false))
		var suite := String(res.get("suite", ""))
		var ok_tool := is_tool == bool(c["tool"])
		var ok_suite := suite == String(c["suite"])
		if not (ok_tool and ok_suite):
			all_ok = false
		_check(ok_tool, "命令行 %s → 工具运行=%s（实际 %s）"
			% [c["label"], str(c["tool"]), str(is_tool)])
		_check(ok_suite, "命令行 %s → 套件名=%s（实际 %s）"
			% [c["label"], str(c["suite"]), suite])
	return all_ok


func _check_scene_tool(_mgr, real_before: String) -> void:
	## 端到端：真的拉起一个 res://tools/*.tscn 场景工具，看它写到哪个文件。
	var exe := OS.get_executable_path()
	var out: Array = []
	var args := PackedStringArray([
		"--headless",
		"--path", ProjectSettings.globalize_path("res://"),
		TOOL_SCENE,
		"--quit-after", "240",
	])
	OS.execute(exe, args, out, true)
	var text := ""
	for line in out:
		text += String(line) + "\n"
	var scene_suite := TOOL_SCENE.get_file().get_basename()
	_check(not text.contains(REAL_SAVE),
		"场景工具 %s 没有读写玩家真实存档" % TOOL_SCENE)
	_check(text.contains("user://test_%s.json" % scene_suite),
		"场景工具 %s 使用测试存档 user://test_%s.json" % [TOOL_SCENE, scene_suite])
	_check(_digest(REAL_SAVE) == real_before, "场景工具运行后玩家真实存档仍未被改写")
	if text.contains(REAL_SAVE):
		print("   --- 子进程日志里的存档行 ---")
		for line in text.split("\n"):
			if line.contains("存档"):
				print("   %s" % line)
