extends Area2D
## 经验宝石（经验点）脚本
##
## 敌人死亡后掉落，被玩家吸附拾取。
##
## 两级可读性处理（用户反馈"经验点太小看不清"）：
##   1. 不再用 6x6 白方块，改成程序化菱形宝石 + 加色光晕，按 XP 值分三档尺寸/颜色；
##   2. 30px 内的同类掉落会合并成一枚更大的宝石——同屏不再是几十个看不清的小点，
##      而是一眼看得出"值多少"的三档颜色，节点数量也跟着降下来。
##
## 注意对象池：`_ready` 只在首次实例化时跑，池里复用不会重跑。
## 所以"每次上场都要做"的事（合并、刷新档位、掉落弹跳）必须挂在 `_enter_tree`。


@export var xp_value: int = 2
@export var attraction_speed: float = 320.0
@export var attraction_range: float = 88.0

## 合并半径：这段距离内的经验宝石并成一枚，避免"一地看不清的小点"
const MERGE_RADIUS: float = 30.0
## 吸附到这个距离就拾取
const PICKUP_DISTANCE: float = 16.0

var is_attracted: bool = false
var player: Node2D = null

var _pulse: Tween = null
var _base_scale: Vector2 = Vector2.ONE

func _enter_tree() -> void:
	add_to_group("xp_gems")
	# 先合并（可能改变 xp_value 与档位），再刷新视觉
	_merge_nearby()
	_refresh_visual()
	_play_drop_animation()

func _ready() -> void:
	add_to_group("xp_gems")
	_refresh_visual()

func _setup_gem() -> void:
	## 保留给外部（敌人掉落时）调用；真正的动画/合并走 _enter_tree，
	## 因为节点入树前 create_tween() 拿不到 SceneTree。
	add_to_group("xp_gems")
	_refresh_visual()

func reset_for_pool() -> void:
	## 归还对象池前重置状态
	_kill_pulse()
	is_attracted = false
	player = null
	scale = Vector2.ONE
	modulate = Color.WHITE
	xp_value = 0

# ==================== 视觉 ====================

## 按 XP 值分三档：绿（小怪）/ 蓝（中怪）/ 金（精英与 Boss）
## 尺寸在真机截图里校对过：12px 在深色地板 + 怪堆里仍偏小，统一上调一档
func _tier_for(value: int) -> Dictionary:
	if value >= 20:
		return {"size": 26.0, "color": Color(1.0, 0.78, 0.30), "pulse": 0.16}
	elif value >= 8:
		return {"size": 19.0, "color": Color(0.45, 0.82, 1.0), "pulse": 0.12}
	return {"size": 14.0, "color": Color(0.52, 1.0, 0.62), "pulse": 0.09}

func _refresh_visual() -> void:
	var spr := get_node_or_null("Sprite2D") as Sprite2D
	if spr == null:
		return
	var tier := _tier_for(xp_value)
	ProjectileVisuals.style_gem(spr, tier["color"], float(tier["size"]))
	_base_scale = spr.scale
	_start_pulse(spr, float(tier["pulse"]))

func _start_pulse(spr: Sprite2D, amount: float) -> void:
	## 轻微呼吸，让宝石在怪堆里"活着"；幅度刻意小，避免几十个同时闪成迪厅
	_kill_pulse()
	if not is_inside_tree():
		return
	_pulse = create_tween().set_loops()
	_pulse.tween_property(spr, "scale", _base_scale * (1.0 + amount), 0.55) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse.tween_property(spr, "scale", _base_scale, 0.55) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _kill_pulse() -> void:
	if _pulse != null and _pulse.is_valid():
		_pulse.kill()
	_pulse = null
	var spr := get_node_or_null("Sprite2D") as Sprite2D
	if spr != null and _base_scale != Vector2.ZERO:
		spr.scale = _base_scale

func _play_drop_animation() -> void:
	## 掉落弹跳：从死亡点弹出去一点，让玩家注意到"掉东西了"
	if not is_inside_tree():
		return
	var random_offset := Vector2(randf_range(-20.0, 20.0), randf_range(-20.0, 20.0))
	var tween := create_tween()
	tween.tween_property(self, "position", position + random_offset, 0.3) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BOUNCE)

# ==================== 合并 ====================

func _merge_nearby() -> void:
	## 把附近还没被吸走的小宝石并进自己，值相加、档位跟着升。
	## 这既是可读性修复（少一堆小点），也顺手降低了节点数量。
	if xp_value <= 0 or not is_inside_tree():
		return
	var absorbed: int = 0
	for other in get_tree().get_nodes_in_group("xp_gems"):
		if other == self or not is_instance_valid(other):
			continue
		if not (other is Node2D):
			continue
		if other.has_meta("_in_pool") and other.get_meta("_in_pool"):
			continue
		var raw_value = other.get("xp_value")
		var other_value: int = int(raw_value) if raw_value != null else 0
		if other_value <= 0:
			continue
		# 已经被吸走的别抢，否则玩家眼看着宝石在半空消失
		if bool(other.get("is_attracted")):
			continue
		var other_pos: Vector2 = (other as Node2D).global_position
		if other_pos.distance_to(global_position) > MERGE_RADIUS:
			continue
		absorbed += other_value
		other.set("xp_value", 0)
		if other.has_method("_kill_pulse"):
			other.call("_kill_pulse")
		ObjectPool.release(other)
	if absorbed > 0:
		xp_value += absorbed
		_refresh_visual()

# ==================== 吸附与拾取 ====================

func _physics_process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		# 查找玩家
		var players := get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player = players[0]
		return

	var distance := global_position.distance_to(player.global_position)

	# 进入吸附范围后自动靠近玩家（戒指/磁铁会扩大这个范围）
	var range_now := attraction_range
	if "pickup_range" in player:
		range_now += float(player.pickup_range)
	if distance < range_now:
		is_attracted = true

	if is_attracted:
		var direction := (player.global_position - global_position).normalized()
		position += direction * attraction_speed * delta
		# 足够近时拾取
		if distance < PICKUP_DISTANCE:
			_collect()

func _collect() -> void:
	# 通知玩家获得经验
	if player != null and player.has_method("gain_xp"):
		player.gain_xp(xp_value)
	# 拾取 VFX
	var vfx := get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.spawn_xp_particles(global_position)
	# 播放拾取音效
	var audio_lib := AudioLib
	AudioManager.play_sfx(audio_lib.get_sound("pickup_xp"))
	# 拾取特效（必须先停掉呼吸 tween，否则两个 tween 抢同一个 scale 属性）
	_kill_pulse()
	set_physics_process(false)
	xp_value = 0
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, 0.1)
	tween.tween_callback(func(): ObjectPool.release(self))
