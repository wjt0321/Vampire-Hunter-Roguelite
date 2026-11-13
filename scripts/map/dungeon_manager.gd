extends Node
class_name DungeonManager
## 地下城管理器
## 负责楼层推进、层内房间节奏（战斗/商店/宝箱/休息/Boss）、每层敌人池与 Boss 形态
##
## 结构：5 层 × 7 个节点。每层 5 间战斗、1 间特殊房、1 间 Boss。
## 波次计数全局累加（不随楼层重置），层倍率叠加在波次缩放之上

# === 层配置表 ===
# 每层 7 个节点：5 战斗 + 1 特殊 + 1 Boss。boss_id 决定场景。
const FLOOR_BLUEPRINT: Array = [
	{"index": 1, "boss_id": "blood_lord", "playable": true, "greybox": false},
	{"index": 2, "boss_id": "blood_matriarch", "playable": true, "greybox": false},
	{"index": 3, "boss_id": "tomb_warden", "playable": true, "greybox": false},
	{"index": 4, "boss_id": "alchemist_prince", "playable": true, "greybox": false},
	{"index": 5, "boss_id": "eclipse_queen", "playable": true, "greybox": false},
]

var floors_data: Array = [
	{
		"index": 1,
		"name": "血月回廊",
		"subtitle": "THE CRIMSON HALLS",
		"hint": "盾卫挡在正面，绕开再打",
		"rooms": 7,
		"special_rooms": 1,
		"rule": "halls",
		"themes": ["dungeon", "castle"],
		"enemies": ["vampire", "bat", "zombie", "skeleton_archer", "werewolf", "shield_guard", "blood_hound"],
		"boss_id": "blood_lord",
		"boss_name": "血铠领主",
		"accent": Color(0.78, 0.13, 0.18),
	},
	{
		"index": 2,
		"name": "织血巢穴",
		"subtitle": "THE BLOOD NEST",
		"hint": "祭司会治疗同伴，网要先清掉",
		"rooms": 7,
		"special_rooms": 1,
		"rule": "nest",
		"themes": ["cave", "dungeon"],
		"enemies": ["vampire", "bat", "zombie", "skeleton_archer", "werewolf",
				"exploder", "vampire_mage", "blood_priest", "web_weaver", "burrower"],
		"boss_id": "blood_matriarch",
		"boss_name": "织血母皇",
		"accent": Color(0.72, 0.16, 0.32),
	},
	{
		"index": 3,
		"name": "骸骨墓穴",
		"subtitle": "THE BONE CRYPT",
		"hint": "先打结界和棺材，别让亡者爬起来",
		"rooms": 7,
		"special_rooms": 1,
		"rule": "tomb",
		"themes": ["dungeon", "cave"],
		"enemies": ["zombie", "skeleton_archer", "gargoyle", "coffin_guard", "gem_leech", "lantern_wraith", "summoner"],
		"boss_id": "tomb_warden",
		"boss_name": "墓穴守望者",
		"accent": Color(0.45, 0.55, 0.62),
	},
	{
		"index": 4,
		"name": "炼金工坊",
		"subtitle": "THE ALCHEMY WORKS",
		"hint": "药液敌我都会伤，可以引到怪群里",
		"rooms": 7,
		"special_rooms": 1,
		"rule": "alchemy",
		"themes": ["castle", "cave"],
		"enemies": ["exploder", "elite_vampire", "vampire_mage", "alchemist_pitcher", "furnace_golem", "resonance_mage"],
		"boss_id": "alchemist_prince",
		"boss_name": "炼金亲王",
		"accent": Color(0.35, 0.75, 0.42),
	},
	{
		"index": 5,
		"name": "月蚀王座",
		"subtitle": "THE ECLIPSE THRONE",
		"hint": "看月相和落点，祭坛会改场地",
		"rooms": 7,
		"special_rooms": 1,
		"rule": "eclipse",
		"themes": ["castle", "boss"],
		"enemies": ["vampire_prince", "elite_vampire", "gargoyle", "moon_wing", "vampire_mage", "summoner"],
		"boss_id": "eclipse_queen",
		"boss_name": "月蚀女王",
		"accent": Color(0.55, 0.45, 0.9),
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
## 本层已经进入的战斗房数量。商店/宝箱/休息房**不**计入。
## 远程敌人按"战斗房"逐间解禁（见 GameConfig.RANGED_UNLOCK_ROOM_BY_FLOOR）：
## 旧口径是 room_in_floor（房间序号），一间宝箱房就白白吃掉一个解禁名额，
## 于是第 1 层永远轮不到射手。
var combat_rooms_entered: int = 0
## 进入当前这间房之前，本层已经清掉的战斗房数。
## 远程解禁判定的入参就是它（不是 room_in_floor）。
var combat_rooms_before_current: int = 0
var _room_plan: Array = []
var _combat_theme_cursor: int = 0
## 岔路：房间下标 → 事件房类型。计划表本身仍写 "combat"，不选就走原计划。
var _forks: Dictionary = {}
var _variants: Dictionary = {}
var _pending_choice: String = ""
## 每日挑战把地图随机从全局 RNG 里拆出来。为空时仍用 randf/shuffle，普通局不变。
var _rng: RandomNumberGenerator = null

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
	combat_rooms_entered = 0
	combat_rooms_before_current = 0
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
	combat_rooms_entered = 0
	combat_rooms_before_current = 0
	_combat_theme_cursor = 0
	_generate_room_plan()
	floor_started.emit(current_floor, get_current_floor_data())
	return true

# ==================== 房间节奏 ====================

func use_rng(rng: RandomNumberGenerator) -> void:
	## 必须在 start_dungeon / advance_floor 之前调用。
	## 传 null 等于回到全局随机。
	_rng = rng

func _randf() -> float:
	if _rng != null:
		return _rng.randf()
	return randf()

func _shuffle(items: Array) -> void:
	if _rng == null:
		items.shuffle()
		return
	for i in range(items.size() - 1, 0, -1):
		var j: int = _rng.randi_range(0, i)
		var tmp: Variant = items[i]
		items[i] = items[j]
		items[j] = tmp

func _generate_room_plan() -> void:
	## 生成本层房间序列：最后一间固定 Boss，前面按配置穿插特殊房间
	_room_plan.clear()
	_forks.clear()
	_variants.clear()
	_pending_choice = ""
	var total: int = get_room_count()
	var boss_index: int = total - 1

	for i in range(total):
		_room_plan.append("combat")

	# 候选位：第 2 间到 Boss 房前一间
	var candidates: Array = []
	for i in range(1, boss_index):
		candidates.append(i)
	_shuffle(candidates)

	var special_count: int = mini(get_special_count(), candidates.size())
	for k in range(special_count):
		_room_plan[candidates[k]] = _roll_special_type()

	_room_plan[boss_index] = "boss"
	_place_variant()
	_place_forks()

func _place_variant() -> void:
	## 每层只给一间战斗房一个看得见的修饰。第一间和 Boss 房不挂。
	var slots: Array = []
	for i in range(1, _room_plan.size() - 1):
		if String(_room_plan[i]) == "combat":
			slots.append(i)
	if slots.is_empty():
		return
	_shuffle(slots)
	_variants[int(slots[0])] = GameConfig.room_variant_for_floor(current_floor)

func _place_forks() -> void:
	## 只挂在“仍是战斗房”的格子上。第一间和 Boss 房不挂，
	## 商店/宝箱/休息的数量也不被岔路吃掉——岔路是战斗房的替代选项。
	var boss_index: int = _room_plan.size() - 1
	var slots: Array = []
	for i in range(1, boss_index):
		if String(_room_plan[i]) == "combat":
			slots.append(i)
	_shuffle(slots)
	var types: Array = GameConfig.MAP_EVENT_TYPES.duplicate()
	_shuffle(types)
	var want: int = mini(GameConfig.map_event_forks(current_floor), slots.size())
	for k in range(want):
		_forks[int(slots[k])] = String(types[k % types.size()])

func _roll_special_type() -> String:
	var roll := _randf()
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
	var room_type: String = String(_room_plan[idx])
	if _pending_choice != "":
		var event_type := String(_forks.get(idx, ""))
		if _pending_choice == room_type or _pending_choice == event_type:
			room_type = _pending_choice
		_pending_choice = ""
	room_in_floor += 1
	rooms_cleared_total += 1
	# 战斗房计数。先记"进本房之前已清的战斗房数"，再把本房计进去。
	# 顺序不能反：反了的话本房自己就参与了自己的解禁判定。
	combat_rooms_before_current = combat_rooms_entered
	if is_combat_room(room_type):
		combat_rooms_entered += 1
	return room_type

## 这间房算不算"战斗房"。
## 战斗房 = 普通战斗 + 迷雾房 + 镜像房（都要刷怪）。
## Boss 房单独算：它只刷 Boss，不参与远程解禁的计数。
## 商店/宝箱/休息房更不算——它们不吃掉远程解禁的名额。
func is_combat_room(room_type: String) -> bool:
	return room_type == "combat" or room_type == "fog" or room_type == "mirror"

func peek_room_choices() -> Array:
	## 下一间的门口选项。没有岔路时只有计划中的那一间。
	if _room_plan.is_empty() or room_in_floor < 0 or room_in_floor >= _room_plan.size():
		return [GameConfig.room_choice_info("combat")]
	var planned := String(_room_plan[room_in_floor])
	var choices: Array = [GameConfig.room_choice_info(planned)]
	var variant := String(_variants.get(room_in_floor, ""))
	if variant != "" and planned == "combat":
		var info: Dictionary = GameConfig.room_variant_info(variant)
		choices[0]["title"] = String(info.get("title", choices[0]["title"]))
		choices[0]["detail"] = String(info.get("detail", ""))
		choices[0]["reward"] = String(info.get("reward", ""))
		choices[0]["variant"] = variant
	if _forks.has(room_in_floor):
		var event_type := String(_forks[room_in_floor])
		if event_type != planned:
			choices.append(GameConfig.room_choice_info(event_type))
	return choices

func choose_next(room_type: String) -> bool:
	## 只接受当前门口真正摆出来的那几扇门。乱传一个 "boss" 不能跳关。
	for choice in peek_room_choices():
		if String(choice.get("type", "")) == room_type:
			_pending_choice = room_type
			return true
	return false

func get_forks() -> Dictionary:
	return _forks.duplicate()

func current_variant() -> String:
	var idx := room_in_floor - 1
	if idx < 0:
		return ""
	return String(_variants.get(idx, ""))

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

func get_boss_id() -> String:
	return String(get_current_floor_data().get("boss_id", "vampire_queen"))

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
