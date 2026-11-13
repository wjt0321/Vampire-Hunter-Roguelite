extends CanvasLayer
class_name RoomShop
## 局内商店（Brotato 式波间商店的简化版）
##
## 为什么要有它：之前商店房只是 `player.heal(max_hp*0.3)` 然后开传送门，
## 玩家整局没有任何"花钱做取舍"的机会，所有决策都压在三选一上，而三选一完全随机。
## 现在改成：怪物掉银币 → 商店 4 格货架 → 买武器/被动/消耗品，可重抽、可锁定。
##
## UI 全部代码构建，不依赖 .tscn —— 少一个要维护的场景文件，改布局只改这里。

signal shop_closed

const SLOT_COUNT: int = 4
const REROLL_COSTS: Array = [8, 14, 22, 34]
const RECAST_COST: int = 30
const HEAL_PRICE: int = 10
const DISMANTLE_REFUND: int = 8

var player: Node = null
var weapon_manager: Node = null

var _offers: Array = []      # 每格商品（{} 表示空格）
var _locked: Array = []      # 每格是否锁定（重抽时保留）
var _sold: Array = []        # 每格是否已售出

var _rerolls: int = 0
## 带到下一间商店的那一件。买掉或换掉就清空，同时只能有一件。
var carried_offer: Dictionary = {}
var _floor_index: int = 1
var _recast_floor: int = -1
var _dismantle_floor: int = -1
var _recast_btn: Button = null
var _dismantle_btn: Button = null

var _built: bool = false
var _root: Control = null
var _silver_label: Label = null
var _slots_box: HBoxContainer = null
var _reroll_btn: Button = null
var _hint_label: Label = null

# ---------------------------------------------------------------- 生命周期

func _ready() -> void:
	layer = 95
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

func open(player_node: Node, weapon_mgr: Node = null, floor_index: int = 1) -> void:
	player = player_node
	weapon_manager = weapon_mgr
	_floor_index = floor_index
	_rerolls = 0
	_offers.clear()
	_locked.clear()
	_sold.clear()
	for i in SLOT_COUNT:
		_offers.append({})
		_locked.append(false)
		_sold.append(false)

	if not _built:
		_build_ui()
	_roll_all()
	if not carried_offer.is_empty():
		_offers[0] = carried_offer.duplicate(true)
		_locked[0] = true
		_sold[0] = false
	_refresh()
	visible = true
	# 暂停世界，玩家可以慢慢挑（和升级界面一致）
	PauseController.acquire(self)

func close() -> void:
	if not visible:
		return
	carried_offer = {}
	for i in SLOT_COUNT:
		if _locked[i] and not _sold[i] and not _offers[i].is_empty():
			carried_offer = _offers[i].duplicate(true)
			break
	visible = false
	PauseController.release(self)
	shop_closed.emit()

# ---------------------------------------------------------------- 货架逻辑

func _build_pool() -> Array:
	## 可售池：已拥有的武器（重复购买＝升级）、未满级被动、消耗品
	var pool: Array = []

	var owned_ids: Array = []
	if weapon_manager != null and "weapons" in weapon_manager:
		for w in weapon_manager.weapons:
			owned_ids.append(w.weapon_id)
	var slots_full: bool = owned_ids.size() >= GameConfig.MAX_WEAPON_SLOTS

	for w in ItemCatalog.WEAPONS:
		if weapon_manager != null and weapon_manager.has_method("is_weapon_evolved") \
				and weapon_manager.is_weapon_evolved(w["id"]):
			continue
		if slots_full and not (w["id"] in owned_ids):
			continue
		if w.get("upgrade_only", false) and not (w["id"] in owned_ids):
			continue
		if not _can_apply_offer(w):
			continue
		pool.append(w.duplicate())

	for p in ItemCatalog.PASSIVES:
		if _is_passive_maxed(p["id"]):
			continue
		pool.append(p.duplicate())

	# 消耗品权重低一些：混进池子即可（4 件 / 25 件池 ≈ 16%）
	for c in ItemCatalog.CONSUMABLES:
		pool.append(c.duplicate())

	return pool

func _is_passive_maxed(passive_id: String) -> bool:
	## 与升级三选一共用同一条判定（passive_item_data.is_effectively_maxed）。
	## 两处各写一份的话，会出现"商店还在卖、三选一已经过滤掉"的错位。
	if player == null or not ("passive_items" in player):
		return false
	for item in player.passive_items:
		if item.item_id == passive_id:
			if item.has_method("is_effectively_maxed"):
				return bool(item.is_effectively_maxed())
			if item.has_method("is_max_level"):
				return bool(item.is_max_level())
	return false

func _roll_all() -> void:
	var pool := _build_pool()
	for i in SLOT_COUNT:
		if _locked[i] and not _offers[i].is_empty():
			continue  # 锁定的格子保留
		_offers[i] = {}
		_sold[i] = false
		if pool.is_empty():
			continue
		var picked: Dictionary = pool.pick_random()
		_offers[i] = picked
	_ensure_heal_offer()

func _ensure_heal_offer() -> void:
	for offer in _offers:
		if String(offer.get("id", "")) == "heal" and String(offer.get("type", "")) == "consumable":
			offer["price"] = HEAL_PRICE
			return
	var heal: Dictionary = ItemCatalog.find_consumable("heal")
	if heal.is_empty():
		return
	heal = heal.duplicate(true)
	heal["price"] = HEAL_PRICE
	for i in range(SLOT_COUNT - 1, -1, -1):
		if not _locked[i]:
			_offers[i] = heal
			_sold[i] = false
			return

func _current_reroll_cost() -> int:
	return REROLL_COSTS[mini(_rerolls, REROLL_COSTS.size() - 1)]

func _get_silver() -> int:
	if player != null and "silver" in player:
		return int(player.silver)
	return 0

# ---------------------------------------------------------------- UI

func _build_ui() -> void:
	_built = true

	_root = Control.new()
	_root.name = "ShopRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.03, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _make_style(Color(0.09, 0.07, 0.10, 0.98), Color(0.62, 0.48, 0.22, 0.9), 2, 10))
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "银 币 商 店"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.55))
	vbox.add_child(title)

	_silver_label = Label.new()
	_silver_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_silver_label.add_theme_font_size_override("font_size", 18)
	_silver_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.7))
	vbox.add_child(_silver_label)

	_slots_box = HBoxContainer.new()
	_slots_box.add_theme_constant_override("separation", 12)
	_slots_box.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(_slots_box)

	_hint_label = Label.new()
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.add_theme_font_size_override("font_size", 12)
	_hint_label.add_theme_color_override("font_color", Color(0.65, 0.62, 0.58))
	_hint_label.text = "血瓶每间都有。重抽会变贵。锁定的一件带到下一间，拆解每层一次"
	vbox.add_child(_hint_label)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 16)
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(bottom)

	_reroll_btn = _make_button("重抽")
	_reroll_btn.pressed.connect(_on_reroll)
	bottom.add_child(_reroll_btn)

	_recast_btn = _make_button("重铸")
	_recast_btn.pressed.connect(_on_recast)
	bottom.add_child(_recast_btn)

	_dismantle_btn = _make_button("拆解")
	_dismantle_btn.pressed.connect(_on_dismantle)
	bottom.add_child(_dismantle_btn)

	var leave_btn := _make_button("离开商店")
	leave_btn.pressed.connect(close)
	bottom.add_child(leave_btn)

func _make_style(bg: Color, border: Color, border_w: int = 1, radius: int = 8) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_w)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

func _make_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(150, 42)
	# Space = 开火（见 project.godot 的 shoot 动作）。按钮可聚焦时
	# Space 会先被当成"按下焦点按钮"，玩家一边开火一边点商店就会误买。
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 16)
	btn.add_theme_stylebox_override("normal", _make_style(Color(0.14, 0.11, 0.16, 1.0), Color(0.5, 0.4, 0.22, 0.9)))
	btn.add_theme_stylebox_override("hover", _make_style(Color(0.22, 0.17, 0.14, 1.0), Color(0.95, 0.8, 0.42, 1.0)))
	btn.add_theme_stylebox_override("pressed", _make_style(Color(0.28, 0.2, 0.12, 1.0), Color(1.0, 0.86, 0.45, 1.0)))
	btn.add_theme_stylebox_override("disabled", _make_style(Color(0.10, 0.09, 0.10, 1.0), Color(0.3, 0.28, 0.26, 0.8)))
	UiFx.hover(btn)
	return btn

func _refresh() -> void:
	if not _built:
		return

	_silver_label.text = "持有银币：%d" % _get_silver()

	for child in _slots_box.get_children():
		_slots_box.remove_child(child)
		child.queue_free()
	for i in SLOT_COUNT:
		_slots_box.add_child(_make_card(i))

	var cost := _current_reroll_cost()
	_reroll_btn.text = "重抽 (%d 银)" % cost
	_reroll_btn.disabled = _get_silver() < cost
	if _recast_btn != null:
		var used := _recast_floor == _floor_index
		_recast_btn.text = "本层已重铸" if used else "重铸 (%d 银)" % RECAST_COST
		_recast_btn.disabled = used or _get_silver() < RECAST_COST or weapon_manager == null
	if _dismantle_btn != null:
		var dismantled := _dismantle_floor == _floor_index
		_dismantle_btn.text = "本层已拆解" if dismantled else "拆解 (+%d 银)" % DISMANTLE_REFUND
		_dismantle_btn.disabled = dismantled or player == null or not player.has_method("dismantle_passive")

func _make_card(index: int) -> Control:
	var slot: Dictionary = _offers[index]
	var sold: bool = _sold[index]
	var locked: bool = _locked[index]

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(180, 250)
	var border := Color(0.95, 0.78, 0.35, 1.0) if locked else Color(0.28, 0.24, 0.28, 0.9)
	card.add_theme_stylebox_override("panel", _make_style(Color(0.06, 0.05, 0.07, 0.95), border, 2 if locked else 1, 8))

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	card.add_child(vb)

	if slot.is_empty() or sold:
		var empty := Label.new()
		empty.text = "— 已售出 —" if sold else "— 空 —"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty.size_flags_vertical = Control.SIZE_EXPAND_FILL
		empty.add_theme_color_override("font_color", Color(0.45, 0.43, 0.42))
		vb.add_child(empty)
		return card

	# 图标：统一走 ItemCatalog 映射。拿不到贴图就留白——
	# 旧版回退显示 catalog 里的单字（"枪"/"书"），单字长得像图标，
	# 反而把"这里缺一张图"这件事藏起来了。
	var icon_tex: Texture2D = ItemCatalog.get_icon_texture(
		String(slot.get("id", "")), String(slot.get("type", "")))
	if icon_tex != null:
		var icon_rect := TextureRect.new()
		icon_rect.texture = icon_tex
		icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.custom_minimum_size = Vector2(48, 48)
		icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		vb.add_child(icon_rect)

	var name_label := Label.new()
	name_label.text = String(slot.get("name", "?"))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 17)
	name_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.72))
	vb.add_child(name_label)

	var type_label := Label.new()
	type_label.text = _kind_text(String(slot.get("type", "")))
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_label.add_theme_font_size_override("font_size", 11)
	type_label.add_theme_color_override("font_color", Color(0.62, 0.58, 0.52))
	vb.add_child(type_label)

	var desc := Label.new()
	desc.text = String(slot.get("desc", ""))
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(160, 46)
	desc.add_theme_font_size_override("font_size", 12)
	desc.add_theme_color_override("font_color", Color(0.82, 0.8, 0.78))
	vb.add_child(desc)

	var price: int = int(slot.get("price", 0))
	var buy_btn := _make_button("%d" % price)
	buy_btn.custom_minimum_size = Vector2(150, 38)
	buy_btn.disabled = _get_silver() < price or not _can_apply_offer(slot)
	if not buy_btn.disabled:
		buy_btn.add_theme_color_override("font_color", Color(1.0, 0.92, 0.6))
	buy_btn.pressed.connect(func(): _on_buy(index))
	vb.add_child(buy_btn)

	var lock_btn := _make_button("已锁定" if locked else "锁定")
	lock_btn.custom_minimum_size = Vector2(150, 30)
	lock_btn.add_theme_font_size_override("font_size", 12)
	lock_btn.pressed.connect(func(): _on_toggle_lock(index))
	vb.add_child(lock_btn)

	return card

func _kind_text(kind: String) -> String:
	match kind:
		"weapon":
			return "武器"
		"passive":
			return "被动道具"
		"consumable":
			return "消耗品"
	return ""

# ---------------------------------------------------------------- 交互

func _on_toggle_lock(index: int) -> void:
	var turn_on: bool = not bool(_locked[index])
	for i in SLOT_COUNT:
		_locked[i] = false
	if turn_on:
		_locked[index] = true
	_refresh()

func _on_reroll() -> void:
	var cost := _current_reroll_cost()
	if player == null or not player.has_method("spend_silver"):
		return
	if not player.spend_silver(cost):
		return
	_rerolls += 1
	_note_shop("reroll", cost)
	_roll_all()
	_refresh()

func _on_recast() -> void:
	if _recast_floor == _floor_index or weapon_manager == null or not weapon_manager.has_method("recast_choices"):
		return
	var choices: Array = weapon_manager.recast_choices()
	if choices.is_empty():
		return
	for child in _slots_box.get_children():
		if String(child.name).begins_with("RecastChoice"):
			child.queue_free()
	for i in choices.size():
		var picked: Dictionary = choices[i]
		var btn := _make_button("%s→%s" % [picked.get("from_name", ""), picked.get("to_name", "")])
		btn.name = "RecastChoice%d" % i
		btn.custom_minimum_size = Vector2(120, 64)
		var choice_index := i
		btn.pressed.connect(func(): _confirm_recast(choice_index))
		_slots_box.add_child(btn)

func _confirm_recast(index: int) -> void:
	if player == null or not player.has_method("spend_silver") or weapon_manager == null:
		return
	var choices: Array = weapon_manager.recast_choices()
	if index < 0 or index >= choices.size() or not player.spend_silver(RECAST_COST):
		return
	var picked: Dictionary = choices[index]
	if not weapon_manager.apply_recast(String(picked.get("from", "")), String(picked.get("to", ""))):
		player.add_silver(RECAST_COST)
		return
	_recast_floor = _floor_index
	_note_shop("recast", RECAST_COST)
	_refresh()

func _on_dismantle() -> void:
	if _dismantle_floor == _floor_index or player == null or not player.has_method("dismantle_passive"):
		return
	if not ("passive_items" in player) or player.passive_items.is_empty():
		return
	for child in _slots_box.get_children():
		if String(child.name).begins_with("DismantleChoice"):
			child.queue_free()
	for i in player.passive_items.size():
		var item = player.passive_items[i]
		var warning := ""
		if weapon_manager != null and weapon_manager.has_method("dismantle_warning"):
			warning = String(weapon_manager.dismantle_warning(String(item.item_id)))
		var label := String(item.item_name)
		if warning != "":
			label += "\n" + warning
		var btn := _make_button(label)
		btn.name = "DismantleChoice%d" % i
		btn.custom_minimum_size = Vector2(160, 64)
		var picked_id := String(item.item_id)
		btn.pressed.connect(func(): _confirm_dismantle(picked_id))
		_slots_box.add_child(btn)

func _confirm_dismantle(item_id: String) -> void:
	if _dismantle_floor == _floor_index or player == null or not player.has_method("dismantle_passive"):
		return
	if not player.dismantle_passive(item_id):
		return
	if player.has_method("add_silver"):
		player.add_silver(DISMANTLE_REFUND)
	_dismantle_floor = _floor_index
	_note_shop("dismantle", 0)
	_refresh()

func _note_shop(kind: String, amount: int) -> void:
	var log: Node = get_tree().get_first_node_in_group("run_log") if is_inside_tree() else null
	if log != null and log.has_method("note_shop"):
		log.note_shop(kind, amount)
	if kind == "buy" and player != null:
		var left := get_tree().get_first_node_in_group("run_log")
		if left != null and left.has_method("note_silver_left") and "silver" in player:
			left.note_silver_left(int(player.silver))

func _on_buy(index: int) -> void:
	if index < 0 or index >= _offers.size():
		return
	var slot: Dictionary = _offers[index]
	if slot.is_empty() or _sold[index]:
		return
	var price: int = int(slot.get("price", 0))
	if player == null or not player.has_method("spend_silver"):
		return
	if price < 0 or _get_silver() < price or not _can_apply_offer(slot):
		_refresh()
		return
	# 同步应用成功后才收费；底层容量检查是最终裁决。
	if not _apply_offer(slot):
		_refresh()
		return
	player.spend_silver(price)
	_note_shop("buy", price)
	if _locked[index]:
		carried_offer = {}
	_sold[index] = true
	_locked[index] = false
	_offers[index] = {}
	_refresh()

func _can_apply_offer(offer: Dictionary) -> bool:
	if player == null:
		return false
	var id := String(offer.get("id", ""))
	match String(offer.get("type", "")):
		"weapon":
			var entry := ItemCatalog.find_weapon(id)
			if entry.is_empty() or weapon_manager == null:
				return false
			if entry.get("upgrade_only", false):
				var owned := false
				for weapon in weapon_manager.weapons:
					if weapon.weapon_id == id:
						owned = true
				if not owned:
					return false
			return weapon_manager.can_add_weapon(id)
		"passive":
			return not ItemCatalog.find_passive(id).is_empty() and not _is_passive_maxed(id) and player.has_method("add_passive_item")
		"consumable":
			return not ItemCatalog.find_consumable(id).is_empty()
	return false

func _apply_offer(offer: Dictionary) -> bool:
	if not _can_apply_offer(offer):
		return false
	var kind: String = String(offer.get("type", ""))
	var id: String = String(offer.get("id", ""))
	match kind:
		"weapon":
			var data = ItemCatalog.create_weapon(id)
			if data == null or not weapon_manager.add_weapon(data):
				return false
		"passive":
			var item = ItemCatalog.create_passive(id)
			if item == null:
				return false
			player.add_passive_item(item)
		"consumable":
			_apply_consumable(id)
	AudioManager.play_ui_sfx(AudioLib.get_sound("purchase"))
	return true

func _apply_consumable(id: String) -> void:
	if player == null:
		return
	match id:
		"heal":
			if player.has_method("heal"):
				player.heal(player.max_hp * 0.4)
		"max_hp":
			player.max_hp += 15.0
			if player.has_method("heal"):
				player.heal(15.0)
		"damage":
			player.damage_multiplier += 0.12
		"speed":
			player.move_speed *= 1.10
