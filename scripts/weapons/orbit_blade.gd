extends Node2D
class_name OrbitBlade
## 进化飞刀的"刀阵环绕"：飞刀不再掷出，而是围绕玩家旋转持续绞杀。
##
## 为什么不做成 Area2D + 碰撞回调：
## 环绕刀刃每帧都在怪物身上，Area2D 的 enter/exit 只会在刚贴上时触发一次，
## 要做"持续伤害"还是得自己算冷却。既然都要算，直接用距离判定更可控，也好测。

## 每把刀对同一个敌人的再次命中间隔（秒）
const HIT_INTERVAL: float = 0.45
## 判定半径（视觉 22px，判定略小，避免"看着没碰到却掉血"）
const HIT_RADIUS: float = 20.0

var player: Node2D = null
var angle_offset: float = 0.0
var orbit_radius: float = 92.0
var angular_speed: float = 4.2
var damage: float = 10.0
var damage_multiplier: float = 1.0
var weapon_manager: Node = null
var weapon: Resource = null
var color: Color = Color(0.4, 0.9, 0.95)

var _angle: float = 0.0
var _sprite: Sprite2D = null
## instance_id -> 剩余冷却秒数
var _cooldowns: Dictionary = {}

func init_orbit(target: Node2D, offset_angle: float, radius: float, dmg: float, mult: float, tint: Color) -> void:
	player = target
	angle_offset = offset_angle
	orbit_radius = radius
	damage = dmg
	damage_multiplier = mult
	color = tint
	# 从当前角度起飞，避免六把刀同时从 0 度弹出来
	_angle = 0.0

func _ready() -> void:
	z_index = 6
	_sprite = Sprite2D.new()
	# 复用弹道视觉：同一条"亮芯 + 光晕"的生成管线，颜色跟武器一致
	if ProjectileVisuals:
		ProjectileVisuals.style_sprite(_sprite, color, 24.0, 7.0, false)
	add_child(_sprite)

func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		queue_free()
		return

	_angle += angular_speed * delta
	var offset := Vector2(cos(_angle + angle_offset), sin(_angle + angle_offset))
	global_position = player.global_position + offset * orbit_radius
	rotation = _angle + angle_offset + PI * 0.5

	_tick_cooldowns(delta)
	_strike(delta)

func _tick_cooldowns(delta: float) -> void:
	for key in _cooldowns.keys():
		var left: float = float(_cooldowns[key]) - delta
		if left <= 0.0:
			_cooldowns.erase(key)
		else:
			_cooldowns[key] = left

func _strike(_delta: float) -> void:
	var enemies := get_tree().get_nodes_in_group("enemies")
	var radius_sq: float = HIT_RADIUS * HIT_RADIUS
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if enemy.get("is_dead") == true:
			continue
		var id: int = enemy.get_instance_id()
		if _cooldowns.has(id):
			continue
		if global_position.distance_squared_to(enemy.global_position) > radius_sq:
			continue

		_cooldowns[id] = HIT_INTERVAL
		var dmg: float = get_current_damage()
		var dir: Vector2 = (enemy.global_position - global_position).normalized()
		if enemy.has_method("take_damage_with_knockback"):
			enemy.take_damage_with_knockback(dmg, dir, 40.0, 0.03)
		elif enemy.has_method("take_damage"):
			enemy.take_damage(dmg)

func get_current_damage() -> float:
	var mult := damage_multiplier
	if is_instance_valid(player) and player.has_method("get_total_damage_multiplier"):
		mult = player.get_total_damage_multiplier()
	if is_instance_valid(weapon_manager) and weapon != null:
		mult *= weapon_manager.get_weapon_decay(weapon)
		return weapon.get_scaled_damage() * 0.55 * mult
	return damage * mult
