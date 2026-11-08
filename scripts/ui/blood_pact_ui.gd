extends CanvasLayer
class_name BloodPactUI
## 深渊契约（休息房）
##
## 设计意图：休息房原来是"进房回 50% 血然后开门"，是一个纯正向、零决策的房间。
## 一局里有 1-2 间这样的房，等于白送两次治疗，节奏上是个空洞。
## 现在改成二选一：**安息**（拿血，稳妥）或 **契约**（卖本层血量换本层收益）。
##
## 为什么惩罚挂在"本层"而不是"整局"：
## 整局 -20% 最大生命是纯粹的数值惩罚，三间休息房能叠到 -48%，
## 直接把一局玩死；而"本层"惩罚在层结束就归还，玩家每层重新做一次决策，
## 赌的是"这层我能不能靠 +30% 掉落把收益赚回来"。
##
## UI 全部代码构建，不依赖 .tscn（和 room_shop 一致）。

signal pact_chosen(kind: String)  ## kind: "rest" / "pact"

var player: Node = null
var floor_index: int = 1

var _built: bool = false
var _root: Control = null
var _pact_btn: Button = null
var _rest_btn: Button = null
var _hint: Label = null

func _ready() -> void:
	layer = 96
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

# ---------------------------------------------------------------- 生命周期

func open(player_node: Node, floor_idx: int) -> void:
	player = player_node
	floor_index = floor_idx
	if not _built:
		_build_ui()
	_refresh()
	visible = true
	# 和商店/升级一致：暂停世界，玩家可以慢慢看代价
	get_tree().paused = true

func close() -> void:
	visible = false
	if get_tree().paused:
		get_tree().paused = false

## 契约是否可选：扣 20% 上限后必须仍活着。
## 不设这道闸门的话，残血玩家点契约 = 当场自杀（而且是他自己选的，会很气）。
func can_pact() -> bool:
	if player == null or not is_instance_valid(player):
		return false
	var new_max: float = float(player.max_hp) * (1.0 - GameConfig.BLOOD_PACT_HP_RATIO)
	return new_max >= 1.0 and float(player.current_hp) > new_max * GameConfig.BLOOD_PACT_MIN_HP_RATIO

func _choose(kind: String) -> void:
	close()
	pact_chosen.emit(kind)

# ---------------------------------------------------------------- 构建

func _build_ui() -> void:
	_built = true

	_root = Control.new()
	_root.name = "PactRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	# 压暗背景：休息房本身很亮，不压暗的话祭坛读不出来
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.03, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	_root.add_child(center)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.04, 0.06, 0.97)
	style.border_color = Color(0.62, 0.16, 0.20, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "血 之 祭 坛"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.72))
	vbox.add_child(title)

	var sub := Label.new()
	sub.text = "第 %d 层 · 石台上还留着上一个人的血" % floor_index
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 13)
	sub.add_theme_color_override("font_color", Color(0.7, 0.66, 0.7))
	vbox.add_child(sub)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 22)
	vbox.add_child(row)

	_rest_btn = _make_card(
		"安　息",
		"恢复 %d%% 最大生命" % roundi(GameConfig.BLOOD_PACT_REST_HEAL_RATIO * 100.0),
		"稳妥，但这间房就白跑了",
		Color(0.62, 0.85, 1.0)
	)
	_rest_btn.pressed.connect(func(): _choose("rest"))
	row.add_child(_rest_btn)

	_pact_btn = _make_card(
		"缔 结 契 约",
		"本层最大生命 -%d%%" % roundi(GameConfig.BLOOD_PACT_HP_RATIO * 100.0),
		"本层：敌人 +%d%% 数量 · 银币与经验 +%d%%" % [
			roundi((GameConfig.BLOOD_PACT_COUNT_MULT - 1.0) * 100.0),
			roundi((GameConfig.BLOOD_PACT_LOOT_MULT - 1.0) * 100.0),
		],
		Color(1.0, 0.42, 0.42)
	)
	_pact_btn.pressed.connect(func(): _choose("pact"))
	row.add_child(_pact_btn)

	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 6)
	vbox.add_child(spacer2)

	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 12)
	_hint.add_theme_color_override("font_color", Color(0.62, 0.6, 0.64))
	vbox.add_child(_hint)

func _make_card(title: String, main_text: String, sub_text: String, accent: Color) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(248, 168)
	btn.focus_mode = Control.FOCUS_NONE

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.10, 0.08, 0.11, 1.0)
	normal.border_color = Color(accent.r, accent.g, accent.b, 0.5)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(8)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.17, 0.12, 0.16, 1.0)
	hover.border_color = accent

	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.07, 0.07, 0.08, 1.0)
	disabled.border_color = Color(0.24, 0.22, 0.24, 1.0)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_stylebox_override("disabled", disabled)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 8)
	btn.add_child(vbox)

	var l1 := Label.new()
	l1.text = title
	l1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l1.add_theme_font_size_override("font_size", 20)
	l1.add_theme_color_override("font_color", accent)
	vbox.add_child(l1)

	var l2 := Label.new()
	l2.text = main_text
	l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l2.add_theme_font_size_override("font_size", 15)
	l2.add_theme_color_override("font_color", Color(0.96, 0.94, 0.9))
	vbox.add_child(l2)

	var l3 := Label.new()
	l3.text = sub_text
	l3.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l3.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l3.custom_minimum_size = Vector2(216, 0)
	l3.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l3.add_theme_font_size_override("font_size", 12)
	l3.add_theme_color_override("font_color", Color(0.72, 0.7, 0.74))
	vbox.add_child(l3)

	return btn

func _refresh() -> void:
	if _pact_btn == null:
		return
	var pact_ok: bool = can_pact()
	_pact_btn.disabled = not pact_ok
	if pact_ok:
		_hint.text = "1 安息　　2 缔结契约　　（契约在本层结束时归还）"
		_hint.add_theme_color_override("font_color", Color(0.62, 0.6, 0.64))
	else:
		_hint.text = "生命太低，祭坛拒绝与你缔约"
		_hint.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))

# ---------------------------------------------------------------- 输入

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1, KEY_KP_1:
				get_viewport().set_input_as_handled()
				if _rest_btn:
					_rest_btn.pressed.emit()
			KEY_2, KEY_KP_2:
				get_viewport().set_input_as_handled()
				if can_pact():
					_pact_btn.pressed.emit()
