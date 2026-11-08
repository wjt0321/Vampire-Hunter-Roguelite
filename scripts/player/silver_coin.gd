extends Node2D
## 银币掉落物
##
## 不用 Area2D / 碰撞体：一次战斗可能掉几十枚，纯 Node2D + 距离判定最省。
## 行为：先原地小弹跳，进入拾取范围后吸附，靠近即收；12 秒后自动收取（避免残局跑图捡钱）。

@export var value: int = 1
@export var attraction_speed: float = 340.0
@export var base_attraction_range: float = 110.0
@export var auto_collect_delay: float = 12.0

var _player: Node2D = null
var _age: float = 0.0
var _attracted: bool = false

func _ready() -> void:
	add_to_group("silver_coins")
	var spr := Sprite2D.new()
	spr.name = "CoinSprite"
	add_child(spr)
	ProjectileVisuals.style_sprite(spr, Color(1.0, 0.84, 0.38), 13.0, 13.0, true)
	# 出场：弹一下，让玩家注意到"掉东西了"
	var dir := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	var pop_target := position + dir * randf_range(14.0, 30.0)
	var tw := create_tween()
	tw.tween_property(self, "position", pop_target, 0.22).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

func _process(delta: float) -> void:
	_age += delta
	if _age >= auto_collect_delay:
		_collect()
		return

	if _player == null or not is_instance_valid(_player):
		var players := get_tree().get_nodes_in_group("player")
		if players.is_empty():
			return
		_player = players[0]
		return

	var dist := global_position.distance_to(_player.global_position)
	var range_now := base_attraction_range
	if "pickup_range" in _player:
		range_now += float(_player.pickup_range) * 0.5

	if dist < 16.0:
		_collect()
		return
	if dist < range_now:
		_attracted = true
	if _attracted:
		global_position = global_position.move_toward(_player.global_position, attraction_speed * delta)

func _collect() -> void:
	if _player != null and is_instance_valid(_player) and _player.has_method("add_silver"):
		_player.add_silver(value)
	var vfx := get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.spawn_hit_particles(global_position, Color(1.0, 0.86, 0.42), 2)
	queue_free()
