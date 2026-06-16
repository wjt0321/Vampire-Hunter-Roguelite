extends Area2D
## 子弹脚本
## 沿指定方向飞行，碰到敌人造成伤害后消失

# 缓存的玩家引用
var _cached_player: Node = null

# === 属性 ===
@export var speed: float = 500.0
@export var base_damage: float = 10.0
@export var max_range: float = 800.0
var direction: Vector2 = Vector2.RIGHT
var damage_multiplier: float = 1.0
var distance_traveled: float = 0.0

# 追踪相关
var homing: bool = false
var homing_strength: float = 8.0
var _homing_target: Node2D = null

func _ready() -> void:
	# 缓存玩家引用
	_cached_player = get_tree().get_first_node_in_group("player")
	# 设置子弹旋转方向
	rotation = direction.angle()
	# 加载子弹纹理
	var spr := $Sprite2D as Sprite2D
	if spr and spr.texture == null:
		var tex := TextureManager.instance.get_weapon_icon("bullet")
		if tex:
			spr.texture = tex
		else:
			var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
			img.fill(Color.WHITE)
			spr.texture = ImageTexture.create_from_image(img)

func _physics_process(delta: float) -> void:
	if homing:
		_update_homing(delta)
	var move_distance := speed * delta
	position += direction * move_distance
	distance_traveled += move_distance
	# 子弹拖尾
	var vfx := get_node_or_null("/root/VFXManager")
	if vfx and Engine.get_physics_frames() % 3 == 0:
		vfx.spawn_bullet_trail(global_position)
	# 超出射程后销毁
	if distance_traveled >= max_range:
		queue_free()

func _update_homing(delta: float) -> void:
	if _homing_target == null or not is_instance_valid(_homing_target):
		_homing_target = _find_nearest_enemy()
	if _homing_target and is_instance_valid(_homing_target):
		var target_dir := (_homing_target.global_position - global_position).normalized()
		direction = direction.move_toward(target_dir, homing_strength * delta).normalized()
		rotation = direction.angle()
	else:
		_homing_target = null

func _find_nearest_enemy() -> Node2D:
	var enemies := get_tree().get_nodes_in_group("enemies")
	var nearest: Node2D = null
	var nearest_dist: float = INF
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var dist := global_position.distance_squared_to(enemy.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = enemy
	return nearest

func get_damage() -> float:
	return base_damage * damage_multiplier

func _on_body_entered(body: Node2D) -> void:
	# 碰到墙壁
	if body.is_in_group("walls"):
		queue_free()
		return
	# 碰到敌人
	if body.has_method("take_damage"):
		var dmg := get_damage()
		# 暴击检查
		if _cached_player and _cached_player.has_method("roll_crit"):
			if _cached_player.roll_crit():
				dmg *= _cached_player.crit_damage
				# 暴击视觉
				var vfx := get_node_or_null("/root/VFXManager")
				if vfx:
					vfx.spawn_hit_particles(global_position, Color(1.0, 0.9, 0.3), 4)
		var knockback_dir := direction
		if body.has_method("take_damage_with_knockback"):
			body.take_damage_with_knockback(dmg, knockback_dir, 120.0, 0.08)
		else:
			body.take_damage(dmg)
		# 冰冻之心效果：检查是否冻结敌人
		_check_freeze(body)
	queue_free()

func _check_freeze(enemy: Node2D) -> void:
	## 检查是否触发冰冻效果
	# 检查敌人是否有效且存活
	if not is_instance_valid(enemy):
		return
	if "is_dead" in enemy and enemy.is_dead:
		return

	# 使用缓存的玩家引用，必要时重新获取
	if _cached_player == null or not is_instance_valid(_cached_player):
		_cached_player = get_tree().get_first_node_in_group("player")
	if _cached_player and _cached_player.has_method("get_owned_passive_items"):
		# 检查是否有冰冻之心
		for item in _cached_player.passive_items:
			if item.item_id == "frozen_heart":
				if randf() < _cached_player.freeze_chance:
					# 冻结敌人
					if enemy.has_method("freeze"):
						enemy.freeze(2.0)  # 冻结2秒
						print("❄️ 敌人被冻结!")
					# 冰冻视觉效果
					var vfx := get_node_or_null("/root/VFXManager")
					if vfx:
						vfx.spawn_freeze_effect(enemy.global_position)
				break

func _on_area_entered(area: Area2D) -> void:
	# 碰到墙壁等
	if area.is_in_group("walls"):
		queue_free()
