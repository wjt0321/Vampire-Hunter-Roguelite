extends "res://scripts/enemies/enemy_base.gd"
## 炼金投手。把药瓶扔到玩家脚下，药液对谁都有害。

var _throw_cd: float = 1.4

func _ready() -> void:
	base_hp = 13.0
	move_speed = 42.0
	base_contact_damage = 5.0
	xp_value = 8
	super._ready()

func _load_sprite_texture() -> void:
	use_dedicated_sprite("alchemist_pitcher", "idle", Color(0.3, 0.7, 0.35))

func _get_enemy_type() -> String:
	return "alchemist_pitcher"

func _move_towards_player(delta: float) -> void:
	if player == null:
		return
	var dist := global_position.distance_to(player.global_position)
	if dist < 180.0:
		velocity = (global_position - player.global_position).normalized() * move_speed
		move_and_slide()
	_throw_cd -= delta
	if _throw_cd <= 0.0:
		_throw_cd = 2.6
		toss(player.global_position)
		# 投掷药瓶：播投掷动作条
		play_action_strip("alchemist_pitcher", "throw", "once")

func toss(at: Vector2) -> Node:
	var puddle = preload("res://scripts/map/potion_puddle.gd").new()
	puddle.global_position = at
	var parent := get_parent()
	if parent == null:
		return null
	parent.add_child(puddle)
	return puddle
