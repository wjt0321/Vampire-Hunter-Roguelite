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
	var bullet := bullet_scene.instantiate() as Area2D
	bullet.global_position = origin + direction * 16.0
	bullet.direction = direction
	bullet.speed = weapon.bullet_speed
	bullet.base_damage = weapon.get_scaled_damage()
	bullet.max_range = weapon.bullet_range
	bullet.damage_multiplier = player.damage_multiplier if player else 1.0
	get_tree().current_scene.add_child(bullet)

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
