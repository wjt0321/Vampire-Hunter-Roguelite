extends CanvasLayer
## 升级商店
## 展示永久升级选项和血晶消费

@onready var crystals_label: Label = $Panel/VBoxContainer/Header/CrystalsLabel
@onready var upgrades_container: VBoxContainer = $Panel/VBoxContainer/ScrollContainer/UpgradesContainer
@onready var back_btn: Button = $Panel/VBoxContainer/BackButton

signal shop_closed

var save_mgr: Node

const UPGRADE_INFO: Dictionary = {
	"base_damage": {"name": "基础伤害", "desc": "+5% 武器伤害", "icon": "⚔"},
	"base_hp": {"name": "基础血量", "desc": "+10 最大生命", "icon": "❤"},
	"base_speed": {"name": "基础速度", "desc": "+5% 移动速度", "icon": "👟"},
	"base_armor": {"name": "基础护甲", "desc": "+3 伤害减免", "icon": "🛡"},
	"xp_bonus": {"name": "经验加成", "desc": "+10% 经验获取", "icon": "✨"},
	"blood_crystal_bonus": {"name": "血晶加成", "desc": "+10% 血晶获取", "icon": "💎"},
}

func _ready() -> void:
	visible = false
	back_btn.pressed.connect(_on_back_pressed)
	save_mgr = get_node_or_null("/root/SaveManager")

func show_shop() -> void:
	visible = true
	_refresh_ui()

func _refresh_ui() -> void:
	if not save_mgr:
		return
	crystals_label.text = "💎 血晶: %d" % save_mgr.get_blood_crystals()
	for child in upgrades_container.get_children():
		child.queue_free()
	for upgrade_id in UPGRADE_INFO:
		var info: Dictionary = UPGRADE_INFO[upgrade_id]
		var level: int = save_mgr.get_upgrade_level(upgrade_id)
		var cost: int = save_mgr.get_upgrade_cost(upgrade_id)
		var maxed: bool = save_mgr.is_upgrade_maxed(upgrade_id)
		
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, 40)
		
		var name_label := Label.new()
		name_label.text = "%s %s Lv.%d/%d" % [info["icon"], info["name"], level, 5]
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
			buy_btn.text = "💎 %d" % cost
			buy_btn.disabled = save_mgr.get_blood_crystals() < cost
			var uid: String = upgrade_id
			buy_btn.pressed.connect(func(): _purchase(uid))
		buy_btn.custom_minimum_size = Vector2(100, 0)
		row.add_child(buy_btn)
		
		upgrades_container.add_child(row)

func _purchase(upgrade_id: String) -> void:
	if save_mgr and save_mgr.purchase_upgrade(upgrade_id):
		print("🛒 购买升级: %s" % upgrade_id)
		_refresh_ui()

func _on_back_pressed() -> void:
	visible = false
	shop_closed.emit()
