extends StaticBody2D
## 棺卫倒下后留下的棺材。倒计时结束前打掉，它就不再爬起来。

var max_hp: float = 16.0
var current_hp: float = 16.0
var is_dead: bool = false
var counts_as_enemy: bool = false
var owner_guard: Node = null
var revive_delay: float = 4.0
var _elapsed: float = 0.0

func _ready() -> void:
	add_to_group("enemies")
	collision_layer = GameConfig.LAYER_ENEMY
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(28, 18)
	shape.shape = rect
	add_child(shape)
	var lid := Polygon2D.new()
	lid.polygon = PackedVector2Array([Vector2(-16, -8), Vector2(16, -8), Vector2(16, 8), Vector2(-16, 8)])
	lid.color = Color(0.42, 0.28, 0.2, 0.9)
	add_child(lid)

func _process(delta: float) -> void:
	if is_dead:
		return
	_elapsed += delta
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
