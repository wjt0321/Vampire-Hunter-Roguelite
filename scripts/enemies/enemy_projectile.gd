extends Area2D
## 敌人投射物
## 骷髅射手等远程敌人发射的投射物

@export var speed: float = 250.0
@export var max_range: float = 500.0
var direction: Vector2 = Vector2.RIGHT
var damage: float = 10.0
var distance_traveled: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	# 自动创建纹理
	if sprite and sprite.texture == null:
		var img := Image.create(8, 4, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.8, 0.2, 0.2, 1.0))  # 暗红色
		sprite.texture = ImageTexture.create_from_image(img)
	
	# 设置旋转朝向
	rotation = direction.angle()
	
	# 连接碰撞信号
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	var move_distance := speed * delta
	position += direction * move_distance
	distance_traveled += move_distance
	
	# 超出射程后销毁
	if distance_traveled >= max_range:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	# 碰到玩家造成伤害
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage)
		queue_free()
	# 碰到墙壁销毁
	elif body.is_in_group("walls"):
		queue_free()
