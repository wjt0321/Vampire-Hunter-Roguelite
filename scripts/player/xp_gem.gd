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
## 基础吸附半径。原 88 太小：玩家跑过一堆宝石时全靠"擦身而过"才吸得到，
## 稍微偏一点就留在原地，体感就是"经验点有时候捡不到"。
## 120 大约是一个身位，走位时能自然带上一片。
@export var attraction_range: float = 120.0

## 合并半径：这段距离内的经验宝石并成一枚，避免"一地看不清的小点"
const MERGE_RADIUS: float = 30.0
## 吸附到这个距离就拾取
const PICKUP_DISTANCE: float = 16.0
## 被强制吸走时（波次结束结算）的速度，要明显快过玩家跑速
const FORCED_ATTRACT_SPEED: float = 1600.0

var is_attracted: bool = false
var player: Node2D = null

var _pulse: Tween = null
var _base_scale: Vector2 = Vector2.ONE

func _enter_tree() -> void:
	add_to_group("xp_gems")
	# ⚠ 必须显式重新打开物理帧。
	# `_collect()` 里为了停止吸附会 `set_physics_process(false)`，而对象池复用时
	# 节点不会重跑 `_ready`，`ObjectPool.acquire()` 也只恢复 visible/process_mode/monitoring。
	# 结果：凡是"被捡过一次"的宝石回到池里就永久僵死——躺在地上不动、也永远不会被捡，
	# 这就是玩家反馈的"经验点有时候捡不到"（取决于这一枚是不是回收来的）。
	set_physics_process(true)
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
	# magnetize() 会把速度顶到 1600，不复位的话下一枚掉落的宝石会像炮弹一样飞过来
	attraction_speed = 320.0

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

	# 贴身就直接捡：不再依赖 is_attracted。
	# 旧版只有"先被吸附、再走到 16px 内"才拾取，一旦 is_attracted 没被置上
	# （玩家刚好从远处擦过、或宝石是从池里复用来的），宝石就在脚边也不响应。
	if distance < PICKUP_DISTANCE:
		_collect()
		return

	# 进入吸附范围后自动靠近玩家（磁力戒指/拾取范围升级会扩大这个范围）
	# ⚠ 玩家字段名是 pickup_range_bonus。旧代码写的是 pickup_range（字段不存在），
	# 于是磁力戒指与"拾取范围 +30"全部是空转——这也是"感觉捡不到"的主因之一。
	var range_now := attraction_range
	if "pickup_range_bonus" in player:
		range_now += float(player.pickup_range_bonus)
	elif "pickup_range" in player:
		range_now += float(player.pickup_range)
	if distance < range_now:
		is_attracted = true

	if is_attracted:
		var direction := (player.global_position - global_position).normalized()
		position += direction * _current_speed() * delta
		# 用移动后的距离判定：用移动前的 distance 会整整慢一帧，
		# 高速吸引时宝石会在玩家身边"擦过去"再折返，观感像卡了一下
		if global_position.distance_to(player.global_position) < PICKUP_DISTANCE:
			_collect()

func _current_speed() -> float:
	## 吸引速度必须严格快过玩家跑速，否则玩家一边跑宝石一边追，
	## 相对速度接近 0，宝石会一路跟着却永远吃不到（"捡不到"的另一种形态）。
	if player == null or not is_instance_valid(player):
		return attraction_speed
	var pv := Vector2.ZERO
	if player.has_method("get_velocity"):
		pv = player.get_velocity()
	elif "velocity" in player:
		pv = player.velocity
	var want: float = pv.length() * 1.6 + 120.0
	return maxf(attraction_speed, want)

func magnetize() -> void:
	## 波次结束时把地上剩下的宝石一次性吸过来。
	## 不走 auto_collect() 的直接入账：玩家需要看到"经验飞过来了"，
	## 而不是打完一波地上东西凭空消失。
	if xp_value <= 0:
		return
	is_attracted = true
	attraction_speed = maxf(attraction_speed, FORCED_ATTRACT_SPEED)
	set_physics_process(true)

## 房间结束时的自动结算：把没捡的宝石直接算进经验。
## 旧版是 `queue_free()` 直接清掉——玩家打了一屋子怪、最后 2 秒掉的宝石
## 在换房那一瞬间凭空消失，这也是"经验点有时候捡不到"的一半来源。
func auto_collect() -> void:
	if xp_value <= 0:
		return
	if player == null or not is_instance_valid(player):
		var players := get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player = players[0]
	if player != null and is_instance_valid(player) and player.has_method("gain_xp"):
		player.gain_xp(xp_value)
	xp_value = 0
	_kill_pulse()
	set_physics_process(false)
	ObjectPool.release(self)

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
