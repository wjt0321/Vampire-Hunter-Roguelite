extends CanvasLayer
## 变异房祭坛（17.15）
##
## 这间房本身不打架。决策是“献血豪赌”还是“空手离开”。
## 扣血放在 main 里做：UI 只负责把代价说清楚，并在残血时把豪赌关掉。
## 不关的话，25% 上限会把残血玩家直接扣死，这不是赌博，是自杀按钮。

signal decided(kind: String)

var player: Node = null
var _built: bool = false
var _gamble_btn: Button = null
var _hint: Label = null

func _ready() -> void:
	layer = 96
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

func open(player_node: Node) -> void:
	player = player_node
	if not _built:
		_build_ui()
	_refresh()
	visible = true
	PauseController.acquire(self)

func close() -> void:
	visible = false
	PauseController.release(self)

func _choose(kind: String) -> void:
	close()
	decided.emit(kind)

func _build_ui() -> void:
	_built = true
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.01, 0.04, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.03, 0.05, 0.97)
	style.border_color = Color(0.72, 0.18, 0.24, 0.95)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "变 异 祭 坛"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1.0, 0.78, 0.72))
	vbox.add_child(title)

	var sub := Label.new()
	sub.text = "石盆里的血还是温的。它记得每一个肯付钱的人。"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 13)
	sub.add_theme_color_override("font_color", Color(0.72, 0.64, 0.66))
	vbox.add_child(sub)

	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size = Vector2(420, 0)
	_hint.add_theme_font_size_override("font_size", 15)
	_hint.add_theme_color_override("font_color", Color(0.95, 0.9, 0.86))
	vbox.add_child(_hint)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	vbox.add_child(row)

	_gamble_btn = Button.new()
	_gamble_btn.custom_minimum_size = Vector2(210, 64)
	_gamble_btn.focus_mode = Control.FOCUS_NONE
	_gamble_btn.pressed.connect(func(): _choose("gamble"))
	row.add_child(_gamble_btn)

	var leave := Button.new()
	leave.text = "离开\n不献血，也没有奖励"
	leave.custom_minimum_size = Vector2(210, 64)
	leave.focus_mode = Control.FOCUS_NONE
	leave.pressed.connect(func(): _choose("leave"))
	row.add_child(leave)

func _refresh() -> void:
	var cost := 0.0
	var allowed := false
	if player != null and is_instance_valid(player):
		cost = GameConfig.mutation_cost(float(player.max_hp))
		allowed = GameConfig.can_mutation_gamble(float(player.current_hp), float(player.max_hp))
	var win_pct := roundi(GameConfig.MUTATION_WIN_CHANCE * 100.0)
	_hint.text = "献出 %.0f 生命。%d%% 概率获得银币 %d 与经验 %d，否则只剩银币 %d。血不会还。" % [
		cost, win_pct, GameConfig.MUTATION_WIN_SILVER, GameConfig.MUTATION_WIN_XP, GameConfig.MUTATION_LOSE_SILVER]
	if allowed:
		_gamble_btn.text = "豪赌\n献出 %.0f 生命" % cost
		_gamble_btn.disabled = false
	else:
		_gamble_btn.text = "豪赌\n血不够，会直接倒下"
		_gamble_btn.disabled = true
