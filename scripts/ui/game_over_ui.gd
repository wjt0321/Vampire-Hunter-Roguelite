extends CanvasLayer
## 游戏结束界面
## 显示本局统计信息和血晶奖励

signal restart_requested
signal menu_requested
## 深渊阶梯（17.14）：胜利界面"继续深入"按钮
signal abyss_continue_requested

@onready var title_label: Label = $CenterContainer/PanelContainer/VBoxContainer/TitleLabel
@onready var stats_label: Label = $CenterContainer/PanelContainer/VBoxContainer/StatsLabel
@onready var achievement_label: Label = $CenterContainer/PanelContainer/VBoxContainer/AchievementLabel
@onready var panel: PanelContainer = $CenterContainer/PanelContainer

var save_mgr: Node
var achievement_mgr: Node
var bg_rect: TextureRect
## 深渊阶梯按钮（胜利界面动态创建）
var abyss_button: Button = null
## 成就徽章行容器（运行时创建，挂在 AchievementLabel 下面）
var achievement_list: VBoxContainer = null
## 成就列表的滚动外层（一局解锁很多成就时不让面板撑出屏幕）
var achievement_scroll: ScrollContainer = null
var _run_settlement_submitted: bool = false

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
		# stats_panel 纹理自带约 24px 金框。不设 texture_margin 时 PanelContainer
		# 会把内容从纹理边缘开始摆，标题和统计行直接压在金框花纹上。
		# 主菜单/商店/升级弹窗都是九宫格拉出内容区，这里漏了。
		style.texture_margin_left = 26.0
		style.texture_margin_right = 26.0
		# 面板顶部中间有个向上凸起的尖刺装饰（选角界面用的是 62/66）。
		# 这里按尖刺高度让出内容区，标题才不会撞在花纹上。
		style.texture_margin_top = 56.0
		style.texture_margin_bottom = 28.0
		style.content_margin_top = 60.0
		style.content_margin_bottom = 32.0
		panel.add_theme_stylebox_override("panel", style)
	_setup_button_effects()

func _setup_button_effects() -> void:
	for btn in panel.find_children("", "Button", true):
		_apply_button_style(btn)

func _apply_button_style(btn: Button) -> void:
	## 只作用单个按钮：动态创建的深渊按钮不能走"整面板重连"，
	## 那会给已有的 Restart/Menu 再叠一次音效连接（hover/click 双播）。
	## 焦点也一样：统一在这里设，动态建的 AbyssButton 才不会漏。
	## Space 是开火键，按钮吃到焦点就会被 ui_accept 吞掉。
	btn.focus_mode = Control.FOCUS_NONE
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
	UiFx.hover(btn)
	if not btn.mouse_entered.is_connected(_on_button_hover_sfx):
		btn.mouse_entered.connect(_on_button_hover_sfx)
	if not btn.pressed.is_connected(_on_button_click_sfx):
		btn.pressed.connect(_on_button_click_sfx)

func _on_button_hover_sfx() -> void:
	AudioManager.play_ui_sfx(AudioLib.get_sound("hover"))

func _on_button_click_sfx() -> void:
	AudioManager.play_ui_sfx(AudioLib.get_sound("button_click"))

func show_game_over(stats: Dictionary, is_victory: bool = false) -> void:
	if _run_settlement_submitted:
		return
	_run_settlement_submitted = true
	visible = true
	PauseController.acquire(self)
	
	var crystals: int = 0
	var daily_line := ""
	if save_mgr:
		crystals = save_mgr.end_run(stats)
		if bool(stats.get("daily", false)) and save_mgr.has_method("record_daily_run"):
			var rec: Dictionary = save_mgr.record_daily_run(String(stats.get("daily_date", "")), stats)
			crystals += int(rec.get("crystals", 0))
			daily_line = String(rec.get("summary", ""))
	if achievement_mgr and crystals > 0:
		achievement_mgr.record_crystals_earned(crystals)
	
	if is_victory:
		title_label.text = "胜利！吸血鬼领主已被终结"
		stats_label.label_settings = null
		title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4, 1.0))
		stats_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4, 1.0))
		if bg_rect:
			bg_rect.texture = TextureManager.instance.get_ui_texture("victory_bg")
		AudioManager.play_bgm(AudioLib.get_victory_bgm())
	else:
		title_label.text = "游戏结束"
		title_label.add_theme_color_override("font_color", Color(0.85, 0.2, 0.2, 1.0))
		stats_label.add_theme_color_override("font_color", Color(0.9, 0.42, 0.42, 1.0))
		if bg_rect:
			bg_rect.texture = TextureManager.instance.get_ui_texture("defeat_bg")
		AudioManager.play_bgm(AudioLib.get_defeat_bgm())

	var text := ""
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
		text += "\n获得血晶: +%d\n" % crystals
		text += "总血晶: %d" % save_mgr.get_blood_crystals()
	if daily_line != "":
		text += "\n" + daily_line
	stats_label.text = text
	
	# 显示本局解锁的成就
	_update_achievement_display()
	# 深渊阶梯按钮：胜利才出现
	# 每日挑战不接深渊。两套规则叠在一起，排行榜和词缀都说不清是哪一局。
	_setup_abyss_button(is_victory and not bool(stats.get("daily", false)))
	
	panel.modulate = Color(1, 1, 1, 0)
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(panel, "modulate:a", 1.0, 0.3)

func _update_achievement_display() -> void:
	## 成就列表：每行一个徽章贴图 + 名称。
	## 旧版是一个 Label 里拼 "★ 第一滴血" 这种纯文字——25 个成就共用同一个
	## "★" 字符，结算界面就是一整列没有辨识度的文字。
	var list := _ensure_achievement_list()
	for child in list.get_children():
		child.queue_free()

	if not achievement_mgr:
		achievement_label.text = ""
		return

	var unlocked: Array[String] = achievement_mgr.get_unlocked_this_run()
	if unlocked.is_empty():
		achievement_label.text = ""
		return

	achievement_label.text = "本局解锁成就:"
	for ach_id in unlocked:
		var info: Dictionary = achievement_mgr.get_achievement_info(ach_id)
		list.add_child(_make_achievement_row(ach_id, String(info.get("name", ach_id))))

func _ensure_achievement_list() -> VBoxContainer:
	## 成就行容器：运行时建在 AchievementLabel 下面（不改 .tscn 结构）
	##
	## 外层套 ScrollContainer：一局解锁 20+ 个成就时，
	## 48px 图标行会把面板撑到 1000px 高，整块跑出屏幕。
	## 152px 高——正好 3 行徽章（48*3 + 行距 4*2），第三行不会被裁掉半截。
	if achievement_list != null and is_instance_valid(achievement_list):
		return achievement_list
	var parent := achievement_label.get_parent()

	var scroll := ScrollContainer.new()
	scroll.name = "AchievementScroll"
	scroll.custom_minimum_size = Vector2(0, 152)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(scroll)
	achievement_scroll = scroll

	achievement_list = VBoxContainer.new()
	achievement_list.name = "AchievementList"
	achievement_list.alignment = BoxContainer.ALIGNMENT_CENTER
	achievement_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	achievement_list.add_theme_constant_override("separation", 4)
	scroll.add_child(achievement_list)

	parent.move_child(scroll, achievement_label.get_index() + 1)
	return achievement_list

func _make_achievement_row(ach_id: String, ach_name: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(48, 48)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tex: Texture2D = TextureManager.instance.get_achievement_icon(ach_id)
	if tex != null:
		icon.texture = tex
	else:
		icon.visible = false
	row.add_child(icon)

	var name_label := Label.new()
	name_label.text = ach_name
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.55))
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(name_label)
	return row

func _on_restart_pressed() -> void:
	PauseController.release(self)
	restart_requested.emit()

func _on_menu_pressed() -> void:
	PauseController.release(self)
	menu_requested.emit()

func _on_abyss_pressed() -> void:
	## 深渊阶梯：+1 等级后重开。reload_current_scene() 不会替新场景解掉
	## 上一帧留下的暂停（上一轮踩过：无尽阶梯第一层就是冻结画面），
	## 所以这里走"场景即将整体重载"的专用入口，它自己会解除暂停。
	PauseController.reset_for_scene_change()
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
		# 放在"重新开始"前面：胜利时它是主推选项。
		# 位置要落在成就列表**之后**——成就行容器是运行时建的，
		# 插在 AchievementLabel 后面，所以基准节点要跟着换。
		vbox.add_child(abyss_button)
		var anchor: Node = achievement_scroll if (achievement_scroll != null and is_instance_valid(achievement_scroll)) \
			else vbox.get_node("AchievementLabel")
		vbox.move_child(abyss_button, anchor.get_index() + 1)
		abyss_button.pressed.connect(_on_abyss_pressed)
		# 只给新按钮上样式/音效，绝不再遍历整面板（旧按钮会双播）
		_apply_button_style(abyss_button)
	var next_level: int = GameConfig.abyss_level + 1
	# 百分比是"下一轮的总倍率"（等级 × 每级步进），不是这一次继续的增量。
	# 不写明口径的话，"血 +45%" 会被读成"在现有基础上再加 45%"。
	abyss_button.text = "深入深渊 %d（下一轮总计：血 +%d%% · 伤 +%d%% · 掉落 +%d%%）" % [
		next_level,
		int(GameConfig.ABYSS_STEP_HP * 100.0 * next_level),
		int(GameConfig.ABYSS_STEP_DAMAGE * 100.0 * next_level),
		int(GameConfig.ABYSS_STEP_LOOT * 100.0 * next_level)]
	abyss_button.visible = victory
