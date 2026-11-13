extends "res://scripts/enemies/boss_stage.gd"
## 织血母皇。产卵、铺网，卵巢被清掉以后改成高机动近身，不再回到产卵阶段。
## 动画只读战斗状态：召唤/产卵/铺网的生成时点仍由 _pending_timer 0.25s 保证，
## 动画层只做表现，不引入第二个计时源。幼虫用现成的蝙蝠，数量有上限。

const EGG_CAP := 3
const WEB_CAP := 3
const LARVA_CAP := 3
const LarvaScene = preload("res://scenes/enemies/blood_larva.tscn")
## 6 帧动作的接触帧（第 3~4 帧）：动作第 0 帧只定种类，0.25s 后才真正落地
const CONTACT_DELAY := 0.25

const AssetSlots = preload("res://scripts/core/asset_slots.gd")
## 破卵暴露的变身表现时长；期间速度强制为零，不改动仇恨/伤害逻辑
const PHASE_VISUAL := 0.6
## 动作表现时长：_pending_timer 触发后再播这么久才回落到移动/待机。
## 只驱动画面帧推进，绝不参与生成/伤害计时（那时序归 CONTACT_DELAY 独占）。
const ACTION_VISUAL := 0.5
const DEATH_VISUAL := 0.60

var exposed: bool = false
var _animation_textures: Dictionary = {}
var _fallback_texture: Texture2D
var _animation_state: String = ""
var _animation_elapsed: float = 0.0
## -1.0 表示未在变身表现中；_expose() 置 0.0 起播 phase_change
var _phase_visual_elapsed: float = -1.0
## 最近一次已触发的动作种类及其剩余表现时间，让动作画面撑到可见结束
var _last_action: String = ""
var _action_visual_remaining: float = 0.0
var eggs_laid: int = 0
var _eggs: Array = []
var _larvae: Array = []
var _action_timer: float = 1.1
var _pending_kind: String = ""
var _pending_timer: float = -1.0

func _ready() -> void:
	boss_title = "织血母皇"
	asset_id = "blood_matriarch"
	boss_tier = 2
	move_speed = 62.0
	base_contact_damage = 12.0
	sprite_tint = Color(0.78, 0.22, 0.42)
	_boot_boss()

func _get_enemy_type() -> String:
	return "blood_matriarch"

func lay_egg() -> Node:
	if exposed or _living_eggs() >= EGG_CAP:
		return null
	var egg := preload("res://scripts/enemies/nest_egg.gd").new()
	egg.owner_boss = self
	var parent := get_parent()
	if parent == null:
		return null
	parent.add_child(egg)
	egg.global_position = global_position + Vector2(randf_range(-70, 70), randf_range(-40, 50))
	_eggs.append(egg)
	eggs_laid += 1
	return egg

func egg_destroyed(egg: Node) -> void:
	_eggs.erase(egg)
	if eggs_laid > 0 and _living_eggs() == 0:
		_expose()

func summon_larva() -> Node:
	if exposed or _living_larvae() >= LARVA_CAP:
		return null
	if get_parent() == null:
		return null
	var larva = LarvaScene.instantiate()
	larva.queen = self
	get_parent().add_child(larva)
	larva.global_position = global_position + Vector2(randf_range(-70, 70), randf_range(-40, 50))
	_larvae.append(larva)
	linked_nodes.append(larva)  # 母皇销毁时连带清理
	# 自然死亡钩子：enemy_base._die 发 enemy_died，这里做注销簿记；
	# 被直接 free 的幼虫由 _living_larvae 的 is_instance_valid 兜底。
	larva.connect("enemy_died", larva_destroyed)
	return larva

func _living_larvae() -> int:
	var count := 0
	for larva in _larvae:
		if is_instance_valid(larva) and larva.get("is_dead") != true:
			count += 1
	return count

func larva_destroyed(larva: Node) -> void:
	_larvae.erase(larva)
	linked_nodes.erase(larva)

func _expose() -> void:
	if exposed:
		return
	exposed = true
	move_speed = 120.0
	base_contact_damage = 18.0
	# 变身表现即刻起播；期间 _physics_process 强制速度为零
	_phase_visual_elapsed = 0.0
	_tick_sprite(0.0)
	boss_phase_changed.emit(1)

func _in_phase_visual() -> bool:
	return _phase_visual_elapsed >= 0.0 and _phase_visual_elapsed < PHASE_VISUAL

func _living_eggs() -> int:
	var count := 0
	for egg in _eggs:
		if is_instance_valid(egg) and egg.get("is_dead") != true:
			count += 1
	return count

func drop_web() -> Node:
	if _web_count() >= WEB_CAP:
		return null
	var web := preload("res://scripts/enemies/web_patch.gd").new()
	var parent := get_parent()
	if parent == null:
		return null
	parent.add_child(web)
	web.global_position = global_position + Vector2(randf_range(-50, 50), 24)
	return web

func _web_count() -> int:
	var count := 0
	var script = preload("res://scripts/enemies/web_patch.gd")
	for node in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(node) and node.get_script() == script:
			count += 1
	return count

func _melee_strike() -> void:
	# 沿用血铠领主 _strike 的判定口径：96px / 0.7rad / 18 伤害。
	# 先把画面钉到接触帧 4，再回调玩家扣血；伤害时点仍归 _pending_timer 管。
	_show_animation("melee")
	if not using_placeholder:
		_set_animation_frame(4)
	var forward := (player.global_position - global_position).normalized()
	for enemy in get_tree().get_nodes_in_group("player"):
		if not (enemy is Node2D):
			continue
		var offset: Vector2 = (enemy as Node2D).global_position - global_position
		if offset.length() > 96.0 or absf(forward.angle_to(offset)) > 0.7:
			continue
		if enemy.has_method("take_damage"):
			enemy.take_damage(18.0)

func _play_death_visual() -> void:
	# 同血铠领主：条带死亡演出 0.6s 后 queue_free（<0.8s 自回收契约）。
	# boss_stage._die 不会自毁，这里必须自己 free，幼虫才会经 linked_nodes 连带清理。
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

func _load_sprite_texture() -> void:
	# 包括缺图结果一起缓存；状态 tick 不做路径检查或 load。
	_animation_textures.clear()
	for state in AssetSlots.BOSSES["blood_matriarch"]["states"]:
		var texture := AssetSlots.boss_texture("blood_matriarch", state)
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
	if _in_phase_visual():
		return "phase_change"
	if _pending_kind != "" or _action_visual_remaining > 0.0:
		var kind := _pending_kind if _pending_kind != "" else _last_action
		match kind:
			"summon":
				return "summon"
			"egg":
				return "lay_egg"
			"web":
				return "web_cast"
			"melee":
				return "melee"
	if velocity.length_squared() > 1.0:
		return "move"
	return "idle"

func _tick_sprite(delta: float) -> void:
	if sprite == null or is_dead:
		return
	if _phase_visual_elapsed >= 0.0:
		_phase_visual_elapsed += delta
	if _action_visual_remaining > 0.0:
		_action_visual_remaining = maxf(_action_visual_remaining - delta, 0.0)
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
		"phase_change":
			_set_animation_frame(int(_phase_visual_elapsed / PHASE_VISUAL * 6.0))
		"lay_egg", "summon", "web_cast":
			_set_animation_frame(clampi(int(_animation_elapsed / ACTION_VISUAL * 6.0), 0, 5))
		"melee":
			if _action_visual_remaining > 0.0:
				# 已结算：接触帧 4 起手，随剩余表现时间推进到收招帧 5
				_set_animation_frame(4 + int((1.0 - _action_visual_remaining / ACTION_VISUAL) * 2.0))
			else:
				# 前摇：0.25s 内从 0 推到接触帧之前
				_set_animation_frame(clampi(int(_animation_elapsed / CONTACT_DELAY * 4.0), 0, 3))
		_:
			_set_animation_frame(int(_animation_elapsed * 8.0) % 6)

func _set_animation_frame(frame_index: int) -> void:
	if sprite != null:
		sprite.frame = clampi(frame_index, 0, sprite.hframes - 1)

func _physics_process(delta: float) -> void:
	if is_dead or intro_invulnerable or player == null or not is_instance_valid(player):
		return
	# 延迟生成：动作第 0 帧只定种类，接触帧（0.25s 后）才真正召唤/产卵/铺网/挥击
	if _pending_timer >= 0.0:
		_pending_timer -= delta
		if _pending_timer < 0.0:
			var fired := _pending_kind
			match fired:
				"summon": summon_larva()
				"egg": lay_egg()
				"web": drop_web()
				"melee": _melee_strike()
			# 动作画面要撑到接触之后可见的时长；只影响表现帧，不影响生成时点
			_last_action = fired
			_action_visual_remaining = ACTION_VISUAL
			_pending_kind = ""
	var to_player := player.global_position - global_position
	if _in_phase_visual():
		# 变身表现期间定住身体；表现结束回到原本的追击/拉开逻辑
		velocity = Vector2.ZERO
	else:
		var speed := move_speed * (1.35 if exposed else 0.7)
		if exposed or to_player.length() > 150.0:
			velocity = to_player.normalized() * speed
		else:
			velocity = (-to_player.normalized()) * speed * 0.8
	move_and_slide()
	_action_timer -= delta
	if _action_timer > 0.0:
		_tick_sprite(0.0)
		return
	_action_timer = 2.4
	if exposed:
		# 暴露后不再召唤/产卵/铺网，贴近（<=100px）就挥击
		if to_player.length() <= 100.0:
			_pending_kind = "melee"
			_pending_timer = CONTACT_DELAY
		_tick_sprite(0.0)
		return
	if _living_larvae() < LARVA_CAP:
		_pending_kind = "summon"
	elif _living_eggs() < EGG_CAP and eggs_laid < EGG_CAP + 1:
		_pending_kind = "egg"
	else:
		_pending_kind = "web"
	_pending_timer = CONTACT_DELAY
	_tick_sprite(0.0)
