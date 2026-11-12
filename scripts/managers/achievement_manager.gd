extends Node
## 成就管理器（自动加载单例）
## 管理成就解锁检测和通知

signal achievement_unlocked(achievement_id: String, achievement_name: String)

const ACHIEVEMENTS: Dictionary = {
	# 击杀里程碑
	"first_blood": {
		"name": "第一滴血",
		"description": "首次击杀敌人",
		"icon": "ach_first_blood",
		"condition": "kills >= 1",
	},
	"novice_hunter": {
		"name": "初出茅庐",
		"description": "累计击杀100个敌人",
		"icon": "ach_novice_hunter",
		"condition": "total_kills >= 100",
	},
	"expert_hunter": {
		"name": "猎杀专家",
		"description": "累计击杀1000个敌人",
		"icon": "ach_expert_hunter",
		"condition": "total_kills >= 1000",
	},
	"vampire_slayer": {
		"name": "吸血鬼猎人",
		"description": "累计击杀100只吸血鬼",
		"icon": "ach_vampire_slayer",
		"condition": "vampire_kills >= 100",
	},
	"werewolf_hunter": {
		"name": "狼人猎手",
		"description": "累计击杀50只狼人",
		"icon": "ach_werewolf_hunter",
		"condition": "werewolf_kills >= 50",
	},
	"zombie_hunter": {
		"name": "不死终结者",
		"description": "累计击杀50只僵尸",
		"icon": "ach_zombie_hunter",
		"condition": "zombie_kills >= 50",
	},
	"exterminator": {
		"name": "灭绝者",
		"description": "累计击杀20只自爆者",
		"icon": "ach_exterminator",
		"condition": "exploder_kills >= 20",
	},
	"elite_hunter": {
		"name": "精英猎杀者",
		"description": "累计击杀30只精英吸血鬼",
		"icon": "ach_elite_hunter",
		"condition": "elite_kills >= 30",
	},
	"prince_slayer": {
		"name": "亲王克星",
		"description": "累计击杀10只血族亲王",
		"icon": "ach_prince_slayer",
		"condition": "prince_kills >= 10",
	},

	# 通关挑战
	"boss_killer": {
		"name": "Boss杀手",
		"description": "首次击败楼层 Boss",
		"icon": "ach_boss_killer",
		"condition": "boss_killed >= 1",
	},
	"crypt_breaker": {
		"name": "墓穴闯入者",
		"description": "击败第二层的血族亲王",
		"icon": "ach_crypt_breaker",
		"condition": "floors_cleared >= 2",
	},
	"throne_breaker": {
		"name": "王座终结者",
		"description": "通关地下城，击败血族女王",
		"icon": "ach_throne_breaker",
		"condition": "dungeon_cleared >= 1",
	},
	"flawless_victory": {
		"name": "无伤通关",
		"description": "击败Boss且未受伤",
		"icon": "ach_flawless_victory",
		"condition": "flawless_boss_kill == true",
	},
	"speed_runner": {
		"name": "速通大师",
		"description": "10分钟内击败Boss",
		"icon": "ach_speed_runner",
		"condition": "boss_kill_time <= 600",
	},

	# 生存挑战
	"survivor": {
		"name": "生存专家",
		"description": "单局存活超过15分钟",
		"icon": "ach_survivor",
		"condition": "survival_time >= 900",
	},
	"wave_master": {
		"name": "波次大师",
		"description": "达到第20波",
		"icon": "ach_wave_master",
		"condition": "wave >= 20",
	},
	"room_explorer": {
		"name": "探索者",
		"description": "单局探索10个房间",
		"icon": "ach_room_explorer",
		"condition": "rooms >= 10",
	},

	# 武器大师
	"weapon_master": {
		"name": "武器大师",
		"description": "单局将所有武器升到满级",
		"icon": "ach_weapon_master",
		"condition": "all_weapons_maxed == true",
	},
	"jack_of_all_trades": {
		"name": "全能选手",
		"description": "单局使用所有类型的武器",
		"icon": "ach_jack_of_all_trades",
		"condition": "all_weapon_types_used == true",
	},
	"evolutionist": {
		"name": "进化论者",
		"description": "单局进化3把武器",
		"icon": "ach_evolutionist",
		"condition": "evolved_weapons >= 3",
	},

	# 经济成就
	"rich_hunter": {
		"name": "富有的猎人",
		"description": "单局获得500血晶",
		"icon": "ach_rich_hunter",
		"condition": "crystals_earned >= 500",
	},
	"maxed_out": {
		"name": "满级大佬",
		"description": "达到等级20",
		"icon": "ach_maxed_out",
		"condition": "level >= 20",
	},

	# 探索与杂项
	"shopaholic": {
		"name": "购物狂",
		"description": "单局进入3次商店房间",
		"icon": "ach_shopaholic",
		"condition": "shops_visited >= 3",
	},
	"treasure_hunter": {
		"name": "宝藏猎人",
		"description": "单局进入3次宝箱房间",
		"icon": "ach_treasure_hunter",
		"condition": "treasures_visited >= 3",
	},
	"rest_stop": {
		"name": "短暂休息",
		"description": "单局进入2次休息站",
		"icon": "ach_rest_stop",
		"condition": "rests_visited >= 2",
	},
}

# 当前局统计（运行时）
var run_stats: Dictionary = {
	"kills": 0,
	"total_kills": 0,
	"vampire_kills": 0,
	"werewolf_kills": 0,
	"bat_kills": 0,
	"zombie_kills": 0,
	"skeleton_kills": 0,
	"exploder_kills": 0,
	"elite_kills": 0,
	"prince_kills": 0,
	"mage_kills": 0,
	"summoner_kills": 0,
	"gargoyle_kills": 0,
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
	"evolved_weapons": 0,
	"shops_visited": 0,
	"treasures_visited": 0,
	"rests_visited": 0,
	"damage_taken": 0,
	"floors_cleared": 0,
	"dungeon_cleared": 0,
	"start_time": 0,
}

# 本局解锁的成就
var unlocked_this_run: Array[String] = []

# 引用 SaveManager
var save_mgr: Node = null
var _effective_game_time: float = 0.0
var _prior_kill_categories: Dictionary = {}
var _run_finished: bool = false

func _process(delta: float) -> void:
	_effective_game_time += delta
	run_stats["survival_time"] = int(_effective_game_time)
	_check_achievements()

func get_effective_time() -> float:
	return _effective_game_time

func finish_run() -> void:
	# 截止击杀与时钟；Boss/通关奖励和结算收入仍可合法入账。
	_run_finished = true
	set_process(false)

func is_run_finished() -> bool:
	return _run_finished

func _ready() -> void:
	# autoload 在主菜单也存在；只有 start_new_run 才启用本局计时。
	set_process(false)
	save_mgr = get_node_or_null("/root/SaveManager")
	print("🏆 成就管理器已初始化")

# === 开始新游戏 ===
func start_new_run() -> void:
	_run_finished = false
	set_process(true)
	_effective_game_time = 0.0
	_prior_kill_categories = save_mgr.save_data.get("kill_categories", {}).duplicate() if save_mgr else {}
	run_stats = {
		"kills": 0,
		"total_kills": 0,
		"vampire_kills": 0,
		"werewolf_kills": 0,
		"bat_kills": 0,
		"zombie_kills": 0,
		"skeleton_kills": 0,
		"exploder_kills": 0,
		"elite_kills": 0,
		"prince_kills": 0,
		"mage_kills": 0,
		"summoner_kills": 0,
		"gargoyle_kills": 0,
		"kill_categories": {},
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
		"evolved_weapons": 0,
		"shops_visited": 0,
		"treasures_visited": 0,
		"rests_visited": 0,
		"damage_taken": 0,
		"floors_cleared": 0,
		"dungeon_cleared": 0,
		"start_time": Time.get_unix_time_from_system(),
	}
	unlocked_this_run.clear()
	print("🏆 新游戏开始，成就统计已重置")

# === 更新统计 ===
func record_kill(enemy_type: String) -> void:
	if _run_finished:
		return
	run_stats["kills"] += 1
	var categories: Variant = run_stats.get("kill_categories", {})
	if not (categories is Dictionary):
		categories = {}
	run_stats["kill_categories"] = categories
	var category := _kill_category(enemy_type)
	if category != "":
		categories[category] = int(categories.get(category, 0)) + 1
	if save_mgr != null:
		run_stats["total_kills"] = int(save_mgr.save_data.get("total_kills", 0)) + int(run_stats["kills"])
	else:
		run_stats["total_kills"] += 1
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
		"vampire_prince":
			run_stats["prince_kills"] += 1
		"vampire_mage":
			run_stats["mage_kills"] += 1
		"summoner":
			run_stats["summoner_kills"] += 1
		"gargoyle":
			run_stats["gargoyle_kills"] += 1

	# 检查成就
	_check_achievements()

func _kill_category(enemy_type: String) -> String:
	match enemy_type:
		"vampire", "werewolf", "bat", "zombie", "skeleton", "exploder", "elite", "vampire_prince", "vampire_mage", "summoner", "gargoyle":
			return enemy_type
		"skeleton_archer":
			return "skeleton"
		"elite_vampire":
			return "elite"
	return ""

func record_boss_kill(damage_taken_in_boss_fight: float) -> void:
	run_stats["boss_killed"] = true
	run_stats["boss_kill_time"] = int(_effective_game_time)
	run_stats["flawless_boss_kill"] = (damage_taken_in_boss_fight == 0)
	_check_achievements()

func record_floor_cleared(floor_index: int) -> void:
	## 记录某层已通过（取最大值，避免重复累计）
	run_stats["floors_cleared"] = maxi(int(run_stats.get("floors_cleared", 0)), floor_index)
	_check_achievements()

func record_dungeon_clear() -> void:
	run_stats["dungeon_cleared"] = 1
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

func record_weapon_evolved(_weapon_id: String) -> void:
	run_stats["evolved_weapons"] += 1
	_check_achievements()

func record_room_visit(room_type: String) -> void:
	match room_type:
		"shop":
			run_stats["shops_visited"] += 1
		"treasure":
			run_stats["treasures_visited"] += 1
		"rest":
			run_stats["rests_visited"] += 1
	_check_achievements()

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
	if condition == "boss_kill_time <= 600":
		# 速通成就需要实际击败 Boss
		return run_stats.get("boss_killed", false) and run_stats.get("boss_kill_time", 999999) <= 600
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
	var category_keys := {"vampire_kills": "vampire", "werewolf_kills": "werewolf", "zombie_kills": "zombie", "exploder_kills": "exploder", "elite_kills": "elite", "prince_kills": "vampire_prince"}
	if category_keys.has(key):
		var category: String = category_keys[key]
		stat_value = int(_prior_kill_categories.get(category, 0)) + int(run_stats.get("kill_categories", {}).get(category, 0))

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
	run_stats["survival_time"] = int(_effective_game_time)
	return run_stats
