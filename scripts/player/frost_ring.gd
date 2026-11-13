extends Node2D
## 寒霜圣铃。从玩家向外扩一圈，擦到的敌人吃一次低伤并挂上霜缚。
## 进化后圆环收束，原地再留一小段寒冷。

var radius: float = 120.0
var base_damage: float = 2.2
var damage_multiplier: float = 1.0
var slow_duration: float = 1.6
var linger: bool = false
var _grown: float = 0.0
var _hit_ids: Dictionary = {}
var _lingering: bool = false
var _linger_time: float = 0.0

func _ready() -> void:
	add_to_group("player_frost")
	var ring := Line2D.new()
	ring.name = "Ring"
	ring.width = 3.0
	ring.default_color = Color(0.65, 0.88, 1.0, 0.85)
	ring.closed = true
	add_child(ring)

func _physics_process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	if _lingering:
		_linger_time += delta
		_touch(radius * 0.45)
		if _linger_time >= 2.0:
			queue_free()
		return
	_grown = minf(_grown + delta * radius * 2.2, radius)
	_redraw()
	_touch(_grown)
	if _grown >= radius - 0.5:
		if linger:
			_lingering = true
			_hit_ids.clear()
		else:
			queue_free()

func _redraw() -> void:
	var ring := get_node_or_null("Ring") as Line2D
	if ring == null:
		return
	ring.clear_points()
	var use_r := radius * 0.45 if _lingering else _grown
	for i in 24:
		var a := TAU * float(i) / 24.0
		ring.add_point(Vector2(cos(a), sin(a)) * use_r)

func _touch(use_r: float) -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.get("is_dead") == true:
			continue
		if not (enemy is Node2D):
			continue
		var key := enemy.get_instance_id()
		if _hit_ids.has(key):
			continue
		if global_position.distance_to((enemy as Node2D).global_position) > use_r + 16.0:
			continue
		_hit_ids[key] = true
		if enemy.has_method("take_damage"):
			enemy.take_damage(base_damage * damage_multiplier)
		if enemy.has_method("apply_slow"):
			enemy.apply_slow(GameConfig.SLOW_MULT, slow_duration)
