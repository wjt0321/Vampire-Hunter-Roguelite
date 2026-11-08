extends CanvasLayer
## 暂停菜单
## ESC 键暂停游戏

@onready var panel: PanelContainer = $CenterContainer/PanelContainer

signal resume_requested
signal menu_requested

## 导航出口：默认切主菜单场景。做成可注入 Callable，
## 是为了让"返回主菜单必须放弃深渊"这条行为能在不换场景的前提下被真实驱动。
var go_to_main_menu: Callable = Callable()

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not go_to_main_menu.is_valid():
		go_to_main_menu = func() -> void:
			get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
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
	# 回主菜单 = 放弃深渊：与 main._on_return_to_menu 同一语义，
	# 不能因为走了暂停菜单这条更短的路径就把深渊等级带进下一局。
	GameConfig.abandon_abyss()
	get_tree().paused = false
	visible = false
	menu_requested.emit()
	if go_to_main_menu.is_valid():
		go_to_main_menu.call()
