extends "res://scripts/enemies/boss_stage.gd"
## 血铠领主。正面盾挡，剑击连段，冲锋撞墙后眩晕。
## 盾破了才进入猛攻，不靠血量百分比变身。
## 动画只读战斗状态；持盾挥剑第 3 帧、无盾下劈第 2 帧与真实命中同步。

enum Phase { GUARD, BROKEN }
enum Motion { IDLE, WINDUP, CHARGE, STUN, SWING }

const SHIELD_HP := 90.0
const STUN_TIME := 1.35
const CHARGE_SPEED := 460.0
const CHARGE_TIME := 0.42
const WINDUP_TIME := 0.45

var phase: Phase = Phase.GUARD
var motion: Motion = Motion.IDLE
var shield_hp: float = SHIELD_HP
var _hit_dir: Vector2 = Vector2.ZERO
var _motion_timer: float = 0.8
var _charge_dir: Vector2 = Vector2.RIGHT
var _swings_left: int = 0

const AssetSlots = preload("res://scripts/core/asset_slots.gd")
const SWING_RECOVERY := 0.14
const SHIELD_BREAK_VISUAL := 0.30
const ENRAGED_VISUAL := 0.36
const DEATH_VISUAL := 0.60

var _animation_textures: Dictionary = {}
var _fallback_texture: Texture2D
var _animation_state: String = ""
var _animation_elapsed: float = 0.0
var _break_visual_elapsed: float = -1.0
var _swing_windup: float = 0.22
var _swing_recovery_remaining: float = 0.0

func _load_sprite_texture() -> void:
	# 包括缺图结果一起缓存；状态 tick 不做路径检查或 load。
	_animation_textures.clear()
	for state in AssetSlots.BOSSES["blood_lord"]["states"]:
		var texture := AssetSlots.boss_texture("blood_lord", state)
		if texture != null and texture.get_size() == Vector2(768, 128):
			_animation_textures[state] = texture
	_fallback_texture = null
	if TextureManager.instance != null:
		_fallback_texture = TextureManager.instance.get_boss_texture("idle")
	if _fallback_texture == null:
		var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
		image.fill(Color.WHITE)
		_fallback_texture = ImageTexture.create_from_image(image)
	_animation_state = ""
	_show_animation("idle")

func _show_animation(state: String) -> void:
	if sprite == null or _animation_state == state:
		return
	_animation_state = state
	_animation_elapsed = 0.0
	var texture: Texture2D = _animation_textures.get(state)
	using_placeholder = texture == null
	placeholder_tint = sprite_tint
	# 缺无盾动作时不能借用专属持盾 idle；回到旧图并明确标为占位。
	sprite.texture = _fallback_texture if using_placeholder else texture
	sprite.modulate = _rest_modulate()
	_present_sprite(128.0 * size_mult)

func _animation_for_motion() -> String:
	if is_dead:
		return "death"
	if intro_invulnerable:
		return "idle"
	# 破盾表现不遮挡攻击预告/命中，也不让冲锋方向失去可读性。
	if motion == Motion.SWING or _swing_recovery_remaining > 0.0:
		return "broken_sword_combo" if phase == Phase.BROKEN else "sword_combo"
	if motion == Motion.CHARGE:
		return "broken_move" if phase == Phase.BROKEN else "charge"
	if _break_visual_elapsed >= 0.0 and _break_visual_elapsed < SHIELD_BREAK_VISUAL:
		return "shield_break"
	if motion == Motion.STUN:
		return "stunned" if phase == Phase.BROKEN else "guarded_stunned"
	if motion == Motion.WINDUP:
		return "enraged" if phase == Phase.BROKEN else "guard"
	if _break_visual_elapsed >= SHIELD_BREAK_VISUAL and _break_visual_elapsed < SHIELD_BREAK_VISUAL + ENRAGED_VISUAL:
		return "enraged"
	if velocity.length_squared() > 1.0:
		return "broken_move" if phase == Phase.BROKEN else "move"
	return "enraged" if phase == Phase.BROKEN else "idle"

func _tick_sprite(delta: float) -> void:
	if sprite == null or is_dead:
		return
	if _break_visual_elapsed >= 0.0:
		_break_visual_elapsed += delta
		if motion == Motion.SWING or motion == Motion.CHARGE or _swing_recovery_remaining > 0.0:
			# 破盾被无盾攻击/冲锋抢占即消费掉，之后不能重播有盾的前段。
			_break_visual_elapsed = maxf(_break_visual_elapsed, SHIELD_BREAK_VISUAL)
	_animation_elapsed += delta
	_show_animation(_animation_for_motion())
	var direction := facing()
	if motion == Motion.CHARGE:
		direction = _charge_dir
	elif motion == Motion.IDLE and velocity.length_squared() > 1.0:
		direction = velocity
	if absf(direction.x) > 0.001:
		sprite.flip_h = direction.x < 0.0
	sprite.rotation = 0.0
	if using_placeholder:
		super._tick_sprite(delta)
		return
	sprite.position = _sprite_rest_pos
	if _animation_state == "sword_combo" or _animation_state == "broken_sword_combo":
		# 无盾：0/1 预备、2 命中、3/4/5 收招；持盾仍是 0/1/2 预备、3 命中。
		var impact_frame := 2 if phase == Phase.BROKEN else 3
		if _swing_recovery_remaining > 0.0:
			_set_animation_frame(impact_frame + int((1.0 - _swing_recovery_remaining / SWING_RECOVERY) * (6 - impact_frame)))
		else:
			_set_animation_frame(clampi(int((1.0 - _motion_timer / _swing_windup) * impact_frame), 0, impact_frame - 1))
	elif _animation_state == "guard" and motion == Motion.WINDUP:
		_set_animation_frame(int((1.0 - _motion_timer / WINDUP_TIME) * 6.0))
	elif _animation_state == "charge":
		_set_animation_frame(int((1.0 - _motion_timer / CHARGE_TIME) * 6.0))
	elif _animation_state == "shield_break":
		_set_animation_frame(int(_break_visual_elapsed / SHIELD_BREAK_VISUAL * 6.0))
	elif _animation_state == "enraged":
		var elapsed := maxf(_break_visual_elapsed - SHIELD_BREAK_VISUAL, _animation_elapsed)
		_set_animation_frame(int(elapsed / ENRAGED_VISUAL * 6.0))
	else:
		_set_animation_frame(int(_animation_elapsed * 8.0) % 6)

func _set_animation_frame(frame_index: int) -> void:
	if sprite != null:
		sprite.frame = clampi(frame_index, 0, sprite.hframes - 1)

func _die() -> void:
	if is_dead:
		return
	# main 的 boss_defeated 同步清空 enemies；main 另将房间退出绑定到本节点回收。
	remove_from_group("enemies")
	_set_boss_collisions(false)
	if _contact_area != null:
		_contact_area.set_deferred("monitoring", false)
		_contact_area.set_deferred("monitorable", false)
	super._die()

func _play_death_visual() -> void:
	_show_animation("death")
	sprite.rotation = 0.0
	sprite.position = _sprite_rest_pos
	var tween := create_tween()
	# 绑定本节点的 tween 随暂停冻结、随场景销毁取消；不依赖死后停掉的 _process。
	if using_placeholder:
		tween.tween_property(sprite, "modulate:a", 0.0, 0.4)
	else:
		tween.tween_method(_advance_death_frame, 0.0, 6.0, DEATH_VISUAL)
	tween.tween_callback(queue_free)

func _advance_death_frame(progress: float) -> void:
	_set_animation_frame(int(progress))

func _ready() -> void:
	boss_title = "血铠领主"
	asset_id = "blood_lord"
	boss_tier = 1
	move_speed = 70.0
	base_contact_damage = 16.0
	sprite_tint = Color(0.68, 0.74, 0.86)
	_boot_boss()

func _get_enemy_type() -> String:
	return "blood_lord"

func facing() -> Vector2:
	if player != null and is_instance_valid(player):
		var toward := player.global_position - global_position
		if toward.length_squared() > 1.0:
			return toward.normalized()
	return _charge_dir

func is_frontal_hit(incoming: Vector2) -> bool:
	if phase == Phase.BROKEN or incoming.length_squared() < 0.001:
		return false
	return facing().dot(incoming.normalized()) < -0.35

func take_damage_with_knockback(amount: float, knockback_dir: Vector2, _knockback_force: float = 120.0, _stun_duration: float = 0.08) -> void:
	_hit_dir = knockback_dir
	take_damage(amount)
	_hit_dir = Vector2.ZERO

func _direct_damage(amount: float) -> float:
	amount = super._direct_damage(amount)
	if phase == Phase.BROKEN:
		return amount
	var frontal := is_frontal_hit(_hit_dir)
	if frontal:
		shield_hp -= amount * 0.45
		amount *= 0.3
	else:
		shield_hp -= amount
	if shield_hp <= 0.0:
		_break_shield()
	return amount

func _break_shield() -> void:
	if phase == Phase.BROKEN:
		return
	phase = Phase.BROKEN
	shield_hp = 0.0
	_break_visual_elapsed = 0.0
	_tick_sprite(0.0)
	boss_phase_changed.emit(1)

func notify_wall_contact() -> void:
	if motion != Motion.CHARGE:
		return
	motion = Motion.STUN
	_motion_timer = STUN_TIME
	velocity = Vector2.ZERO

func _physics_process(delta: float) -> void:
	if is_dead or intro_invulnerable:
		return
	if player == null or not is_instance_valid(player):
		return
	_motion_timer -= delta
	_swing_recovery_remaining = maxf(_swing_recovery_remaining - delta, 0.0)
	match motion:
		Motion.STUN:
			velocity = Vector2.ZERO
			if _motion_timer <= 0.0:
				motion = Motion.IDLE
				_motion_timer = 0.45
		Motion.WINDUP:
			velocity = Vector2.ZERO
			if _motion_timer <= 0.0:
				motion = Motion.CHARGE
				_motion_timer = CHARGE_TIME
				_charge_dir = facing()
		Motion.CHARGE:
			velocity = _charge_dir * CHARGE_SPEED
			move_and_slide()
			if get_slide_collision_count() > 0:
				notify_wall_contact()
			elif _motion_timer <= 0.0:
				motion = Motion.IDLE
				_motion_timer = 0.55
		Motion.SWING:
			velocity = Vector2.ZERO
			if _motion_timer <= 0.0:
				_swing_recovery_remaining = SWING_RECOVERY
				_strike()
				_swings_left -= 1
				if _swings_left > 0:
					_motion_timer = 0.28
					_swing_windup = 0.28 - SWING_RECOVERY
				else:
					motion = Motion.IDLE
					_motion_timer = 0.7 if phase == Phase.GUARD else 0.35
		_:
			var to_player := player.global_position - global_position
			velocity = to_player.normalized() * move_speed * (1.25 if phase == Phase.BROKEN else 0.75)
			move_and_slide()
			if _motion_timer > 0.0:
				_tick_sprite(0.0)
				return
			if to_player.length() > 160.0 and phase == Phase.GUARD:
				motion = Motion.WINDUP
				_motion_timer = WINDUP_TIME
				_charge_dir = to_player.normalized()
			else:
				motion = Motion.SWING
				_swings_left = 3 if phase == Phase.BROKEN else 2
				_motion_timer = 0.22
				_swing_windup = 0.22
				_swing_recovery_remaining = 0.0
	_tick_sprite(0.0)

func _strike() -> void:
	# 先把画面设到命中帧，再回调玩家扣血；保持原有 0.22/0.28 秒伤害时点。
	_show_animation("broken_sword_combo" if phase == Phase.BROKEN else "sword_combo")
	if not using_placeholder:
		_set_animation_frame(2 if phase == Phase.BROKEN else 3)
	var forward := facing()
	for enemy in get_tree().get_nodes_in_group("player"):
		if not (enemy is Node2D):
			continue
		var offset: Vector2 = (enemy as Node2D).global_position - global_position
		if offset.length() > 96.0:
			continue
		if absf(forward.angle_to(offset)) > 0.7:
			continue
		if enemy.has_method("take_damage"):
			enemy.take_damage(14.0 if phase == Phase.GUARD else 18.0)
