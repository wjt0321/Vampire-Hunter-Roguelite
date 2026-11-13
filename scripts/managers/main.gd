extends Node2D
## 游戏主场景脚本
## 管理整体游戏流程：房间生成、波次战斗、房间切换

const GameRoomScript = preload("res://scripts/map/game_room.gd")
const RoomManagerScript = preload("res://scripts/map/room_manager.gd")
const DungeonManagerScript = preload("res://scripts/map/dungeon_manager.gd")
const FloorBannerScript = preload("res://scripts/ui/floor_banner.gd")
const CharacterDataScript = preload("res://scripts/player/character_data.gd")
const RoomEventScript = preload("res://scripts/managers/room_event_manager.gd")
var boss_scene: PackedScene = preload("res://scenes/enemies/vampire_lord.tscn")
var run_log: Node = null

# 缓存的 AudioLibrary 实例
var _audio_lib: AudioLibrary = null

@onready var player: CharacterBody2D = $Player
@onready var camera: Camera2D = $Player/Camera2D
@onready var wave_manager = $WaveManager
@onready var weapon_manager = $WeaponManager
@onready var hud = $HUD
@onready var upgrade_ui = $UpgradeUI
@onready var game_over_ui = $GameOverUI
@onready var boss_hp_bar = $BossHPBar

var current_room: Node2D = null
var _current_room_type: String = ""
var room_manager: Node = null
var dungeon: Node = null
var floor_banner: CanvasLayer = null
var room_shop: CanvasLayer = null
var blood_pact: CanvasLayer = null
var mutation_ui: CanvasLayer = null
var fog_overlay: Node2D = null
var rooms_cleared: int = 0
var transition_overlay: ColorRect = null
## 局内目标事件（17.14）：战斗房的小目标管理器
var room_events: Node = null
## 测试注入点：非空时忽略存档里选中的角色（见 _apply_selected_character）。
## 必须在 add_child 之前赋值，因为 _ready 里就会读。
var debug_force_character: String = ""
## 测试注入点：非空时深渊推进/结算用这个存档对象，不碰真实 SaveManager。
var debug_save_manager: Node = null
## 深渊契约：本层是否生效，以及被扣掉的生命上限绝对值（层末归还）
var pact_active: bool = false
var pact_hp_penalty: float = 0.0
## Boss 击败结算防重标志（每层 Boss 房重置）
var _boss_defeat_handled: bool = false
## 升级弹窗队列：一次吃下多颗经验宝石时 level_up 会连续发多次，
## 而升级界面是单例的。不做队列的话后一次会把前一次的选项直接顶掉（玩家白丢一次升级）。
var _pending_upgrades: int = 0
var _upgrade_open: bool = false
var _run_token: int = 0
var _room_token: int = 0
var _room_transitioning: bool = false
var _terminal_state: String = ""
var _boss_damage_baseline: float = 0.0
var debug_loot_grace_seconds: int = -1

func _begin_terminal_state(state: String) -> bool:
	if state == "death":
		if _terminal_state == "death":
			return false
		_terminal_state = "death"
		_run_token += 1
	elif state == "victory":
		if _terminal_state != "":
			return false
		_terminal_state = "victory"
	else:
		return false
	# 死亡和最终胜利都取消升级，包含关闭动画与尚未打开的队列。
	_pending_upgrades = 0
	_upgrade_open = false
	if upgrade_ui != null and upgrade_ui.has_method("dismiss_for_game_over"):
		upgrade_ui.dismiss_for_game_over()
	return true

func _lifecycle_token_valid(run_token: int, room_token: int = -1, room: Node = null) -> bool:
	if not is_instance_valid(self) or run_token != _run_token:
		return false
	if room_token >= 0 and room_token != _room_token:
		return false
	if room != null and (not is_instance_valid(room) or room != current_room):
		return false
	return true

func _ready() -> void:
	print("VampireHunter - 游戏启动!")
	var initial_achievements := get_node_or_null("/root/AchievementManager")
	if initial_achievements:
		initial_achievements.start_new_run()
	_run_token += 1
	_audio_lib = AudioLib

	# 深渊镜像：存档是 best_abyss 真值源，GameConfig 只是运行时副本
	var save_mirror := get_node_or_null("/root/SaveManager")
	if save_mirror:
		GameConfig.best_abyss = save_mirror.get_best_abyss()
	if GameConfig.abyss_level > 0:
		print("🌀 深渊 %d 轮开局：敌人血量 ×%.2f / 伤害 ×%.2f / 掉落 ×%.2f" % [
			GameConfig.abyss_level, GameConfig.get_abyss_hp_mult(),
			GameConfig.get_abyss_damage_mult(), GameConfig.get_abyss_loot_mult()])

	# 创建房间管理器
	room_manager = Node.new()
	room_manager.set_script(RoomManagerScript)
	add_child(room_manager)
	room_manager.setup(player)

	# 创建地下城管理器
	dungeon = Node.new()
	dungeon.set_script(DungeonManagerScript)
	add_child(dungeon)
	run_log = Node.new()
	run_log.name = "RunLog"
	run_log.set_script(preload("res://scripts/managers/run_log.gd"))
	add_child(run_log)
	if player != null and player.has_signal("damage_received"):
		player.damage_received.connect(run_log.note_damage)

	# 局内目标事件（17.14）：必须在 wave_manager/player/hud 都就绪后 setup
	room_events = Node.new()
	room_events.set_script(RoomEventScript)
	add_child(room_events)
	room_events.setup(wave_manager, player, hud)

	# 创建过渡遮罩与楼层横幅
	_create_transition_overlay()
	_create_floor_banner()
	_create_room_shop()
	_create_blood_pact()
	_create_mutation_ui()

	_connect_signals()

	# 应用选中的角色数据
	var initial_weapon_id := _apply_selected_character()
	# 应用血晶购买的永久升级
	_apply_permanent_upgrades()
	weapon_manager.setup(player, initial_weapon_id)

	camera.add_to_group("camera")

	# 初始化 HUD
	if hud.has_method("bind_run"):
		hud.bind_run(player, weapon_manager)
	# 难度软挂钩：把"玩家当前理论 DPS"喂给波次管理器，由它在每波边界算软因子
	wave_manager.dps_provider = _estimate_player_dps
	hud.update_hp(player.current_hp, player.max_hp)
	hud.update_xp(player.current_xp, player.xp_to_next_level, player.current_level)
	hud.update_silver(player.silver)
	_refresh_evolution_hint()

	# 开始地下城：生成楼层房间序列并进入第一间（先不启动波次，等提示播完）
	# 先连信号再 start_dungeon()：start_dungeon 会同步 emit floor_started，
	# 晚连会让首层 on_floor_changed 根本不执行（一层一次的标记就不会重置）
	_apply_daily_rules()
	dungeon.floor_started.connect(_on_floor_started)
	dungeon.floor_cleared.connect(_on_floor_cleared)
	dungeon.dungeon_cleared.connect(_on_dungeon_cleared)
	dungeon.start_dungeon()
	_enter_next_room(false)
	await get_tree().create_timer(0.3).timeout
	await _show_current_floor_intro()

	# 提示结束后才正式开战
	AudioManager.play_bgm(_audio_lib.get_battle_bgm())
	wave_manager.start(player)
	# 首房走 autostart=false，但仍要计入本层战斗房数；否则“第 2 间起”会错成第 3 间。
	if room_events:
		room_events.on_combat_room_entered(dungeon.current_floor)

	# 成就时钟已在初始化阶段启动，避免开场提示漏计时间。


func _exit_tree() -> void:
	# 暂停菜单可直接换场景；在退出本局的统一生命周期停止时钟。
	var ach_mgr := get_node_or_null("/root/AchievementManager")
	if ach_mgr:
		ach_mgr.finish_run()

func _estimate_player_dps() -> float:
	## 当前构筑的理论 DPS，供波次管理器做难度软挂钩。
	## 只算"武器基础输出 × 伤害倍率 × 暴击期望"，不含场景加成：
	## 软因子是慢变量，多算少算 10% 只影响它偏一点，不影响玩家感知。
	if weapon_manager == null or player == null or not is_instance_valid(player):
		return 0.0
	var base: float = weapon_manager.estimate_run_dps()
	base *= player.get_total_damage_multiplier()
	# 暴击期望：暴击率 p、暴击倍率 m → 期望倍率 1 + p(m-1)
	base *= 1.0 + player.crit_chance * (GameConfig.PLAYER_CRIT_DAMAGE - 1.0)
	return base


func _apply_permanent_upgrades() -> void:
	## 把存档里的永久升级（血晶购买）真正作用到玩家身上

	var save_mgr := get_node_or_null("/root/SaveManager")
	if save_mgr == null or player == null:
		return

	var bonus_damage: float = save_mgr.get_bonus_damage()
	var bonus_hp: float = save_mgr.get_bonus_hp()
	var bonus_speed: float = save_mgr.get_bonus_speed()
	var bonus_armor: float = save_mgr.get_bonus_armor()
	var bonus_xp: float = save_mgr.get_bonus_xp()

	if bonus_damage > 0.0:
		player.damage_multiplier += bonus_damage
	if bonus_hp > 0.0:
		player.max_hp += bonus_hp
		player.current_hp = minf(player.current_hp + bonus_hp, player.max_hp)
	if bonus_speed > 0.0:
		player.move_speed *= (1.0 + bonus_speed)
	if bonus_armor > 0.0:
		player.armor += bonus_armor
	if bonus_xp > 0.0:
		player.xp_bonus_multiplier += bonus_xp

	print("💎 永久升级已应用: 伤害+%.0f%% 生命+%.0f 速度+%.0f%% 护甲+%.0f 经验+%.0f%%" % [
		bonus_damage * 100.0, bonus_hp, bonus_speed * 100.0, bonus_armor, bonus_xp * 100.0
	])

func _apply_selected_character() -> String:
	## 读取存档中的选中角色并应用
	var save_mgr := get_node_or_null("/root/SaveManager")
	var selected_id := "hunter"
	if save_mgr:
		selected_id = save_mgr.get_selected_character()
	# 测试注入点：在 add_child 之前赋值即可覆盖存档里的角色。
	## 为什么需要：回归测试是围绕猎人（手枪开局）写的，而玩家的存档随时可能是
	## 女祭司（法球开局，且 base_speed / base_damage 都不同）。
	## 测试一旦依赖"当前存档选了谁"，同一个提交会时绿时红 —— 这类失败最难查。
	if debug_force_character != "":
		selected_id = debug_force_character

	var char_data = null
	for c in CharacterDataScript.get_all_characters():
		if c.char_id == selected_id:
			char_data = c
			break
	
	if char_data and player.has_method("apply_character_data"):
		player.apply_character_data(char_data)
		return char_data.initial_weapon
	
	return "pistol"

func _connect_signals() -> void:
	player.hp_changed.connect(hud.update_hp)
	if player.has_signal("damage_received"):
		player.damage_received.connect(_on_player_damage_received)
	player.xp_changed.connect(hud.update_xp)
	player.silver_changed.connect(hud.update_silver)
	player.level_up.connect(_on_player_level_up)
	player.player_died.connect(_on_player_died)
	wave_manager.wave_started.connect(hud.update_wave)
	wave_manager.wave_started.connect(_on_wave_started)
	wave_manager.enemy_killed.connect(hud.update_kills)
	wave_manager.enemy_killed.connect(_on_enemy_killed)
	wave_manager.wave_completed.connect(_on_wave_completed)
	weapon_manager.weapon_evolved.connect(_on_weapon_evolved)
	if weapon_manager.has_signal("weapon_added"):
		weapon_manager.weapon_added.connect(_on_weapon_added)
	weapon_manager.weapon_leveled_up.connect(_on_weapon_leveled_up)
	upgrade_ui.upgrade_selected.connect(_on_upgrade_selected)
	game_over_ui.restart_requested.connect(_on_restart)
	game_over_ui.menu_requested.connect(_on_return_to_menu)
	game_over_ui.abyss_continue_requested.connect(_on_abyss_continue)

func _create_room(width: float, height: float, room_type: String, theme: String = "") -> void:
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

	# 根据房间类型预布置（必须在 add_child 前完成，以影响 _ready 中的主题生成）
	match room_type:
		"boss":
			current_room.room_theme = "boss"
			current_room.room_width = 2080.0
			current_room.room_height = 1248.0
		"shop":
			current_room.setup_shop_room()
		"treasure":
			current_room.setup_treasure_room()
		"rest":
			current_room.setup_rest_room()
		"mutation":
			current_room.setup_mutation_room()
		"fog", "mirror":
			current_room.room_theme = theme if theme != "" else "dungeon"
		_:
			current_room.room_theme = theme if theme != "" else _get_combat_theme()

	add_child(current_room)
	# 移到最底层
	move_child(current_room, 0)

	# 连接传送门信号
	current_room.portal_entered.connect(_on_portal_entered)
	current_room.portal_chosen.connect(_on_portal_chosen)

	# 根据房间类型添加障碍物与装饰（在场景树中操作）
	match room_type:
		"combat", "fog", "mirror":
			if rooms_cleared > 1:
				current_room.add_pillars(randi_range(2, 4))
				current_room.add_props(randi_range(1, 3))
			current_room.add_decorations(randi_range(2, 5))
			if room_type == "mirror":
				current_room.apply_mirror()
		"boss":
			current_room.add_pillars(randi_range(4, 7))
			current_room.add_props(randi_range(2, 4))
			current_room.add_decorations(randi_range(3, 6))

func _get_combat_theme() -> String:
	## 普通战斗房间在几个主题间轮换
	var themes: Array = ["dungeon", "castle", "cave"]
	return themes[rooms_cleared % themes.size()]

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

func _create_floor_banner() -> void:
	floor_banner = CanvasLayer.new()
	floor_banner.set_script(FloorBannerScript)
	floor_banner.name = "FloorBanner"
	floor_banner.layer = 90
	add_child(floor_banner)

func _create_room_shop() -> void:
	## 局内商店（房间内购买）。全部代码构建，不需要 .tscn。
	room_shop = CanvasLayer.new()
	room_shop.name = "RoomShop"
	room_shop.set_script(preload("res://scripts/ui/room_shop.gd"))
	add_child(room_shop)

func _create_mutation_ui() -> void:
	mutation_ui = CanvasLayer.new()
	mutation_ui.name = "MutationAltar"
	mutation_ui.set_script(preload("res://scripts/ui/mutation_altar_ui.gd"))
	add_child(mutation_ui)

func _create_blood_pact() -> void:
	## 血之祭坛（休息房二选一）。同样全部代码构建。
	blood_pact = CanvasLayer.new()
	blood_pact.name = "BloodPact"
	blood_pact.set_script(preload("res://scripts/ui/blood_pact_ui.gd"))
	add_child(blood_pact)

# === 房间切换 ===
func _on_wave_completed(wave_number: int) -> void:
	# 每完成一波后出现传送门
	if dungeon != null and dungeon.current_variant() == "leyline" and is_instance_valid(player) and player.has_method("add_silver"):
		player.add_silver(12)
	if dungeon != null and dungeon.current_variant() == "quiet_antechamber" and is_instance_valid(player) and player.has_method("heal"):
		player.heal(player.max_hp * 0.12)
	if current_room != null and not current_room.portal_spawned:
		AudioManager.play_sfx(_audio_lib.get_sound("room_clear"))
		_open_room_exit(current_room)
	# 波次标签别继续挂着波次号让人以为还有活怪——写明已清
	if hud and hud.has_method("set_wave_status"):
		hud.set_wave_status("出口已开启 · 走传送门", true)

func _on_portal_chosen(room_type: String) -> void:
	if dungeon:
		dungeon.choose_next(room_type)
	_on_portal_entered()

func _on_portal_entered() -> void:
	if _room_transitioning or _terminal_state == "death":
		return
	_room_transitioning = true
	AudioManager.play_sfx(_audio_lib.get_sound("teleport"))
	_transition_to_next_room()

func _transition_to_next_room() -> void:
	if _terminal_state == "death":
		_room_transitioning = false
		return
	var run_token := _run_token
	var old_room_token := _room_token
	wave_manager.stop()
	# 换房前先把地上没捡的经验结算掉：宝石是房间节点的子节点，
	# 房间一释放它们就跟着没了，不结算等于玩家白丢经验
	wave_manager.settle_xp_gems()
	# 清除所有敌人与残留掉落物（掉落物带着旧房间的坐标，带过去会出现在墙里）
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.queue_free()
	for powerup in get_tree().get_nodes_in_group("powerups"):
		powerup.queue_free()
	_clear_enemy_projectiles()

	# 淡出
	# 注意：这里用 timer 而不是 await tween.finished。
	# 嵌套协程里 await Tween.finished 存在丢信号的风险（tween 已完成但协程不恢复），
	# 表现为换层时整局卡死在黑屏。
	var fade_out := create_tween()
	fade_out.tween_property(transition_overlay, "color:a", 1.0, 0.3)
	await get_tree().create_timer(0.3, false).timeout
	if not _lifecycle_token_valid(run_token, old_room_token) or _terminal_state == "death":
		_room_transitioning = false
		return

	print("🚪 切换房间 → 第 %d 层 第 %d 间" % [dungeon.current_floor, dungeon.room_in_floor + 1])
	# 只调用一次！曾经这里和下面各写了一次 _enter_next_room()，
	# 导致每换一间房都会生成两个房间、两个 Boss，房间计数还会越界（6/6 → 7/6）。
	_enter_next_room()

	# 淡入
	var fade_in := create_tween()
	fade_in.tween_property(transition_overlay, "color:a", 0.0, 0.3)
	await get_tree().create_timer(0.3, false).timeout
	if not _lifecycle_token_valid(run_token) or _terminal_state == "death":
		_room_transitioning = false
		return
	_room_transitioning = false

func _enter_next_room(autostart: bool = true) -> String:
	## 从地下城取出下一个房间并布置，返回房间类型
	if _terminal_state == "death":
		return ""
	_room_token += 1
	# 事件不跨房：玩家迈出房间的那一刻，没做完的事件就算失败（奖励不追发）
	if room_events:
		room_events.cancel()
	_clear_fog()
	if wave_manager:
		wave_manager.mirror_spawns = false
		wave_manager.set_room_loot_mult(1.0)
	var room_type: String = dungeon.consume_room()
	_current_room_type = room_type
	rooms_cleared = dungeon.rooms_cleared_total

	# 同步层敌人池与层倍率。第三个参数是"本层已清的战斗房数"，
	# 远程敌人靠它逐间解禁。
	# 口径必须是**战斗房**而不是房间序号：商店/宝箱/休息房也要占一间房，
	# 旧口径下第 1 层第 3 间（哪怕是宝箱房）就把解禁名额用光了，
	# 结果整层一个射手都不刷。DungeonManager 在 consume_room 里记好了这个数。
	wave_manager.set_floor(dungeon.current_floor, dungeon.get_enemy_pool(),
		dungeon.combat_rooms_before_current)
	if run_log != null:
		run_log.note_room(dungeon.current_floor, room_type, dungeon.current_variant(), wave_manager._encounter_id)

	var template: Dictionary = room_manager.get_random_template()
	var themed := room_type == "combat" or room_type == "fog" or room_type == "mirror"
	var theme: String = dungeon.get_combat_theme() if themed else ""
	_create_room(
		template["width"] * 32.0,
		template["height"] * 32.0,
		room_type,
		theme
	)
	_setup_camera_limits()
	_update_dungeon_hud()

	# 记录房间成就
	var ach_mgr := get_node_or_null("/root/AchievementManager")
	if ach_mgr:
		ach_mgr.update_rooms(rooms_cleared)

	# 非战斗房没有波次：把 HUD 的波次标签换成房间名。
	# 否则进了宝箱房，标签还挂着上一波的 "Wave 4"，房间却空的（试玩反馈）
	if room_type != "combat" and hud and hud.has_method("set_wave_status"):
		# 房间名表在 GameConfig：HUD 那边要拿 "BOSS" 判断"退出 Boss 战别复活占位文案"，
		# 两处各写一份字面量的话，改一边就会出现"标签还在闪、判定已经不认识它"。
		hud.set_wave_status(String(GameConfig.ROOM_LABELS.get(room_type, "—")))

	# 上一间的事件行不要带到这间。迷雾/镜像/变异会在自己的入口里重写。
	if hud and hud.has_method("set_event_status"):
		hud.set_event_status("")

	# 处理特殊房间
	match room_type:
		"shop":
			_enter_shop_room()
		"treasure":
			_enter_treasure_room()
		"rest":
			_enter_rest_room()
		"mutation":
			_enter_mutation_room()
		"fog":
			_enter_fog_room(autostart)
		"mirror":
			_enter_mirror_room(autostart)
		"boss":
			_enter_boss_room()
		_:
			# 普通战斗房间，切换回战斗 BGM 并启动波次
			AudioManager.play_bgm(_audio_lib.get_battle_bgm())
			if autostart:
				wave_manager.start(player)
				_apply_room_variant()
				_apply_floor_rule()
				# 事件敌人在 start 之后刷（spawn_special_enemy 要挂到当前场景）；
				# 一间房判定一次，触发与否都由它自己打印
				if room_events:
					room_events.on_combat_room_entered(dungeon.current_floor)

	print("📍 第 %d 层 · 房间 %d/%d [%s]" % [
		dungeon.current_floor,
		dungeon.room_in_floor,
		dungeon.get_room_count(),
		room_type
	])
	return room_type

func _update_dungeon_hud() -> void:
	if hud and hud.has_method("update_dungeon"):
		hud.update_dungeon(
			dungeon.current_floor,
			dungeon.room_in_floor,
			dungeon.get_room_count(),
			dungeon.get_floor_name()
		)

# === 特殊房间 ===
func _enter_shop_room() -> void:
	print("🏪 商店房间!")
	AudioManager.play_bgm(_audio_lib.get_shop_bgm())
	var ach_mgr := get_node_or_null("/root/AchievementManager")
	if ach_mgr:
		ach_mgr.record_room_visit("shop")

	# 进门给一点基础回复，避免"没钱＝白跑一间房"
	if is_instance_valid(player):
		player.heal(player.max_hp * 0.2)

	var room: Node2D = current_room
	if room_shop == null:
		_open_portal_after_delay(1.0)
		return

	# 等换房淡入结束再弹货架，否则玩家只看到"黑屏上突然出现商店"
	await get_tree().create_timer(0.5).timeout
	if not is_instance_valid(room) or not is_instance_valid(self) or room != current_room:
		return

	# 打开商店；关闭后才开传送门（一次性连接，避免多次进商店重复触发）
	room_shop.open(player, weapon_manager, dungeon.current_floor if dungeon else 1)
	room_shop.shop_closed.connect(func():
		if is_instance_valid(room) and is_instance_valid(self) and room == current_room:
			_open_room_exit(room)
	, CONNECT_ONE_SHOT)

func _enter_treasure_room() -> void:
	print("🎁 宝箱房间!")
	AudioManager.play_sfx(_audio_lib.get_sound("chest_open"))
	var ach_mgr := get_node_or_null("/root/AchievementManager")
	if ach_mgr:
		ach_mgr.record_room_visit("treasure")

	# 进化是"事件"：宝箱是唯一入口。条件齐了就在这里进化，没齐就还是普通奖励。
	var evolved: Array = []
	if weapon_manager and is_instance_valid(player) and player.has_method("get_owned_passive_items"):
		evolved = weapon_manager.try_evolve_from_chest(player.get_owned_passive_items())

	if not evolved.is_empty():
		_announce_evolution(evolved)
	elif weapon_manager:
		var slots_full: bool = weapon_manager.weapons.size() >= GameConfig.MAX_WEAPON_SLOTS
		var weapon_script = preload("res://scripts/weapons/weapon_manager.gd")
		var weapons := [weapon_script.create_shotgun, weapon_script.create_magic_book]
		if slots_full:
			# 武器槽已满：改为给经验 + 银币，避免绕过槽位限制无限堆武器。
			# 只给经验时玩家进房看到的是"空房间 + 一句提示"，体感等于白跑一间；
			# 补一份银币，这个房间至少有实打实的东西可拿。
			print("🎁 武器槽已满，宝箱转化为 经验 + 银币")
			if is_instance_valid(player):
				player.gain_xp(80)
				player.add_silver(40)
			if hud and hud.has_method("set_wave_status"):
				hud.set_wave_status("宝 箱 · 已转化为 经验+80 银币+40", true)
		else:
			var factory: Callable = weapons.pick_random()
			weapon_manager.add_weapon(factory.call())

	if is_instance_valid(player):
		player.gain_xp(50)
	_refresh_evolution_hint()
	_open_portal_after_delay(2.0)

func _announce_evolution(evolved: Array) -> void:
	## 宝箱进化演出：横幅 + 光效（进化是单局里最值得庆祝的时刻）
	var names: Array = []
	for entry in evolved:
		names.append(String(entry.get("name", "")))
	var text: String = "、".join(names)
	print("✨ 宝箱进化：%s" % text)

	if hud and hud.has_method("show_evolution_banner"):
		hud.show_evolution_banner(text)
	var vfx := get_node_or_null("/root/VFXManager")
	if vfx and is_instance_valid(player):
		vfx.spawn_evolution_effect(player.global_position, Color(1.0, 0.86, 0.42))
		vfx.screen_shake(6.0, 0.3)
	if floor_banner and floor_banner.has_method("show_card"):
		floor_banner.show_card(
			"武器进化",
			text,
			"EVOLVED",
			"宝箱的力量已注入你的武器",
			Color(1.0, 0.86, 0.42),
			1.4
		)

func _enter_rest_room() -> void:
	## 休息房 = 血之祭坛：安息（回血）或缔约（卖本层上限换本层收益）
	print("⛺ 休息站!")
	var ach_mgr := get_node_or_null("/root/AchievementManager")
	if ach_mgr:
		ach_mgr.record_room_visit("rest")

	var room: Node2D = current_room
	if blood_pact == null:
		# 兜底：祭坛没建起来就退回老行为，绝不能把玩家卡在没有出口的房间里
		_apply_rest_heal()
		_open_portal_after_delay(1.5)
		return

	# 等换房淡入结束再弹，否则玩家只看到黑屏上突然压了个面板
	await get_tree().create_timer(0.5).timeout
	if not is_instance_valid(room) or not is_instance_valid(self) or room != current_room:
		return

	blood_pact.open(player, dungeon.current_floor)
	blood_pact.pact_chosen.connect(func(kind: String):
		_on_pact_chosen(kind)
		if is_instance_valid(room) and is_instance_valid(self) and room == current_room:
			_open_room_exit(room)
	, CONNECT_ONE_SHOT)

func _on_pact_chosen(kind: String) -> void:
	if kind == "pact":
		_apply_blood_pact()
	else:
		_apply_rest_heal()

func _apply_rest_heal() -> void:
	if is_instance_valid(player):
		player.heal(player.max_hp * GameConfig.BLOOD_PACT_REST_HEAL_RATIO)
		print("🕯 安息：恢复 %.0f 生命" % (player.max_hp * GameConfig.BLOOD_PACT_REST_HEAL_RATIO))

func _apply_blood_pact() -> void:
	## 缔约：扣本层生命上限，换本层敌人更多 + 掉落更高。
	## 同一层只允许一次——否则连开两间休息房能把上限卖到 64%，
	## 而收益是叠乘的，等于逼玩家必须连点两次契约，这就不是选择了。
	if not is_instance_valid(player):
		return
	if pact_active:
		print("🩸 本层已缔约，改为安息")
		_apply_rest_heal()
		return

	var penalty: float = player.max_hp * GameConfig.BLOOD_PACT_HP_RATIO
	pact_active = true
	pact_hp_penalty = penalty
	player.change_max_hp(-penalty)
	wave_manager.set_run_modifiers(GameConfig.BLOOD_PACT_COUNT_MULT, GameConfig.BLOOD_PACT_LOOT_MULT)
	if hud and hud.has_method("update_blood_pact"):
		hud.update_blood_pact(true, "契约：上限 -%d%% · 掉落 +%d%%" % [
			roundi(GameConfig.BLOOD_PACT_HP_RATIO * 100.0),
			roundi((GameConfig.BLOOD_PACT_LOOT_MULT - 1.0) * 100.0),
		])

	print("🩸 缔结契约：本层生命上限 -%.0f（现 %.0f），敌人 +%d%%，掉落 +%d%%" % [
		penalty, player.max_hp,
		roundi((GameConfig.BLOOD_PACT_COUNT_MULT - 1.0) * 100.0),
		roundi((GameConfig.BLOOD_PACT_LOOT_MULT - 1.0) * 100.0),
	])
	if floor_banner and floor_banner.has_method("show_card"):
		floor_banner.show_card(
			"契约生效",
			"本层：生命上限 -%d%%" % roundi(GameConfig.BLOOD_PACT_HP_RATIO * 100.0),
			"BLOOD PACT",
			"敌人 +%d%% 数量 · 银币与经验 +%d%%（层末归还）" % [
				roundi((GameConfig.BLOOD_PACT_COUNT_MULT - 1.0) * 100.0),
				roundi((GameConfig.BLOOD_PACT_LOOT_MULT - 1.0) * 100.0),
			],
			Color(0.85, 0.25, 0.28),
			1.4
		)

func _expire_blood_pact() -> void:
	## 层结束时归还上限与倍率。必须在层通关治疗之前调用，
	## 否则治疗是按被压过的上限算的（会少回 20%）。
	if not pact_active:
		return
	pact_active = false
	if is_instance_valid(player) and pact_hp_penalty > 0.0:
		player.change_max_hp(pact_hp_penalty)
		print("🩸 契约结束：生命上限归还 +%.0f（现 %.0f）" % [pact_hp_penalty, player.max_hp])
	pact_hp_penalty = 0.0
	wave_manager.set_run_modifiers(1.0, 1.0)
	if hud and hud.has_method("update_blood_pact"):
		hud.update_blood_pact(false, "")

func _open_portal_after_delay(delay: float) -> void:
	## 延时给当前房间开传送门
	## 关键：先记住"当时的房间"，否则玩家在这期间换房间后会把传送门开错地方
	var room: Node2D = current_room
	await get_tree().create_timer(delay).timeout
	if is_instance_valid(room) and is_instance_valid(self) and room == current_room:
		_open_room_exit(room)

func _enter_mutation_room() -> void:
	print("🩸 变异房!")
	AudioManager.play_bgm(_audio_lib.get_shop_bgm())
	if hud and hud.has_method("set_event_status"):
		hud.set_event_status("献出生命换奖励，也可能什么都换不到")
	var room: Node2D = current_room
	if mutation_ui == null:
		_open_portal_after_delay(1.0)
		return
	await get_tree().create_timer(0.5).timeout
	if not is_instance_valid(room) or not is_instance_valid(self) or room != current_room:
		return
	mutation_ui.open(player)
	mutation_ui.decided.connect(func(kind: String):
		_on_mutation_decided(kind)
		if is_instance_valid(room) and is_instance_valid(self) and room == current_room:
			_open_room_exit(room)
	, CONNECT_ONE_SHOT)

func _on_mutation_decided(kind: String) -> void:
	if kind != "gamble" or not is_instance_valid(player):
		if hud and hud.has_method("set_event_status"):
			hud.set_event_status("你离开了祭坛")
		return
	var cost := GameConfig.mutation_cost(player.max_hp)
	if not player.spend_hp(cost):
		return
	var result := GameConfig.roll_mutation(randf())
	player.add_silver(int(result.get("silver", 0)))
	var xp := int(result.get("xp", 0))
	if xp > 0:
		player.gain_xp(xp)
	var won: bool = bool(result.get("win", false))
	var text := "祭坛应验：银币 +%d　经验 +%d" % [int(result.get("silver", 0)), xp] if won \
		else "祭坛沉默：血已献上，只剩银币 +%d" % int(result.get("silver", 0))
	if hud and hud.has_method("set_event_status"):
		hud.set_event_status(text)
	if hud and hud.has_method("set_wave_status"):
		hud.set_wave_status("变异 · %s" % ("应验" if won else "落空"))
	print("🩸 %s" % text)

func _enter_fog_room(autostart: bool) -> void:
	## 迷雾是战斗房，但不要再叠一层猎物/宝箱事件——这间房的规则就是看不见。
	print("🌫 迷雾房!")
	wave_manager.set_room_loot_mult(GameConfig.FOG_LOOT_MULT)
	_enable_fog()
	var pct := roundi((GameConfig.FOG_LOOT_MULT - 1.0) * 100.0)
	if hud and hud.has_method("set_event_status"):
		hud.set_event_status("视野受限 · 掉落与经验 +%d%%" % pct)
	AudioManager.play_bgm(_audio_lib.get_battle_bgm())
	if autostart:
		wave_manager.start(player)

func _enter_mirror_room(autostart: bool) -> void:
	print("🪞 镜像房!")
	wave_manager.mirror_spawns = true
	if hud and hud.has_method("set_event_status"):
		hud.set_event_status("敌人与障碍已左右对调")
	AudioManager.play_bgm(_audio_lib.get_battle_bgm())
	if autostart:
		wave_manager.start(player)

func _enable_fog() -> void:
	_clear_fog()
	fog_overlay = Node2D.new()
	fog_overlay.name = "FogOverlay"
	fog_overlay.set_script(preload("res://scripts/map/fog_overlay.gd"))
	add_child(fog_overlay)
	fog_overlay.setup(player)

func _clear_fog() -> void:
	if fog_overlay != null and is_instance_valid(fog_overlay):
		fog_overlay.queue_free()
	fog_overlay = null

func _clear_enemy_projectiles() -> void:
	for group_name in ["enemy_projectiles", "enemy_bullets"]:
		for projectile in get_tree().get_nodes_in_group(group_name):
			if is_instance_valid(projectile):
				projectile.queue_free()

func _open_room_exit(room: Node2D) -> void:
	## 离开当前房间。下一间如果挂了岔路，就开两扇门，否则还是一扇。
	if not is_instance_valid(room) or room != current_room:
		return
	if room.get("portal_spawned"):
		return
	var choices: Array = dungeon.peek_room_choices() if dungeon else []
	if not choices.is_empty() and hud and hud.has_method("set_event_status"):
		var next_room: Dictionary = choices[0]
		hud.set_event_status("下一间 · %s · %s" % [next_room.get("title", ""), next_room.get("detail", "")])
	if choices.size() >= 2 and room.has_method("spawn_choice_portals"):
		room.spawn_choice_portals(choices)
		_announce_door_choice(choices)
	elif room.has_method("spawn_portal"):
		var preview := ""
		if not choices.is_empty():
			preview = String(choices[0].get("title", ""))
		room.spawn_portal(preview)
	if room.get("portal_spawned"):
		AudioManager.play_sfx(_audio_lib.get_sound("door_open"))

func _announce_door_choice(choices: Array) -> void:
	if choices.size() < 2 or hud == null:
		return
	var left: Dictionary = choices[0]
	var right: Dictionary = choices[1]
	if hud.has_method("set_wave_status"):
		hud.set_wave_status("选路 · 左%s / 右%s" % [left.get("title", ""), right.get("title", "")])
	if hud.has_method("set_event_status"):
		hud.set_event_status("左：%s　　右：%s" % [left.get("detail", ""), right.get("detail", "")])

func _apply_daily_rules() -> void:
	## 重开同一场景会再走一遍：每日状态挂在 GameConfig 上，重开仍是今天的挑战。
	## 回主菜单才会清掉。这样“再来一局”比的是同一组词缀，而不是不小心开了一局普通的。
	if not GameConfig.daily_active:
		return
	if GameConfig.has_daily("bounty") and wave_manager:
		wave_manager.loot_bonus_mult = GameConfig.DAILY_BOUNTY_MULT
	if GameConfig.has_daily("slow") and is_instance_valid(player):
		player.move_speed *= GameConfig.DAILY_SLOW_MULT
	if GameConfig.daily_seed != 0 and dungeon:
		var map_rng := RandomNumberGenerator.new()
		map_rng.seed = GameConfig.daily_seed
		dungeon.use_rng(map_rng)
		var combat_rng := RandomNumberGenerator.new()
		combat_rng.seed = GameConfig.daily_seed ^ 0x5A17
		wave_manager.combat_rng = combat_rng
		# 升级抽卡也用固定随机流：每日挑战的可复现性不能只覆盖地图和战斗。
		# 边界要说清楚——同一种子 + 同一个池状态（以及同样的抽牌次数）才给同一手牌；
		# 玩家中途重抽过、手牌池被放逐过，结果就会不同，这是设计使然，不是 bug。
		# 用独立盐值派生，避免和地图/战斗共用同一条随机序列（共用会让后面的抽卡
		# 结果依赖前面刷了几波怪，跨机器就不一致了）。
		var upgrade_rng := RandomNumberGenerator.new()
		upgrade_rng.seed = GameConfig.daily_seed ^ GameConfig.DAILY_UPGRADE_RNG_SALT
		upgrade_ui.rng = upgrade_rng
	print("☀ 每日挑战 %s · %s" % [GameConfig.daily_date, GameConfig.daily_name_list()])

func _apply_room_variant() -> void:
	if dungeon == null or wave_manager == null:
		return
	var variant: String = String(dungeon.current_variant())
	if variant != "" and variant != "quiet_antechamber":
		wave_manager.variant_loot_mult = 1.25
	match variant:
		"blood_tide":
			wave_manager.variant_hp_mult = 0.85
			wave_manager.variant_spawn_bonus = 1
		"crossfire":
			wave_manager.prefer_ranged = true
		"leyline":
			_pulse_leyline()
		"armored_patrol":
			wave_manager.variant_hp_mult = 1.4
			wave_manager.variant_spawn_bonus = -1
			wave_manager.prefer_melee = true
		"hunter_hall":
			wave_manager.prefer_fast = true
			wave_manager.variant_speed_mult = 1.2
			wave_manager.variant_loot_mult = 1.35
		"quiet_antechamber":
			wave_manager.variant_spawn_bonus = -2
			wave_manager.variant_loot_mult = 0.75

func _pulse_leyline() -> void:
	if current_room == null or not current_room.has_method("get_center"):
		return
	var puddle = preload("res://scripts/map/potion_puddle.gd").new()
	puddle.damage = 6.0
	puddle.global_position = current_room.to_global(current_room.get_center())
	current_room.add_child(puddle)

func _apply_floor_rule() -> void:
	if dungeon == null or current_room == null or not current_room.has_method("get_center"):
		return
	var rule := String(dungeon.get_current_floor_data().get("rule", ""))
	var pos: Vector2 = current_room.to_global(current_room.get_center())
	match rule:
		"nest":
			var web = preload("res://scripts/enemies/web_patch.gd").new()
			web.global_position = pos
			current_room.add_child(web)
			var web_side = preload("res://scripts/enemies/web_patch.gd").new()
			web_side.global_position = pos + Vector2(-140, 80)
			current_room.add_child(web_side)
		"tomb":
			var shell = preload("res://scripts/enemies/coffin_shell.gd").new()
			shell.revive_delay = 9999.0
			shell.global_position = pos + Vector2(90, 30)
			current_room.add_child(shell)
			var shell_side = preload("res://scripts/enemies/coffin_shell.gd").new()
			shell_side.revive_delay = 9999.0
			shell_side.global_position = pos + Vector2(-120, -40)
			current_room.add_child(shell_side)
		"alchemy":
			var puddle = preload("res://scripts/map/potion_puddle.gd").new()
			puddle.global_position = pos
			current_room.add_child(puddle)
			var puddle_side = preload("res://scripts/map/potion_puddle.gd").new()
			puddle_side.global_position = pos + Vector2(160, -70)
			current_room.add_child(puddle_side)
		"eclipse":
			var well = preload("res://scripts/map/moon_well.gd").new()
			well.global_position = pos
			current_room.add_child(well)
			var well_side = preload("res://scripts/map/moon_well.gd").new()
			well_side.global_position = pos + Vector2(-150, 60)
			current_room.add_child(well_side)

func _boss_scene_for(boss_id: String) -> PackedScene:
	match boss_id:
		"blood_lord":
			return preload("res://scenes/enemies/blood_lord.tscn")
		"blood_matriarch":
			return preload("res://scenes/enemies/blood_matriarch.tscn")
		"tomb_warden":
			return preload("res://scenes/enemies/tomb_warden.tscn")
		"alchemist_prince":
			return preload("res://scenes/enemies/alchemist_prince.tscn")
		"eclipse_queen":
			return preload("res://scenes/enemies/eclipse_queen.tscn")
		_:
			return boss_scene

func _enter_boss_room() -> void:
	var boss_name: String = dungeon.get_boss_name()
	print("💀 第 %d 层 Boss 房间! %s 降临!" % [dungeon.current_floor, boss_name])

	# 切换到 Boss BGM
	AudioManager.play_bgm(_audio_lib.get_boss_bgm())
	_boss_defeat_handled = false

	# 五层各用自己的 Boss 控制器。旧的三形态领主不再负责主线。
	var boss := _boss_scene_for(dungeon.get_boss_id()).instantiate()
	var boss_achievements := get_node_or_null("/root/AchievementManager")
	_boss_damage_baseline = float(boss_achievements.get_run_stats().get("damage_taken", 0.0)) if boss_achievements else 0.0
	if "boss_variant" in boss:
		boss.boss_variant = dungeon.get_boss_variant()
	boss.spawn_wave = maxi(wave_manager.current_wave, 1)
	boss.floor_index = dungeon.current_floor
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
	if boss.has_signal("boss_intro_finished"):
		boss.boss_intro_finished.connect(_on_boss_intro_finished)
	if boss.has_signal("enemy_died"):
		boss.enemy_died.connect(func(_e): pass)  # Boss 不计入波次

	var spawn_parent: Node = get_tree().current_scene
	if spawn_parent == null:
		spawn_parent = self
	spawn_parent.add_child(boss)
	var saves := _save_manager_ref()
	if saves != null and saves.has_method("discover_codex") and boss.has_method("_get_enemy_type"):
		saves.discover_codex("boss", String(boss._get_enemy_type()))
	# Boss._ready 设置独立场景的深渊默认值；生成后应用完整的本局倍率。
	if "loot_mult" in boss:
		boss.loot_mult = wave_manager.effective_loot_mult()
	boss_hp_bar.show_boss_bar(boss_name)
	# Boss 不计入波次（enemy_died 那条连接是空回调），波次编号打到这层就停住了。
	# 继续挂在 HUD 上会让玩家以为"还差几波"而不是"把这条血打完"。
	if hud and hud.has_method("set_boss_mode"):
		hud.set_boss_mode(true)

func _on_boss_intro_finished() -> void:
	## Boss 登场演出结束，血条亮满 → 进入正常战斗
	if boss_hp_bar and boss_hp_bar.has_method("end_intro"):
		boss_hp_bar.end_intro()

func _save_manager_ref() -> Node:
	## 存档读取统一入口：测试注入优先，避免碰真实 user:// 存档
	if debug_save_manager != null:
		return debug_save_manager
	return get_node_or_null("/root/SaveManager")

func _floor_clear_crystals(floor_index: int) -> int:
	## 通关血晶结算：基础值 × 深渊掉落倍率，至少 1（别让四舍五入吃掉奖励）
	return maxi(
		roundi(GameConfig.get_floor_clear_crystals(floor_index) * GameConfig.get_abyss_loot_mult()),
		1)

func _advance_abyss() -> int:
	## 深渊阶梯（17.14）：+1 等级，并把"最深到达"同步到存档。
	## 抽成纯推进函数：UI 回调只负责 reload，数值推进可被测试真实调用。
	GameConfig.abyss_level += 1
	if GameConfig.abyss_level > GameConfig.best_abyss:
		GameConfig.best_abyss = GameConfig.abyss_level
		var save_mgr := _save_manager_ref()
		if save_mgr:
			save_mgr.set_best_abyss(GameConfig.abyss_level)
	return GameConfig.abyss_level

func _on_boss_defeated() -> void:
	# 每层只结算一次；只有最终层才进入整局胜利终态。死亡可抢占最终层结算。
	if _terminal_state == "death" or _boss_defeat_handled:
		return
	if dungeon.current_floor >= GameConfig.DUNGEON_FLOOR_COUNT and not _begin_terminal_state("victory"):
		return
	_boss_defeat_handled = true
	var run_token := _run_token

	boss_hp_bar.hide_boss_bar()
	if hud and hud.has_method("set_boss_mode"):
		hud.set_boss_mode(false)
	wave_manager.stop()

	var cleared_floor: int = dungeon.current_floor
	# 深渊轮的通关血晶也吃掉落加成
	var crystals: int = _floor_clear_crystals(cleared_floor)
	print("👑 第 %d 层 Boss 被击败! 血晶 +%d" % [cleared_floor, crystals])

	# 记录Boss击杀成就
	var ach_mgr := get_node_or_null("/root/AchievementManager")
	if ach_mgr:
		if cleared_floor >= GameConfig.DUNGEON_FLOOR_COUNT:
			ach_mgr.finish_run()
		ach_mgr.record_boss_kill(maxf(float(ach_mgr.run_stats.get("damage_taken", 0.0)) - _boss_damage_baseline, 0.0))
		ach_mgr.record_floor_cleared(cleared_floor)
		ach_mgr.record_crystals_earned(crystals)

	# 血晶奖励
	var save_mgr := _save_manager_ref()
	if save_mgr:
		save_mgr.add_blood_crystals(crystals)

	# 层通关奖励：回复部分生命
	# 顺序很重要：先归还契约上限，再治疗。反过来治疗会按被压过的上限算，少回 20%
	_expire_blood_pact()
	if is_instance_valid(player):
		player.heal(player.max_hp * GameConfig.FLOOR_CLEAR_HEAL_RATIO)

	# 清除残留敌人与掉落
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.queue_free()
	_clear_enemy_projectiles()

	# 2026-11-09 反馈：Boss 一死掉落立刻被清场，经验宝石/银币根本来不及捡。
	# 先给 10 秒拾取窗口（HUD 倒计时 + 拾取范围临时放大），喘口气再下潜。
	await _loot_grace_countdown(debug_loot_grace_seconds if debug_loot_grace_seconds >= 0 else 10)
	if not _lifecycle_token_valid(run_token) or _terminal_state == "death":
		return

	# 推进到下一层；false 表示已经是最后一层
	var has_next: bool = dungeon.advance_floor()

	await _show_floor_clear(cleared_floor, crystals)
	if not _lifecycle_token_valid(run_token) or _terminal_state == "death":
		return
	await get_tree().create_timer(0.4, false).timeout
	if not _lifecycle_token_valid(run_token) or _terminal_state == "death":
		return

	if has_next:
		await _show_floor_intro(dungeon.current_floor)
		if not _lifecycle_token_valid(run_token) or _terminal_state == "death":
			return
		_transition_to_next_room()
		return

	# === 地下城通关结算 ===
	await _show_dungeon_clear()
	if not _lifecycle_token_valid(run_token) or _terminal_state == "death":
		return
	if ach_mgr:
		ach_mgr.record_dungeon_clear()
	var run_stats: Dictionary = ach_mgr.get_run_stats() if ach_mgr else {}
	var stats := {
		"wave": wave_manager.current_wave,
		"kills": wave_manager.total_kills,
		"level": player.current_level if is_instance_valid(player) else 1,
		"rooms": rooms_cleared,
		"floor": dungeon.current_floor,
		"floors_cleared": GameConfig.DUNGEON_FLOOR_COUNT,
		"kill_categories": run_stats.get("kill_categories", {}).duplicate(true),
		"survival_time": run_stats.get("survival_time", 0),
		"damage_taken": run_stats.get("damage_taken", 0),
		"review": run_log.summary() if run_log != null else "",
		"abyss_level": GameConfig.abyss_level,
		"daily": GameConfig.daily_active,
		"daily_date": GameConfig.daily_date,
	}
	game_over_ui.show_game_over(stats, true)

func _loot_grace_countdown(seconds: int) -> void:
	if not is_instance_valid(player):
		return
	var run_token := _run_token
	const PICKUP_CONTRIBUTION := 260.0
	player.pickup_range_bonus += PICKUP_CONTRIBUTION
	for i in range(seconds, 0, -1):
		if hud != null and is_instance_valid(hud) and hud.has_method("set_wave_status"):
			hud.set_wave_status("拾取战利品 · %d 秒后下潜" % i, true)
		await get_tree().create_timer(1.0, false).timeout
		if not _lifecycle_token_valid(run_token):
			break
	if is_instance_valid(player):
		player.pickup_range_bonus = maxf(float(player.pickup_range_bonus) - PICKUP_CONTRIBUTION, 0.0)

# === 楼层流程 ===
func _on_floor_started(_floor_index: int, _floor_data: Dictionary) -> void:
	var saves := get_node_or_null("/root/SaveManager")
	if saves != null and saves.has_method("unlock_weapons_for_floor"):
		saves.unlock_weapons_for_floor(_floor_index)
	_update_dungeon_hud()
	# 事件"一层一次"的标记按层重置
	if room_events:
		room_events.on_floor_changed(_floor_index)

func _on_floor_cleared(floor_index: int, _floor_data: Dictionary) -> void:
	print("🚪 第 %d 层已肃清" % floor_index)

func _on_dungeon_cleared() -> void:
	print("🏆 地下城已通关!")

func _show_current_floor_intro() -> void:
	await _show_floor_intro(dungeon.current_floor)

func _show_floor_intro(floor_index: int) -> void:
	var data_list: Array = dungeon.floors_data
	var data: Dictionary = data_list[clampi(floor_index - 1, 0, data_list.size() - 1)]
	var title := "第 %d 层" % floor_index
	if GameConfig.abyss_level > 0:
		# 深渊轮：换层横幅必须写明轮次，否则"为什么怪变硬了"无从解释
		title = "深渊 %d · 第 %d 层" % [GameConfig.abyss_level, floor_index]
	if GameConfig.daily_active:
		title = "每日 · " + title
	var hint := String(data.get("hint", ""))
	var extras: PackedStringArray = PackedStringArray()
	if GameConfig.daily_active and GameConfig.daily_name_list() != "":
		extras.append("每日 " + GameConfig.daily_name_list())
	var rules := GameConfig.abyss_rule_text()
	if rules != "":
		extras.append("深渊 " + rules)
	if extras.size() > 0:
		hint += "　" + "　".join(extras)
	await floor_banner.show_card(
		title,
		String(data.get("name", "")),
		String(data.get("subtitle", "")),
		hint,
		data.get("accent", Color(0.8, 0.15, 0.2)),
		1.6
	)

func _show_floor_clear(floor_index: int, crystals: int) -> void:
	await floor_banner.show_card(
		"第 %d 层" % floor_index,
		"已肃清",
		"FLOOR CLEARED",
		"血晶 +%d　　生命已恢复" % crystals,
		Color(0.95, 0.8, 0.35),
		1.2
	)

func _show_dungeon_clear() -> void:
	await floor_banner.show_card(
		"DUNGEON CLEARED",
		"地下城已征服",
		"THE THRONE IS SILENT",
		"血族女王的王座，终于空无一人",
		Color(1.0, 0.86, 0.42),
		2.0
	)

# === 现有回调 ===
func _on_player_level_up(new_level: int) -> void:
	# 记录等级成就
	var ach_mgr := get_node_or_null("/root/AchievementManager")
	if ach_mgr:
		ach_mgr.update_level(new_level)

	if _terminal_state != "":
		return
	_pending_upgrades += 1
	_try_open_upgrade()

func _try_open_upgrade() -> void:
	if _terminal_state != "" or (player != null and is_instance_valid(player) and player.has_method("is_dead") and player.is_dead()):
		_pending_upgrades = 0
		return
	if _upgrade_open or _pending_upgrades <= 0:
		return
	if upgrade_ui == null or upgrade_ui.visible:
		return
	_upgrade_open = true
	_pending_upgrades -= 1
	upgrade_ui.show_upgrade(player, weapon_manager)

func _on_upgrade_selected() -> void:
	_upgrade_open = false
	# 升级也可能让武器满了 / 拿到进化所需被动，顺手刷新提示
	_refresh_evolution_hint()
	# 等暂停真正解除再开下一个，否则新面板会被同一帧的 paused=false 覆盖
	await get_tree().create_timer(0.05).timeout
	_try_open_upgrade()

func _on_player_damage_received(actual_damage: float) -> void:
	if actual_damage <= 0.0:
		return
	var ach_mgr := get_node_or_null("/root/AchievementManager")
	if ach_mgr:
		ach_mgr.record_damage_taken(actual_damage)

func _on_wave_started(wave: int) -> void:
	# 记录波次成就
	var ach_mgr := get_node_or_null("/root/AchievementManager")
	if ach_mgr:
		ach_mgr.update_wave(wave)

func _on_enemy_killed(_kill_count: int = 0) -> void:
	# 敌人掉血/死亡不影响进化条件（条件已改为 满级 + 被动 + 宝箱），
	# 但杀怪会掉银币和可能升级，顺手把 HUD 的三态提示刷新一下
	_refresh_evolution_hint()

func _refresh_evolution_hint() -> void:
	## 把"进化准备度"画到 HUD 上。三态：无 / 还差被动 / 可开宝箱进化
	if hud == null or not hud.has_method("update_evolution"):
		return
	if weapon_manager == null or player == null or not is_instance_valid(player):
		hud.update_evolution("none", "")
		return
	var owned: Array = []
	if player.has_method("get_owned_passive_items"):
		owned = player.get_owned_passive_items()
	var status: Dictionary = weapon_manager.get_evolution_status(owned)
	hud.update_evolution(String(status.get("state", "none")), String(status.get("text", "")))

func _on_weapon_added(weapon) -> void:
	if run_log != null:
		run_log.note_build("获得", String(weapon.weapon_name))
	var saves := _save_manager_ref()
	if saves != null and saves.has_method("discover_codex"):
		saves.discover_codex("weapon", String(weapon.weapon_id))

func _on_weapon_leveled_up(weapon) -> void:
	if weapon.is_max_level():
		var ach_mgr := get_node_or_null("/root/AchievementManager")
		if ach_mgr:
			ach_mgr.record_weapon_maxed(weapon.weapon_name)

func _on_weapon_evolved(weapon, evolution) -> void:
	## 武器进化回调
	print("✨ 武器进化: %s -> %s" % [weapon.weapon_name, evolution.evolution_name])

	# 记录武器大师与进化成就
	var ach_mgr := get_node_or_null("/root/AchievementManager")
	if ach_mgr:
		ach_mgr.record_weapon_evolved(weapon.weapon_id)
	if run_log != null:
		run_log.note_build("进化", String(weapon.weapon_name))

func _on_player_died() -> void:
	if not _begin_terminal_state("death"):
		return
	wave_manager.stop()
	_clear_enemy_projectiles()
	if floor_banner:
		floor_banner.force_hide()
	var ach_mgr := get_node_or_null("/root/AchievementManager")
	if ach_mgr:
		ach_mgr.finish_run()
	var run_stats: Dictionary = ach_mgr.get_run_stats() if ach_mgr else {}
	var stats := {
		"wave": wave_manager.current_wave,
		"kills": wave_manager.total_kills,
		"level": player.current_level if is_instance_valid(player) else 1,
		"rooms": rooms_cleared,
		"floor": dungeon.current_floor if dungeon else 1,
		"survival_time": run_stats.get("survival_time", 0),
		"damage_taken": run_stats.get("damage_taken", 0),
		"review": run_log.summary() if run_log != null else "",
		"kill_categories": run_stats.get("kill_categories", {}).duplicate(true),
		"daily": GameConfig.daily_active,
		"daily_date": GameConfig.daily_date,
	}
	var terminal_token := _run_token
	await get_tree().create_timer(0.8, false).timeout
	if not _lifecycle_token_valid(terminal_token) or _terminal_state != "death":
		return
	game_over_ui.show_game_over(stats)

func _on_restart() -> void:
	# 普通重开 = 放弃深渊进度（深渊只在"连胜式"继续时保留）
	# 每日不在这里清：重开仍是今天的词缀和种子，只有回主菜单才退出每日。
	GameConfig.abandon_abyss()
	get_tree().reload_current_scene()

func _on_return_to_menu() -> void:
	GameConfig.abandon_abyss()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

func _on_abyss_continue() -> void:
	## 深渊阶梯（17.14）：+1 等级后重开三层。
	## 等级挂在 GameConfig 的 static var 上（GameConfig 是静态脚本资源，不是 autoload），
	## reload 重建 main 后依然在。
	_advance_abyss()
	print("🌀 深渊阶梯：进入第 %d 级（血 ×%.2f / 伤 ×%.2f / 掉落 ×%.2f）" % [
		GameConfig.abyss_level, GameConfig.get_abyss_hp_mult(),
		GameConfig.get_abyss_damage_mult(), GameConfig.get_abyss_loot_mult()])
	get_tree().reload_current_scene()
