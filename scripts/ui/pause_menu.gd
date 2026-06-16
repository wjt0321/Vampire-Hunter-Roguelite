extends CanvasLayer
## 暂停菜单
## ESC 键暂停游戏

@onready var panel: PanelContainer = $CenterContainer/PanelContainer

signal resume_requested
signal menu_requested

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_panel_style()
	_setup_button_effects()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if visible:
			_resume()
		else:
			_pause()

func _setup_panel_style() -> void:
	var panel_texture := TextureManager.instance.get_ui_texture("stats_panel")
	if panel_texture:
		var style := StyleBoxTexture.new()
		style.texture = panel_texture
		panel.add_theme_stylebox_override("panel", style)

func _setup_button_effects() -> void:
	var normal := TextureManager.instance.get_ui_texture("btn_normal")
	var hover := TextureManager.instance.get_ui_texture("btn_hover")
	var pressed := TextureManager.instance.get_ui_texture("btn_pressed")
	for btn in panel.find_children("", "Button", true):
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
		btn.mouse_entered.connect(func(): AudioManager.play_sfx(AudioLib.get_sound("hover")))
		btn.pressed.connect(func(): AudioManager.play_sfx(AudioLib.get_sound("button_click")))

func _pause() -> void:
	visible = true
	get_tree().paused = true
	panel.modulate = Color(1, 1, 1, 0)
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(panel, "modulate:a", 1.0, 0.2)

func _resume() -> void:
	get_tree().paused = false
	visible = false
	resume_requested.emit()

func _on_resume_pressed() -> void:
	_resume()

func _on_menu_pressed() -> void:
	get_tree().paused = false
	visible = false
	menu_requested.emit()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
