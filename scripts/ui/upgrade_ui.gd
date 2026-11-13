extends CanvasLayer
## 升级选择界面
##
## 三选一 + 重抽 + 跳过 + 放逐：
## - 每局 3 次免费重抽，之后每次 10 银币 → 让"这手牌太烂"有出口，
##   同时把随机性变成一种可以花的资源，而不是纯粹的运气。
## - 跳过换 15 银币 → 给"我这把不需要任何一张"的情况一个不亏的选择。
## - 每局 3 次放逐 → 把某张卡从**本局**选池永久移除。重抽解决"这一手烂"，
##   放逐解决"这个池子里永远别再来"。二者不共享资源，见 GameConfig 的说明。

var player: Node = null
var weapon_manager: Node = null

## 剩余免费重抽次数（每局重置）
var rerolls_left: int = GameConfig.REROLL_FREE_COUNT
## 剩余放逐次数（每局重置）
var banish_left: int = GameConfig.BANISH_COUNT
## 本局已放逐的选项键（"type:id"）。只影响三选一池，商店仍可买到
var banished_keys: Array = []
## 放逐模式：此时点卡片 = 把它从池中移除，而不是选它
var banish_mode: bool = false
## 当前展示的 3 个选项（重抽/测试需要读它）
var current_options: Array = []
## 局内固定随机源。每日挑战由 main 注入（同一种子 → 同一手牌）；
## 普通局为空，继续走全局随机，行为不变。
var rng: RandomNumberGenerator = null

var _submitted: bool = false
var _close_tween: Tween = null

var _reroll_button: Button = null
var _skip_button: Button = null
var _banish_button: Button = null
var _hint_label: Label = null

signal upgrade_selected

@onready var panel: PanelContainer = $CenterContainer/PanelContainer
@onready var options_container: HBoxContainer = $CenterContainer/PanelContainer/VBoxContainer/OptionsContainer
@onready var title_label: Label = $CenterContainer/PanelContainer/VBoxContainer/TitleLabel

func _ready() -> void:
	visible = false
	# 必须压在所有演出层之上：楼层横幅是 layer 90，商店 95，祭坛 96。
	# 之前这里没设 layer（默认 1），换层横幅播放期间升级会看到三选一被横幅文字盖住。
	layer = 100
	# 界面会在 get_tree().paused = true 时使用，必须能继续收输入
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_panel_style()
	rerolls_left = GameConfig.REROLL_FREE_COUNT
	banish_left = GameConfig.BANISH_COUNT
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
	banish_mode = false
	_submitted = false
	if _close_tween != null:
		_close_tween.kill()
	PauseController.acquire(self)

	_draw_and_render_options()
	_refresh_footer()

	panel.modulate = Color(1, 1, 1, 0)
	panel.scale = Vector2(0.8, 0.8)
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(panel, "modulate:a", 1.0, 0.2)
	tween.parallel().tween_property(panel, "scale", Vector2.ONE, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func _draw_and_render_options() -> void:
	## 只有打开、重抽和实际放逐才消耗随机数。
	var available_options := _get_available_options()
	if available_options.is_empty():
		available_options = _available_basic_rewards()

	current_options = _shape_hand(draw_options(available_options))
	_render_options()

func _render_options() -> void:
	## 模式变化只重建当前手牌的显示。
	for child in options_container.get_children():
		options_container.remove_child(child)
		child.queue_free()
	for option in current_options:
		var decorated := _decorate_option(option)
		if banish_mode:
			# 放逐模式下把卡片信息整块换成"这张卡要被删掉"，
			# 避免玩家在 ban 模式下还以为点下去是选它
			decorated["badge"] = "放逐"
			decorated["badge_color"] = Color(1.0, 0.34, 0.34)
			decorated["level_text"] = "点这张卡从本局池移除"
			decorated["desc"] = "本局不会再出现"
		options_container.add_child(_create_option_button(decorated))

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
				# 卡片只写这一级真正变化的那一轴。
				var step_text := ""
				if w.has_method("describe_next_level"):
					step_text = String(w.describe_next_level())
				opt["desc"] = step_text if step_text != "" else String(opt.get("desc", ""))
		"fusion":
			opt["badge"] = "融合"
			opt["badge_color"] = Color(0.95, 0.55, 1.0)
			opt["level_text"] = "主武器留下，副武器离槽"
		"passive":
			var p = _find_owned_passive(opt_id)
			if p == null:
				opt["badge"] = "NEW"
				opt["badge_color"] = Color(0.42, 0.95, 0.58)
				opt["level_text"] = "新被动 · Lv.1"
				# 新拿到的只写"拿到手就是什么效果"。
				# 之前写 get_scaled_value_at(1) → get_scaled_value_at(2)，
				# 第一次见到这张卡的玩家看到"流血 25% → 33%"，读起来像"拿了立刻升一级"，
				# 而且一半信息在讲他还没做的决定。升级前后对比只留给"升级"分支。
				var fresh = ItemCatalog.create_passive(opt_id)
				if fresh != null:
					opt["desc"] = _passive_value_current(opt_id, fresh.get_scaled_value_at(1))
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
		"basic":
			# 满级后的补给卡。原本只写一句"攻击力+10%（本局）"，
			# 玩家既不知道自己现在多少、也不知道加完是多少——
			# 「攻击力提升没有具体数值，可以有体感提升」说的就是这个。
			opt["badge"] = "补给"
			opt["badge_color"] = Color(0.95, 0.72, 0.42)
			opt["level_text"] = _basic_preview(opt_id)
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

func _cap_passive_value(passive_id: String, value: float) -> float:
	## 被动预览必须和 player._apply_passive_effect() 用同一套上限。
	## 表在 GameConfig.cap_passive_value()：这里再抄一份 minf，
	## 以后改上限就会漏掉一边，卡面又开始承诺不存在的增益。
	return GameConfig.cap_passive_value(passive_id, value)

func _passive_value_current(passive_id: String, value: float) -> String:
	## 新被动只有"当前这一级的效果"，没有下一级对比。
	## 单位和 _passive_value_text 保持一致：同一张卡在两处读起来应该是同一种说法。
	value = _cap_passive_value(passive_id, value)
	match passive_id:
		"shield":
			return "每 %.0fs 生成一次护盾" % value
		"lightning_shield":
			return "受击反击 %.0f 伤害" % value
		"magnet":
			# 磁铁的 base_value 是"倍率"，实际加成 = 50px × 倍率。
			# 按 (倍率 - 1) 折算成百分比会在 Lv.1 写出 "+0%" ——
			# 而 Lv.1 其实已经给了 +50px，玩家会以为这件道具是空卡。
			return "拾取范围 +%.0f" % (GameConfig.MAGNET_BASE_RANGE * value)
		"blood_edge":
			return "命中时 %.0f%% 几率使敌人流血" % (value * 100.0)
		"frost_bind":
			return "命中时 %.0f%% 几率使敌人减速" % (value * 100.0)
		"blood_drain":
			return "造成伤害的 %.1f%% 转为生命" % (value * 100.0)
		"execution_mark":
			return "同一精英或 Boss 每层伤害 +%.0f%%" % (value * 100.0)
		"time_gear":
			return "弹丸放大到 %.0f%%，穿透 +1，飞行变慢" % (value * 100.0)
		"cold_blood":
			return "流血且霜缚时崩开 %.0f 伤害" % value
		"regeneration":
			return "每 5 秒恢复 %.0f%% 最大生命" % (value * 100.0)
		"greed_ring":
			return "经验获取 +%.0f%%" % (value * 100.0)
		"berserker_blood":
			return "低血时伤害 +%.0f%%" % (value * 100.0)
		"frozen_heart":
			return "命中 %.0f%% 几率冻结敌人" % (value * 100.0)
		"shadow_cloak":
			return "闪避几率 +%.0f%%" % (value * 100.0)
		"vampiric_fang":
			return "击杀 %.0f%% 几率回血" % (value * 100.0)
		"swift_boots":
			return "移动速度 +%.0f%%" % (value * 100.0)
		"lucky_clover":
			return "暴击几率 +%.0f%%" % (value * 100.0)
		_:
			return "效果 %.0f%%" % (value * 100.0)

func _passive_value_text(passive_id: String, cur_value: float, next_value: float) -> String:
	## 被动数值量级不统一（有的是倍率 1.3、有的是 0.08、有的是 30 秒），
	## 所以按 id 决定单位，别用一个通式硬套
	cur_value = _cap_passive_value(passive_id, cur_value)
	next_value = _cap_passive_value(passive_id, next_value)
	match passive_id:
		"shield":
			return "冷却 %.0fs → %.0fs" % [cur_value, next_value]
		"lightning_shield":
			return "反击 %.0f → %.0f 伤害" % [cur_value, next_value]
		"magnet":
			return "拾取范围 +%.0f → +%.0f" % [
				GameConfig.MAGNET_BASE_RANGE * cur_value, GameConfig.MAGNET_BASE_RANGE * next_value]
		"blood_edge":
			return "流血几率 %.0f%% → %.0f%%" % [cur_value * 100.0, next_value * 100.0]
		"frost_bind":
			return "减速几率 %.0f%% → %.0f%%" % [cur_value * 100.0, next_value * 100.0]
		"blood_drain":
			return "伤害转治疗 %.1f%% → %.1f%%" % [cur_value * 100.0, next_value * 100.0]
		"execution_mark":
			return "每层伤害 +%.0f%% → +%.0f%%" % [cur_value * 100.0, next_value * 100.0]
		"time_gear":
			return "弹丸 %.0f%% → %.0f%%" % [cur_value * 100.0, next_value * 100.0]
		"cold_blood":
			return "崩开 %.0f → %.0f" % [cur_value, next_value]
		"regeneration":
			return "每 5 秒回复 %.0f%% → %.0f%%" % [cur_value * 100.0, next_value * 100.0]
		"greed_ring":
			return "经验获取 +%.0f%% → +%.0f%%" % [cur_value * 100.0, next_value * 100.0]
		"berserker_blood":
			return "低血时伤害 +%.0f%% → +%.0f%%" % [cur_value * 100.0, next_value * 100.0]
		"frozen_heart":
			return "冻结几率 %.0f%% → %.0f%%" % [cur_value * 100.0, next_value * 100.0]
		"shadow_cloak":
			return "闪避几率 %.0f%% → %.0f%%" % [cur_value * 100.0, next_value * 100.0]
		"vampiric_fang":
			return "回血几率 %.0f%% → %.0f%%" % [cur_value * 100.0, next_value * 100.0]
		"swift_boots":
			return "移动速度 +%.0f%% → +%.0f%%" % [cur_value * 100.0, next_value * 100.0]
		"lucky_clover":
			return "暴击几率 +%.0f%% → +%.0f%%" % [cur_value * 100.0, next_value * 100.0]
		_:
			return "效果 %.0f%% → %.0f%%" % [cur_value * 100.0, next_value * 100.0]

func _stat_preview(stat_id: String) -> String:
	## 属性卡显示"现在 → 选完"，让加成幅度可比较
	if player == null:
		return ""
	var lv := "　" + _stat_level_text(stat_id)
	match stat_id:
		"damage":
			return "攻击 ×%.2f → ×%.2f%s" % [player.damage_multiplier,
				player.damage_multiplier + GameConfig.UPGRADE_DAMAGE_MULT, lv]
		"speed":
			return "移速 ×%.2f → ×%.2f%s" % [player.speed_multiplier,
				player.speed_multiplier + GameConfig.UPGRADE_SPEED_MULT, lv]
		"shoot_speed":
			return "射速 ×%.2f → ×%.2f%s" % [player.shoot_speed_multiplier,
				player.shoot_speed_multiplier + GameConfig.UPGRADE_SHOOT_SPEED_MULT, lv]
		"max_hp":
			return "生命 %.0f → %.0f%s" % [player.max_hp,
				player.max_hp + GameConfig.UPGRADE_MAX_HP, lv]
		"armor":
			return "护甲 %.0f → %.0f%s" % [player.armor,
				player.armor + GameConfig.UPGRADE_ARMOR, lv]
		"pickup_range":
			return "拾取 %.0f → %.0f%s" % [player.pickup_range_bonus,
				player.pickup_range_bonus + GameConfig.UPGRADE_PICKUP_RANGE, lv]
	return ""

func _basic_preview(reward_id: String) -> String:
	## 补给卡的"现在 → 选完"。right side 必须有数字，
	## 否则玩家选完只有一句 print，完全不知道发生了什么变化。
	if player == null:
		return ""
	match reward_id:
		"damage_boost":
			var now: float = player.damage_multiplier
			var nxt: float = now + GameConfig.BASIC_REWARD_DAMAGE
			return "攻击 ×%.2f → ×%.2f" % [now, nxt]
		"heal":
			var before: float = player.current_hp
			var after: float = minf(before + player.max_hp * 0.3, player.max_hp)
			if is_equal_approx(before, player.max_hp):
				return "生命已满 %.0f/%.0f · 选了没收益" % [before, player.max_hp]
			return "生命 %.0f → %.0f（上限 %.0f）" % [before, after, player.max_hp]
		"gold":
			return "血晶 +100（立即入账）"
	return ""

# ==================== 重抽 / 跳过 ====================

## 按当前随机源抽牌。rng 为空时用全局随机（普通局行为不变）。
## 抽牌与渲染分开：测试可以直接调这里断言"同种子同手牌"，
## 不用真的把界面搭起来。
## count <= 0 表示"整池洗一遍不截断"（洗牌/复现用）；默认截成手牌张数。
func draw_options(options: Array, count: int = 3) -> Array:
	var pool: Array = options.duplicate()
	if rng != null:
		_shuffle_with_rng(pool)
	else:
		pool.shuffle()
	if count <= 0:
		return pool
	return pool.slice(0, mini(count, pool.size()))

const NEW_WEAPON_IDS: Array = ["scythe", "thorn_whip", "frost_bell", "repeater", "soul_lantern", "spike_tome", "chain_gun"]

func _shape_hand(hand: Array) -> Array:
	## 一手里最多一张还没拿到的新武器，避免池子变大以后养不满旧武器。
	## 融合卡满足条件时占掉最后一格，玩家可以不选。
	var shaped: Array = []
	var fresh_new := false
	for opt in hand:
		if String(opt.get("type", "")) == "weapon" and String(opt.get("id", "")) in NEW_WEAPON_IDS:
			if _find_owned_weapon(String(opt.get("id", ""))) == null:
				if fresh_new:
					continue
				fresh_new = true
		shaped.append(opt)
	if weapon_manager != null and weapon_manager.has_method("get_fusion_offer"):
		var offer: Dictionary = weapon_manager.get_fusion_offer()
		if not offer.is_empty() and not is_banished(offer):
			var already := false
			for opt in shaped:
				if String(opt.get("type", "")) == "fusion":
					already = true
			if not already:
				if shaped.is_empty():
					shaped.append(offer)
				else:
					shaped[shaped.size() - 1] = offer
	return shaped

func _shuffle_with_rng(items: Array) -> void:
	## 与 Array.shuffle 同样的 Fisher-Yates，只是随机数来自注入的 rng
	for i in range(items.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Variant = items[i]
		items[i] = items[j]
		items[j] = tmp

func _build_footer() -> void:
	var vbox := $CenterContainer/PanelContainer/VBoxContainer as VBoxContainer
	if vbox == null:
		return

	var footer := HBoxContainer.new()
	footer.name = "Footer"
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 16)

	_reroll_button = _make_footer_button("重抽", Color(0.55, 0.75, 1.0))
	_reroll_button.pressed.connect(_on_reroll)
	footer.add_child(_reroll_button)

	_banish_button = _make_footer_button("放逐", Color(1.0, 0.45, 0.45))
	_banish_button.pressed.connect(_on_banish_toggle)
	footer.add_child(_banish_button)

	_skip_button = _make_footer_button("跳过", Color(1.0, 0.85, 0.45))
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
	UiFx.hover(btn)

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
		_reroll_button.text = "重抽 (%d)" % rerolls_left
	else:
		_reroll_button.text = "重抽 (-%d 银)" % cost
	_reroll_button.disabled = _submitted or not can_reroll()

	if _banish_button != null:
		if banish_mode:
			_banish_button.text = "取消放逐"
		else:
			_banish_button.text = "放逐 (%d)" % banish_left
		_banish_button.disabled = _submitted or (banish_left <= 0 and not banish_mode)

	_skip_button.disabled = _submitted
	_skip_button.text = "跳过 (+%d 银)" % GameConfig.SKIP_SILVER_REWARD
	if banish_mode:
		_hint_label.text = "放逐模式：点任意一张卡把它从本局池移除（剩 %d 次）　B 取消" % banish_left
		_hint_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.55))
	else:
		_hint_label.text = "R 重抽　B 放逐　Tab 跳过　　免费重抽剩 %d 次 · 放逐剩 %d 次" % [rerolls_left, banish_left]
		_hint_label.add_theme_color_override("font_color", Color(0.66, 0.66, 0.72))

func _on_reroll() -> bool:
	## 返回是否真的重抽了（测试要用）
	if _submitted or not can_reroll():
		return false
	if rerolls_left > 0:
		rerolls_left -= 1
	else:
		if player == null or not player.spend_silver(GameConfig.REROLL_SILVER_COST):
			return false
	_draw_and_render_options()
	_refresh_footer()
	return true

func _on_skip() -> void:
	if not _begin_submit():
		return
	if player != null and player.has_method("add_silver"):
		player.add_silver(GameConfig.SKIP_SILVER_REWARD)
	_close_and_emit()

# ==================== 放逐 ====================

func _option_key(option: Dictionary) -> String:
	## 池子里靠 type+id 唯一识别一个选项（属性卡可重复出现，但同 id 是同一张）
	return "%s:%s" % [String(option.get("type", "")), String(option.get("id", ""))]

func can_banish() -> bool:
	return banish_left > 0

func _on_banish_toggle() -> bool:
	## 进入/退出放逐模式。返回是否处于放逐模式（测试要用）
	if _submitted or banish_left <= 0:
		return false
	banish_mode = not banish_mode
	_render_options()
	_refresh_footer()
	return banish_mode

func _on_banish_clicked(option: Dictionary) -> bool:
	## 把这张卡从本局选池移除，并立刻补一手新的。
	## 注意：这里**不消耗重抽次数**——放逐本身就是一次免费刷新，
	## 否则玩家每次 ban 都要额外付一次重抽，两个功能的成本会叠乘。
	if _submitted or banish_left <= 0:
		return false
	var key := _option_key(option)
	if key in banished_keys:
		return false
	banished_keys.append(key)
	banish_left -= 1
	banish_mode = false
	print("🚫 放逐 %s（剩 %d 次，已 ban %d 项）" % [
		String(option.get("name", key)), banish_left, banished_keys.size()])
	_draw_and_render_options()
	_refresh_footer()
	return true

func is_banished(option: Dictionary) -> bool:
	return _option_key(option) in banished_keys

func _input(event: InputEvent) -> void:
	if not visible or _submitted:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_R:
				get_viewport().set_input_as_handled()
				_on_reroll()
			KEY_B:
				get_viewport().set_input_as_handled()
				_on_banish_toggle()
			KEY_TAB:
				get_viewport().set_input_as_handled()
				_on_skip()

func dismiss_for_game_over() -> void:
	## 玩家已死。关掉三选一并放开它持有的暂停，不要发 upgrade_selected
	## ——那会让主场景以为「这张卡选完了」再排队开下一张。
	_submitted = true
	if _close_tween != null:
		_close_tween.kill()
	visible = false
	if PauseController.is_held_by(self):
		PauseController.release(self)

func _begin_submit() -> bool:
	if _submitted:
		return false
	_submitted = true
	for button in options_container.get_children():
		if button is Button:
			button.disabled = true
	_refresh_footer()
	return true

func _close_and_emit() -> void:
	_close_tween = create_tween()
	_close_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_close_tween.tween_property(panel, "modulate:a", 0.0, 0.15)
	_close_tween.tween_callback(func():
		visible = false
		PauseController.release(self)
		upgrade_selected.emit()
	)

func _get_available_options() -> Array:
	## 获取可用的升级选项
	var available: Array = []

	# 添加属性升级（单卡 5 级上限 + 共享总预算；满级或预算用尽的都不再进池）
	# stat_available 记录"还有没有能升级的属性卡"：属性卡全满或预算用尽之后
	# 就要把既有补给卡放回池子里，否则这条分支永远走不到。
	var stat_available: bool = false
	if not _is_stat_budget_exhausted():
		for stat_opt in ItemCatalog.STATS:
			if _is_stat_maxed(stat_opt["id"]):
				continue
			stat_available = true
			available.append(stat_opt)
	
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
		if weapon_opt.get("upgrade_only", false) and not owned:
			continue
		if slots_full and not owned:
			continue
		if not owned and int(weapon_opt.get("unlock_floor", 0)) > 0 and not _is_weapon_unlocked(String(weapon_opt["id"])):
			continue
		# 满级武器再出现就是废卡（卡面会写成 Lv.5 → Lv.5），直接过滤
		var owned_weapon = _find_owned_weapon(weapon_opt["id"])
		if owned_weapon != null and owned_weapon.is_max_level():
			continue
		# 没有变种表的武器不能升级，也不能当作新卡塞进来后升不了级。
		if owned_weapon != null and owned_weapon.has_method("has_level_table") and not owned_weapon.has_level_table():
			continue
		available.append(weapon_opt)
		# 已有武器的升级比新武器更容易被抽到。只加权，不指定成品。
		if owned:
			available.append(weapon_opt)
	
	# 添加被动道具选项（排除已满级的）
	for passive_opt in ItemCatalog.PASSIVES:
		if not _is_passive_maxed(passive_opt["id"]):
			available.append(passive_opt)

	# 统一过滤放逐清单。放在最后一次遍历里做，
	# 避免在三个 append 点各抄一遍过滤逻辑（加第四类选项时必然漏掉一处）
	if not banished_keys.is_empty():
		var kept: Array = []
		for opt in available:
			if not is_banished(opt):
				kept.append(opt)
		available = kept

	# 属性卡全部满级 / 预算用尽 → 启用既有补给卡。
	# 旧逻辑是"整个池子空了才用补给卡"，可属性卡没有上限时池子永远不空，
	# 补给卡这条分支等于一段永远走不到的死代码。
	if not stat_available:
		available.append_array(_available_basic_rewards())

	return available

func _is_stat_maxed(stat_id: String) -> bool:
	## 属性卡是否已满级。没有玩家时一律当作没满（测试与预览都走这里）
	if player == null or not player.has_method("is_stat_maxed"):
		return false
	return bool(player.call("is_stat_maxed", stat_id))

func _is_stat_budget_exhausted() -> bool:
	## 属性卡的共享总预算是否用满。没有玩家时一律当作没满
	if player == null or not player.has_method("is_stat_budget_exhausted"):
		return false
	return bool(player.call("is_stat_budget_exhausted"))

func _stat_level_text(stat_id: String) -> String:
	## 属性卡提示：单卡等级 + 本局共享属性点用量，例如 "Lv.2/5 · 属性点 8/12"。
	## 只给单卡等级时，玩家看不出"这局还能买几张属性"，会在"再开一条线"和
	## "把这条练满"之间瞎猜，直到池子空了才发现触顶。
	if player == null or not player.has_method("get_stat_level"):
		return ""
	if not player.has_method("get_stat_max_level"):
		return ""
	var cur: int = int(player.call("get_stat_level", stat_id))
	var max_lv: int = int(player.call("get_stat_max_level"))
	# 显示的是"选完之后的等级"。夹到上限：满级的卡写 "Lv.6/5" 是自相矛盾的
	var text: String = "Lv.%d/%d" % [mini(cur + 1, max_lv), max_lv]
	if player.has_method("get_total_stat_level") and player.has_method("get_total_stat_max_level"):
		var used: int = int(player.call("get_total_stat_level"))
		var budget: int = int(player.call("get_total_stat_max_level"))
		if budget > 0:
			text += " · 属性点 %d/%d" % [used, budget]
	return text

func _is_weapon_unlocked(weapon_id: String) -> bool:
	var saves := get_node_or_null("/root/SaveManager")
	if saves == null or not saves.has_method("is_weapon_unlocked"):
		return true
	return bool(saves.is_weapon_unlocked(weapon_id))

func _is_weapon_evolved(weapon_id: String) -> bool:
	## 检查武器是否已进化
	if weapon_manager == null:
		return false
	return weapon_manager.is_weapon_evolved(weapon_id)

func _is_passive_maxed(passive_id: String) -> bool:
	## 满级判定统一走 passive_item_data.is_effectively_maxed()：
	## 只看 is_max_level() 会漏掉"上限已经截住、下一级不涨"的道具——
	## 那种卡进了池子，玩家选完会发现卡面数字和选之前一模一样。
	if player == null or not player.has_method("get_owned_passive_items"):
		return false

	for item in player.passive_items:
		if item.item_id == passive_id:
			if item.has_method("is_effectively_maxed"):
				return bool(item.is_effectively_maxed())
			return bool(item.is_max_level())
	return false

func _get_basic_rewards() -> Array:
	## 当所有武器和被动都满级/进化后，提供基础奖励
	## 文案只讲"是什么"，具体幅度由 _basic_preview 补成"现在 → 选完"。
	## 图标留空：本机字体不含 emoji，填 ⚔️💰❤️ 会在 Button 上渲染成蓝方块。
	return [
		{"id": "heal", "name": "生命恢复", "desc": "回复 30% 最大生命", "type": "basic"},
		{"id": "gold", "name": "血晶奖励", "desc": "100 血晶立即入账", "type": "basic"},
		{"id": "damage_boost", "name": "伤害提升", "desc": "攻击倍率 +10%（本局永久）", "type": "basic"},
	]

func _available_basic_rewards() -> Array:
	## 补给卡的**唯一出口**。
	##
	## 所有要给补给卡的地方都必须走这里。之前有两个出口：
	## 选池构建（过滤了放逐）和"池子空了"的兜底（没过滤）——
	## 玩家放逐了"生命恢复"，兜底又把同一张卡塞回池子，放逐形同虚设。
	var kept: Array = []
	for basic in _get_basic_rewards():
		if is_banished(basic):
			continue
		kept.append(basic)
	return kept

func _create_option_button(option: Dictionary) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(222, 196)
	# Space 是开火键。按钮可聚焦时 Space 会被当成"按下当前焦点按钮"，
	# 玩家在面板还开着的那一帧按住开火就会直接选掉一张卡。
	btn.focus_mode = Control.FOCUS_NONE
	# 大卡放大 3% 就够，5% 会让三张卡在屏幕上互相压边
	UiFx.hover(btn, 1.03)
	if banish_mode:
		btn.pressed.connect(func(): _on_banish_clicked(option))
	else:
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
	# 拿不到纹理就留白：不画任何字符回退。
	# 本机主字体不含 emoji，Button 上会变成蓝色方块（GDD 附录 D.4）；
	# 中文字回退同样会变成"只有字没有图标"。留白才能一眼看出缺图，
	# tools/verify_round4.gd 会把这种情况当成回归报出来。

	# 添加名称
	var name_label := Label.new()
	name_label.text = option["name"]
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	name_label.custom_minimum_size.x = 186
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
		level_label.custom_minimum_size.x = 186
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
	desc_label.custom_minimum_size.x = 186  # 数值行加宽后，描述行对齐同一宽度
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

	# 放逐模式整卡染红：不用改 stylebox（会丢贴图纹理），直接压色调最省事
	if banish_mode:
		btn.modulate = Color(1.0, 0.74, 0.74, 1.0)

	return btn

func _get_option_icon(option: Dictionary) -> Texture2D:
	## 获取选项对应的图标纹理。
	## 2026-11-09 反馈"很多卡只有字没有图"：图标映射原本只覆盖了一半物品，
	## 现在统一走 ItemCatalog.get_icon_texture（武器/被动/属性/消耗品一张表），
	## 拿不到贴图再回退旧的逐项 match（未来 catalog 改动也只改一处）。
	var lookup_type := String(option.get("type", ""))
	if lookup_type == "fusion":
		lookup_type = "weapon"
	var tex: Texture2D = ItemCatalog.get_icon_texture(
		String(option.get("id", "")), lookup_type)
	if tex != null:
		return tex

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
					return TextureManager.instance.get_weapon_icon("heal_potion_icon")
				"armor":
					return TextureManager.instance.get_weapon_icon("shield")
				"pickup_range":
					return TextureManager.instance.get_weapon_icon("magnet")
				"gold":
					return TextureManager.instance.get_weapon_icon("blood_crystal_icon")
	
	return null

func _on_option_selected(option: Dictionary) -> void:
	if not _begin_submit():
		return
	var option_type: String = option.get("type", "stat")
	if option_type == "stat":
		if player != null and player.has_method("apply_upgrade"):
			player.apply_upgrade(option["id"])
	elif option_type == "weapon":
		if weapon_manager != null and weapon_manager.has_method("add_weapon"):
			var weapon_data = ItemCatalog.create_weapon(option["id"])
			if weapon_data:
				weapon_manager.add_weapon(weapon_data)
	elif option_type == "fusion":
		if weapon_manager != null and weapon_manager.has_method("apply_fusion"):
			weapon_manager.apply_fusion(String(option.get("id", "")))
	elif option_type == "passive":
		if player != null and player.has_method("add_passive_item"):
			var passive_data = ItemCatalog.create_passive(option["id"])
			if passive_data:
				player.add_passive_item(passive_data)
	elif option_type == "basic":
		_apply_basic_reward(option["id"])
	_close_and_emit()

func _apply_basic_reward(reward_id: String) -> void:
	## 应用基础奖励。
	## 每一项都要在屏幕上留下数字：卡片上写了"×1.30 → ×1.40"，
	## 选完如果什么都不显示，玩家会怀疑到底生效没有。
	var hud := get_tree().get_first_node_in_group("hud")
	match reward_id:
		"heal":
			if player != null and player.has_method("heal"):
				var heal_amount: float = player.max_hp * 0.3
				player.heal(heal_amount)
				print("❤ 恢复 %.0f 生命" % heal_amount)
				if hud and hud.has_method("show_toast"):
					hud.show_toast("生命 +%.0f（%.0f / %.0f）" % [
						heal_amount, player.current_hp, player.max_hp])
		"gold":
			var save_mgr := get_node_or_null("/root/SaveManager")
			if save_mgr:
				save_mgr.add_blood_crystals(100)
				var achievements := get_node_or_null("/root/AchievementManager")
				if achievements != null:
					achievements.record_crystals_earned(100)
				print("+ 获得 100 血晶")
				if hud and hud.has_method("show_toast"):
					hud.show_toast("血晶 +100（立即入账）")
		"damage_boost":
			if player != null:
				var before: float = player.damage_multiplier
				player.damage_multiplier += GameConfig.BASIC_REWARD_DAMAGE
				var after: float = player.damage_multiplier
				print("⚔ 攻击倍率 %.2f → %.2f" % [before, after])
				if hud and hud.has_method("show_toast"):
					hud.show_toast("攻击 ×%.2f → ×%.2f" % [before, after])
				print("⚔️ 攻击力 +10%")
