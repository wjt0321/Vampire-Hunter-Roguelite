extends StaticBody2D
## 月蚀祭坛。打掉它会推进月相。

var current_hp: float = 40.0
var is_dead: bool = false
var counts_as_enemy: bool = false
var owner_boss: Node = null

func _ready() -> void:
	add_to_group("enemies")
	collision_layer = GameConfig.LAYER_ENEMY
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(28, 28)
	shape.shape = rect
	add_child(shape)
	var mark := Polygon2D.new()
	mark.polygon = PackedVector2Array([Vector2(-14, 14), Vector2(14, 14), Vector2(0, -14)])
	mark.color = Color(0.7, 0.55, 1.0, 0.9)
	add_child(mark)

func take_damage(amount: float) -> void:
	if is_dead:
		return
	current_hp -= maxf(amount, 0.0)
	if current_hp <= 0.0:
		is_dead = true
		if owner_boss != null and is_instance_valid(owner_boss) and owner_boss.has_method("altar_destroyed"):
			owner_boss.altar_destroyed()
		queue_free()
