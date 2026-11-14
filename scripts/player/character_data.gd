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
## 被动技能图标 key（对应 assets/ui/passive_<key>.png）。
@export var passive_icon: String = ""
@export var weapon_slots: int = 4
@export var fusion_level: int = 5
@export var sprite_tint: Color = Color.WHITE

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
	data.passive_icon = "hunter_instinct"
	data.weapon_slots = 4
	data.fusion_level = 5
	data.sprite_tint = Color.WHITE
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
	data.passive_icon = "holy_ward"
	data.weapon_slots = 4
	data.fusion_level = 5
	data.sprite_tint = Color.WHITE
	return data

static func create_assassin() -> Resource:
	var data := Resource.new()
	data.set_script(load("res://scripts/player/character_data.gd"))
	data.char_id = "assassin"
	data.char_name = "刺客莉薇娅"
	data.description = "只有 3 个武器槽。两把武器 4 级就能融合，融合后不再升级。"
	data.initial_weapon = "kunai"
	data.unlock_cost = 1500
	data.base_hp = 90.0
	data.base_speed = 215.0
	data.base_damage_mult = 1.0
	data.passive_name = "断刃"
	data.passive_description = "槽位更少，融合提前一级。融合会停在 4 级。"
	data.passive_icon = "swift_boots"
	data.weapon_slots = 3
	data.fusion_level = 4
	data.sprite_tint = Color(0.62, 0.74, 1.0)
	return data

static func get_all_characters() -> Array:
	return [create_hunter(), create_priestess(), create_assassin()]
