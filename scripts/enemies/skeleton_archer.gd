extends "res://scripts/enemies/enemy_base.gd"
class_name SkeletonArcher
## 骷髅射手 — 远程型，保持距离，发射投射物

const PREFERRED_DISTANCE: float = 250.0  # 理想距离
const RETREAT_DISTANCE: float = 150.0    # 小于此距离后退
const ATTACK_RANGE: float = 400.0        # 攻击范围
const ATTACK_COOLDOWN: float = 2.0       # 攻击冷却

var attack_timer: float = 0.0
var projectile_scene: PackedScene = preload("res://scenes/enemies/enemy_projectile.tscn")

func _ready() -> void:
	max_hp = 27.5  # 增加10% (原25.0)
	move_speed = 70.0
	contact_damage = 5.0
	xp_value = 8
	super._ready()

func _load_sprite_texture() -> void:
	if sprite:
		var texture := TextureManager.instance.get_enemy_texture("skeleton", "idle")
		if texture:
			sprite.texture = texture
			sprite.modulate = Color.WHITE
			_adjust_sprite_scale()
		else:
			_ensure_default_texture()
			_adjust_sprite_scale()

func _physics_process(delta: float) -> void:
	if is_dead or player == null or not is_instance_valid(player):
		return
	
	var distance_to_player := global_position.distance_to(player.global_position)
	var direction_to_player := (player.global_position - global_position).normalized()
	
	# 更新攻击计时器
	if attack_timer > 0:
		attack_timer -= delta
	
	# 行为逻辑
	if distance_to_player < RETREAT_DISTANCE:
		# 太近，后退
		velocity = -direction_to_player * move_speed * 1.5
		move_and_slide()
	elif distance_to_player > PREFERRED_DISTANCE + 50:
		# 太远，靠近
		velocity = direction_to_player * move_speed
		move_and_slide()
	else:
		# 理想距离，停止移动并尝试攻击
		velocity = Vector2.ZERO
		if attack_timer <= 0 and distance_to_player <= ATTACK_RANGE:
			_attack()
	
	# 翻转朝向
	if direction_to_player.x < 0:
		sprite.flip_h = true
	else:
		sprite.flip_h = false

func _attack() -> void:
	attack_timer = ATTACK_COOLDOWN

	if projectile_scene == null or player == null:
		return

	# 20% 概率散射三发
	var is_triple_shot: bool = randf() < 0.2
	var shot_count: int = 3 if is_triple_shot else 1
	var base_direction := _get_predicted_aim_direction()

	for i in range(shot_count):
		var projectile := projectile_scene.instantiate() as Area2D
		projectile.global_position = global_position

		var direction := base_direction
		if is_triple_shot:
			# 三发呈扇形：-15° / 0° / +15°
			var spread: float = deg_to_rad(15.0) * (i - 1)
			direction = base_direction.rotated(spread)

		projectile.direction = direction
		projectile.damage = contact_damage * 2

		get_tree().current_scene.add_child(projectile)

	# 播放射击动画（闪烁）
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color(1.5, 1.5, 1.5, 1.0), 0.1)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)

func _get_predicted_aim_direction() -> Vector2:
	## 预测玩家位置，提前量瞄准
	var player_vel: Vector2 = Vector2.ZERO
	if player.has_method("get_velocity"):
		player_vel = player.get_velocity()
	elif "velocity" in player:
		player_vel = player.velocity

	var to_player := player.global_position - global_position
	var projectile_speed: float = 300.0  # 与 enemy_projectile.gd 默认速度一致
	var time_to_hit: float = to_player.length() / maxf(projectile_speed, 1.0)
	var predicted_pos: Vector2 = player.global_position + player_vel * time_to_hit
	return (predicted_pos - global_position).normalized()

func _get_enemy_type() -> String:
	return "skeleton"
