extends StaticBody2D
## 棺卫倒下后留下的棺材。倒计时结束前打掉，它就不再爬起来。

var max_hp: float = 16.0
var current_hp: float = 16.0
var is_dead: bool = false
var counts_as_enemy: bool = false
var owner_guard: Node = null
var revive_delay: float = 4.0
var _elapsed: float = 0.0

const COFFIN_TEXTURE := "res://assets/tiles/props/coffin.png"
const COFFIN_HEIGHT: float = 52.0
var _coffin: Sprite2D = null

func _ready() -> void:
	add_to_group("enemies")
	collision_layer = GameConfig.LAYER_ENEMY
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(28, 18)
	shape.shape = rect
	add_child(shape)
	_build_visual()

func _build_visual() -> void:
	## 正式棺材贴图。以前是一个深棕色矩形（"贴图痕迹"），而且一动不动。
	if ResourceLoader.exists(COFFIN_TEXTURE):
		var tex := load(COFFIN_TEXTURE) as Texture2D
		if tex != null:
			var sprite := Sprite2D.new()
			sprite.name = "CoffinSprite"
			sprite.texture = tex
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			var s := COFFIN_HEIGHT / maxf(float(tex.get_height()), 1.0)
			sprite.scale = Vector2(s, s)
			add_child(sprite)
			_coffin = sprite
			return
	var lid := Polygon2D.new()
	lid.polygon = PackedVector2Array([Vector2(-16, -8), Vector2(16, -8), Vector2(16, 8), Vector2(-16, 8)])
	lid.color = Color(0.42, 0.28, 0.2, 0.9)
	add_child(lid)

func _process(delta: float) -> void:
	if is_dead:
		return
	_elapsed += delta
	# 复活倒计时的视觉预告：越接近爬起来，棺材抖得越厉害。
	# 以前棺材是一块静止的深色矩形，玩家根本不知道它快开了。
	if _coffin != null and is_instance_valid(_coffin):
		var left := maxf(revive_delay - _elapsed, 0.0)
		var urgency := 1.0 - clampf(left / maxf(revive_delay, 0.001), 0.0, 1.0)
		var shake := sin(_elapsed * (6.0 + urgency * 26.0)) * (0.6 + urgency * 2.2)
		_coffin.position.x = shake
		_coffin.modulate = Color(1.0, 1.0 - urgency * 0.25, 1.0 - urgency * 0.3, 1.0)
	if _elapsed < revive_delay:
		return
	is_dead = true
	if owner_guard != null and is_instance_valid(owner_guard) and owner_guard.has_method("revive_from_coffin"):
		owner_guard.revive_from_coffin()
	queue_free()

func take_damage(amount: float) -> void:
	if is_dead:
		return
	current_hp -= maxf(amount, 0.0)
	if current_hp <= 0.0:
		is_dead = true
		if owner_guard != null and is_instance_valid(owner_guard) and owner_guard.has_method("confirm_coffin_destroyed"):
			owner_guard.confirm_coffin_destroyed()
		queue_free()
