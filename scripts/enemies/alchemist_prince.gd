extends "res://scripts/enemies/boss_stage.gd"
## 炼金亲王。和巨像是两个目标。先倒下一个，另一个会换一套招，而不是只加快。

const AssetSlots = preload("res://scripts/core/asset_slots.gd")
## 掷瓶表现时长：与 _toss 同帧起播，只驱动画面帧推进，不参与掷瓶/冷却计时。
const CAST_VISUAL := 0.6
## 换位表现时长：colossus_fell 与 solo 切换同帧起播，只驱动画面帧。
const SOLO_SHIFT_VISUAL := 0.6
## 死亡条带 0→6 帧的推进时长（<0.8s 自回收契约）
const DEATH_VISUAL := 0.60

var colossus: Node = null
var _mode: String = "pair"
var _timer: float = 1.2

var _animation_textures: Dictionary = {}
var _fallback_texture: Texture2D
var _animation_state: String = ""
var _animation_elapsed: float = 0.0
## 掷瓶表现剩余时长；>0 期间 _animation_for_state 选 cast，只在表现层递减
var _cast_visual_remaining: float = 0.0
## 换位表现剩余时长；>0 期间选 solo_shift
var _solo_shift_visual_remaining: float = 0.0

# 死亡演出播完标志：条带（或占位淡出）播完置 true。
var _death_visual_done: bool = false
# _finish_fight 已发生标志：boss_defeated 必须先于亲王 queue_free 发出。
var _finish_fight_called: bool = false

func _ready() -> void:
	boss_title = "炼金亲王"
	asset_id = "alchemist_prince"
	boss_tier = 4
	move_speed = 78.0
	base_contact_damage = 12.0
	sprite_tint = Color(0.4, 0.78, 0.48)
	_boot_boss()
	_spawn_colossus()

func _get_enemy_type() -> String:
	return "alchemist_prince"

func _spawn_colossus() -> void:
	var parent := get_parent()
	if parent == null:
		return
	colossus = preload("res://scenes/enemies/alchemist_colossus.tscn").instantiate()
	colossus.prince = self
	parent.add_child(colossus)
	colossus.global_position = global_position + Vector2(140, 20)
	linked_nodes.append(colossus)

func colossus_fell() -> void:
	colossus = null
	if is_dead:
		_finish_fight()
		# 留尸路线的最终回收点：此时死亡条带早已播完（0.4s < 等待时长），
		# 双标志俱备 → 立即自回收，不再重播演出。
		_try_self_recycle()
		return
	_mode = "solo_prince"
	# 表现接线：换位条带与 solo 切换同帧起播；只驱动画面帧，判定/冷却一行不动
	_solo_shift_visual_remaining = SOLO_SHIFT_VISUAL
	_tick_sprite(0.0)
	boss_phase_changed.emit(1)

func _physics_process(delta: float) -> void:
	if is_dead or intro_invulnerable or player == null:
		return
	var to_player := player.global_position - global_position
	velocity = to_player.normalized() * (140.0 if _mode == "solo_prince" else move_speed)
	move_and_slide()
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = 2.2 if _mode == "pair" else 1.3
	_toss(player.global_position)

func _toss(at: Vector2) -> void:
	# 表现接线：cast 条带与药瓶生成同帧起播；生成时点与冷却一行不动
	_cast_visual_remaining = CAST_VISUAL
	var puddle = preload("res://scripts/map/potion_puddle.gd").new()
	puddle.damage = 10.0
	puddle.global_position = at
	var parent := get_parent()
	if parent:
		parent.add_child(puddle)
	_tick_sprite(0.0)

func _die() -> void:
	if is_dead:
		return
	is_dead = true
	# main 的 boss_defeated 会同步清空 enemies 组；先退组 + 关碰撞，
	# 保住死亡演出不被立刻清场（退组后 main 清场扫不到，回收责任移到这里）。
	remove_from_group("enemies")
	_set_boss_collisions(false)
	if _contact_area != null:
		_contact_area.set_deferred("monitoring", false)
		_contact_area.set_deferred("monitorable", false)
	set_physics_process(false)
	if colossus != null and is_instance_valid(colossus) and colossus.get("is_dead") != true:
		# 留尸契约：巨像存活时亲王不 queue_free，照常 enrage，契约一行不动。
		colossus.call("enrage")
		boss_phase_changed.emit(2)
		_play_death_visual()
		return
	_finish_fight()
	_play_death_visual()

func _play_death_visual() -> void:
	# 真实 death 条带 tween_method 推 0→6 帧（0.6s）后收口（<0.8s 自回收契约）；
	# 收口仍统一走 _on_death_visual_finished → 双标志 _try_self_recycle，一行不动。
	# 绑定本节点的 tween 随暂停冻结、随场景销毁取消；不依赖死后停掉的 _process。
	# 无精灵或无真实表时退回占位淡出兜底。
	if sprite == null:
		_on_death_visual_finished()
		return
	_show_animation("death")
	sprite.rotation = 0.0
	sprite.position = _sprite_rest_pos
	var tween := create_tween()
	if using_placeholder:
		tween.tween_property(sprite, "modulate:a", 0.0, 0.4)
	else:
		tween.tween_method(_advance_death_frame, 0.0, 6.0, DEATH_VISUAL)
	tween.tween_callback(_on_death_visual_finished)

func _advance_death_frame(progress: float) -> void:
	_set_animation_frame(int(progress))

func _on_death_visual_finished() -> void:
	visible = false
	_death_visual_done = true
	_try_self_recycle()

func _try_self_recycle() -> void:
	# 统一收口：演出播完且战斗已结算（_finish_fight 已发 boss_defeated）才自行回收。
	if _death_visual_done and _finish_fight_called:
		queue_free()

func _finish_fight() -> void:
	_finish_fight_called = true
	boss_defeated.emit()
	enemy_died.emit(self)

func _load_sprite_texture() -> void:
	# 照搬守望者：5 状态表全量缓存（含缺图结果），状态 tick 不做路径检查或 load。
	_animation_textures.clear()
	for state in AssetSlots.BOSSES["alchemist_prince"]["states"]:
		var texture := AssetSlots.boss_texture("alchemist_prince", state)
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
	if _cast_visual_remaining > 0.0:
		return "cast"
	if _solo_shift_visual_remaining > 0.0:
		return "solo_shift"
	if velocity.length_squared() > 1.0:
		return "move"
	return "idle"

func _tick_sprite(delta: float) -> void:
	if sprite == null or is_dead:
		return
	if _cast_visual_remaining > 0.0:
		_cast_visual_remaining = maxf(_cast_visual_remaining - delta, 0.0)
	if _solo_shift_visual_remaining > 0.0:
		_solo_shift_visual_remaining = maxf(_solo_shift_visual_remaining - delta, 0.0)
	_animation_elapsed += delta
	_show_animation(_animation_for_state())
	# 朝向沿用母皇/守望者的 velocity flip_h 镜像
	if absf(velocity.x) > 0.001:
		sprite.flip_h = velocity.x < 0.0
	sprite.rotation = 0.0
	if using_placeholder:
		super._tick_sprite(delta)
		return
	sprite.position = _sprite_rest_pos
	match _animation_state:
		"cast":
			_set_animation_frame(clampi(int(_animation_elapsed / CAST_VISUAL * 6.0), 0, 5))
		"solo_shift":
			_set_animation_frame(clampi(int(_animation_elapsed / SOLO_SHIFT_VISUAL * 6.0), 0, 5))
		_:
			_set_animation_frame(int(_animation_elapsed * 8.0) % 6)

func _set_animation_frame(frame_index: int) -> void:
	if sprite != null:
		sprite.frame = clampi(frame_index, 0, sprite.hframes - 1)
