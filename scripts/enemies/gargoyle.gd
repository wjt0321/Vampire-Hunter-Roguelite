extends "res://scripts/enemies/enemy_base.gd"
class_name GargoyleEnemy
## 石像鬼 — 高护甲，移动慢，伤害高
## 特性：生命值低于50%时会石化恢复生命

@export var armor: float = 15.0  # 高护甲值
@export var petrify_threshold: float = 0.5  # 石化触发阈值（50%生命）
@export var petrify_duration: float = 3.0  # 石化持续时间
@export var petrify_heal_percent: float = 0.3  # 石化恢复生命百分比

var is_petrified: bool = false
var petrify_timer: float = 0.0
var has_petrified: bool = false  # 是否已经使用过石化

func _ready() -> void:
	max_hp = 200.0  # 高血量
	move_speed = 25.0  # 移动慢
	contact_damage = 40.0  # 高伤害
	xp_value = 30
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
	
	# 处理石化状态
	if is_petrified:
		petrify_timer -= delta
		if petrify_timer <= 0:
			_unpetrify()
		return
	
	# 检查是否需要石化
	if not has_petrified and current_hp / max_hp <= petrify_threshold:
		_petrify()
	
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

func _petrify() -> void:
	## 进入石化状态
	is_petrified = true
	has_petrified = true
	petrify_timer = petrify_duration
	
	print("🗿 石像鬼进入石化状态!")
	
	# 石化视觉效果
	if sprite:
		var tex := TextureManager.instance.get_enemy_texture("gargoyle", "petrify")
		if tex:
			sprite.texture = tex
			_adjust_sprite_scale()
		sprite.modulate = Color(0.7, 0.7, 0.7, 1.0)  # 轻微压暗
		# 石化粒子
		var vfx := get_node_or_null("/root/VFXManager")
		if vfx:
			vfx.spawn_death_particles(global_position, Color(0.5, 0.5, 0.5, 0.8), 15)
	
	# 石化时恢复生命
	var heal_amount := max_hp * petrify_heal_percent
	current_hp = clampf(current_hp + heal_amount, 0.0, max_hp)
	
	# 石化时无敌
	set_physics_process(false)

func _unpetrify() -> void:
	## 解除石化
	is_petrified = false
	set_physics_process(true)
	
	print("🗿 石像鬼解除石化!")
	
	# 恢复视觉效果
	if sprite:
		var tex := TextureManager.instance.get_enemy_texture("gargoyle", "wake")
		if tex:
			sprite.texture = tex
			_adjust_sprite_scale()
		sprite.modulate = Color.WHITE
		# 解除石化粒子
		var vfx := get_node_or_null("/root/VFXManager")
		if vfx:
			vfx.spawn_death_particles(global_position, Color(0.8, 0.8, 0.8, 0.8), 10)
	
	# 播放音效
	var audio_lib := AudioLib
	AudioManager.play_sfx(audio_lib.get_sound("enemy_death"))

func take_damage(amount: float) -> void:
	if is_dead:
		return
	
	# 石化时无敌
	if is_petrified:
		return
	
	# 应用护甲减伤
	var actual_damage := maxf(amount - armor, 1.0)
	current_hp -= actual_damage
	_flash_hit()
	
	if current_hp <= 0:
		_die()

func _flash_hit() -> void:
	## 受击闪白效果（石像鬼有护甲，效果不同）
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color(0.8, 0.8, 0.8, 1.0), 0.03)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.07)
	
	# 受击粒子（石头碎片）
	var vfx := get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.spawn_hit_particles(global_position, Color(0.6, 0.6, 0.6, 0.9), 4)
	
	# 播放受击音效（石头声）
	var audio_lib := AudioLib
	AudioManager.play_sfx(audio_lib.get_sound("hit_enemy"))

func _get_enemy_type() -> String:
	return "gargoyle"

func _load_sprite_texture() -> void:
	if sprite:
		var texture := TextureManager.instance.get_enemy_texture("gargoyle", "idle")
		if texture:
			sprite.texture = texture
			sprite.modulate = Color.WHITE
			_adjust_sprite_scale()
		else:
			_ensure_default_texture()
			_adjust_sprite_scale()
