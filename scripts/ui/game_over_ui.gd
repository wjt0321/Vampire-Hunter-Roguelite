extends CanvasLayer
## 游戏结束界面
## 显示本局统计信息和血晶奖励

signal restart_requested
signal menu_requested
## 深渊阶梯（17.14）：胜利界面"继续深入"按钮
signal abyss_continue_requested

@onready var stats_label: Label = $CenterContainer/PanelContainer/VBoxContainer/StatsLabel
@onready var achievement_label: Label = $CenterContainer/PanelContainer/VBoxContainer/AchievementLabel
@onready var panel: PanelContainer = $CenterContainer/PanelContainer

var save_mgr: Node
var achievement_mgr: Node
var bg_rect: TextureRect
## 深渊阶梯按钮（胜利界面动态创建）
var abyss_button: Button = null

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
	for btn in panel.find_children("", "Button", true):
		_apply_button_style(btn)

func _apply_button_style(btn: Button) -> void:
	## 只作用单个按钮：动态创建的深渊按钮不能走"整面板重连"，
	## 那会给已有的 Restart/Menu 再叠一次音效连接（hover/click 双播）。
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
	if not btn.mouse_entered.is_connected(_on_button_hover_sfx):
		btn.mouse_entered.connect(_on_button_hover_sfx)
	if not btn.pressed.is_connected(_on_button_click_sfx):
		btn.pressed.connect(_on_button_click_sfx)

func _on_button_hover_sfx() -> void:
	AudioManager.play_sfx(AudioLib.get_sound("hover"))

func _on_button_click_sfx() -> void:
	AudioManager.play_sfx(AudioLib.get_sound("button_click"))

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
	if is_victory:
		var abyss: int = int(stats.get("abyss_level", 0))
		if abyss > 0:
			text += "深渊 %d · " % abyss
		text += "已征服层数: %d / %d\n" % [
			stats.get("floors_cleared", GameConfig.DUNGEON_FLOOR_COUNT),
			GameConfig.DUNGEON_FLOOR_COUNT
		]
	else:
		text += "止步于: 第 %d 层\n" % stats.get("floor", 1)
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
	# 深渊阶梯按钮：胜利才出现
	_setup_abyss_button(is_victory)
	
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

func _on_abyss_pressed() -> void:
	## 深渊阶梯：+1 等级后重开。先归零 paused（reload 不会自动解）
	get_tree().paused = false
	abyss_continue_requested.emit()

func _setup_abyss_button(victory: bool) -> void:
	## 胜利界面才有"继续深入"。按钮动态创建：
	## 失败界面出现它只会把挫败感变成"被劝退感"——连创建都不做，
	## 隐藏按钮仍会留一条无意义的音效连接。
	if not victory:
		if abyss_button != null and is_instance_valid(abyss_button):
			abyss_button.visible = false
		return
	if abyss_button == null:
		abyss_button = Button.new()
		abyss_button.name = "AbyssButton"
		abyss_button.text = "深渊阶梯"
		var vbox: Node = panel.get_node("VBoxContainer")
		# 放在"重新开始"前面：胜利时它是主推选项
		vbox.add_child(abyss_button)
		vbox.move_child(abyss_button, vbox.get_node("AchievementLabel").get_index() + 1)
		abyss_button.pressed.connect(_on_abyss_pressed)
		# 只给新按钮上样式/音效，绝不再遍历整面板（旧按钮会双播）
		_apply_button_style(abyss_button)
	var next_level: int = GameConfig.abyss_level + 1
	abyss_button.text = "深入深渊 %d（血 +%d%% · 伤 +%d%% · 掉落 +%d%%）" % [
		next_level,
		int(GameConfig.ABYSS_STEP_HP * 100.0 * next_level),
		int(GameConfig.ABYSS_STEP_DAMAGE * 100.0 * next_level),
		int(GameConfig.ABYSS_STEP_LOOT * 100.0 * next_level)]
	abyss_button.visible = victory
