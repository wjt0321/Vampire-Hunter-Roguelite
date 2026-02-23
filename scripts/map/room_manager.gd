extends Node
class_name RoomManager
## 房间管理器
## 管理房间切换、传送门逻辑、特殊房间生成

const ROOM_TEMPLATES: Array = [
	{"width": 40, "height": 24, "name": "标准竞技场", "obstacles": "none"},
	{"width": 50, "height": 30, "name": "宽阔大厅", "obstacles": "pillars"},
	{"width": 30, "height": 30, "name": "方形密室", "obstacles": "walls"},
]

# 特殊房间概率
const SPECIAL_ROOM_CHANCE: float = 0.25
const SHOP_WEIGHT: float = 0.4
const TREASURE_WEIGHT: float = 0.35
const REST_WEIGHT: float = 0.25

var current_room_index: int = 0
var rooms_cleared: int = 0
var current_room_node: Node2D = null
var player: CharacterBody2D = null

signal room_changed(room_index: int, room_name: String)
signal special_room_entered(room_type: String)

func setup(player_node: CharacterBody2D) -> void:
	player = player_node

func get_next_room_type() -> String:
	rooms_cleared += 1
	current_room_index += 1
	
	# 每 5 个房间出 Boss
	if rooms_cleared % 5 == 0:
		return "boss"
	
	# 随机特殊房间
	if randf() < SPECIAL_ROOM_CHANCE:
		var roll := randf()
		if roll < SHOP_WEIGHT:
			return "shop"
		elif roll < SHOP_WEIGHT + TREASURE_WEIGHT:
			return "treasure"
		else:
			return "rest"
	
	return "combat"

func get_random_template() -> Dictionary:
	return ROOM_TEMPLATES.pick_random()

func get_room_info() -> Dictionary:
	return {
		"index": current_room_index,
		"cleared": rooms_cleared,
	}
