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
## HUD 文本降频：每 0.2 秒写一次，别每帧拼字符串
var _hud_tick: float = 0.0

func setup(wm: Node, player_node: Node, hud_node: Node) -> void:
	wave_manager = wm
	player = player_node
	hud = hud_node

func on_floor_changed(floor_index: int) -> void:
	## 换层重置"一层一次"的标记；进行中的事件随 cancel() 结束
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
	if randf() < GameConfig.ROOM_EVENT_HUNT_WEIGHT:
		_start_hunt()
	else:
		_start_guard()
	return true

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
	_hud_tick += delta
	var hud_dirty := _hud_tick >= 0.2
	if hud_dirty:
		_hud_tick = 0.0

	match kind:
		"hunt":
			_process_hunt(delta, hud_dirty)
		"guard":
			_process_guard(hud_dirty)

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
		# 一只守卫都没刷出来：宝箱必须一起收回，否则玩家会对着一个
		# 永远打不开的箱子发呆（而且它还会留到下一房）
		var orphan: Node2D = _chest
		_chest = null
		if orphan != null and is_instance_valid(orphan):
			orphan.queue_free()
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
	label.position = Vector2(-32, -46)
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
	if hud and hud.has_method("show_toast"):
		hud.show_toast(text)

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

func _end(success: bool, reason: String) -> void:
	var finished_kind := kind
	kind = ""
	_hunt_enemy = null
	_hunt_timer = 0.0
	_hunt_delay = 0.0
	_guards_left = 0
	_chest = null
	_set_hud("")
	print("🎯 局内事件结束：%s（%s）" % [finished_kind, reason])
	if not finished_kind.is_empty():
		event_finished.emit(finished_kind, success)

func cancel() -> void:
	## 换房/换层调用：事件不跨房。没事件时是纯空操作。
	if kind.is_empty():
		return
	_disconnect_hunt_killed()
	# 宝箱是 current_scene 的子节点，不随 GameRoom 释放；必须显式清理，否则会留到下一房。
	if _chest != null and is_instance_valid(_chest):
		_chest.queue_free()
	# 猎物与普通敌人由 main 的换房清场统一回收。
	_end(false, "离开房间")
