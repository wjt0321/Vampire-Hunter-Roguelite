extends Area2D
## 敌人投射物
## 骷髅射手等远程敌人发射的投射物

@export var speed: float = 250.0
@export var max_range: float = 500.0
## 存活时间（秒）。<= 0 表示只靠 max_range 销毁。
## 吸血鬼法师会把这里设成 3.0，之前脚本没有这个属性，导致每次施法都报错刷屏。
@export var lifetime: float = 0.0
## 弹道颜色（法师改成紫色，射手保持血红）
@export var visual_color: Color = Color(1.0, 0.28, 0.22)
## 视觉尺寸（像素）。刻意比碰撞体略大：看着够大，判定仍然好躲
@export var visual_length: float = 16.0
@export var visual_thickness: float = 10.0
var direction: Vector2 = Vector2.RIGHT
var damage: float = 10.0
var distance_traveled: float = 0.0
var _age: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	# "亮芯 + 柔光"外观：早期 8x4 暗红方块在混战里几乎看不见
	apply_visual_style(visual_color, visual_length, visual_thickness)
	# 设置旋转朝向
	rotation = direction.angle()

func apply_visual_style(color: Color, length: float = 16.0, thickness: float = 10.0) -> void:
	visual_color = color
	visual_length = length
	visual_thickness = thickness
	if sprite == null:
		sprite = get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		return
	ProjectileVisuals.style_sprite(sprite, color, length, thickness, true)

func _physics_process(delta: float) -> void:
	var move_distance := speed * delta
	position += direction * move_distance
	distance_traveled += move_distance
	_age += delta

	# 时间寿命（法师法术弹幕用）
	if lifetime > 0.0 and _age >= lifetime:
		queue_free()
		return

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
