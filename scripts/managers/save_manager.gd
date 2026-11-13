extends Node
## 存档管理器（自动加载单例）
## JSON 文件保存/加载永久进度

const SAVE_PATH: String = "user://save_data.json"

## 工具测试专用存档前缀：每个测试套件一个独立文件，跑完即删。
const TEST_SAVE_PREFIX: String = "user://test_"

## 存档版本号：结构或数值体系变化时 +1，并在 _migrate_save 中补迁移逻辑
const SAVE_VERSION: int = 2

## 实际生效的存档路径。真实游戏 = SAVE_PATH；工具测试用 use_test_save_path() 切走。
var save_path: String = SAVE_PATH
## 工具脚本运行（godot --script res://xxx.gd）时为 true：此时禁止写玩家真实存档。
var is_tool_run: bool = false
## 当前测试套件名。非空表示存档指向 user://test_<套件>.json。
var test_suite: String = ""
var _load_blocked: bool = false

func _companion_path(suffix: String) -> String:
	return save_path + suffix

# === 默认存档数据 ===
var save_data: Dictionary = _default_save_data()


func _default_save_data() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"blood_crystals": 0,         # 血晶货币
		"total_runs": 0,             # 总局数
		"best_wave": 0,              # 最高波次
		"best_rooms": 0,             # 最多房间
		"total_kills": 0,            # 累计击杀
		"kill_categories": {},       # 兼容旧档的分类累计击杀
		# 永久升级
		"upgrades": {
			"base_damage": 0,        # 基础伤害增加（每级 +5%）
			"base_hp": 0,            # 基础血量增加（每级 +10）
			"base_speed": 0,         # 基础速度增加（每级 +5%）
			"base_armor": 0,         # 基础护甲增加（每级 +3）
			"xp_bonus": 0,           # 经验加成（每级 +10%）
			"blood_crystal_bonus": 0, # 血晶获取加成（每级 +10%）
		},
		# 解锁角色
		"unlocked_characters": ["hunter"],
		# 到达对应楼层后解锁的新武器。旧武器和首批三把不进这张表。
		"unlocked_weapons": [],
		"codex": {"enemies": [], "weapons": [], "passives": [], "bosses": []},
		"selected_character": "hunter",
		# 深渊阶梯：历史最高通关深渊层
		"best_abyss": 0,
		# 每日挑战：只留当天的本地排名。换日清空，不跟历史最佳混在一张表里。
		"daily_board": {
			"date": "",
			"participation_claimed": false,
			"best_bonus_claimed": false,
			"runs": [],
		},
		# 音量设置。默认值与 AudioManager 自己的兜底值一致（0.1）。
		"audio_settings": {
			"music_volume": 0.1,
			"sfx_volume": 0.1,
		},
		# 已解锁的成就 id 列表。AchievementManager 往里写，存档时一起带走。
		"achievements": [],
	}

# 升级价格（每级递增）
const UPGRADE_COSTS: Dictionary = {
	"base_damage": [50, 100, 200, 400, 800],
	"base_hp": [30, 60, 120, 240, 500],
	"base_speed": [40, 80, 160, 320, 640],
	"base_armor": [40, 80, 160, 320, 640],
	"xp_bonus": [60, 120, 240, 480, 960],
	"blood_crystal_bonus": [80, 160, 320, 640, 1280],
}

const MAX_UPGRADE_LEVEL: int = 5

func _ready() -> void:
	var detected := detect_tool_run(OS.get_cmdline_args())
	if bool(detected.get("is_tool", false)):
		# 工具运行：存档落到独立的测试文件，绝不读写真实玩家存档
		is_tool_run = true
		test_suite = String(detected.get("suite", "tool"))
		save_path = _tool_save_path(test_suite)
		clear_test_save(test_suite)
	load_game()

func _exit_tree() -> void:
	## 工具运行结束删掉本次的测试存档，不在用户目录留垃圾
	if test_suite != "":
		clear_test_save(test_suite)

func save_game() -> void:
	try_save_game()

func try_save_game() -> bool:
	if save_path == SAVE_PATH and is_tool_run:
		push_error("工具测试禁止写玩家真实存档 %s：请改用 use_test_save_path() 切到测试存档" % SAVE_PATH)
		return false
	if _load_blocked:
		push_error("存档损坏且无可用备份，拒绝覆盖 %s" % save_path)
		return false
	var tmp_path := _companion_path(".tmp")
	var backup_path := _companion_path(".bak")
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		push_error("无法打开临时存档: %s" % FileAccess.get_open_error())
		return false
	file.store_string(JSON.stringify(save_data, "\t"))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		push_error("临时存档写入失败: %s" % write_error)
		return false
	if FileAccess.file_exists(save_path):
		if not _read_valid_save(save_path).is_empty():
			if DirAccess.copy_absolute(ProjectSettings.globalize_path(save_path), ProjectSettings.globalize_path(backup_path)) != OK:
				push_error("无法保留有效备份 %s" % backup_path)
				return false
		if DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path)) != OK:
			push_error("无法替换旧存档，临时文件保留于 %s" % tmp_path)
			return false
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp_path), ProjectSettings.globalize_path(save_path)) != OK:
		push_error("存档替换失败；恢复数据保留于 %s" % backup_path)
		return false
	print("💾 存档已保存 (%s)" % save_path)
	return true

func _read_valid_save(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var json := JSON.new()
	var result := json.parse(file.get_as_text())
	file.close()
	return json.data if result == OK and json.data is Dictionary else {}

func load_game() -> void:
	_load_blocked = false
	var loaded := _read_valid_save(save_path)
	var recovered := false
	var has_save_files := FileAccess.file_exists(save_path)
	for suffix in [".bak", ".tmp"]:
		var recovery_path := _companion_path(suffix)
		has_save_files = has_save_files or FileAccess.file_exists(recovery_path)
		if loaded.is_empty():
			loaded = _read_valid_save(recovery_path)
			recovered = not loaded.is_empty()
	if loaded.is_empty():
		if has_save_files:
			_load_blocked = true
			push_error("主存档损坏且无有效备份；保留原文件并阻止覆盖")
		else:
			print("📂 未找到存档 (%s)，使用默认数据" % save_path)
		return
	var old_version: int = int(loaded.get("version", 1))
	if old_version < SAVE_VERSION:
		loaded = _migrate_save(loaded, old_version)
		print("🔄 存档从 v%d 迁移到 v%d" % [old_version, SAVE_VERSION])
	_merge_dict(save_data, loaded)
	_sanitize_save()
	print("📂 存档已加载 (v%d) %s%s" % [SAVE_VERSION, save_path, "（备份恢复）" if recovered else ""])
	if recovered or old_version < SAVE_VERSION:
		try_save_game()

func reload_from_disk() -> bool:
	## 从当前路径重载，不改变路径、不清理文件、不重置测试状态。
	save_data = _default_save_data()
	load_game()
	return not _load_blocked

# === 测试隔离（只给 tools/ 下的工具测试用） ===

func use_test_save_path(suite: String) -> String:
	## 把存档切到 user://test_<suite>.json，测试期间只在测试文件里读写。
	## 会清掉上一次遗留的测试存档，保证每次运行从干净状态开始。返回切换后的路径。
	_load_blocked = false
	test_suite = suite
	save_path = _tool_save_path(suite)
	clear_test_save(suite)
	save_data = _default_save_data()
	return save_path

func clear_test_save(suite: String) -> void:
	## 删除属于该测试的临时存档。只删 user://test_*.json，永远不碰玩家真实存档。
	var path := _tool_save_path(suite)
	for suffix in ["", ".tmp", ".bak"]:
		var target: String = path if suffix == "" else path + suffix
		if FileAccess.file_exists(target):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(target))

func _tool_save_path(suite: String) -> String:
	return "%s%s.json" % [TEST_SAVE_PREFIX, suite]

func detect_tool_run(args: PackedStringArray) -> Dictionary:
	## 判断这次运行是不是工具测试，并给出套件名。返回 {"is_tool": bool, "suite": String}
	##
	## 规则：
	##   出现 --script / -s → 工具运行（真实游戏不会用这两个参数）
	##   参数里有 res://tools/*.tscn 或本项目 tools/ 下的场景 → 工具运行
	##   其余（真实游戏、编辑器启动的普通场景）→ 不是工具运行
	for i in args.size():
		var arg := String(args[i])
		if arg == "--script" or arg == "-s":
			var script_path := ""
			if i + 1 < args.size():
				script_path = String(args[i + 1])
			return {"is_tool": true, "suite": _safe_suite_name(script_path)}
		if _is_tool_scene_path(arg):
			return {"is_tool": true, "suite": _safe_suite_name(arg)}
	return {"is_tool": false, "suite": ""}

func _is_tool_scene_path(arg: String) -> bool:
	## 只有明确指向 tools/ 的场景才算工具运行，避免把正常游戏场景误判成工具
	var p := arg.replace("\\", "/")
	if not p.ends_with(".tscn"):
		return false
	if p.begins_with("res://tools/"):
		return true
	var project_root := ProjectSettings.globalize_path("res://").replace("\\", "/").rstrip("/")
	return p.begins_with(project_root + "/tools/")

func _safe_suite_name(raw: String) -> String:
	## 套件名取安全 basename：只留文件名、去掉扩展名、非法文件名字符换成下划线
	var name := raw.replace("\\", "/").get_file()
	if name.get_extension() != "":
		name = name.get_basename()
	var safe := ""
	for ch in name:
		safe += ch if ch.is_valid_filename() else "_"
	return safe if safe != "" else "tool"

func _migrate_save(data: Dictionary, from_version: int) -> Dictionary:
	## 逐版本升级存档结构
	var d := data.duplicate(true)
	# v1 -> v2：护甲从"固定减伤"改为"百分比减伤"，护甲等级含义不变，
	# 但需要保证新字段存在、旧字段类型正确。
	if from_version < 2:
		if not d.has("unlocked_characters") or not (d["unlocked_characters"] is Array):
			d["unlocked_characters"] = ["hunter"]
		if not d.has("upgrades") or not (d["upgrades"] is Dictionary):
			d["upgrades"] = {}
		for key in UPGRADE_COSTS.keys():
			if not d["upgrades"].has(key):
				d["upgrades"][key] = 0
	d["version"] = SAVE_VERSION
	return d

func _sanitize_save() -> void:
	## 洗一遍数据，避免手改存档或旧档导致的崩溃
	save_data["version"] = SAVE_VERSION
	save_data["blood_crystals"] = maxi(int(save_data.get("blood_crystals", 0)), 0)
	save_data["total_runs"] = maxi(int(save_data.get("total_runs", 0)), 0)
	save_data["total_kills"] = maxi(int(save_data.get("total_kills", 0)), 0)
	var categories = save_data.get("kill_categories", {})
	if not (categories is Dictionary):
		categories = {}
	for key in categories.keys():
		categories[key] = maxi(int(categories[key]), 0)
	save_data["kill_categories"] = categories
	var ups = save_data.get("upgrades", null)
	if not (ups is Dictionary):
		# 手改存档 / 写坏的存档会把 upgrades 写成字符串或数组。
		# 旧写法是 `var ups: Dictionary = save_data.get("upgrades", {})`：
		# 右边不是字典时这一行本身就是类型错误 → 读档当场崩，整局游戏读不出存档。
		ups = {}
	for key in UPGRADE_COSTS.keys():
		ups[key] = clampi(int(ups.get(key, 0)), 0, MAX_UPGRADE_LEVEL)
	save_data["upgrades"] = ups
	var unlocked = save_data.get("unlocked_characters", [])
	if not (unlocked is Array):
		unlocked = ["hunter"]
	if "hunter" not in unlocked:
		unlocked.append("hunter")
	save_data["unlocked_characters"] = unlocked
	if not (save_data.get("unlocked_weapons", []) is Array):
		save_data["unlocked_weapons"] = []
	if not (save_data.get("codex", {}) is Dictionary):
		save_data["codex"] = {"enemies": [], "weapons": [], "passives": [], "bosses": []}
	if not (save_data.get("selected_character", "") in unlocked):
		save_data["selected_character"] = "hunter"
	_sanitize_daily_board()
	_sanitize_audio_settings()
	_sanitize_achievements()

func _sanitize_audio_settings() -> void:
	## 音量设置洗白：不是字典就整段换成默认，音量一律夹回 0~1。
	## 手改存档或旧档写出 9.0 / -3.0 时，AudioManager 会拿它去设 AudioServer 音量，
	## 负数会让引擎报错、超过 1 会把音量顶满。
	var audio = save_data.get("audio_settings", null)
	if not (audio is Dictionary):
		audio = {}
	var settings: Dictionary = audio
	settings["music_volume"] = clampf(float(settings.get("music_volume", 0.1)), 0.0, 1.0)
	settings["sfx_volume"] = clampf(float(settings.get("sfx_volume", 0.1)), 0.0, 1.0)
	save_data["audio_settings"] = settings

func _sanitize_achievements() -> void:
	## 成就列表洗白：不是数组就换成空数组，顺手去掉重复项和空串。
	var achs = save_data.get("achievements", null)
	if not (achs is Array):
		achs = []
	var cleaned: Array = []
	for id in achs:
		var key: String = String(id)
		if key == "" or key in cleaned:
			continue
		cleaned.append(key)
	save_data["achievements"] = cleaned

func _merge_dict(target: Dictionary, source: Dictionary) -> void:
	## target = 默认存档，source = 存档文件。source 覆盖 target。
	##
	## 旧实现只处理"两边都有"的键：target 里没有的键直接被丢掉。
	## 于是存档文件里有、默认存档里没有的字段（audio_settings / achievements）
	## 在每次读档时整段消失——玩家调好的音量和已解锁的成就全部归零。
	## 现在补上"source 有、target 没有 → 直接收下"这一条。
	for key in source:
		if not target.has(key):
			target[key] = source[key]
			continue
		if target[key] is Dictionary and source[key] is Dictionary:
			_merge_dict(target[key], source[key])
		else:
			target[key] = source[key]

# === 血晶奖励计算 ===
func calculate_blood_crystals(stats: Dictionary) -> int:
	var base: int = 0
	base += stats.get("kills", 0) / 5        # 每 5 杀 1 血晶
	base += stats.get("rooms", 0) * 3        # 每房间 3 血晶
	base += stats.get("wave", 0) * 2         # 每波次 2 血晶
	base += stats.get("level", 1) * 5        # 每等级 5 血晶
	# 应用加成
	var bonus_level: int = get_upgrade_level("blood_crystal_bonus")
	var multiplier: float = 1.0 + bonus_level * 0.1
	return int(base * multiplier)

func add_blood_crystals(amount: int) -> void:
	save_data["blood_crystals"] += amount
	save_game()

func get_blood_crystals() -> int:
	return save_data["blood_crystals"]

# === 深渊阶梯（17.14） ===
func set_best_abyss(level: int) -> void:
	if level > int(save_data.get("best_abyss", 0)):
		save_data["best_abyss"] = level
		save_game()

func get_best_abyss() -> int:
	return int(save_data.get("best_abyss", 0))

# === 每日挑战（17.15） ===
const DAILY_BOARD_LIMIT: int = 8

func _sanitize_daily_board() -> void:
	var bucket: Variant = save_data.get("daily_board", {})
	if not (bucket is Dictionary):
		bucket = {}
	if not (bucket.get("runs", []) is Array):
		bucket["runs"] = []
	bucket["date"] = String(bucket.get("date", ""))
	bucket["participation_claimed"] = bool(bucket.get("participation_claimed", false))
	bucket["best_bonus_claimed"] = bool(bucket.get("best_bonus_claimed", false))
	save_data["daily_board"] = bucket

func _ensure_daily_bucket(date_key: String) -> Dictionary:
	_sanitize_daily_board()
	var bucket: Dictionary = save_data["daily_board"]
	if String(bucket.get("date", "")) != date_key:
		bucket = {
			"date": date_key,
			"participation_claimed": false,
			"best_bonus_claimed": false,
			"runs": [],
		}
		save_data["daily_board"] = bucket
	return bucket

func get_daily_runs(date_key: String) -> Array:
	## 只读。换日清空放在 record 里，打开面板不该把昨天的榜从内存里抹掉。
	_sanitize_daily_board()
	var bucket: Dictionary = save_data.get("daily_board", {})
	if String(bucket.get("date", "")) != date_key:
		return []
	return (bucket.get("runs", []) as Array).duplicate(true)

func record_daily_run(date_key: String, stats: Dictionary) -> Dictionary:
	## 参与奖只在当天第一局发。最佳奖只在“打赢了自己的上一条记录”时发一次。
	## 第一局永远是当天最佳，如果也发最佳奖，玩家不用打第二局就能把 250 拿满。
	if date_key == "":
		return {"crystals": 0, "summary": "", "rank": 0}
	var bucket := _ensure_daily_bucket(date_key)
	var runs: Array = bucket["runs"]
	var had_runs := not runs.is_empty()
	var prev_best: Dictionary = (runs[0] as Dictionary).duplicate(true) if had_runs else {}
	var entry := {
		"id": Time.get_ticks_usec(),
		"wave": int(stats.get("wave", 0)),
		"kills": int(stats.get("kills", 0)),
		"rooms": int(stats.get("rooms", 0)),
		"time": int(stats.get("survival_time", 0)),
		"level": int(stats.get("level", 1)),
	}
	runs.append(entry)
	runs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _daily_better(a, b)
	)
	while runs.size() > DAILY_BOARD_LIMIT:
		runs.pop_back()
	bucket["runs"] = runs
	var rank := -1
	for i in runs.size():
		if int(runs[i].get("id", -1)) == int(entry["id"]):
			rank = i
			break
	var crystals := 0
	var notes: PackedStringArray = PackedStringArray()
	if not bool(bucket.get("participation_claimed", false)):
		bucket["participation_claimed"] = true
		crystals += GameConfig.DAILY_PARTICIPATION_CRYSTALS
		notes.append("参与 +%d" % GameConfig.DAILY_PARTICIPATION_CRYSTALS)
	if had_runs and rank == 0 and _daily_better(entry, prev_best) \
			and not bool(bucket.get("best_bonus_claimed", false)):
		bucket["best_bonus_claimed"] = true
		crystals += GameConfig.DAILY_BEST_BONUS_CRYSTALS
		notes.append("今日最佳 +%d" % GameConfig.DAILY_BEST_BONUS_CRYSTALS)
	if crystals > 0:
		save_data["blood_crystals"] = int(save_data.get("blood_crystals", 0)) + crystals
	save_data["daily_board"] = bucket
	save_game()
	var summary := "每日第 %d 名" % (rank + 1) if rank >= 0 else "每日未上榜（本地榜单仅保留前 %d 名）" % DAILY_BOARD_LIMIT
	if notes.size() > 0:
		summary += " · " + "，".join(notes)
	return {"crystals": crystals, "summary": summary, "rank": rank + 1}

func _daily_better(a: Dictionary, b: Dictionary) -> bool:
	## 排序：波次高的在前，击杀次之，用时短的再其次。
	if int(a.get("wave", 0)) != int(b.get("wave", 0)):
		return int(a.get("wave", 0)) > int(b.get("wave", 0))
	if int(a.get("kills", 0)) != int(b.get("kills", 0)):
		return int(a.get("kills", 0)) > int(b.get("kills", 0))
	if int(a.get("time", 0)) != int(b.get("time", 0)):
		return int(a.get("time", 0)) < int(b.get("time", 0))
	return false

# === 永久升级 ===
func get_upgrade_level(upgrade_id: String) -> int:
	return save_data["upgrades"].get(upgrade_id, 0)

func get_upgrade_cost(upgrade_id: String) -> int:
	var level: int = get_upgrade_level(upgrade_id)
	var costs: Array = UPGRADE_COSTS.get(upgrade_id, [])
	if level >= costs.size():
		return -1  # 已满级
	return costs[level]

func purchase_upgrade(upgrade_id: String) -> bool:
	var cost: int = get_upgrade_cost(upgrade_id)
	if cost < 0 or save_data["blood_crystals"] < cost:
		return false
	save_data["blood_crystals"] -= cost
	save_data["upgrades"][upgrade_id] += 1
	save_game()
	return true

func is_upgrade_maxed(upgrade_id: String) -> bool:
	return get_upgrade_level(upgrade_id) >= MAX_UPGRADE_LEVEL

# === 角色解锁 ===
func is_character_unlocked(char_id: String) -> bool:
	return char_id in save_data["unlocked_characters"]

func unlock_character(char_id: String, cost: int) -> bool:
	if save_data["blood_crystals"] < cost:
		return false
	if is_character_unlocked(char_id):
		return false
	save_data["blood_crystals"] -= cost
	save_data["unlocked_characters"].append(char_id)
	save_game()
	return true

func is_weapon_unlocked(weapon_id: String) -> bool:
	var catalog = load("res://scripts/core/item_catalog.gd")
	var info: Dictionary = catalog.find_weapon(weapon_id)
	if int(info.get("unlock_floor", 0)) <= 0:
		return true
	return weapon_id in save_data.get("unlocked_weapons", [])

func discover_codex(kind: String, entry_id: String) -> void:
	if entry_id == "":
		return
	var book: Dictionary = save_data.get("codex", {})
	if not book.has(kind) or not (book[kind] is Array):
		book[kind] = []
	if entry_id in book[kind]:
		return
	book[kind].append(entry_id)
	save_data["codex"] = book
	save_game()

func codex_known(kind: String, entry_id: String) -> bool:
	var book: Dictionary = save_data.get("codex", {})
	return entry_id in book.get(kind, [])

func next_unlock_text() -> String:
	var catalog = load("res://scripts/core/item_catalog.gd")
	var owned: Array = save_data.get("unlocked_weapons", [])
	var next_floor := 0
	var names: PackedStringArray = PackedStringArray()
	for weapon in catalog.WEAPONS:
		var need := int(weapon.get("unlock_floor", 0))
		var wid := String(weapon.get("id", ""))
		if need <= 0 or wid in owned:
			continue
		if next_floor == 0 or need < next_floor:
			next_floor = need
			names = PackedStringArray([String(weapon.get("name", wid))])
		elif need == next_floor:
			names.append(String(weapon.get("name", wid)))
	if next_floor == 0:
		return "新武器已全部解锁"
	return "下一项解锁：到达第 %d 层，%s" % [next_floor, "、".join(names)]

func unlock_weapons_for_floor(floor_index: int) -> void:
	var catalog = load("res://scripts/core/item_catalog.gd")
	var changed := false
	var owned: Array = save_data.get("unlocked_weapons", [])
	for weapon in catalog.WEAPONS:
		var need := int(weapon.get("unlock_floor", 0))
		var wid := String(weapon.get("id", ""))
		if need > 0 and floor_index >= need and wid not in owned:
			owned.append(wid)
			changed = true
	if changed:
		save_data["unlocked_weapons"] = owned
		save_game()

func select_character(char_id: String) -> void:
	save_data["selected_character"] = char_id
	save_game()

func get_selected_character() -> String:
	return save_data["selected_character"]

# === 局结算 ===
func end_run(stats: Dictionary) -> int:
	save_data["total_runs"] += 1
	save_data["total_kills"] += stats.get("kills", 0)
	var categories: Dictionary = save_data.get("kill_categories", {})
	var run_categories: Variant = stats.get("kill_categories", {})
	if run_categories is Dictionary:
		for key in run_categories:
			categories[key] = int(categories.get(key, 0)) + int(run_categories[key])
	save_data["kill_categories"] = categories
	if stats.get("wave", 0) > save_data["best_wave"]:
		save_data["best_wave"] = stats.get("wave", 0)
	if stats.get("rooms", 0) > save_data["best_rooms"]:
		save_data["best_rooms"] = stats.get("rooms", 0)
	var crystals: int = calculate_blood_crystals(stats)
	add_blood_crystals(crystals)
	return crystals

# === 获取永久加成数值 ===
func get_bonus_damage() -> float:
	return get_upgrade_level("base_damage") * GameConfig.PERMANENT_DAMAGE_PER_LEVEL

func get_bonus_hp() -> float:
	return get_upgrade_level("base_hp") * GameConfig.PERMANENT_HP_PER_LEVEL

func get_bonus_speed() -> float:
	return get_upgrade_level("base_speed") * GameConfig.PERMANENT_SPEED_PER_LEVEL

func get_bonus_armor() -> float:
	return get_upgrade_level("base_armor") * GameConfig.PERMANENT_ARMOR_PER_LEVEL

func get_bonus_xp() -> float:
	return get_upgrade_level("xp_bonus") * GameConfig.PERMANENT_XP_PER_LEVEL
