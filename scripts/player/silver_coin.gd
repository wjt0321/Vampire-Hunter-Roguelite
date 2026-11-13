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
var _drop_tween: Tween = null

func _ready() -> void:
	add_to_group("silver_coins")
	var spr := Sprite2D.new()
	spr.name = "CoinSprite"
	add_child(spr)
	# 真贴图：以前是一枚程序化发光圆点（style_sprite），地上根本不像"钱"
	var tex: Texture2D = TextureManager.instance.get_item_texture("silver_coin")
	if tex != null:
		spr.texture = tex
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.material = null
		var ts := tex.get_size()
		if ts.x > 0.0:
			var s := 16.0 / ts.x
			spr.scale = Vector2(s, s)
		spr.z_index = 0
	else:
		ProjectileVisuals.style_sprite(spr, Color(1.0, 0.84, 0.38), 13.0, 13.0, true)
	# 出场：弹一下，让玩家注意到"掉东西了"
	var dir := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	var pop_target := position + dir * randf_range(14.0, 30.0)
	_drop_tween = create_tween()
	_drop_tween.tween_property(self, "position", pop_target, 0.22).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

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
	if "pickup_range_bonus" in _player:
		range_now += float(_player.pickup_range_bonus) * 0.5

	if dist < 16.0:
		_collect()
		return
	if dist < range_now:
		_attracted = true
	if _attracted:
		global_position = global_position.move_toward(_player.global_position, attraction_speed * delta)

func magnetize() -> void:
	## 和经验宝石同一条拉力：停掉出场弹跳，再高速飞向玩家。
	if value <= 0 or is_queued_for_deletion():
		return
	if _drop_tween != null and _drop_tween.is_valid():
		_drop_tween.kill()
	_drop_tween = null
	_attracted = true
	attraction_speed = maxf(attraction_speed, GameConfig.MAGNET_PULL_SPEED)

func _collect() -> void:
	if is_queued_for_deletion():
		return
	if _player != null and is_instance_valid(_player) and _player.has_method("add_silver"):
		_player.add_silver(value)
		AudioManager.play_sfx(AudioLib.get_sound("pickup_coin"))
	var vfx := get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.spawn_hit_particles(global_position, Color(1.0, 0.86, 0.42), 2)
	queue_free()
