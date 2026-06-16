extends "res://scripts/enemies/enemy_base.gd"
class_name SummonerEnemy
## 召唤师 — 保持距离，定期召唤小怪

@export var summon_interval: float = 5.0  # 召唤间隔
@export var summon_range: float = 200.0  # 召唤距离
@export var min_distance_to_player: float = 150.0  # 保持的最小距离
@export var max_distance_to_player: float = 300.0  # 保持的最大距离

var summon_timer: float = 0.0
var summon_count: int = 2  # 每次召唤数量

# 召唤特效
var summon_particles: CPUParticles2D = null

func _ready() -> void:
	max_hp = 50.0
	move_speed = 60.0
	contact_damage = 8.0
	xp_value = 20
	super._ready()
	
	# 创建召唤特效
	_summon_particles_setup()

func _summon_particles_setup() -> void:
	summon_particles = CPUParticles2D.new()
	summon_particles.emitting = false
	summon_particles.one_shot = true
	summon_particles.explosiveness = 1.0
	summon_particles.amount = 20
	summon_particles.lifetime = 0.5
	summon_particles.color = Color(0.8, 0.2, 0.9, 0.8)  # 紫色
	summon_particles.direction = Vector2.UP
	summon_particles.spread = 180.0
	summon_particles.gravity = Vector2.ZERO
	summon_particles.initial_velocity_min = 50.0
	summon_particles.initial_velocity_max = 100.0
	add_child(summon_particles)

func _physics_process(delta: float) -> void:
	if is_dead or player == null or not is_instance_valid(player):
		return
	
	# 处理冻结状态
	if is_frozen:
		freeze_timer -= delta
		if freeze_timer <= 0:
			_unfreeze()
		return
	
	var distance_to_player := global_position.distance_to(player.global_position)
	
	# 处理召唤
	summon_timer -= delta
	if summon_timer <= 0 and distance_to_player <= summon_range:
		_summon()
		summon_timer = summon_interval
	
	# 移动逻辑：保持距离
	_move_maintain_distance(delta, distance_to_player)

func _move_maintain_distance(delta: float, distance: float) -> void:
	var direction := (player.global_position - global_position).normalized()
	
	if distance < min_distance_to_player:
		# 太近，后退
		velocity = -direction * move_speed
	elif distance > max_distance_to_player:
		# 太远，靠近
		velocity = direction * move_speed
	else:
		# 距离合适，横向移动
		var perpendicular := Vector2(-direction.y, direction.x)
		velocity = perpendicular * move_speed
	
	move_and_slide()
	
	# 翻转
	if direction.x < 0:
		sprite.flip_h = true
	else:
		sprite.flip_h = false

func _summon() -> void:
	## 召唤小怪
	print("🔮 召唤师召唤了小怪!")
	
	# 播放特效
	if summon_particles:
		summon_particles.restart()
	
	# 播放音效
	var audio_lib := AudioLib
	AudioManager.play_sfx(audio_lib.get_sound("enemy_death"))
	
	# 召唤蝙蝠（较弱的敌人）
	for i in summon_count:
		var bat_scene := preload("res://scenes/enemies/bat.tscn")
		var bat := bat_scene.instantiate()
		
		# 在召唤师周围随机位置生成
		var angle := randf() * TAU
		var offset := Vector2(cos(angle), sin(angle)) * 40.0
		bat.global_position = global_position + offset
		
		get_tree().current_scene.add_child(bat)

func _get_enemy_type() -> String:
	return "summoner"
