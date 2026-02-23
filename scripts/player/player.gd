extends CharacterBody2D
## 玩家角色脚本
## 处理移动、生命值、经验升级等核心逻辑
## 射击由 WeaponManager 独立处理

const AudioLibraryScript = preload("res://scripts/managers/audio_library.gd")

# === 移动属性 ===
@export var move_speed: float = 200.0

# === 生命属性 ===
@export var max_hp: float = 100.0
var current_hp: float = max_hp
var is_invincible: bool = false
@export var invincible_duration: float = 0.5

# === 经验与升级 ===
var current_xp: int = 0
var current_level: int = 1
var xp_to_next_level: int = 8  # 再次降低20% (原10)

# === 战斗属性（可被升级修改） ===
var damage_multiplier: float = 1.0
var speed_multiplier: float = 1.0
var shoot_speed_multiplier: float = 1.0
var pickup_range_bonus: float = 0.0
var armor: float = 0.0

func get_total_damage_multiplier() -> float:
	## 获取总伤害倍率（包含狂战士之血效果）
	var total := damage_multiplier
	# 狂战士之血：生命值低于30%时增加伤害
	if berserker_bonus > 0 and current_hp / max_hp < 0.3:
		total += berserker_bonus
	return total

# === 被动道具 ===
var passive_items: Array = []
var magnet_multiplier: float = 1.0
var has_shield: bool = false
var shield_cooldown: float = 30.0
var shield_timer: float = 0.0
var regen_rate: float = 0.0
var regen_timer: float = 0.0
# 新被动道具
var xp_bonus_multiplier: float = 0.0  # 贪婪戒指
var berserker_bonus: float = 0.0  # 狂战士之血
var freeze_chance: float = 0.0  # 冰冻之心
var lightning_retaliate_damage: float = 0.0  # 闪电护符
var dodge_chance: float = 0.0  # 影子披风

# === 信号 ===
signal hp_changed(current: float, maximum: float)
signal xp_changed(current_xp: int, xp_needed: int, level: int)
signal level_up(new_level: int)
signal player_died

# === 节点引用 ===
@onready var sprite: Sprite2D = $Sprite2D
@onready var invincible_timer: Timer = $InvincibleTimer
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	add_to_group("player")
	current_hp = max_hp
	# 自动创建纹理（如果 sprite 没有 texture）
	if sprite and sprite.texture == null:
		var img := Image.create(16, 24, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		sprite.texture = ImageTexture.create_from_image(img)
	invincible_timer.wait_time = invincible_duration
	invincible_timer.one_shot = true
	invincible_timer.timeout.connect(_on_invincible_timer_timeout)
	hp_changed.emit(current_hp, max_hp)
	xp_changed.emit(current_xp, xp_to_next_level, current_level)

func _physics_process(delta: float) -> void:
	_handle_movement()
	_handle_rotation()
	_process_passive_items(delta)

func _handle_movement() -> void:
	var input_dir := Vector2.ZERO
	input_dir.x = Input.get_axis("move_left", "move_right")
	input_dir.y = Input.get_axis("move_up", "move_down")
	input_dir = input_dir.normalized()
	velocity = input_dir * move_speed * speed_multiplier
	move_and_slide()

func _handle_rotation() -> void:
	var mouse_pos := get_global_mouse_position()
	var direction := mouse_pos - global_position
	if direction.x < 0:
		sprite.flip_h = true
	else:
		sprite.flip_h = false

# === 经验值相关 ===
func gain_xp(amount: int) -> void:
	# 应用贪婪戒指加成
	var final_amount := int(amount * (1.0 + xp_bonus_multiplier))
	current_xp += final_amount
	while current_xp >= xp_to_next_level:
		current_xp -= xp_to_next_level
		_level_up()
	xp_changed.emit(current_xp, xp_to_next_level, current_level)

func _level_up() -> void:
	current_level += 1
	xp_to_next_level = 8 + (current_level - 1) * 4  # 再次降低20% (原10+5)
	level_up.emit(current_level)
	# 升级光效
	var vfx := get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.spawn_levelup_particles(global_position)
	# 播放升级音效
	var audio_lib := AudioLibraryScript.new()
	AudioManager.play_sfx(audio_lib.get_sound("level_up"))

# === 升级效果应用 ===
func apply_upgrade(upgrade_type: String) -> void:
	match upgrade_type:
		"damage":
			damage_multiplier += 0.2
		"speed":
			speed_multiplier += 0.15
		"shoot_speed":
			shoot_speed_multiplier += 0.2
		"max_hp":
			max_hp += 20.0
			current_hp += 20.0
			hp_changed.emit(current_hp, max_hp)
		"armor":
			armor += 5.0
		"pickup_range":
			pickup_range_bonus += 30.0

# === 生命值相关 ===
func take_damage(amount: float) -> void:
	if is_invincible:
		return
	
	# 护盾抵挡伤害
	if has_shield:
		_break_shield()
		_start_invincibility()
		_flash_damage()
		return
	
	# 影子披风闪避检查
	if dodge_chance > 0 and randf() < dodge_chance:
		print("🌑 闪避成功!")
		# 闪避视觉效果
		var vfx := get_node_or_null("/root/VFXManager")
		if vfx:
			vfx.spawn_dodge_effect(global_position)
		return
	
	var actual_damage := maxf(amount - armor, 1.0)
	current_hp = clampf(current_hp - actual_damage, 0.0, max_hp)
	hp_changed.emit(current_hp, max_hp)
	_start_invincibility()
	_flash_damage()
	
	# 闪电护符反击
	if lightning_retaliate_damage > 0:
		_lightning_retaliate()
	
	# 受击屏幕震动
	var vfx := get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.screen_shake(3.0, 0.1)
	if current_hp <= 0:
		_die()

func _lightning_retaliate() -> void:
	## 闪电护符反击
	var enemies := get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		return
	
	# 找到最近的敌人
	var nearest_enemy = null
	var nearest_dist: float = INF
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var dist := global_position.distance_squared_to(enemy.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest_enemy = enemy
	
	if nearest_enemy and nearest_dist < 300 * 300:  # 300范围内
		# 创建闪电效果
		var lightning := preload("res://scenes/player/lightning_chain.tscn").instantiate()
		lightning.global_position = global_position
		lightning.base_damage = lightning_retaliate_damage
		lightning.damage_multiplier = 1.0
		lightning.max_jumps = 1
		lightning._current_damage = lightning_retaliate_damage
		get_tree().current_scene.add_child(lightning)
		
		# 播放音效
		var audio_lib := AudioLibraryScript.new()
		AudioManager.play_sfx(audio_lib.get_sound("shoot_magic"))

func heal(amount: float) -> void:
	current_hp = clampf(current_hp + amount, 0.0, max_hp)
	hp_changed.emit(current_hp, max_hp)

func _start_invincibility() -> void:
	is_invincible = true
	invincible_timer.start()

func _on_invincible_timer_timeout() -> void:
	is_invincible = false
	sprite.modulate = Color.WHITE

func _flash_damage() -> void:
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color(1.0, 0.3, 0.3, 1.0), 0.05)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.05)
	tween.tween_property(sprite, "modulate", Color(1.0, 0.3, 0.3, 0.7), 0.05)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.05)

func _die() -> void:
	player_died.emit()
	set_physics_process(false)
	collision_shape.set_deferred("disabled", true)
	var tween := create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)

# === 被动道具处理 ===
func _process_passive_items(delta: float) -> void:
	# 护盾计时
	if shield_cooldown < 30.0:  # 有护盾道具才计时
		shield_timer += delta
		if shield_timer >= shield_cooldown and not has_shield:
			_grant_shield()
	
	# 回血计时
	if regen_rate > 0:
		regen_timer += delta
		if regen_timer >= 5.0:  # 每5秒回血
			regen_timer = 0.0
			_heal_regen()

func _grant_shield() -> void:
	has_shield = true
	shield_timer = 0.0
	print("🛡️ 护盾生成!")
	# 护盾视觉效果
	var tween := create_tween().set_loops()
	tween.tween_property(sprite, "modulate", Color(0.5, 0.8, 1.0, 1.0), 0.3)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.3)

func _break_shield() -> void:
	has_shield = false
	shield_timer = 0.0
	print("💥 护盾破碎!")
	# 播放护盾破碎音效
	var audio_lib := AudioLibraryScript.new()
	AudioManager.play_sfx(audio_lib.get_sound("shield_break"))

func _heal_regen() -> void:
	var heal_amount := max_hp * regen_rate
	heal(heal_amount)
	print("💚 恢复 %.1f 生命" % heal_amount)

func add_passive_item(item) -> void:
	# 检查是否已有相同道具
	for existing in passive_items:
		if existing.item_id == item.item_id:
			existing.level_up()
			_apply_passive_effect(existing)
			print("被动道具升级: %s Lv.%d" % [existing.item_name, existing.current_level])
			return
	
	passive_items.append(item)
	_apply_passive_effect(item)
	print("获得被动道具: %s" % item.item_name)

func _apply_passive_effect(item) -> void:
	match item.effect_type:
		0:  # MAGNET
			magnet_multiplier = item.get_scaled_value()
			pickup_range_bonus = 50.0 * magnet_multiplier
		1:  # SHIELD
			shield_cooldown = item.get_scaled_value()
			shield_timer = 0.0
		2:  # REGENERATION
			regen_rate = item.get_scaled_value()
		3:  # GREED
			xp_bonus_multiplier = item.get_scaled_value()
		4:  # BERSERKER
			berserker_bonus = item.get_scaled_value()
		5:  # FROZEN
			freeze_chance = item.get_scaled_value()
		6:  # LIGHTNING_SHIELD
			lightning_retaliate_damage = item.get_scaled_value()
		7:  # SHADOW
			dodge_chance = item.get_scaled_value()

func get_owned_passive_items() -> Array[String]:
	## 获取已拥有的被动道具ID列表
	var items: Array[String] = []
	for item in passive_items:
		items.append(item.item_id)
	return items
