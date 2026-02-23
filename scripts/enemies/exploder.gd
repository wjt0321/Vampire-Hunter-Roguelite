extends "res://scripts/enemies/enemy_base.gd"
class_name Exploder
## 自爆僵尸 — 快速接近玩家，靠近后爆炸

const EXPLOSION_RANGE: float = 80.0      # 爆炸范围
const EXPLOSION_DAMAGE: float = 30.0     # 爆炸伤害
const DETONATION_DISTANCE: float = 60.0  # 引爆距离
const DETONATION_DELAY: float = 1.0      # 引爆延迟
const BLINK_RATE: float = 0.1            # 闪烁频率

var is_detonating: bool = false
var detonation_timer: float = 0.0
var blink_timer: float = 0.0

func _ready() -> void:
	max_hp = 40.0
	move_speed = 120.0
	contact_damage = 5.0
	xp_value = 12
	super._ready()

func _physics_process(delta: float) -> void:
	if is_dead or player == null or not is_instance_valid(player):
		return
	
	if is_detonating:
		# 正在引爆倒计时
		detonation_timer -= delta
		blink_timer -= delta
		
		# 闪烁效果
		if blink_timer <= 0:
			blink_timer = BLINK_RATE
			sprite.modulate = Color.RED if sprite.modulate == Color.WHITE else Color.WHITE
		
		# 引爆
		if detonation_timer <= 0:
			_explode()
	else:
		# 正常移动
		var distance_to_player := global_position.distance_to(player.global_position)
		
		if distance_to_player <= DETONATION_DISTANCE:
			# 进入引爆范围
			_start_detonation()
		else:
			# 快速接近玩家
			var direction := (player.global_position - global_position).normalized()
			velocity = direction * move_speed
			move_and_slide()
			
			# 翻转朝向
			if direction.x < 0:
				sprite.flip_h = true
			else:
				sprite.flip_h = false

func _start_detonation() -> void:
	is_detonating = true
	detonation_timer = DETONATION_DELAY
	blink_timer = 0.0
	# 停止移动
	velocity = Vector2.ZERO
	print("💣 自爆者开始引爆倒计时!")

func _explode() -> void:
	if is_dead:
		return
	
	print("💥 自爆者爆炸!")
	
	# 对范围内玩家造成伤害
	if player != null and is_instance_valid(player):
		var distance := global_position.distance_to(player.global_position)
		if distance <= EXPLOSION_RANGE:
			if player.has_method("take_damage"):
				player.take_damage(EXPLOSION_DAMAGE)
	
	# 播放爆炸音效
	var audio_lib := AudioLibraryScript.new()
	AudioManager.play_sfx(audio_lib.get_sound("explosion"))
	
	# 爆炸视觉效果
	var vfx := get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.spawn_death_particles(global_position, Color.ORANGE, 20)
	
	# 自爆者死亡（不触发正常死亡流程，避免重复音效）
	is_dead = true
	enemy_died.emit(self)
	
	# 禁用碰撞
	collision_shape.set_deferred("disabled", true)
	set_physics_process(false)
	
	# 立即消失
	queue_free()

func take_damage(amount: float) -> void:
	if is_dead:
		return
	
	current_hp -= amount
	_flash_hit()
	
	# 受伤时如果还没开始引爆，有概率提前引爆
	if not is_detonating and current_hp <= max_hp * 0.3:
		_start_detonation()
	
	if current_hp <= 0:
		_die()
