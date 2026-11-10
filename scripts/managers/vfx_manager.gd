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
	spawn_texture_fx("xp_collect", pos,
		{"scale_from": 0.25, "scale_to": 0.75, "duration": 0.3, "z": 90})
	for i in count:
		_create_particle(pos, Color(0.4, 1.0, 0.5, 0.8), randf_range(2, 4), randf_range(40, 100), randf_range(0.2, 0.3))

func spawn_levelup_particles(pos: Vector2, count: int = 20) -> void:
	## 升级光效：先是脚下的金色法阵环，再是向外飞的粒子
	spawn_texture_fx("levelup_aura", pos,
		{"scale_from": 0.55, "scale_to": 2.5, "duration": 0.8,
		 "fade_delay": 0.25, "z": 90})
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
	spawn_texture_fx("boss_warning", pos,
		{"scale_from": 0.5, "scale_to": 1.3, "duration": 0.9, "fade_delay": 0.3})
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
	# 地面层：压在地板之上、角色之下。这里原来写的是 2，比玩家(1)还高，
	# 预警圈会盖在角色身上——注释说的和实际做的不是一回事。
	root.z_index = ReadabilityVisuals.Z_GROUND

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
	## 闪避效果：残影 + 一点拖尾碎屑
	spawn_texture_fx("dodge_afterimage", pos,
		{"scale_from": 2.2, "scale_to": 2.6, "duration": 0.28, "additive": false,
		 "color": Color(0.8, 0.8, 0.95, 0.55)})
	var p := _create_particle_node(pos, Color(0.3, 0.3, 0.3, 0.8), 8.0)
	var tween := p.create_tween()
	tween.tween_property(p, "modulate:a", 0.0, 0.3)
	tween.parallel().tween_property(p, "scale", Vector2(2, 2), 0.3)
	tween.tween_callback(p.queue_free)

func spawn_freeze_effect(pos: Vector2) -> void:
	## 冰冻效果：先盖一层冰壳，再炸出碎冰粒子
	spawn_texture_fx("freeze_effect", pos,
		{"scale_from": 0.7, "scale_to": 1.1, "duration": 0.45,
		 "color": Color(0.9, 1.0, 1.15, 0.95)})
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

# ========== 贴图特效（2026-11-09 美术接线） ==========
#
# 这一批是 assets/effects 下的正式美术（第二轮重做）。贴图是单帧，
# 所以动效统一用「放大 + 消隐」的 tween 表达——不另做序列帧的理由：
#   · 这些效果在游戏里都只有 0.3~0.9 秒，单帧扩散已经能读出来；
#   · 序列帧要多出 8~10 倍文件，还得逐个对像素，收益不成比例；
#   · tween 的时长/缩放可以按等级、武器档次随时调，比固定帧数灵活。
#
# 加色混合（BLEND_MODE_ADD）是刻意的：画面上这些光斑要"发光"而不是
# "贴一张图"，普通混合会被背景压暗、看着像贴纸。

## 通用贴图特效。opts 支持：
##   scale_from / scale_to（倍数，默认 0.35 → 1.0）
##   duration（默认 0.35）、fade_delay（先放大后消隐）
##   rotation、color（modulate）、additive（默认 true）、z（默认 100）
func spawn_texture_fx(tex_name: String, pos: Vector2, opts: Dictionary = {}) -> Sprite2D:
	if TextureManager.instance == null:
		return null
	var tex: Texture2D = TextureManager.instance.get_effect_texture(tex_name)
	if tex == null:
		return null
	var scene := _ensure_current_scene()
	if scene == null:
		return null

	var sprite := Sprite2D.new()
	sprite.name = "Fx_" + tex_name
	sprite.texture = tex
	sprite.global_position = pos
	sprite.z_index = int(opts.get("z", 100))
	sprite.rotation = float(opts.get("rotation", 0.0))
	sprite.modulate = opts.get("color", Color.WHITE)
	var from_s := float(opts.get("scale_from", 0.35))
	var to_s := float(opts.get("scale_to", 1.0))
	sprite.scale = Vector2.ONE * from_s
	if bool(opts.get("additive", true)):
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		sprite.material = mat

	var dur := float(opts.get("duration", 0.35))
	var fade_delay := float(opts.get("fade_delay", 0.0))
	scene.add_child(sprite)
	var tw := sprite.create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.set_parallel(true)
	tw.tween_property(sprite, "scale", Vector2.ONE * to_s, dur) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(sprite, "modulate:a", 0.0, dur).set_delay(fade_delay)
	tw.chain().tween_callback(sprite.queue_free)
	return sprite

func spawn_shield_break(pos: Vector2) -> void:
	## 护盾碎：一圈青蓝的碎环，比普通受击粒子更"重"，配合屏幕轻震
	spawn_texture_fx("shield_break", pos,
		{"scale_from": 0.5, "scale_to": 1.5, "duration": 0.4,
		 "color": Color(1.2, 1.45, 1.6, 1.0)})

func spawn_holy_pillar(pos: Vector2) -> void:
	## 圣光柱：竖直光柱，从下往上长一点，落在命中点
	spawn_texture_fx("holy_light", pos,
		{"scale_from": 0.55, "scale_to": 1.15, "duration": 0.45, "color": Color(1.0, 1.0, 0.95, 0.95)})

func spawn_poison_burst(pos: Vector2) -> void:
	## 毒云落点的扩散：绿色雾团铺开，比粒子更"有面积"
	spawn_texture_fx("poison_spread", pos,
		{"scale_from": 0.4, "scale_to": 1.35, "duration": 0.55,
		 "color": Color(0.85, 1.0, 0.75, 0.9)})

func spawn_chain_arc(pos: Vector2) -> void:
	## 连锁闪电每跳一下的落点电光
	spawn_texture_fx("chain_lightning", pos,
		{"scale_from": 0.2, "scale_to": 0.45, "duration": 0.22,
		 "color": Color(1.1, 1.1, 0.85, 1.0)})

func spawn_thunder_strike(pos: Vector2) -> void:
	## 雷神之怒：一道竖雷劈在落点，比 chain_arc 大一号
	spawn_texture_fx("thunder_wrath", pos,
		{"scale_from": 0.5, "scale_to": 1.25, "duration": 0.5,
		 "color": Color(1.15, 1.2, 1.35, 1.0)})

func spawn_knife_tornado(pos: Vector2) -> void:
	## 刀阵成型的旋风（进化瞬间播一次，之后靠旋转的刀刃持续表现）
	var sprite := spawn_texture_fx("knife_tornado", pos,
		{"scale_from": 0.4, "scale_to": 1.5, "duration": 0.6,
		 "color": Color(0.85, 1.05, 1.1, 0.95)})
	if sprite:
		var spin := sprite.create_tween()
		spin.tween_property(sprite, "rotation", TAU, 0.6)

func spawn_achievement_burst(pos: Vector2) -> void:
	spawn_texture_fx("achievement_unlock", pos,
		{"scale_from": 0.5, "scale_to": 1.3, "duration": 0.7})
