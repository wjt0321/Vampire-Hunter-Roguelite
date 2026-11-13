extends Node2D
## 魂火。飞向最近的敌人，命中后回到玩家身边，路上再打一次。

var player: Node2D = null
var speed: float = 240.0
var base_damage: float = 4.2
var damage_multiplier: float = 1.0
var return_damage_mult: float = 0.5
var can_split: bool = false
var _returning: bool = false
var _hit: Dictionary = {}
var _split_done: bool = false

func _ready() -> void:
	add_to_group("player_soul")
	var blob := Polygon2D.new()
	blob.polygon = PackedVector2Array([Vector2(0, -8), Vector2(7, 0), Vector2(0, 8), Vector2(-7, 0)])
	blob.color = Color(0.95, 0.82, 0.45, 0.9)
	add_child(blob)

func _physics_process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	if not _returning:
		var target := _nearest()
		if target == null:
			_returning = true
		else:
			var dest: Vector2 = target.global_position
			global_position = global_position.move_toward(dest, speed * delta)
			if global_position.distance_to(dest) <= 18.0:
				_strike(target, 1.0)
				if can_split and not _split_done and target.get("is_dead") == true:
					_split_done = true
					_spawn_child()
				_returning = true
		return
	if player == null or not is_instance_valid(player):
		queue_free()
		return
	global_position = global_position.move_toward(player.global_position, speed * delta)
	_strike_near(return_damage_mult)
	if global_position.distance_to(player.global_position) <= 16.0:
		queue_free()

func _strike(target: Node, mult: float) -> void:
	var key := target.get_instance_id()
	if _hit.has(key):
		return
	_hit[key] = true
	if target.has_method("take_damage"):
		target.take_damage(base_damage * damage_multiplier * mult)

func _strike_near(mult: float) -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.get("is_dead") == true or not (enemy is Node2D):
			continue
		if global_position.distance_to((enemy as Node2D).global_position) <= 20.0:
			_strike(enemy, mult)

func _nearest() -> Node2D:
	var best: Node2D = null
	var best_dist := INF
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.get("is_dead") == true or not (enemy is Node2D):
			continue
		var dist := global_position.distance_squared_to((enemy as Node2D).global_position)
		if dist < best_dist:
			best_dist = dist
			best = enemy
	return best

func _spawn_child() -> void:
	if get_tree().get_nodes_in_group("player_soul").size() >= 4:
		return
	var child := duplicate()
	child.can_split = false
	child.base_damage = base_damage * 0.5
	child._returning = false
	child._hit = {}
	var parent := get_parent()
	if parent:
		parent.add_child(child)
		child.global_position = global_position
