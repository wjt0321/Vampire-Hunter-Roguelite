extends "res://scripts/enemies/enemy_base.gd"
## 血祭司。自己缩在后排，给视线内血量最低的同伴回血。墙挡住视线就治不了。
## 立绘未到，借用法师施法图并染成暗红。

const HEAL_AMOUNT := 6.0
const HEAL_INTERVAL := 1.4
const HEAL_RANGE := 280.0

var _heal_cd: float = 0.6

func _ready() -> void:
	base_hp = 14.0
	move_speed = 46.0
	base_contact_damage = 6.0
	xp_value = 9
	silver_value = 2
	super._ready()

func _load_sprite_texture() -> void:
	use_dedicated_sprite("blood_priest", "idle", Color(0.85, 0.28, 0.38))

func _get_enemy_type() -> String:
	return "blood_priest"

func _move_towards_player(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	var offset := global_position - player.global_position
	var dist := offset.length()
	var away := offset.normalized() if dist > 1.0 else Vector2.UP
	if dist < 190.0:
		velocity = away * move_speed
	else:
		velocity = away.orthogonal() * move_speed * 0.65
	move_and_slide()
	if sprite:
		sprite.flip_h = (player.global_position - global_position).x < 0.0
	_heal_cd -= delta
	if _heal_cd <= 0.0:
		_heal_cd = HEAL_INTERVAL
		if try_heal():
			play_action_strip("blood_priest", "cast", "once")

func try_heal() -> bool:
	var target := _worst_ally()
	if target == null:
		return false
	target.current_hp = minf(target.max_hp, target.current_hp + HEAL_AMOUNT)
	return true

func _worst_ally() -> Node:
	var worst: Node = null
	var worst_ratio := 1.0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy == self or not is_instance_valid(enemy):
			continue
		if enemy.get("is_dead") == true or enemy.get("counts_as_enemy") == false:
			continue
		if not ("current_hp" in enemy) or not ("max_hp" in enemy):
			continue
		if float(enemy.max_hp) <= 0.0:
			continue
		if global_position.distance_to(enemy.global_position) > HEAL_RANGE:
			continue
		if _line_blocked(enemy):
			continue
		var ratio := float(enemy.current_hp) / float(enemy.max_hp)
		if ratio >= 0.999:
			continue
		if ratio < worst_ratio:
			worst_ratio = ratio
			worst = enemy
	return worst

func _line_blocked(target: Node2D) -> bool:
	var world := get_world_2d()
	if world == null:
		return false
	var space := world.direct_space_state
	if space == null:
		return false
	var query := PhysicsRayQueryParameters2D.create(global_position, target.global_position)
	query.exclude = [get_rid()]
	query.collision_mask = GameConfig.LAYER_WALL
	return not space.intersect_ray(query).is_empty()
