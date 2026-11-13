extends "res://scripts/enemies/boss_stage.gd"
## 月蚀女王。换位前会标出落点。祭坛被毁掉后月相推进，安全圈缩小。

var altar: Node = null
var moon_phase: int = 0
var _blink_to: Vector2 = Vector2.ZERO
var _blinking: bool = false
var _timer: float = 1.4

const AssetSlots = preload("res://scripts/core/asset_slots.gd")
## 瞬移落点表现时长；与闪烁落点帧同帧起播，只驱动画面帧，不参与任何判定计时。
const APPEAR_VISUAL := 0.35
## 月相推进表现时长；祭坛破碎与月相 2 判定帧同帧起播，只驱动画面帧。
const PHASE_CHANGE_VISUAL := 0.6
## 死亡条带 0→6 帧的推进时长（<0.8s 自回收契约）。
const DEATH_VISUAL := 0.60

var _animation_textures: Dictionary = {}
var _fallback_texture: Texture2D
var _animation_state: String = ""
var _animation_elapsed: float = 0.0
## 瞬移落点表现剩余时长；>0 期间 _animation_for_state 选 appear，只在表现层递减。
var _appear_visual_remaining: float = 0.0
## 月相推进表现剩余时长；>0 期间选 phase_change，只在表现层递减。
var _phase_visual_remaining: float = 0.0

func _ready() -> void:
	boss_title = "月蚀女王"
	asset_id = "eclipse_queen"
	boss_tier = 5
	move_speed = 80.0
	base_contact_damage = 14.0
	sprite_tint = Color(0.62, 0.48, 0.95)
	_boot_boss()
	_spawn_altar()

func _get_enemy_type() -> String:
	return "eclipse_queen"

func _spawn_altar() -> void:
	altar = preload("res://scripts/enemies/moon_altar.gd").new()
	altar.owner_boss = self
	var parent := get_parent()
	if parent == null:
		return
	parent.add_child(altar)
	altar.global_position = global_position + Vector2(-130, 50)
	linked_nodes.append(altar)

func altar_destroyed() -> void:
	altar = null
	moon_phase = 1
	# 表现接线：phase_change 条带与祭坛破碎同帧起播；只驱动画面帧，判定一行不动。
	_phase_visual_remaining = PHASE_CHANGE_VISUAL
	_tick_sprite(0.0)
	boss_phase_changed.emit(1)

func _physics_process(delta: float) -> void:
	if is_dead or intro_invulnerable or player == null:
		return
	_timer -= delta
	if _blinking:
		if _timer <= 0.0:
			global_position = _blink_to
			_blinking = false
			_timer = 0.7 if moon_phase == 0 else 0.4
			# 表现接线：appear 条带与瞬移落点同帧起播；只驱动画面帧，判定一行不动。
			_appear_visual_remaining = APPEAR_VISUAL
			_tick_sprite(0.0)
		return
	if current_hp < max_hp * 0.4 and moon_phase < 2:
		moon_phase = 2
		boss_phase_changed.emit(2)
		# 表现接线：phase_change 条带与月相 2 判定帧同帧起播；只驱动画面帧。
		_phase_visual_remaining = PHASE_CHANGE_VISUAL
		_tick_sprite(0.0)
	var to_player := player.global_position - global_position
	velocity = to_player.normalized() * move_speed
	move_and_slide()
	if _timer > 0.0:
		return
	_blink_to = player.global_position
	_blinking = true
	_timer = 0.45

func safe_radius() -> float:
	return 150.0 if moon_phase == 0 else 90.0

func _die() -> void:
	if is_dead:
		return
	# main 的 boss_defeated 会同步清空 enemies 组；先退组才能保住死亡演出不被立刻清场。
	remove_from_group("enemies")
	_set_boss_collisions(false)
	if _contact_area != null:
		_contact_area.set_deferred("monitoring", false)
		_contact_area.set_deferred("monitorable", false)
	super._die()

func _play_death_visual() -> void:
	# TASK4 WIRE 已接线：真实素材下 tween_method 推 death 条带 0→6 帧（0.6s）后自回收，
	# 保住 <0.8s 自回收契约，祭坛才会经 linked_nodes 在 _exit_tree 连带清理。
	# 绑定本节点的 tween 随暂停冻结、随场景销毁取消；不依赖死后停掉的 _process。
	# 无精灵或无真实表时退回占位淡出兜底。
	if sprite == null:
		queue_free()
		return
	_show_animation("death")
	sprite.rotation = 0.0
	sprite.position = _sprite_rest_pos
	var tween := create_tween()
	if using_placeholder:
		tween.tween_property(sprite, "modulate:a", 0.0, 0.4)
	else:
		tween.tween_method(_advance_death_frame, 0.0, 6.0, DEATH_VISUAL)
	tween.tween_callback(queue_free)

func _advance_death_frame(progress: float) -> void:
	_set_animation_frame(int(progress))

func _load_sprite_texture() -> void:
	# 照搬守望者：6 状态表全量缓存（含缺图结果），状态 tick 不做路径检查或 load。
	_animation_textures.clear()
	for state in AssetSlots.BOSSES["eclipse_queen"]["states"]:
		var texture := AssetSlots.boss_texture("eclipse_queen", state)
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
	sprite.texture = _fallback_texture if using_placeholder else texture
	sprite.modulate = _rest_modulate()
	_present_sprite(128.0 * size_mult)

func _animation_for_state() -> String:
	# 优先级：death > intro(idle) > blink > appear > phase_change > move > idle。
	if is_dead:
		return "death"
	if intro_invulnerable:
		return "idle"
	if _blinking:
		return "blink"
	if _appear_visual_remaining > 0.0:
		return "appear"
	if _phase_visual_remaining > 0.0:
		return "phase_change"
	if velocity.length_squared() > 1.0:
		return "move"
	return "idle"

func _tick_sprite(delta: float) -> void:
	if sprite == null or is_dead:
		return
	if _appear_visual_remaining > 0.0:
		_appear_visual_remaining = maxf(_appear_visual_remaining - delta, 0.0)
	if _phase_visual_remaining > 0.0:
		_phase_visual_remaining = maxf(_phase_visual_remaining - delta, 0.0)
	_animation_elapsed += delta
	_show_animation(_animation_for_state())
	if absf(velocity.x) > 0.001:
		sprite.flip_h = velocity.x < 0.0
	sprite.rotation = 0.0
	if using_placeholder:
		super._tick_sprite(delta)
		return
	sprite.position = _sprite_rest_pos
	match _animation_state:
		"appear":
			_set_animation_frame(clampi(int(_animation_elapsed / APPEAR_VISUAL * 6.0), 0, 5))
		"phase_change":
			_set_animation_frame(clampi(int(_animation_elapsed / PHASE_CHANGE_VISUAL * 6.0), 0, 5))
		_:
			_set_animation_frame(int(_animation_elapsed * 8.0) % 6)

func _set_animation_frame(frame_index: int) -> void:
	if sprite != null:
		sprite.frame = clampi(frame_index, 0, sprite.hframes - 1)

