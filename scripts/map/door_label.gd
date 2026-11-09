extends Node2D
## 岔路口传送门上的短标题。详细规则写在 HUD，这里只负责“这扇门是哪一间”。
##
## 2026-11-09 反馈"字体不明显"：原实现是 fallback_font 裸字画在门上方，
## 压在暗色墙上几乎看不见。改为 Label + 黑描边 + 半透明底板。

var text: String = ""
var color: Color = Color.WHITE

func _ready() -> void:
	z_index = 6
	if text.is_empty():
		return
	var lbl := Label.new()
	lbl.text = text
	# fallback 字体在这个尺寸没有粗体，用 17px + 6px 黑描边保证暗底可读
	lbl.add_theme_font_size_override("font_size", 17)
	lbl.add_theme_color_override("font_color", color.lightened(0.25))
	lbl.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.05, 0.95))
	lbl.add_theme_constant_override("outline_size", 6)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lbl)
	# 居中：Label 要等一帧才知道自己的 size，用 resized 信号摆位
	lbl.resized.connect(func(): lbl.position = -lbl.size * 0.5 + Vector2(0, -58))
	lbl.reset_size()
	lbl.position = -lbl.size * 0.5 + Vector2(0, -58)
