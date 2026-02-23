extends Resource
## 角色数据定义

@export var char_id: String = "hunter"
@export var char_name: String = "猎人阿尔忒弥斯"
@export var description: String = "平衡型角色"
@export var initial_weapon: String = "pistol"   # 初始武器 ID
@export var unlock_cost: int = 0                # 0 = 默认角色

# 基础属性
@export var base_hp: float = 100.0
@export var base_speed: float = 200.0
@export var base_damage_mult: float = 1.0

# 被动技能
@export var passive_name: String = "无"
@export var passive_description: String = ""

static func create_hunter() -> Resource:
	var data := Resource.new()
	data.set_script(load("res://scripts/player/character_data.gd"))
	data.char_id = "hunter"
	data.char_name = "猎人阿尔忒弥斯"
	data.description = "平衡型角色，适合新手"
	data.initial_weapon = "pistol"
	data.unlock_cost = 0
	data.base_hp = 100.0
	data.base_speed = 200.0
	data.base_damage_mult = 1.0
	data.passive_name = "猎人直觉"
	data.passive_description = "拾取范围 +20%"
	return data

static func create_priestess() -> Resource:
	var data := Resource.new()
	data.set_script(load("res://scripts/player/character_data.gd"))
	data.char_id = "priestess"
	data.char_name = "牧师塞西莉亚"
	data.description = "高血量低速，防御型角色"
	data.initial_weapon = "magic_book"
	data.unlock_cost = 500
	data.base_hp = 150.0
	data.base_speed = 160.0
	data.base_damage_mult = 0.85
	data.passive_name = "神圣庇护"
	data.passive_description = "每 10 秒恢复 5% 最大生命"
	return data

static func get_all_characters() -> Array:
	return [create_hunter(), create_priestess()]
