extends Area2D
## 经验宝石脚本
## 敌人死亡后掉落，被玩家吸附拾取


@export var xp_value: int = 2
@export var attraction_speed: float = 300.0
@export var attraction_range: float = 80.0

var is_attracted: bool = false
var player: Node2D = null

func _ready() -> void:
	_setup_gem()

func _setup_gem() -> void:
	add_to_group("xp_gems")
	# 自动创建纹理
	var spr := $Sprite2D as Sprite2D
	if spr and spr.texture == null:
		var img := Image.create(6, 6, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		spr.texture = ImageTexture.create_from_image(img)
	# 掉落弹跳效果
	var tween := create_tween()
	var random_offset := Vector2(randf_range(-20, 20), randf_range(-20, 20))
	tween.tween_property(self, "position", position + random_offset, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BOUNCE)

func reset_for_pool() -> void:
	## 归还对象池前/后重置状态
	is_attracted = false
	player = null
	scale = Vector2.ONE
	modulate = Color.WHITE

func _physics_process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		# 查找玩家
		var players := get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player = players[0]
		return
	
	var distance := global_position.distance_to(player.global_position)
	
	# 进入吸附范围后自动靠近玩家
	if distance < attraction_range:
		is_attracted = true
	
	if is_attracted:
		var direction := (player.global_position - global_position).normalized()
		position += direction * attraction_speed * delta
		# 足够近时拾取
		if distance < 15.0:
			_collect()

func _collect() -> void:
	# 通知玩家获得经验
	if player != null and player.has_method("gain_xp"):
		player.gain_xp(xp_value)
	# 拾取 VFX
	var vfx := get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.spawn_xp_particles(global_position)
	# 播放拾取音效
	var audio_lib := AudioLib
	AudioManager.play_sfx(audio_lib.get_sound("pickup_xp"))
	# 拾取特效
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, 0.1)
	tween.tween_callback(func(): ObjectPool.release(self))
