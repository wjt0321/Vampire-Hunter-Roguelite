extends "res://scripts/enemies/enemy_base.gd"
## 共振术士。把附近敌人连在一起分摊伤害。先杀术士，连接就断。

var blocks_random_affix: bool = true
var _link_cd: float = 0.4
var _linked: Array = []

func _ready() -> void:
	base_hp = 12.0
	move_speed = 40.0
	base_contact_damage = 4.0
	xp_value = 9
	super._ready()

func _load_sprite_texture() -> void:
	use_dedicated_sprite("resonance_mage", "idle", Color(0.62, 0.4, 0.9))

func _get_enemy_type() -> String:
	return "resonance_mage"

func _move_towards_player(delta: float) -> void:
	if player != null and global_position.distance_to(player.global_position) < 200.0:
		velocity = (global_position - player.global_position).normalized() * move_speed
		move_and_slide()
	_link_cd -= delta
	if _link_cd <= 0.0:
		_link_cd = 1.2
		if link_nearby():
			# 连上同伴：播连线动作条
			play_action_strip("resonance_mage", "cast", "once")

## 连上附近同伴时返回 true（用于播连线动作条）。
func link_nearby() -> bool:
	clear_links()
	var found: Array = []
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy == self or not is_instance_valid(enemy) or enemy.get("is_dead") == true:
			continue
		if enemy.get("counts_as_enemy") == false:
			continue
		if global_position.distance_to(enemy.global_position) > 220.0:
			continue
		found.append(enemy)
		if found.size() >= 2:
			break
	if found.size() >= 2:
		found[0].split_partner = found[1]
		found[1].split_partner = found[0]
		_linked = found
		return true
	if found.size() == 1:
		found[0].split_partner = self
		_linked = found
		return true
	return false

func clear_links() -> void:
	for enemy in _linked:
		if is_instance_valid(enemy):
			enemy.split_partner = null
	_linked.clear()

func _die() -> void:
	clear_links()
	super._die()
