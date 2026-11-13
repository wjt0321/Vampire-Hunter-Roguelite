extends Node2D
## 炼金药液。玩家和敌人站进去都会掉血。

var radius: float = 70.0
var tick: float = 0.5
var damage: float = 8.0
var _timer: float = 0.0

func _ready() -> void:
	var pool := Polygon2D.new()
	pool.polygon = PackedVector2Array([
		Vector2(-radius, -radius * 0.6), Vector2(radius, -radius * 0.55),
		Vector2(radius * 0.8, radius * 0.6), Vector2(-radius * 0.85, radius * 0.5),
	])
	pool.color = Color(0.3, 0.85, 0.35, 0.35)
	add_child(pool)

func _process(delta: float) -> void:
	_timer += delta
	if _timer < tick:
		return
	_timer = 0.0
	for node in get_tree().get_nodes_in_group("player"):
		_hurt(node)
	for node in get_tree().get_nodes_in_group("enemies"):
		if node.get("counts_as_enemy") == false:
			continue
		_hurt(node)

func _hurt(node: Node) -> void:
	if not is_instance_valid(node) or not (node is Node2D) or not node.has_method("take_damage"):
		return
	if global_position.distance_to((node as Node2D).global_position) <= radius:
		node.take_damage(damage)
