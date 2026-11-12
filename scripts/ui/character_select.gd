extends CanvasLayer
## 角色选择界面

const CharacterData = preload("res://scripts/player/character_data.gd")

@onready var chars_container: HBoxContainer = $Panel/VBoxContainer/CharsContainer
@onready var crystals_label: Label = $Panel/VBoxContainer/Header/CrystalsLabel
@onready var back_btn: Button = $Panel/VBoxContainer/BackButton

signal character_selected(char_id: String)
signal selection_closed

var save_mgr: Node

## 卡片尺寸：立绘 96 + 名字 + 描述 + 三行属性 + 武器 + 被动 + 按钮
const CARD_SIZE := Vector2(340, 420)

func _ready() -> void:
	visible = false
	back_btn.focus_mode = Control.FOCUS_NONE
	back_btn.pressed.connect(_on_back_pressed)
	save_mgr = get_node_or_null("/root/SaveManager")
	_setup_panel_style()

## 外层大框和升级商店用同一张 stats_panel，九宫格切开，角上的宝石不再被拉伸。
func _setup_panel_style() -> void:
	var tex := TextureManager.instance.get_ui_texture("stats_panel")
	if tex == null:
		return
	var style := StyleBoxTexture.new()
	style.texture = tex
	style.texture_margin_left = 48
	style.texture_margin_right = 48
	style.texture_margin_top = 62
	style.texture_margin_bottom = 60
	style.content_margin_left = 52
	style.content_margin_right = 52
	style.content_margin_top = 66
	style.content_margin_bottom = 64
	$Panel.add_theme_stylebox_override("panel", style)

func show_selection() -> void:
	visible = true
	_refresh_ui()
	UiFx.pop_in($Panel, 0.16, 0.97)

func _refresh_ui() -> void:
	if not save_mgr:
		return
	crystals_label.text = "血晶: %d" % save_mgr.get_blood_crystals()
	for child in chars_container.get_children():
		child.queue_free()
	
	var characters: Array = CharacterData.get_all_characters()
	for char_data in characters:
		var card := _create_card(char_data)
		chars_container.add_child(card)

## 卡面上原来直接打的是内部 id（pistol / magic_book），玩家看到的是英文键名。
func _weapon_display_name(id: String) -> String:
	var n := ItemCatalog.get_display_name(id)
	if n != id:
		return n
	match id:
		"pistol":
			return "手枪"
		"throwing_knife":
			return "飞刀"
		_:
			return id

## 卡片立绘：直接用游戏内真实精灵的第一帧。
## 角色专属图放 assets/sprites/player/{char_id}_idle.png 就会被自动取用；
## 目前只有一套通用玩家精灵，别的角色先复用它。
func _character_portrait(char_id: String) -> Texture2D:
	var own := "res://assets/sprites/player/%s_idle.png" % char_id
	var tex: Texture2D = null
	if ResourceLoader.exists(own):
		tex = load(own)
	if tex == null and TextureManager.instance:
		tex = TextureManager.instance.get_player_texture("idle")
	if tex == null:
		return null
	var cell: int = tex.get_height()
	var atlas := AtlasTexture.new()
	atlas.atlas = tex
	atlas.region = Rect2(0, 0, cell, cell)
	return atlas

func _create_card(char_data: Resource) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = CARD_SIZE

	# 卡片背景：九宫格切开，金框和四角宝石保持原尺寸，不随卡片拉伸
	var card_texture := TextureManager.instance.get_ui_texture("upgrade_card")
	if card_texture:
		var style := StyleBoxTexture.new()
		style.texture = card_texture
		style.texture_margin_left = 28
		style.texture_margin_right = 28
		style.texture_margin_top = 22
		style.texture_margin_bottom = 18
		style.content_margin_left = 34
		style.content_margin_right = 34
		style.content_margin_top = 28
		style.content_margin_bottom = 22
		card.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(vbox)

	var is_unlocked: bool = save_mgr.is_character_unlocked(char_data.char_id) if save_mgr else false
	var is_selected: bool = (save_mgr.get_selected_character() == char_data.char_id) if save_mgr else false

	# 立绘：套一个暗色描边槽再放图。
	# 槽内净宽 112 = 56 的整数 2 倍，最近邻放大后像素是均匀的；
	# 没有这层暗底时，猎人的黑色披风会直接糊在卡片的棕色底上。
	var portrait_frame := Panel.new()
	portrait_frame.custom_minimum_size = Vector2(132, 132)
	portrait_frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var slot_style := StyleBoxFlat.new()
	slot_style.bg_color = Color(0.06, 0.045, 0.055, 0.72)
	slot_style.border_color = Color(0.62, 0.5, 0.28, 0.75)
	slot_style.set_border_width_all(1)
	slot_style.set_corner_radius_all(3)
	portrait_frame.add_theme_stylebox_override("panel", slot_style)
	vbox.add_child(portrait_frame)

	var portrait := TextureRect.new()
	portrait.texture = _character_portrait(char_data.char_id)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# 像素精灵放大必须用最近邻，否则糊成一团
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait_frame.add_child(portrait)
	portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	portrait.offset_left = 10
	portrait.offset_top = 10
	portrait.offset_right = -10
	portrait.offset_bottom = -10

	# 「已选择」用星号贴图（star_gold.png），不再用 "★ " 字符：
	# 角色名旁边挂一个字符星号，本质还是"用字符代替图标"。
	# 走 HBox 而不是多挂一个独立子节点，两种状态的卡片高度仍然一致
	# （星号 24px 小于名字行高，HBox 取两者最大值，未选中时星标不占空间）。
	var name_row := HBoxContainer.new()
	name_row.alignment = BoxContainer.ALIGNMENT_CENTER
	name_row.add_theme_constant_override("separation", 6)

	var star := TextureRect.new()
	star.texture = TextureManager.instance.get_ui_texture("star_gold")
	star.custom_minimum_size = Vector2(24, 24)
	star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	star.visible = is_selected
	name_row.add_child(star)

	var name_label := Label.new()
	name_label.text = char_data.char_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 22)
	if is_selected:
		name_label.modulate = Color(1.0, 0.85, 0.2)
	name_row.add_child(name_label)
	vbox.add_child(name_row)

	var desc_label := Label.new()
	desc_label.text = char_data.description
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_font_size_override("font_size", 13)
	desc_label.custom_minimum_size.x = 250
	desc_label.modulate = Color(0.75, 0.75, 0.75)
	vbox.add_child(desc_label)

	var stats_label := Label.new()
	stats_label.text = "生命 %d · 速度 %d · 伤害 x%.2f" % [
		int(char_data.base_hp), int(char_data.base_speed), char_data.base_damage_mult
	]
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats_label.add_theme_font_size_override("font_size", 14)
	stats_label.add_theme_constant_override("line_spacing", -2)
	vbox.add_child(stats_label)

	var weapon_label := Label.new()
	weapon_label.text = "初始武器: %s" % _weapon_display_name(char_data.initial_weapon)
	weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	weapon_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(weapon_label)

	# 被动技能：图标 + 名称/说明。
	# 旧版是一个纯文字 Label（"猎人直觉\n拾取范围 +20%"），角色卡片上两行字
	# 完全没有辨识度，玩家看不出这个被动到底给了什么。
	var passive_row := HBoxContainer.new()
	passive_row.alignment = BoxContainer.ALIGNMENT_CENTER
	passive_row.add_theme_constant_override("separation", 10)

	var passive_icon := TextureRect.new()
	passive_icon.custom_minimum_size = Vector2(48, 48)
	passive_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	passive_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	passive_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	passive_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var passive_tex: Texture2D = TextureManager.instance.get_passive_icon(
		String(char_data.passive_icon))
	if passive_tex != null:
		passive_icon.texture = passive_tex
	else:
		passive_icon.visible = false
	passive_row.add_child(passive_icon)

	var passive_text := VBoxContainer.new()
	passive_text.custom_minimum_size.x = 190
	passive_text.add_theme_constant_override("separation", 1)

	var passive_name_label := Label.new()
	passive_name_label.text = String(char_data.passive_name)
	passive_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	passive_name_label.add_theme_font_size_override("font_size", 15)
	passive_name_label.modulate = Color(0.5, 0.9, 1.0)
	passive_text.add_child(passive_name_label)

	var passive_label := Label.new()
	passive_label.text = String(char_data.passive_description)
	passive_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	passive_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	passive_label.add_theme_font_size_override("font_size", 12)
	passive_label.modulate = Color(0.5, 0.9, 1.0)
	passive_text.add_child(passive_label)

	passive_row.add_child(passive_text)
	vbox.add_child(passive_row)

	# 未解锁时灰化卡片
	if not is_unlocked:
		card.modulate = Color(0.6, 0.6, 0.6, 1.0)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 42)
	# Space 是开火键。角色卡按钮留在键盘焦点链里，按 Space 会直接换角色。
	btn.focus_mode = Control.FOCUS_NONE
	_apply_button_style(btn)
	if not is_unlocked:
		btn.text = "解锁 (血晶 %d)" % char_data.unlock_cost
		btn.disabled = (not save_mgr) or save_mgr.get_blood_crystals() < char_data.unlock_cost
		var cid: String = char_data.char_id
		var cost: int = char_data.unlock_cost
		btn.pressed.connect(func(): _unlock_character(cid, cost))
	elif is_selected:
		btn.text = "已选择"
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
	btn.mouse_entered.connect(func(): AudioManager.play_ui_sfx(AudioLib.get_sound("hover")))
	btn.pressed.connect(func(): AudioManager.play_ui_sfx(AudioLib.get_sound("button_click")))
	UiFx.hover(btn)

func _on_card_hover(card: PanelContainer, unlocked: bool) -> void:
	if not unlocked:
		return
	# 不设 pivot 时节点按左上角缩放，放大后整张卡往右下跑
	card.pivot_offset = card.size * 0.5
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
