extends "res://scripts/enemies/boss_stage.gd"
## 墓穴守望者。结界还在就能把棺材里的东西拉起来。结界被打掉后不再复苏。

var ward: Node = null
var _sweep_timer: float = 1.6
var _sweep_left: float = 0.0
var _sweep_dir: Vector2 = Vector2.RIGHT
var _revive_cd: float = 3.0

const AssetSlots = preload("res://scripts/core/asset_slots.gd")
## 扫击表现时长，与伤害窗 0.55s 同长：动画起点帧与伤害窗起点同帧，不加前摇。
## 只驱动画面帧推进，不参与任何判定计时。
const SWEEP_VISUAL := 0.55
## 复苏表现时长；与僵尸生成同帧起播，只驱动画面帧
const REVIVE_VISUAL := 0.6
## 结界破碎表现时长；与 ward_broken 同帧起播，只驱动画面帧
const WARD_BREAK_VISUAL := 0.6
## 死亡条带 0→6 帧的推进时长（<0.8s 自回收契约）
const DEATH_VISUAL := 0.60

var _animation_textures: Dictionary = {}
var _fallback_texture: Texture2D
var _animation_state: String = ""
var _animation_elapsed: float = 0.0
## 复苏表现剩余时长；>0 期间 _animation_for_state 选 revive，只在表现层递减
var _revive_visual_remaining: float = 0.0
## 结界破碎表现剩余时长；>0 期间选 ward_break
var _ward_break_visual_remaining: float = 0.0

func _ready() -> void:
	boss_title = "墓穴守望者"
	asset_id = "tomb_warden"
	boss_tier = 3
	move_speed = 58.0
	base_contact_damage = 14.0
	sprite_tint = Color(0.55, 0.62, 0.68)
	_boot_boss()
	_spawn_ward()

func _get_enemy_type() -> String:
	return "tomb_warden"

func _spawn_ward() -> void:
	ward = preload("res://scripts/enemies/ward_core.gd").new()
	ward.owner_boss = self
	var parent := get_parent()
	if parent == null:
		return
	parent.add_child(ward)
	ward.global_position = global_position + Vector2(120, 40)
	linked_nodes.append(ward)

func ward_broken() -> void:
	ward = null
	# 表现接线：结界破碎与 ward_break 条带同帧起播；只驱动画面帧
	_ward_break_visual_remaining = WARD_BREAK_VISUAL
	_tick_sprite(0.0)
	boss_phase_changed.emit(1)

func _physics_process(delta: float) -> void:
	if is_dead or intro_invulnerable or player == null:
		return
	var to_player := player.global_position - global_position
	velocity = to_player.normalized() * move_speed * (1.2 if ward == null else 0.7)
	move_and_slide()
	_sweep_timer -= delta
	_revive_cd -= delta
	if _sweep_left > 0.0:
		_sweep_left -= delta
		if _sweep_hits():
			player.take_damage(9.0)
	elif _sweep_timer <= 0.0:
		_sweep_dir = to_player.normalized()
		_sweep_left = 0.55
		_sweep_timer = 2.8
		# 表现接线：扫击条带与伤害窗同帧起播（第 0 帧），朝向同帧锁定 _sweep_dir；
		# 灯笼画在条带角色右侧，flip_h 镜像即可，不旋转。判定计时一行不动。
		_show_animation("lantern_sweep")
		if not using_placeholder:
			_set_animation_frame(0)
		if sprite != null:
			sprite.flip_h = _sweep_dir.x < 0.0
	if ward != null and _revive_cd <= 0.0:
		_revive_cd = 6.0
		_raise_one()

func _sweep_hits() -> bool:
	if player == null:
		return false
	var offset: Vector2 = player.global_position - global_position
	return offset.length() < 260.0 and absf(_sweep_dir.angle_to(offset)) < 0.35

func _raise_one() -> void:
	if get_tree().get_nodes_in_group("enemies").size() > 12:
		return
	# 表现接线：revive 条带与僵尸生成同帧起播；生成时点与上限判定一行不动
	_revive_visual_remaining = REVIVE_VISUAL
	var zombie = load("res://scenes/enemies/zombie.tscn").instantiate()
	zombie.global_position = global_position + Vector2(-40, 30)
	var parent := get_parent()
	if parent:
		parent.add_child(zombie)
	_tick_sprite(0.0)

func can_revive() -> bool:
	return ward != null and is_instance_valid(ward) and ward.get("is_dead") != true

func _die() -> void:
	if is_dead:
		return
	# main 的 boss_defeated 会同步清空 enemies 组；先退组才能保住死亡条带不被立刻清场。
	remove_from_group("enemies")
	_set_boss_collisions(false)
	if _contact_area != null:
		_contact_area.set_deferred("monitoring", false)
		_contact_area.set_deferred("monitorable", false)
	super._die()

func _play_death_visual() -> void:
	# 同织血母皇：真实素材下 tween_method 推 death 条带 0→6 帧（0.6s）后自回收，
	# 保住 <0.8s 自回收契约，结界才会经 linked_nodes 在 _exit_tree 连带清理。
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
	# 照搬织血母皇：6 状态表全量缓存（含缺图结果），状态 tick 不做路径检查或 load。
	_animation_textures.clear()
	for state in AssetSlots.BOSSES["tomb_warden"]["states"]:
		var texture := AssetSlots.boss_texture("tomb_warden", state)
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
	if is_dead:
		return "death"
	if intro_invulnerable:
		return "idle"
	if _sweep_left > 0.0:
		return "lantern_sweep"
	if _revive_visual_remaining > 0.0:
		return "revive"
	if _ward_break_visual_remaining > 0.0:
		return "ward_break"
	if velocity.length_squared() > 1.0:
		return "move"
	return "idle"

func _tick_sprite(delta: float) -> void:
	if sprite == null or is_dead:
		return
	if _revive_visual_remaining > 0.0:
		_revive_visual_remaining = maxf(_revive_visual_remaining - delta, 0.0)
	if _ward_break_visual_remaining > 0.0:
		_ward_break_visual_remaining = maxf(_ward_break_visual_remaining - delta, 0.0)
	_animation_elapsed += delta
	_show_animation(_animation_for_state())
	# 台账硬约束：提灯朝向与扫射预警同向——sweep 期间 flip_h 锁定 _sweep_dir，
	# 不跟移动方向；平时沿用母皇的 velocity flip_h 镜像。
	if _sweep_left > 0.0:
		sprite.flip_h = _sweep_dir.x < 0.0
	elif absf(velocity.x) > 0.001:
		sprite.flip_h = velocity.x < 0.0
	sprite.rotation = 0.0
	if using_placeholder:
		super._tick_sprite(delta)
		return
	sprite.position = _sprite_rest_pos
	match _animation_state:
		"lantern_sweep":
			_set_animation_frame(clampi(int(_animation_elapsed / SWEEP_VISUAL * 6.0), 0, 5))
		"revive":
			_set_animation_frame(clampi(int(_animation_elapsed / REVIVE_VISUAL * 6.0), 0, 5))
		"ward_break":
			_set_animation_frame(clampi(int(_animation_elapsed / WARD_BREAK_VISUAL * 6.0), 0, 5))
		_:
			_set_animation_frame(int(_animation_elapsed * 8.0) % 6)

func _set_animation_frame(frame_index: int) -> void:
	if sprite != null:
		sprite.frame = clampi(frame_index, 0, sprite.hframes - 1)
