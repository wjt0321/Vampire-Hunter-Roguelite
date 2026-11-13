extends Area2D
## 回旋镰。沿弧线飞出再沿原路回来，去程和回程各能打到一次。
## 没有专属弹道图，先用一块三角色块顶着。

var direction: Vector2 = Vector2.RIGHT
var speed: float = 280.0
var travel: float = 240.0
var arc_width: float = 64.0
var base_damage: float = 5.5
var damage_multiplier: float = 1.0
var return_damage_mult: float = 0.6
var lateral_sign: float = 1.0

var origin: Vector2 = Vector2.ZERO
var origin_set: bool = false
var _progress: float = 0.0
var _returning: bool = false
var _hit_ids: Dictionary = {}

func _ready() -> void:
	add_to_group("player_scythe")
	collision_layer = 4
	collision_mask = 0
	monitoring = false
	if not origin_set:
		origin = global_position
		origin_set = true
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([Vector2(18, 0), Vector2(-12, 9), Vector2(-4, 0), Vector2(-12, -9)])
	poly.color = Color(0.62, 0.86, 0.58, 0.95)
	add_child(poly)

func _physics_process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	var step := speed * delta / maxf(travel, 1.0)
	if not _returning:
		_progress += step
		if _progress >= 1.0:
			_progress = 1.0
			_returning = true
			_hit_ids.clear()
	else:
		_progress -= step
		if _progress <= 0.0:
			queue_free()
			return
	var forward := direction.normalized()
	var curve := sin(_progress * PI) * arc_width * lateral_sign
	global_position = origin + forward * (travel * _progress) + forward.orthogonal() * curve
	rotation = forward.angle()
	_damage_overlapping(global_position)

func _damage_overlapping(at: Vector2) -> void:
	var amount := base_damage * damage_multiplier
	if _returning:
		amount *= return_damage_mult
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.get("is_dead") == true:
			continue
		if not (enemy is Node2D):
			continue
		if at.distance_to((enemy as Node2D).global_position) > 28.0:
			continue
		var key := enemy.get_instance_id()
		if _hit_ids.has(key):
			continue
		_hit_ids[key] = true
		if enemy.has_method("take_damage"):
			enemy.take_damage(amount)
