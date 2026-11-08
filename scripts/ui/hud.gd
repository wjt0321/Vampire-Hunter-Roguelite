extends CanvasLayer
## 游戏内 HUD
## 显示生命值、经验条、波次信息、击杀数、游戏时间、房间编号

@onready var hp_bar: ProgressBar = $MarginContainer/VBoxContainer/TopBar/HpBar
@onready var hp_label: Label = $MarginContainer/VBoxContainer/TopBar/HpBar/HpLabel
@onready var xp_bar: ProgressBar = $MarginContainer/VBoxContainer/BottomBar/XpBar
@onready var level_label: Label = $MarginContainer/VBoxContainer/BottomBar/LevelLabel
@onready var wave_label: Label = $MarginContainer/VBoxContainer/TopBar/WaveLabel
@onready var kills_label: Label = $MarginContainer/VBoxContainer/TopBar/KillsLabel
@onready var wave_banner: Label = $WaveBanner
@onready var time_label: Label = $MarginContainer/VBoxContainer/TopBar/TimeLabel
@onready var room_label: Label = $MarginContainer/VBoxContainer/TopBar/RoomLabel

var silver_label: Label = null
var evolution_label: Label = null

# === 局内 Build 面板（武器/被动等级一览） ===
var player_ref: Node = null
var weapon_manager_ref: Node = null
var _build_panel: PanelContainer = null
var _build_box: VBoxContainer = null
var _build_signature: String = ""
var _build_refresh_timer: float = 0.0
## 深渊契约状态文案（空 = 本层无契约）
var _pact_text: String = ""

# === 护盾状态条 ===
var _shield_row: HBoxContainer = null
var _shield_text: Label = null
var _shield_bar: ProgressBar = null
var _shield_pulse: Tween = null

var game_time: float = 0.0
var _low_hp_tween: Tween = null
var _evo_pulse: Tween = null

func _ready() -> void:
	wave_banner.visible = false
	_setup_bar_textures()
	_create_silver_label()
	_create_evolution_label()
	_create_shield_indicator()
	_create_build_panel()

func bind_run(player_node: Node, weapon_mgr: Node) -> void:
	## 由 main 在开局时注入引用：HUD 只在 _process 里轮询状态，
	## 不依赖"每次升级/加武器都记得发信号"——少一处漏连就少一个隐形 bug。
	player_ref = player_node
	weapon_manager_ref = weapon_mgr
	_build_signature = ""
	_refresh_build(true)

# ==================== 护盾状态 ====================

func _create_shield_indicator() -> void:
	## 护盾状态必须显式可见：玩家拿不到"我身上到底有没有盾"的信息时，
	## 这个被动等于不存在。
	var vbox := $MarginContainer/VBoxContainer as VBoxContainer
	if vbox == null:
		return
	_shield_row = HBoxContainer.new()
	_shield_row.name = "ShieldRow"
	_shield_row.visible = false
	_shield_row.add_theme_constant_override("separation", 6)
	_shield_row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_shield_text = Label.new()
	_shield_text.add_theme_font_size_override("font_size", 12)
	_shield_row.add_child(_shield_text)

	_shield_bar = ProgressBar.new()
	_shield_bar.custom_minimum_size = Vector2(88, 8)
	_shield_bar.show_percentage = false
	_shield_bar.max_value = 1.0
	_shield_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_shield_row.add_child(_shield_bar)

	vbox.add_child(_shield_row)
	# 紧跟血条下方（TopBar 是 VBox 的第 0 个孩子）
	vbox.move_child(_shield_row, 1)

func _update_shield_indicator() -> void:
	if _shield_row == null:
		return
	if player_ref == null or not is_instance_valid(player_ref) \
			or not player_ref.has_method("get_shield_status"):
		_shield_row.visible = false
		return
	var st: Dictionary = player_ref.get_shield_status()
	if not bool(st.get("has_item", false)):
		_shield_row.visible = false
		_stop_shield_pulse()
		return
	_shield_row.visible = true
	if bool(st.get("active", false)):
		_shield_text.text = "🛡 护盾 已激活"
		_shield_text.add_theme_color_override("font_color", Color(0.55, 0.9, 1.0))
		_shield_bar.value = 1.0
		_shield_bar.modulate = Color(0.55, 0.9, 1.0)
		_start_shield_pulse()
	else:
		_shield_text.text = "🛡 护盾充能 %.0fs" % float(st.get("remain", 0.0))
		_shield_text.add_theme_color_override("font_color", Color(0.55, 0.62, 0.7))
		_shield_bar.value = float(st.get("progress", 0.0))
		_shield_bar.modulate = Color(0.45, 0.6, 0.75)
		_stop_shield_pulse()

func _start_shield_pulse() -> void:
	if _shield_pulse != null and _shield_pulse.is_valid():
		return
	_shield_pulse = create_tween().set_loops()
	_shield_pulse.tween_property(_shield_text, "modulate:a", 0.55, 0.5)
	_shield_pulse.tween_property(_shield_text, "modulate:a", 1.0, 0.5)

func _stop_shield_pulse() -> void:
	if _shield_pulse != null and _shield_pulse.is_valid():
		_shield_pulse.kill()
	_shield_pulse = null
	if _shield_text:
		_shield_text.modulate = Color.WHITE

# ==================== 武器 / 被动 等级面板 ====================

func _create_build_panel() -> void:
	var panel := PanelContainer.new()
	panel.name = "BuildPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.08, 0.66)
	style.border_color = Color(0.32, 0.34, 0.44, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(168, 0)
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	panel.position = Vector2(14, 92)
	panel.visible = false
	_build_panel = panel

	_build_box = VBoxContainer.new()
	_build_box.add_theme_constant_override("separation", 2)
	_build_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_build_box)

func _refresh_build(force: bool = false) -> void:
	if _build_panel == null or _build_box == null:
		return
	if player_ref == null or weapon_manager_ref == null:
		return
	var sig := _build_signature_of()
	if not force and sig == _build_signature:
		return
	_build_signature = sig
	for child in _build_box.get_children():
		# 先 remove 再 free：只 queue_free 的话旧行要到帧末才消失，
		# 面板会在刷新那一帧里叠出两套内容（重抽界面踩过同一个坑）。
		_build_box.remove_child(child)
		child.queue_free()

	var weapons: Array = weapon_manager_ref.weapons
	_build_panel.visible = true
	# 契约状态顶在最上面：它是本层最重要的"场上条件"，
	# 埋在下面玩家会在打完半层之后才发现自己血上限少了 20%
	if _pact_text != "":
		_add_build_pact_row(_pact_text)
	_add_build_header("武器 %d/%d" % [weapons.size(), GameConfig.MAX_WEAPON_SLOTS])
	if weapons.is_empty():
		_add_build_hint("（空手）")
	for w in weapons:
		_add_build_row(String(w.icon_emoji), String(w.weapon_name),
			int(w.current_level), int(w.max_level))

	var passives: Array = player_ref.passive_items
	if not passives.is_empty():
		_add_build_header("被动")
		for p in passives:
			# 满级的被动用金色标出来：玩家要能一眼看出"这条已经喂到顶了"
			var max_lv: int = 0
			if p.has_method("is_max_level") and p.is_max_level():
				max_lv = int(p.current_level)
			_add_build_row(String(p.icon_emoji), String(p.item_name),
				int(p.current_level), max_lv)

func _build_signature_of() -> String:
	## 轮询用：只有等级/数量变化才重建控件，避免每帧 new 一堆 Label
	var parts: PackedStringArray = []
	parts.append("pact:%s" % _pact_text)
	for w in weapon_manager_ref.weapons:
		parts.append("%s:%d" % [String(w.weapon_id), int(w.current_level)])
	parts.append("|")
	for p in player_ref.passive_items:
		parts.append("%s:%d" % [String(p.item_id), int(p.current_level)])
	return ",".join(parts)

func _add_build_pact_row(text: String) -> void:
	var lbl := Label.new()
	lbl.text = "🩸 %s" % text
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
	_build_box.add_child(lbl)

func _add_build_header(text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.6, 0.65, 0.78))
	_build_box.add_child(lbl)

func _add_build_hint(text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.45, 0.45, 0.5))
	_build_box.add_child(lbl)

func _add_build_row(icon: String, item_name: String, level: int, max_level: int) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var icon_lbl := Label.new()
	icon_lbl.text = icon
	icon_lbl.add_theme_font_size_override("font_size", 12)
	row.add_child(icon_lbl)

	var name_lbl := Label.new()
	name_lbl.text = item_name
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.add_theme_color_override("font_color", Color(0.88, 0.88, 0.94))
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.clip_text = true
	row.add_child(name_lbl)

	var is_max: bool = max_level > 0 and level >= max_level
	var lv_lbl := Label.new()
	lv_lbl.text = "Lv.%d" % level
	lv_lbl.add_theme_font_size_override("font_size", 12)
	lv_lbl.add_theme_color_override("font_color",
		Color(1.0, 0.82, 0.35) if is_max else Color(0.55, 0.8, 1.0))
	row.add_child(lv_lbl)
	_build_box.add_child(row)

func _create_evolution_label() -> void:
	## 进化准备度：三态提示（无 / 还差被动 / 可开宝箱进化）
	## 之前进化是"击杀数 50 自动触发"，玩家根本不知道有这回事；
	## 现在条件变成事件后，必须把"差什么"明明白白写在屏幕上。
	var vbox := $MarginContainer/VBoxContainer as VBoxContainer
	if vbox == null:
		return
	evolution_label = Label.new()
	evolution_label.name = "EvolutionLabel"
	evolution_label.text = ""
	evolution_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	evolution_label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(evolution_label)

func update_evolution(state: String, text: String) -> void:
	if evolution_label == null:
		return
	if state == "none" or text == "":
		evolution_label.text = ""
		_stop_evo_pulse()
		return
	evolution_label.text = text
	if state == "ready":
		evolution_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.42))
		_start_evo_pulse()
	else:
		evolution_label.add_theme_color_override("font_color", Color(0.62, 0.62, 0.68))
		_stop_evo_pulse()

func _start_evo_pulse() -> void:
	if _evo_pulse != null and _evo_pulse.is_valid():
		return
	_evo_pulse = create_tween().set_loops()
	_evo_pulse.tween_property(evolution_label, "modulate:a", 0.55, 0.6)
	_evo_pulse.tween_property(evolution_label, "modulate:a", 1.0, 0.6)

func _stop_evo_pulse() -> void:
	if _evo_pulse != null and _evo_pulse.is_valid():
		_evo_pulse.kill()
	_evo_pulse = null
	if evolution_label:
		evolution_label.modulate = Color.WHITE

func show_evolution_banner(text: String) -> void:
	## 宝箱进化时的横幅
	wave_banner.text = "✨ 进化：%s" % text
	wave_banner.visible = true
	wave_banner.modulate = Color(1, 1, 1, 1)
	var tween := create_tween()
	tween.tween_interval(1.6)
	tween.tween_property(wave_banner, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func(): wave_banner.visible = false)

func _create_silver_label() -> void:
	## 银币计数放在击杀数旁边：代码建，避免为一个 Label 去改 hud.tscn
	var top_bar := $MarginContainer/VBoxContainer/TopBar as HBoxContainer
	if top_bar == null:
		return
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(spacer)
	silver_label = Label.new()
	silver_label.name = "SilverLabel"
	silver_label.text = "💰 0"
	silver_label.add_theme_color_override("font_color", Color(1.0, 0.87, 0.45))
	top_bar.add_child(silver_label)

func update_blood_pact(active: bool, text: String = "") -> void:
	## 契约状态（本层）。传空字符串即清除。
	var new_text: String = text if active else ""
	if new_text == _pact_text:
		return
	_pact_text = new_text
	_refresh_build(true)

func update_silver(amount: int) -> void:	if silver_label:
		silver_label.text = "💰 %d" % amount

func _process(delta: float) -> void:
	game_time += delta
	var minutes := int(game_time) / 60
	var seconds := int(game_time) % 60
	time_label.text = "⏱ %02d:%02d" % [minutes, seconds]
	_update_shield_indicator()
	_build_refresh_timer += delta
	if _build_refresh_timer >= 0.25:
		_build_refresh_timer = 0.0
		_refresh_build()

func update_hp(current: float, maximum: float) -> void:
	hp_bar.max_value = maximum
	hp_bar.value = current
	hp_label.text = "%d / %d" % [int(current), int(maximum)]
	_update_low_hp_warning(current, maximum)

func _update_low_hp_warning(current: float, maximum: float) -> void:
	var ratio := current / maximum if maximum > 0 else 1.0
	if ratio <= 0.25:
		hp_bar.modulate = Color(1.5, 0.3, 0.3, 1.0)
		if _low_hp_tween == null or not _low_hp_tween.is_valid():
			_low_hp_tween = create_tween().set_loops()
			_low_hp_tween.tween_property(hp_bar, "modulate", Color(2.0, 0.2, 0.2, 1.0), 0.4)
			_low_hp_tween.tween_property(hp_bar, "modulate", Color(1.2, 0.3, 0.3, 1.0), 0.4)
	else:
		hp_bar.modulate = Color.WHITE
		if _low_hp_tween and _low_hp_tween.is_valid():
			_low_hp_tween.kill()
			_low_hp_tween = null

func update_xp(current_xp: int, xp_needed: int, level: int) -> void:
	xp_bar.max_value = xp_needed
	xp_bar.value = current_xp
	level_label.text = "Lv.%d" % level

func update_wave(wave_number: int) -> void:
	wave_label.text = "Wave %d" % wave_number
	_show_wave_banner(wave_number)

func update_kills(total_kills: int) -> void:
	kills_label.text = "击杀: %d" % total_kills

func update_room(room_number: int) -> void:
	room_label.text = "房间 %d" % room_number

func update_dungeon(floor_index: int, room_in_floor: int, rooms_per_floor: int, floor_name: String) -> void:
	## 地下城层进度：第N层 · 层名 · X/Y
	var shown: int = clampi(room_in_floor, 1, maxi(rooms_per_floor, 1))
	room_label.text = "第%d层 %s  %d/%d" % [floor_index, floor_name, shown, rooms_per_floor]

func _show_wave_banner(wave_number: int) -> void:
	wave_banner.text = "=== WAVE %d ===" % wave_number
	wave_banner.visible = true
	wave_banner.modulate = Color(1, 1, 1, 1)
	var tween := create_tween()
	tween.tween_interval(1.5)
	tween.tween_property(wave_banner, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func(): wave_banner.visible = false)

func _setup_bar_textures() -> void:
	## 设置血条和经验条的纹理
	var hp_fill_texture := TextureManager.instance.get_ui_texture("hp_bar_fill")
	var hp_bg_texture := TextureManager.instance.get_ui_texture("hp_bar_bg")
	var xp_fill_texture := TextureManager.instance.get_ui_texture("xp_bar_fill")
	var xp_bg_texture := TextureManager.instance.get_ui_texture("xp_bar_bg")
	
	if hp_fill_texture:
		var hp_style := StyleBoxTexture.new()
		hp_style.texture = hp_fill_texture
		hp_bar.add_theme_stylebox_override("fill", hp_style)
	
	if hp_bg_texture:
		var hp_bg_style := StyleBoxTexture.new()
		hp_bg_style.texture = hp_bg_texture
		hp_bar.add_theme_stylebox_override("background", hp_bg_style)
	
	if xp_fill_texture:
		var xp_style := StyleBoxTexture.new()
		xp_style.texture = xp_fill_texture
		xp_bar.add_theme_stylebox_override("fill", xp_style)
	
	if xp_bg_texture:
		var xp_bg_style := StyleBoxTexture.new()
		xp_bg_style.texture = xp_bg_texture
		xp_bar.add_theme_stylebox_override("background", xp_bg_style)
