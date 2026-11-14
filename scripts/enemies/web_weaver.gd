extends "res://scripts/enemies/enemy_base.gd"
## 织网者。隔一会儿在脚下留一张可打掉的减速网。
## 立绘未到，借用蝙蝠飞行动图并染成暗绿。

const WEB_INTERVAL := 3.2
const WEB_CAP := 3

var _web_cd: float = 1.2

func _ready() -> void:
	base_hp = 12.0
	move_speed = 52.0
	base_contact_damage = 7.0
	xp_value = 7
	silver_value = 1
	super._ready()

func _load_sprite_texture() -> void:
	use_dedicated_sprite("web_weaver", "idle", Color(0.32, 0.62, 0.4))

func _get_enemy_type() -> String:
	return "web_weaver"

func _move_towards_player(delta: float) -> void:
	super._move_towards_player(delta)
	_web_cd -= delta
	if _web_cd > 0.0:
		return
	if _web_count() >= WEB_CAP:
		_web_cd = 0.6
		return
	_web_cd = WEB_INTERVAL
	drop_web()

func drop_web() -> Node:
	var web := preload("res://scripts/enemies/web_patch.gd").new()
	web.global_position = global_position
	var parent := get_parent()
	if parent == null:
		return null
	parent.add_child(web)
	return web

func _web_count() -> int:
	var count := 0
	for node in get_tree().get_nodes_in_group("enemies"):
		if node.get_script() == preload("res://scripts/enemies/web_patch.gd"):
			count += 1
	return count
