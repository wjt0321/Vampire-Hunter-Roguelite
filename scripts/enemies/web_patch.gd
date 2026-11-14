extends StaticBody2D
## 可打掉的减速网。不算一只怪，不占刷怪名额。
##
## 以前没有网的贴图，用一块半透明绿色多边形标出范围：
## 和像素画场景完全不像（试玩反馈："部分场景有错误贴图"），
## 而且它永远是静止的（"还有一些没有动态帧的"）。
## 现在用正式的蛛网贴图，并给它一点缓慢的呼吸。

const WEB_TEXTURE := "res://assets/tiles/props/cobweb.png"
## 视觉直径对齐判定半径 34。
const WEB_DIAMETER: float = 68.0

var max_hp: float = 12.0
var current_hp: float = 12.0
var is_dead: bool = false
var counts_as_enemy: bool = false
var _slowing: Node = null
var _web: Sprite2D = null
var _anim_time: float = 0.0

func _ready() -> void:
	add_to_group("enemies")
	collision_layer = GameConfig.LAYER_ENEMY
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(36, 36)
	shape.shape = rect
	add_child(shape)
	_build_visual()

func _build_visual() -> void:
	if ResourceLoader.exists(WEB_TEXTURE):
		var tex := load(WEB_TEXTURE) as Texture2D
		if tex != null:
			var sprite := Sprite2D.new()
			sprite.name = "WebSprite"
			sprite.texture = tex
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			var s := WEB_DIAMETER / maxf(float(tex.get_width()), 1.0)
			sprite.scale = Vector2(s, s)
			sprite.modulate = Color(0.92, 1.0, 0.92, 0.9)
			add_child(sprite)
			_web = sprite
			return
	# 缺贴图时退回色块，但保留呼吸，不能是一块钉死的几何。
	var patch := Polygon2D.new()
	patch.polygon = PackedVector2Array([Vector2(-18, -12), Vector2(18, -8), Vector2(14, 16), Vector2(-16, 14)])
	patch.color = Color(0.35, 0.75, 0.4, 0.45)
	add_child(patch)

func _process(delta: float) -> void:
	_anim_time += delta
	if _web != null and is_instance_valid(_web):
		# 呼吸 + 轻微明暗：网在"浮动"，玩家一眼能看出这是危险区。
		var breathe := 1.0 + sin(_anim_time * 2.0) * 0.05
		var base_scale := WEB_DIAMETER / maxf(float(_web.texture.get_width()), 1.0)
		_web.scale = Vector2(base_scale * breathe, base_scale * breathe)
		_web.modulate.a = 0.78 + sin(_anim_time * 2.6) * 0.12
	var player := get_tree().get_first_node_in_group("player")
	var touching: bool = player != null and is_instance_valid(player) and global_position.distance_to(player.global_position) <= 34.0
	if touching and _slowing == null and player.has_method("add_hazard_slow"):
		player.add_hazard_slow()
		_slowing = player
	elif not touching and _slowing != null:
		if is_instance_valid(_slowing) and _slowing.has_method("remove_hazard_slow"):
			_slowing.remove_hazard_slow()
		_slowing = null

func take_damage(amount: float) -> void:
	if is_dead:
		return
	current_hp -= maxf(amount, 0.0)
	if current_hp <= 0.0:
		is_dead = true
		if _slowing != null and is_instance_valid(_slowing) and _slowing.has_method("remove_hazard_slow"):
			_slowing.remove_hazard_slow()
		queue_free()

func _exit_tree() -> void:
	if _slowing != null and is_instance_valid(_slowing) and _slowing.has_method("remove_hazard_slow"):
		_slowing.remove_hazard_slow()
		_slowing = null
