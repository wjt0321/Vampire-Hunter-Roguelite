extends "res://scripts/enemies/enemy_base.gd"
## Boss: 吸血鬼领主
## 攻击模式：远程弹幕 + 召唤小怪 + 冲刺
## 50% 血量以下进入狂暴模式

enum BossPhase { NORMAL, ENRAGED, DESPERATE }
enum AttackState { IDLE, BARRAGE, SUMMON, DASH, COOLDOWN, DASH_WINDUP, NOVA_WINDUP, BARRAGE_WINDUP }

# === Boss 属性 ===
@export var barrage_count: int = 8         # 弹幕数量
@export var barrage_speed: float = 200.0   # 弹幕速度
@export var barrage_damage: float = 15.0
@export var summon_count: int = 3          # 召唤小怪数量
@export var dash_speed: float = 500.0      # 冲刺速度
@export var dash_duration: float = 0.4
@export var attack_cooldown: float = 2.5

# === 形态（0 领主 / 1 亲王 / 2 女王） ===
## 由 DungeonManager 在生成 Boss 前设置
@export var boss_variant: int = 0
## 形态对应的 tier（决定 Boss 血量档位）
var boss_tier: int = 1
## Boss 显示名（用于日志与血条）
var boss_title: String = "吸血鬼领主"
## 精灵体型倍率
var size_mult: float = 1.0
## 阶段阈值倍率（越小的形态越早狂暴）
var phase_threshold: float = 0.5
## 光环颜色
var aura_color: Color = Color(0.7, 0.05, 0.1, 0.35)

var current_phase: BossPhase = BossPhase.NORMAL
var attack_state: AttackState = AttackState.IDLE
var attack_timer: float = 0.0
var cooldown_timer: float = 0.0
var dash_timer: float = 0.0
var dash_direction: Vector2 = Vector2.ZERO
## 冲刺前摇 / 新星前摇：给玩家 0.5 秒看清地面预警再躲
const DASH_WINDUP: float = 0.45
const NOVA_WINDUP: float = 0.55
## 环形弹幕前摇。旧实现是"选到弹幕 → 同一帧就把一圈弹全射出去"，
## 玩家连 Boss 抬手的动作都看不到，弹幕就已经糊在脸上了。
## 现在先亮地面预警圈、站定蓄力 BARRAGE_WINDUP 秒，再真的开火。
const BARRAGE_WINDUP: float = 0.6
var windup_timer: float = 0.0
var phase_changed: bool = false
var desperate_changed: bool = false
var nova_count: int = 12

# === 登场演出（"亮血条"无敌时间） ===
## 玩家最烦的就是 Boss 刚刷出来、镜头还没跟过去就已经被打掉一截血。
## 所以登场期间：关碰撞（子弹直接穿过去，不会打空还没反馈）、免疫伤害、
## 不移动不攻击，血条从 0 填满后再正式开战。
const INTRO_BAR_DELAY: float = 1.1     # 登场后多久开始填血条
const INTRO_BAR_FILL: float = 1.3      # 血条填充时长
const INTRO_DURATION: float = 2.6      # 总无敌时长（要 > DELAY + FILL）
var intro_invulnerable: bool = true
var _intro_shield: Sprite2D = null
var _intro_pulse: Tween = null
var _last_block_fx: float = 0.0

var bat_scene: PackedScene = preload("res://scenes/enemies/bat.tscn")

# Boss 血条信号
signal boss_hp_changed(current: float, max_val: float)
signal boss_defeated
signal boss_phase_changed(phase: int)
## 登场演出结束（血条已亮满，可以开打）
signal boss_intro_finished

func _ready() -> void:
	# 先确定形态（tier / 攻击参数 / 体型 / 光环），再据此设定属性
	_apply_variant()

	base_hp = GameConfig.get_boss_hp(boss_tier)
	xp_value = 100
	silver_value = 12

	# Boss HP 只由形态 tier 决定，并随玩家等级软性放大
	# 注意：Boss 不再叠加层倍率与波次倍率，否则会出现"第三次方乘"的数值爆炸
	# 深渊倍率必须在这里手动乘：Boss 覆写 _ready、不走 EnemyBase 的缩放链
	max_hp = base_hp * GameConfig.get_player_level_hp_scale(_get_player_level()) \
		* GameConfig.get_abyss_hp_mult()
	loot_mult = GameConfig.get_abyss_loot_mult()
	_recalc_damage()
	current_hp = max_hp

	add_to_group("enemies")
	add_to_group("boss")
	_load_sprite_texture()
	_create_variant_aura()
	_find_player()
	_contact_area = _find_contact_area()

	_begin_intro()

func _begin_intro() -> void:
	## 登场演出：无敌 + 不动 + 血条从 0 填满
	intro_invulnerable = true
	current_hp = max_hp
	_set_collisions_enabled(false)
	_play_intro_visual()

	# 延迟一点再填血条，让玩家先看清"谁来了"
	await get_tree().create_timer(INTRO_BAR_DELAY).timeout
	if is_dead:
		return
	boss_hp_changed.emit(0.0, max_hp)
	var tween := create_tween()
	tween.tween_method(_update_boss_hp_bar, 0.0, max_hp, INTRO_BAR_FILL)

	# 用 timer 而不是 await tween.finished：嵌套协程里 tween 信号有过丢失记录
	await get_tree().create_timer(maxf(INTRO_DURATION - INTRO_BAR_DELAY, 0.1)).timeout
	_end_intro()

func _set_collisions_enabled(enabled: bool) -> void:
	## 关掉本体碰撞（子弹会直接穿过，不会"打空了还没反馈"）
	## 和接触判定（登场期间不该被贴脸掉血）
	if collision_shape:
		collision_shape.set_deferred("disabled", not enabled)
	var contact_shape := get_node_or_null("ContactArea/ContactShape") as CollisionShape2D
	if contact_shape:
		contact_shape.set_deferred("disabled", not enabled)

func _end_intro() -> void:
	if is_dead or not intro_invulnerable:
		return
	intro_invulnerable = false
	_update_boss_hp_bar(max_hp)
	_set_collisions_enabled(true)
	_clear_intro_visual()
	boss_intro_finished.emit()
	print("⚔️ %s 血条亮起，正式开战！" % boss_title)

func _play_intro_visual() -> void:
	## 登场表现：从半透明放大浮现 + 一圈护盾光环
	if sprite:
		var final_scale: Vector2 = sprite.scale
		var base_mod: Color = sprite.modulate
		sprite.modulate = Color(base_mod.r, base_mod.g, base_mod.b, 0.0)
		sprite.scale = final_scale * 0.6
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(sprite, "modulate:a", maxf(base_mod.a, 0.6), 0.5)
		tw.tween_property(sprite, "scale", final_scale, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	_intro_shield = Sprite2D.new()
	_intro_shield.name = "IntroShield"
	_intro_shield.texture = ProjectileVisuals.get_orb_texture()
	_intro_shield.material = ProjectileVisuals.get_additive_material()
	_intro_shield.modulate = Color(0.65, 0.85, 1.0, 0.35)
	_intro_shield.z_index = -1
	var ring_size: float = 150.0 * size_mult
	var tex_size: Vector2 = _intro_shield.texture.get_size()
	_intro_shield.scale = Vector2(ring_size / tex_size.x, ring_size / tex_size.y)
	add_child(_intro_shield)

	_intro_pulse = create_tween().set_loops()
	_intro_pulse.tween_property(_intro_shield, "modulate:a", 0.12, 0.55)
	_intro_pulse.tween_property(_intro_shield, "modulate:a", 0.42, 0.55)

	var vfx := get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.spawn_boss_warning(global_position)

func _clear_intro_visual() -> void:
	if _intro_pulse and _intro_pulse.is_valid():
		_intro_pulse.kill()
		_intro_pulse = null
	if is_instance_valid(_intro_shield):
		var ring := _intro_shield
		_intro_shield = null
		var tw := create_tween()
		tw.tween_property(ring, "scale", ring.scale * 1.6, 0.35).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(ring, "modulate:a", 0.0, 0.35)
		tw.tween_callback(ring.queue_free)

func _on_intro_hit_blocked() -> void:
	## 无敌期间的受击反馈：护盾闪光，让玩家知道"打到了但没生效"
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - _last_block_fx < 0.1:
		return
	_last_block_fx = now
	if is_instance_valid(_intro_shield):
		var tw := create_tween()
		tw.tween_property(_intro_shield, "modulate", Color(0.9, 0.97, 1.0, 0.9), 0.05)
		tw.tween_property(_intro_shield, "modulate", Color(0.65, 0.85, 1.0, 0.35), 0.12)
	var vfx := get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.spawn_hit_particles(global_position, Color(0.6, 0.9, 1.0), 3)

func _apply_variant() -> void:
	## 根据 boss_variant 配置形态差异
	match boss_variant:
		1:  # 血族亲王：更快、更密、体型略大
			boss_tier = 2
			boss_title = "血族亲王"
			move_speed = 75.0
			base_contact_damage = 22.0
			barrage_count = 10
			barrage_speed = 230.0
			summon_count = 4
			attack_cooldown = 2.2
			dash_speed = 560.0
			nova_count = 14
			size_mult = 1.1
			phase_threshold = 0.55
			aura_color = Color(0.55, 0.25, 1.0, 0.4)
		2:  # 血族女王：最强形态，光环金色
			boss_tier = 3
			boss_title = "血族女王 · 塞拉菲娜"
			move_speed = 85.0
			base_contact_damage = 26.0
			barrage_count = 12
			barrage_speed = 250.0
			summon_count = 5
			attack_cooldown = 2.0
			dash_speed = 620.0
			nova_count = 16
			size_mult = 1.2
			phase_threshold = 0.6
			aura_color = Color(1.0, 0.75, 0.2, 0.45)
		_:  # 吸血鬼领主（默认）
			boss_tier = 1
			boss_title = "吸血鬼领主"
			move_speed = 60.0
			base_contact_damage = 20.0
			barrage_count = 8
			barrage_speed = 200.0
			summon_count = 3
			attack_cooldown = 2.5
			dash_speed = 500.0
			nova_count = 12
			size_mult = 1.0
			phase_threshold = 0.5
			aura_color = Color(0.7, 0.05, 0.1, 0.35)

func _recalc_damage() -> void:
	## 统一从基础伤害推导实际接触伤害（阶段切换时复用，避免 HP 被误重置）
	## 深渊伤害倍率放在这里，狂暴/绝望重算时不会丢掉
	contact_damage = base_contact_damage * GameConfig.get_enemy_damage_multiplier(spawn_wave) \
		* GameConfig.get_abyss_damage_mult()

func _create_variant_aura() -> void:
	## 用不同颜色的光晕区分三种 Boss 形态
	var aura := Sprite2D.new()
	aura.name = "VariantAura"
	var tex := TextureManager.instance.get_effect_texture("portal")
	if tex == null:
		return
	aura.texture = tex
	aura.modulate = aura_color
	aura.scale = Vector2(1.8, 1.8) * size_mult
	aura.z_index = -1
	add_child(aura)

	var tw := create_tween().set_loops()
	tw.tween_property(aura, "modulate:a", aura_color.a * 0.3, 1.2)
	tw.tween_property(aura, "modulate:a", aura_color.a, 1.2)

func _update_boss_hp_bar(value: float) -> void:
	## 更新血条
	boss_hp_changed.emit(value, max_hp)

func _get_enemy_type() -> String:
	## Boss 的类型标识。图鉴按这个 id 解锁，
	## 缺了它，血铠领主在图鉴里永远是 ???（它也没实现 get_boss_type）。
	return "blood_lord"

func _load_sprite_texture() -> void:
	if sprite:
		var texture := TextureManager.instance.get_boss_texture("idle")
		if texture:
			sprite.texture = texture
			sprite.modulate = Color.WHITE
			_adjust_sprite_scale()
		else:
			_ensure_default_texture()
			_adjust_sprite_scale()

func _adjust_sprite_scale() -> void:
	## Boss 目标 128px，形态倍率乘在目标上。横条同样按一格算。
	_present_sprite(128.0 * size_mult)

func _physics_process(delta: float) -> void:
	if is_frozen:
		return
	if is_dead:
		return
	# 登场演出期间站着不动、不出招
	if intro_invulnerable:
		return
	if player == null or not is_instance_valid(player):
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
		
		AttackState.DASH_WINDUP:
			windup_timer += delta
			velocity = Vector2.ZERO
			if windup_timer >= DASH_WINDUP:
				windup_timer = 0.0
				dash_timer = 0.0
				attack_state = AttackState.DASH

		AttackState.NOVA_WINDUP:
			windup_timer += delta
			velocity = Vector2.ZERO
			if windup_timer >= NOVA_WINDUP:
				windup_timer = 0.0
				_release_nova()

		AttackState.BARRAGE_WINDUP:
			# 蓄力期间站定不动：一边滑一边蓄力，玩家根本读不出"要开火了"
			windup_timer += delta
			velocity = Vector2.ZERO
			if windup_timer >= BARRAGE_WINDUP:
				windup_timer = 0.0
				_release_barrage()

		AttackState.DASH:
			dash_timer += delta
			velocity = dash_direction * dash_speed
			move_and_slide()
			if dash_timer >= dash_duration:
				dash_timer = 0.0
				attack_state = AttackState.COOLDOWN
				# 恢复 idle 贴图
				if sprite and _sprite_loop_tex != null:
					use_sprite(_sprite_loop_tex, "loop")

func _check_phase_transition() -> void:
	if not phase_changed and current_hp <= max_hp * phase_threshold:
		phase_changed = true
		current_phase = BossPhase.ENRAGED
		boss_phase_changed.emit(1)
		# 狂暴视觉效果
		_enrage_effect()
		print("💀 %s 进入狂暴模式!" % boss_title)
		return
	if not desperate_changed and current_hp <= max_hp * 0.25:
		desperate_changed = true
		current_phase = BossPhase.DESPERATE
		boss_phase_changed.emit(2)
		_desperate_effect()
		print("🔥 %s 进入绝望模式!" % boss_title)

func _enrage_effect() -> void:
	# 切换到狂暴贴图
	if sprite:
		var tex := TextureManager.instance.get_boss_texture("enraged")
		if tex:
			use_sprite(tex, "loop")
	# 闪烁红色
	var tween := create_tween().set_loops(3)
	tween.tween_property(sprite, "modulate", Color(2.0, 0.3, 0.3, 1.0), 0.15)
	tween.tween_property(sprite, "modulate", Color(1.0, 0.5, 0.5, 1.0), 0.15)
	# 增强属性
	set_base_move_speed(88.0 + boss_variant * 10.0)
	base_contact_damage = 30.0 + boss_variant * 4.0
	# 只重算伤害，绝不能重算 HP（否则会重置 max_hp 并破坏血条）
	_recalc_damage()
	barrage_count = 12 + boss_variant * 2
	attack_cooldown = 2.0 - boss_variant * 0.1
	# 屏幕震动
	var vfx := get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.screen_shake(8.0, 0.4)

func _desperate_effect() -> void:
	# 切换到狂暴贴图（如有死亡/暴怒贴图可替换）
	if sprite:
		var tex := TextureManager.instance.get_boss_texture("enraged")
		if tex:
			use_sprite(tex, "loop")
	# 闪烁暗红
	var tween := create_tween().set_loops(5)
	tween.tween_property(sprite, "modulate", Color(3.0, 0.1, 0.1, 1.0), 0.1)
	tween.tween_property(sprite, "modulate", Color(1.0, 0.3, 0.3, 1.0), 0.1)
	# 极大增强
	set_base_move_speed(120.0 + boss_variant * 8.0)
	base_contact_damage = 40.0 + boss_variant * 5.0
	_recalc_damage()
	barrage_count = 16 + boss_variant * 2
	summon_count = 5 + boss_variant
	attack_cooldown = 1.5 - boss_variant * 0.05
	nova_count = 18 + boss_variant * 2
	# 屏幕震动
	var vfx := get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.screen_shake(12.0, 0.5)

func _choose_attack() -> void:
	var attacks: Array = ["barrage", "summon", "dash"]
	if current_phase == BossPhase.ENRAGED:
		# 狂暴模式更常弹幕
		attacks.append("barrage")
		attacks.append("barrage")
	elif current_phase == BossPhase.DESPERATE:
		# 绝望模式加入新星攻击并更频繁
		attacks.append("barrage")
		attacks.append("barrage")
		attacks.append("nova")
		attacks.append("dash")
	
	var choice: String = attacks.pick_random()
	match choice:
		"barrage":
			_attack_barrage()
		"summon":
			_attack_summon()
		"dash":
			_attack_dash()
		"nova":
			_attack_nova()

func _attack_barrage() -> void:
	## 环形弹幕：先前摇，再开火。
	## 前摇期间 Boss 站定不动，只亮地面预警圈——玩家有机会拉开距离或者穿过去。
	attack_state = AttackState.BARRAGE_WINDUP
	windup_timer = 0.0
	_play_attack_strip("attack1")
	_telegraph_attack()
	var vfx := get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.spawn_ground_marker(global_position, 170.0, _get_projectile_color(), BARRAGE_WINDUP)
	print("🔥 弹幕蓄力!")

func _release_barrage() -> void:
	## 前摇结束：真的射出一圈弹丸
	attack_state = AttackState.COOLDOWN
	var count: int = barrage_count
	for i in range(count):
		var angle: float = (TAU / float(count)) * float(i)
		var direction := Vector2(cos(angle), sin(angle))
		_spawn_boss_projectile(direction)
	print("🔥 弹幕攻击!")

func _play_attack_strip(state_name: String) -> void:
	## attack1 / attack2 仍是 1024 单张时不换图，避免 Boss 缩成一小块。
	## 文件换成横条之后，这里会播一次再回到待机或狂暴。
	if TextureManager.instance == null:
		return
	var tex := TextureManager.instance.get_boss_texture(state_name)
	if tex != null and SpriteSheetLib.frame_count(tex) > 1:
		use_sprite(tex, "once")

func _get_projectile_color() -> Color:
	## 三形态弹幕用不同颜色，混战时也能分清是谁的弹
	match boss_variant:
		1:
			return Color(0.78, 0.42, 1.0)
		2:
			return Color(1.0, 0.78, 0.25)
	return Color(1.0, 0.3, 0.22)

func _spawn_boss_projectile(direction: Vector2) -> void:
	var proj := Area2D.new()
	proj.add_to_group("enemy_projectiles")
	proj.collision_layer = GameConfig.LAYER_ENEMY_BULLET
	proj.collision_mask = GameConfig.LAYER_PLAYER | GameConfig.LAYER_WALL

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 8.0
	shape.shape = circle
	proj.add_child(shape)

	# 视觉：发光弹丸。Boss 弹幕又多又密，必须比小怪的更亮更清楚，
	# 早期这里是个 10x10 的纯色方块，混战里基本看不见。
	var core := Sprite2D.new()
	proj.add_child(core)
	ProjectileVisuals.style_sprite(core, _get_projectile_color(), 22.0, 22.0, true)

	var spawn_parent: Node = get_tree().current_scene
	if spawn_parent == null:
		spawn_parent = self
	spawn_parent.add_child(proj)
	proj.global_position = global_position + direction * 20.0

	# 移动 + 碰撞检测
	proj.body_entered.connect(func(body: Node2D):
		if body.is_in_group("player") and body.has_method("take_damage"):
			# 弹幕是"非接触伤害源"，与接触/爆炸/法术同一口径（波次 × 楼层 × 深渊）。
			# barrage_damage 始终是形态基础值，缩放只在命中时算一次，不会二次乘法。
			body.take_damage(_scaled_damage(barrage_damage), global_position)
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
	_play_attack_strip("attack2")
	_telegraph_attack()
	var count: int = summon_count
	if current_phase == BossPhase.ENRAGED:
		count += 2
	
	var wave_manager = null
	var wave_managers := get_tree().get_nodes_in_group("wave_manager")
	if wave_managers.size() > 0:
		wave_manager = wave_managers[0]
	
	for i in range(count):
		var angle: float = TAU * randf()
		var spawn_pos: Vector2 = global_position + Vector2(cos(angle), sin(angle)) * 100.0
		var bat := bat_scene.instantiate()
		bat.global_position = spawn_pos
		bat.spawn_wave = spawn_wave
		bat.floor_index = floor_index
		if bat.has_signal("enemy_died") and wave_manager and wave_manager.has_method("record_external_kill"):
			bat.enemy_died.connect(func(_e): wave_manager.record_external_kill("bat"))
		get_tree().current_scene.add_child(bat)
	print("🦇 召唤 %d 只蝙蝠!" % count)

func _attack_dash() -> void:
	## 冲刺攻击
	if player == null or not is_instance_valid(player):
		attack_state = AttackState.COOLDOWN
		return
	_telegraph_attack()
	dash_direction = (player.global_position - global_position).normalized()
	dash_timer = 0.0
	windup_timer = 0.0
	attack_state = AttackState.DASH_WINDUP
	# 地面预警：把"要冲到哪"画出来，而不是只让 Boss 自己闪两下
	var vfx := get_node_or_null("/root/VFXManager")
	if vfx:
		var landing: Vector2 = global_position + dash_direction * dash_speed * dash_duration
		vfx.spawn_ground_marker(landing, 82.0, Color(1.0, 0.22, 0.2), DASH_WINDUP)
	# 切换到冲刺贴图
	if sprite:
		var tex := TextureManager.instance.get_boss_texture("attack3")
		if tex:
			use_sprite(tex, "once")
	print("💨 冲刺预备!")


func _telegraph_attack() -> void:
	AudioManager.play_sfx(AudioLib.get_sound("boss_attack"))
	## 攻击前 Telegraph：红色闪烁 + 警告环
	if sprite:
		var tw := create_tween()
		tw.tween_property(sprite, "modulate", Color(2.0, 0.2, 0.2, 1.0), 0.1)
		tw.tween_property(sprite, "modulate", Color.WHITE, 0.15)
	var vfx := get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.spawn_boss_warning(global_position)

func _attack_nova() -> void:
	## 绝望模式新星：两圈向外扩散的弹丸。先亮 0.55s 地面圈，让玩家有机会拉开距离。
	_telegraph_attack()
	windup_timer = 0.0
	attack_state = AttackState.NOVA_WINDUP
	var vfx := get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.spawn_ground_marker(global_position, 150.0, Color(1.0, 0.35, 0.85), NOVA_WINDUP)
	print("💥 新星蓄力!")

func _release_nova() -> void:
	attack_state = AttackState.COOLDOWN
	var inner_count: int = nova_count
	var outer_count: int = nova_count + 6
	for i in range(inner_count):
		var angle: float = (TAU / float(inner_count)) * float(i)
		_spawn_boss_projectile(Vector2(cos(angle), sin(angle)))
	# 第二圈稍微旋转偏移
	for i in range(outer_count):
		var angle: float = (TAU / float(outer_count)) * float(i) + PI / float(outer_count)
		_spawn_boss_projectile(Vector2(cos(angle), sin(angle)))
	print("💥 新星爆发!")

func take_damage(amount: float) -> void:
	if is_dead:
		return
	# 登场无敌：伤害不生效，但要给玩家"打到了"的反馈
	if intro_invulnerable:
		_on_intro_hit_blocked()
		return
	amount = _subtract_hp(_direct_damage(amount))
	_after_damage_taken(amount)
	boss_hp_changed.emit(current_hp, max_hp)
	if current_hp <= 0:
		_die()
		return
	_flash_hit()

func take_damage_with_knockback(amount: float, _knockback_dir: Vector2, _knockback_force: float = 120.0, _stun_duration: float = 0.08) -> void:
	# Boss ignores displacement, but shares damage, HP and drain semantics.
	take_damage(amount)

func _die() -> void:
	if is_dead:
		return
	is_dead = true
	AudioManager.play_sfx(AudioLib.get_sound("enemy_death"))
	enemy_died.emit(self)
	boss_defeated.emit()
	# 死亡强烈震动
	var vfx := get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.screen_shake(15.0, 0.8)
	_drop_xp_gem()
	_drop_silver()
	# 掉落额外经验
	for i in range(5):
		var gem_scene := preload("res://scenes/player/xp_gem.tscn")
		var gem := gem_scene.instantiate() as Area2D
		gem.global_position = global_position + Vector2(randf_range(-40, 40), randf_range(-40, 40))
		gem.xp_value = _loot_scaled(20)
		get_tree().current_scene.call_deferred("add_child", gem)
	# 禁用碰撞
	collision_shape.set_deferred("disabled", true)
	set_physics_process(false)
	# 切换到死亡贴图
	if sprite:
		var tex := TextureManager.instance.get_boss_texture("death")
		if tex:
			use_sprite(tex, "hold")
	# Boss 死亡动画（更壮观）
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color(5.0, 0.0, 0.0, 1.0), 0.3)
	tween.tween_property(sprite, "scale", Vector2(3.0, 3.0), 0.5)
	tween.parallel().tween_property(sprite, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)
	print("👑 %s 已被击败!" % boss_title)
