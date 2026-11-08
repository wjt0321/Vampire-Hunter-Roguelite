extends Node2D
## 岔路口传送门上的短标题。详细规则写在 HUD，这里只负责“这扇门是哪一间”。

var text: String = ""
var color: Color = Color.WHITE

func _ready() -> void:
	z_index = 6

func _draw() -> void:
	if text.is_empty():
		return
	var font := ThemeDB.fallback_font
	var size := 18
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string(font, Vector2(-width * 0.5, -46), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
