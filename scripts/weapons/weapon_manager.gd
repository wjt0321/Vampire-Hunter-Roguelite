extends Node
class_name WeaponManager
## 武器管理器

const WeaponDataScript = preload("res://scripts/weapons/weapon_data.gd")

var weapons: Array = []
var shoot_timers: Dictionary = {}
var player: CharacterBody2D = null
var bullet_scene: PackedScene = preload("res://scenes/player/bullet.tscn")

signal weapon_added(weapon: Resource)
signal weapon_leveled_up(weapon: Resource)
signal weapon_evolved(weapon: Resource)

func setup(player_node: CharacterBody2D) -> void:
	player = player_node
	var pistol := _create_pistol()
	add_weapon(pistol)

func _process(_delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
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
					weapon_evolved.emit(existing)
				print("武器升级: %s Lv.%d" % [existing.weapon_name, existing.current_level])
			return
	weapons.append(weapon_data)
	var timer := Timer.new()
	timer.wait_time = weapon_data.get_scaled_fire_rate()
	timer.one_shot = true
	add_child(timer)
	shoot_timers[weapon_data.weapon_id] = timer
	weapon_added.emit(weapon_data)
	print("获得武器: %s" % weapon_data.weapon_name)

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
		bullet = preload("res://scenes/player/knife_bullet.tscn").instantiate()
		# 设置穿透数
		if bullet.has_method("set_pierce_count"):
			bullet.set_pierce_count(weapon.get_scaled_pierce_count())
	else:
		bullet = bullet_scene.instantiate()
	
	bullet.global_position = origin + direction * 16.0
	bullet.direction = direction
	bullet.speed = weapon.bullet_speed
	bullet.base_damage = weapon.get_scaled_damage()
	bullet.max_range = weapon.bullet_range
	bullet.damage_multiplier = player.damage_multiplier if player else 1.0
	get_tree().current_scene.add_child(bullet)
	
	# 播放射击音效
	_play_shoot_sound(weapon.weapon_id)

func _get_nearest_enemy_direction(from: Vector2) -> Vector2:
	var enemies := get_tree().get_nodes_in_group("enemies")
	var nearest_dist: float = INF
	var nearest_dir: Vector2 = Vector2.ZERO
	for enemy in enemies:
		if not is_instance_valid(enemy) or not enemy is CharacterBody2D:
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
	w.base_damage = 10.0
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
	w.base_damage = 6.0
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
	w.base_damage = 8.0
	w.fire_rate = 0.6
	w.bullet_speed = 350.0
	w.bullet_range = 600.0
	w.projectile_count = 1
	w.spread_angle = 0.0
	w.auto_aim = true
	return w

func _play_shoot_sound(weapon_id: String) -> void:
	var audio_lib := AudioLibrary.new()
	var sound_name: String = "shoot_pistol"
	match weapon_id:
		"shotgun":
			sound_name = "shoot_shotgun"
		"magic_book":
			sound_name = "shoot_magic"
		"throwing_knife":
			sound_name = "shoot_pistol"  # 飞刀使用相同音效
	var sound := audio_lib.get_sound(sound_name)
	AudioManager.play_sfx(sound)

static func create_throwing_knife() -> Resource:
	var script = preload("res://scripts/weapons/weapon_data.gd")
	var w = script.new()
	w.weapon_name = "飞刀"
	w.weapon_id = "throwing_knife"
	w.description = "穿透敌人的飞刀"
	w.icon_emoji = "🔪"
	w.base_damage = 12.0
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
	w.base_damage = 5.0
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
	w.base_damage = 15.0
	w.fire_rate = 0.8
	w.bullet_speed = 0.0
	w.bullet_range = 0.0
	w.projectile_count = 1
	w.spread_angle = 0.0
	w.auto_aim = true
	w.lightning_jumps = 3
	return w

func _spawn_poison_cloud(weapon) -> void:
	var cloud := preload("res://scenes/player/poison_cloud.tscn").instantiate()
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
	var lightning := preload("res://scenes/player/lightning_chain.tscn").instantiate()
	lightning.global_position = player.global_position
	lightning.base_damage = weapon.get_scaled_damage()
	lightning.damage_multiplier = player.damage_multiplier if player else 1.0
	lightning.max_jumps = weapon.get_scaled_lightning_jumps()
	lightning._current_damage = lightning.base_damage
	get_tree().current_scene.add_child(lightning)
	_play_shoot_sound(weapon.weapon_id)

func _get_nearest_enemy_position(from: Vector2) -> Vector2:
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
