@static_unload
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
## 暗边尺寸倍率与浓度。
## 纯加色亮芯在浅色石砖上会"糊进"地板（加色只能变亮，亮地板本来就近饱和），
## 所以在亮芯**底下**再垫一层不发光、比地板暗的柔边轮廓：
## 深色地板靠亮芯发光，浅色地板靠暗边定形，两种场景至少有一种拉得开。
const OUTLINE_SCALE: float = 1.55
const OUTLINE_ALPHA: float = 0.72
const OUTLINE_COLOR := Color(0.05, 0.02, 0.08)
var direction: Vector2 = Vector2.RIGHT
var damage: float = 10.0
var distance_traveled: float = 0.0
var _age: float = 0.0

## 暗边材质全场共享：每个弹丸 new 一份会在同屏几十发时白占几十份等价资源，
## 材质内容恒定，静态惰性创建一次即可（同 ProjectileVisuals.get_additive_material）。
static var _outline_material: CanvasItemMaterial = null

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	# 进组是为了让远程敌人能查"场上现在有几发在飞"，
	# 超过 GameConfig.ENEMY_PROJECTILE_CAP_BY_FLOOR 就暂停开火
	add_to_group("enemy_projectiles")
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
	_ensure_outline(length, thickness)

func _ensure_outline(length: float, thickness: float) -> void:
	## 暗边必须在亮芯之前画（子节点顺序决定同 z_index 下的绘制顺序）。
	## 只在尺寸变化时改缩放，换色不动它——暗边永远是同一层"剪影"。
	var outline := get_node_or_null("Outline") as Sprite2D
	if outline == null:
		outline = Sprite2D.new()
		outline.name = "Outline"
		add_child(outline)
		move_child(outline, 0)
		outline.texture = ProjectileVisuals.get_orb_texture()
		outline.material = _get_outline_material()
		outline.modulate = Color(OUTLINE_COLOR.r, OUTLINE_COLOR.g, OUTLINE_COLOR.b, OUTLINE_ALPHA)
	outline.z_index = 0
	var tex_size: Vector2 = outline.texture.get_size()
	var diameter: float = maxf(length, thickness) * OUTLINE_SCALE
	outline.scale = Vector2(diameter / tex_size.x, diameter / tex_size.y)

static func _get_outline_material() -> CanvasItemMaterial:
	if _outline_material == null:
		_outline_material = CanvasItemMaterial.new()
		_outline_material.blend_mode = CanvasItemMaterial.BLEND_MODE_MIX
	return _outline_material

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

func _on_area_entered(area: Node2D) -> void:
	## 玩家子弹能打掉敌方弹丸。
	## 场景里一直连着 area_entered，但这个方法从来没实现过：
	## 报错刷屏的同时，"玩家用子弹挡弹幕"这件事其实一次都没发生过。
	## 口径：撞上就销毁**敌方弹丸**，玩家子弹照飞不误（谁挡谁，不互相抵消）。
	##
	## 判定用"是不是玩家弹丸"，而不是物理层：毒雾和血爆也挂在 LAYER_BULLET 上，
	## 按层判断的话，玩家一圈毒雾就把射向自己的敌方弹幕一只只吃掉，
	## 双方都看不见发生了什么。玩家弹丸（手枪弹 / 飞刀 / 弩箭 / 圣光弹）
	## 都有 get_damage()，范围效果没有，用这个接口区分最省事。
	if area == null or not is_instance_valid(area):
		return
	if area.has_method("get_damage"):
		queue_free()

static func clear_shared_resources() -> void:
	_outline_material = null
