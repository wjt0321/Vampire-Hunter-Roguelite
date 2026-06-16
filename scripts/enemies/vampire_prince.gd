extends "res://scripts/enemies/enemy_base.gd"
class_name VampirePrinceEnemy
## 血族亲王 — 小Boss类型
## 特性：高血量、中等速度、会吸血恢复、有冲锋技能

@export var lifesteal_percent: float = 0.2  # 吸血百分比
@export var charge_cooldown: float = 5.0  # 冲锋冷却
@export var charge_speed: float = 250.0  # 冲锋速度
@export var charge_duration: float = 0.8  # 冲锋持续时间

var charge_timer: float = 0.0
var is_charging: bool = false
var charge_direction: Vector2 = Vector2.ZERO

# 阶段转换
var is_second_phase: bool = false

func _ready() -> void:
	max_hp = 350.0  # 高血量（介于普通敌人和Boss之间）
	move_speed = 70.0
	contact_damage = 25.0
	xp_value = 80  # 高经验值
	super._ready()

func _physics_process(delta: float) -> void:
	if is_dead or player == null or not is_instance_valid(player):
		return
	
	# 处理冻结状态
	if is_frozen:
		freeze_timer -= delta
		if freeze_timer <= 0:
			_unfreeze()
		return
	
	# 检查阶段转换
	if not is_second_phase and current_hp / max_hp <= 0.5:
		_enter_second_phase()
	
	# 处理冲锋
	if is_charging:
		velocity = charge_direction * charge_speed
		move_and_slide()
		return
	
	# 冲锋冷却
	charge_timer -= delta
	if charge_timer <= 0:
		_start_charge()
		charge_timer = charge_cooldown
	
	# 正常移动
	_move_towards_player(delta)

func _move_towards_player(_delta: float) -> void:
	var direction := (player.global_position - global_position).normalized()
	velocity = direction * move_speed
	move_and_slide()
	
	# 翻转
	if direction.x < 0:
		sprite.flip_h = true
	else:
		sprite.flip_h = false

func _start_charge() -> void:
	## 开始冲锋
	if player == null or not is_instance_valid(player):
		return
	
	is_charging = true
	charge_direction = (player.global_position - global_position).normalized()
	
	print("👑 血族亲王开始冲锋!")
	
	# 冲锋预警
	_flash_red()
	
	# 延迟后开始冲锋
	await get_tree().create_timer(0.3).timeout
	
	if is_dead:
		return
	
	# 冲锋特效
	var vfx := get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.spawn_death_particles(global_position, Color(0.8, 0.0, 0.0, 0.8), 10)
	
	# 冲锋持续时间
	await get_tree().create_timer(charge_duration).timeout
	
	if not is_dead:
		is_charging = false

func _flash_red() -> void:
	## 冲锋预警红色闪烁
	if sprite:
		var tween := create_tween()
		tween.tween_property(sprite, "modulate", Color(2.0, 0.5, 0.5, 1.0), 0.1)
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
		tween.tween_property(sprite, "modulate", Color(2.0, 0.5, 0.5, 1.0), 0.1)
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)

func _enter_second_phase() -> void:
	## 进入第二阶段
	is_second_phase = true
	move_speed = 90.0  # 速度提升
	contact_damage = 30.0  # 伤害提升
	
	print("👑 血族亲王进入狂暴状态!")
	
	# 第二阶段特效
	if sprite:
		sprite.modulate = Color(1.2, 0.8, 0.8, 1.0)  # 略微发红
	
	# 播放音效
	var audio_lib := AudioLib
	AudioManager.play_sfx(audio_lib.get_sound("boss_attack"))
	
	# 屏幕震动
	var vfx := get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.screen_shake(5.0, 0.3)

func take_damage(amount: float) -> void:
	if is_dead:
		return
	
	current_hp -= amount
	_flash_hit()
	
	if current_hp <= 0:
		_die()

func _flash_hit() -> void:
	## 受击闪白效果
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color(10.0, 10.0, 10.0, 1.0), 0.03)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.07)
	
	# 受击粒子
	var vfx := get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.spawn_hit_particles(global_position, Color(0.8, 0.0, 0.0, 0.9), 6)
	
	# 播放受击音效
	var audio_lib := AudioLib
	AudioManager.play_sfx(audio_lib.get_sound("hit_enemy"))

func _on_contact_area_body_entered(body: Node2D) -> void:
	## 碰到玩家时造成伤害并吸血
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(contact_damage)
		
		# 吸血
		var lifesteal := contact_damage * lifesteal_percent
		current_hp = clampf(current_hp + lifesteal, 0.0, max_hp)
		
		# 吸血特效
		var vfx := get_node_or_null("/root/VFXManager")
		if vfx:
			vfx.spawn_hit_particles(global_position, Color(0.8, 0.0, 0.0, 0.8), 4)

func _get_enemy_type() -> String:
	return "vampire_prince"

func _load_sprite_texture() -> void:
	if sprite:
		var texture := TextureManager.instance.get_enemy_texture("vampire_prince", "idle")
		if texture:
			sprite.texture = texture
			sprite.modulate = Color.WHITE
			_adjust_sprite_scale()
		else:
			_ensure_default_texture()
			_adjust_sprite_scale()
