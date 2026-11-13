extends StaticBody2D
## 墓穴结界核心。打掉之后守望者不能再把亡者拉起来。

var max_hp: float = 48.0
var current_hp: float = 48.0
var is_dead: bool = false
var counts_as_enemy: bool = false
var owner_boss: Node = null

func _ready() -> void:
	add_to_group("enemies")
	collision_layer = GameConfig.LAYER_ENEMY
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 16.0
	shape.shape = circle
	add_child(shape)
	var mark := Polygon2D.new()
	mark.polygon = PackedVector2Array([Vector2(0, -16), Vector2(14, 12), Vector2(-14, 12)])
	mark.color = Color(0.55, 0.75, 0.85, 0.9)
	add_child(mark)

func take_damage(amount: float) -> void:
	if is_dead:
		return
	current_hp -= maxf(amount, 0.0)
	if current_hp <= 0.0:
		is_dead = true
		if owner_boss != null and is_instance_valid(owner_boss) and owner_boss.has_method("ward_broken"):
			owner_boss.ward_broken()
		queue_free()
