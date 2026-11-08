extends Node2D
## 游戏主场景脚本
## 管理整体游戏流程：房间生成、波次战斗、房间切换

const GameRoomScript = preload("res://scripts/map/game_room.gd")
const RoomManagerScript = preload("res://scripts/map/room_manager.gd")
const DungeonManagerScript = preload("res://scripts/map/dungeon_manager.gd")
const FloorBannerScript = preload("res://scripts/ui/floor_banner.gd")
const CharacterDataScript = preload("res://scripts/player/character_data.gd")
var boss_scene: PackedScene = preload("res://scenes/enemies/vampire_lord.tscn")

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
var room_manager: Node = null
var dungeon: Node = null
var floor_banner: CanvasLayer = null
var room_shop: CanvasLayer = null
var blood_pact: CanvasLayer = null
var rooms_cleared: int = 0
var transition_overlay: ColorRect = null
## 深渊契约：本层是否生效，以及被扣掉的生命上限绝对值（层末归还）
var pact_active: bool = false
var pact_hp_penalty: float = 0.0
## Boss 击败结算防重标志（每层 Boss 房重置）
var _boss_defeat_handled: bool = false
## 升级弹窗队列：一次吃下多颗经验宝石时 level_up 会连续发多次，
## 而升级界面是单例的。不做队列的话后一次会把前一次的选项直接顶掉（玩家白丢一次升级）。
var _pending_upgrades: int = 0
var _upgrade_open: bool = false

func _ready() -> void:
	print("VampireHunter - 游戏启动!")
	_audio_lib = AudioLib

	# 创建房间管理器
	room_manager = Node.new()
	room_manager.set_script(RoomManagerScript)
	add_child(room_manager)
	room_manager.setup(player)

	# 创建地下城管理器
	dungeon = Node.new()
	dungeon.set_script(DungeonManagerScript)
	add_child(dungeon)

	# 创建过渡遮罩与楼层横幅
	_create_transition_overlay()
	_create_floor_banner()
	_create_room_shop()
	_create_blood_pact()

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
	dungeon.start_dungeon()
	dungeon.floor_started.connect(_on_floor_started)
	dungeon.floor_cleared.connect(_on_floor_cleared)
	dungeon.dungeon_cleared.connect(_on_dungeon_cleared)
	_enter_next_room(false)
	await get_tree().create_timer(0.3).timeout
	await _show_current_floor_intro()

	# 提示结束后才正式开战
	AudioManager.play_bgm(_audio_lib.get_battle_bgm())
	wave_manager.start(player)

	# 初始化成就系统
	var ach_mgr := get_node_or_null("/root/AchievementManager")
	if ach_mgr:
		ach_mgr.start_new_run()
	

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
	player.hp_changed.connect(_on_player_hp_changed)
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
	upgrade_ui.upgrade_selected.connect(_on_upgrade_selected)
	game_over_ui.restart_requested.connect(_on_restart)
	game_over_ui.menu_requested.connect(_on_return_to_menu)

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
		_:
			current_room.room_theme = theme if theme != "" else _get_combat_theme()

	add_child(current_room)
	# 移到最底层
	move_child(current_room, 0)

	# 连接传送门信号
	current_room.portal_entered.connect(_on_portal_entered)

	# 根据房间类型添加障碍物与装饰（在场景树中操作）
	match room_type:
		"combat":
			if rooms_cleared > 1:
				current_room.add_pillars(randi_range(2, 4))
				current_room.add_props(randi_range(1, 3))
			current_room.add_decorations(randi_range(2, 5))
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

func _create_blood_pact() -> void:
	## 血之祭坛（休息房二选一）。同样全部代码构建。
	blood_pact = CanvasLayer.new()
	blood_pact.name = "BloodPact"
	blood_pact.set_script(preload("res://scripts/ui/blood_pact_ui.gd"))
	add_child(blood_pact)

# === 房间切换 ===
func _on_wave_completed(wave_number: int) -> void:
	# 每完成一波后出现传送门
	if current_room != null and not current_room.portal_spawned:
		current_room.spawn_portal()

func _on_portal_entered() -> void:
	# 播放传送音效
	AudioManager.play_sfx(_audio_lib.get_sound("teleport"))
	_transition_to_next_room()

func _transition_to_next_room() -> void:
	wave_manager.stop()
	# 换房前先把地上没捡的经验结算掉：宝石是房间节点的子节点，
	# 房间一释放它们就跟着没了，不结算等于玩家白丢经验
	wave_manager.settle_xp_gems()
	# 清除所有敌人与残留掉落物（掉落物带着旧房间的坐标，带过去会出现在墙里）
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.queue_free()
	for powerup in get_tree().get_nodes_in_group("powerups"):
		powerup.queue_free()

	# 淡出
	# 注意：这里用 timer 而不是 await tween.finished。
	# 嵌套协程里 await Tween.finished 存在丢信号的风险（tween 已完成但协程不恢复），
	# 表现为换层时整局卡死在黑屏。
	var fade_out := create_tween()
	fade_out.tween_property(transition_overlay, "color:a", 1.0, 0.3)
	await get_tree().create_timer(0.3).timeout

	print("🚪 切换房间 → 第 %d 层 第 %d 间" % [dungeon.current_floor, dungeon.room_in_floor + 1])
	# 只调用一次！曾经这里和下面各写了一次 _enter_next_room()，
	# 导致每换一间房都会生成两个房间、两个 Boss，房间计数还会越界（6/6 → 7/6）。
	_enter_next_room()

	# 淡入
	var fade_in := create_tween()
	fade_in.tween_property(transition_overlay, "color:a", 0.0, 0.3)
	await get_tree().create_timer(0.3).timeout

func _enter_next_room(autostart: bool = true) -> String:
	## 从地下城取出下一个房间并布置，返回房间类型
	var room_type: String = dungeon.consume_room()
	rooms_cleared = dungeon.rooms_cleared_total

	# 同步层敌人池与层倍率
	wave_manager.set_floor(dungeon.current_floor, dungeon.get_enemy_pool())

	var template: Dictionary = room_manager.get_random_template()
	var theme: String = dungeon.get_combat_theme() if room_type == "combat" else ""
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
			# 普通战斗房间，切换回战斗 BGM 并启动波次
			AudioManager.play_bgm(_audio_lib.get_battle_bgm())
			if autostart:
				wave_manager.start(player)

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
	room_shop.open(player, weapon_manager)
	room_shop.shop_closed.connect(func():
		if is_instance_valid(room) and is_instance_valid(self) and room == current_room:
			room.spawn_portal()
	, CONNECT_ONE_SHOT)

func _enter_treasure_room() -> void:
	print("🎁 宝箱房间!")
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
			# 武器槽已满：改为给经验奖励，避免绕过槽位限制无限堆武器
			print("🎁 武器槽已满，宝箱转化为经验")
			if is_instance_valid(player):
				player.gain_xp(80)
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
			room.spawn_portal()
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
		room.spawn_portal()

func _enter_boss_room() -> void:
	var boss_name: String = dungeon.get_boss_name()
	print("💀 第 %d 层 Boss 房间! %s 降临!" % [dungeon.current_floor, boss_name])

	# 切换到 Boss BGM
	AudioManager.play_bgm(_audio_lib.get_boss_bgm())
	_boss_defeat_handled = false

	# 生成 Boss
	var boss := boss_scene.instantiate()
	# 形态决定血量档位、攻击参数与光效
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
	boss_hp_bar.show_boss_bar(boss_name)

func _on_boss_intro_finished() -> void:
	## Boss 登场演出结束，血条亮满 → 进入正常战斗
	if boss_hp_bar and boss_hp_bar.has_method("end_intro"):
		boss_hp_bar.end_intro()

func _on_boss_defeated() -> void:
	# 防重：同一层只结算一次（历史上曾因为换房重复调用生成两个 Boss，
	# 导致血晶翻倍、层数连跳两次）
	if _boss_defeat_handled:
		return
	_boss_defeat_handled = true

	boss_hp_bar.hide_boss_bar()
	wave_manager.stop()

	var cleared_floor: int = dungeon.current_floor
	var crystals: int = GameConfig.get_floor_clear_crystals(cleared_floor)
	print("👑 第 %d 层 Boss 被击败! 血晶 +%d" % [cleared_floor, crystals])

	# 记录Boss击杀成就
	var ach_mgr := get_node_or_null("/root/AchievementManager")
	if ach_mgr:
		ach_mgr.record_boss_kill(int(ach_mgr.run_stats.get("damage_taken", 0)))
		ach_mgr.record_floor_cleared(cleared_floor)
		ach_mgr.record_crystals_earned(crystals)

	# 血晶奖励
	var save_mgr := get_node_or_null("/root/SaveManager")
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

	# 推进到下一层；false 表示已经是最后一层
	var has_next: bool = dungeon.advance_floor()

	await _show_floor_clear(cleared_floor, crystals)
	await get_tree().create_timer(0.4).timeout

	if has_next:
		await _show_floor_intro(dungeon.current_floor)
		_transition_to_next_room()
		return

	# === 地下城通关结算 ===
	await _show_dungeon_clear()
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
		"survival_time": run_stats.get("survival_time", 0),
		"damage_taken": run_stats.get("damage_taken", 0),
	}
	game_over_ui.show_game_over(stats, true)

# === 楼层流程 ===
func _on_floor_started(_floor_index: int, _floor_data: Dictionary) -> void:
	_update_dungeon_hud()

func _on_floor_cleared(floor_index: int, _floor_data: Dictionary) -> void:
	print("🚪 第 %d 层已肃清" % floor_index)

func _on_dungeon_cleared() -> void:
	print("🏆 地下城已通关!")

func _show_current_floor_intro() -> void:
	await _show_floor_intro(dungeon.current_floor)

func _show_floor_intro(floor_index: int) -> void:
	var data_list: Array = dungeon.floors_data
	var data: Dictionary = data_list[clampi(floor_index - 1, 0, data_list.size() - 1)]
	await floor_banner.show_card(
		"第 %d 层" % floor_index,
		String(data.get("name", "")),
		String(data.get("subtitle", "")),
		String(data.get("hint", "")),
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

	_pending_upgrades += 1
	_try_open_upgrade()

func _try_open_upgrade() -> void:
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

func _on_player_hp_changed(current: float, _max: float) -> void:
	# 记录受到伤害（用于无伤通关成就）
	var damage_taken: float = _max - current
	if damage_taken > 0:
		var ach_mgr := get_node_or_null("/root/AchievementManager")
		if ach_mgr:
			ach_mgr.record_damage_taken(damage_taken)

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

func _on_weapon_evolved(weapon, evolution) -> void:
	## 武器进化回调
	print("✨ 武器进化: %s -> %s" % [weapon.weapon_name, evolution.evolution_name])

	# 记录武器大师与进化成就
	var ach_mgr := get_node_or_null("/root/AchievementManager")
	if ach_mgr:
		ach_mgr.record_weapon_maxed(weapon.weapon_name)
		ach_mgr.record_weapon_evolved(weapon.weapon_id)

func _on_player_died() -> void:
	wave_manager.stop()
	if floor_banner:
		floor_banner.force_hide()
	var ach_mgr := get_node_or_null("/root/AchievementManager")
	var run_stats: Dictionary = ach_mgr.get_run_stats() if ach_mgr else {}
	var stats := {
		"wave": wave_manager.current_wave,
		"kills": wave_manager.total_kills,
		"level": player.current_level if is_instance_valid(player) else 1,
		"rooms": rooms_cleared,
		"floor": dungeon.current_floor if dungeon else 1,
		"survival_time": run_stats.get("survival_time", 0),
		"damage_taken": run_stats.get("damage_taken", 0),
	}
	await get_tree().create_timer(0.8).timeout
	game_over_ui.show_game_over(stats)

func _on_restart() -> void:
	get_tree().reload_current_scene()

func _on_return_to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
