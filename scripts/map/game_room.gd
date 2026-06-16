extends Node2D
## 战斗地图生成器
## 程序化生成战斗房间（墙壁碰撞 + 地板 + 障碍物 + 装饰物）

@export var room_width: float = 1280.0    # 房间宽（像素）
@export var room_height: float = 768.0    # 房间高（像素）
@export var wall_thickness: float = 32.0

# 房间视觉主题
var room_theme: String = "dungeon"

const THEME_BACKGROUND_MAP: Dictionary = {
	"dungeon": "standard",
	"castle": "hall",
	"cave": "standard",
	"boss": "boss",
}

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
	# 根据主题选择背景纹理
	var bg_name: String = THEME_BACKGROUND_MAP.get(room_theme, "standard")
	var bg_texture := TextureManager.instance.get_background(bg_name)

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
	# 上
	_create_wall_segment(Vector2(0, 0), Vector2(room_width, wall_thickness), false)
	# 下
	_create_wall_segment(Vector2(0, room_height - wall_thickness), Vector2(room_width, wall_thickness), false)
	# 左
	_create_wall_segment(Vector2(0, 0), Vector2(wall_thickness, room_height), true)
	# 右
	_create_wall_segment(Vector2(room_width - wall_thickness, 0), Vector2(wall_thickness, room_height), true)

func _create_wall_segment(pos: Vector2, size: Vector2, is_vertical: bool) -> void:
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

	# 使用主题墙壁纹理（平铺而非拉伸）
	var texture := TextureManager.instance.get_tile_texture(room_theme, "wall_v" if is_vertical else "wall")
	if texture:
		var tex_w: float = texture.get_width()
		var tex_h: float = texture.get_height()
		if is_vertical:
			var tiles_y: int = ceili(size.y / tex_h)
			for i in range(tiles_y):
				var visual := Sprite2D.new()
				visual.texture = texture
				visual.centered = false
				visual.position = Vector2(-size.x / 2.0, -size.y / 2.0 + i * tex_h)
				wall.add_child(visual)
		else:
			var tiles_x: int = ceili(size.x / tex_w)
			for i in range(tiles_x):
				var visual := Sprite2D.new()
				visual.texture = texture
				visual.centered = false
				visual.position = Vector2(-size.x / 2.0 + i * tex_w, -size.y / 2.0)
				wall.add_child(visual)
	else:
		# 回退：纯色块
		var fallback := ColorRect.new()
		fallback.color = Color(0.3, 0.15, 0.2, 1.0)
		fallback.size = size
		fallback.position = -size / 2.0
		wall.add_child(fallback)

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
	portal.z_index = 2

	var portal_shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 24.0
	portal_shape.shape = circle
	portal.add_child(portal_shape)

	# 传送门视觉
	var portal_texture := TextureManager.instance.get_effect_texture("portal")
	if portal_texture:
		var portal_visual := Sprite2D.new()
		portal_visual.name = "PortalVisual"
		portal_visual.texture = portal_texture
		portal_visual.scale = Vector2(0.6, 0.6)
		portal.add_child(portal_visual)
	else:
		var portal_visual := ColorRect.new()
		portal_visual.color = Color(0.5, 0.0, 1.0, 0.8)
		portal_visual.size = Vector2(48, 48)
		portal_visual.position = Vector2(-24, -24)
		portal.add_child(portal_visual)

	add_child(portal)

	# 延迟启用碰撞
	portal.monitoring = false
	await get_tree().create_timer(0.5).timeout
	portal.monitoring = true
	portal.body_entered.connect(_on_portal_entered)

	# 脉动动画
	var tween := create_tween().set_loops()
	tween.tween_property(portal, "modulate:a", 0.5, 0.8)
	tween.tween_property(portal, "modulate:a", 1.0, 0.8)

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

	var texture := TextureManager.instance.get_tile_texture(room_theme, "pillar")
	if texture:
		var visual := Sprite2D.new()
		visual.texture = texture
		visual.scale = Vector2(32.0 / texture.get_width(), 32.0 / texture.get_height())
		pillar.add_child(visual)
	else:
		var visual := ColorRect.new()
		visual.color = Color(0.4, 0.2, 0.3, 1.0)
		visual.size = Vector2(32, 32)
		visual.position = Vector2(-16, -16)
		pillar.add_child(visual)

	add_child(pillar)

func add_inner_walls() -> void:
	## 添加内部墙壁分隔
	# 上方横墙
	_create_wall_segment(
		Vector2(room_width * 0.3, room_height * 0.3),
		Vector2(room_width * 0.15, wall_thickness),
		false
	)
	# 下方横墙
	_create_wall_segment(
		Vector2(room_width * 0.55, room_height * 0.65),
		Vector2(room_width * 0.15, wall_thickness),
		false
	)

# === 装饰物生成 ===
func add_props(count: int = 3) -> void:
	## 添加带碰撞的环境道具（棺材、书架、雕像、祭坛、断裂石柱）
	var collidable_props: Array = ["coffin", "bookshelf", "statue", "altar", "broken_pillar"]
	for i in range(count):
		var prop_name: String = collidable_props.pick_random()
		var pos := get_random_interior_position()
		_create_prop(prop_name, pos)

func _create_prop(prop_name: String, pos: Vector2) -> void:
	var texture := TextureManager.instance.get_prop_texture(prop_name)
	if texture == null:
		return

	var tex_size: Vector2 = texture.get_size()
	var collision_size := Vector2(tex_size.x * 0.7, tex_size.y * 0.5)

	var prop := StaticBody2D.new()
	prop.position = pos
	prop.collision_layer = 2
	prop.collision_mask = 0
	prop.add_to_group("walls")

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = collision_size
	shape.shape = rect
	shape.position = Vector2(0, tex_size.y * 0.15)
	prop.add_child(shape)

	var visual := Sprite2D.new()
	visual.texture = texture
	prop.add_child(visual)

	add_child(prop)

func add_decorations(count: int = 5) -> void:
	## 添加无碰撞装饰物（火把、血迹、蛛网）
	var decorations: Array = ["torch", "blood_splatter", "cobweb"]
	for i in range(count):
		var dec_name: String = decorations.pick_random()
		var pos := get_random_interior_position()
		_create_decoration(dec_name, pos)

func _create_decoration(dec_name: String, pos: Vector2) -> void:
	var texture := TextureManager.instance.get_prop_texture(dec_name)
	if texture == null:
		return

	var deco := Sprite2D.new()
	deco.texture = texture
	deco.position = pos
	deco.z_index = -8 if dec_name == "blood_splatter" else -1
	add_child(deco)

# === 特殊房间布置 ===
func setup_shop_room() -> void:
	## 商店房间：金币堆、商店招牌、商人
	room_theme = "castle"
	_add_prop_at("shop_sign", get_center() + Vector2(-120, -60))
	_add_prop_at("gold_pile", get_center() + Vector2(80, 50))
	_add_prop_at("gold_pile", get_center() + Vector2(-80, 60))
	_create_merchant(get_center() + Vector2(0, -30))
	add_decorations(2)

func setup_treasure_room() -> void:
	## 宝箱房间：大宝箱、金币堆
	room_theme = "dungeon"
	_add_prop_at("chest", get_center())
	_add_prop_at("gold_pile", get_center() + Vector2(-50, 40))
	_add_prop_at("gold_pile", get_center() + Vector2(50, 40))
	add_decorations(2)

func setup_rest_room() -> void:
	## 休息站：篝火、睡袋
	room_theme = "cave"
	_add_decoration_at("campfire", get_center())
	_add_decoration_at("bedroll", get_center() + Vector2(50, 20))
	_add_decoration_at("bedroll", get_center() + Vector2(-50, 25))
	add_decorations(2)

func _add_prop_at(prop_name: String, pos: Vector2) -> void:
	_create_prop(prop_name, pos)

func _add_decoration_at(dec_name: String, pos: Vector2) -> void:
	_create_decoration(dec_name, pos)

func _create_merchant(pos: Vector2) -> void:
	## 在房间中放置商人立绘（无碰撞装饰）
	var texture := TextureManager.instance.get_ui_texture("merchant")
	if texture == null:
		return

	var merchant := Sprite2D.new()
	merchant.name = "MerchantNPC"
	merchant.texture = texture
	merchant.position = pos
	merchant.scale = Vector2(0.8, 0.8)
	merchant.z_index = -1
	add_child(merchant)

	# 商人脚下光晕
	var glow := Sprite2D.new()
	glow.texture = TextureManager.instance.get_effect_texture("portal")
	if glow.texture:
		glow.modulate = Color(1.0, 0.9, 0.4, 0.3)
		glow.scale = Vector2(0.8, 0.4)
		merchant.add_child(glow)
