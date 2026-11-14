extends StaticBody2D
## 月蚀祭坛。打掉它会推进月相。

var current_hp: float = 40.0
var is_dead: bool = false
var counts_as_enemy: bool = false
var owner_boss: Node = null

const ALTAR_TEXTURE := "res://assets/tiles/props/altar.png"
const ALTAR_WIDTH: float = 52.0
var _altar: Sprite2D = null
var _anim_time: float = 0.0

func _ready() -> void:
	add_to_group("enemies")
	collision_layer = GameConfig.LAYER_ENEMY
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(28, 28)
	shape.shape = rect
	add_child(shape)
	_build_visual()

func _build_visual() -> void:
	## 正式祭坛贴图 + 月蚀紫染色。以前是一个紫色三角形（"贴图痕迹"）。
	if ResourceLoader.exists(ALTAR_TEXTURE):
		var tex := load(ALTAR_TEXTURE) as Texture2D
		if tex != null:
			var sprite := Sprite2D.new()
			sprite.name = "AltarSprite"
			sprite.texture = tex
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			var s := ALTAR_WIDTH / maxf(float(tex.get_width()), 1.0)
			sprite.scale = Vector2(s, s)
			sprite.modulate = Color(0.82, 0.72, 1.0, 0.95)
			add_child(sprite)
			_altar = sprite
			return
	var mark := Polygon2D.new()
	mark.polygon = PackedVector2Array([Vector2(-14, 14), Vector2(14, 14), Vector2(0, -14)])
	mark.color = Color(0.7, 0.55, 1.0, 0.9)
	add_child(mark)

func _process(delta: float) -> void:
	# 月蚀祭坛在缓慢地"呼吸"，还会越走越亮——它越亮说明月相越近。
	_anim_time += delta
	if _altar != null and is_instance_valid(_altar):
		var pulse := 0.55 + 0.45 * (0.5 + 0.5 * sin(_anim_time * 2.2))
		_altar.modulate = Color(0.82 + pulse * 0.18, 0.72 + pulse * 0.2, 1.0, 0.85 + pulse * 0.15)

func take_damage(amount: float) -> void:
	if is_dead:
		return
	current_hp -= maxf(amount, 0.0)
	if current_hp <= 0.0:
		is_dead = true
		if owner_boss != null and is_instance_valid(owner_boss) and owner_boss.has_method("altar_destroyed"):
			owner_boss.altar_destroyed()
		queue_free()
