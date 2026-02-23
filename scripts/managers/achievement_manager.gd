extends Node
## 成就管理器（自动加载单例）
## 管理成就解锁检测和通知

signal achievement_unlocked(achievement_id: String, achievement_name: String)

const ACHIEVEMENTS: Dictionary = {
	# 击杀里程碑
	"first_blood": {
		"name": "第一滴血",
		"description": "首次击杀敌人",
		"icon": "🩸",
		"condition": "kills >= 1",
	},
	"novice_hunter": {
		"name": "初出茅庐",
		"description": "累计击杀100个敌人",
		"icon": "⚔️",
		"condition": "total_kills >= 100",
	},
	"expert_hunter": {
		"name": "猎杀专家",
		"description": "累计击杀1000个敌人",
		"icon": "🏹",
		"condition": "total_kills >= 1000",
	},
	"vampire_slayer": {
		"name": "吸血鬼猎人",
		"description": "累计击杀100只吸血鬼",
		"icon": "🧛",
		"condition": "vampire_kills >= 100",
	},
	
	# 通关挑战
	"boss_killer": {
		"name": "Boss杀手",
		"description": "首次击败吸血鬼领主",
		"icon": "👑",
		"condition": "boss_killed >= 1",
	},
	"flawless_victory": {
		"name": "无伤通关",
		"description": "击败Boss且未受伤",
		"icon": "✨",
		"condition": "flawless_boss_kill == true",
	},
	"speed_runner": {
		"name": "速通大师",
		"description": "10分钟内击败Boss",
		"icon": "⚡",
		"condition": "boss_kill_time <= 600",
	},
	
	# 生存挑战
	"survivor": {
		"name": "生存专家",
		"description": "单局存活超过15分钟",
		"icon": "⏱️",
		"condition": "survival_time >= 900",
	},
	"wave_master": {
		"name": "波次大师",
		"description": "达到第20波",
		"icon": "🌊",
		"condition": "wave >= 20",
	},
	"room_explorer": {
		"name": "探索者",
		"description": "单局探索10个房间",
		"icon": "🗺️",
		"condition": "rooms >= 10",
	},
	
	# 武器大师
	"weapon_master": {
		"name": "武器大师",
		"description": "单局将所有武器升到满级",
		"icon": "🔨",
		"condition": "all_weapons_maxed == true",
	},
	"jack_of_all_trades": {
		"name": "全能选手",
		"description": "单局使用所有类型的武器",
		"icon": "🎯",
		"condition": "all_weapon_types_used == true",
	},
	
	# 经济成就
	"rich_hunter": {
		"name": "富有的猎人",
		"description": "单局获得500血晶",
		"icon": "💎",
		"condition": "crystals_earned >= 500",
	},
	"maxed_out": {
		"name": "满级大佬",
		"description": "达到等级20",
		"icon": "⭐",
		"condition": "level >= 20",
	},
}

# 当前局统计（运行时）
var run_stats: Dictionary = {
	"kills": 0,
	"vampire_kills": 0,
	"werewolf_kills": 0,
	"bat_kills": 0,
	"zombie_kills": 0,
	"skeleton_kills": 0,
	"exploder_kills": 0,
	"elite_kills": 0,
	"boss_killed": false,
	"flawless_boss_kill": false,
	"boss_kill_time": 0,
	"survival_time": 0,
	"wave": 0,
	"rooms": 0,
	"level": 1,
	"crystals_earned": 0,
	"weapons_maxed": [],
	"weapon_types_used": [],
	"damage_taken": 0,
	"start_time": 0,
}

# 本局解锁的成就
var unlocked_this_run: Array[String] = []

# 引用 SaveManager
var save_mgr: Node = null

func _ready() -> void:
	save_mgr = get_node_or_null("/root/SaveManager")
	print("🏆 成就管理器已初始化")

# === 开始新游戏 ===
func start_new_run() -> void:
	run_stats = {
		"kills": 0,
		"vampire_kills": 0,
		"werewolf_kills": 0,
		"bat_kills": 0,
		"zombie_kills": 0,
		"skeleton_kills": 0,
		"exploder_kills": 0,
		"elite_kills": 0,
		"boss_killed": false,
		"flawless_boss_kill": false,
		"boss_kill_time": 0,
		"survival_time": 0,
		"wave": 0,
		"rooms": 0,
		"level": 1,
		"crystals_earned": 0,
		"weapons_maxed": [],
		"weapon_types_used": [],
		"damage_taken": 0,
		"start_time": Time.get_unix_time_from_system(),
	}
	unlocked_this_run.clear()
	print("🏆 新游戏开始，成就统计已重置")

# === 更新统计 ===
func record_kill(enemy_type: String) -> void:
	run_stats["kills"] += 1
	match enemy_type:
		"vampire":
			run_stats["vampire_kills"] += 1
		"werewolf":
			run_stats["werewolf_kills"] += 1
		"bat":
			run_stats["bat_kills"] += 1
		"zombie":
			run_stats["zombie_kills"] += 1
		"skeleton":
			run_stats["skeleton_kills"] += 1
		"exploder":
			run_stats["exploder_kills"] += 1
		"elite":
			run_stats["elite_kills"] += 1
	
	# 检查成就
	_check_achievements()

func record_boss_kill(damage_taken_in_boss_fight: int) -> void:
	run_stats["boss_killed"] = true
	run_stats["boss_kill_time"] = int(Time.get_unix_time_from_system() - run_stats["start_time"])
	run_stats["flawless_boss_kill"] = (damage_taken_in_boss_fight == 0)
	_check_achievements()

func record_damage_taken(amount: float) -> void:
	run_stats["damage_taken"] += amount

func update_wave(wave: int) -> void:
	run_stats["wave"] = wave
	_check_achievements()

func update_rooms(rooms: int) -> void:
	run_stats["rooms"] = rooms
	_check_achievements()

func update_level(level: int) -> void:
	run_stats["level"] = level
	_check_achievements()

func record_crystals_earned(amount: int) -> void:
	run_stats["crystals_earned"] += amount
	_check_achievements()

func record_weapon_maxed(weapon_name: String) -> void:
	if weapon_name not in run_stats["weapons_maxed"]:
		run_stats["weapons_maxed"].append(weapon_name)
	_check_achievements()

func record_weapon_used(weapon_type: String) -> void:
	if weapon_type not in run_stats["weapon_types_used"]:
		run_stats["weapon_types_used"].append(weapon_type)

# === 成就检测 ===
func _check_achievements() -> void:
	for achievement_id in ACHIEVEMENTS:
		if is_achievement_unlocked(achievement_id):
			continue
		if _check_condition(ACHIEVEMENTS[achievement_id]["condition"]):
			_unlock_achievement(achievement_id)

func _check_condition(condition: String) -> bool:
	# 解析条件字符串
	if condition == "flawless_boss_kill == true":
		return run_stats.get("flawless_boss_kill", false)
	if condition == "all_weapons_maxed == true":
		# 简化：至少3个武器满级
		return run_stats["weapons_maxed"].size() >= 3
	if condition == "all_weapon_types_used == true":
		# 简化：至少使用3种武器
		return run_stats["weapon_types_used"].size() >= 3
	
	# 解析比较条件 (如 "kills >= 100")
	var parts: PackedStringArray = condition.split(" ")
	if parts.size() != 3:
		return false
	
	var key: String = parts[0]
	var op: String = parts[1]
	var value: int = int(parts[2])
	
	var stat_value: int = run_stats.get(key, 0)
	
	match op:
		">=":
			return stat_value >= value
		"<=":
			return stat_value <= value
		"==":
			return stat_value == value
		">":
			return stat_value > value
		"<":
			return stat_value < value
	
	return false

func _unlock_achievement(achievement_id: String) -> void:
	if achievement_id in unlocked_this_run:
		return
	
	unlocked_this_run.append(achievement_id)
	
	# 保存到存档
	if save_mgr:
		if not save_mgr.save_data.has("achievements"):
			save_mgr.save_data["achievements"] = []
		if achievement_id not in save_mgr.save_data["achievements"]:
			save_mgr.save_data["achievements"].append(achievement_id)
			save_mgr.save_game()
	
	var achievement: Dictionary = ACHIEVEMENTS[achievement_id]
	print("🏆 成就解锁: %s - %s" % [achievement["name"], achievement["description"]])
	achievement_unlocked.emit(achievement_id, achievement["name"])

# === 查询 ===
func is_achievement_unlocked(achievement_id: String) -> bool:
	if achievement_id in unlocked_this_run:
		return true
	if save_mgr and save_mgr.save_data.has("achievements"):
		return achievement_id in save_mgr.save_data["achievements"]
	return false

func get_achievement_info(achievement_id: String) -> Dictionary:
	return ACHIEVEMENTS.get(achievement_id, {})

func get_all_achievements() -> Dictionary:
	return ACHIEVEMENTS

func get_unlocked_count() -> int:
	var count: int = 0
	if save_mgr and save_mgr.save_data.has("achievements"):
		count = save_mgr.save_data["achievements"].size()
	return count

func get_total_count() -> int:
	return ACHIEVEMENTS.size()

func get_unlocked_this_run() -> Array[String]:
	return unlocked_this_run

# === 获取本局统计 ===
func get_run_stats() -> Dictionary:
	# 更新生存时间
	run_stats["survival_time"] = int(Time.get_unix_time_from_system() - run_stats["start_time"])
	return run_stats
