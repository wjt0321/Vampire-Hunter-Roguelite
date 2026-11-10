extends SceneTree
## 存档递归合并回归测试（2026-11-10 玩法迭代 Task 3 追加项）
## 用法: godot --headless --path . --script res://tools/save_merge_test.gd
##
## 背景：Task 1 发现的既有数据 bug ——
##   SaveManager._merge_dict 只覆盖"默认存档里已经有的键"，
##   存档文件里存在、默认存档里没有的字段（audio_settings / achievements）
##   在读档时被整段丢掉：玩家调好的音量和已解锁的成就全部归零。
##
## 覆盖：
##   ① 存档里已有、默认里没有的字段（audio_settings / achievements）读档后还在
##   ② 默认里新增的字段（daily_board / best_abyss…）读档后不被抹掉
##   ③ 嵌套字典递归合并（upgrades 只被存档覆盖自己有的键）
##   ④ 旧版本存档迁移后同样保留这些字段
##   ⑤ 洗数据（sanitization）仍然生效：负数被夹回、类型错乱被修正
##   ⑥ 整个过程绝不碰玩家真实存档
##
## 重要：本测试只读写 user://test_save_merge_test.json，绝不写玩家真实存档。

const SaveManagerScript := preload("res://scripts/managers/save_manager.gd")

const REAL_SAVE: String = "user://save_data.json"
const SUITE: String = "save_merge_test"

var _fail: int = 0
var _pass: int = 0


func _initialize() -> void:
	_run()


func _check(ok: bool, label: String) -> void:
	if ok:
		_pass += 1
		print("  ✅ %s" % label)
	else:
		_fail += 1
		print("  ❌ %s" % label)


func _digest(path: String) -> String:
	if not FileAccess.file_exists(path):
		return "<missing>"
	return FileAccess.get_sha256(path)


func _finish() -> void:
	print("")
	print("通过 %d / 失败 %d" % [_pass, _fail])
	if _fail == 0:
		print("✅ 全部通过")
	else:
		print("❌ 失败 %d 项" % _fail)
	quit(0 if _fail == 0 else 1)


func _write_save(path: String, data: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("无法写入测试存档 %s" % path)
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()


func _run() -> void:
	await process_frame
	print("\n====== 存档递归合并回归测试 ======")

	var mgr = root.get_node_or_null("SaveManager")
	_check(mgr != null, "SaveManager 单例存在")
	if mgr == null:
		_finish()
		return

	var real_before := _digest(REAL_SAVE)
	print("   玩家真实存档基线: %s" % real_before)

	# ---------- 隔离：先切到测试存档，再做任何写入 ----------
	var test_path: String = str(mgr.call("use_test_save_path", SUITE))
	_check(test_path != REAL_SAVE, "测试存档路径不是玩家真实存档: %s" % test_path)
	_check(test_path.begins_with("user://test_"), "测试存档带 test_ 前缀: %s" % test_path)
	if test_path == REAL_SAVE:
		print("⚠️ 未隔离：跳过全部写入类断言")
		_finish()
		return

	# ---------- ① ③ 当前版本存档：既有字段保留 + 默认字段补齐 + 嵌套递归 ----------
	var save_v2: Dictionary = {
		"version": int(SaveManagerScript.SAVE_VERSION),
		"blood_crystals": 123,
		"total_kills": 42,
		"audio_settings": {"music_volume": 0.55, "sfx_volume": 0.33},
		"achievements": ["first_blood", "floor_1"],
		"upgrades": {"base_damage": 2},
	}
	_write_save(test_path, save_v2)
	mgr.call("load_game")
	var data: Dictionary = mgr.get("save_data")

	_check(data.has("audio_settings"),
		"读档后 audio_settings 还在（存档里有、默认里没有的字段）")
	if data.has("audio_settings"):
		var audio: Dictionary = data["audio_settings"]
		_check(is_equal_approx(float(audio.get("music_volume", -1.0)), 0.55),
			"音量设置读回来了：music=%.2f（存档 0.55）"
			% float(audio.get("music_volume", -1.0)))
		_check(is_equal_approx(float(audio.get("sfx_volume", -1.0)), 0.33),
			"音量设置读回来了：sfx=%.2f（存档 0.33）"
			% float(audio.get("sfx_volume", -1.0)))

	_check(data.has("achievements"),
		"读档后 achievements 还在（存档里有、默认里没有的字段）")
	if data.has("achievements"):
		var achs: Array = data["achievements"]
		_check("first_blood" in achs and "floor_1" in achs,
			"已解锁的成就读回来了（%s）" % str(achs))

	# 存档里已有的标量
	_check(int(data.get("blood_crystals", -1)) == 123,
		"存档里的血晶读回来了（%d）" % int(data.get("blood_crystals", -1)))
	_check(int(data.get("total_kills", -1)) == 42,
		"存档里的累计击杀读回来了（%d）" % int(data.get("total_kills", -1)))

	# 默认里新增的字段不能被抹掉
	_check(data.has("daily_board"),
		"默认里新增的 daily_board 没被旧存档抹掉")
	_check(data.has("best_abyss"),
		"默认里新增的 best_abyss 没被旧存档抹掉")
	_check(int(data.get("best_abyss", -1)) == 0,
		"best_abyss 保持默认值 0")

	# 嵌套字典：存档覆盖自己有的键，默认补齐自己没有的键
	var ups: Dictionary = data.get("upgrades", {})
	_check(int(ups.get("base_damage", -1)) == 2,
		"存档里的 upgrades.base_damage 覆盖了默认值（%d）" % int(ups.get("base_damage", -1)))
	_check(ups.has("base_hp") and int(ups.get("base_hp", -1)) == 0,
		"存档没有的 upgrades.base_hp 保持默认值 0")

	# ---------- ④ 旧版本存档迁移后同样保留字段 ----------
	var save_v1: Dictionary = {
		"version": 1,
		"blood_crystals": 7,
		"audio_settings": {"music_volume": 0.77, "sfx_volume": 0.11},
		"achievements": ["floor_2"],
	}
	_write_save(test_path, save_v1)
	mgr.call("load_game")
	var data_v1: Dictionary = mgr.get("save_data")
	_check(data_v1.has("audio_settings"),
		"v1 存档迁移后 audio_settings 还在")
	if data_v1.has("audio_settings"):
		_check(is_equal_approx(float((data_v1["audio_settings"] as Dictionary).get("music_volume", -1.0)), 0.77),
			"v1 存档迁移后音量读回来了")
	_check(data_v1.has("achievements") and "floor_2" in (data_v1["achievements"] as Array),
		"v1 存档迁移后成就读回来了")

	# ---------- ⑤ 洗数据仍然生效 ----------
	var save_dirty: Dictionary = {
		"version": int(SaveManagerScript.SAVE_VERSION),
		"blood_crystals": -50,
		"total_kills": -7,
		"audio_settings": {"music_volume": 9.0, "sfx_volume": -3.0},
		"achievements": "not_a_list",
		"upgrades": {"base_damage": 99},
	}
	_write_save(test_path, save_dirty)
	mgr.call("load_game")
	var data_dirty: Dictionary = mgr.get("save_data")
	_check(int(data_dirty.get("blood_crystals", -1)) >= 0,
		"负数血晶被洗成非负（%d）" % int(data_dirty.get("blood_crystals", -1)))
	_check(int(data_dirty.get("total_kills", -1)) >= 0,
		"负数击杀被洗成非负（%d）" % int(data_dirty.get("total_kills", -1)))
	_check(data_dirty.get("achievements", null) is Array,
		"类型错误的 achievements 被洗成数组")
	_check(data_dirty.get("audio_settings", null) is Dictionary,
		"类型错误的 audio_settings 被洗成字典")
	if data_dirty.get("audio_settings", null) is Dictionary:
		var dirty_audio: Dictionary = data_dirty["audio_settings"]
		_check(float(dirty_audio.get("music_volume", -1.0)) <= 1.0
			and float(dirty_audio.get("sfx_volume", -1.0)) >= 0.0,
			"越界音量被夹回 0~1（music=%.2f sfx=%.2f）"
			% [float(dirty_audio.get("music_volume", -1.0)),
			   float(dirty_audio.get("sfx_volume", -1.0))])
	var dirty_ups: Dictionary = data_dirty.get("upgrades", {})
	_check(int(dirty_ups.get("base_damage", -1)) <= int(SaveManagerScript.MAX_UPGRADE_LEVEL),
		"越界升级等级被夹回上限（base_damage=%d）"
		% int(dirty_ups.get("base_damage", -1)))

	# ---------- ⑤b 坏存档：upgrades 整段不是字典 ----------
	# 手改存档 / 写坏档都会出现这种字段。旧实现直接 `var ups: Dictionary = save_data.get("upgrades", {})`，
	# 右边是字符串时这一行就是**类型错误**，读档当场炸掉，整局游戏读不出存档。
	var save_bad: Dictionary = {
		"version": int(SaveManagerScript.SAVE_VERSION),
		"upgrades": "not_a_dict",
		"blood_crystals": 9,
	}
	_write_save(test_path, save_bad)
	mgr.call("load_game")
	var data_bad: Dictionary = mgr.get("save_data")
	_check(data_bad.get("upgrades", null) is Dictionary,
		"类型错误的 upgrades 被洗成字典（当前 %s）" % str(data_bad.get("upgrades", null)))
	if data_bad.get("upgrades", null) is Dictionary:
		var bad_ups: Dictionary = data_bad["upgrades"]
		_check(bad_ups.has("base_damage") and int(bad_ups.get("base_damage", -1)) == 0,
			"坏掉的 upgrades 被洗成默认等级（base_damage=%d）"
			% int(bad_ups.get("base_damage", -1)))
	_check(int(data_bad.get("blood_crystals", -1)) == 9,
		"坏存档里其它字段照常读回（blood_crystals=%d）"
		% int(data_bad.get("blood_crystals", -1)))

	# ---------- ⑥ 真实存档没被动过 ----------
	_check(_digest(REAL_SAVE) == real_before,
		"整个测试过程没有碰玩家真实存档")

	mgr.call("clear_test_save", SUITE)
	_check(not FileAccess.file_exists(test_path),
		"测试专属存档已清理: %s" % test_path)

	print("")
	_finish()
