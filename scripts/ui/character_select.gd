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
	card.custom_minimum_size = Vector2(280, 360)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	card.add_child(vbox)
	
	var is_unlocked: bool = save_mgr.is_character_unlocked(char_data.char_id) if save_mgr else false
	var is_selected: bool = (save_mgr.get_selected_character() == char_data.char_id) if save_mgr else false
	
	var name_label := Label.new()
	name_label.text = char_data.char_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 20)
	if is_selected:
		name_label.modulate = Color(1.0, 0.8, 0.2)
	vbox.add_child(name_label)
	
	var desc_label := Label.new()
	desc_label.text = char_data.description
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.modulate = Color(0.7, 0.7, 0.7)
	vbox.add_child(desc_label)
	
	var stats_label := Label.new()
	stats_label.text = "❤ HP: %d\n👟 速度: %d\n⚔ 伤害: x%.2f" % [
		int(char_data.base_hp), int(char_data.base_speed), char_data.base_damage_mult
	]
	vbox.add_child(stats_label)
	
	var weapon_label := Label.new()
	weapon_label.text = "🔫 初始: %s" % char_data.initial_weapon
	vbox.add_child(weapon_label)
	
	var passive_label := Label.new()
	passive_label.text = "🌟 %s\n%s" % [char_data.passive_name, char_data.passive_description]
	passive_label.modulate = Color(0.5, 0.9, 1.0)
	vbox.add_child(passive_label)
	
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 40)
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
	
	return card

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
