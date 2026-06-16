extends Node2D
## 战斗地图生成器
## 程序化生成战斗房间（墙壁碰撞 + 地板 + 障碍物）

@export var room_width: float = 1280.0    # 房间宽（像素）
@export var room_height: float = 768.0    # 房间高（像素）
@export var wall_thickness: float = 32.0

var is_cleared: bool = false
var portal_spawned: bool = false

signal room_cleared
signal portal_entered

func _ready() -> void:
	_generate_room()

func _generate_room() -> void:
	_create_floor()
	_create_walls()

func _create_floor() -> void:
	# 尝试加载背景纹理
	var bg_texture := TextureManager.instance.get_background("standard")

	if bg_texture:
		# 使用纹理背景
		var sprite := Sprite2D.new()
		sprite.name = "FloorSprite"
		sprite.texture = bg_texture
		sprite.centered = false
		sprite.z_index = -10
		# 调整缩放以适应房间大小
		var tex_size: Vector2 = bg_texture.get_size()
		sprite.scale = Vector2(room_width / tex_size.x, room_height / tex_size.y)
		add_child(sprite)
	else:
		# 回退到纯色背景
		var floor_rect := ColorRect.new()
		floor_rect.name = "Floor"
		floor_rect.color = Color(0.12, 0.08, 0.15, 1.0)  # 暗紫色地板
		floor_rect.position = Vector2.ZERO
		floor_rect.size = Vector2(room_width, room_height)
		floor_rect.z_index = -10
		add_child(floor_rect)
	
	# 装饰性网格线
	var grid := _create_grid_overlay()
	add_child(grid)

func _create_grid_overlay() -> Node2D:
	var grid := Node2D.new()
	grid.name = "GridOverlay"
	grid.z_index = -9
	var grid_size := 64.0
	var line_color := Color(0.2, 0.15, 0.25, 0.3)
	# 竖线
	var x := grid_size
	while x < room_width:
		var line := Line2D.new()
		line.add_point(Vector2(x, 0))
		line.add_point(Vector2(x, room_height))
		line.width = 1.0
		line.default_color = line_color
		grid.add_child(line)
		x += grid_size
	# 横线
	var y := grid_size
	while y < room_height:
		var line := Line2D.new()
		line.add_point(Vector2(0, y))
		line.add_point(Vector2(room_width, y))
		line.width = 1.0
		line.default_color = line_color
		grid.add_child(line)
		y += grid_size
	return grid

func _create_walls() -> void:
	var wall_color := Color(0.3, 0.15, 0.2, 1.0)  # 暗红墙壁
	# 上
	_create_wall_segment(Vector2(0, 0), Vector2(room_width, wall_thickness), wall_color)
	# 下
	_create_wall_segment(Vector2(0, room_height - wall_thickness), Vector2(room_width, wall_thickness), wall_color)
	# 左
	_create_wall_segment(Vector2(0, 0), Vector2(wall_thickness, room_height), wall_color)
	# 右
	_create_wall_segment(Vector2(room_width - wall_thickness, 0), Vector2(wall_thickness, room_height), wall_color)

func _create_wall_segment(pos: Vector2, size: Vector2, color: Color) -> void:
	var wall := StaticBody2D.new()
	wall.position = pos + size / 2.0
	wall.collision_layer = 2  # 环境层
	wall.collision_mask = 0
	wall.add_to_group("walls")
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	wall.add_child(shape)
	var visual := ColorRect.new()
	visual.color = color
	visual.size = size
	visual.position = -size / 2.0
	wall.add_child(visual)
	add_child(wall)

func get_room_bounds() -> Rect2:
	return Rect2(
		Vector2(wall_thickness, wall_thickness),
		Vector2(room_width - wall_thickness * 2, room_height - wall_thickness * 2)
	)

func get_center() -> Vector2:
	return Vector2(room_width / 2.0, room_height / 2.0)

func get_room_size() -> float:
	## 返回房间对角线长度，用于限制子弹射程等
	return sqrt(room_width * room_width + room_height * room_height)

func get_random_interior_position() -> Vector2:
	var bounds := get_room_bounds()
	var margin := 48.0
	return Vector2(
		randf_range(bounds.position.x + margin, bounds.end.x - margin),
		randf_range(bounds.position.y + margin, bounds.end.y - margin)
	)

func get_spawn_position_on_edge() -> Vector2:
	## 在房间边缘生成位置（用于敌人出生点）
	var bounds := get_room_bounds()
	var side := randi() % 4
	match side:
		0:  # 上
			return Vector2(randf_range(bounds.position.x, bounds.end.x), bounds.position.y + 16)
		1:  # 下
			return Vector2(randf_range(bounds.position.x, bounds.end.x), bounds.end.y - 16)
		2:  # 左
			return Vector2(bounds.position.x + 16, randf_range(bounds.position.y, bounds.end.y))
		_:  # 右
			return Vector2(bounds.end.x - 16, randf_range(bounds.position.y, bounds.end.y))

# === 传送门 ===
func spawn_portal() -> void:
	if portal_spawned:
		return
	portal_spawned = true
	is_cleared = true
	room_cleared.emit()
	
	var portal := Area2D.new()
	portal.name = "Portal"
	portal.collision_layer = 0
	portal.collision_mask = 1  # 碰撞玩家
	portal.global_position = get_center()
	
	var portal_shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 24.0
	portal_shape.shape = circle
	portal.add_child(portal_shape)
	
	# 传送门视觉
	var portal_visual := ColorRect.new()
	portal_visual.color = Color(0.5, 0.0, 1.0, 0.8)  # 紫色传送门
	portal_visual.size = Vector2(48, 48)
	portal_visual.position = Vector2(-24, -24)
	portal.add_child(portal_visual)
	
	# 传送门光晕动画
	var glow := ColorRect.new()
	glow.color = Color(0.7, 0.3, 1.0, 0.3)
	glow.size = Vector2(64, 64)
	glow.position = Vector2(-32, -32)
	portal.add_child(glow)
	
	add_child(portal)
	
	# 延迟启用碰撞
	portal.monitoring = false
	await get_tree().create_timer(0.5).timeout
	portal.monitoring = true
	portal.body_entered.connect(_on_portal_entered)
	
	# 脉动动画
	var tween := create_tween().set_loops()
	tween.tween_property(portal_visual, "modulate:a", 0.4, 0.8)
	tween.tween_property(portal_visual, "modulate:a", 1.0, 0.8)
	
	print("🌀 传送门已出现!")

func _on_portal_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		portal_entered.emit()

# === 障碍物生成 ===
func add_pillars(count: int = 4) -> void:
	## 添加柱子障碍物
	for i in range(count):
		var pos := get_random_interior_position()
		_create_pillar(pos)

func _create_pillar(pos: Vector2) -> void:
	var pillar := StaticBody2D.new()
	pillar.position = pos
	pillar.collision_layer = 2
	pillar.collision_mask = 0
	pillar.add_to_group("walls")
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(32, 32)
	shape.shape = rect
	pillar.add_child(shape)
	var visual := ColorRect.new()
	visual.color = Color(0.4, 0.2, 0.3, 1.0)
	visual.size = Vector2(32, 32)
	visual.position = Vector2(-16, -16)
	pillar.add_child(visual)
	add_child(pillar)

func add_inner_walls() -> void:
	## 添加内部墙壁分隔
	var wall_color := Color(0.35, 0.18, 0.25, 1.0)
	# 上方横墙
	_create_wall_segment(
		Vector2(room_width * 0.3, room_height * 0.3),
		Vector2(room_width * 0.15, wall_thickness),
		wall_color
	)
	# 下方横墙
	_create_wall_segment(
		Vector2(room_width * 0.55, room_height * 0.65),
		Vector2(room_width * 0.15, wall_thickness),
		wall_color
	)
