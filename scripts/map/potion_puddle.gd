extends Node2D
## 炼金药液。玩家和敌人站进去都会掉血。
##
## 这块地上物以前是一块 Polygon2D 色块：硬边、多边形、没有贴图、永不过期。
## 三个后果都踩在试玩反馈上：
##   1) "图片有贴图痕迹" —— 硬边绿色色块和像素画场景格格不入；
##   2) "颜色太深污染画面" —— 一块暗绿直接盖在地板上；
##   3) "效果会带到下一场景" —— 它挂在主场景下，换房不清，还会继续掉血。
## 现在：用正式毒雾贴图、亮色低透明、定时消散，并登记 ground_effects 让换房清场。

## 药液存活时间（秒）。到期淡出并自行释放，不再无限期留在场上。
const DURATION: float = 6.0
## 贴图按 2×半径铺开：视觉面积 = 判定面积，玩家能看出"这里有东西"。
const SPRITE_SCALE_BASE: float = 140.0

var radius: float = 70.0
var tick: float = 0.5
var damage: float = 8.0
var _timer: float = 0.0
var _life: float = 0.0
var _expired: bool = false

func _ready() -> void:
	# 地面持续效果统一登记：换房时由 main 一次性清掉，不会带进下一间房。
	add_to_group("ground_effects")
	_build_visual()

func _build_visual() -> void:
	var sprite := Sprite2D.new()
	sprite.name = "PuddleSprite"
	# 正式毒雾贴图（单帧 128×128）。缺图时退化成径向渐变，
	# 不再拿一块实心色块顶替。
	var tex: Texture2D = null
	if TextureManager.instance != null:
		tex = TextureManager.instance.get_effect_texture("poison_spread")
	if tex == null and ResourceLoader.exists("res://assets/effects/poison_spread.png"):
		tex = load("res://assets/effects/poison_spread.png") as Texture2D
	if tex != null:
		sprite.texture = tex
		var w := maxf(float(tex.get_width()), 1.0)
		var h := maxf(float(tex.get_height()), 1.0)
		sprite.scale = Vector2(SPRITE_SCALE_BASE / w, SPRITE_SCALE_BASE / h)
		# 比玩家毒雾更亮、更薄：这是"敌人的药液"，不该比玩家自己的雾更抢眼。
		sprite.modulate = Color(0.95, 1.0, 0.62, 0.42)
	else:
		var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
		for y in 64:
			for x in 64:
				var dist := Vector2(x - 31.5, y - 31.5).length() / 32.0
				var alpha := 0.42 * clampf(1.0 - dist, 0.0, 1.0)
				img.set_pixel(x, y, Color(0.72, 0.95, 0.45, alpha))
		sprite.texture = ImageTexture.create_from_image(img)
		sprite.scale = Vector2(SPRITE_SCALE_BASE / 64.0, SPRITE_SCALE_BASE / 64.0)
	add_child(sprite)

func _process(delta: float) -> void:
	if _expired:
		return
	_life += delta
	if _life >= DURATION:
		_expired = true
		_fade_out()
		return
	_timer += delta
	if _timer < tick:
		return
	_timer = 0.0
	for node in get_tree().get_nodes_in_group("player"):
		_hurt(node)
	for node in get_tree().get_nodes_in_group("enemies"):
		if node.get("counts_as_enemy") == false:
			continue
		_hurt(node)

func _hurt(node: Node) -> void:
	if not is_instance_valid(node) or not (node is Node2D) or not node.has_method("take_damage"):
		return
	if global_position.distance_to((node as Node2D).global_position) <= radius:
		node.take_damage(damage)

func _fade_out() -> void:
	set_process(false)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	tween.tween_callback(queue_free)
