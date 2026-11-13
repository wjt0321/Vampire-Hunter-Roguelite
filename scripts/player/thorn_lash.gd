extends Node2D
## 荆棘长鞭。身前扇形抽一下，带击退。进化后可以再朝身后抽。
## 鞭影是一条线，正式鞭子贴图以后再换。

var origin: Vector2 = Vector2.ZERO
var direction: Vector2 = Vector2.RIGHT
var reach: float = 130.0
var cone: float = 0.9
var base_damage: float = 3.4
var damage_multiplier: float = 1.0
var knockback: float = 90.0
var also_behind: bool = false
var _swung: bool = false

func _ready() -> void:
	add_to_group("player_whip")
	global_position = origin
	_draw_lash(direction, Color(0.45, 0.75, 0.32, 0.9))
	if also_behind:
		_draw_lash(-direction, Color(0.3, 0.55, 0.22, 0.75))
	_strike(direction)
	if also_behind:
		_strike(-direction)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.12)
	tween.tween_callback(queue_free)

func _draw_lash(dir: Vector2, color: Color) -> void:
	var line := Line2D.new()
	line.width = 4.0
	line.default_color = color
	line.add_point(Vector2.ZERO)
	line.add_point(dir.normalized() * reach)
	add_child(line)

func _strike(dir: Vector2) -> void:
	var forward := dir.normalized()
	if forward == Vector2.ZERO:
		return
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.get("is_dead") == true:
			continue
		if not (enemy is Node2D):
			continue
		var offset: Vector2 = (enemy as Node2D).global_position - global_position
		var dist := offset.length()
		if dist > reach or dist < 1.0:
			continue
		if absf(forward.angle_to(offset)) > cone * 0.5:
			continue
		var amount := base_damage * damage_multiplier
		if enemy.has_method("take_damage_with_knockback"):
			enemy.take_damage_with_knockback(amount, forward, knockback, 0.06)
		elif enemy.has_method("take_damage"):
			enemy.take_damage(amount)
