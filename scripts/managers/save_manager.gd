extends Node
## 存档管理器（自动加载单例）
## JSON 文件保存/加载永久进度

const SAVE_PATH: String = "user://save_data.json"

# === 默认存档数据 ===
var save_data: Dictionary = {
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
		# 合并数据（保留新增字段）
		_merge_dict(save_data, loaded)
		print("📂 存档已加载")

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
	return get_upgrade_level("base_damage") * 0.05

func get_bonus_hp() -> float:
	return get_upgrade_level("base_hp") * 10.0

func get_bonus_speed() -> float:
	return get_upgrade_level("base_speed") * 0.05

func get_bonus_armor() -> float:
	return get_upgrade_level("base_armor") * 3.0

func get_bonus_xp() -> float:
	return get_upgrade_level("xp_bonus") * 0.1
