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

const PASSIVE_UPGRADES: Array = [
	{"id": "magnet", "name": "经验磁铁", "desc": "经验吸附范围 +30%", "icon": "🧲", "type": "passive"},
	{"id": "shield", "name": "能量护盾", "desc": "定期生成护盾", "icon": "🛡️", "type": "passive"},
	{"id": "regeneration", "name": "生命恢复", "desc": "每5秒恢复生命", "icon": "💚", "type": "passive"},
	{"id": "greed_ring", "name": "贪婪戒指", "desc": "经验获取 +20%", "icon": "💍", "type": "passive"},
	{"id": "berserker_blood", "name": "狂战士之血", "desc": "低血量时伤害 +50%", "icon": "🩸", "type": "passive"},
	{"id": "frozen_heart", "name": "冰冻之心", "desc": "10%几率冻结敌人", "icon": "❄️", "type": "passive"},
	{"id": "lightning_shield", "name": "闪电护符", "desc": "受击时闪电反击", "icon": "⚡", "type": "passive"},
	{"id": "shadow_cloak", "name": "影子披风", "desc": "闪避几率 +5%", "icon": "🌑", "type": "passive"},
]

const WEAPON_UPGRADES: Array = [
	{"id": "shotgun", "name": "散弹枪", "desc": "近距离扇形射击", "icon": "💥", "type": "weapon"},
	{"id": "magic_book", "name": "魔法书", "desc": "自动追踪敌人", "icon": "📖", "type": "weapon"},
	{"id": "throwing_knife", "name": "飞刀", "desc": "穿透多个敌人", "icon": "🔪", "type": "weapon"},
	{"id": "poison_cloud", "name": "毒雾瓶", "desc": "持续伤害区域", "icon": "☠️", "type": "weapon"},
	{"id": "lightning_chain", "name": "闪电法杖", "desc": "闪电链跳跃", "icon": "⚡", "type": "weapon"},
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
	
	# 构建可用选项池
	var available_options := _get_available_options()
	
	# 如果没有可用选项，提供基础奖励
	if available_options.is_empty():
		available_options = _get_basic_rewards()
	
	available_options.shuffle()
	var selected := available_options.slice(0, mini(3, available_options.size()))
	
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

func _get_available_options() -> Array:
	## 获取可用的升级选项
	var available: Array = []
	
	# 添加属性升级（总是可用）
	available.append_array(STAT_UPGRADES.duplicate())
	
	# 添加武器选项（排除已进化的）
	for weapon_opt in WEAPON_UPGRADES:
		if not _is_weapon_evolved(weapon_opt["id"]):
			available.append(weapon_opt)
	
	# 添加被动道具选项（排除已满级的）
	for passive_opt in PASSIVE_UPGRADES:
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
	elif option_type == "passive":
		if player != null and player.has_method("add_passive_item"):
			var passive_data = _create_passive_by_id(option["id"])
			if passive_data:
				player.add_passive_item(passive_data)
	elif option_type == "basic":
		_apply_basic_reward(option["id"])
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(panel, "modulate:a", 0.0, 0.15)
	tween.tween_callback(func():
		visible = false
		get_tree().paused = false
		upgrade_selected.emit()
	)

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

func _create_weapon_by_id(weapon_id: String):
	match weapon_id:
		"shotgun":
			return WeaponManagerScript.create_shotgun()
		"magic_book":
			return WeaponManagerScript.create_magic_book()
		"throwing_knife":
			return WeaponManagerScript.create_throwing_knife()
		"poison_cloud":
			return WeaponManagerScript.create_poison_cloud()
		"lightning_chain":
			return WeaponManagerScript.create_lightning_chain()
	return null

func _create_passive_by_id(passive_id: String):
	match passive_id:
		"magnet":
			return preload("res://scripts/player/passive_item_data.gd").create_magnet()
		"shield":
			return preload("res://scripts/player/passive_item_data.gd").create_shield()
		"regeneration":
			return preload("res://scripts/player/passive_item_data.gd").create_regeneration()
		"greed_ring":
			return preload("res://scripts/player/passive_item_data.gd").create_greed_ring()
		"berserker_blood":
			return preload("res://scripts/player/passive_item_data.gd").create_berserker_blood()
		"frozen_heart":
			return preload("res://scripts/player/passive_item_data.gd").create_frozen_heart()
		"lightning_shield":
			return preload("res://scripts/player/passive_item_data.gd").create_lightning_shield()
		"shadow_cloak":
			return preload("res://scripts/player/passive_item_data.gd").create_shadow_cloak()
	return null
