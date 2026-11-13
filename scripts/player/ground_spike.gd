extends Node2D
## 预警之后才扎出的地刺。预警期间不造成伤害。

var warn_time: float = 0.55
var radius: float = 42.0
var base_damage: float = 7.0
var damage_multiplier: float = 1.0
var _elapsed: float = 0.0
var _done: bool = false

func _ready() -> void:
	var mark := Polygon2D.new()
	mark.polygon = PackedVector2Array([
		Vector2(-radius, -6), Vector2(radius, -6), Vector2(radius, 6), Vector2(-radius, 6),
	])
	mark.color = Color(0.75, 0.45, 0.2, 0.45)
	add_child(mark)

func _process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	if _done:
		return
	_elapsed += delta
	if _elapsed < warn_time:
		return
	_done = true
	erupt()
	queue_free()

func erupt() -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.get("is_dead") == true or not (enemy is Node2D):
			continue
		if global_position.distance_to((enemy as Node2D).global_position) <= radius:
			if enemy.has_method("take_damage"):
				enemy.take_damage(base_damage * damage_multiplier)
