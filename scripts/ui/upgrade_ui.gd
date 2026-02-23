extends CanvasLayer
## 升级选择界面

const WeaponManagerScript = preload("res://scripts/weapons/weapon_manager.gd")

const STAT_UPGRADES: Array = [
	{"id": "damage", "name": "攻击强化", "desc": "攻击力 +20%", "icon": "⚔️", "type": "stat"},
	{"id": "speed", "name": "疾风步", "desc": "移动速度 +15%", "icon": "💨", "type": "stat"},
	{"id": "shoot_speed", "name": "连射精通", "desc": "射击速度 +20%", "icon": "🔫", "type": "stat"},
	{"id": "max_hp", "name": "生命之泉", "desc": "最大生命 +20", "icon": "❤️", "type": "stat"},
	{"id": "armor", "name": "铁壁防御", "desc": "护甲 +5", "icon": "🛡️", "type": "stat"},
	{"id": "pickup_range", "name": "磁力吸引", "desc": "拾取范围 +30", "icon": "🧲", "type": "stat"},
]

const WEAPON_UPGRADES: Array = [
	{"id": "shotgun", "name": "散弹枪", "desc": "近距离扇形射击", "icon": "💥", "type": "weapon"},
	{"id": "magic_book", "name": "魔法书", "desc": "自动追踪敌人", "icon": "📖", "type": "weapon"},
	{"id": "throwing_knife", "name": "飞刀", "desc": "穿透多个敌人", "icon": "🔪", "type": "weapon"},
]

var player: Node = null
var weapon_manager: Node = null

signal upgrade_selected

@onready var panel: PanelContainer = $CenterContainer/PanelContainer
@onready var options_container: HBoxContainer = $CenterContainer/PanelContainer/VBoxContainer/OptionsContainer
@onready var title_label: Label = $CenterContainer/PanelContainer/VBoxContainer/TitleLabel

func _ready() -> void:
	visible = false

func show_upgrade(player_node: Node, weapon_mgr: Node = null) -> void:
	player = player_node
	weapon_manager = weapon_mgr
	visible = true
	get_tree().paused = true
	var pool: Array = STAT_UPGRADES.duplicate()
	for wo in WEAPON_UPGRADES:
		pool.append(wo)
	pool.shuffle()
	var selected := pool.slice(0, 3)
	for child in options_container.get_children():
		child.queue_free()
	await get_tree().process_frame
	for option in selected:
		var btn := _create_option_button(option)
		options_container.add_child(btn)
	panel.modulate = Color(1, 1, 1, 0)
	panel.scale = Vector2(0.8, 0.8)
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(panel, "modulate:a", 1.0, 0.2)
	tween.parallel().tween_property(panel, "scale", Vector2.ONE, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func _create_option_button(option: Dictionary) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(180, 120)
	btn.text = "%s\n%s\n%s" % [option["icon"], option["name"], option["desc"]]
	btn.pressed.connect(func(): _on_option_selected(option))
	return btn

func _on_option_selected(option: Dictionary) -> void:
	var option_type: String = option.get("type", "stat")
	if option_type == "stat":
		if player != null and player.has_method("apply_upgrade"):
			player.apply_upgrade(option["id"])
	elif option_type == "weapon":
		if weapon_manager != null and weapon_manager.has_method("add_weapon"):
			var weapon_data = _create_weapon_by_id(option["id"])
			if weapon_data:
				weapon_manager.add_weapon(weapon_data)
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(panel, "modulate:a", 0.0, 0.15)
	tween.tween_callback(func():
		visible = false
		get_tree().paused = false
		upgrade_selected.emit()
	)

func _create_weapon_by_id(weapon_id: String):
	match weapon_id:
		"shotgun":
			return WeaponManagerScript.create_shotgun()
		"magic_book":
			return WeaponManagerScript.create_magic_book()
		"throwing_knife":
			return WeaponManagerScript.create_throwing_knife()
	return null
