extends Node
## 局内目标事件管理器（17.14）
##
## 战斗房里的小目标。为什么需要它：6~7 间房里只有 shop/treasure/rest/boss
## 有"进这间要干什么"，战斗房之间彼此无差别——玩家对房间的记忆是
## "又一间打怪的"，没有"这间有猎物/这间有箱子要守"的钩子。
##
## 两种事件，每层最多触发一次（触发过就不再判定，失败也不重来）：
##   hunt  深渊猎物：1.5 秒后刷一只双词缀强化精英，限时内击杀给奖励，
##         超时遁入黑暗。检验的是"边躲小怪边集火"的输出能力。
##   guard 受诅宝箱：房间中央刷上锁宝箱 + 一圈守卫，守卫全清开箱。
##         检验的是清场速度，且给了"要不要优先清守卫"的选择。
##
## 接线约定：main 在每次 _enter_next_room 开头调 cancel()（事件不跨房），
## 进 combat 房时调 on_combat_room_entered()，换层时调 on_floor_changed()。

signal event_started(kind: String)
signal event_finished(kind: String, success: bool)

const HuntDelay: float = 1.5       # 进房后多久刷猎物（给玩家半秒认清房间）
## 开场信息在事件行上停留多久（秒）。不留这一拍，守卫的
## "受 诅 宝 箱 · 守 卫 苏 醒" 会在 0.2 秒后被"守卫 ×5"顶掉，等于没显示。
const AnnounceHold: float = 1.2

var kind: String = ""              # "" = 本房无事件
var floor_fired: int = -1          # 已触发过事件的层号（一层一次）
var combat_room_count: int = 0     # 本层已进入的战斗房计数
## 最近一次 on_floor_changed 收到的层号（-1 = 还没换过层）。
## main 用它确认首层 floor_started 确实走到了事件管理器。
var last_floor_index: int = -1

var wave_manager: Node = null
var player: Node = null
var hud: Node = null

var _hunt_enemy: Node = null
var _hunt_timer: float = 0.0
var _hunt_delay: float = 0.0
var _guards_left: int = 0
var _chest: Node2D = null
var _event_nodes: Array = []
var _nest_core: Node = null
var _nest_time: float = 0.0
var _nest_spawn: float = 0.0
var _nest_adds: int = 0
var _flee_enemy: Node = null
var _flee_dir: Vector2 = Vector2.RIGHT
var _seals: Array = []
var _seal_time: Array = []
var _bounty_enemy: Node = null
var _bounty_mark: Vector2 = Vector2.ZERO
var _bounty_accepted: bool = false
## HUD 文本降频：每 0.2 秒写一次，别每帧拼字符串
var _hud_tick: float = 0.0
## 开场信息占位倒计时（秒）：> 0 时状态刷新不覆盖事件行
var _announce_timer: float = 0.0

func setup(wm: Node, player_node: Node, hud_node: Node) -> void:
	wave_manager = wm
	player = player_node
	hud = hud_node

func on_floor_changed(floor_index: int) -> void:
	## 换层重置"一层一次"的标记；进行中的事件随 cancel() 结束。
	## 这里自己 cancel：事件不跨层，不能指望换房流程恰好先 cancel 过
	## （Boss 房直进、换层路径都会绕开 _enter_next_room 的常规清理）。
	cancel()
	last_floor_index = floor_index
	combat_room_count = 0
	if floor_fired != floor_index:
		floor_fired = -1

func on_combat_room_entered(floor_index: int) -> bool:
	## 进战斗房时判定是否触发。返回 true = 本房有事件。
	## 注意：必须在 wave_manager.start() 之后调用（事件敌人要挂到当前场景）。
	cancel()
	combat_room_count += 1
	if not GameConfig.ROOM_EVENT_ENABLED:
		return false
	if floor_fired == floor_index:
		return false
	if combat_room_count < GameConfig.ROOM_EVENT_MIN_COMBAT_ROOM:
		return false
	var chance: float = float(GameConfig.ROOM_EVENT_CHANCE_BY_FLOOR[
		clampi(floor_index, 1, GameConfig.ROOM_EVENT_CHANCE_BY_FLOOR.size()) - 1])
	if randf() >= chance:
		return false
	floor_fired = floor_index
	match _roll_event_kind():
		"guard":
			_start_guard()
		"nest":
			_start_nest()
		"flee":
			_start_flee()
		"seals":
			_start_seals()
		"bounty":
			_start_bounty()
		_:
			_start_hunt()
	return true

func _roll_event_kind() -> String:
	var roll := randf()
	var weights: Array = [
		["hunt", 0.28],
		["guard", 0.18],
		["nest", 0.14],
		["flee", 0.14],
		["seals", 0.13],
		["bounty", 0.13],
	]
	var acc := 0.0
	for row in weights:
		acc += float(row[1])
		if roll < acc:
			return String(row[0])
	return "hunt"

func _start_hunt() -> void:
	kind = "hunt"
	_hunt_delay = HuntDelay
	_hunt_timer = GameConfig.ROOM_EVENT_HUNT_TIME
	_notify("深 渊 猎 物 现 身")
	event_started.emit("hunt")
	print("🏹 局内事件：深渊猎物（限时 %.0f 秒）" % GameConfig.ROOM_EVENT_HUNT_TIME)

func _start_guard() -> void:
	kind = "guard"
	_notify("受 诅 宝 箱 · 守 卫 苏 醒")
	event_started.emit("guard")
	print("🎁 局内事件：受诅宝箱（守卫 %d 只）" % GameConfig.ROOM_EVENT_GUARD_COUNT)
	_spawn_chest()
	_spawn_guards()

func _process(delta: float) -> void:
	if kind.is_empty():
		return
	# 开场信息优先占住事件行：状态刷新每 0.2 秒一次，不留这一拍的话
	# "守卫苏醒"会被"守卫 ×5"立刻顶掉
	if _announce_timer > 0.0:
		_announce_timer -= delta
	_hud_tick += delta
	var hud_dirty := _hud_tick >= 0.2 and _announce_timer <= 0.0
	if hud_dirty:
		_hud_tick = 0.0

	match kind:
		"hunt":
			_process_hunt(delta, hud_dirty)
		"guard":
			_process_guard(hud_dirty)
		"nest":
			_process_nest(delta, hud_dirty)
		"flee":
			_process_flee(delta, hud_dirty)
		"seals":
			_process_seals(delta, hud_dirty)
		"bounty":
			_process_bounty(hud_dirty)

func _process_hunt(delta: float, hud_dirty: bool) -> void:
	if _hunt_enemy == null or not is_instance_valid(_hunt_enemy):
		if _hunt_delay > 0.0:
			# 还没刷出来
			_hunt_delay -= delta
			if _hunt_delay <= 0.0:
				_spawn_hunt_enemy()
			return
		# 已出场却失效（换房清场 / 对象池回收 / 被别的系统释放）：
		# 不能一直等一个不存在的敌人，否则事件永远停在 hunt、HUD 卡在倒计时
		_end(false, "猎物失踪")
		return
	# 敌人出场后才开始走倒计时（1.5 秒延迟不算在 20 秒里）
	_hunt_timer -= delta
	if hud_dirty:
		_set_hud("猎杀 %d 秒" % maxi(ceili(_hunt_timer), 0))
	if _hunt_timer <= 0.0:
		_hunt_escape()

func _process_guard(hud_dirty: bool) -> void:
	if hud_dirty and _guards_left > 0:
		_set_hud("守卫 ×%d" % _guards_left)

# ==================== 猎杀 ====================

func _spawn_hunt_enemy() -> void:
	if wave_manager == null or player == null or not is_instance_valid(player):
		_end(false, "猎物未现身")
		return
	# 类型从本层敌人池里挑（Boss 类型除外）——玩家已经知道怎么打它，
	# 新鲜感来自"双词缀 + 限时"而不是没见过的怪
	var pool: Array = []
	if "enemy_pool" in wave_manager and not wave_manager.enemy_pool.is_empty():
		pool = wave_manager.enemy_pool.duplicate()
	else:
		pool = ["vampire", "bat", "zombie", "skeleton_archer", "werewolf"]
	pool.erase("vampire_prince")
	if pool.is_empty():
		_end(false, "猎物未现身")
		return
	var enemy_type: String = String(pool.pick_random())

	# 双词缀：主词缀沿用逐层池（第 1 层只有急速，保持教学身份）；
	# 第二词缀从**完整合法池**排除主词缀后取——ROADMAP/GDD 的"双词缀"
	# 没有楼层例外，第 1 层猎物也必须是两个词缀。
	var allowed: Array = GameConfig.get_elite_affix_pool(
		int(wave_manager.floor_index) if "floor_index" in wave_manager else 1)
	var a1: String = EliteAffix.roll([], allowed)
	if a1.is_empty():
		# 配置里楼层池为空时退回完整池：宁可少一层教学，也不能出单词缀猎物
		a1 = EliteAffix.roll()
	var a2: String = EliteAffix.roll([a1])
	var affixes: Array = []
	if not a1.is_empty():
		affixes.append(a1)
	if not a2.is_empty():
		affixes.append(a2)

	# 位置：玩家 320~420px 外（看得见、但要走两步）
	var angle: float = randf() * TAU
	var radius: float = randf_range(320.0, 420.0)
	var pos: Vector2 = player.global_position + Vector2(cos(angle), sin(angle)) * radius
	var bounds: Rect2 = _room_bounds()
	pos.x = clampf(pos.x, bounds.position.x + 40.0, bounds.end.x - 40.0)
	pos.y = clampf(pos.y, bounds.position.y + 40.0, bounds.end.y - 40.0)

	_hunt_enemy = wave_manager.spawn_special_enemy(
		enemy_type, pos, affixes, 1.0, GameConfig.ROOM_EVENT_HUNT_HP_MULT)
	if _hunt_enemy == null:
		_end(false, "猎物未现身")
		return
	_hunt_enemy.enemy_died.connect(_on_hunt_killed)
	# 名字标识：头顶加一行字，别让玩家把猎物当成普通精英
	_tag_enemy(_hunt_enemy, "猎 物", Color(1.0, 0.42, 0.3))

func _on_hunt_killed(_enemy: Node) -> void:
	# 事件已结束（超时遁走 / cancel）后补发的死亡信号不能结算：
	# 淡出期间 DoT 打死、或换房后清场，都不该再给一次奖励。
	if kind != "hunt":
		return
	_reward(GameConfig.ROOM_EVENT_HUNT_SILVER, GameConfig.ROOM_EVENT_HUNT_XP,
		"猎物已诛 +%d 银" % GameConfig.ROOM_EVENT_HUNT_SILVER)
	_end(true, "猎物已诛")

func _hunt_escape() -> void:
	_disconnect_hunt_killed()
	if _hunt_enemy != null and is_instance_valid(_hunt_enemy):
		# 遁走动画：变透明 + 放大，然后消失。直接 queue_free 会像"凭空蒸发"
		var tw := create_tween()
		tw.tween_property(_hunt_enemy, "modulate:a", 0.0, 0.5)
		tw.tween_callback(_hunt_enemy.queue_free)
		_hunt_enemy.set_physics_process(false)
		if _hunt_enemy is CollisionObject2D:
			var shape := _hunt_enemy.get_node_or_null("CollisionShape2D")
			if shape:
				shape.set_deferred("disabled", true)
	if hud and hud.has_method("show_toast"):
		hud.show_toast("猎物遁入黑暗…")
	_end(false, "猎物逃走")

# ==================== 守卫 / 宝箱 ====================

func _spawn_chest() -> void:
	var bounds: Rect2 = _room_bounds()
	var center: Vector2 = bounds.get_center()
	var spawn_pos: Vector2 = center
	# 玩家站在房间中央时，宝箱不能刷在同一个点上：互相遮挡，也读不出"守卫圈"
	# 的中心在哪。沿远离玩家的方向推开，再夹回房间内。
	if player != null and is_instance_valid(player):
		var away: Vector2 = center - player.global_position
		if away.length() < 80.0:
			var dir: Vector2 = away.normalized() if away.length() > 0.01 else Vector2.RIGHT
			spawn_pos = center + dir * 110.0
			spawn_pos.x = clampf(spawn_pos.x, bounds.position.x + 40.0, bounds.end.x - 40.0)
			spawn_pos.y = clampf(spawn_pos.y, bounds.position.y + 40.0, bounds.end.y - 40.0)
	_chest = Node2D.new()
	_chest.set_script(preload("res://scripts/managers/cursed_chest.gd"))
	_chest.position = spawn_pos
	var scene := get_tree().current_scene
	if scene:
		scene.add_child(_chest)

func _spawn_guards() -> void:
	if wave_manager == null or _chest == null:
		_end(false, "宝箱未现身")
		return
	# 守卫类型：同样从本层池里挑，但不重复——一圈各不相同的怪读起来更像"护卫队"
	var pool: Array = []
	if "enemy_pool" in wave_manager and not wave_manager.enemy_pool.is_empty():
		pool = wave_manager.enemy_pool.duplicate()
	else:
		pool = ["vampire", "bat", "zombie", "skeleton_archer", "werewolf"]
	pool.erase("vampire_prince")
	_guards_left = 0
	var count: int = mini(GameConfig.ROOM_EVENT_GUARD_COUNT, pool.size() * 3)
	for i in range(count):
		var enemy_type: String = String(pool[i % pool.size()])
		var angle: float = TAU * float(i) / float(count) + randf() * 0.3
		var radius: float = 130.0 + randf() * 30.0
		var pos: Vector2 = _chest.position + Vector2(cos(angle), sin(angle)) * radius
		var bounds: Rect2 = _room_bounds()
		pos.x = clampf(pos.x, bounds.position.x + 40.0, bounds.end.x - 40.0)
		pos.y = clampf(pos.y, bounds.position.y + 40.0, bounds.end.y - 40.0)
		var guard: Node = wave_manager.spawn_special_enemy(
			enemy_type, pos, [], 1.0, GameConfig.ROOM_EVENT_GUARD_HP_MULT)
		if guard == null:
			continue
		guard.enemy_died.connect(_on_guard_died)
		guard.modulate = GameConfig.ROOM_EVENT_GUARD_COLOR
		_tag_enemy(guard, "守 卫", GameConfig.ROOM_EVENT_GUARD_COLOR)
		_guards_left += 1
	if _guards_left == 0:
		# 一只守卫都没刷出来：宝箱由 _end() 统一回收
		_end(false, "守卫未现身")

func _on_guard_died(_enemy: Node) -> void:
	# 同猎杀：cancel / 超时后守卫才被清场打死，不能补开箱给奖励
	if kind != "guard":
		return
	_guards_left = maxi(_guards_left - 1, 0)
	if _guards_left > 0:
		return
	if _chest != null and is_instance_valid(_chest) and _chest.has_method("open"):
		_chest.open()
	# 开箱动画自己会 queue_free：把引用交还出去，别让 _end() 的回收抢在动画前
	_chest = null
	_reward(GameConfig.ROOM_EVENT_GUARD_SILVER, GameConfig.ROOM_EVENT_GUARD_XP,
		"诅咒解除 +%d 银" % GameConfig.ROOM_EVENT_GUARD_SILVER)
	_end(true, "宝箱开启")

# ==================== 通用 ====================

func _tag_enemy(enemy: Node, text: String, color: Color) -> void:
	## 头顶小字：区分"事件怪"和普通精英。不挂 enemy 子节点树里的位置逻辑，
	## 直接放 enemy 下面跟着走（敌人死亡缩放动画会带着它一起消失）
	var label := Label.new()
	label.name = "EventTag"
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(64, 14)
	# 词缀图标中心在 y=-66，24px 图标的顶部为 -78；Label 实际高度为 24px，
	# 放在 -104 后底部为 -80，与图标保留 2px 间隔。
	label.position = Vector2(-32, -104)
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.04, 0.02, 0.03, 0.9))
	label.add_theme_constant_override("outline_size", 3)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	enemy.add_child(label)

func _reward(silver: int, xp: int, toast: String) -> void:
	if player != null and is_instance_valid(player):
		if player.has_method("add_silver"):
			player.add_silver(silver)
		if player.has_method("gain_xp"):
			player.gain_xp(xp)
	if hud and hud.has_method("show_toast"):
		hud.show_toast(toast)

func _notify(text: String) -> void:
	## 事件开场信息写独立事件行（不借用 wave_banner）：
	## 事件与 "Wave N 开始" 可能同帧，共用横幅会互相覆盖
	_set_hud(text)
	_announce_timer = AnnounceHold

func _set_hud(text: String) -> void:
	if hud and hud.has_method("set_event_status"):
		hud.set_event_status(text)

func _room_bounds() -> Rect2:
	var scene := get_tree().current_scene
	if scene:
		var room := scene.get_node_or_null("GameRoom")
		if room and room.has_method("get_room_bounds"):
			return room.get_room_bounds()
	return Rect2(Vector2(64, 64), Vector2(1152, 592))

func _disconnect_hunt_killed() -> void:
	## 猎物在淡出/清场期间仍可能被 DoT 打死。提前断线，
	## 别让"已经逃走/已经离房"的怪再结算一次。
	if _hunt_enemy != null and is_instance_valid(_hunt_enemy) \
			and _hunt_enemy.has_signal("enemy_died") \
			and _hunt_enemy.enemy_died.is_connected(_on_hunt_killed):
		_hunt_enemy.enemy_died.disconnect(_on_hunt_killed)

func _start_nest() -> void:
	kind = "nest"
	_nest_time = 18.0
	_nest_spawn = 1.2
	_nest_adds = 0
	_notify("血 巢 出 现 · 打 掉 核 心")
	event_started.emit("nest")
	if wave_manager == null or player == null:
		_end(false, "血巢未现身")
		return
	var pos: Vector2 = _offset_from_player(220.0)
	_nest_core = wave_manager.spawn_special_enemy("zombie", pos, [], 1.0, 2.4)
	if _nest_core == null:
		_end(false, "血巢未现身")
		return
	_nest_core.enemy_died.connect(_on_nest_killed)
	_tag_enemy(_nest_core, "血 巢", Color(0.85, 0.2, 0.28))

func _process_nest(delta: float, hud_dirty: bool) -> void:
	_nest_time -= delta
	_nest_spawn -= delta
	if hud_dirty:
		_set_hud("血巢 %.0f 秒" % maxf(_nest_time, 0.0))
	if _nest_time <= 0.0:
		if _nest_core != null and is_instance_valid(_nest_core):
			_nest_core.queue_free()
		_end(false, "血巢消失")
		return
	if _nest_spawn > 0.0 or _nest_adds >= 4 or wave_manager == null or _nest_core == null:
		return
	_nest_spawn = 2.4
	_nest_adds += 1
	var add: Node = wave_manager.spawn_special_enemy("bat", _offset_from_player(160.0), [], 1.0, 0.7)
	if add != null:
		_tag_enemy(add, "巢 虫", Color(0.7, 0.25, 0.3))

func _on_nest_killed(_enemy: Node) -> void:
	if kind != "nest":
		return
	_reward(28, 70, "血巢摧毁 +28 银")
	_end(true, "血巢摧毁")

func _start_flee() -> void:
	kind = "flee"
	_notify("逃 匿 魔 · 在 它 跑 出 去 前 打 倒")
	event_started.emit("flee")
	if wave_manager == null or player == null:
		_end(false, "逃匿魔未现身")
		return
	var pos: Vector2 = _offset_from_player(180.0)
	_flee_enemy = wave_manager.spawn_special_enemy("bat", pos, [], 1.0, 0.8)
	if _flee_enemy == null:
		_end(false, "逃匿魔未现身")
		return
	if _flee_enemy.has_method("set_base_move_speed"):
		_flee_enemy.set_base_move_speed(0.0)
	_flee_dir = _edge_direction(pos)
	_flee_enemy.enemy_died.connect(_on_flee_killed)
	_tag_enemy(_flee_enemy, "逃 匿", Color(0.55, 0.85, 0.95))

func _process_flee(delta: float, hud_dirty: bool) -> void:
	if _flee_enemy == null or not is_instance_valid(_flee_enemy):
		_end(false, "逃匿魔失踪")
		return
	_flee_enemy.global_position += _flee_dir * 110.0 * delta
	if hud_dirty:
		_set_hud("拦住逃匿魔")
	var bounds := _room_bounds()
	var pos: Vector2 = _flee_enemy.global_position
	if pos.x <= bounds.position.x + 28.0 or pos.x >= bounds.end.x - 28.0 \
			or pos.y <= bounds.position.y + 28.0 or pos.y >= bounds.end.y - 28.0:
		_flee_enemy.queue_free()
		_end(false, "逃匿魔逃走")

func _on_flee_killed(_enemy: Node) -> void:
	if kind != "flee":
		return
	_reward(26, 64, "逃匿魔倒下 +26 银")
	_end(true, "逃匿魔倒下")

func _start_seals() -> void:
	kind = "seals"
	_seal_time = [0.0, 0.0]
	_notify("双 封 印 · 站 在 圈 里")
	event_started.emit("seals")
	var bounds := _room_bounds()
	var center := bounds.get_center()
	_seals = [
		_make_marker(center + Vector2(-140, 40), Color(0.45, 0.75, 0.95, 0.85), true),
		_make_marker(center + Vector2(140, -20), Color(0.45, 0.75, 0.95, 0.85), true),
	]

func _process_seals(delta: float, hud_dirty: bool) -> void:
	if player == null or not is_instance_valid(player):
		return
	for i in _seals.size():
		var seal: Node2D = _seals[i]
		if not is_instance_valid(seal):
			continue
		if player.global_position.distance_to(seal.global_position) <= 48.0:
			_seal_time[i] = float(_seal_time[i]) + delta
		var filled: float = clampf(float(_seal_time[i]) / 1.2, 0.0, 1.0)
		_update_seal_marker(seal, filled)
	if hud_dirty:
		_set_hud("封印 %.0f%% / %.0f%%" % [
			clampf(float(_seal_time[0]) / 1.2, 0.0, 1.0) * 100.0,
			clampf(float(_seal_time[1]) / 1.2, 0.0, 1.0) * 100.0,
		])
	if float(_seal_time[0]) >= 1.2 and float(_seal_time[1]) >= 1.2:
		_reward(24, 60, "封印完成 +24 银")
		_end(true, "封印完成")

func _start_bounty() -> void:
	kind = "bounty"
	_bounty_accepted = false
	_notify("悬 赏 · 走 进 标记 才 会 强化 目 标")
	event_started.emit("bounty")
	if wave_manager == null or player == null:
		_end(false, "悬赏未现身")
		return
	var pos: Vector2 = _offset_from_player(240.0)
	_bounty_enemy = wave_manager.spawn_special_enemy("vampire", pos, [], 1.0, 1.0)
	if _bounty_enemy == null:
		_end(false, "悬赏未现身")
		return
	_bounty_mark = pos + Vector2(70, 0)
	_make_marker(_bounty_mark, Color(0.95, 0.75, 0.25, 0.9), false)
	_bounty_enemy.enemy_died.connect(_on_bounty_killed)
	_tag_enemy(_bounty_enemy, "可 拒 绝", Color(0.95, 0.8, 0.35))

func _process_bounty(hud_dirty: bool) -> void:
	if _bounty_enemy == null or not is_instance_valid(_bounty_enemy):
		return
	if not _bounty_accepted and player != null and is_instance_valid(player) \
			and player.global_position.distance_to(_bounty_mark) <= 56.0:
		_bounty_accepted = true
		if "max_hp" in _bounty_enemy:
			_bounty_enemy.max_hp *= 1.8
			_bounty_enemy.current_hp = _bounty_enemy.max_hp
		if "base_contact_damage" in _bounty_enemy:
			_bounty_enemy.base_contact_damage *= 1.4
		_tag_enemy(_bounty_enemy, "悬 赏", Color(1.0, 0.45, 0.2))
	if hud_dirty:
		_set_hud("悬赏已接受" if _bounty_accepted else "走进标记接受悬赏，也可以走开")

func _on_bounty_killed(_enemy: Node) -> void:
	if kind != "bounty":
		return
	if not _bounty_accepted:
		_end(false, "未接受悬赏")
		return
	_reward(32, 72, "悬赏完成 +32 银")
	_end(true, "悬赏完成")

func _offset_from_player(distance: float) -> Vector2:
	var angle := randf() * TAU
	var pos: Vector2 = (player as Node2D).global_position + Vector2(cos(angle), sin(angle)) * distance
	var bounds := _room_bounds()
	pos.x = clampf(pos.x, bounds.position.x + 48.0, bounds.end.x - 48.0)
	pos.y = clampf(pos.y, bounds.position.y + 48.0, bounds.end.y - 48.0)
	return pos

func _edge_direction(from: Vector2) -> Vector2:
	var bounds := _room_bounds()
	var center := bounds.get_center()
	var away := from - center
	if away.length() < 1.0:
		away = Vector2.RIGHT
	return away.normalized()

## 事件地面标记的直径（像素）。判定半径用 MARKER_RADIUS，两者不要再分叉。
const MARKER_DIAMETER: float = 72.0
const MARKER_RADIUS: float = 36.0

## 柔边圆盘贴图（一次性烘好缓存）。中心接近实心、到 0.72 之外快速收尾。
## 早期这里是 Polygon2D 画的 16 边形纯色块：硬边、实心、颜色一压就成
## 一坨"贴图错误的蓝色圆饼"盖在地板上（实机截图里玩家脚下就是一团实心蓝），
## 和"地面圈"这种读法完全对不上号。改成柔边贴图 + 加色光环才是地面投影。
static var _marker_fill_tex: Texture2D = null

func _get_marker_fill_texture() -> Texture2D:
	if _marker_fill_tex != null:
		return _marker_fill_tex
	const S := 96
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	var c := float(S) * 0.5
	for y in S:
		for x in S:
			var d := Vector2(float(x) + 0.5 - c, float(y) + 0.5 - c).length() / c
			var a := 0.0
			if d < 1.0:
				a = 1.0 - smoothstep(0.70, 1.0, d)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	_marker_fill_tex = ImageTexture.create_from_image(img)
	return _marker_fill_tex

## 事件地面标记：柔边光环 + 可选填充。
## 结构固定成 Fill / Ring 两个子节点，_process_seals 按名字取用并分别改色与改透明度。
func _make_marker(pos: Vector2, color: Color, show_fill: bool = false) -> Node2D:
	var marker := Node2D.new()
	marker.name = "EventMarker"
	# 地面层：压在地板之上、角色之下。标记是"圈在哪"，不是"圈盖住谁"。
	marker.z_index = ReadabilityVisuals.Z_GROUND

	var fill := Sprite2D.new()
	fill.name = "Fill"
	fill.texture = _get_marker_fill_texture()
	fill.scale = Vector2.ONE * (MARKER_DIAMETER / float(fill.texture.get_width()))
	fill.modulate = Color(color.r, color.g, color.b, 0.0 if not show_fill else 0.22)
	marker.add_child(fill)

	var ring := Sprite2D.new()
	ring.name = "Ring"
	ring.texture = ProjectileVisuals.get_ring_texture()
	ring.material = ProjectileVisuals.get_additive_material()
	ring.scale = Vector2.ONE * (MARKER_DIAMETER / float(ring.texture.get_width()))
	ring.modulate = color
	marker.add_child(ring)

	var scene := get_tree().current_scene if is_inside_tree() else null
	if scene:
		scene.add_child(marker)
	marker.global_position = pos
	_event_nodes.append(marker)
	return marker

## 封印圈的进度表现：光环由冷蓝转绿并呼吸，填充由中心向外涨。
func _update_seal_marker(seal: Node2D, filled: float) -> void:
	if seal == null or not is_instance_valid(seal):
		return
	var tint := Color(0.45, 0.75, 0.95).lerp(Color(0.45, 0.95, 0.55), filled)
	var breathe := 0.82 + 0.18 * sin(float(Time.get_ticks_msec()) * 0.004)
	var ring := seal.get_node_or_null("Ring") as Sprite2D
	if ring != null:
		ring.modulate = Color(tint.r, tint.g, tint.b, breathe)
	var fill := seal.get_node_or_null("Fill") as Sprite2D
	if fill != null and fill.texture != null:
		var base := MARKER_DIAMETER / float(fill.texture.get_width())
		fill.scale = Vector2.ONE * base * lerpf(0.45, 1.0, filled)
		fill.modulate = Color(tint.r, tint.g, tint.b, lerpf(0.08, 0.40, filled))

func _free_event_nodes() -> void:
	for node in _event_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_event_nodes.clear()
	_seals.clear()

func _end(success: bool, reason: String) -> void:
	var finished_kind := kind
	kind = ""
	_hunt_enemy = null
	_hunt_timer = 0.0
	_hunt_delay = 0.0
	_guards_left = 0
	_nest_core = null
	_flee_enemy = null
	_bounty_enemy = null
	_bounty_accepted = false
	_announce_timer = 0.0
	_free_event_nodes()
	var log: Node = get_tree().get_first_node_in_group("run_log") if is_inside_tree() else null
	if log != null and log.has_method("note_event") and finished_kind != "":
		log.call("note_event", finished_kind, success)
	# 宝箱回收收敛在这里（幂等）：任何结束路径——守卫刷失败、wave_manager 缺失、
	# 换房 cancel、换层——都不会把上锁宝箱留在场上。开箱成功那条路径已经
	# 把 _chest 交还给宝箱自己的开箱动画（见 _on_guard_died），不会被这里抢走。
	_recycle_chest()
	_set_hud("")
	print("🎯 局内事件结束：%s（%s）" % [finished_kind, reason])
	if not finished_kind.is_empty():
		event_finished.emit(finished_kind, success)

func _recycle_chest() -> void:
	## 宝箱是 current_scene 的子节点，不随 GameRoom 释放；必须显式清理。
	## 幂等：引用先置空再释放，重复调用不会二次 free。
	var chest := _chest
	_chest = null
	if chest != null and is_instance_valid(chest):
		chest.queue_free()

func cancel() -> void:
	## 换房/换层调用：事件不跨房。没事件时是纯空操作。
	if kind.is_empty():
		return
	_disconnect_hunt_killed()
	# 猎物与普通敌人由 main 的换房清场统一回收；宝箱由 _end() 回收。
	_end(false, "离开房间")
