extends CanvasLayer
## 升级商店
## 展示永久升级选项和血晶消费

@onready var crystals_label: Label = $Panel/VBoxContainer/Header/CrystalsLabel
@onready var upgrades_container: VBoxContainer = $Panel/VBoxContainer/ScrollContainer/UpgradesContainer
@onready var back_btn: Button = $Panel/VBoxContainer/BackButton

signal shop_closed

var save_mgr: Node

## 元进度 6 项没有自己的贴图，复用语义相近的物品图标。
## （原来的 "icon": "攻"/"命"… 单字字段已删：贴图永远能命中，
##   留着单字就等于把"用字符当图标"的口子一直开着。）
const UPGRADE_INFO: Dictionary = {
	"base_damage": {"name": "基础伤害", "desc": "+5% 武器伤害"},
	"base_hp": {"name": "基础血量", "desc": "+10 最大生命"},
	"base_speed": {"name": "基础速度", "desc": "+5% 移动速度"},
	"base_armor": {"name": "基础护甲", "desc": "+3 伤害减免"},
	"xp_bonus": {"name": "经验加成", "desc": "+10% 经验获取"},
	"blood_crystal_bonus": {"name": "血晶加成", "desc": "+10% 血晶获取"},
}

func _ready() -> void:
	visible = false
	back_btn.pressed.connect(_on_back_pressed)
	save_mgr = get_node_or_null("/root/SaveManager")
	_setup_panel_style()
	_setup_back_button_style()

func _setup_panel_style() -> void:
	var panel_texture := TextureManager.instance.get_ui_texture("stats_panel")
	if panel_texture:
		var style := StyleBoxTexture.new()
		style.texture = panel_texture
		# 贴图 400×300 里，金色花纹本身左右各约 48px、上 62px、下 60px。
		# 之前只写了 content_margin=30，比花纹还窄，文字就压在框线外面。
		# 现在两件事一起做：
		#   ① texture_margin 九宫格 —— 角上的宝石和花纹按原尺寸绘制，不再被拉伸 1.5 倍变糊；
		#   ② content_margin 在花纹内侧再让 8px，保证文字不贴花。
		style.texture_margin_left = 48
		style.texture_margin_right = 48
		style.texture_margin_top = 62
		style.texture_margin_bottom = 60
		style.content_margin_left = 56
		style.content_margin_right = 56
		style.content_margin_top = 70
		style.content_margin_bottom = 68
		$Panel.add_theme_stylebox_override("panel", style)

func _setup_back_button_style() -> void:
	_apply_button_texture(back_btn)

func _apply_button_texture(btn: Button) -> void:
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

func show_shop() -> void:
	visible = true
	_refresh_ui()
	UiFx.pop_in($Panel, 0.16, 0.97)

func _upgrade_icon_item(upgrade_id: String) -> String:
	## 元进度 6 项没有自己的贴图，复用语义相近的物品图标
	match upgrade_id:
		"base_damage": return "damage"
		"base_hp": return "max_hp"
		"base_speed": return "speed"
		"base_armor": return "armor"
		"xp_bonus": return "magnet"
		"blood_crystal_bonus": return "gold"
	return ""

func _refresh_ui() -> void:
	if not save_mgr:
		return
	crystals_label.text = "血晶: %d" % save_mgr.get_blood_crystals()
	for child in upgrades_container.get_children():
		child.queue_free()
	for upgrade_id in UPGRADE_INFO:
		var info: Dictionary = UPGRADE_INFO[upgrade_id]
		var level: int = save_mgr.get_upgrade_level(upgrade_id)
		var cost: int = save_mgr.get_upgrade_cost(upgrade_id)
		var maxed: bool = save_mgr.is_upgrade_maxed(upgrade_id)
		
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, 40)
		
		# 图标：贴图优先（复用统一映射）
		var icon_tex: Texture2D = ItemCatalog.get_icon_texture(_upgrade_icon_item(upgrade_id))
		var name_label := Label.new()
		name_label.text = "%s Lv.%d/%d" % [info["name"], level, 5]
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if icon_tex != null:
			var icon_rect := TextureRect.new()
			icon_rect.texture = icon_tex
			icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon_rect.custom_minimum_size = Vector2(22, 22)
			icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(icon_rect)
		row.add_child(name_label)
		
		var desc_label := Label.new()
		desc_label.text = info["desc"]
		desc_label.modulate = Color(0.7, 0.7, 0.7)
		row.add_child(desc_label)
		
		var buy_btn := Button.new()
		if maxed:
			buy_btn.text = "已满级"
			buy_btn.disabled = true
		else:
			buy_btn.text = "血晶 %d" % cost
			buy_btn.disabled = save_mgr.get_blood_crystals() < cost
			var uid: String = upgrade_id
			buy_btn.pressed.connect(func(): _purchase(uid))
		buy_btn.custom_minimum_size = Vector2(100, 0)
		_apply_button_texture(buy_btn)
		row.add_child(buy_btn)
		
		upgrades_container.add_child(row)

func _purchase(upgrade_id: String) -> void:
	if save_mgr and save_mgr.purchase_upgrade(upgrade_id):
		print("🛒 购买升级: %s" % upgrade_id)
		_refresh_ui()

func _on_back_pressed() -> void:
	visible = false
	shop_closed.emit()
