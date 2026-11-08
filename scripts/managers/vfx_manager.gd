extends Node
## 视觉效果管理器
## 提供粒子特效和屏幕震动功能

var camera: Camera2D = null
var _current_scene: Node = null

func _ensure_current_scene() -> Node:
	if _current_scene == null or not is_instance_valid(_current_scene):
		_current_scene = get_tree().current_scene
	return _current_scene

# ========== 屏幕震动 ==========

func screen_shake(intensity: float = 5.0, duration: float = 0.2) -> void:
	if camera == null:
		var cam_nodes := get_tree().get_nodes_in_group("camera")
		if cam_nodes.size() > 0:
			camera = cam_nodes[0] as Camera2D
	if camera == null:
		return
	
	var tween := create_tween()
	var shake_count: int = int(duration / 0.04)
	for i in shake_count:
		var offset := Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
		tween.tween_property(camera, "offset", offset, 0.04)
	tween.tween_property(camera, "offset", Vector2.ZERO, 0.04)

# ========== 粒子特效 ==========

func spawn_hit_particles(pos: Vector2, color: Color = Color.WHITE, count: int = 6) -> void:
	## 受击粒子 —— 小碎片飞溅
	for i in count:
		_create_particle(pos, color, randf_range(2, 5), randf_range(80, 200), randf_range(0.2, 0.4))

func spawn_death_particles(pos: Vector2, color: Color = Color.RED, count: int = 12) -> void:
	## 死亡爆炸粒子
	for i in count:
		_create_particle(pos, color, randf_range(3, 8), randf_range(60, 180), randf_range(0.3, 0.6))

func spawn_xp_particles(pos: Vector2, count: int = 5) -> void:
	## 经验拾取粒子
	for i in count:
		_create_particle(pos, Color(0.4, 1.0, 0.5, 0.8), randf_range(2, 4), randf_range(40, 100), randf_range(0.2, 0.3))

func spawn_levelup_particles(pos: Vector2, count: int = 20) -> void:
	## 升级光效
	for i in count:
		var angle := TAU * float(i) / float(count)
		var dir := Vector2(cos(angle), sin(angle))
		var p := _create_particle_node(pos, Color(1.0, 0.9, 0.3, 0.9), randf_range(3, 6))
		var tween := p.create_tween()
		var target := pos + dir * randf_range(60, 120)
		tween.tween_property(p, "global_position", target, 0.5).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(p, "modulate:a", 0.0, 0.5)
		tween.parallel().tween_property(p, "scale", Vector2.ZERO, 0.5)
		tween.tween_callback(p.queue_free)

func spawn_evolution_effect(pos: Vector2, theme_color: Color = Color(1.0, 0.85, 0.3, 0.9)) -> void:
	## 武器进化大光环特效
	# 1. 中心爆发粒子
	for i in 32:
		var angle := TAU * float(i) / 32.0
		var dir := Vector2(cos(angle), sin(angle))
		var p := _create_particle_node(pos, theme_color, randf_range(4, 8))
		var tween := p.create_tween()
		var target := pos + dir * randf_range(80, 160)
		tween.tween_property(p, "global_position", target, 0.6).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(p, "modulate:a", 0.0, 0.6)
		tween.parallel().tween_property(p, "scale", Vector2.ZERO, 0.6)
		tween.tween_callback(p.queue_free)

	# 2. 扩散圆环
	for i in range(3):
		var ring := _create_ring(pos, Color(theme_color.r, theme_color.g, theme_color.b, 0.7), 15.0 + i * 12.0)
		var tween := ring.create_tween()
		tween.tween_property(ring, "scale", Vector2(6 + i * 2, 6 + i * 2), 0.8).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.8)
		tween.tween_callback(ring.queue_free)

	# 3. 中心闪光
	var flash := ColorRect.new()
	flash.color = Color(theme_color.r, theme_color.g, theme_color.b, 0.4)
	flash.size = Vector2(200, 200)
	flash.position = Vector2(-100, -100)
	flash.z_index = 99
	var flash_container := Node2D.new()
	flash_container.global_position = pos
	flash_container.add_child(flash)
	var scene := _ensure_current_scene()
	if scene:
		scene.add_child(flash_container)
	var flash_tween := flash_container.create_tween()
	flash_tween.tween_property(flash, "modulate:a", 0.0, 0.4)
	flash_tween.parallel().tween_property(flash, "scale", Vector2(3, 3), 0.4)
	flash_tween.tween_callback(flash_container.queue_free)

func spawn_bullet_trail(pos: Vector2, color: Color = Color(1.0, 0.9, 0.3, 0.5)) -> void:
	## 子弹拖尾
	var p := _create_particle_node(pos, color, 3.0)
	var tween := p.create_tween()
	tween.tween_property(p, "modulate:a", 0.0, 0.15)
	tween.parallel().tween_property(p, "scale", Vector2.ZERO, 0.15)
	tween.tween_callback(p.queue_free)

func spawn_boss_warning(pos: Vector2) -> void:
	## Boss 出现警告特效
	for i in range(3):
		var ring := _create_ring(pos, Color(1.0, 0.1, 0.1, 0.8), 10.0 + i * 20.0)
		var tween := ring.create_tween()
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.tween_property(ring, "scale", Vector2(5, 5), 0.8).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.8)
		tween.tween_callback(ring.queue_free)

# ========== 打击感：枪口闪光 / 地面预警 ==========

func spawn_muzzle_flash(pos: Vector2, direction: Vector2, color: Color = Color(1.0, 0.86, 0.35)) -> Node2D:
	## 枪口闪光：60ms 的锥形亮片，加色混合。
	## 为什么不用粒子：粒子有随机性、会飘走；枪口闪光必须"钉在枪口、朝向正确"，
	## 玩家靠它判断"这一枪真的打出去了"，飘走的特效反而削弱可读性。
	var container := Node2D.new()
	container.global_position = pos
	container.rotation = direction.angle()
	container.z_index = 101

	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([
		Vector2(0, -5.0),
		Vector2(18.0, 0.0),
		Vector2(0, 5.0),
		Vector2(5.0, 0.0),
	])
	poly.color = Color(color.r, color.g, color.b, 0.95)
	container.add_child(poly)

	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	container.material = mat

	var scene := _ensure_current_scene()
	if scene == null:
		container.queue_free()
		return null
	scene.add_child(container)

	var tween := container.create_tween()
	tween.tween_property(container, "scale", Vector2(1.7, 0.55), GameConfig.MUZZLE_FLASH_DURATION)
	tween.parallel().tween_property(poly, "modulate:a", 0.0, GameConfig.MUZZLE_FLASH_DURATION)
	tween.tween_callback(container.queue_free)
	return container

func spawn_ground_marker(pos: Vector2, radius: float, color: Color = Color(1.0, 0.15, 0.15), duration: float = -1.0) -> Node2D:
	## 地面预警：在落点画一个逐渐填满的圆环。
	## 参考 Halls of Torment —— 玩家需要知道"打到哪里"，而不是只能看到 Boss 自己在闪。
	var dur: float = duration if duration > 0.0 else GameConfig.GROUND_MARKER_DURATION

	var root := Node2D.new()
	root.global_position = pos
	root.z_index = 2  # 地面层：压在地板之上、角色之下

	var fill := Polygon2D.new()
	fill.polygon = _circle_points(radius, 28)
	fill.color = Color(color.r, color.g, color.b, 0.16)
	root.add_child(fill)

	var outline := Line2D.new()
	var pts := _circle_points(radius, 32)
	pts.append(pts[0])
	outline.points = pts
	outline.width = 3.0
	outline.default_color = Color(color.r, color.g, color.b, 0.9)
	root.add_child(outline)

	var scene := _ensure_current_scene()
	if scene == null:
		root.queue_free()
		return null
	scene.add_child(root)

	# 从 35% 缩放长到 100%：玩家看到"圈在长大"，自然知道该躲开哪里
	root.scale = Vector2(0.35, 0.35)
	var tween := root.create_tween()
	tween.tween_property(root, "scale", Vector2.ONE, dur).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.parallel().tween_method(
		func(v: float): outline.width = v, 3.0, 6.0, dur
	)
	# 落点瞬间：闪一下再消失
	tween.tween_property(fill, "color", Color(color.r, color.g, color.b, 0.55), 0.08)
	tween.parallel().tween_property(outline, "default_color", Color(1, 1, 1, 1), 0.08)
	tween.tween_property(root, "modulate:a", 0.0, 0.16)
	tween.tween_callback(root.queue_free)
	return root

func _circle_points(radius: float, segments: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(segments):
		var a := TAU * float(i) / float(segments)
		pts.append(Vector2(cos(a), sin(a)) * radius)
	return pts

# ========== 内部工具 ==========

func _create_particle(pos: Vector2, color: Color, size: float, speed: float, lifetime: float) -> void:
	var p := _create_particle_node(pos, color, size)
	var angle := randf() * TAU
	var dir := Vector2(cos(angle), sin(angle))
	var target := pos + dir * speed * lifetime
	
	var tween := p.create_tween()
	tween.tween_property(p, "global_position", target, lifetime).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(p, "modulate:a", 0.0, lifetime)
	tween.parallel().tween_property(p, "scale", Vector2.ZERO, lifetime)
	tween.tween_callback(p.queue_free)

func _create_particle_node(pos: Vector2, color: Color, size: float) -> Node2D:
	var p := ColorRect.new()
	p.color = color
	p.size = Vector2(size, size)
	p.position = Vector2(-size / 2, -size / 2)
	p.z_index = 100

	var container := Node2D.new()
	container.global_position = pos
	container.add_child(p)
	var scene := _ensure_current_scene()
	if scene:
		scene.add_child(container)
	return container

func _create_ring(pos: Vector2, color: Color, radius: float) -> Node2D:
	var ring := Node2D.new()
	ring.global_position = pos
	ring.z_index = 100

	# 用多个小矩形模拟环形
	var segments := 16
	for i in segments:
		var angle := TAU * float(i) / float(segments)
		var dot := ColorRect.new()
		dot.color = color
		dot.size = Vector2(4, 4)
		dot.position = Vector2(cos(angle) * radius - 2, sin(angle) * radius - 2)
		ring.add_child(dot)

	var scene := _ensure_current_scene()
	if scene:
		scene.add_child(ring)
	return ring

# ========== 新被动道具效果 ==========

func spawn_dodge_effect(pos: Vector2) -> void:
	## 闪避效果
	var p := _create_particle_node(pos, Color(0.3, 0.3, 0.3, 0.8), 8.0)
	var tween := p.create_tween()
	tween.tween_property(p, "modulate:a", 0.0, 0.3)
	tween.parallel().tween_property(p, "scale", Vector2(2, 2), 0.3)
	tween.tween_callback(p.queue_free)

func spawn_freeze_effect(pos: Vector2) -> void:
	## 冰冻效果
	for i in 8:
		var angle := TAU * float(i) / 8.0
		var p := _create_particle_node(pos, Color(0.5, 0.8, 1.0, 0.8), 6.0)
		var dir := Vector2(cos(angle), sin(angle))
		var target := pos + dir * 30.0
		
		var tween := p.create_tween()
		tween.tween_property(p, "global_position", target, 0.3).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(p, "modulate:a", 0.0, 0.3)
		tween.tween_callback(p.queue_free)

func spawn_freeze_particles(pos: Vector2) -> void:
	## 冻结粒子
	for i in 6:
		var p := _create_particle_node(pos, Color(0.6, 0.9, 1.0, 0.9), randf_range(2, 4))
		var tween := p.create_tween()
		tween.tween_property(p, "modulate:a", 0.0, 1.0)
		tween.parallel().tween_property(p, "position:y", p.position.y - 20, 1.0)
		tween.tween_callback(p.queue_free)
