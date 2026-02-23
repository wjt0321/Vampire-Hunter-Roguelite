extends Node2D
## 闪电链
## 自动追踪并在敌人之间跳跃

const AudioLibraryScript = preload("res://scripts/managers/audio_library.gd")

@export var base_damage: float = 15.0
@export var max_jumps: int = 3
@export var jump_range: float = 200.0
@export var damage_decay: float = 0.7
var damage_multiplier: float = 1.0

var _hit_enemies: Array = []
var _current_damage: float

@onready var line: Line2D = $Line2D

func _ready() -> void:
	line.width = 3.0
	line.default_color = Color(1.0, 1.0, 0.3, 0.8)
	
	# 查找第一个目标
	var first_target := _find_nearest_enemy(global_position)
	if first_target:
		_cast_lightning(global_position, first_target)
	else:
		queue_free()

func _cast_lightning(from_pos: Vector2, target: Node2D) -> void:
	if _hit_enemies.has(target):
		return
	
	_hit_enemies.append(target)
	
	# 绘制闪电
	var points := _generate_lightning_points(from_pos, target.global_position)
	line.points = points
	
	# 造成伤害
	if target.has_method("take_damage"):
		target.take_damage(_current_damage * damage_multiplier)
	
	# 播放音效
	var audio_lib := AudioLibraryScript.new()
	AudioManager.play_sfx(audio_lib.get_sound("shoot_magic"))
	
	# 查找下一个目标
	if _hit_enemies.size() < max_jumps:
		var next_target := _find_next_target(target.global_position)
		if next_target:
			_current_damage *= damage_decay
			_cast_lightning(target.global_position, next_target)
	
	# 延迟后消失
	await get_tree().create_timer(0.2).timeout
	_fade_out()

func _find_nearest_enemy(from_pos: Vector2) -> Node2D:
	var enemies := get_tree().get_nodes_in_group("enemies")
	var nearest: Node2D = null
	var nearest_dist: float = INF
	
	for enemy in enemies:
		if not is_instance_valid(enemy) or _hit_enemies.has(enemy):
			continue
		var dist := from_pos.distance_squared_to(enemy.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = enemy
	
	return nearest

func _find_next_target(from_pos: Vector2) -> Node2D:
	var enemies := get_tree().get_nodes_in_group("enemies")
	var nearest: Node2D = null
	var nearest_dist: float = jump_range * jump_range
	
	for enemy in enemies:
		if not is_instance_valid(enemy) or _hit_enemies.has(enemy):
			continue
		var dist := from_pos.distance_squared_to(enemy.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = enemy
	
	return nearest

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
