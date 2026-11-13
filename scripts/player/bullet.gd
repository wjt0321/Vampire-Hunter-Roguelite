extends Area2D
## 子弹脚本
## 沿指定方向飞行，碰到敌人造成伤害后消失

# 缓存的玩家引用
var _cached_player: Node = null

# === 属性 ===
@export var speed: float = 500.0
@export var base_damage: float = 10.0
@export var max_range: float = 800.0
var direction: Vector2 = Vector2.RIGHT
var damage_multiplier: float = 1.0
var distance_traveled: float = 0.0

# === 外观 ===
## 弹道颜色（由武器决定，决定发光色）
@export var visual_color: Color = Color(1.0, 0.87, 0.35)
## 视觉长度/厚度（像素）。比碰撞体略大，看着就"打得中"
@export var visual_length: float = 18.0
@export var visual_thickness: float = 9.0
## 是否圆形弹（法术球用）
@export var visual_round: bool = false

# 追踪相关
var homing: bool = false
var homing_strength: float = 8.0
var _homing_target: Node2D = null

## 融合行为。对象池复用，每次发射都要重写，归还时清空。
var fusion_kind: String = ""
var _released: bool = false

func _ready() -> void:
	# 缓存玩家引用
	_cached_player = get_tree().get_first_node_in_group("player")
	_setup_visuals()

func _setup_visuals() -> void:
	# 设置子弹旋转方向
	rotation = direction.angle()
	var spr := $Sprite2D as Sprite2D
	if spr == null:
		return
	# 统一走"亮芯+柔光"外观：早期 8x8 白方块在混战里基本看不见
	apply_visual_style(visual_color, visual_length, visual_thickness, visual_round)

func apply_visual_style(color: Color, length: float = 18.0, thickness: float = 9.0, round_shape: bool = false) -> void:
	## 由武器管理器在每次发射时调用（对象池复用的子弹不会重跑 _ready）
	visual_color = color
	visual_length = length
	visual_thickness = thickness
	visual_round = round_shape
	var spr := get_node_or_null("Sprite2D") as Sprite2D
	if spr == null:
		return
	ProjectileVisuals.style_sprite(spr, color, length, thickness, round_shape)

func reset_for_pool() -> void:
	## 归还对象池前重置状态
	distance_traveled = 0.0
	homing = false
	homing_strength = 8.0
	_homing_target = null
	_cached_player = null
	fusion_kind = ""
	_released = false
	rotation = 0.0
	modulate = Color.WHITE
	scale = Vector2.ONE
	# 摘掉火焰喷射器的粒子流，防止复用给别的武器时还拖着火
	var fire := get_node_or_null("FlameTrail")
	if fire != null:
		fire.queue_free()

func _physics_process(delta: float) -> void:
	if homing:
		_update_homing(delta)
	var move_distance := speed * delta
	position += direction * move_distance
	distance_traveled += move_distance
	# 子弹拖尾（用弹道本身的颜色，拖尾也跟着亮起来）
	var vfx := get_node_or_null("/root/VFXManager")
	if vfx and Engine.get_physics_frames() % 3 == 0:
		vfx.spawn_bullet_trail(global_position, Color(visual_color.r, visual_color.g, visual_color.b, 0.55))
	# 超出射程后归还对象池
	if distance_traveled >= max_range:
		_release("range")

func _update_homing(delta: float) -> void:
	if not is_instance_valid(_homing_target) or _homing_target.get("is_dead") == true:
		_homing_target = _find_nearest_enemy()
	if _homing_target and is_instance_valid(_homing_target):
		var target_dir := (_homing_target.global_position - global_position).normalized()
		direction = direction.move_toward(target_dir, homing_strength * delta).normalized()
		rotation = direction.angle()
	else:
		_homing_target = null

func _find_nearest_enemy() -> Node2D:
	var enemies := get_tree().get_nodes_in_group("enemies")
	var nearest: Node2D = null
	var nearest_dist: float = INF
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy.get("is_dead") == true:
			continue
		var dist := global_position.distance_squared_to(enemy.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = enemy
	return nearest

func get_damage() -> float:
	return base_damage * damage_multiplier

func _release(reason: String) -> void:
	if _released:
		return
	_released = true
	if fusion_kind != "" and is_inside_tree():
		var wm := get_tree().get_first_node_in_group("weapon_manager")
		if wm != null and wm.has_method("on_projectile_event"):
			wm.on_projectile_event(self, reason)
	ObjectPool.release(self)

func _on_body_entered(body: Node2D) -> void:
	# 碰到墙壁
	if body.is_in_group("walls"):
		_release("wall")
		return
	# 碰到敌人
	if body.has_method("take_damage"):
		var dmg := get_damage()
		# Direct hit passives resolve once in the enemy damage entry.
		if not is_instance_valid(_cached_player):
			_cached_player = get_tree().get_first_node_in_group("player")
		var knockback_dir := direction
		if body.has_method("take_damage_with_knockback"):
			body.take_damage_with_knockback(dmg, knockback_dir, 120.0, 0.08)
		else:
			body.take_damage(dmg)
	_release("hit")

func _on_area_entered(area: Area2D) -> void:
	# 碰到墙壁等
	if area.is_in_group("walls"):
		_release("wall")
