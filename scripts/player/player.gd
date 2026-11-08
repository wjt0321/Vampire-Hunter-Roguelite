extends CharacterBody2D
## 玩家角色脚本
## 处理移动、生命值、经验升级等核心逻辑
## 射击由 WeaponManager 独立处理

const LightningChainScene = preload("res://scenes/player/lightning_chain.tscn")

# 缓存的 AudioLibrary 实例
var _audio_lib: AudioLibrary = null

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
var xp_to_next_level: int = 20

# === 战斗属性（可被升级修改） ===
var damage_multiplier: float = 1.0
var speed_multiplier: float = 1.0
var shoot_speed_multiplier: float = 1.0
var pickup_range_bonus: float = 0.0
var armor: float = 0.0  # 护甲值，通过百分比公式换算减伤

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
var has_shield_item: bool = false
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
var lifesteal_chance: float = 0.0  # 吸血獠牙触发几率
var lifesteal_amount: float = 0.03  # 吸血量（最大生命百分比）
var move_speed_bonus_multiplier: float = 0.0  # 疾风靴移速加成
var crit_chance: float = 0.0  # 幸运四叶草暴击几率
var crit_damage: float = 2.0  # 暴击伤害倍率

# === 角色特性 ===
var character_id: String = "hunter"
var character_passive_timer: float = 0.0
var character_passive_interval: float = 10.0  # 牧师被动每10秒触发

# === 局内货币（银币） ===
## 只在本局有效，结算清零。血晶是局外 Meta 货币，两者不要混。
var silver: int = 0

# === 开火反馈（纯视觉，绝不产生位移） ===
## 早期版本这里存的是"向后速度"，会被加进 velocity 里真正推着人走，
## 用户的反馈就是"发射的时候人物有轻微回退"。
## 现在改成精灵挤压回弹：位置不动，只有 0.08s 的形变，收枪感还在，位移没有了。
var _sprite_base_scale: Vector2 = Vector2.ONE
var _fire_punch_tween: Tween = null
# 护盾光环节点（有护盾时才存在）
var _shield_aura: Sprite2D = null
var _shield_pulse: Tween = null

# === 信号 ===
signal hp_changed(current: float, maximum: float)
signal xp_changed(current_xp: int, xp_needed: int, level: int)
signal level_up(new_level: int)
signal player_died
signal silver_changed(amount: int)

# === 节点引用 ===
@onready var sprite: Sprite2D = $Sprite2D
@onready var invincible_timer: Timer = $InvincibleTimer
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	add_to_group("player")
	current_hp = max_hp
	xp_to_next_level = GameConfig.get_xp_required(current_level)
	# 初始化 AudioLib 缓存
	_audio_lib = AudioLib
	# 加载精灵图纹理
	_load_sprite_texture()
	invincible_timer.wait_time = invincible_duration
	invincible_timer.one_shot = true
	invincible_timer.timeout.connect(_on_invincible_timer_timeout)
	hp_changed.emit(current_hp, max_hp)
	xp_changed.emit(current_xp, xp_to_next_level, current_level)

func _load_sprite_texture() -> void:
	## 加载玩家精灵图
	if sprite:
		var texture := TextureManager.instance.get_player_texture("idle")
		if texture:
			sprite.texture = texture
			sprite.modulate = Color.WHITE  # 重置颜色
			# 根据碰撞体大小缩放精灵
			_adjust_sprite_scale()
		else:
			# 回退到默认白色方块
			var img := Image.create(16, 24, false, Image.FORMAT_RGBA8)
			img.fill(Color.WHITE)
			sprite.texture = ImageTexture.create_from_image(img)
			_adjust_sprite_scale()

func _adjust_sprite_scale() -> void:
	## 根据目标大小调整精灵缩放
	if sprite and sprite.texture:
		var texture_size: Vector2 = sprite.texture.get_size()
		if texture_size.x > 0 and texture_size.y > 0:
			# 目标精灵大小
			var target_size: float = 56.0
			# 计算缩放比例
			var scale_factor: float = target_size / max(texture_size.x, texture_size.y)
			sprite.scale = Vector2(scale_factor, scale_factor)
			# 记下基准缩放：开火挤压是"在基准上乘一个系数再回到基准"，
			# 不能直接写死 1.0，否则会把按碰撞体算出来的缩放覆盖掉（精英怪巨型贴图就是这么来的）
			_sprite_base_scale = sprite.scale

func apply_character_data(char_data: Resource) -> void:
	## 应用角色数据到玩家
	if char_data == null:
		return
	character_id = char_data.char_id
	max_hp = char_data.base_hp
	current_hp = max_hp
	move_speed = char_data.base_speed
	damage_multiplier = char_data.base_damage_mult
	# 猎人直觉：拾取范围 +20%
	if character_id == "hunter":
		pickup_range_bonus += 20.0
	hp_changed.emit(current_hp, max_hp)
	print("🎭 应用角色: %s (HP:%.0f 速度:%.0f 伤害:x%.2f)" % [
		char_data.char_name, max_hp, move_speed, damage_multiplier
	])

func _physics_process(delta: float) -> void:
	_handle_movement()
	_handle_rotation()
	_process_passive_items(delta)
	_process_character_passive(delta)

func apply_recoil(backward_dir: Vector2, speed: float = -1.0) -> void:
	## 名字保留（外部/测试都按这个接口调用），但语义已经改成"开火挤压"。
	## backward_dir 只用来决定挤压方向，不参与任何位移计算。
	_fire_punch(backward_dir)

func _fire_punch(direction: Vector2) -> void:
	## 开火反馈：沿开火轴的垂直方向压扁一点点，再弹回。
	## 53px 的精灵压 6% ≈ 3px 的视觉变化，读作"枪有后劲"，但角色坐标一动不动。
	if sprite == null or not is_instance_valid(sprite):
		return
	if _sprite_base_scale == Vector2.ONE:
		_sprite_base_scale = sprite.scale
	var punch: float = GameConfig.PLAYER_FIRE_PUNCH_SCALE
	# 竖直方向开火时压在横轴上，横向开火时压在纵轴上，观感更贴近"后坐"
	var axis_vertical: bool = absf(direction.normalized().y) > absf(direction.normalized().x)
	var squashed: Vector2 = _sprite_base_scale
	if axis_vertical:
		squashed = Vector2(punch, 2.0 - punch) * _sprite_base_scale
	else:
		squashed = Vector2(2.0 - punch, punch) * _sprite_base_scale

	if _fire_punch_tween != null and _fire_punch_tween.is_valid():
		_fire_punch_tween.kill()
	sprite.scale = squashed
	_fire_punch_tween = create_tween()
	_fire_punch_tween.tween_property(sprite, "scale", _sprite_base_scale,
		GameConfig.PLAYER_FIRE_PUNCH_TIME).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

func _handle_movement() -> void:
	var input_dir := Vector2.ZERO
	input_dir.x = Input.get_axis("move_left", "move_right")
	input_dir.y = Input.get_axis("move_up", "move_down")
	input_dir = input_dir.normalized()
	var total_speed_mult := speed_multiplier * (1.0 + move_speed_bonus_multiplier)
	# 注意：这里只由输入决定速度。开火反馈是纯视觉的，不许再往 velocity 里塞东西。
	velocity = input_dir * move_speed * total_speed_mult
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
	xp_to_next_level = GameConfig.get_xp_required(current_level)
	level_up.emit(current_level)
	# 升级光效
	var vfx := get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.spawn_levelup_particles(global_position)
	# 播放升级音效
	AudioManager.play_sfx(_audio_lib.get_sound("level_up"))

# === 银币（局内货币） ===
func add_silver(amount: int) -> void:
	if amount <= 0:
		return
	silver += amount
	silver_changed.emit(silver)

func spend_silver(amount: int) -> bool:
	## 够就扣并返回 true；不够返回 false（调用方据此禁用按钮/提示）
	if amount <= 0:
		return true
	if silver < amount:
		return false
	silver -= amount
	silver_changed.emit(silver)
	return true

# === 升级效果应用 ===
func apply_upgrade(upgrade_type: String) -> void:
	match upgrade_type:
		"damage":
			damage_multiplier += GameConfig.UPGRADE_DAMAGE_MULT
		"speed":
			speed_multiplier += GameConfig.UPGRADE_SPEED_MULT
		"shoot_speed":
			shoot_speed_multiplier += GameConfig.UPGRADE_SHOOT_SPEED_MULT
		"max_hp":
			max_hp += GameConfig.UPGRADE_MAX_HP
			current_hp += GameConfig.UPGRADE_MAX_HP
			hp_changed.emit(current_hp, max_hp)
		"armor":
			armor += GameConfig.UPGRADE_ARMOR
		"pickup_range":
			pickup_range_bonus += GameConfig.UPGRADE_PICKUP_RANGE

# === 生命值相关 ===
func take_damage(amount: float, source_position: Vector2 = Vector2.ZERO) -> void:
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

	# 护甲改为百分比减伤（上限 75%），避免后期固定减伤导致免疫
	var reduction: float = GameConfig.calculate_damage_reduction(armor)
	var actual_damage: float = maxf(amount * (1.0 - reduction), 1.0)
	current_hp = clampf(current_hp - actual_damage, 0.0, max_hp)
	hp_changed.emit(current_hp, max_hp)
	_start_invincibility()
	_flash_damage()

	# 受击击退
	if source_position != Vector2.ZERO:
		var knockback_dir := (global_position - source_position).normalized()
		velocity += knockback_dir * 300.0

	# 播放受击音效
	AudioManager.play_sfx(_audio_lib.get_sound("player_hurt"))

	# 闪电护符反击
	if lightning_retaliate_damage > 0:
		_lightning_retaliate()

	# 受击屏幕震动 + 粒子
	var vfx := get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.screen_shake(4.0, 0.15)
		vfx.spawn_hit_particles(global_position, Color(0.9, 0.1, 0.1), 6)

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
		var lightning := LightningChainScene.instantiate()
		lightning.global_position = global_position
		lightning.base_damage = lightning_retaliate_damage
		lightning.damage_multiplier = 1.0
		lightning.max_jumps = 1
		lightning._current_damage = lightning_retaliate_damage
		get_tree().current_scene.add_child(lightning)

		# 播放音效
		AudioManager.play_sfx(_audio_lib.get_sound("lightning_chain"))

func heal(amount: float) -> void:
	current_hp = clampf(current_hp + amount, 0.0, max_hp)
	hp_changed.emit(current_hp, max_hp)
	if amount > 0:
		AudioManager.play_sfx(_audio_lib.get_sound("heal"))

func change_max_hp(delta_value: float) -> void:
	## 增减最大生命上限（深渊契约这类"临时上限"用）。
	## 故意不动 current_hp 的语义：扣上限时当前血量被 clamp 下去，
	## 还上限时也不会凭空把血补回来——不然契约就是个零成本的血包。
	## 调用方想补血请显式 heal()。
	max_hp = maxf(max_hp + delta_value, 1.0)
	current_hp = clampf(current_hp, 0.0, max_hp)
	hp_changed.emit(current_hp, max_hp)

func roll_crit() -> bool:
	## 暴击判定
	return crit_chance > 0 and randf() < crit_chance

func _on_enemy_died(_enemy: Node2D) -> void:
	## 敌人死亡时触发的效果（吸血等）
	if lifesteal_chance > 0 and randf() < lifesteal_chance:
		var heal_amount := max_hp * lifesteal_amount
		heal(heal_amount)
		print("🦷 吸血触发，恢复 %.1f 生命" % heal_amount)
		var vfx := get_node_or_null("/root/VFXManager")
		if vfx:
			vfx.spawn_hit_particles(global_position, Color(0.8, 0.1, 0.1), 4)

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
	# 死亡强烈震动
	var vfx := get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.screen_shake(12.0, 0.5)
	var tween := create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)

# === 被动道具处理 ===
func _process_passive_items(delta: float) -> void:
	# 护盾计时（只有拿到护盾道具才计时）
	if has_shield_item:
		shield_timer += delta
		if shield_timer >= shield_cooldown and not has_shield:
			_grant_shield()
	
	# 回血计时
	if regen_rate > 0:
		regen_timer += delta
		if regen_timer >= 5.0:  # 每5秒回血
			regen_timer = 0.0
			_heal_regen()

func _process_character_passive(delta: float) -> void:
	## 处理角色专属被动
	match character_id:
		"hunter":
			# 猎人直觉：拾取范围 +20%（只需设置一次即可）
			pass
		"priestess":
			# 神圣庇护：每10秒恢复5%最大生命
			character_passive_timer += delta
			if character_passive_timer >= character_passive_interval:
				character_passive_timer = 0.0
				heal(max_hp * 0.05)
				print("✨ 神圣庇护触发，恢复 %.0f 生命" % (max_hp * 0.05))

func _grant_shield() -> void:
	has_shield = true
	shield_timer = 0.0
	print("🛡️ 护盾生成!")
	_spawn_shield_aura()
	var vfx := get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.spawn_hit_particles(global_position, GameConfig.SHIELD_AURA_COLOR, 8)

func _spawn_shield_aura() -> void:
	## 护盾的"实体"表现：一圈青蓝色光环。
	## 早期版本是给 sprite 挂一个 set_loops() 的 modulate 循环 —— 有两个致命问题：
	## ① 那个 tween 从来没有被 kill，护盾破了人物还在一直闪蓝；
	## ② modulate 和受击闪红抢同一个属性，挨打时护盾完全看不出来。
	## 现在光环是独立子节点，护盾破时整圈扩散淡出，谁也不会覆盖谁。
	if _shield_aura != null and is_instance_valid(_shield_aura):
		return
	_shield_aura = ProjectileVisuals.make_ring_sprite(GameConfig.SHIELD_AURA_RADIUS, GameConfig.SHIELD_AURA_COLOR)
	_shield_aura.name = "ShieldAura"
	add_child(_shield_aura)
	_shield_aura.modulate.a = 0.0
	var fade_in := create_tween()
	fade_in.tween_property(_shield_aura, "modulate:a", 0.9, 0.16)
	_shield_pulse = create_tween().set_loops()
	_shield_pulse.tween_property(_shield_aura, "modulate:a", 0.5, 0.55)
	_shield_pulse.tween_property(_shield_aura, "modulate:a", 0.9, 0.55)

func _break_shield() -> void:
	has_shield = false
	shield_timer = 0.0
	print("💥 护盾破碎!")
	# 播放护盾破碎音效
	AudioManager.play_sfx(_audio_lib.get_sound("shield_break"))
	_break_shield_aura()
	var vfx := get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.spawn_hit_particles(global_position, GameConfig.SHIELD_AURA_COLOR, 10)
		vfx.screen_shake(3.0, 0.12)

func _break_shield_aura() -> void:
	if _shield_pulse != null and _shield_pulse.is_valid():
		_shield_pulse.kill()
	_shield_pulse = null
	if _shield_aura == null or not is_instance_valid(_shield_aura):
		_shield_aura = null
		return
	var ring: Sprite2D = _shield_aura
	_shield_aura = null
	ring.modulate = Color(1.6, 1.9, 2.0, 1.0)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", ring.scale * 1.5, 0.26)
	tw.tween_property(ring, "modulate:a", 0.0, 0.26)
	tw.chain().tween_callback(ring.queue_free)

func get_shield_status() -> Dictionary:
	## 给 HUD 用：是否拥有护盾道具 / 当前是否顶着护盾 / 充能进度
	if not has_shield_item and not has_shield:
		return {"has_item": false, "active": false, "progress": 0.0, "remain": 0.0}
	var progress: float = 1.0
	var remain: float = 0.0
	if not has_shield:
		progress = clampf(shield_timer / maxf(shield_cooldown, 0.01), 0.0, 1.0)
		remain = maxf(shield_cooldown - shield_timer, 0.0)
	return {
		"has_item": has_shield_item,
		"active": has_shield,
		"progress": progress,
		"remain": remain,
	}

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
			has_shield_item = true
			shield_cooldown = maxf(item.get_scaled_value(), 8.0)
			shield_timer = 0.0
			# 拿到道具立刻亮一层：原来要空等 30 秒冷却，玩家会以为"这东西没生效"
			if GameConfig.SHIELD_FIRST_GRANT_IMMEDIATE and not has_shield:
				_grant_shield()
		2:  # REGENERATION
			regen_rate = item.get_scaled_value()
		3:  # GREED
			xp_bonus_multiplier = item.get_scaled_value()
		4:  # BERSERKER
			berserker_bonus = item.get_scaled_value()
		5:  # FROZEN
			freeze_chance = minf(item.get_scaled_value(), GameConfig.PASSIVE_MAX_FREEZE)
		6:  # LIGHTNING_SHIELD
			lightning_retaliate_damage = item.get_scaled_value()
		7:  # SHADOW
			dodge_chance = minf(item.get_scaled_value(), GameConfig.PASSIVE_MAX_DODGE)
		8:  # VAMPIRIC
			lifesteal_chance = minf(item.get_scaled_value(), GameConfig.PASSIVE_MAX_LIFESTEAL)
		9:  # SWIFT
			move_speed_bonus_multiplier = item.get_scaled_value()
		10: # CLOVER
			crit_chance = minf(item.get_scaled_value(), GameConfig.PASSIVE_MAX_CRIT)

func get_owned_passive_items() -> Array[String]:
	## 获取已拥有的被动道具ID列表
	var items: Array[String] = []
	for item in passive_items:
		items.append(item.item_id)
	return items
