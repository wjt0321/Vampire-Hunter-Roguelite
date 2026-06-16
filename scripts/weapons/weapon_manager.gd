extends Node
class_name WeaponManager
## 武器管理器

const WeaponDataScript = preload("res://scripts/weapons/weapon_data.gd")
const WeaponEvolutionScript = preload("res://scripts/weapons/weapon_evolution.gd")

# 场景预加载常量
const KnifeBulletScene = preload("res://scenes/player/knife_bullet.tscn")
const PoisonCloudScene = preload("res://scenes/player/poison_cloud.tscn")
const LightningChainScene = preload("res://scenes/player/lightning_chain.tscn")

var weapons: Array = []
var weapon_evolutions: Dictionary = {}  # weapon_id -> WeaponEvolution
var shoot_timers: Dictionary = {}
var player: CharacterBody2D = null
var bullet_scene: PackedScene = preload("res://scenes/player/bullet.tscn")

# 缓存的 AudioLibrary 实例
var _audio_lib: AudioLibrary = null

# 敌人方向缓存（降低每帧扫描开销）
var _nearest_enemy_dir: Vector2 = Vector2.ZERO
var _nearest_enemy_pos: Vector2 = Vector2.ZERO
var _enemy_cache_timer: float = 0.0
const ENEMY_CACHE_INTERVAL: float = 0.15

signal weapon_added(weapon: Resource)
signal weapon_leveled_up(weapon: Resource)
signal weapon_evolved(weapon: Resource, evolution: WeaponEvolution)

# 进化条件配置
const EVOLUTION_CONFIG: Dictionary = {
	"pistol": {
		"evolution_name": "神圣手枪",
		"evolution_description": "发射神圣光芒，伤害大幅提升",
		"evolution_icon": "✨",
		"required_passive_items": [],
		"required_kill_count": 50,
		"damage_multiplier": 3.0,
		"fire_rate_multiplier": 0.3,
		"size_multiplier": 1.5,
		"special_effect": "神圣光芒",
	},
	"shotgun": {
		"evolution_name": "毁灭者",
		"evolution_description": "散射更多子弹，覆盖更广范围",
		"evolution_icon": "💥",
		"required_passive_items": [],
		"required_kill_count": 50,
		"damage_multiplier": 2.5,
		"fire_rate_multiplier": 0.4,
		"size_multiplier": 1.3,
		"special_effect": "额外散射",
	},
	"magic_book": {
		"evolution_name": "大魔导书",
		"evolution_description": "同时追踪多个敌人",
		"evolution_icon": "📚",
		"required_passive_items": [],
		"required_kill_count": 50,
		"damage_multiplier": 2.5,
		"fire_rate_multiplier": 0.4,
		"size_multiplier": 1.4,
		"special_effect": "多重追踪",
	},
	"throwing_knife": {
		"evolution_name": "刀阵旋风",
		"evolution_description": "飞刀围绕玩家旋转",
		"evolution_icon": "🌪️",
		"required_passive_items": [],
		"required_kill_count": 50,
		"damage_multiplier": 2.0,
		"fire_rate_multiplier": 0.5,
		"size_multiplier": 1.5,
		"special_effect": "刀阵环绕",
	},
	"poison_cloud": {
		"evolution_name": "瘟疫之源",
		"evolution_description": "更大范围的致命毒雾",
		"evolution_icon": "☣️",
		"required_passive_items": [],
		"required_kill_count": 50,
		"damage_multiplier": 2.5,
		"fire_rate_multiplier": 0.5,
		"size_multiplier": 2.0,
		"special_effect": "范围扩大",
	},
	"lightning_chain": {
		"evolution_name": "雷神之怒",
		"evolution_description": "全屏闪电链",
		"evolution_icon": "🌩️",
		"required_passive_items": [],
		"required_kill_count": 50,
		"damage_multiplier": 3.0,
		"fire_rate_multiplier": 0.4,
		"size_multiplier": 1.5,
		"special_effect": "全屏连锁",
	},
}

func setup(player_node: CharacterBody2D, initial_weapon_id: String = "pistol") -> void:
	player = player_node
	# 初始化 AudioLib 缓存
	_audio_lib = AudioLib
	var initial_weapon = _create_weapon_by_id(initial_weapon_id)
	if initial_weapon:
		add_weapon(initial_weapon)
	else:
		var pistol := _create_pistol()
		add_weapon(pistol)

func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	
	# 定期刷新最近敌人缓存
	_enemy_cache_timer += delta
	if _enemy_cache_timer >= ENEMY_CACHE_INTERVAL:
		_enemy_cache_timer = 0.0
		_refresh_enemy_cache()
	
	for weapon in weapons:
		var timer_key: String = weapon.weapon_id
		if shoot_timers.has(timer_key):
			var timer: Timer = shoot_timers[timer_key]
			if timer.is_stopped():
				_fire_weapon(weapon)
				timer.start(weapon.get_scaled_fire_rate())

func add_weapon(weapon_data) -> void:
	for existing in weapons:
		if existing.weapon_id == weapon_data.weapon_id:
			if existing.level_up():
				weapon_leveled_up.emit(existing)
				if existing.is_max_level():
					# 满级时创建进化数据
					_create_weapon_evolution(existing)
				print("武器升级: %s Lv.%d" % [existing.weapon_name, existing.current_level])
			return
	weapons.append(weapon_data)

	# 记录武器使用类型（成就统计）
	var ach_mgr := get_node_or_null("/root/AchievementManager")
	if ach_mgr:
		ach_mgr.record_weapon_used(weapon_data.weapon_id)

	var timer := Timer.new()
	timer.wait_time = weapon_data.get_scaled_fire_rate()
	timer.one_shot = true
	add_child(timer)
	shoot_timers[weapon_data.weapon_id] = timer
	weapon_added.emit(weapon_data)
	print("获得武器: %s" % weapon_data.weapon_name)

func _create_weapon_evolution(weapon) -> void:
	## 为满级武器创建进化数据
	if weapon_evolutions.has(weapon.weapon_id):
		return
	
	var config: Dictionary = EVOLUTION_CONFIG.get(weapon.weapon_id, {})
	if config.is_empty():
		return
	
	var evolution := WeaponEvolutionScript.new()
	evolution.evolution_name = config.get("evolution_name", "进化武器")
	evolution.evolution_description = config.get("evolution_description", "")
	evolution.evolution_icon = config.get("evolution_icon", "✨")
	evolution.required_passive_items = config.get("required_passive_items", [])
	evolution.required_kill_count = config.get("required_kill_count", 50)
	evolution.damage_multiplier = config.get("damage_multiplier", 2.0)
	evolution.fire_rate_multiplier = config.get("fire_rate_multiplier", 0.5)
	evolution.size_multiplier = config.get("size_multiplier", 1.5)
	evolution.special_effect = config.get("special_effect", "")
	
	weapon_evolutions[weapon.weapon_id] = evolution
	print("⚔️ %s 已达到满级，满足条件后可进化为 %s" % [weapon.weapon_name, evolution.evolution_name])

func check_evolution_conditions(kill_count: int, owned_passives: Array) -> void:
	## 检查是否有武器可以进化
	for weapon_id in weapon_evolutions:
		var evolution: WeaponEvolution = weapon_evolutions[weapon_id]
		if evolution.can_evolve(kill_count, owned_passives):
			_evolve_weapon(weapon_id, evolution)

func _evolve_weapon(weapon_id: String, evolution: WeaponEvolution) -> void:
	## 执行武器进化
	evolution.evolve()

	# 找到对应的武器
	for weapon in weapons:
		if weapon.weapon_id == weapon_id:
			# 更新武器属性
			weapon.base_damage = evolution.get_evolved_damage(weapon.base_damage)
			weapon.fire_rate = evolution.get_evolved_fire_rate(weapon.fire_rate)
			# 更新武器显示名称
			weapon.weapon_name = evolution.evolution_name
			weapon.description = evolution.evolution_description
			weapon.icon_emoji = evolution.evolution_icon

			# 更新计时器
			if shoot_timers.has(weapon_id):
				shoot_timers[weapon_id].wait_time = weapon.get_scaled_fire_rate()

			weapon_evolved.emit(weapon, evolution)
			print("✨ %s 已进化为 %s!" % [weapon_id, evolution.evolution_name])

			# 视觉与音效反馈
			var vfx := get_node_or_null("/root/VFXManager")
			if vfx and player and is_instance_valid(player):
				var theme_color := _get_evolution_color(weapon_id)
				vfx.spawn_evolution_effect(player.global_position, theme_color)
				vfx.screen_shake(6.0, 0.35)

			# 播放进化音效
			AudioManager.play_sfx(_audio_lib.get_sound("level_up"))
			break

func _get_evolution_color(weapon_id: String) -> Color:
	match weapon_id:
		"pistol":
			return Color(1.0, 0.9, 0.4, 0.9)   # 神圣金
		"shotgun":
			return Color(1.0, 0.4, 0.2, 0.9)   # 爆裂橙红
		"magic_book":
			return Color(0.8, 0.3, 0.9, 0.9)   # 魔导紫
		"throwing_knife":
			return Color(0.4, 0.9, 0.95, 0.9)  # 刀阵青
		"poison_cloud":
			return Color(0.4, 0.9, 0.3, 0.9)   # 瘟疫绿
		"lightning_chain":
			return Color(1.0, 0.95, 0.3, 0.9)  # 雷电黄
	return Color(1.0, 0.85, 0.3, 0.9)

func get_weapon_evolution(weapon_id: String) -> WeaponEvolution:
	return weapon_evolutions.get(weapon_id, null)

func is_weapon_evolved(weapon_id: String) -> bool:
	if weapon_evolutions.has(weapon_id):
		return weapon_evolutions[weapon_id].is_evolved
	return false

func _fire_weapon(weapon) -> void:
	if player == null or not is_instance_valid(player):
		return
	
	# 特殊武器类型处理
	match weapon.weapon_id:
		"poison_cloud":
			_spawn_poison_cloud(weapon)
			return
		"lightning_chain":
			_spawn_lightning_chain(weapon)
			return
	
	var origin: Vector2 = player.global_position
	var base_direction: Vector2
	if weapon.auto_aim:
		base_direction = _get_nearest_enemy_direction(origin)
	else:
		base_direction = (player.get_global_mouse_position() - origin).normalized()
	if base_direction == Vector2.ZERO:
		return
	var count: int = weapon.get_scaled_projectile_count()
	var total_spread: float = weapon.spread_angle
	for i in range(count):
		var angle_offset: float = 0.0
		if count > 1:
			angle_offset = lerp(-total_spread / 2.0, total_spread / 2.0, float(i) / float(count - 1))
		var direction := base_direction.rotated(angle_offset)
		_spawn_bullet(origin, direction, weapon)

func _spawn_bullet(origin: Vector2, direction: Vector2, weapon) -> void:
	# 根据武器类型创建不同的子弹
	var bullet: Area2D
	if weapon.weapon_id == "throwing_knife":
		bullet = KnifeBulletScene.instantiate()
		# 设置穿透数
		if bullet.has_method("set_pierce_count"):
			bullet.set_pierce_count(weapon.get_scaled_pierce_count())
	else:
		bullet = bullet_scene.instantiate()

	bullet.global_position = origin + direction * 16.0
	bullet.direction = direction
	bullet.speed = weapon.bullet_speed
	bullet.base_damage = weapon.get_scaled_damage()
	# 根据房间大小限制子弹射程，避免穿越房间
	var room_size: float = 800.0
	if player and is_instance_valid(player):
		var room := player.get_parent()
		if room and room.has_method("get_room_size"):
			room_size = room.get_room_size()
	# 子弹射程不超过房间对角线的一半
	bullet.max_range = minf(weapon.bullet_range, room_size * 0.6)
	# 使用玩家的总伤害倍率（包含狂战士之血等被动效果）
	if player and player.has_method("get_total_damage_multiplier"):
		bullet.damage_multiplier = player.get_total_damage_multiplier()
	else:
		bullet.damage_multiplier = player.damage_multiplier if player else 1.0

	# 进化后视觉强化
	var is_evolved: bool = is_weapon_evolved(weapon.weapon_id)
	if bullet.has_node("Sprite2D"):
		var spr := bullet.get_node("Sprite2D") as Sprite2D
		if is_evolved:
			spr.modulate = _get_evolution_color(weapon.weapon_id)
			var evo: WeaponEvolution = weapon_evolutions.get(weapon.weapon_id, null)
			if evo:
				spr.scale *= evo.size_multiplier
		else:
			spr.modulate = Color.WHITE

	get_tree().current_scene.add_child(bullet)

	# 播放射击音效
	_play_shoot_sound(weapon.weapon_id)

func _refresh_enemy_cache() -> void:
	## 刷新最近敌人方向和位置缓存
	if player == null or not is_instance_valid(player):
		_nearest_enemy_dir = Vector2.ZERO
		_nearest_enemy_pos = Vector2.ZERO
		return
	
	var origin := player.global_position
	var enemies := get_tree().get_nodes_in_group("enemies")
	var nearest_dist: float = INF
	var nearest_pos: Vector2 = Vector2.ZERO
	
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var dist := origin.distance_squared_to(enemy.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest_pos = enemy.global_position
	
	_nearest_enemy_pos = nearest_pos
	if nearest_pos != Vector2.ZERO:
		_nearest_enemy_dir = (nearest_pos - origin).normalized()
	else:
		_nearest_enemy_dir = Vector2.ZERO

func _get_nearest_enemy_direction(from: Vector2) -> Vector2:
	# 如果缓存有效直接返回，否则实时计算一次
	if _nearest_enemy_dir != Vector2.ZERO:
		return _nearest_enemy_dir
	
	var enemies := get_tree().get_nodes_in_group("enemies")
	var nearest_dist: float = INF
	var nearest_dir: Vector2 = Vector2.ZERO
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var dist := from.distance_squared_to(enemy.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest_dir = (enemy.global_position - from).normalized()
	return nearest_dir

func _create_pistol() -> Resource:
	var w = WeaponDataScript.new()
	w.weapon_name = "手枪"
	w.weapon_id = "pistol"
	w.description = "可靠的基础武器"
	w.icon_emoji = "🔫"
	w.base_damage = 2.5
	w.fire_rate = 0.35
	w.bullet_speed = 500.0
	w.bullet_range = 800.0
	w.projectile_count = 1
	w.spread_angle = 0.0
	w.auto_aim = false
	return w

static func create_shotgun() -> Resource:
	var script = preload("res://scripts/weapons/weapon_data.gd")
	var w = script.new()
	w.weapon_name = "散弹枪"
	w.weapon_id = "shotgun"
	w.description = "近距离扇形射击"
	w.icon_emoji = "💥"
	w.base_damage = 3.0
	w.fire_rate = 0.8
	w.bullet_speed = 400.0
	w.bullet_range = 400.0
	w.projectile_count = 3
	w.spread_angle = 0.5
	w.auto_aim = false
	return w

static func create_magic_book() -> Resource:
	var script = preload("res://scripts/weapons/weapon_data.gd")
	var w = script.new()
	w.weapon_name = "魔法书"
	w.weapon_id = "magic_book"
	w.description = "自动追踪最近的敌人"
	w.icon_emoji = "📖"
	w.base_damage = 4.0
	w.fire_rate = 0.6
	w.bullet_speed = 350.0
	w.bullet_range = 600.0
	w.projectile_count = 1
	w.spread_angle = 0.0
	w.auto_aim = true
	return w

func _play_shoot_sound(weapon_id: String) -> void:
	var sound_name: String = "shoot_pistol"
	match weapon_id:
		"shotgun":
			sound_name = "shoot_shotgun"
		"magic_book":
			sound_name = "shoot_magic"
		"throwing_knife":
			sound_name = "knife_throw"
		"poison_cloud":
			sound_name = "poison_cloud"
		"lightning_chain":
			sound_name = "lightning_chain"
	var sound := _audio_lib.get_sound(sound_name)
	AudioManager.play_sfx(sound)

static func create_throwing_knife() -> Resource:
	var script = preload("res://scripts/weapons/weapon_data.gd")
	var w = script.new()
	w.weapon_name = "飞刀"
	w.weapon_id = "throwing_knife"
	w.description = "穿透敌人的飞刀"
	w.icon_emoji = "🔪"
	w.base_damage = 6.0
	w.fire_rate = 0.5
	w.bullet_speed = 450.0
	w.bullet_range = 500.0
	w.projectile_count = 1
	w.spread_angle = 0.0
	w.auto_aim = true
	w.pierce_count = 3  # 基础穿透3个
	return w

static func create_poison_cloud() -> Resource:
	var script = preload("res://scripts/weapons/weapon_data.gd")
	var w = script.new()
	w.weapon_name = "毒雾瓶"
	w.weapon_id = "poison_cloud"
	w.description = "投掷毒雾造成持续伤害"
	w.icon_emoji = "☠️"
	w.base_damage = 2.5
	w.fire_rate = 1.5
	w.bullet_speed = 0.0
	w.bullet_range = 0.0
	w.projectile_count = 1
	w.spread_angle = 0.0
	w.auto_aim = true
	w.cloud_duration = 5.0
	w.cloud_size = 1.0
	return w

static func create_lightning_chain() -> Resource:
	var script = preload("res://scripts/weapons/weapon_data.gd")
	var w = script.new()
	w.weapon_name = "闪电法杖"
	w.weapon_id = "lightning_chain"
	w.description = "闪电在敌人之间跳跃"
	w.icon_emoji = "⚡"
	w.base_damage = 7.5
	w.fire_rate = 0.8
	w.bullet_speed = 0.0
	w.bullet_range = 0.0
	w.projectile_count = 1
	w.spread_angle = 0.0
	w.auto_aim = true
	w.lightning_jumps = 3
	return w

func _create_weapon_by_id(weapon_id: String):
	match weapon_id:
		"pistol":
			return _create_pistol()
		"shotgun":
			return create_shotgun()
		"magic_book":
			return create_magic_book()
		"throwing_knife":
			return create_throwing_knife()
		"poison_cloud":
			return create_poison_cloud()
		"lightning_chain":
			return create_lightning_chain()
	return null

func _spawn_poison_cloud(weapon) -> void:
	var cloud := PoisonCloudScene.instantiate()
	# 自动瞄准最近的敌人位置投掷
	var target_pos := _get_nearest_enemy_position(player.global_position)
	if target_pos == Vector2.ZERO:
		target_pos = player.global_position + Vector2(randf_range(-100, 100), randf_range(-100, 100))
	cloud.global_position = target_pos
	cloud.base_damage = weapon.get_scaled_damage()
	cloud.damage_multiplier = player.damage_multiplier if player else 1.0
	cloud.duration = weapon.get_scaled_cloud_duration()
	cloud.set_size(weapon.get_scaled_cloud_size())
	get_tree().current_scene.add_child(cloud)
	_play_shoot_sound(weapon.weapon_id)

func _spawn_lightning_chain(weapon) -> void:
	var lightning := LightningChainScene.instantiate()
	lightning.global_position = player.global_position
	lightning.base_damage = weapon.get_scaled_damage()
	lightning.damage_multiplier = player.damage_multiplier if player else 1.0
	lightning.max_jumps = weapon.get_scaled_lightning_jumps()
	lightning._current_damage = lightning.base_damage
	get_tree().current_scene.add_child(lightning)
	_play_shoot_sound(weapon.weapon_id)

func _get_nearest_enemy_position(from: Vector2) -> Vector2:
	# 优先使用缓存位置
	if _nearest_enemy_pos != Vector2.ZERO:
		return _nearest_enemy_pos
	
	var enemies := get_tree().get_nodes_in_group("enemies")
	var nearest_pos := Vector2.ZERO
	var nearest_dist: float = INF
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var dist := from.distance_squared_to(enemy.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest_pos = enemy.global_position
	return nearest_pos
