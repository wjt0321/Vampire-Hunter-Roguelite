extends StaticBody2D
## 织血母皇的卵巢。清掉之后母皇不再产卵，改成近身。
## 没有卵的贴图，用一颗暗红色圆块代替。

var max_hp: float = 18.0
var current_hp: float = 18.0
var is_dead: bool = false
var counts_as_enemy: bool = false
var owner_boss: Node = null

func _ready() -> void:
	add_to_group("enemies")
	collision_layer = GameConfig.LAYER_ENEMY
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 12.0
	var collision := CollisionShape2D.new()
	collision.shape = circle
	add_child(collision)
	var blob := Polygon2D.new()
	blob.polygon = PackedVector2Array([
		Vector2(0, -12), Vector2(10, -4), Vector2(8, 10), Vector2(-8, 10), Vector2(-10, -4),
	])
	blob.color = Color(0.72, 0.12, 0.28, 0.9)
	add_child(blob)

func take_damage(amount: float) -> void:
	if is_dead:
		return
	current_hp -= maxf(amount, 0.0)
	if current_hp <= 0.0:
		is_dead = true
		if owner_boss != null and is_instance_valid(owner_boss) and owner_boss.has_method("egg_destroyed"):
			owner_boss.egg_destroyed(self)
		queue_free()
