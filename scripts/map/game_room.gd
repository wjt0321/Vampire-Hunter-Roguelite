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
## 普通传送门与玩家至少保持这么远（像素）。
## 旧版传送门固定生成在房间正中：玩家清完波一转身就踩上去了，
## 看起来像"这间还没打完就被换掉了"。
const PORTAL_MIN_PLAYER_DISTANCE: float = 320.0
## 传送门落点四周必须留出的间隙（门体半径 24 + 16 安全边距）。
## 门是直径 48px 的圆，落点离墙 10px 也算"不在墙里"，
## 但门会有一半卡进墙里，玩家根本走不进去。
const PORTAL_CLEAR_RADIUS: float = 40.0
## 最后兜底时的最小间隙：房间被塞得几乎没有空地时，
## 至少保证门心不落在障碍内部。
const PORTAL_MIN_CLEAR_RADIUS: float = 8.0
## 网格扫描的步长与内缩（像素）
const PORTAL_GRID_STEP: float = 20.0
const PORTAL_GRID_INSET: float = 16.0
## 兜底地板网格的线距。与 PORTAL_GRID_* 无关，别混用。
const GRID_LINE_STEP: float = 64.0

# === 障碍/装饰摆放 ===
## 两个摆件之间至少留这么多空隙，否则柱子边上会"糊"出一个更大的障碍。
const PLACEMENT_PADDING: float = 8.0
## 玩家出生点（房间正中）周围必须空出来的半径。
## 刷出来就卡在柱子里的观感比"这里放个柱子"更糟。
const PLAYER_SPAWN_CLEAR: float = 72.0
## 障碍离房间边界至少留这么多：边缘是刷怪点，堵住会出现"怪卡在墙里"。
const PLACEMENT_EDGE_INSET: float = 40.0
## 已经占地的矩形（障碍、道具、装饰都登记在这里，摆放时互相避让）
var _occupied_rects: Array[Rect2] = []
## 实际放进房间的数量。放不下时会少放，验收与回归测试读这三个数，
## 而不是猜节点名（重名道具会被引擎改成 @Prop_xxx@2，按名字统计会漏）。
var pillar_count: int = 0
var prop_count: int = 0
var decoration_count: int = 0

signal room_cleared
signal portal_entered
signal portal_chosen(room_type: String)

const DoorLabelScript = preload("res://scripts/map/door_label.gd")
const ReadabilityLib = preload("res://scripts/core/readability_visuals.gd")
var _choice_taken: bool = false

func _ready() -> void:
	_generate_room()

func _generate_room() -> void:
	_create_floor()
	_create_walls()

func _create_floor() -> void:
	# 背景过滤策略（显式，不靠项目默认）：
	#   · 有成品背景图 → 只贴图，不叠任何程序网格。
	#     砖缝、地砖、柱子透视全在图里，再盖一层 64px 网格就是"两套对齐规则打架"，
	#     玩家看到的是错位的斜线，敌人剪影也被切碎。
	#   · 没有成品图 → 回退纯色地板，这时网格是唯一的地面参照，保留但必须对齐。
	var bg_name: String = THEME_BACKGROUND_MAP.get(room_theme, "standard")
	var bg_texture := _get_background_texture(bg_name)

	if bg_texture:
		var sprite := Sprite2D.new()
		sprite.name = "FloorSprite"
		sprite.texture = bg_texture
		sprite.centered = false
		sprite.z_index = -10
		# 成品背景是手绘像素图，缩放是"非整数倍"，必须显式声明线性采样。
		# 项目没设 rendering/textures/canvas_textures/default_texture_filter，
		# 靠引擎默认值等于把画面交给配置，任何一处改动都会让整块地板变硬边色块。
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		var tex_size: Vector2 = bg_texture.get_size()
		sprite.scale = Vector2(room_width / tex_size.x, room_height / tex_size.y)
		add_child(sprite)
		return

	# 回退到纯色背景
	var floor_rect := ColorRect.new()
	floor_rect.name = "Floor"
	floor_rect.color = Color(0.12, 0.08, 0.15, 1.0)  # 暗紫色地板
	floor_rect.position = Vector2.ZERO
	floor_rect.size = Vector2(room_width, room_height)
	floor_rect.z_index = -10
	add_child(floor_rect)

	# 网格只在没有成品背景时出现（见上）
	add_child(_create_grid_overlay())

func _texture_manager() -> Node:
	## 取纹理管理器。**不能**用 get_node_or_null("/root/TextureManager")：
	## 商店/宝箱/休息/变异房是"先摆家具、再 add_child"（见 main._create_room），
	## 调用点还在场景树外，绝对路径查询会报
	## "Can't use get_node() with absolute paths from outside the active scene tree"
	## 并返回 null——结果是宝箱、金币堆、商人、篝火一个都画不出来，
	## 只留下一串看起来像噪音的报错。静态 instance 与是否入树无关。
	return TextureManager.instance

func _get_background_texture(bg_name: String) -> Texture2D:
	var tm := _texture_manager()
	if tm == null:
		return null
	return tm.get_background(bg_name)

func _create_grid_overlay() -> Node2D:
	## 兜底地板上的网格辅助线。
	## 线距固定 64px，且**包含房间两端的边界线**：
	## 旧版从 64 起、到 1216/704 就停，最外一圈格子和房间对不上，
	## 视觉上就是"网格比地板小一圈"。
	var grid := Node2D.new()
	grid.name = "GridOverlay"
	grid.z_index = -9
	var line_color := Color(0.2, 0.15, 0.25, 0.3)
	var x := 0.0
	while x <= room_width:
		var line := Line2D.new()
		line.add_point(Vector2(x, 0))
		line.add_point(Vector2(x, room_height))
		line.width = 1.0
		line.default_color = line_color
		grid.add_child(line)
		x += GRID_LINE_STEP
	var y := 0.0
	while y <= room_height:
		var line := Line2D.new()
		line.add_point(Vector2(0, y))
		line.add_point(Vector2(room_width, y))
		line.width = 1.0
		line.default_color = line_color
		grid.add_child(line)
		y += GRID_LINE_STEP
	return grid

func _create_walls() -> void:
	## 四条边界墙额外进 "room_bounds" 组：
	## 它们互相在四角有必然的矩形重叠（上墙横贯全宽、左墙竖贯全高），
	## 检查"家具之间有没有穿模"时必须能把它们排除掉，否则四角永远算 4 处重叠。
	#
	# 上
	_mark_bounds(_create_wall_segment(Vector2(0, 0), Vector2(room_width, wall_thickness), false))
	# 下
	_mark_bounds(_create_wall_segment(Vector2(0, room_height - wall_thickness), Vector2(room_width, wall_thickness), false))
	# 左
	_mark_bounds(_create_wall_segment(Vector2(0, 0), Vector2(wall_thickness, room_height), true))
	# 右
	_mark_bounds(_create_wall_segment(Vector2(room_width - wall_thickness, 0), Vector2(wall_thickness, room_height), true))

func _mark_bounds(wall: StaticBody2D) -> void:
	wall.add_to_group("room_bounds")

func _create_wall_segment(pos: Vector2, size: Vector2, is_vertical: bool) -> StaticBody2D:
	var wall := StaticBody2D.new()
	wall.position = pos + size / 2.0
	wall.collision_layer = GameConfig.LAYER_WALL  # 墙体统一物理层 5
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
	return wall

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
func get_safe_portal_position() -> Vector2:
	## 普通传送门的落点：离玩家足够远，而且不在墙/柱子/道具里。
	## 分层兜底：
	##   ① 随机采样里"空旷且离玩家够远"的点（首选）
	##   ② 随机采样里任意空旷点
	##   ③ 网格扫描找空旷点（随机 32 次全被墙挡掉时用）
	##   ④ 网格扫描找"不在障碍里"的点（房间几乎被塞满时用）
	##   ⑤ 房间中心（最后兜底）
	## 注意：旧版把"最远的采样点"在过滤空旷与否**之前**记下来当兜底，
	## 结果兜底值可能就在墙里——房间被塞满时门直接卡进墙里打不开。
	var bounds := get_room_bounds()
	var margin := 64.0
	var player_pos := _get_player_global_position()
	var far_clear := Vector2.ZERO
	var far_clear_dist := -1.0
	var any_clear := Vector2.ZERO
	var any_clear_dist := -1.0
	for i in 32:
		var local_pos := Vector2(
			randf_range(bounds.position.x + margin, bounds.end.x - margin),
			randf_range(bounds.position.y + margin, bounds.end.y - margin))
		var world_pos := to_global(local_pos)
		if not is_position_clear(world_pos):
			continue
		var dist := world_pos.distance_to(player_pos)
		if dist > any_clear_dist:
			any_clear_dist = dist
			any_clear = world_pos
		if dist >= PORTAL_MIN_PLAYER_DISTANCE and dist > far_clear_dist:
			far_clear_dist = dist
			far_clear = world_pos
	if far_clear_dist >= 0.0:
		return far_clear
	if any_clear_dist >= 0.0:
		return any_clear
	var grid_clear := _scan_portal_grid(bounds, player_pos, PORTAL_CLEAR_RADIUS)
	if grid_clear != Vector2.INF:
		return grid_clear
	var grid_any := _scan_portal_grid(bounds, player_pos, PORTAL_MIN_CLEAR_RADIUS)
	if grid_any != Vector2.INF:
		return grid_any
	return to_global(get_center())

func _scan_portal_grid(bounds: Rect2, player_pos: Vector2, clearance: float) -> Vector2:
	## 网格扫描：在房间里找离玩家最远、四周还留得出 clearance 间隙的点。
	## 随机采样只有 32 次，碰上"房间几乎被墙填满"时会全军覆没，
	## 这时退到网格扫描，保证能给出一个不卡进墙里的落点。
	## 返回 Vector2.INF 表示这一层没找到。
	var area := bounds.grow(-PORTAL_GRID_INSET)
	var best := Vector2.ZERO
	var best_dist := -1.0
	var found := false
	var x := area.position.x
	while x <= area.end.x:
		var y := area.position.y
		while y <= area.end.y:
			var world_pos := to_global(Vector2(x, y))
			var dist := world_pos.distance_to(player_pos)
			if dist > best_dist and is_position_clear_at(world_pos, clearance):
				best_dist = dist
				best = world_pos
				found = true
			y += PORTAL_GRID_STEP
		x += PORTAL_GRID_STEP
	return best if found else Vector2.INF

func is_position_clear(world_pos: Vector2) -> bool:
	## 这个点四周有没有墙/柱子/道具（只查物理层 5）。
	## 用**圆**查询而不是点查询：传送门门体半径 24px，
	## 落点"刚好不在墙里"也意味着门会有一半卡在墙面上。
	return is_position_clear_at(world_pos, PORTAL_CLEAR_RADIUS)

func is_position_clear_at(world_pos: Vector2, radius: float) -> bool:
	## 以 world_pos 为圆心、半径 radius 的范围内有没有墙/柱子/道具。
	if not is_inside_tree():
		return true
	var space := get_world_2d().direct_space_state
	if space == null:
		return true
	var params := PhysicsShapeQueryParameters2D.new()
	var circle := CircleShape2D.new()
	circle.radius = maxf(radius, 0.5)
	params.shape = circle
	params.transform = Transform2D(0.0, world_pos)
	params.collision_mask = GameConfig.LAYER_WALL
	params.collide_with_areas = false
	params.collide_with_bodies = true
	return space.intersect_shape(params, 1).is_empty()

func _get_player_global_position() -> Vector2:
	var players := get_tree().get_nodes_in_group("player")
	for p in players:
		if p is Node2D:
			return (p as Node2D).global_position
	return to_global(get_center())

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
	portal.global_position = get_safe_portal_position()
	# 传送门是"地面上的门"：压在角色之上会把走进去的人整个盖住。
	portal.z_index = ReadabilityLib.Z_GROUND

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

func spawn_choice_portals(choices: Array) -> void:
	## 清完一间之后的岔路。左门是原计划，右门是事件房。
	if portal_spawned:
		return
	if choices.size() < 2:
		spawn_portal()
		return
	portal_spawned = true
	is_cleared = true
	room_cleared.emit()
	var offsets: Array = [Vector2(-180, 48), Vector2(180, 48)]
	var portals: Array = []
	for i in range(2):
		portals.append(_build_choice_portal(get_center() + offsets[i], choices[i]))
	await get_tree().create_timer(0.5).timeout
	for portal in portals:
		if not is_instance_valid(portal):
			return
		portal.monitoring = true
	print("🌀 两条路已打开")

func _build_choice_portal(pos: Vector2, info: Dictionary) -> Area2D:
	var room_type := String(info.get("type", "combat"))
	var portal := Area2D.new()
	portal.name = "Portal_%s" % room_type
	portal.collision_layer = 0
	portal.collision_mask = 1
	portal.global_position = pos
	portal.z_index = ReadabilityLib.Z_GROUND
	portal.modulate = info.get("color", Color(0.7, 0.5, 1.0))

	var portal_shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 24.0
	portal_shape.shape = circle
	portal.add_child(portal_shape)

	var portal_texture := TextureManager.instance.get_effect_texture("portal")
	if portal_texture:
		var portal_visual := Sprite2D.new()
		portal_visual.texture = portal_texture
		portal_visual.scale = Vector2(0.6, 0.6)
		portal.add_child(portal_visual)
	else:
		var portal_visual := ColorRect.new()
		portal_visual.color = Color(0.5, 0.0, 1.0, 0.8)
		portal_visual.size = Vector2(48, 48)
		portal_visual.position = Vector2(-24, -24)
		portal.add_child(portal_visual)

	var label := Node2D.new()
	label.set_script(DoorLabelScript)
	label.text = String(info.get("title", room_type))
	label.color = info.get("color", Color.WHITE)
	portal.add_child(label)

	portal.monitoring = false
	portal.body_entered.connect(func(body: Node2D) -> void:
		_emit_choice(body, room_type)
	)
	add_child(portal)

	var tween := create_tween().set_loops()
	tween.tween_property(portal, "modulate:a", 0.45, 0.8)
	tween.tween_property(portal, "modulate:a", 1.0, 0.8)
	return portal

func _emit_choice(body: Node2D, room_type: String) -> void:
	if _choice_taken:
		return
	if body.is_in_group("player"):
		_choice_taken = true
		portal_chosen.emit(room_type)

func _on_portal_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		portal_entered.emit()

# === 摆位工具 ===
func _rect_of(center_offset: Vector2, size: Vector2, origin: Vector2) -> Rect2:
	## 摆件碰撞体的实际占地矩形（碰撞形状可能不居中，比如道具底座偏下）
	return Rect2(origin + center_offset - size * 0.5, size)

func is_placement_free(rect: Rect2) -> bool:
	## 一个占地矩形能不能放：不出房间边、不压玩家出生点、不压已占的矩形
	var bounds := get_room_bounds().grow(-PLACEMENT_EDGE_INSET)
	if not bounds.encloses(rect):
		return false
	var padded := rect.grow(PLACEMENT_PADDING)
	if padded.grow(PLAYER_SPAWN_CLEAR).has_point(get_center()):
		return false
	for used in _occupied_rects:
		if padded.intersects(used):
			return false
	return true

func _reserve_rect(rect: Rect2) -> void:
	_occupied_rects.append(rect)

func find_free_position(size: Vector2, center_offset: Vector2 = Vector2.ZERO) -> Vector2:
	## 给一个占地 size 的摆件找落点：先随机采样，全被占用就网格扫描。
	## 返回 Vector2.INF 表示这个房间已经放不下——调用方应当少放一个，
	## 而不是硬塞（硬塞就是柱子长在柱子里的观感来源）。
	var bounds := get_room_bounds().grow(-PLACEMENT_EDGE_INSET)
	var half := size * 0.5
	var min_x: float = bounds.position.x - center_offset.x + half.x
	var max_x: float = bounds.end.x - center_offset.x - half.x
	var min_y: float = bounds.position.y - center_offset.y + half.y
	var max_y: float = bounds.end.y - center_offset.y - half.y
	if min_x > max_x or min_y > max_y:
		return Vector2.INF

	for i in 48:
		var candidate := Vector2(randf_range(min_x, max_x), randf_range(min_y, max_y))
		if is_placement_free(_rect_of(center_offset, size, candidate)):
			return candidate

	# 网格扫描：随机 48 次都没落下时兜底（房间被塞满，或余量只剩窄条）
	var step := 24.0
	var y := min_y
	while y <= max_y:
		var x := min_x
		while x <= max_x:
			var candidate := Vector2(x, y)
			if is_placement_free(_rect_of(center_offset, size, candidate)):
				return candidate
			x += step
		y += step
	return Vector2.INF

# === 障碍物生成 ===
func add_pillars(count: int = 4) -> void:
	## 添加柱子障碍物。放不下的就少放——不重叠比凑数量重要。
	for i in range(count):
		var size := Vector2(32, 32)
		var pos := find_free_position(size)
		if pos == Vector2.INF:
			return
		_create_pillar(pos)

func _create_pillar(pos: Vector2) -> void:
	var pillar := StaticBody2D.new()
	pillar.name = "Pillar%d" % _occupied_rects.size()
	pillar.position = pos
	pillar.collision_layer = GameConfig.LAYER_WALL
	pillar.collision_mask = 0
	pillar.add_to_group("walls")
	pillar.add_to_group("mirrorable")
	_reserve_rect(_rect_of(Vector2.ZERO, Vector2(32, 32), pos))
	pillar_count += 1

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(32, 32)
	shape.shape = rect
	pillar.add_child(shape)

	var texture: Texture2D = _get_tile_texture("pillar")
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
		var footprint := _prop_footprint(prop_name)
		if footprint.is_empty():
			continue
		var size: Vector2 = footprint["size"]
		var offset: Vector2 = footprint["offset"]
		var pos := find_free_position(size, offset)
		if pos == Vector2.INF:
			return
		_create_prop(prop_name, pos)

func _prop_footprint(prop_name: String) -> Dictionary:
	## 道具的碰撞占地：贴图的 70% 宽 × 50% 高，底座中心比精灵中心低 15%。
	## 摆位、绘制、碰撞三处共用这一份换算，改一处不会漏另一处。
	var texture: Texture2D = _get_prop_texture(prop_name)
	if texture == null:
		return {}
	var tex_size: Vector2 = texture.get_size()
	return {
		"size": Vector2(tex_size.x * 0.7, tex_size.y * 0.5),
		"offset": Vector2(0, tex_size.y * 0.15),
	}

func _create_prop(prop_name: String, pos: Vector2) -> void:
	var texture: Texture2D = _get_prop_texture(prop_name)
	if texture == null:
		return

	var tex_size: Vector2 = texture.get_size()
	var collision_size := Vector2(tex_size.x * 0.7, tex_size.y * 0.5)

	var prop := StaticBody2D.new()
	prop.name = "Prop_%s" % prop_name
	prop.position = pos
	prop.collision_layer = GameConfig.LAYER_WALL
	prop.collision_mask = 0
	prop.add_to_group("walls")
	prop.add_to_group("mirrorable")
	_reserve_rect(_rect_of(Vector2(0, tex_size.y * 0.15), collision_size, pos))
	prop_count += 1

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
		var texture: Texture2D = _get_prop_texture(dec_name)
		if texture == null:
			continue
		var size := Vector2(texture.get_width(), texture.get_height())
		var pos := find_free_position(size)
		if pos == Vector2.INF:
			return
		_create_decoration(dec_name, pos)

func _create_decoration(dec_name: String, pos: Vector2) -> void:
	var texture: Texture2D = _get_prop_texture(dec_name)
	if texture == null:
		return

	var deco := Sprite2D.new()
	deco.name = "Deco_%s" % dec_name
	deco.texture = texture
	deco.position = pos
	deco.z_index = -8 if dec_name == "blood_splatter" else -1
	deco.add_to_group("mirrorable")
	_reserve_rect(_rect_of(Vector2.ZERO, texture.get_size(), pos))
	decoration_count += 1
	add_child(deco)

func _get_tile_texture(tile_name: String) -> Texture2D:
	var tm := _texture_manager()
	if tm == null:
		return null
	return tm.get_tile_texture(room_theme, tile_name)

func _get_prop_texture(prop_name: String) -> Texture2D:
	var tm := _texture_manager()
	if tm == null:
		return null
	return tm.get_prop_texture(prop_name)

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

func setup_mutation_room() -> void:
	## 变异房：中央一座祭坛，没有战斗。赌博发生在弹窗里。
	room_theme = "dungeon"
	_add_prop_at("altar", get_center())
	add_decorations(3)

func apply_mirror() -> void:
	## 只翻带 mirrorable 标记的障碍和装饰。边界墙也在 "walls" 组里，
	## 跟着翻会把左墙搬到右边，房间就漏了。
	var center_x := room_width * 0.5
	for child in get_children():
		if child.is_in_group("mirrorable") and child is Node2D:
			var node := child as Node2D
			node.position.x = GameConfig.mirror_x(node.position.x, center_x)

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
	var tm := _texture_manager()
	if tm == null:
		return
	var texture: Texture2D = tm.get_ui_texture("merchant")
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
	glow.texture = tm.get_effect_texture("portal")
	if glow.texture:
		glow.modulate = Color(1.0, 0.9, 0.4, 0.3)
		glow.scale = Vector2(0.8, 0.4)
		merchant.add_child(glow)
