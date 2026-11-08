extends Node2D
## 受诅宝箱（局内事件 guard 的目标物）
##
## 房间中央的上锁宝箱：守卫全清后 open() 播放开箱动画并自我了结。
## 奖励本身由 room_event_manager 结算（保持"数值"与"演出"分离，
## 这样测试可以只断言数值，不用等动画）。

var _opened: bool = false
var _box: ColorRect = null
var _lock_label: Label = null

func _ready() -> void:
	add_to_group("event_chests")

	# 箱体：暗色矩形 + 描边。不用 Sprite——项目还没有美术资源，
	# ColorRect 的"平涂 + 边框"和墙/地砖是同一套视觉语言
	_box = ColorRect.new()
	_box.color = Color(0.32, 0.2, 0.12)
	_box.size = Vector2(40, 30)
	_box.position = Vector2(-20, -15)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_box)

	var edge := ColorRect.new()
	edge.color = Color(0.78, 0.6, 0.24)
	edge.size = Vector2(44, 4)
	edge.position = Vector2(-22, -17)
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(edge)

	# 锁：中文字"锁"（D.4：界面不用 emoji）
	_lock_label = Label.new()
	_lock_label.text = "锁"
	_lock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lock_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_lock_label.size = Vector2(40, 30)
	_lock_label.position = Vector2(-20, -15)
	_lock_label.add_theme_font_size_override("font_size", 15)
	_lock_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	_lock_label.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.04, 0.95))
	_lock_label.add_theme_constant_override("outline_size", 4)
	_lock_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_lock_label)

	var name_label := Label.new()
	name_label.text = "受 诅 宝 箱"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.size = Vector2(80, 14)
	name_label.position = Vector2(-40, 18)
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.add_theme_color_override("font_color", Color(0.95, 0.72, 0.3))
	name_label.add_theme_color_override("font_outline_color", Color(0.04, 0.02, 0.03, 0.9))
	name_label.add_theme_constant_override("outline_size", 3)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(name_label)

	# 呼吸：静止物必须有轻微脉动才不会被当成背景贴图（同 powerup）
	var pulse := create_tween()
	pulse.set_loops()
	pulse.tween_property(_box, "scale", Vector2(1.08, 1.08), 0.9).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(_box, "scale", Vector2.ONE, 0.9).set_trans(Tween.TRANS_SINE)

func open() -> void:
	## 开箱演出：锁字换成"开"、金色闪光、放大淡出。奖励在调用方结算。
	if _opened:
		return
	_opened = true
	if _lock_label:
		_lock_label.text = "开"
		_lock_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6))
	var vfx := get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.spawn_hit_particles(global_position, Color(1.0, 0.85, 0.3), 5)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.3, 1.3), 0.35).set_trans(Tween.TRANS_BACK)
	tw.tween_property(self, "modulate:a", 0.0, 0.4)
	tw.tween_callback(queue_free)
	print("🔓 受诅宝箱开启")
