extends Node
class_name DungeonManager
## 地下城管理器
## 负责楼层推进、层内房间节奏（战斗/商店/宝箱/休息/Boss）、每层敌人池与 Boss 形态
##
## 结构：3 层 × 5 房间 = 15 房间，每层最后一间为 Boss 房
## 波次计数全局累加（不随楼层重置），层倍率叠加在波次缩放之上

# === 层配置表 ===
# themes      : 该层战斗房间轮流使用的视觉主题
# enemies     : 该层的敌人池（波次仍会按 wave 做一次解锁过滤）
# boss_variant: 传给 vampire_lord 的形态编号（0 领主 / 1 亲王 / 2 女王）
# accent      : 楼层横幅的主题色
var floors_data: Array = [
	{
		"index": 1,
		"name": "血月回廊",
		"subtitle": "THE CRIMSON HALLS",
		"hint": "腐朽的大厅里，血的味道还很新鲜",
		"rooms": 6,
		"special_rooms": 1,
		"themes": ["dungeon", "castle"],
		"enemies": ["vampire", "bat", "zombie", "skeleton_archer", "werewolf"],
		"boss_variant": 0,
		"boss_name": "吸血鬼领主",
		"accent": Color(0.78, 0.13, 0.18),
	},
	{
		"index": 2,
		"name": "骸骨墓穴",
		"subtitle": "THE BONE CRYPT",
		"hint": "亡者在此长眠，直到有人打扰",
		"rooms": 7,
		"special_rooms": 2,
		"themes": ["cave", "dungeon"],
		"enemies": ["vampire", "bat", "zombie", "skeleton_archer", "werewolf",
				"exploder", "elite_vampire", "vampire_mage"],
		"boss_variant": 1,
		"boss_name": "血族亲王",
		"accent": Color(0.55, 0.28, 0.85),
	},
	{
		"index": 3,
		"name": "血之王座",
		"subtitle": "THE THRONE OF BLOOD",
		"hint": "一切的源头，就在这扇门后",
		"rooms": 7,
		"special_rooms": 2,
		"themes": ["castle", "boss"],
		"enemies": ["vampire", "bat", "zombie", "skeleton_archer", "werewolf",
				"exploder", "elite_vampire", "vampire_mage", "summoner",
				"gargoyle", "vampire_prince"],
		"boss_variant": 2,
		"boss_name": "血族女王 · 塞拉菲娜",
		"accent": Color(0.95, 0.72, 0.25),
	},
]

# 特殊房间权重
const WEIGHT_SHOP: float = 0.45
const WEIGHT_TREASURE: float = 0.35
const WEIGHT_REST: float = 0.20

# === 运行状态 ===
var current_floor: int = 1
var room_in_floor: int = 0
var rooms_cleared_total: int = 0
var _room_plan: Array = []
var _combat_theme_cursor: int = 0

# === 信号 ===
signal floor_started(floor_index: int, floor_data: Dictionary)
signal floor_cleared(floor_index: int, floor_data: Dictionary)
signal dungeon_cleared()

func _ready() -> void:
	add_to_group("dungeon_manager")

# ==================== 生命周期 ====================

func start_dungeon() -> void:
	## 开始一局新的地下城
	current_floor = 1
	room_in_floor = 0
	rooms_cleared_total = 0
	_combat_theme_cursor = 0
	_generate_room_plan()
	floor_started.emit(current_floor, get_current_floor_data())

func advance_floor() -> bool:
	## 当前层通过后推进到下一层。返回 false 表示已经是最后一层（地下城通关）
	var cleared_floor := current_floor
	var cleared_data := get_current_floor_data()
	floor_cleared.emit(cleared_floor, cleared_data)

	if current_floor >= GameConfig.DUNGEON_FLOOR_COUNT:
		dungeon_cleared.emit()
		return false

	current_floor += 1
	room_in_floor = 0
	_combat_theme_cursor = 0
	_generate_room_plan()
	floor_started.emit(current_floor, get_current_floor_data())
	return true

# ==================== 房间节奏 ====================

func _generate_room_plan() -> void:
	## 生成本层房间序列：最后一间固定 Boss，前面按配置穿插特殊房间
	_room_plan.clear()
	var total: int = get_room_count()
	var boss_index: int = total - 1

	for i in range(total):
		_room_plan.append("combat")

	# 候选位：第 2 间到 Boss 房前一间
	var candidates: Array = []
	for i in range(1, boss_index):
		candidates.append(i)
	candidates.shuffle()

	var special_count: int = mini(get_special_count(), candidates.size())
	for k in range(special_count):
		_room_plan[candidates[k]] = _roll_special_type()

	_room_plan[boss_index] = "boss"

func _roll_special_type() -> String:
	var roll := randf()
	if roll < WEIGHT_SHOP:
		return "shop"
	elif roll < WEIGHT_SHOP + WEIGHT_TREASURE:
		return "treasure"
	return "rest"

func consume_room() -> String:
	## 取出当前房间类型并推进到下一间
	if _room_plan.is_empty():
		_generate_room_plan()

	var idx: int = clampi(room_in_floor, 0, _room_plan.size() - 1)
	var room_type: String = _room_plan[idx]
	room_in_floor += 1
	rooms_cleared_total += 1
	return room_type

func peek_next_room_type() -> String:
	if _room_plan.is_empty():
		return "combat"
	var idx: int = clampi(room_in_floor, 0, _room_plan.size() - 1)
	return _room_plan[idx]

func is_boss_room() -> bool:
	return peek_next_room_type() == "boss"

func is_last_floor() -> bool:
	return current_floor >= GameConfig.DUNGEON_FLOOR_COUNT

func get_room_plan() -> Array:
	## 返回本层房间序列的副本（调试/测试用）
	return _room_plan.duplicate()

# ==================== 数据查询 ====================

func get_current_floor_data() -> Dictionary:
	var idx: int = clampi(current_floor - 1, 0, floors_data.size() - 1)
	return floors_data[idx]

func get_floor_name() -> String:
	return String(get_current_floor_data().get("name", "未知区域"))

func get_boss_variant() -> int:
	return int(get_current_floor_data().get("boss_variant", 0))

func get_boss_name() -> String:
	return String(get_current_floor_data().get("boss_name", "吸血鬼领主"))

func get_enemy_pool() -> Array:
	return get_current_floor_data().get("enemies", ["vampire"])

func get_combat_theme() -> String:
	## 层内战斗房轮流使用该层的主题
	var themes: Array = get_current_floor_data().get("themes", ["dungeon"])
	if themes.is_empty():
		return "dungeon"
	var theme: String = themes[_combat_theme_cursor % themes.size()]
	_combat_theme_cursor += 1
	return theme

func get_floor_hp_multiplier() -> float:
	return GameConfig.get_floor_hp_multiplier(current_floor)

func get_floor_damage_multiplier() -> float:
	return GameConfig.get_floor_damage_multiplier(current_floor)

func get_room_count() -> int:
	## 本层房间总数（含 Boss 房）
	var n: int = int(get_current_floor_data().get("rooms", GameConfig.DUNGEON_ROOMS_PER_FLOOR))
	return clampi(n, 3, GameConfig.DUNGEON_MAX_ROOMS_PER_FLOOR)

func get_special_count() -> int:
	## 本层特殊房间数量
	return int(get_current_floor_data().get("special_rooms", 1))

func get_progress_text() -> String:
	## 例："第 2 层 · 房间 3/7"
	var total: int = get_room_count()
	var shown: int = clampi(room_in_floor, 1, total)
	return "第 %d 层 · 房间 %d/%d" % [current_floor, shown, total]

func get_total_rooms_in_dungeon() -> int:
	var sum: int = 0
	for data in floors_data:
		sum += int(data.get("rooms", GameConfig.DUNGEON_ROOMS_PER_FLOOR))
	return sum
