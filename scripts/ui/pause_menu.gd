extends CanvasLayer
## 暂停菜单
## ESC 键暂停游戏，可进设置，可放弃本局（需二次确认）

@onready var panel: PanelContainer = $CenterContainer/PanelContainer

signal resume_requested
signal menu_requested

## 导航出口：默认切主菜单场景。做成可注入 Callable，
## 是为了让"返回主菜单必须放弃深渊"这条行为能在不换场景的前提下被真实驱动。
var go_to_main_menu: Callable = Callable()

## 设置面板（代码构建，和 room_shop 一致：少一个要维护的 .tscn 层级）
var settings_panel: PanelContainer = null
var music_slider: HSlider = null
var sfx_slider: HSlider = null
## 放弃本局的一次性"上膛"状态：第一次点只把按钮变成确认，
## 第二次点才真的退出。暂停菜单是 ESC 顺手按出来的地方，
## 一个误点就把整局（和深渊层数）扔掉，代价和操作太不匹配。
var _abandon_armed: bool = false
var _abandon_button: Button = null
var _settings_button: Button = null

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not go_to_main_menu.is_valid():
		go_to_main_menu = func() -> void:
			get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
	_setup_panel_style()
	_build_settings_panel()
	_setup_button_effects()

func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	# 设置面板开着时 ESC 先收设置，不要顺手把整局也解暂停
	if visible and settings_panel != null and settings_panel.visible:
		get_viewport().set_input_as_handled()
		_on_settings_back_pressed()
		return
	if visible:
		_resume()
	else:
		_pause()

func _setup_panel_style() -> void:
	var panel_texture := TextureManager.instance.get_ui_texture("stats_panel")
	if panel_texture:
		var style := StyleBoxTexture.new()
		style.texture = panel_texture
		style.texture_margin_left = 26.0
		style.texture_margin_right = 26.0
		style.texture_margin_top = 24.0
		style.texture_margin_bottom = 24.0
		panel.add_theme_stylebox_override("panel", style)

func _setup_button_effects() -> void:
	_abandon_button = panel.find_child("MenuButton", true, false) as Button
	if _abandon_button != null:
		# 按钮文案要说清后果：原来的"返回主菜单"看起来像"去看看菜单"，
		# 实际是把这一局（含深渊层数）整局丢掉。
		_abandon_button.text = "放弃本局"
	_ensure_settings_button()
	for btn in panel.find_children("", "Button", true):
		# Space 是开火键。面板按钮可聚焦时，Space 会先被按钮吃掉当成"按下"，
		# 玩家一边点面板一边开火就会误触"返回主菜单"这类不可逆操作。
		btn.focus_mode = Control.FOCUS_NONE
		_style_button(btn)
		UiFx.hover(btn)

func _ensure_settings_button() -> void:
	if _settings_button != null and is_instance_valid(_settings_button):
		return
	var vbox := panel.find_child("VBoxContainer", true, false) as VBoxContainer
	if vbox == null:
		return
	_settings_button = Button.new()
	_settings_button.name = "SettingsButton"
	_settings_button.text = "设置"
	_settings_button.custom_minimum_size = Vector2(0, 45)
	_settings_button.add_theme_font_size_override("font_size", 18)
	_settings_button.focus_mode = Control.FOCUS_NONE
	_settings_button.pressed.connect(_on_settings_pressed)
	vbox.add_child(_settings_button)
	# 排在"继续游戏"下面、"放弃本局"上面
	var resume_btn := panel.find_child("ResumeButton", true, false)
	if resume_btn != null:
		vbox.move_child(_settings_button, resume_btn.get_index() + 1)

func _style_button(btn: Button) -> void:
	var normal := TextureManager.instance.get_ui_texture("btn_normal")
	var hover := TextureManager.instance.get_ui_texture("btn_hover")
	var pressed := TextureManager.instance.get_ui_texture("btn_pressed")
	if normal and hover:
		var normal_style := StyleBoxTexture.new()
		normal_style.texture = normal
		var hover_style := StyleBoxTexture.new()
		hover_style.texture = hover
		var pressed_style := StyleBoxTexture.new()
		pressed_style.texture = pressed if pressed else hover
		btn.add_theme_stylebox_override("normal", normal_style)
		btn.add_theme_stylebox_override("hover", hover_style)
		btn.add_theme_stylebox_override("pressed", pressed_style)
		btn.add_theme_color_override("font_color", Color.WHITE)
		btn.add_theme_color_override("font_hover_color", Color(1, 0.9, 0.7, 1))
		btn.add_theme_color_override("font_pressed_color", Color(0.9, 0.9, 0.9, 1))

# ==================== 设置 ====================

func _build_settings_panel() -> void:
	settings_panel = PanelContainer.new()
	settings_panel.name = "SettingsPanel"
	settings_panel.visible = false
	settings_panel.custom_minimum_size = Vector2(360, 0)
	var panel_texture := TextureManager.instance.get_ui_texture("stats_panel")
	if panel_texture:
		var style := StyleBoxTexture.new()
		style.texture = panel_texture
		style.texture_margin_left = 26.0
		style.texture_margin_right = 26.0
		style.texture_margin_top = 24.0
		style.texture_margin_bottom = 24.0
		style.content_margin_left = 44.0
		style.content_margin_right = 44.0
		style.content_margin_top = 56.0
		style.content_margin_bottom = 32.0
		settings_panel.add_theme_stylebox_override("panel", style)
	$CenterContainer.add_child(settings_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	settings_panel.add_child(vbox)

	var title := Label.new()
	title.text = "设 置"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.66))
	vbox.add_child(title)

	music_slider = _make_slider_row(vbox, "音乐", func(v: float) -> void:
		AudioManager.set_music_volume(v))
	sfx_slider = _make_slider_row(vbox, "音效", func(v: float) -> void:
		AudioManager.set_sfx_volume(v))

	var back := Button.new()
	back.name = "SettingsBackButton"
	back.text = "返回"
	back.custom_minimum_size = Vector2(0, 40)
	back.focus_mode = Control.FOCUS_NONE
	back.add_theme_font_size_override("font_size", 16)
	back.pressed.connect(_on_settings_back_pressed)
	_style_button(back)
	UiFx.hover(back)
	vbox.add_child(back)

func _make_slider_row(parent: VBoxContainer, label_text: String, on_change: Callable) -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(52, 0)
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", Color(0.9, 0.88, 0.84))
	row.add_child(lbl)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.focus_mode = Control.FOCUS_NONE
	row.add_child(slider)

	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(46, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_font_size_override("font_size", 15)
	value_label.add_theme_color_override("font_color", Color(0.72, 0.72, 0.78))
	row.add_child(value_label)
	# 标签句柄挂在滑块上：打开设置时要用 set_value_no_signal 同步当前音量，
	# 而 value_changed 不会因为 set_value_no_signal 触发，数字会停在空白。
	slider.set_meta("value_label", value_label)

	slider.value_changed.connect(func(v: float) -> void:
		value_label.text = "%d%%" % roundi(v * 100.0)
		on_change.call(v))
	return slider

func _sync_slider(slider: HSlider, value: float) -> void:
	if slider == null:
		return
	slider.set_value_no_signal(value)
	if slider.has_meta("value_label"):
		var lbl = slider.get_meta("value_label")
		if lbl is Label and is_instance_valid(lbl):
			lbl.text = "%d%%" % roundi(value * 100.0)

func _on_settings_pressed() -> void:
	if settings_panel == null:
		return
	# 进设置等于"我改主意了"：放弃本局的上膛状态必须清掉。
	# 不清的话，"点放弃 → 反悔 → 看眼设置 → 关设置 → 又点一下"就直接退出，
	# 二次确认变成一次性。
	_disarm_abandon()
	# 两块面板都挂在同一个 CenterContainer 里，同时显示会正对着叠在一起：
	# 设置面板的半透明边缘会把下面的"放弃本局"透出来，字和字压成一团。
	panel.visible = false
	settings_panel.visible = true
	_sync_slider(music_slider, AudioManager.get_music_volume())
	_sync_slider(sfx_slider, AudioManager.get_sfx_volume())
	UiFx.pop_in(settings_panel, 0.16, 0.96)

func _on_settings_back_pressed() -> void:
	if settings_panel == null:
		return
	settings_panel.visible = false
	panel.visible = true

# ==================== 暂停 / 恢复 ====================

func _pause() -> void:
	visible = true
	PauseController.acquire(self)
	_disarm_abandon()
	# 淡入 + 微放大统一交给 UiFx；原来的 modulate 补间会和它抢同一个属性
	UiFx.pop_in(panel, 0.2, 0.96)

func _resume() -> void:
	_disarm_abandon()
	if settings_panel != null:
		settings_panel.visible = false
	panel.visible = true
	PauseController.release(self)
	visible = false
	resume_requested.emit()

func _on_resume_pressed() -> void:
	_resume()

func _disarm_abandon() -> void:
	_abandon_armed = false
	if _abandon_button != null and is_instance_valid(_abandon_button):
		_abandon_button.text = "放弃本局"

func _on_abandon_pressed() -> void:
	## 第一次点：只把按钮换成确认文案。第二次点才真的走。
	## 中途收手的方式是"继续游戏"或再按一次 ESC——那时 _disarm_abandon 会复原。
	if not _abandon_armed:
		_abandon_armed = true
		if _abandon_button != null and is_instance_valid(_abandon_button):
			_abandon_button.text = "再点一次确认放弃"
		return
	_on_menu_pressed()

func _on_menu_pressed() -> void:
	## 回主菜单 = 放弃深渊：与 main._on_return_to_menu 同一语义，
	## 不能因为走了暂停菜单这条更短的路径就把深渊等级带进下一局。
	GameConfig.abandon_abyss()
	_disarm_abandon()
	PauseController.release(self)
	visible = false
	menu_requested.emit()
	if go_to_main_menu.is_valid():
		go_to_main_menu.call()
