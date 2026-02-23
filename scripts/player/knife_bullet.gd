extends Area2D
## 飞刀子弹
## 可穿透多个敌人

@export var speed: float = 450.0
@export var base_damage: float = 12.0
@export var max_range: float = 500.0
var direction: Vector2 = Vector2.RIGHT
var damage_multiplier: float = 1.0
var distance_traveled: float = 0.0

# 穿透相关
var max_pierce: int = 3          # 最大穿透数
var pierce_count: int = 0        # 已穿透数
var hit_enemies: Array = []      # 已击中的敌人（避免重复伤害）

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	# 设置飞刀旋转方向
	rotation = direction.angle()
	# 自动创建纹理（长条形飞刀）
	if sprite and sprite.texture == null:
		var img := Image.create(16, 4, false, Image.FORMAT_RGBA8)
		img.fill(Color.SILVER)
		sprite.texture = ImageTexture.create_from_image(img)

func _physics_process(delta: float) -> void:
	var move_distance := speed * delta
	position += direction * move_distance
	distance_traveled += move_distance
	
	# 飞刀拖尾（较少）
	var vfx := get_node_or_null("/root/VFXManager")
	if vfx and Engine.get_physics_frames() % 5 == 0:
		vfx.spawn_bullet_trail(global_position)
	
	# 超出射程后销毁
	if distance_traveled >= max_range:
		queue_free()

func get_damage() -> float:
	return base_damage * damage_multiplier

func _on_body_entered(body: Node2D) -> void:
	# 碰到敌人
	if body.has_method("take_damage"):
		# 避免重复伤害同一敌人
		if hit_enemies.has(body):
			return
		
		body.take_damage(get_damage())
		hit_enemies.append(body)
		
		# 检查是否还能穿透
		pierce_count += 1
		if pierce_count >= max_pierce:
			queue_free()
		else:
			# 穿透时产生小特效
			var vfx := get_node_or_null("/root/VFXManager")
			if vfx:
				vfx.spawn_hit_particles(global_position, Color.SILVER, 2)

func _on_area_entered(area: Area2D) -> void:
	# 碰到墙壁销毁（飞刀不能穿透墙壁）
	if area.is_in_group("walls"):
		queue_free()

func set_pierce_count(count: int) -> void:
	max_pierce = count
