extends CanvasLayer
## 游戏结束界面
## 显示本局统计信息和血晶奖励

signal restart_requested
signal menu_requested

@onready var stats_label: Label = $CenterContainer/PanelContainer/VBoxContainer/StatsLabel
@onready var achievement_label: Label = $CenterContainer/PanelContainer/VBoxContainer/AchievementLabel
@onready var panel: PanelContainer = $CenterContainer/PanelContainer

var save_mgr: Node
var achievement_mgr: Node
var bg_rect: TextureRect

func _ready() -> void:
	visible = false
	save_mgr = get_node_or_null("/root/SaveManager")
	achievement_mgr = get_node_or_null("/root/AchievementManager")
	_setup_background()
	_setup_panel_style()

func _setup_background() -> void:
	bg_rect = TextureRect.new()
	bg_rect.name = "Background"
	bg_rect.anchors_preset = Control.PRESET_FULL_RECT
	bg_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg_rect.z_index = -10
	bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg_rect)
	move_child(bg_rect, 0)

func _setup_panel_style() -> void:
	var panel_texture := TextureManager.instance.get_ui_texture("stats_panel")
	if panel_texture:
		var style := StyleBoxTexture.new()
		style.texture = panel_texture
		panel.add_theme_stylebox_override("panel", style)
	_setup_button_effects()

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

func show_game_over(stats: Dictionary, is_victory: bool = false) -> void:
	visible = true
	get_tree().paused = true
	
	var crystals: int = 0
	if save_mgr:
		crystals = save_mgr.end_run(stats)
	
	var title := ""
	if is_victory:
		title = "🦇 胜利！吸血鬼领主已被终结 🦇\n\n"
		stats_label.label_settings = null
		stats_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4, 1.0))
		if bg_rect:
			bg_rect.texture = TextureManager.instance.get_ui_texture("victory_bg")
		AudioManager.play_bgm(AudioLib.get_victory_bgm())
	else:
		title = "☠ 游戏结束 ☠\n\n"
		stats_label.add_theme_color_override("font_color", Color(0.85, 0.2, 0.2, 1.0))
		if bg_rect:
			bg_rect.texture = TextureManager.instance.get_ui_texture("defeat_bg")
		AudioManager.play_bgm(AudioLib.get_defeat_bgm())
	
	var text := title
	text += "探索房间: %d\n" % stats.get("rooms", 0)
	text += "存活波次: %d\n" % stats.get("wave", 0)
	text += "击杀数: %d\n" % stats.get("kills", 0)
	text += "达到等级: %d\n" % stats.get("level", 1)

	var survival_seconds: int = stats.get("survival_time", 0)
	var minutes: int = survival_seconds / 60
	var seconds: int = survival_seconds % 60
	text += "生存时间: %d:%02d\n" % [minutes, seconds]
	text += "受到伤害: %.0f\n" % stats.get("damage_taken", 0)

	if save_mgr:
		text += "\n💎 获得血晶: +%d\n" % crystals
		text += "💎 总血晶: %d" % save_mgr.get_blood_crystals()
	stats_label.text = text
	
	# 显示本局解锁的成就
	_update_achievement_display()
	
	panel.modulate = Color(1, 1, 1, 0)
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(panel, "modulate:a", 1.0, 0.3)

func _update_achievement_display() -> void:
	if not achievement_mgr:
		achievement_label.text = ""
		return
	
	var unlocked: Array[String] = achievement_mgr.get_unlocked_this_run()
	if unlocked.is_empty():
		achievement_label.text = ""
		return
	
	var text := "\n🏆 本局解锁成就:\n"
	for ach_id in unlocked:
		var info: Dictionary = achievement_mgr.get_achievement_info(ach_id)
		text += "  %s %s\n" % [info.get("icon", "🏆"), info.get("name", ach_id)]
	
	achievement_label.text = text

func _on_restart_pressed() -> void:
	get_tree().paused = false
	restart_requested.emit()

func _on_menu_pressed() -> void:
	get_tree().paused = false
	menu_requested.emit()
