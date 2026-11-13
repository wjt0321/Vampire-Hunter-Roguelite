extends Area2D
## 飞刀子弹
## 可穿透多个敌人

@export var speed: float = 450.0
@export var base_damage: float = 12.0
@export var max_range: float = 500.0
var direction: Vector2 = Vector2.RIGHT
var damage_multiplier: float = 1.0
var distance_traveled: float = 0.0

# === 外观 ===
@export var visual_color: Color = Color(0.72, 0.86, 1.0)
@export var visual_length: float = 22.0
@export var visual_thickness: float = 8.0

# 穿透相关
var max_pierce: int = 3          # 最大穿透数
var pierce_count: int = 0        # 已穿透数
var hit_enemies: Array = []      # 已击中的敌人（避免重复伤害）
## 弹墙次数。飞刀 4 级给 1 次，命中墙后折返，不叠在穿透次数上。
var bounces_left: int = 0
var fusion_kind: String = ""
var _released: bool = false

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	_setup_visuals()

func _setup_visuals() -> void:
	# 设置飞刀旋转方向
	rotation = direction.angle()
	apply_visual_style(visual_color, visual_length, visual_thickness)

func apply_visual_style(color: Color, length: float = 22.0, thickness: float = 8.0, _round_shape: bool = false) -> void:
	## 由武器管理器在发射时调用（对象池复用的弹丸不会重跑 _ready）
	visual_color = color
	visual_length = length
	visual_thickness = thickness
	if sprite == null:
		sprite = get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		return
	ProjectileVisuals.style_sprite(sprite, color, length, thickness)

func reset_for_pool() -> void:
	## 归还对象池前重置状态
	distance_traveled = 0.0
	pierce_count = 0
	bounces_left = 0
	fusion_kind = ""
	_released = false
	hit_enemies.clear()
	rotation = 0.0
	modulate = Color.WHITE
	scale = Vector2.ONE

func _notify_fusion(reason: String) -> void:
	if fusion_kind == "" or not is_inside_tree():
		return
	var wm := get_tree().get_first_node_in_group("weapon_manager")
	if wm != null and wm.has_method("on_projectile_event"):
		wm.on_projectile_event(self, reason)

func _release(reason: String) -> void:
	if _released:
		return
	_released = true
	_notify_fusion(reason)
	ObjectPool.release(self)

func _bounce() -> void:
	bounces_left -= 1
	direction = -direction
	rotation = direction.angle()
	position += direction * 10.0
	hit_enemies.clear()

func _physics_process(delta: float) -> void:
	var move_distance := speed * delta
	position += direction * move_distance
	distance_traveled += move_distance
	
	# 飞刀拖尾（用自身颜色）
	var vfx := get_node_or_null("/root/VFXManager")
	if vfx and Engine.get_physics_frames() % 5 == 0:
		vfx.spawn_bullet_trail(global_position, Color(visual_color.r, visual_color.g, visual_color.b, 0.5))
	
	# 超出射程后归还对象池
	if distance_traveled >= max_range:
		_release("range")

func get_damage() -> float:
	return base_damage * damage_multiplier

func _on_body_entered(body: Node2D) -> void:
	# 碰到墙壁
	if body.is_in_group("walls"):
		if bounces_left > 0:
			_bounce()
			return
		_release("wall")
		return
	
	# 碰到敌人
	if body.has_method("take_damage"):
		# 避免重复伤害同一敌人
		if hit_enemies.has(body):
			return
		
		body.take_damage(get_damage())
		hit_enemies.append(body)
		# 雷矢的跳跃跟在这一下命中后面，不等弹丸彻底消失。
		_notify_fusion("hit")
		
		# 检查是否还能穿透
		pierce_count += 1
		if pierce_count >= max_pierce:
			_release("hit")
		else:
			# 穿透时产生小特效
			var vfx := get_node_or_null("/root/VFXManager")
			if vfx:
				vfx.spawn_hit_particles(global_position, Color.SILVER, 2)

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("walls"):
		if bounces_left > 0:
			_bounce()
			return
		_release("wall")

func set_pierce_count(count: int) -> void:
	max_pierce = count
