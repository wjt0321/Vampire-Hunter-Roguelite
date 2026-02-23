extends "res://scripts/enemies/enemy_base.gd"
## Boss: 吸血鬼领主
## 攻击模式：远程弹幕 + 召唤小怪 + 冲刺
## 50% 血量以下进入狂暴模式

enum BossPhase { NORMAL, ENRAGED }
enum AttackState { IDLE, BARRAGE, SUMMON, DASH, COOLDOWN }

# === Boss 属性 ===
@export var barrage_count: int = 8         # 弹幕数量
@export var barrage_speed: float = 200.0   # 弹幕速度
@export var barrage_damage: float = 15.0
@export var summon_count: int = 3          # 召唤小怪数量
@export var dash_speed: float = 500.0      # 冲刺速度
@export var dash_duration: float = 0.4
@export var attack_cooldown: float = 2.5

var current_phase: BossPhase = BossPhase.NORMAL
var attack_state: AttackState = AttackState.IDLE
var attack_timer: float = 0.0
var cooldown_timer: float = 0.0
var dash_timer: float = 0.0
var dash_direction: Vector2 = Vector2.ZERO
var phase_changed: bool = false

var bat_scene: PackedScene = preload("res://scenes/enemies/bat.tscn")

# Boss 血条信号
signal boss_hp_changed(current: float, max_val: float)
signal boss_defeated
signal boss_phase_changed(phase: int)

func _ready() -> void:
	# 覆写基类属性
	max_hp = 845.0  # 增加30% (原650)
	move_speed = 60.0
	contact_damage = 20.0
	xp_value = 50  # 降低50% (原100)
	
	current_hp = max_hp
	add_to_group("enemies")
	add_to_group("boss")
	_ensure_sprite_texture()
	_find_player()

func _physics_process(delta: float) -> void:
	if is_dead or player == null or not is_instance_valid(player):
		return
	
	# 检查阶段转换
	_check_phase_transition()
	
	# 攻击状态机
	match attack_state:
		AttackState.IDLE:
			_move_towards_player(delta)
			attack_timer += delta
			var cd: float = attack_cooldown
			if current_phase == BossPhase.ENRAGED:
				cd *= 0.6  # 狂暴模式攻击更频繁
			if attack_timer >= cd:
				attack_timer = 0.0
				_choose_attack()
		
		AttackState.COOLDOWN:
			cooldown_timer += delta
			if cooldown_timer >= 1.0:
				cooldown_timer = 0.0
				attack_state = AttackState.IDLE
		
		AttackState.DASH:
			dash_timer += delta
			velocity = dash_direction * dash_speed
			move_and_slide()
			if dash_timer >= dash_duration:
				dash_timer = 0.0
				attack_state = AttackState.COOLDOWN

func _check_phase_transition() -> void:
	if phase_changed:
		return
	if current_hp <= max_hp * 0.5:
		phase_changed = true
		current_phase = BossPhase.ENRAGED
		boss_phase_changed.emit(1)
		# 狂暴视觉效果
		_enrage_effect()
		print("💀 吸血鬼领主进入狂暴模式!")

func _enrage_effect() -> void:
	# 闪烁红色
	var tween := create_tween().set_loops(3)
	tween.tween_property(sprite, "modulate", Color(2.0, 0.3, 0.3, 1.0), 0.15)
	tween.tween_property(sprite, "modulate", Color(1.0, 0.5, 0.5, 1.0), 0.15)
	# 增强属性
	move_speed = 90.0
	contact_damage = 30.0
	barrage_count = 12

func _choose_attack() -> void:
	var attacks: Array = ["barrage", "summon", "dash"]
	if current_phase == BossPhase.ENRAGED:
		# 狂暴模式更常弹幕
		attacks.append("barrage")
		attacks.append("barrage")
	
	var choice: String = attacks.pick_random()
	match choice:
		"barrage":
			_attack_barrage()
		"summon":
			_attack_summon()
		"dash":
			_attack_dash()

func _attack_barrage() -> void:
	## 弹幕攻击：向四周发射弹丸
	attack_state = AttackState.COOLDOWN
	var count: int = barrage_count
	for i in range(count):
		var angle: float = (TAU / float(count)) * float(i)
		var direction := Vector2(cos(angle), sin(angle))
		_spawn_boss_projectile(direction)
	print("🔥 弹幕攻击!")

func _spawn_boss_projectile(direction: Vector2) -> void:
	var proj := Area2D.new()
	proj.collision_layer = 2
	proj.collision_mask = 1
	proj.global_position = global_position + direction * 20.0
	
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 6.0
	shape.shape = circle
	proj.add_child(shape)
	
	# 视觉
	var visual := ColorRect.new()
	visual.color = Color(1.0, 0.2, 0.0, 0.9)  # 红色弹丸
	visual.size = Vector2(10, 10)
	visual.position = Vector2(-5, -5)
	proj.add_child(visual)
	
	get_tree().current_scene.add_child(proj)
	
	# 移动 + 碰撞检测
	proj.body_entered.connect(func(body: Node2D):
		if body.is_in_group("player") and body.has_method("take_damage"):
			body.take_damage(barrage_damage)
		proj.queue_free()
	)
	
	# 移动（使用 tween 模拟弹丸飞行）
	var target_pos: Vector2 = proj.global_position + direction * 600.0
	var travel_time: float = 600.0 / barrage_speed
	var tween := proj.create_tween()
	tween.tween_property(proj, "global_position", target_pos, travel_time)
	tween.tween_callback(proj.queue_free)

func _attack_summon() -> void:
	## 召唤小怪
	attack_state = AttackState.COOLDOWN
	var count: int = summon_count
	if current_phase == BossPhase.ENRAGED:
		count += 2
	
	for i in range(count):
		var angle: float = TAU * randf()
		var spawn_pos: Vector2 = global_position + Vector2(cos(angle), sin(angle)) * 100.0
		var bat := bat_scene.instantiate()
		bat.global_position = spawn_pos
		if bat.has_signal("enemy_died"):
			# 连接到 wave_manager 的信号
			var wave_managers := get_tree().get_nodes_in_group("wave_manager") 
			# 小怪不计入波次管理
		get_tree().current_scene.add_child(bat)
	print("🦇 召唤 %d 只蝙蝠!" % count)

func _attack_dash() -> void:
	## 冲刺攻击
	if player == null or not is_instance_valid(player):
		attack_state = AttackState.COOLDOWN
		return
	attack_state = AttackState.DASH
	dash_timer = 0.0
	dash_direction = (player.global_position - global_position).normalized()
	# 冲刺预警效果
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color(3.0, 1.0, 1.0, 1.0), 0.1)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
	print("💨 冲刺攻击!")

func take_damage(amount: float) -> void:
	if is_dead:
		return
	current_hp -= amount
	_flash_hit()
	boss_hp_changed.emit(current_hp, max_hp)
	if current_hp <= 0:
		_die()

func _die() -> void:
	if is_dead:
		return
	is_dead = true
	enemy_died.emit(self)
	boss_defeated.emit()
	_drop_xp_gem()
	# 掉落额外经验
	for i in range(5):
		var gem_scene := preload("res://scenes/player/xp_gem.tscn")
		var gem := gem_scene.instantiate() as Area2D
		gem.global_position = global_position + Vector2(randf_range(-40, 40), randf_range(-40, 40))
		gem.xp_value = 20
		get_tree().current_scene.call_deferred("add_child", gem)
	# 禁用碰撞
	collision_shape.set_deferred("disabled", true)
	set_physics_process(false)
	# Boss 死亡动画（更壮观）
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color(5.0, 0.0, 0.0, 1.0), 0.3)
	tween.tween_property(sprite, "scale", Vector2(3.0, 3.0), 0.5)
	tween.parallel().tween_property(sprite, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)
	print("👑 吸血鬼领主已被击败!")
