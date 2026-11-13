extends "res://scripts/enemies/enemy_base.gd"
## 炼金巨像。和亲王互相改招：亲王先倒，巨像改砸地；巨像先倒，亲王改成贴脸。

const AssetSlots = preload("res://scripts/core/asset_slots.gd")
## 砸地表现时长：与砸地判定同帧起播，只驱动画面帧推进，不参与判定/冷却计时。
const SLAM_VISUAL := 0.6
## 狂怒表现时长：enrage 同帧起播，只驱动画面帧。
const ENRAGE_VISUAL := 0.6
## 死亡条带 0→6 帧的推进时长（<0.8s 自回收契约）
const DEATH_VISUAL := 0.60
## 占位回退的染色：沿用 furnace_golem  borrowed 图的绿铜色
const PLACEHOLDER_TINT := Color(0.25, 0.55, 0.32)

var prince: Node = null
var enraged: bool = false
var _timer: float = 1.5

var _animation_textures: Dictionary = {}
var _fallback_texture: Texture2D
var _animation_state: String = ""
var _animation_elapsed: float = 0.0
## 砸地表现剩余时长；>0 期间 _animation_for_state 选 slam，只在表现层递减
var _slam_visual_remaining: float = 0.0
## 狂怒表现剩余时长；>0 期间选 enrage
var _enrage_visual_remaining: float = 0.0

func _ready() -> void:
	base_hp = 220.0
	move_speed = 36.0
	base_contact_damage = 18.0
	xp_value = 20
	super._ready()
	add_to_group("boss_add")

func _load_sprite_texture() -> void:
	# 照搬守望者：5 状态表全量缓存（含缺图结果），状态 tick 不做路径检查或 load；
	# 缺表时回退 furnace_golem idle + 绿铜染色（占位回退保持可用）。
	_animation_textures.clear()
	for state in AssetSlots.BOSSES["alchemist_colossus"]["states"]:
		var texture := AssetSlots.boss_texture("alchemist_colossus", state)
		if texture != null and texture.get_size() == Vector2(768, 128):
			_animation_textures[state] = texture
	_fallback_texture = null
	if TextureManager.instance != null:
		_fallback_texture = TextureManager.instance.get_enemy_texture("furnace_golem", "idle")
	if _fallback_texture == null:
		var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
		image.fill(Color.WHITE)
		_fallback_texture = ImageTexture.create_from_image(image)
	_animation_state = ""
	_show_animation("idle")

func _get_enemy_type() -> String:
	return "alchemist_colossus"

func enrage() -> void:
	enraged = true
	move_speed = 70.0
	_timer = 0.4
	# 表现接线：enrage 条带同帧起播；只驱动画面帧，判定/冷却一行不动
	_enrage_visual_remaining = ENRAGE_VISUAL
	_tick_sprite(0.0)

func _physics_process(delta: float) -> void:
	if is_dead or player == null:
		return
	var to_player := player.global_position - global_position
	velocity = to_player.normalized() * move_speed
	move_and_slide()
	_timer -= delta
	if not enraged or _timer > 0.0:
		return
	_timer = 1.6
	# 表现接线：slam 条带与砸地判定同帧起播（第 0 帧）；判定计时一行不动
	_slam_visual_remaining = SLAM_VISUAL
	_show_animation("slam")
	if to_player.length() < 90.0 and player.has_method("take_damage"):
		player.take_damage(16.0)
	_tick_sprite(0.0)

func _die() -> void:
	if is_dead:
		return
	is_dead = true
	# main 的 boss_defeated 会同步清空 enemies 组；先退组 + 关碰撞，
	# 保住死亡演出不被立刻清场（巨像无人代清，自救是唯一回收路径）。
	remove_from_group("enemies")
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	if _contact_area != null:
		_contact_area.set_deferred("monitoring", false)
		_contact_area.set_deferred("monitorable", false)
	if prince != null and is_instance_valid(prince) and prince.has_method("colossus_fell"):
		prince.colossus_fell()
	enemy_died.emit(self)
	_play_death_visual()

func _play_death_visual() -> void:
	# 真实 death 条带 tween_method 推 0→6 帧（0.6s）后 queue_free（<0.8s 自回收契约）。
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

func _show_animation(state: String) -> void:
	if sprite == null or _animation_state == state:
		return
	_animation_state = state
	_animation_elapsed = 0.0
	var texture: Texture2D = _animation_textures.get(state)
	using_placeholder = texture == null
	placeholder_tint = PLACEHOLDER_TINT
	sprite.texture = _fallback_texture if using_placeholder else texture
	sprite.modulate = _rest_modulate()
	_present_sprite(96.0)

func _animation_for_state() -> String:
	if is_dead:
		return "death"
	if _slam_visual_remaining > 0.0:
		return "slam"
	if _enrage_visual_remaining > 0.0:
		return "enrage"
	if velocity.length_squared() > 1.0:
		return "move"
	return "idle"

func _tick_sprite(delta: float) -> void:
	if sprite == null or is_dead:
		return
	if _slam_visual_remaining > 0.0:
		_slam_visual_remaining = maxf(_slam_visual_remaining - delta, 0.0)
	if _enrage_visual_remaining > 0.0:
		_enrage_visual_remaining = maxf(_enrage_visual_remaining - delta, 0.0)
	_animation_elapsed += delta
	_show_animation(_animation_for_state())
	# 朝向沿用 velocity flip_h 镜像
	if absf(velocity.x) > 0.001:
		sprite.flip_h = velocity.x < 0.0
	sprite.rotation = 0.0
	if using_placeholder:
		super._tick_sprite(delta)
		return
	sprite.position = _sprite_rest_pos
	match _animation_state:
		"slam":
			_set_animation_frame(clampi(int(_animation_elapsed / SLAM_VISUAL * 6.0), 0, 5))
		"enrage":
			_set_animation_frame(clampi(int(_animation_elapsed / ENRAGE_VISUAL * 6.0), 0, 5))
		_:
			_set_animation_frame(int(_animation_elapsed * 8.0) % 6)

func _set_animation_frame(frame_index: int) -> void:
	if sprite != null:
		sprite.frame = clampi(frame_index, 0, sprite.hframes - 1)
