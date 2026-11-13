extends Node2D
## 月蚀安全圈。圈外的玩家会持续掉血，圈会慢慢挪动。

var radius: float = 120.0
var _timer: float = 0.0
var _angle: float = 0.0

func _ready() -> void:
	var ring := Line2D.new()
	ring.name = "Ring"
	ring.width = 3.0
	ring.default_color = Color(0.75, 0.7, 1.0, 0.8)
	ring.closed = true
	for i in 24:
		var a := TAU * float(i) / 24.0
		ring.add_point(Vector2(cos(a), sin(a)) * radius)
	add_child(ring)

func _process(delta: float) -> void:
	_angle += delta * 0.4
	position += Vector2(cos(_angle), sin(_angle)) * 18.0 * delta
	_timer += delta
	if _timer < 0.4:
		return
	_timer = 0.0
	for node in get_tree().get_nodes_in_group("player"):
		if not (node is Node2D) or not node.has_method("take_damage"):
			continue
		if global_position.distance_to((node as Node2D).global_position) > radius:
			node.take_damage(6.0)
