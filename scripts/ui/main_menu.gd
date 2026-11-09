extends CanvasLayer
## 主菜单
## 暗黑哥特风格

const DailyChallengeScript = preload("res://scripts/core/daily_challenge.gd")


@onready var title_label: Label = $CenterContainer/VBoxContainer/TitleRow/TitleLabel
@onready var subtitle_label: Label = $CenterContainer/VBoxContainer/SubtitleLabel
@onready var start_btn: Button = $CenterContainer/VBoxContainer/ButtonContainer/StartButton
@onready var char_btn: Button = $CenterContainer/VBoxContainer/ButtonContainer/CharButton
@onready var shop_btn: Button = $CenterContainer/VBoxContainer/ButtonContainer/ShopButton
@onready var settings_btn: Button = $CenterContainer/VBoxContainer/ButtonContainer/SettingsButton
@onready var quit_btn: Button = $CenterContainer/VBoxContainer/ButtonContainer/QuitButton
@onready var settings_panel: PanelContainer = $SettingsPanel
@onready var bg: ColorRect = $Background
@onready var crystals_label: Label = $CenterContainer/VBoxContainer/CrystalsRow/CrystalsLabel
@onready var crystal_icon: TextureRect = $CenterContainer/VBoxContainer/CrystalsRow/CrystalIcon
@onready var bat_left: TextureRect = $CenterContainer/VBoxContainer/TitleRow/BatLeft
@onready var bat_right: TextureRect = $CenterContainer/VBoxContainer/TitleRow/BatRight
@onready var upgrade_shop = $UpgradeShop
@onready var character_select = $CharacterSelect

@onready var music_slider: HSlider = $SettingsPanel/VBoxContainer/MusicSlider
@onready var sfx_slider: HSlider = $SettingsPanel/VBoxContainer/SFXSlider
@onready var fullscreen_check: CheckButton = $SettingsPanel/VBoxContainer/FullscreenCheck
@onready var back_btn: Button = $SettingsPanel/VBoxContainer/BackButton

var save_mgr: Node

# 按钮动画缓动缓存，避免快速悬停时 tween 堆积
var _button_tweens: Dictionary = {}

var daily_btn: Button
var daily_panel: CanvasLayer

func _ready() -> void:
	# 主菜单是新一局的入口：从任何路径回到这里都等于放弃深渊，也退出每日挑战
	GameConfig.abandon_abyss()
	GameConfig.clear_daily()
	_create_daily_button()
	settings_panel.visible = false
	save_mgr = get_node_or_null("/root/SaveManager")
	_setup_background()
	_setup_button_effects()
	_setup_button_textures()
	_setup_menu_icons()
	_setup_settings_panel()
	_setup_volume_sliders()
	_animate_title()
	_update_crystals()
	upgrade_shop.shop_closed.connect(_update_crystals)
	character_select.selection_closed.connect(_update_crystals)
	
	# 播放主菜单 BGM
	var audio_lib := AudioLib
	AudioManager.play_bgm(audio_lib.get_menu_bgm())

func _setup_settings_panel() -> void:
	## 设置面板使用统一面板纹理。
	## stats_panel 纹理自带约 24px 金框；不设 texture_margin 时 PanelContainer
	## 会把内容从纹理边缘开始摆（滑块/按钮压在金框外面），必须九宫格拉出内容区。
	var panel_texture := TextureManager.instance.get_ui_texture("stats_panel")
	if panel_texture:
		var style := StyleBoxTexture.new()
		style.texture = panel_texture
		style.texture_margin_left = 26.0
		style.texture_margin_right = 26.0
		style.texture_margin_top = 24.0
		style.texture_margin_bottom = 24.0
		settings_panel.add_theme_stylebox_override("panel", style)

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
		# 只写 anchors_preset 不够：Control 不在容器里时 rect 仍是 0×0，
		# 结果就是菜单背景不显示、透出引擎清屏灰。必须同时把 offset 归零。
		texture_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(texture_rect)
		texture_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		move_child(texture_rect, 0)  # 移到最底层
		bg.visible = false  # 隐藏原来的ColorRect

## 之前标题和按钮里的 🧛 ⚔ 🏪 之类是 emoji 字形：字体缺字时会掉成方块，
## 而且形状完全不受控。这里统一换成像素图标（assets/ui/menu_*.png）。
func _setup_menu_icons() -> void:
	var ui := TextureManager.instance
	var bat := ui.get_ui_texture("menu_bat")
	if bat:
		bat_left.texture = bat
		bat_right.texture = bat
	var crystal := ui.get_ui_texture("menu_crystal")
	if crystal:
		crystal_icon.texture = crystal

	var pairs := [
		[start_btn, "menu_play"],
		[char_btn, "menu_character"],
		[shop_btn, "menu_shop"],
		[settings_btn, "menu_settings"],
		[quit_btn, "menu_quit"],
	]
	if daily_btn:
		pairs.append([daily_btn, "menu_daily"])
	for pair in pairs:
		_decorate_button(pair[0], ui.get_ui_texture(pair[1]))

## Button.icon 是把图标按 icon_alignment 单独摆位、文字另外居中，
## 两者不在同一组里，图标会压在金色边框上。改成在按钮内塞一个
## HBox([图标][文字])，整组居中，位置才对。
func _decorate_button(btn: Button, tex: Texture2D) -> void:
	if btn == null or tex == null:
		return
	var text := btn.text
	btn.text = ""
	var row := HBoxContainer.new()
	row.name = "IconRow"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	btn.add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var icon := TextureRect.new()
	icon.texture = tex
	icon.custom_minimum_size = Vector2(tex.get_width(), tex.get_height())
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)

	var label := Label.new()
	label.text = text
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", btn.get_theme_font_size("font_size"))
	label.add_theme_color_override("font_color", Color(0.93, 0.9, 0.86))
	row.add_child(label)

func _update_crystals() -> void:
	if save_mgr:
		crystals_label.text = "血晶: %d" % save_mgr.get_blood_crystals()

func _create_daily_button() -> void:
	var box := $CenterContainer/VBoxContainer/ButtonContainer
	daily_btn = Button.new()
	daily_btn.name = "DailyButton"
	daily_btn.text = "每日挑战"
	daily_btn.custom_minimum_size = Vector2(280, 45)
	daily_btn.add_theme_font_size_override("font_size", 18)
	daily_btn.pivot_offset = Vector2(140, 22)
	box.add_child(daily_btn)
	box.move_child(daily_btn, shop_btn.get_index() + 1)
	daily_btn.pressed.connect(_on_daily_pressed)
	daily_panel = CanvasLayer.new()
	daily_panel.name = "DailyPanel"
	daily_panel.set_script(preload("res://scripts/ui/daily_challenge_panel.gd"))
	add_child(daily_panel)
	daily_panel.start_requested.connect(_on_daily_start)

func _setup_button_effects() -> void:
	for btn in [start_btn, char_btn, shop_btn, daily_btn, settings_btn, quit_btn, back_btn]:
		btn.mouse_entered.connect(func(): _on_button_hover(btn))
		btn.mouse_exited.connect(func(): _on_button_unhover(btn))
		btn.pressed.connect(_on_button_click)
		UiFx.hover(btn)

func _setup_button_textures() -> void:
	## 设置按钮纹理
	var normal_texture := TextureManager.instance.get_ui_texture("btn_normal")
	var hover_texture := TextureManager.instance.get_ui_texture("btn_hover")
	var pressed_texture := TextureManager.instance.get_ui_texture("btn_pressed")
	
	if normal_texture and hover_texture:
		for btn in [start_btn, char_btn, shop_btn, daily_btn, settings_btn, quit_btn, back_btn]:
			# 创建纹理按钮样式
			var normal_style := StyleBoxTexture.new()
			normal_style.texture = normal_texture
			
			var hover_style := StyleBoxTexture.new()
			hover_style.texture = hover_texture
			
			var pressed_style := StyleBoxTexture.new()
			pressed_style.texture = pressed_texture if pressed_texture else hover_texture
			
			btn.add_theme_stylebox_override("normal", normal_style)
			btn.add_theme_stylebox_override("hover", hover_style)
			btn.add_theme_stylebox_override("pressed", pressed_style)
			btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
			btn.add_theme_color_override("font_hover_color", Color(1, 0.9, 0.7, 1))
			btn.add_theme_color_override("font_pressed_color", Color(0.9, 0.9, 0.9, 1))

func _on_button_hover(btn: Button) -> void:
	_kill_button_tween(btn)
	var tween := create_tween()
	_button_tweens[btn] = tween
	tween.tween_property(btn, "scale", Vector2(1.08, 1.08), 0.15)
	btn.modulate = Color(1.3, 0.9, 0.9, 1.0)
	AudioManager.play_sfx(AudioLib.get_sound("hover"))

func _on_button_unhover(btn: Button) -> void:
	_kill_button_tween(btn)
	var tween := create_tween()
	_button_tweens[btn] = tween
	tween.tween_property(btn, "scale", Vector2.ONE, 0.15)
	btn.modulate = Color.WHITE

func _kill_button_tween(btn: Button) -> void:
	if _button_tweens.has(btn):
		var old_tween: Tween = _button_tweens[btn]
		if old_tween and old_tween.is_valid():
			old_tween.kill()
		_button_tweens.erase(btn)

func _on_button_click() -> void:
	var audio_lib := AudioLib
	AudioManager.play_sfx(audio_lib.get_sound("button_click"))

func _animate_title() -> void:
	var tween := create_tween().set_loops()
	tween.tween_property(title_label, "modulate:a", 0.7, 2.0)
	tween.tween_property(title_label, "modulate:a", 1.0, 2.0)

func _on_start_pressed() -> void:
	GameConfig.clear_daily()
	var tween := create_tween()
	tween.tween_property(bg, "color:a", 1.0, 0.5)
	tween.tween_callback(func(): get_tree().change_scene_to_file("res://scenes/main.tscn"))

func _on_daily_pressed() -> void:
	if daily_panel and daily_panel.has_method("open_today"):
		daily_panel.open_today(save_mgr)

func _on_daily_start() -> void:
	var spec: Dictionary = DailyChallengeScript.build(DailyChallengeScript.today())
	GameConfig.abandon_abyss()
	GameConfig.start_daily(spec)
	get_tree().change_scene_to_file("res://scenes/main.tscn")

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
