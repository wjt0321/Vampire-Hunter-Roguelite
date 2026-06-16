extends CanvasLayer
## 主菜单
## 暗黑哥特风格

const AudioLibraryScript = preload("res://scripts/managers/audio_library.gd")

@onready var title_label: Label = $CenterContainer/VBoxContainer/TitleLabel
@onready var subtitle_label: Label = $CenterContainer/VBoxContainer/SubtitleLabel
@onready var start_btn: Button = $CenterContainer/VBoxContainer/ButtonContainer/StartButton
@onready var char_btn: Button = $CenterContainer/VBoxContainer/ButtonContainer/CharButton
@onready var shop_btn: Button = $CenterContainer/VBoxContainer/ButtonContainer/ShopButton
@onready var settings_btn: Button = $CenterContainer/VBoxContainer/ButtonContainer/SettingsButton
@onready var quit_btn: Button = $CenterContainer/VBoxContainer/ButtonContainer/QuitButton
@onready var settings_panel: PanelContainer = $SettingsPanel
@onready var bg: ColorRect = $Background
@onready var crystals_label: Label = $CenterContainer/VBoxContainer/CrystalsLabel
@onready var upgrade_shop = $UpgradeShop
@onready var character_select = $CharacterSelect

@onready var music_slider: HSlider = $SettingsPanel/VBoxContainer/MusicSlider
@onready var sfx_slider: HSlider = $SettingsPanel/VBoxContainer/SFXSlider
@onready var fullscreen_check: CheckButton = $SettingsPanel/VBoxContainer/FullscreenCheck
@onready var back_btn: Button = $SettingsPanel/VBoxContainer/BackButton

var save_mgr: Node

func _ready() -> void:
	settings_panel.visible = false
	save_mgr = get_node_or_null("/root/SaveManager")
	_setup_background()
	_setup_button_effects()
	_setup_button_textures()
	_setup_volume_sliders()
	_animate_title()
	_update_crystals()
	upgrade_shop.shop_closed.connect(_update_crystals)
	character_select.selection_closed.connect(_update_crystals)
	
	# 播放主菜单 BGM
	var audio_lib := AudioLibraryScript.new()
	AudioManager.play_bgm(audio_lib.get_menu_bgm())

func _setup_background() -> void:
	## 设置菜单背景图
	var bg_texture := TextureManager.instance.get_background("menu")
	if bg_texture:
		# 将ColorRect替换为TextureRect
		var texture_rect := TextureRect.new()
		texture_rect.name = "BackgroundTexture"
		texture_rect.texture = bg_texture
		texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		texture_rect.anchors_preset = Control.PRESET_FULL_RECT
		add_child(texture_rect)
		move_child(texture_rect, 0)  # 移到最底层
		bg.visible = false  # 隐藏原来的ColorRect

func _update_crystals() -> void:
	if save_mgr:
		crystals_label.text = "💎 血晶: %d" % save_mgr.get_blood_crystals()

func _setup_button_effects() -> void:
	for btn in [start_btn, char_btn, shop_btn, settings_btn, quit_btn, back_btn]:
		btn.mouse_entered.connect(func(): _on_button_hover(btn))
		btn.mouse_exited.connect(func(): _on_button_unhover(btn))
		btn.pressed.connect(_on_button_click)

func _setup_button_textures() -> void:
	## 设置按钮纹理
	var normal_texture := TextureManager.instance.get_ui_texture("btn_normal")
	var hover_texture := TextureManager.instance.get_ui_texture("btn_hover")
	
	if normal_texture and hover_texture:
		for btn in [start_btn, char_btn, shop_btn, settings_btn, quit_btn, back_btn]:
			# 创建纹理按钮样式
			var normal_style := StyleBoxTexture.new()
			normal_style.texture = normal_texture
			
			var hover_style := StyleBoxTexture.new()
			hover_style.texture = hover_texture
			
			var pressed_style := StyleBoxTexture.new()
			pressed_style.texture = hover_texture
			
			btn.add_theme_stylebox_override("normal", normal_style)
			btn.add_theme_stylebox_override("hover", hover_style)
			btn.add_theme_stylebox_override("pressed", pressed_style)
			btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
			btn.add_theme_color_override("font_hover_color", Color(1, 0.9, 0.7, 1))
			btn.add_theme_color_override("font_pressed_color", Color(0.9, 0.9, 0.9, 1))

func _on_button_hover(btn: Button) -> void:
	var tween := create_tween()
	tween.tween_property(btn, "scale", Vector2(1.08, 1.08), 0.15)
	btn.modulate = Color(1.3, 0.9, 0.9, 1.0)

func _on_button_unhover(btn: Button) -> void:
	var tween := create_tween()
	tween.tween_property(btn, "scale", Vector2.ONE, 0.15)
	btn.modulate = Color.WHITE

func _on_button_click() -> void:
	var audio_lib := AudioLibraryScript.new()
	AudioManager.play_sfx(audio_lib.get_sound("button_click"))

func _animate_title() -> void:
	var tween := create_tween().set_loops()
	tween.tween_property(title_label, "modulate:a", 0.7, 2.0)
	tween.tween_property(title_label, "modulate:a", 1.0, 2.0)

func _on_start_pressed() -> void:
	var tween := create_tween()
	tween.tween_property(bg, "color:a", 1.0, 0.5)
	tween.tween_callback(func(): get_tree().change_scene_to_file("res://scenes/main.tscn"))

func _on_char_pressed() -> void:
	character_select.show_selection()

func _on_shop_pressed() -> void:
	upgrade_shop.show_shop()

func _on_settings_pressed() -> void:
	settings_panel.visible = true
	settings_panel.modulate = Color(1, 1, 1, 0)
	var tween := create_tween()
	tween.tween_property(settings_panel, "modulate:a", 1.0, 0.2)

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_back_pressed() -> void:
	var tween := create_tween()
	tween.tween_property(settings_panel, "modulate:a", 0.0, 0.2)
	tween.tween_callback(func(): settings_panel.visible = false)

func _setup_volume_sliders() -> void:
	## 初始化音量滑块为当前设置
	music_slider.value = AudioManager.get_music_volume()
	sfx_slider.value = AudioManager.get_sfx_volume()

func _on_music_changed(value: float) -> void:
	AudioManager.set_music_volume(value)

func _on_sfx_changed(value: float) -> void:
	AudioManager.set_sfx_volume(value)

func _on_fullscreen_toggled(toggled: bool) -> void:
	if toggled:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
