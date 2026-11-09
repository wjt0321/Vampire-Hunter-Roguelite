extends Node
## 存档管理器（自动加载单例）
## JSON 文件保存/加载永久进度

const SAVE_PATH: String = "user://save_data.json"

## 存档版本号：结构或数值体系变化时 +1，并在 _migrate_save 中补迁移逻辑
const SAVE_VERSION: int = 2

# === 默认存档数据 ===
var save_data: Dictionary = {
	"version": SAVE_VERSION,
	"blood_crystals": 0,         # 血晶货币
	"total_runs": 0,             # 总局数
	"best_wave": 0,              # 最高波次
	"best_rooms": 0,             # 最多房间
	"total_kills": 0,            # 累计击杀
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
	load_game()

func save_game() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("无法保存: %s" % FileAccess.get_open_error())
		return
	file.store_string(JSON.stringify(save_data, "\t"))
	file.close()
	print("💾 存档已保存")

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		print("📂 未找到存档，使用默认数据")
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var json := JSON.new()
	var result := json.parse(file.get_as_text())
	file.close()
	if result != OK:
		push_error("JSON 解析失败: %s" % json.get_error_message())
		return
	var loaded: Variant = json.data
	if loaded is Dictionary:
		var old_version: int = int(loaded.get("version", 1))
		if old_version < SAVE_VERSION:
			loaded = _migrate_save(loaded, old_version)
			print("🔄 存档从 v%d 迁移到 v%d" % [old_version, SAVE_VERSION])
			# 合并数据（保留新增字段）
			_merge_dict(save_data, loaded)
			_sanitize_save()
			save_game()
		else:
			# 合并数据（保留新增字段）
			_merge_dict(save_data, loaded)
			_sanitize_save()
		print("📂 存档已加载 (v%d)" % SAVE_VERSION)

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
	var ups: Dictionary = save_data.get("upgrades", {})
	for key in UPGRADE_COSTS.keys():
		ups[key] = clampi(int(ups.get(key, 0)), 0, MAX_UPGRADE_LEVEL)
	save_data["upgrades"] = ups
	var unlocked = save_data.get("unlocked_characters", [])
	if not (unlocked is Array):
		unlocked = ["hunter"]
	if "hunter" not in unlocked:
		unlocked.append("hunter")
	save_data["unlocked_characters"] = unlocked
	if not (save_data.get("selected_character", "") in unlocked):
		save_data["selected_character"] = "hunter"
	_sanitize_daily_board()

func _merge_dict(target: Dictionary, source: Dictionary) -> void:
	for key in source:
		if target.has(key):
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
	var rank := 0
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
	var summary := "每日第 %d 名" % (rank + 1)
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

func select_character(char_id: String) -> void:
	save_data["selected_character"] = char_id
	save_game()

func get_selected_character() -> String:
	return save_data["selected_character"]

# === 局结算 ===
func end_run(stats: Dictionary) -> int:
	save_data["total_runs"] += 1
	save_data["total_kills"] += stats.get("kills", 0)
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
