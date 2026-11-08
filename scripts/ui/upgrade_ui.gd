extends CanvasLayer
## 升级选择界面
##
## 三选一 + 重抽 + 跳过：
## - 每局 3 次免费重抽，之后每次 10 银币 → 让"这手牌太烂"有出口，
##   同时把随机性变成一种可以花的资源，而不是纯粹的运气。
## - 跳过换 15 银币 → 给"我这把不需要任何一张"的情况一个不亏的选择。

var player: Node = null
var weapon_manager: Node = null

## 剩余免费重抽次数（每局重置）
var rerolls_left: int = GameConfig.REROLL_FREE_COUNT
## 当前展示的 3 个选项（重抽/测试需要读它）
var current_options: Array = []

var _reroll_button: Button = null
var _skip_button: Button = null
var _hint_label: Label = null

signal upgrade_selected

@onready var panel: PanelContainer = $CenterContainer/PanelContainer
@onready var options_container: HBoxContainer = $CenterContainer/PanelContainer/VBoxContainer/OptionsContainer
@onready var title_label: Label = $CenterContainer/PanelContainer/VBoxContainer/TitleLabel

func _ready() -> void:
	visible = false
	# 界面会在 get_tree().paused = true 时使用，必须能继续收输入
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_panel_style()
	rerolls_left = GameConfig.REROLL_FREE_COUNT
	_build_footer()

func _setup_panel_style() -> void:
	var panel_texture := TextureManager.instance.get_ui_texture("stats_panel")
	if panel_texture:
		var style := StyleBoxTexture.new()
		style.texture = panel_texture
		panel.add_theme_stylebox_override("panel", style)

func show_upgrade(player_node: Node, weapon_mgr: Node = null) -> void:
	player = player_node
	weapon_manager = weapon_mgr
	visible = true
	get_tree().paused = true

	_render_options()
	_refresh_footer()

	panel.modulate = Color(1, 1, 1, 0)
	panel.scale = Vector2(0.8, 0.8)
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(panel, "modulate:a", 1.0, 0.2)
	tween.parallel().tween_property(panel, "scale", Vector2.ONE, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func _render_options() -> void:
	## 抽 3 个选项并重建按钮。
	## 用 remove_child + queue_free 而不是只 queue_free：后者要等到帧末才真的移除，
	## 重建时会和新按钮同时存在于容器里（重抽时最明显——6 张卡挤在一起）。
	var available_options := _get_available_options()
	if available_options.is_empty():
		available_options = _get_basic_rewards()

	available_options.shuffle()
	current_options = available_options.slice(0, mini(3, available_options.size()))

	for child in options_container.get_children():
		options_container.remove_child(child)
		child.queue_free()
	for option in current_options:
		options_container.add_child(_create_option_button(_decorate_option(option)))

# ==================== 等级信息（卡片上的 Lv 提示） ====================

func _decorate_option(option: Dictionary) -> Dictionary:
	## 给卡片补"这到底是新拿还是升级、升到几级"。
	## 之前三张卡只有名字 + 一句话描述，玩家选完都不知道自己把武器升到 Lv.几了。
	var opt: Dictionary = option.duplicate(true)
	var opt_type := String(opt.get("type", "stat"))
	var opt_id := String(opt.get("id", ""))

	match opt_type:
		"weapon":
			var w = _find_owned_weapon(opt_id)
			if w == null:
				opt["badge"] = "NEW"
				opt["badge_color"] = Color(0.42, 0.95, 0.58)
				opt["level_text"] = "新武器 · Lv.1"
			else:
				var cur: int = int(w.current_level)
				var max_lv: int = maxi(int(w.max_level), cur + 1)
				opt["badge"] = "升级"
				opt["badge_color"] = Color(1.0, 0.82, 0.35)
				opt["level_text"] = "Lv.%d → Lv.%d" % [cur, mini(cur + 1, max_lv)]
				# 描述换成"这一级到底加了什么"，比原来的定位文案有用
				opt["desc"] = "伤害 %.1f → %.1f" % [
					w.base_damage * (1.0 + (cur - 1) * GameConfig.WEAPON_DAMAGE_PER_LEVEL),
					w.base_damage * (1.0 + cur * GameConfig.WEAPON_DAMAGE_PER_LEVEL),
				]
		"passive":
			var p = _find_owned_passive(opt_id)
			if p == null:
				opt["badge"] = "NEW"
				opt["badge_color"] = Color(0.42, 0.95, 0.58)
				opt["level_text"] = "新被动 · Lv.1"
			else:
				var cur: int = int(p.current_level)
				opt["badge"] = "升级"
				opt["badge_color"] = Color(1.0, 0.82, 0.35)
				opt["level_text"] = "Lv.%d → Lv.%d" % [cur, mini(cur + 1, 5)]
				opt["desc"] = _passive_value_text(opt_id,
					p.get_scaled_value_at(cur), p.get_scaled_value_at(cur + 1))
		"stat":
			opt["badge"] = "属性"
			opt["badge_color"] = Color(0.6, 0.76, 1.0)
			opt["level_text"] = _stat_preview(opt_id)
		_:
			opt["badge"] = ""
			opt["level_text"] = ""
	return opt

func _find_owned_weapon(weapon_id: String):
	if weapon_manager == null or not ("weapons" in weapon_manager):
		return null
	for w in weapon_manager.weapons:
		if String(w.weapon_id) == weapon_id:
			return w
	return null

func _find_owned_passive(passive_id: String):
	if player == null or not ("passive_items" in player):
		return null
	for p in player.passive_items:
		if String(p.item_id) == passive_id:
			return p
	return null

func _passive_value_text(passive_id: String, cur_value: float, next_value: float) -> String:
	## 被动数值量级不统一（有的是倍率 1.3、有的是 0.08、有的是 30 秒），
	## 所以按 id 决定单位，别用一个通式硬套
	match passive_id:
		"shield":
			return "冷却 %.0fs → %.0fs" % [cur_value, next_value]
		"lightning_shield":
			return "反击 %.0f → %.0f 伤害" % [cur_value, next_value]
		"magnet":
			return "吸附范围 +%.0f%% → +%.0f%%" % [(cur_value - 1.0) * 100.0, (next_value - 1.0) * 100.0]
		_:
			return "效果 %.0f%% → %.0f%%" % [cur_value * 100.0, next_value * 100.0]

func _stat_preview(stat_id: String) -> String:
	## 属性卡显示"现在 → 选完"，让加成幅度可比较
	if player == null:
		return ""
	match stat_id:
		"damage":
			return "攻击 ×%.2f → ×%.2f" % [player.damage_multiplier,
				player.damage_multiplier + GameConfig.UPGRADE_DAMAGE_MULT]
		"speed":
			return "移速 ×%.2f → ×%.2f" % [player.speed_multiplier,
				player.speed_multiplier + GameConfig.UPGRADE_SPEED_MULT]
		"shoot_speed":
			return "射速 ×%.2f → ×%.2f" % [player.shoot_speed_multiplier,
				player.shoot_speed_multiplier + GameConfig.UPGRADE_SHOOT_SPEED_MULT]
		"max_hp":
			return "生命 %.0f → %.0f" % [player.max_hp, player.max_hp + GameConfig.UPGRADE_MAX_HP]
		"armor":
			return "护甲 %.0f → %.0f" % [player.armor, player.armor + GameConfig.UPGRADE_ARMOR]
		"pickup_range":
			return "拾取 %.0f → %.0f" % [player.pickup_range_bonus,
				player.pickup_range_bonus + GameConfig.UPGRADE_PICKUP_RANGE]
	return ""

# ==================== 重抽 / 跳过 ====================

func _build_footer() -> void:
	var vbox := $CenterContainer/PanelContainer/VBoxContainer as VBoxContainer
	if vbox == null:
		return

	var footer := HBoxContainer.new()
	footer.name = "Footer"
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 16)

	_reroll_button = _make_footer_button("🔄 重抽", Color(0.55, 0.75, 1.0))
	_reroll_button.pressed.connect(_on_reroll)
	footer.add_child(_reroll_button)

	_skip_button = _make_footer_button("⏭ 跳过", Color(1.0, 0.85, 0.45))
	_skip_button.pressed.connect(_on_skip)
	footer.add_child(_skip_button)

	vbox.add_child(footer)

	_hint_label = Label.new()
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.add_theme_color_override("font_color", Color(0.66, 0.66, 0.72))
	_hint_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(_hint_label)

func _make_footer_button(text: String, accent: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(150, 34)
	btn.focus_mode = Control.FOCUS_NONE

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.11, 0.10, 0.14, 1.0)
	normal.border_color = Color(accent.r, accent.g, accent.b, 0.55)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(6)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.18, 0.16, 0.22, 1.0)
	hover.border_color = accent

	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.09, 0.09, 0.11, 1.0)
	disabled.border_color = Color(0.25, 0.25, 0.28, 1.0)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_color_override("font_color", accent)
	btn.add_theme_color_override("font_disabled_color", Color(0.42, 0.42, 0.46))
	return btn

func reroll_cost() -> int:
	## 还有免费次数就是 0，否则返回银币价格
	return 0 if rerolls_left > 0 else GameConfig.REROLL_SILVER_COST

func can_reroll() -> bool:
	if rerolls_left > 0:
		return true
	return player != null and int(player.silver) >= GameConfig.REROLL_SILVER_COST

func _refresh_footer() -> void:
	if _reroll_button == null:
		return
	var cost := reroll_cost()
	if cost == 0:
		_reroll_button.text = "🔄 重抽 (%d)" % rerolls_left
	else:
		_reroll_button.text = "🔄 重抽 (💰%d)" % cost
	_reroll_button.disabled = not can_reroll()
	_skip_button.text = "⏭ 跳过 (+💰%d)" % GameConfig.SKIP_SILVER_REWARD
	_hint_label.text = "R 重抽　Tab 跳过　　免费重抽剩 %d 次" % rerolls_left

func _on_reroll() -> bool:
	## 返回是否真的重抽了（测试要用）
	if not can_reroll():
		return false
	if rerolls_left > 0:
		rerolls_left -= 1
	else:
		if player == null or not player.spend_silver(GameConfig.REROLL_SILVER_COST):
			return false
	_render_options()
	_refresh_footer()
	return true

func _on_skip() -> void:
	if player != null and player.has_method("add_silver"):
		player.add_silver(GameConfig.SKIP_SILVER_REWARD)
	_close_and_emit()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_R:
				get_viewport().set_input_as_handled()
				_on_reroll()
			KEY_TAB:
				get_viewport().set_input_as_handled()
				_on_skip()

func _close_and_emit() -> void:
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(panel, "modulate:a", 0.0, 0.15)
	tween.tween_callback(func():
		visible = false
		get_tree().paused = false
		upgrade_selected.emit()
	)

func _get_available_options() -> Array:
	## 获取可用的升级选项
	var available: Array = []
	
	# 添加属性升级（总是可用）
	available.append_array(ItemCatalog.STATS.duplicate())
	
	# 武器槽位信息
	var owned_ids: Array = []
	if weapon_manager != null and "weapons" in weapon_manager:
		for w in weapon_manager.weapons:
			owned_ids.append(w.weapon_id)
	var slots_full: bool = owned_ids.size() >= GameConfig.MAX_WEAPON_SLOTS

	# 添加武器选项（排除已进化的、以及已满级的）
	for weapon_opt in ItemCatalog.WEAPONS:
		if _is_weapon_evolved(weapon_opt["id"]):
			continue
		# 槽位已满时不再提供"新武器"，只保留已拥有武器的升级项，
		# 否则玩家可以无限扩充武器栏，DPS 线性叠加到无双。
		var owned: bool = weapon_opt["id"] in owned_ids
		if slots_full and not owned:
			continue
		# 满级武器再出现就是废卡（卡面会写成 Lv.5 → Lv.5），直接过滤
		var owned_weapon = _find_owned_weapon(weapon_opt["id"])
		if owned_weapon != null and owned_weapon.is_max_level():
			continue
		available.append(weapon_opt)
	
	# 添加被动道具选项（排除已满级的）
	for passive_opt in ItemCatalog.PASSIVES:
		if not _is_passive_maxed(passive_opt["id"]):
			available.append(passive_opt)
	
	return available

func _is_weapon_evolved(weapon_id: String) -> bool:
	## 检查武器是否已进化
	if weapon_manager == null:
		return false
	return weapon_manager.is_weapon_evolved(weapon_id)

func _is_passive_maxed(passive_id: String) -> bool:
	## 检查被动道具是否已满级
	if player == null or not player.has_method("get_owned_passive_items"):
		return false

	for item in player.passive_items:
		if item.item_id == passive_id:
			# 使用 is_max_level() 方法检查是否满级
			return item.is_max_level()
	return false

func _get_basic_rewards() -> Array:
	## 当所有武器和被动都满级/进化后，提供基础奖励
	return [
		{"id": "heal", "name": "生命恢复", "desc": "恢复30%最大生命", "icon": "❤️", "type": "basic"},
		{"id": "gold", "name": "金币奖励", "desc": "获得100血晶", "icon": "💰", "type": "basic"},
		{"id": "damage_boost", "name": "伤害提升", "desc": "攻击力+10%（本局）", "icon": "⚔️", "type": "basic"},
	]

func _create_option_button(option: Dictionary) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(204, 190)
	btn.pressed.connect(func(): _on_option_selected(option))
	
	# 创建垂直布局容器
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 4)

	# 角标：NEW / 升级 / 属性 —— 一眼分清"新拿一件"还是"升一级"
	var badge_text := String(option.get("badge", ""))
	if badge_text != "":
		var badge := Label.new()
		badge.text = " %s " % badge_text
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		badge.add_theme_font_size_override("font_size", 11)
		var badge_color: Color = option.get("badge_color", Color(0.8, 0.8, 0.8))
		badge.add_theme_color_override("font_color", badge_color)
		var badge_style := StyleBoxFlat.new()
		badge_style.bg_color = Color(badge_color.r, badge_color.g, badge_color.b, 0.18)
		badge_style.border_color = Color(badge_color.r, badge_color.g, badge_color.b, 0.65)
		badge_style.set_border_width_all(1)
		badge_style.set_corner_radius_all(3)
		badge_style.content_margin_left = 6
		badge_style.content_margin_right = 6
		badge_style.content_margin_top = 1
		badge_style.content_margin_bottom = 1
		badge.add_theme_stylebox_override("normal", badge_style)
		vbox.add_child(badge)

	# 添加图标纹理
	var icon_texture := _get_option_icon(option)
	if icon_texture:
		var icon := TextureRect.new()
		icon.texture = icon_texture
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(48, 48)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		vbox.add_child(icon)
	else:
		# 使用emoji作为回退
		var icon_label := Label.new()
		icon_label.text = option.get("icon", "❓")
		icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var icon_label_settings := LabelSettings.new()
		icon_label_settings.font_size = 32
		icon_label.label_settings = icon_label_settings
		vbox.add_child(icon_label)

	# 添加名称
	var name_label := Label.new()
	name_label.text = option["name"]
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	name_label.custom_minimum_size.x = 140  # 增加宽度
	var name_label_settings := LabelSettings.new()
	name_label_settings.font_size = 16
	name_label_settings.font_color = Color(1, 0.9, 0.7, 1)
	name_label.label_settings = name_label_settings
	vbox.add_child(name_label)

	# 等级行：Lv.2 → Lv.3 / 新武器 · Lv.1 / 攻击 ×1.20 → ×1.40
	var level_text := String(option.get("level_text", ""))
	if level_text != "":
		var level_label := Label.new()
		level_label.text = level_text
		level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		level_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		level_label.custom_minimum_size.x = 150
		var level_settings := LabelSettings.new()
		level_settings.font_size = 13
		level_settings.font_color = option.get("badge_color", Color(0.85, 0.9, 1.0, 1.0))
		level_label.label_settings = level_settings
		vbox.add_child(level_label)

	# 添加描述
	var desc_label := Label.new()
	desc_label.text = option["desc"]
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	desc_label.custom_minimum_size.x = 140  # 增加宽度
	var desc_label_settings := LabelSettings.new()
	desc_label_settings.font_size = 12
	desc_label_settings.font_color = Color(0.8, 0.8, 0.8, 1)
	desc_label.label_settings = desc_label_settings
	vbox.add_child(desc_label)
	
	btn.add_child(vbox)
	
	# 设置按钮样式
	var card_texture := TextureManager.instance.get_ui_texture("upgrade_card")
	var hover_texture := TextureManager.instance.get_ui_texture("upgrade_card_hover")
	if card_texture:
		var normal_style := StyleBoxTexture.new()
		normal_style.texture = card_texture
		
		var hover_style := StyleBoxTexture.new()
		hover_style.texture = hover_texture if hover_texture else card_texture
		
		btn.add_theme_stylebox_override("normal", normal_style)
		btn.add_theme_stylebox_override("hover", hover_style)
		btn.add_theme_stylebox_override("pressed", hover_style)
	
	return btn

func _get_option_icon(option: Dictionary) -> Texture2D:
	## 获取选项对应的图标纹理
	var option_type: String = option.get("type", "stat")
	var option_id: String = option.get("id", "")
	
	match option_type:
		"weapon":
			match option_id:
				"shotgun":
					return TextureManager.instance.get_weapon_icon("shotgun")
				"magic_book":
					return TextureManager.instance.get_weapon_icon("magic_book")
				"throwing_knife":
					return TextureManager.instance.get_weapon_icon("knife")
				"poison_cloud":
					return TextureManager.instance.get_weapon_icon("poison")
				"lightning_chain":
					return TextureManager.instance.get_weapon_icon("lightning")
				"crossbow":
					return TextureManager.instance.get_weapon_icon("crossbow")
				"holy_wand":
					return TextureManager.instance.get_weapon_icon("holy_wand")
		"passive":
			match option_id:
				"magnet":
					return TextureManager.instance.get_weapon_icon("magnet")
				"shield":
					return TextureManager.instance.get_weapon_icon("shield")
				"regeneration":
					return TextureManager.instance.get_weapon_icon("regen")
				"greed_ring":
					return TextureManager.instance.get_weapon_icon("greed")
				"berserker_blood":
					return TextureManager.instance.get_weapon_icon("berserker")
				"frozen_heart":
					return TextureManager.instance.get_weapon_icon("frozen")
				"lightning_shield":
					return TextureManager.instance.get_weapon_icon("lightning_shield")
				"shadow_cloak":
					return TextureManager.instance.get_weapon_icon("shadow")
				"vampiric_fang":
					return TextureManager.instance.get_weapon_icon("vampiric")
				"swift_boots":
					return TextureManager.instance.get_weapon_icon("swift_boots")
				"lucky_clover":
					return TextureManager.instance.get_weapon_icon("clover")
		"stat", "basic":
			match option_id:
				"damage", "damage_boost":
					return TextureManager.instance.get_weapon_icon("berserker")
				"speed":
					return TextureManager.instance.get_weapon_icon("shadow")
				"shoot_speed":
					return TextureManager.instance.get_weapon_icon("knife")
				"max_hp", "heal":
					return TextureManager.instance.get_weapon_icon("heal_potion")
				"armor":
					return TextureManager.instance.get_weapon_icon("shield")
				"pickup_range":
					return TextureManager.instance.get_weapon_icon("magnet")
				"gold":
					return TextureManager.instance.get_weapon_icon("blood_crystal")
	
	return null

func _on_option_selected(option: Dictionary) -> void:
	var option_type: String = option.get("type", "stat")
	if option_type == "stat":
		if player != null and player.has_method("apply_upgrade"):
			player.apply_upgrade(option["id"])
	elif option_type == "weapon":
		if weapon_manager != null and weapon_manager.has_method("add_weapon"):
			var weapon_data = ItemCatalog.create_weapon(option["id"])
			if weapon_data:
				weapon_manager.add_weapon(weapon_data)
	elif option_type == "passive":
		if player != null and player.has_method("add_passive_item"):
			var passive_data = ItemCatalog.create_passive(option["id"])
			if passive_data:
				player.add_passive_item(passive_data)
	elif option_type == "basic":
		_apply_basic_reward(option["id"])
	_close_and_emit()

func _apply_basic_reward(reward_id: String) -> void:
	## 应用基础奖励
	match reward_id:
		"heal":
			if player != null and player.has_method("heal"):
				var heal_amount: float = player.max_hp * 0.3
				player.heal(heal_amount)
				print("❤️ 恢复 %.0f 生命" % heal_amount)
		"gold":
			var save_mgr := get_node_or_null("/root/SaveManager")
			if save_mgr:
				save_mgr.add_blood_crystals(100)
				print("💰 获得 100 血晶")
		"damage_boost":
			if player != null:
				player.damage_multiplier += 0.1
				print("⚔️ 攻击力 +10%")
