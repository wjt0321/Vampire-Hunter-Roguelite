extends StaticBody2D
## 可打掉的减速网。不算一只怪，不占刷怪名额。
## 没有网的贴图，用一块半透明绿色多边形先标出范围。

var max_hp: float = 12.0
var current_hp: float = 12.0
var is_dead: bool = false
var counts_as_enemy: bool = false
var _slowing: Node = null

func _ready() -> void:
	add_to_group("enemies")
	collision_layer = GameConfig.LAYER_ENEMY
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(36, 36)
	shape.shape = rect
	add_child(shape)
	var patch := Polygon2D.new()
	patch.polygon = PackedVector2Array([Vector2(-18, -12), Vector2(18, -8), Vector2(14, 16), Vector2(-16, 14)])
	patch.color = Color(0.35, 0.75, 0.4, 0.45)
	add_child(patch)

func _process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	var touching: bool = player != null and is_instance_valid(player) and global_position.distance_to(player.global_position) <= 34.0
	if touching and _slowing == null and player.has_method("add_hazard_slow"):
		player.add_hazard_slow()
		_slowing = player
	elif not touching and _slowing != null:
		if is_instance_valid(_slowing) and _slowing.has_method("remove_hazard_slow"):
			_slowing.remove_hazard_slow()
		_slowing = null

func take_damage(amount: float) -> void:
	if is_dead:
		return
	current_hp -= maxf(amount, 0.0)
	if current_hp <= 0.0:
		is_dead = true
		if _slowing != null and is_instance_valid(_slowing) and _slowing.has_method("remove_hazard_slow"):
			_slowing.remove_hazard_slow()
		queue_free()

func _exit_tree() -> void:
	if _slowing != null and is_instance_valid(_slowing) and _slowing.has_method("remove_hazard_slow"):
		_slowing.remove_hazard_slow()
		_slowing = null
