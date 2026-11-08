extends CanvasLayer
## 楼层横幅
## 全屏黑幕 + 居中标题卡，用于"第 N 层 / 层已肃清 / 地下城通关"这类节点提示
## 用法：await floor_banner.show_card(kicker, title, subtitle, hint, accent, hold)

var _root: Control
var _veil: ColorRect
var _kicker: Label
var _title: Label
var _subtitle: Label
var _hint: Label
var _line: ColorRect
var _tween: Tween
var _card_serial: int = 0

const FADE_IN: float = 0.35
const FADE_OUT: float = 0.4
const VEIL_ALPHA: float = 0.62

func _ready() -> void:
	layer = 90
	_build_ui()

func _build_ui() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.modulate.a = 0.0
	add_child(_root)

	_veil = ColorRect.new()
	_veil.name = "Veil"
	_veil.color = Color(0, 0, 0, 0)
	_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_veil)

	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 10)
	center.add_child(vbox)

	_kicker = _make_label("第 1 层", 22, Color(0.85, 0.3, 0.35))
	vbox.add_child(_kicker)

	_title = _make_label("标题", 56, Color.WHITE)
	vbox.add_child(_title)

	_line = ColorRect.new()
	_line.custom_minimum_size = Vector2(260, 2)
	_line.color = Color(0.8, 0.15, 0.2, 0.9)
	_line.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(_line)

	_subtitle = _make_label("SUBTITLE", 18, Color(0.75, 0.72, 0.78))
	vbox.add_child(_subtitle)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 18)
	vbox.add_child(spacer)

	_hint = _make_label("提示文字", 18, Color(0.82, 0.78, 0.8))
	vbox.add_child(_hint)

	visible = false

func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	return label

## 显示一张提示卡并等待其播放完毕（协程）
func show_card(kicker: String, title: String, subtitle: String, hint: String, accent: Color, hold: float = 1.5) -> void:
	_card_serial += 1
	var my_id := _card_serial

	_kicker.text = kicker
	_kicker.add_theme_color_override("font_color", accent)
	_title.text = title
	_subtitle.text = subtitle
	_hint.text = hint
	_line.color = Color(accent.r, accent.g, accent.b, 0.9)

	visible = true
	_root.modulate.a = 0.0
	_veil.color = Color(0, 0, 0, 0)

	if _tween and _tween.is_valid():
		_tween.kill()

	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(_root, "modulate:a", 1.0, FADE_IN)
	_tween.tween_property(_veil, "color:a", VEIL_ALPHA, FADE_IN)
	await get_tree().create_timer(FADE_IN).timeout
	if my_id != _card_serial:
		return

	await get_tree().create_timer(hold).timeout
	if my_id != _card_serial:
		return

	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(_root, "modulate:a", 0.0, FADE_OUT)
	_tween.tween_property(_veil, "color:a", 0.0, FADE_OUT)
	await get_tree().create_timer(FADE_OUT).timeout

	if my_id == _card_serial:
		visible = false

## 立即强制隐藏（玩家中途死亡等场景）
func force_hide() -> void:
	_card_serial += 1
	if _tween and _tween.is_valid():
		_tween.kill()
	visible = false
	_root.modulate.a = 0.0
	_veil.color = Color(0, 0, 0, 0)
