extends Node2D
## 迷雾房视野（17.15）
##
## 用世界坐标画一圈透光，而不是屏幕着色器。
## 着色器的 FRAGCOORD 原点在不同 Godot 版本里上下相反，洞会对不准玩家；
## 世界坐标跟摄像机走，玩家走到哪，光就在哪。

var player: Node2D = null
var radius: float = 220.0
var softness: float = 70.0

func setup(player_node: Node2D) -> void:
	player = player_node
	radius = GameConfig.FOG_VISION_RADIUS
	softness = GameConfig.FOG_VISION_SOFTNESS
	z_index = 30
	z_as_relative = false

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if player == null or not is_instance_valid(player):
		return
	var center := to_local(player.global_position)
	var soft_end := radius + softness
	_draw_ring(center, radius, soft_end, Color(0.015, 0.012, 0.02, 0.55))
	_draw_ring(center, soft_end, 3200.0, Color(0.012, 0.01, 0.018, 0.93))

func _draw_ring(center: Vector2, inner: float, outer: float, color: Color) -> void:
	var steps := 48
	for i in steps:
		var a0 := TAU * float(i) / float(steps)
		var a1 := TAU * float(i + 1) / float(steps)
		var poly := PackedVector2Array([
			center + Vector2(cos(a0), sin(a0)) * inner,
			center + Vector2(cos(a0), sin(a0)) * outer,
			center + Vector2(cos(a1), sin(a1)) * outer,
			center + Vector2(cos(a1), sin(a1)) * inner,
		])
		draw_colored_polygon(poly, color)
