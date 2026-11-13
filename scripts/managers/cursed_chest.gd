extends Node2D
## 受诅宝箱（局内事件 guard 的目标物）
##
## 房间中央的上锁宝箱：守卫全清后 open() 播放开箱动画并自我了结。
## 奖励本身由 room_event_manager 结算（保持"数值"与"演出"分离，
## 这样测试可以只断言数值，不用等动画）。
##
## 2026-11-09 第五轮：原来箱体是一个 ColorRect 纯色块 + 一个中文字"锁"，
## 场上根本不像宝箱。现在用美术贴图 assets/items/cursed_chest.png。

var _opened: bool = false
var _chest: Node2D = null

func _ready() -> void:
	add_to_group("event_chests")

	_chest = Node2D.new()
	_chest.name = "ChestVisual"
	add_child(_chest)

	# 箱体：美术贴图（带锁、铁箍、木纹）。
	var tex: Texture2D = TextureManager.instance.get_item_texture("cursed_chest")
	if tex != null:
		var spr := Sprite2D.new()
		spr.texture = tex
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_chest.add_child(spr)
	else:
		# 回退：纯色块 + 金边（没有美术资源时的老样子）
		var box := ColorRect.new()
		box.color = Color(0.32, 0.2, 0.12)
		box.size = Vector2(40, 30)
		box.position = Vector2(-20, -15)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_chest.add_child(box)

		var edge := ColorRect.new()
		edge.color = Color(0.78, 0.6, 0.24)
		edge.size = Vector2(44, 4)
		edge.position = Vector2(-22, -17)
		edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_chest.add_child(edge)

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
	pulse.tween_property(_chest, "scale", Vector2(1.08, 1.08), 0.9).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(_chest, "scale", Vector2.ONE, 0.9).set_trans(Tween.TRANS_SINE)

func open() -> void:
	## 开箱演出：金色闪光、放大淡出。奖励在调用方结算。
	if _opened:
		return
	_opened = true
	AudioManager.play_sfx(AudioLib.get_sound("chest_open"))
	var vfx := get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.spawn_hit_particles(global_position, Color(1.0, 0.85, 0.3), 5)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.3, 1.3), 0.35).set_trans(Tween.TRANS_BACK)
	tw.tween_property(self, "modulate:a", 0.0, 0.4)
	tw.tween_callback(queue_free)
	print("🔓 受诅宝箱开启")
