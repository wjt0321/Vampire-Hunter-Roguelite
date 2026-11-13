extends "res://scripts/enemies/boss_stage.gd"
## 织血母皇。产卵、铺网，卵巢被清掉以后改成高机动近身，不再回到产卵阶段。
## 外观先用旧 Boss 待机图染成绛红。幼虫用现成的蝙蝠，数量有上限。

const EGG_CAP := 3
const WEB_CAP := 3

var exposed: bool = false
var eggs_laid: int = 0
var _eggs: Array = []
var _action_timer: float = 1.1

func _ready() -> void:
	boss_title = "织血母皇"
	asset_id = "blood_matriarch"
	boss_tier = 2
	move_speed = 62.0
	base_contact_damage = 12.0
	sprite_tint = Color(0.78, 0.22, 0.42)
	_boot_boss()

func _get_enemy_type() -> String:
	return "blood_matriarch"

func lay_egg() -> Node:
	if exposed or _living_eggs() >= EGG_CAP:
		return null
	var egg := preload("res://scripts/enemies/nest_egg.gd").new()
	egg.owner_boss = self
	var parent := get_parent()
	if parent == null:
		return null
	parent.add_child(egg)
	egg.global_position = global_position + Vector2(randf_range(-70, 70), randf_range(-40, 50))
	_eggs.append(egg)
	eggs_laid += 1
	return egg

func egg_destroyed(egg: Node) -> void:
	_eggs.erase(egg)
	if eggs_laid > 0 and _living_eggs() == 0:
		_expose()

func _expose() -> void:
	if exposed:
		return
	exposed = true
	move_speed = 120.0
	base_contact_damage = 18.0
	boss_phase_changed.emit(1)

func _living_eggs() -> int:
	var count := 0
	for egg in _eggs:
		if is_instance_valid(egg) and egg.get("is_dead") != true:
			count += 1
	return count

func drop_web() -> Node:
	if _web_count() >= WEB_CAP:
		return null
	var web := preload("res://scripts/enemies/web_patch.gd").new()
	var parent := get_parent()
	if parent == null:
		return null
	parent.add_child(web)
	web.global_position = global_position + Vector2(randf_range(-50, 50), 24)
	return web

func _web_count() -> int:
	var count := 0
	var script = preload("res://scripts/enemies/web_patch.gd")
	for node in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(node) and node.get_script() == script:
			count += 1
	return count

func _physics_process(delta: float) -> void:
	if is_dead or intro_invulnerable or player == null or not is_instance_valid(player):
		return
	var to_player := player.global_position - global_position
	var speed := move_speed * (1.35 if exposed else 0.7)
	if exposed or to_player.length() > 150.0:
		velocity = to_player.normalized() * speed
	else:
		velocity = (-to_player.normalized()) * speed * 0.8
	move_and_slide()
	_action_timer -= delta
	if _action_timer > 0.0 or exposed:
		return
	_action_timer = 2.4
	if _living_eggs() < EGG_CAP and eggs_laid < EGG_CAP + 1:
		lay_egg()
	else:
		drop_web()
