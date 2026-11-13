extends Node2D
## 闪电链
## 自动追踪并在敌人之间跳跃。第一跳和后续跳跃都有半径，
## 并且只打当前房间内部的敌人——墙外被击退出去的怪不再被吸进电弧。

const RoomLookupLib = preload("res://scripts/core/room_lookup.gd")

@export var base_damage: float = 15.0
@export var max_jumps: int = 3
@export var acquire_range: float = 420.0
@export var jump_range: float = 200.0
@export var damage_decay: float = 0.7
var damage_multiplier: float = 1.0
## 当前房间的全局内框。空矩形表示这次没有房间（测试或反击未解析到房间）。
var play_bounds: Rect2 = Rect2()
## 生成方已经写好射程时置真，_ready 不再用基础射程覆盖。
var ranges_overridden: bool = false

var _hit_enemies: Array = []
var _current_damage: float

@onready var line: Line2D = $Line2D

func _ready() -> void:
	line.width = 3.0
	line.default_color = Color(1.0, 1.0, 0.3, 0.8)
	if not ranges_overridden:
		acquire_range = GameConfig.LIGHTNING_ACQUIRE_RANGE
		jump_range = GameConfig.LIGHTNING_JUMP_RANGE
	if play_bounds.size.x <= 0.0 or play_bounds.size.y <= 0.0:
		var room := RoomLookupLib.find_room(self)
		if room != null:
			play_bounds = RoomLookupLib.bounds_global(room)
	
	_current_damage = base_damage
	# 查找第一个目标：必须在索敌半径内，也必须在房间内
	var first_target := _find_target(global_position, acquire_range)
	if first_target:
		AudioManager.play_sfx(AudioLib.get_sound("lightning_chain"))
		_cast_lightning(global_position, first_target)
		await get_tree().create_timer(0.2, false).timeout
		_fade_out()
	else:
		queue_free()

func _cast_lightning(from_pos: Vector2, target: Node2D) -> void:
	if _hit_enemies.has(target):
		return
	
	_hit_enemies.append(target)
	
	# 绘制闪电
	var points := _generate_lightning_points(from_pos, target.global_position)
	for point in points:
		line.add_point(to_local(point))
	
	# 造成伤害
	if target.has_method("take_damage"):
		target.take_damage(_current_damage * damage_multiplier)
	
	# 落点电光
	var vfx := get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.spawn_chain_arc(target.global_position)

	
	# 查找下一个目标
	if _hit_enemies.size() < max_jumps:
		var next_target := _find_target(target.global_position, jump_range)
		if next_target:
			_current_damage *= damage_decay
			_cast_lightning(target.global_position, next_target)
	

func _find_target(from_pos: Vector2, max_range: float) -> Node2D:
	var enemies := get_tree().get_nodes_in_group("enemies")
	var nearest: Node2D = null
	var nearest_dist: float = max_range * max_range
	
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy.get("is_dead") == true or _hit_enemies.has(enemy):
			continue
		if not (enemy is Node2D) or not _inside_play(enemy as Node2D):
			continue
		var dist := from_pos.distance_squared_to(enemy.global_position)
		if dist <= nearest_dist:
			nearest_dist = dist
			nearest = enemy
	
	return nearest

func _inside_play(enemy: Node2D) -> bool:
	## 没有房间矩形时不猜边界（测试场景）。有房间时，墙外的坐标直接排除。
	if play_bounds.size.x <= 0.0 or play_bounds.size.y <= 0.0:
		return true
	return play_bounds.has_point(enemy.global_position)

func _generate_lightning_points(start: Vector2, end: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	points.append(start)
	
	var segments := 5
	var base_dir := (end - start).normalized()
	var segment_length := start.distance_to(end) / segments
	
	for i in range(1, segments):
		var base_pos := start + base_dir * segment_length * i
		var offset := Vector2(randf_range(-10, 10), randf_range(-10, 10))
		points.append(base_pos + offset)
	
	points.append(end)
	return points

func _fade_out() -> void:
	var tween := create_tween()
	tween.tween_property(line, "modulate:a", 0.0, 0.1)
	tween.tween_callback(queue_free)

func set_max_jumps(jumps: int) -> void:
	max_jumps = jumps
