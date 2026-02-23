extends Node2D
## 游戏主场景脚本
## 管理整体游戏流程：房间生成、波次战斗、房间切换

const GameRoomScript = preload("res://scripts/map/game_room.gd")
const RoomManagerScript = preload("res://scripts/map/room_manager.gd")
var boss_scene: PackedScene = preload("res://scenes/enemies/vampire_lord.tscn")

@onready var player: CharacterBody2D = $Player
@onready var camera: Camera2D = $Player/Camera2D
@onready var wave_manager = $WaveManager
@onready var weapon_manager = $WeaponManager
@onready var hud = $HUD
@onready var upgrade_ui = $UpgradeUI
@onready var game_over_ui = $GameOverUI
@onready var boss_hp_bar = $BossHPBar

var current_room: Node2D = null
var room_manager: Node = null
var rooms_cleared: int = 0
var transition_overlay: ColorRect = null

func _ready() -> void:
	print("VampireHunter - 游戏启动!")
	# 创建房间管理器
	room_manager = Node.new()
	room_manager.set_script(RoomManagerScript)
	add_child(room_manager)
	
	# 创建过渡遮罩
	_create_transition_overlay()
	
	_connect_signals()
	weapon_manager.setup(player)
	
	# 生成第一个房间
	_create_room(1280.0, 768.0, "combat")
	
	# 同步相机限制
	_setup_camera_limits()
	camera.add_to_group("camera")
	
	# 初始化 HUD
	hud.update_hp(player.current_hp, player.max_hp)
	hud.update_xp(player.current_xp, player.xp_to_next_level, player.current_level)
	
	# 启动波次
	wave_manager.start(player)

func _connect_signals() -> void:
	player.hp_changed.connect(hud.update_hp)
	player.xp_changed.connect(hud.update_xp)
	player.level_up.connect(_on_player_level_up)
	player.player_died.connect(_on_player_died)
	wave_manager.wave_started.connect(hud.update_wave)
	wave_manager.enemy_killed.connect(hud.update_kills)
	wave_manager.wave_completed.connect(_on_wave_completed)
	game_over_ui.restart_requested.connect(_on_restart)
	game_over_ui.menu_requested.connect(_on_return_to_menu)

func _create_room(width: float, height: float, room_type: String) -> void:
	# 清除旧房间
	if current_room != null:
		current_room.queue_free()
		current_room = null
	
	# 创建新房间
	current_room = Node2D.new()
	current_room.set_script(GameRoomScript)
	current_room.room_width = width
	current_room.room_height = height
	current_room.name = "GameRoom"
	add_child(current_room)
	# 移到最底层
	move_child(current_room, 0)
	
	# 连接传送门信号
	current_room.portal_entered.connect(_on_portal_entered)
	
	# 根据房间类型添加障碍物
	match room_type:
		"combat":
			if rooms_cleared > 1:
				current_room.add_pillars(randi_range(2, 4))
		"boss":
			current_room.room_width = 1600.0
			current_room.room_height = 960.0

func _setup_camera_limits() -> void:
	if current_room == null:
		return
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(current_room.room_width)
	camera.limit_bottom = int(current_room.room_height)
	# 把玩家移到房间中心
	player.global_position = current_room.get_center()

func _create_transition_overlay() -> void:
	transition_overlay = ColorRect.new()
	transition_overlay.name = "TransitionOverlay"
	transition_overlay.color = Color(0, 0, 0, 0)
	transition_overlay.size = Vector2(2000, 2000)
	transition_overlay.position = Vector2(-500, -500)
	transition_overlay.z_index = 100
	transition_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(transition_overlay)

# === 房间切换 ===
func _on_wave_completed(wave_number: int) -> void:
	# 每完成一波后出现传送门
	if current_room != null and not current_room.portal_spawned:
		current_room.spawn_portal()

func _on_portal_entered() -> void:
	rooms_cleared += 1
	_transition_to_next_room()

func _transition_to_next_room() -> void:
	wave_manager.stop()
	# 清除所有敌人
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.queue_free()
	
	# 淡出
	var tween := create_tween()
	tween.tween_property(transition_overlay, "color:a", 1.0, 0.3)
	await tween.finished
	
	# 生成新房间
	var room_type: String = room_manager.get_next_room_type()
	var template: Dictionary = room_manager.get_random_template()
	_create_room(
		template["width"] * 32.0,
		template["height"] * 32.0,
		room_type
	)
	_setup_camera_limits()
	
	# 处理特殊房间
	match room_type:
		"shop":
			_enter_shop_room()
		"treasure":
			_enter_treasure_room()
		"rest":
			_enter_rest_room()
		"boss":
			_enter_boss_room()
		_:
			# 普通战斗房间，启动波次
			wave_manager.start(player)
	
	# 更新 HUD 显示当前房间
	hud.update_wave(rooms_cleared)
	
	# 淡入
	var tween2 := create_tween()
	tween2.tween_property(transition_overlay, "color:a", 0.0, 0.3)
	await tween2.finished
	
	print("📍 进入房间 %d [%s]" % [rooms_cleared, room_type])

# === 特殊房间 ===
func _enter_shop_room() -> void:
	print("🏪 商店房间!")
	# 简化版：自动回血 + 给一个随机升级
	if is_instance_valid(player):
		player.heal(player.max_hp * 0.3)
	# 延迟后生成传送门
	await get_tree().create_timer(2.0).timeout
	if current_room:
		current_room.spawn_portal()

func _enter_treasure_room() -> void:
	print("🎁 宝箱房间!")
	# 给玩家一个随机武器
	if weapon_manager:
		var weapon_script = preload("res://scripts/weapons/weapon_manager.gd")
		var weapons := [weapon_script.create_shotgun, weapon_script.create_magic_book]
		var factory: Callable = weapons.pick_random()
		weapon_manager.add_weapon(factory.call())
	# 给经验
	if is_instance_valid(player):
		player.gain_xp(50)
	await get_tree().create_timer(2.0).timeout
	if current_room:
		current_room.spawn_portal()

func _enter_rest_room() -> void:
	print("⛺ 休息站!")
	# 回复 50% 生命
	if is_instance_valid(player):
		player.heal(player.max_hp * 0.5)
	await get_tree().create_timer(2.0).timeout
	if current_room:
		current_room.spawn_portal()

func _enter_boss_room() -> void:
	print("💀 Boss 房间! 吸血鬼领主降临!")
	# 生成 Boss
	var boss := boss_scene.instantiate()
	if current_room:
		boss.global_position = current_room.get_center() + Vector2(0, -100)
	else:
		boss.global_position = Vector2(640, 200)
	
	# 连接 Boss 信号到血条 UI
	if boss.has_signal("boss_hp_changed"):
		boss.boss_hp_changed.connect(boss_hp_bar.update_hp)
	if boss.has_signal("boss_phase_changed"):
		boss.boss_phase_changed.connect(boss_hp_bar.update_phase)
	if boss.has_signal("boss_defeated"):
		boss.boss_defeated.connect(_on_boss_defeated)
	if boss.has_signal("enemy_died"):
		boss.enemy_died.connect(func(_e): pass)  # Boss 不计入波次
	
	get_tree().current_scene.add_child(boss)
	boss_hp_bar.show_boss_bar("吸血鬼领主")

func _on_boss_defeated() -> void:
	boss_hp_bar.hide_boss_bar()
	print("👑 Boss 被击败! 获得丰厚奖励!")
	# 给玩家额外升级
	if is_instance_valid(player):
		player.heal(player.max_hp)  # 回满血
	# 延迟生成传送门
	await get_tree().create_timer(2.0).timeout
	if current_room:
		current_room.spawn_portal()

# === 现有回调 ===
func _on_player_level_up(new_level: int) -> void:
	upgrade_ui.show_upgrade(player, weapon_manager)

func _on_player_died() -> void:
	wave_manager.stop()
	var stats := {
		"wave": wave_manager.current_wave,
		"kills": wave_manager.total_kills,
		"level": player.current_level if is_instance_valid(player) else 1,
		"rooms": rooms_cleared,
	}
	await get_tree().create_timer(0.8).timeout
	game_over_ui.show_game_over(stats)

func _on_restart() -> void:
	get_tree().reload_current_scene()

func _on_return_to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
