extends CanvasLayer
## 角色选择界面

const CharacterData = preload("res://scripts/player/character_data.gd")

@onready var chars_container: HBoxContainer = $Panel/VBoxContainer/CharsContainer
@onready var crystals_label: Label = $Panel/VBoxContainer/Header/CrystalsLabel
@onready var back_btn: Button = $Panel/VBoxContainer/BackButton

signal character_selected(char_id: String)
signal selection_closed

var save_mgr: Node

func _ready() -> void:
	visible = false
	back_btn.pressed.connect(_on_back_pressed)
	save_mgr = get_node_or_null("/root/SaveManager")

func show_selection() -> void:
	visible = true
	_refresh_ui()

func _refresh_ui() -> void:
	if not save_mgr:
		return
	crystals_label.text = "💎 血晶: %d" % save_mgr.get_blood_crystals()
	for child in chars_container.get_children():
		child.queue_free()
	
	var characters: Array = CharacterData.get_all_characters()
	for char_data in characters:
		var card := _create_card(char_data)
		chars_container.add_child(card)

func _create_card(char_data: Resource) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(300, 400)

	# 卡片背景纹理
	var card_texture := TextureManager.instance.get_ui_texture("upgrade_card")
	if card_texture:
		var style := StyleBoxTexture.new()
		style.texture = card_texture
		card.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(vbox)

	var is_unlocked: bool = save_mgr.is_character_unlocked(char_data.char_id) if save_mgr else false
	var is_selected: bool = (save_mgr.get_selected_character() == char_data.char_id) if save_mgr else false

	# 已选择标记
	if is_selected:
		var mark := TextureRect.new()
		var mark_tex := TextureManager.instance.get_ui_texture("selected_mark")
		if mark_tex:
			mark.texture = mark_tex
			mark.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			mark.custom_minimum_size = Vector2(32, 32)
			mark.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			vbox.add_child(mark)

	var name_label := Label.new()
	name_label.text = char_data.char_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 22)
	if is_selected:
		name_label.modulate = Color(1.0, 0.85, 0.2)
	vbox.add_child(name_label)

	# 角色 emoji 大图标
	var icon_label := Label.new()
	var icon_emoji: Variant = char_data.get("icon_emoji")
	icon_label.text = icon_emoji if icon_emoji != null else "🧛"
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.add_theme_font_size_override("font_size", 48)
	vbox.add_child(icon_label)

	var desc_label := Label.new()
	desc_label.text = char_data.description
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.custom_minimum_size.x = 240
	desc_label.modulate = Color(0.75, 0.75, 0.75)
	vbox.add_child(desc_label)

	var stats_label := Label.new()
	stats_label.text = "❤ HP: %d
👟 速度: %d
⚔ 伤害: x%.2f" % [
		int(char_data.base_hp), int(char_data.base_speed), char_data.base_damage_mult
	]
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(stats_label)

	var weapon_label := Label.new()
	weapon_label.text = "🔫 初始: %s" % char_data.initial_weapon
	weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(weapon_label)

	var passive_label := Label.new()
	passive_label.text = "🌟 %s
%s" % [char_data.passive_name, char_data.passive_description]
	passive_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	passive_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	passive_label.custom_minimum_size.x = 240
	passive_label.modulate = Color(0.5, 0.9, 1.0)
	vbox.add_child(passive_label)

	# 未解锁时灰化卡片
	if not is_unlocked:
		card.modulate = Color(0.6, 0.6, 0.6, 1.0)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 44)
	_apply_button_style(btn)
	if not is_unlocked:
		btn.text = "🔒 解锁 (💎 %d)" % char_data.unlock_cost
		btn.disabled = (not save_mgr) or save_mgr.get_blood_crystals() < char_data.unlock_cost
		var cid: String = char_data.char_id
		var cost: int = char_data.unlock_cost
		btn.pressed.connect(func(): _unlock_character(cid, cost))
	elif is_selected:
		btn.text = "✅ 已选择"
		btn.disabled = true
	else:
		btn.text = "选择角色"
		var cid: String = char_data.char_id
		btn.pressed.connect(func(): _select_character(cid))
	vbox.add_child(btn)

	# 卡片悬停动效
	card.mouse_entered.connect(func(): _on_card_hover(card, is_unlocked))
	card.mouse_exited.connect(func(): _on_card_unhover(card))

	return card

func _apply_button_style(btn: Button) -> void:
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
	btn.mouse_entered.connect(func(): AudioManager.play_sfx(AudioLib.get_sound("hover")))
	btn.pressed.connect(func(): AudioManager.play_sfx(AudioLib.get_sound("button_click")))

func _on_card_hover(card: PanelContainer, unlocked: bool) -> void:
	if not unlocked:
		return
	var tween := create_tween()
	tween.tween_property(card, "scale", Vector2(1.05, 1.05), 0.15)
	tween.parallel().tween_property(card, "modulate", Color(1.2, 1.1, 1.1, 1.0), 0.15)

func _on_card_unhover(card: PanelContainer) -> void:
	var tween := create_tween()
	tween.tween_property(card, "scale", Vector2.ONE, 0.15)
	tween.parallel().tween_property(card, "modulate", Color.WHITE, 0.15)

func _unlock_character(char_id: String, cost: int) -> void:
	if save_mgr and save_mgr.unlock_character(char_id, cost):
		print("🔓 解锁角色: %s" % char_id)
		_refresh_ui()

func _select_character(char_id: String) -> void:
	if save_mgr:
		save_mgr.select_character(char_id)
	character_selected.emit(char_id)
	_refresh_ui()

func _on_back_pressed() -> void:
	visible = false
	selection_closed.emit()
