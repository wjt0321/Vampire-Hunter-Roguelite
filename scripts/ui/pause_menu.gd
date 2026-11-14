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
## 图鉴面板。与设置面板同级，打开时把主菜单面板收起来，关掉再换回来。
var codex_panel: PanelContainer = null
var codex_list: VBoxContainer = null

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not go_to_main_menu.is_valid():
		go_to_main_menu = func() -> void:
			get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
	_setup_panel_style()
	_build_settings_panel()
	_build_codex_panel()
	_setup_button_effects()

func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	# 图鉴开着时 ESC 先关图鉴，回 ESC 菜单本身。
	# 以前没有这一层：ESC 直接把整个菜单关掉，玩家从图鉴回不到菜单，
	# 只能重新按一次 ESC 重新开（试玩反馈："无法返回到 ESC 菜单"）。
	if visible and codex_panel != null and codex_panel.visible:
		get_viewport().set_input_as_handled()
		_on_codex_back_pressed()
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
	_ensure_codex_button()
	# owned 必须传 false：find_children 默认只返回"场景文件里带的"子节点，
	# 而"设置"和"图鉴"两个按钮是运行时 new 出来的，
	# 于是它们从来没进过这个循环，也就从来没套上 btn_normal/btn_hover 贴图——
	# 菜单里另外三个按钮有花纹边框，这两个只有一块灰色底（试玩反馈："设置和图鉴没有贴图"）。
	for btn in panel.find_children("", "Button", true, false):
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
	_style_button(_settings_button)
	UiFx.hover(_settings_button)
	vbox.add_child(_settings_button)
	# 排在"继续游戏"下面、"放弃本局"上面
	var resume_btn := panel.find_child("ResumeButton", true, false)
	if resume_btn != null:
		vbox.move_child(_settings_button, resume_btn.get_index() + 1)

func _ensure_codex_button() -> void:
	var vbox := panel.find_child("VBoxContainer", true, false) as VBoxContainer
	if vbox == null or vbox.find_child("CodexButton", true, false) != null:
		return
	var button := Button.new()
	button.name = "CodexButton"
	button.text = "图鉴"
	button.custom_minimum_size = Vector2(0, 45)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(_show_codex)
	_style_button(button)
	UiFx.hover(button)
	vbox.add_child(button)
	if _settings_button != null:
		vbox.move_child(button, _settings_button.get_index() + 1)

func _show_codex() -> void:
	## 图鉴：以前是一整块纯文本 Label，所有条目糊成 "敌人 ???" 一长串，
	## 既没有图也没有分行（试玩反馈："图鉴功能没做完"）。
	## 现在是正经面板：图标 + 中文名 + 遭遇要点，没见过的显示问号。
	if codex_panel == null:
		_build_codex_panel()
	_refresh_codex()
	var opening := not codex_panel.visible
	codex_panel.visible = opening
	panel.visible = not opening
	if opening:
		_disarm_abandon()
		UiFx.pop_in(codex_panel, 0.18, 0.96)

func _on_codex_back_pressed() -> void:
	## 从图鉴回到 ESC 菜单本体。以前没有这个出口，
	## 玩家只能靠 ESC 把整个菜单一起关掉，回不到菜单里。
	if codex_panel == null:
		return
	codex_panel.visible = false
	panel.visible = true

func _build_codex_panel() -> void:
	codex_panel = PanelContainer.new()
	codex_panel.name = "CodexPanel"
	codex_panel.visible = false
	codex_panel.custom_minimum_size = Vector2(920, 600)
	var panel_texture := TextureManager.instance.get_ui_texture("stats_panel")
	if panel_texture:
		var style := StyleBoxTexture.new()
		style.texture = panel_texture
		style.texture_margin_left = 26.0
		style.texture_margin_right = 26.0
		style.texture_margin_top = 24.0
		style.texture_margin_bottom = 24.0
		# stats_panel 是 400x300 的描金花框贴图，框本身占掉外圈约 70px。
		# 内边距按框留白给，否则图标和分区标题会压在花纹上（实机截图里
		# "敌人"两个字被左侧花纹吃掉一半）。
		style.content_margin_left = 76.0
		style.content_margin_right = 76.0
		style.content_margin_top = 78.0
		style.content_margin_bottom = 74.0
		codex_panel.add_theme_stylebox_override("panel", style)
	$CenterContainer.add_child(codex_panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	codex_panel.add_child(root)

	var title := Label.new()
	title.text = "图  鉴"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.66))
	root.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	codex_list = VBoxContainer.new()
	codex_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	codex_list.add_theme_constant_override("separation", 6)
	scroll.add_child(codex_list)

	var back := Button.new()
	back.name = "CodexBackButton"
	back.text = "返回"
	back.custom_minimum_size = Vector2(190, 42)
	# 不占满整行：按钮贴图是横向花纹带，拉到 900px 宽就成了"一条空杠"。
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.focus_mode = Control.FOCUS_NONE
	back.add_theme_font_size_override("font_size", 16)
	back.pressed.connect(_on_codex_back_pressed)
	_style_button(back)
	UiFx.hover(back)
	root.add_child(back)

func _refresh_codex() -> void:
	## 每次打开都重建：解锁状态是随进度变的，缓存下来的列表会过期。
	if codex_list == null:
		return
	for child in codex_list.get_children():
		codex_list.remove_child(child)
		child.queue_free()
	var slots = preload("res://scripts/core/asset_slots.gd")
	var catalog = preload("res://scripts/core/item_catalog.gd")
	var saves := get_node_or_null("/root/SaveManager")

	_codex_section(codex_list, "敌人")
	for enemy_id in slots.ENEMIES.keys():
		var eid := String(enemy_id)
		var info: Dictionary = slots.ENEMIES[eid]
		_codex_entry(codex_list,
			String(info.get("name", eid)),
			String(info.get("blurb", "")),
			_first_frame(slots.enemy_texture(eid, "idle"), 56),
			_codex_known(saves, "enemy", eid),
			slots.codex_meta_line(eid))

	_codex_section(codex_list, "Boss")
	for boss_id in slots.BOSSES.keys():
		var bid := String(boss_id)
		var info: Dictionary = slots.BOSSES[bid]
		_codex_entry(codex_list,
			String(info.get("name", bid)),
			String(info.get("blurb", "")),
			_first_frame(slots.boss_texture(bid, "idle"), 128),
			_codex_known(saves, "boss", bid),
			slots.codex_meta_line(bid))

	_codex_section(codex_list, "武器")
	for weapon in catalog.WEAPONS:
		var wid := String(weapon.get("id", ""))
		var text := slots.blurb("weapon", wid)
		if text == "":
			text = String(weapon.get("desc", ""))
		_codex_entry(codex_list, String(weapon.get("name", wid)), text,
			catalog.get_icon_texture(wid, "weapon"),
			_codex_known(saves, "weapon", wid),
			"获得：升级三选一 / 两把武器融合")

	_codex_section(codex_list, "被动")
	for passive in catalog.PASSIVES:
		var pid := String(passive.get("id", ""))
		var text := slots.blurb("passive", pid)
		if text == "":
			text = String(passive.get("desc", ""))
		_codex_entry(codex_list, String(passive.get("name", pid)), text,
			catalog.get_icon_texture(pid, "passive"),
			_codex_known(saves, "passive", pid),
			"获得：升级三选一")

func _codex_known(saves: Node, kind: String, entry_id: String) -> bool:
	if saves == null or not saves.has_method("codex_known"):
		return false
	return bool(saves.call("codex_known", kind, entry_id))

func _codex_section(parent: VBoxContainer, title_text: String) -> void:
	var lbl := Label.new()
	lbl.text = title_text
	lbl.add_theme_font_size_override("font_size", 19)
	lbl.add_theme_color_override("font_color", Color(0.85, 0.72, 0.45))
	parent.add_child(lbl)
	var sep := HSeparator.new()
	parent.add_child(sep)

func _codex_entry(parent: VBoxContainer, display_name: String, blurb: String,
		icon: Texture2D, known: bool, meta_line: String = "") -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)

	var slot := PanelContainer.new()
	slot.custom_minimum_size = Vector2(56, 56)
	var slot_style := StyleBoxFlat.new()
	slot_style.bg_color = Color(0.06, 0.05, 0.08, 0.85)
	slot_style.border_color = Color(0.42, 0.34, 0.22, 0.9)
	slot_style.set_border_width_all(1)
	slot.add_theme_stylebox_override("panel", slot_style)
	if icon != null:
		var tr := TextureRect.new()
		tr.texture = icon
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		if not known:
			# 剪影：没解锁时不显示真图（保留"要亲自遭遇"的收集感），
			# 但给一个深色轮廓，比光秃秃的问号更像"图鉴里有这么个东西"。
			tr.modulate = Color(0.09, 0.08, 0.12, 0.92)
		slot.add_child(tr)
	else:
		var q := Label.new()
		q.text = "?"
		q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		q.add_theme_font_size_override("font_size", 30)
		q.add_theme_color_override("font_color", Color(0.4, 0.36, 0.42))
		slot.add_child(q)
	row.add_child(slot)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.add_theme_constant_override("separation", 2)
	row.add_child(info)

	var name_label := Label.new()
	name_label.text = display_name if known else "???"
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color",
		Color(0.96, 0.9, 0.8) if known else Color(0.52, 0.49, 0.55))
	info.add_child(name_label)

	var desc := Label.new()
	desc.text = blurb if known else "尚未遭遇"
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 13)
	desc.add_theme_color_override("font_color",
		Color(0.76, 0.73, 0.68) if known else Color(0.4, 0.38, 0.43))
	info.add_child(desc)

	if known and meta_line != "":
		var meta := Label.new()
		meta.text = meta_line
		meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		meta.add_theme_font_size_override("font_size", 12)
		meta.add_theme_color_override("font_color", Color(0.62, 0.55, 0.38))
		info.add_child(meta)

func _first_frame(tex: Texture2D, cell: int) -> Texture2D:
	## 精灵表是一整条横带，图鉴里只要第一格。
	if tex == null:
		return null
	var at := AtlasTexture.new()
	at.atlas = tex
	var w := minf(float(cell), float(tex.get_width()))
	var h := minf(float(cell), float(tex.get_height()))
	at.region = Rect2(0, 0, w, h)
	return at

func _style_button(btn: Button) -> void:
	var normal := TextureManager.instance.get_ui_texture("btn_normal")
	var hover := TextureManager.instance.get_ui_texture("btn_hover")
	var pressed := TextureManager.instance.get_ui_texture("btn_pressed")
	if normal and hover:
		# 9 宫格边距：btn_normal 是 192x64 的横向花纹带，两端各有一颗红宝石。
		# 不设 texture_margin 的话整张图会被拉扁铺满按钮——按钮越宽，
		# 两端的宝石被推得越远、中间拉成一条空带，读起来就像"没有贴图"。
		const BTN_MARGIN_X := 28.0
		const BTN_MARGIN_Y := 14.0
		var normal_style := StyleBoxTexture.new()
		normal_style.texture = normal
		normal_style.texture_margin_left = BTN_MARGIN_X
		normal_style.texture_margin_right = BTN_MARGIN_X
		normal_style.texture_margin_top = BTN_MARGIN_Y
		normal_style.texture_margin_bottom = BTN_MARGIN_Y
		var hover_style := StyleBoxTexture.new()
		hover_style.texture = hover
		hover_style.texture_margin_left = BTN_MARGIN_X
		hover_style.texture_margin_right = BTN_MARGIN_X
		hover_style.texture_margin_top = BTN_MARGIN_Y
		hover_style.texture_margin_bottom = BTN_MARGIN_Y
		var pressed_style := StyleBoxTexture.new()
		pressed_style.texture = pressed if pressed else hover
		pressed_style.texture_margin_left = BTN_MARGIN_X
		pressed_style.texture_margin_right = BTN_MARGIN_X
		pressed_style.texture_margin_top = BTN_MARGIN_Y
		pressed_style.texture_margin_bottom = BTN_MARGIN_Y
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
	# 模态已持有暂停时，ESC 不能在它背后再打开菜单。
	for holder in PauseController.holders():
		if holder != self:
			return
	visible = true
	PauseController.acquire(self)
	_disarm_abandon()
	# 淡入 + 微放大统一交给 UiFx；原来的 modulate 补间会和它抢同一个属性
	UiFx.pop_in(panel, 0.2, 0.96)

func _resume() -> void:
	_disarm_abandon()
	if settings_panel != null:
		settings_panel.visible = false
	if codex_panel != null:
		codex_panel.visible = false
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
