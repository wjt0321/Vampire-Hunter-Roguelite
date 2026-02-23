extends Node
## 视觉效果管理器
## 提供粒子特效和屏幕震动功能

var camera: Camera2D = null

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
	get_tree().current_scene.add_child(container)
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
	
	get_tree().current_scene.add_child(ring)
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
