extends CanvasLayer

const DailyChallengeScript = preload("res://scripts/core/daily_challenge.gd")
## 每日挑战入口（17.15）
## 进局之前把今天的两条规则和本地排名摊开。规则进了局再解释，玩家已经没法退出。

signal start_requested
signal closed

var _built: bool = false
var _rules: Label = null
var _board: Label = null

func _ready() -> void:
	layer = 40
	visible = false

func open_today(save_mgr: Node) -> void:
	if not _built:
		_build()
	var spec: Dictionary = DailyChallengeScript.build(DailyChallengeScript.today())
	var lines: PackedStringArray = PackedStringArray()
	lines.append(String(spec.get("date", "")))
	for entry in spec.get("modifiers", []):
		lines.append("%s　%s" % [String(entry.get("name", "")), String(entry.get("desc", ""))])
	_rules.text = "\n".join(lines)
	_board.text = _format_board(save_mgr, String(spec.get("date", "")))
	visible = true

func _format_board(save_mgr: Node, date_key: String) -> String:
	if save_mgr == null or not save_mgr.has_method("get_daily_runs"):
		return "本地还没有今日记录"
	var runs: Array = save_mgr.get_daily_runs(date_key)
	if runs.is_empty():
		return "今天还没有记录。\n打完一局记一次：先比波次，再比击杀，最后比用时。"
	var lines: PackedStringArray = PackedStringArray()
	var shown := mini(runs.size(), 5)
	for i in shown:
		var row: Dictionary = runs[i]
		var secs := int(row.get("time", 0))
		lines.append("%d.  波次 %d   击杀 %d   %d:%02d" % [
			i + 1, int(row.get("wave", 0)), int(row.get("kills", 0)), secs / 60, secs % 60])
	return "\n".join(lines)

func _build() -> void:
	_built = true
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.03, 0.78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.04, 0.08, 0.98)
	style.border_color = Color(0.72, 0.55, 0.28, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "每 日 挑 战"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.55))
	vbox.add_child(title)

	var sub := Label.new()
	sub.text = "今天的地图和词缀是固定的。记录只存在这台机器上。"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 13)
	sub.add_theme_color_override("font_color", Color(0.75, 0.7, 0.62))
	vbox.add_child(sub)

	_rules = Label.new()
	_rules.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rules.add_theme_font_size_override("font_size", 16)
	_rules.add_theme_color_override("font_color", Color(0.95, 0.9, 0.82))
	vbox.add_child(_rules)

	var board_title := Label.new()
	board_title.text = "今日本地排名"
	board_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	board_title.add_theme_font_size_override("font_size", 14)
	board_title.add_theme_color_override("font_color", Color(0.8, 0.72, 0.5))
	vbox.add_child(board_title)

	_board = Label.new()
	_board.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_board.add_theme_font_size_override("font_size", 15)
	_board.add_theme_color_override("font_color", Color(0.9, 0.88, 0.84))
	vbox.add_child(_board)

	var reward := Label.new()
	reward.text = "首次打完 +%d 血晶。刷新今日最佳再 +%d（各一次）。" % [
		GameConfig.DAILY_PARTICIPATION_CRYSTALS, GameConfig.DAILY_BEST_BONUS_CRYSTALS]
	reward.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward.add_theme_font_size_override("font_size", 13)
	reward.add_theme_color_override("font_color", Color(0.62, 0.78, 1.0))
	vbox.add_child(reward)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	vbox.add_child(row)

	var start := Button.new()
	start.text = "开始今日挑战"
	start.custom_minimum_size = Vector2(180, 42)
	# Space 是开火键：这个面板出现在菜单上，按钮吃焦点会把开火键吞掉。
	start.focus_mode = Control.FOCUS_NONE
	start.pressed.connect(func():
		visible = false
		start_requested.emit()
	)
	row.add_child(start)

	var back := Button.new()
	back.text = "返回"
	back.custom_minimum_size = Vector2(120, 42)
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(func():
		visible = false
		closed.emit()
	)
	row.add_child(back)
