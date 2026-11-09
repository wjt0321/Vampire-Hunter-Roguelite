extends Node
## 临时验收工具：验证按钮悬停放大 + 点击涟漪（不靠鼠标，直接发信号）。
##
## 为什么要单独做：悬停动效只有鼠标真的移上去才播，截图/录像抓不到；
## 这里手动 emit mouse_entered，让 tween 走一遍，再用 --write-movie 取帧。

func _ready() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.07, 0.09, 1.0)
	bg.size = Vector2(1280, 720)
	layer.add_child(bg)

	var hint := Label.new()
	hint.text = "上：普通状态   中：悬停中（放大 1.05）   下：点击涟漪"
	hint.position = Vector2(60, 40)
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color(0.8, 0.75, 0.65))
	layer.add_child(hint)

	var normal_btn := _make(layer, "普通状态", Vector2(60, 120))
	var hovered_btn := _make(layer, "悬停中", Vector2(60, 260))
	var ripple_btn := _make(layer, "点击涟漪", Vector2(60, 400))

	await get_tree().process_frame
	await get_tree().process_frame
	hovered_btn.mouse_entered.emit()
	await get_tree().create_timer(0.25).timeout
	UiFx.click_ripple(ripple_btn)
	print("ui_fx shot: normal=%s hovered=%s" % [normal_btn.scale, hovered_btn.scale])

func _make(parent: Node, text: String, pos: Vector2) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.position = pos
	btn.custom_minimum_size = Vector2(320, 64)
	btn.size = Vector2(320, 64)
	btn.add_theme_font_size_override("font_size", 18)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.15, 0.12, 0.16, 1.0)
	normal.border_color = Color(0.62, 0.5, 0.28, 0.9)
	normal.set_border_width_all(2)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.24, 0.18, 0.14, 1.0)
	hover.border_color = Color(0.95, 0.8, 0.42, 1.0)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	parent.add_child(btn)
	UiFx.hover(btn)
	return btn
