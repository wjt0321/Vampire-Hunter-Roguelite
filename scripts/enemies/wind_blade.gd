extends Node2D
## 月翼兽俯冲后留下的短风刃。

var life: float = 0.8
var _tick: float = 0.0

func _ready() -> void:
	var line := Line2D.new()
	line.width = 4.0
	line.default_color = Color(0.75, 0.85, 1.0, 0.8)
	line.add_point(Vector2(-36, 0))
	line.add_point(Vector2(36, 0))
	add_child(line)

func _process(delta: float) -> void:
	life -= delta
	_tick += delta
	if _tick >= 0.2:
		_tick = 0.0
		for node in get_tree().get_nodes_in_group("player"):
			if node is Node2D and node.has_method("take_damage") and global_position.distance_to(node.global_position) < 40.0:
				node.take_damage(5.0)
	if life <= 0.0:
		queue_free()
