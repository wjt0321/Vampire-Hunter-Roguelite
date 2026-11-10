extends SceneTree
## 局内目标事件回归测试（17.14）
## 用法: godot --headless --path . --script res://tools/room_event_test.gd
##
## 覆盖：
##   触发规则：一层一次 / 最少战斗房数 / 概率（用 seed 控制）
##   猎杀：双词缀真实装配 / 血量倍率 / 限时结算（击杀给奖励、超时遁走）
##   双词缀：统一加成只结算一次 / 第二词缀血盾真实生效 / 重复与非法 id 去重
##   守卫：数量 / 染色标记 / 全清开箱给奖励
##   spawn_special_enemy 不吃同屏上限（事件目标不能被氛围怪上限卡住）
##   换房 cancel()：事件不跨房
##   HUD 事件标签：空串隐藏、有文显示

var _fail: int = 0
var _pass: int = 0
var _host: Node2D = null
var _wm = null
var _ev = null
var _hud = null
var _silver_before: int = 0
var _xp_before: int = 0
var _player_ref = null
## 信号 lambda 对局部变量是值拷贝，必须写进成员（老坑）
var _last_started_kind: String = ""
## event_finished 的完整记录：超时/取消后再被击杀，不应追加第二次结束
var _finish_log: Array = []


class FakePlayer extends CharacterBody2D:
	## 复用 status_effect_test 的经验：真实 player.tscn 会自动开火
	## 打死被测的事件怪。事件管理器只调 add_silver / gain_xp / global_position。
	var silver: int = 500
	var current_xp: int = 100

	func add_silver(amount: int) -> void:
		silver += amount

	func gain_xp(amount: int) -> void:
		current_xp += amount


class FakeHUD extends Node:
	var event_text: String = "哨兵值"
	var toasts: Array = []

	func set_event_status(text: String) -> void:
		event_text = text

	func show_toast(text: String) -> void:
		toasts.append(text)


class StubHUD:
	## set_event_status 签名检查用（不实例化）
	pass


func _initialize() -> void:
	_run()


func _check(ok: bool, label: String) -> void:
	if ok:
		_pass += 1
		print("✅ %s" % label)
	else:
		_fail += 1
		print("❌ %s" % label)


func _finish() -> void:
	print("")
	print("通过 %d / 失败 %d" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)


func _affix_all_ids() -> Array:
	## 词缀 class_name 在 --script 模式下不能静态引用（编译早于 autoload 注册）
	return load("res://scripts/enemies/elite_affix.gd").all_ids()

func _count_chests() -> int:
	## 受诅宝箱是 current_scene 的直接子节点（不是 GameRoom 的），
	## 按脚本路径数，别按名字（Node2D.new() 的名字会被自动去重成 Node2D2 之类）
	var count: int = 0
	var chest_script: String = "res://scripts/managers/cursed_chest.gd"
	for n in _host.get_children():
		var scr = n.get_script()
		if scr != null and String(scr.resource_path) == chest_script:
			count += 1
	return count


func _secondary_affix(enemy: Node) -> String:
	## 用 get() 读：RED 阶段 enemy_base 还没有 secondary_affix 字段，
	## 直接写 enemy.secondary_affix 会让测试脚本报"属性不存在"而不是断言失败
	if not ("secondary_affix" in enemy):
		return ""
	return String(enemy.get("secondary_affix"))


func _stop_audio() -> void:
	## 只清本测试触发过的播放器；不动 autoload 的缓存（那是项目级资源）。
	## 直接读 AudioManager 的内部数组：测试里没有"停止所有 SFX"的公共接口。
	var am: Node = root.get_node_or_null("AudioManager")
	if am == null:
		return
	var bgm = am.get("_bgm_player")
	if bgm != null and is_instance_valid(bgm):
		bgm.stop()
		bgm.stream = null
	for p in am.get("_sfx_players"):
		if p != null and is_instance_valid(p):
			p.stop()
			p.stream = null
	# AudioServer 要等下一批混音才会释放 playback；headless 下等一两帧不够
	# （最小复现：不等 0.8s 会稳定留下 Ogg playback 泄漏）。
	await create_timer(0.8).timeout


func _wait_until(pred: Callable, timeout: float = 3.0) -> bool:
	## 真实时钟轮询（headless 下写死秒数会抖，ranged_pressure_test 踩过）。
	## SceneTree 没有帧 delta 可读，用 Time.get_ticks_msec。
	var deadline: int = Time.get_ticks_msec() + int(timeout * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if bool(pred.call()):
			return true
		await process_frame
	return bool(pred.call())


func _setup() -> void:
	_host = Node2D.new()
	_host.name = "TestHost"
	root.add_child(_host)
	current_scene = _host

	var player := FakePlayer.new()
	player.position = Vector2(640, 360)
	_host.add_child(player)
	_player_ref = player

	# WaveManager 不用场景里的：测试直接 new 一个，避开 main.tscn 的整串依赖
	var WaveManagerScript = load("res://scripts/managers/wave_manager.gd")
	_wm = Node.new()
	_wm.set_script(WaveManagerScript)
	_host.add_child(_wm)
	_wm.enemy_pool = ["vampire", "bat", "zombie", "skeleton_archer", "werewolf"]
	_wm.floor_index = 1
	# is_active 关掉：不让普通刷怪进程添乱（xp_pickup_diag 的教训）
	_wm.is_active = false

	_hud = FakeHUD.new()

	var EventScript = load("res://scripts/managers/room_event_manager.gd")
	_ev = Node.new()
	_ev.set_script(EventScript)
	_host.add_child(_ev)
	_ev.setup(_wm, player, _hud)
	_ev.event_finished.connect(func(kind: String, success: bool):
		_finish_log.append({"kind": kind, "success": success}))


func _run() -> void:
	await process_frame
	print("\n====== 局内目标事件测试（17.14）======")
	_setup()
	await process_frame

	# ---------- 触发规则 ----------
	print("\n--- 触发规则 ---")
	seed(20261108)
	var GC = load("res://scripts/core/game_config.gd")
	_ev.floor_fired = -1
	_ev.combat_room_count = 0
	# MIN_COMBAT_ROOM 之前不触发：第 1 间
	var r1: bool = _ev.on_combat_room_entered(1)
	_check(not r1 and _ev.combat_room_count == 1,
		"第 1 间战斗房不触发（教学保护）")
	_ev.cancel()
	# 一层一次：手工标记"本层已触发"后，再进房必不触发
	_ev.floor_fired = 1
	var r2: bool = _ev.on_combat_room_entered(1)
	_check(not r2, "本层已触发过则不再触发（一层一次）")
	_ev.cancel()
	# 概率线：固定 seed 判定 40 次（常量是 const 不能运行时改）。
	# 0.35 概率下 40 次全不触发 ≈ 0.65^40 ≈ 1e-8，全触发 ≈ 0，
	# 卡在中间 = 概率分支真实活着。
	# 用独立实例且不给它 wave_manager：触发后 _start_* 走"未现身"提前结束，
	# 不真的刷怪——否则 12 次触发会往场上塞 12 组事件怪，污染后面的行为断言
	var prob_ev: Node = Node.new()
	prob_ev.set_script(load("res://scripts/managers/room_event_manager.gd"))
	_host.add_child(prob_ev)
	var trigger_count: int = 0
	for i in range(40):
		prob_ev.floor_fired = -1
		if prob_ev.on_combat_room_entered(1):
			trigger_count += 1
		prob_ev.cancel()
	_check(trigger_count > 0 and trigger_count < 40,
		"概率判定活着（40 次判定触发 %d 次，期望 ~14）" % trigger_count)
	prob_ev.free()

	# ---------- 猎杀 ----------
	print("\n--- 猎杀事件 ---")
	_ev.floor_fired = -1
	_last_started_kind = ""
	_ev.event_started.connect(func(k: String): _last_started_kind = k)
	var silver0: int = _ev.player.silver
	var xp0: int = _ev.player.current_xp
	# 行为测试绕过概率（const 不能运行时改），直接走启动线
	_ev.combat_room_count = maxi(GameConfig.ROOM_EVENT_MIN_COMBAT_ROOM, 2)
	_ev._start_hunt()
	_check(_ev.kind == "hunt", "猎杀事件启动")
	_check(_last_started_kind == "hunt", "event_started 信号带 hunt")
	await _wait_until(func() -> bool:
		return _ev._hunt_enemy != null and is_instance_valid(_ev._hunt_enemy))
	_check(_ev._hunt_enemy != null and is_instance_valid(_ev._hunt_enemy),
		"延迟后猎物出场")
	if _ev._hunt_enemy != null and is_instance_valid(_ev._hunt_enemy):
		var he: Node = _ev._hunt_enemy
		var ids: Array = _affix_all_ids()
		_check(String(he.elite_affix) in ids,
			"猎物主词缀合法（%s）" % he.elite_affix)
		# 第 1 层词缀池只有急速，但"双词缀"没有楼层例外：
		# 第二词缀从完整合法池里排除主词缀后取。
		_check(String(he.elite_affix) == "haster",
			"第 1 层猎物主词缀仍走逐层池（%s）" % he.elite_affix)
		_check(not _secondary_affix(he).is_empty()
			and _secondary_affix(he) in ids
			and _secondary_affix(he) != String(he.elite_affix),
			"第 1 层猎物也是双词缀（%s + %s）" % [he.elite_affix, _secondary_affix(he)])
		var hunt_ctrl_a = he.get_node_or_null("AffixController")
		var hunt_ctrl_b = he.get_node_or_null("AffixController2")
		_check(hunt_ctrl_a != null and hunt_ctrl_b != null,
			"双词缀各挂一个控制器（AffixController / AffixController2）")
		if hunt_ctrl_a != null and hunt_ctrl_b != null:
			_check(String(hunt_ctrl_a.affix_id) == String(he.elite_affix)
				and String(hunt_ctrl_b.affix_id) == _secondary_affix(he),
				"控制器槽位与主/次词缀对应（%s / %s）" % [hunt_ctrl_a.affix_id, hunt_ctrl_b.affix_id])
		# extra_hp_scale 只写 hp_scale；词缀的 1.35 在 _apply_elite_affix_stats 里乘 max_hp。
		# 两处分开验证，别把两条链混在一个断言里
		_check(he.hp_scale >= GameConfig.ROOM_EVENT_HUNT_HP_MULT - 0.01,
			"猎物事件血量倍率进 hp_scale（%.2f）" % he.hp_scale)
		var base_hp: float = float(he.get("base_hp"))
		_check(he.max_hp >= base_hp * GameConfig.ELITE_AFFIX_HP_MULT * GameConfig.ROOM_EVENT_HUNT_HP_MULT * 0.8,
			"猎物实际血量含词缀加成（max_hp=%.0f，base=%.0f）" % [he.max_hp, base_hp])
		var tag = he.get_node_or_null("EventTag")
		_check(tag != null and String(tag.text).contains("猎"), "猎物头顶有『猎物』标识")
		_check(he.global_position.distance_to(_ev.player.global_position) > 150.0,
			"猎物出场在玩家外圈（不贴脸）")
		# 击杀 → 奖励
		he.take_damage(999999.0)
		await process_frame
		_check(_ev.player.silver - silver0 == GC.ROOM_EVENT_HUNT_SILVER,
			"击杀猎物给 %d 银币（实际 +%d）" % [GC.ROOM_EVENT_HUNT_SILVER, _ev.player.silver - silver0])
		_check(_ev.player.current_xp - xp0 == GC.ROOM_EVENT_HUNT_XP,
			"击杀猎物给 %d 经验（实际 +%d）" % [GC.ROOM_EVENT_HUNT_XP, _ev.player.current_xp - xp0])
		_check(_ev.kind == "", "结算后事件关闭")
	# 超时线：再启动一次，把倒计时拧到 0.05 秒
	_ev.floor_fired = -1
	_ev._start_hunt()
	_check(_ev.kind == "hunt", "第二次猎杀启动（测超时）")
	await _wait_until(func() -> bool:
		return _ev._hunt_enemy != null and is_instance_valid(_ev._hunt_enemy))
	if _ev._hunt_enemy != null:
		_ev._hunt_timer = 0.05
		var enemy_ref: Node = _ev._hunt_enemy
		await _wait_until(func() -> bool:
			return _ev.kind == "", 2.0)
		_check(_ev.kind == "", "超时后事件结束")
		# 遁走是 0.5 秒淡出，用条件等待而不是固定帧数，避免帧时序假红
		await _wait_until(func() -> bool:
			return not is_instance_valid(enemy_ref) or float(enemy_ref.modulate.a) < 1.0, 1.0)
		_check(not is_instance_valid(enemy_ref) or float(enemy_ref.modulate.a) < 1.0,
			"超时猎物开始遁走（透明化）")
	_ev.cancel()

	# ---------- 超时 / 取消后不得结算 ----------
	print("\n--- 超时 / 取消后不得结算 ---")
	# 超时后淡出期间，流血这类 DoT 仍可能把猎物打死。它已经算"逃走"，
	# 再给奖励等于玩家什么都不做白拿一份。
	_ev.floor_fired = -1
	_ev._start_hunt()
	await _wait_until(func() -> bool:
		return _ev._hunt_enemy != null and is_instance_valid(_ev._hunt_enemy))
	var timeout_target: Node = _ev._hunt_enemy
	var silver_t0: int = _ev.player.silver
	var xp_t0: int = _ev.player.current_xp
	_ev._hunt_timer = 0.05
	await _wait_until(func() -> bool: return _ev.kind == "", 2.0)
	# 结束计数在"逃走"结算之后取：要证明的是致死不再**追加**一次
	var finishes_t0: int = _finish_log.size()
	if is_instance_valid(timeout_target):
		timeout_target.take_damage(999999.0)
	await process_frame
	await process_frame
	_check(_ev.player.silver == silver_t0 and _ev.player.current_xp == xp_t0,
		"超时后淡出期间被 DoT 打死不发奖励（银 %+d / 经验 %+d）"
		% [_ev.player.silver - silver_t0, _ev.player.current_xp - xp_t0])
	_check(_finish_log.size() == finishes_t0,
		"超时后致死不再追加一次事件结束（%d 次）" % (_finish_log.size() - finishes_t0))
	_ev.cancel()

	# 换房 cancel() 后同样不许补发
	_ev.floor_fired = -1
	_ev._start_hunt()
	await _wait_until(func() -> bool:
		return _ev._hunt_enemy != null and is_instance_valid(_ev._hunt_enemy))
	var cancel_target: Node = _ev._hunt_enemy
	var silver_c0: int = _ev.player.silver
	var xp_c0: int = _ev.player.current_xp
	_ev.cancel()
	# cancel 本身会结束事件，计数必须在它之后取
	var finishes_c0: int = _finish_log.size()
	if is_instance_valid(cancel_target):
		cancel_target.take_damage(999999.0)
	await process_frame
	await process_frame
	_check(_ev.player.silver == silver_c0 and _ev.player.current_xp == xp_c0,
		"cancel 后猎物死亡不发奖励")
	_check(_finish_log.size() == finishes_c0,
		"cancel 后猎物死亡不追加事件结束（%d 次）" % (_finish_log.size() - finishes_c0))

	# 猎物被外部释放（换房清场 / 对象池回收）：事件必须结束，HUD 不能卡在倒计时
	_ev.floor_fired = -1
	_ev._start_hunt()
	await _wait_until(func() -> bool:
		return _ev._hunt_enemy != null and is_instance_valid(_ev._hunt_enemy))
	var vanished: Node = _ev._hunt_enemy
	vanished.queue_free()
	await _wait_until(func() -> bool: return _ev.kind == "", 2.0)
	_check(_ev.kind == "", "猎物被外部释放后事件结束（不会永久停在 hunt）")
	_check(_ev.hud.event_text == "", "猎物消失后 HUD 事件行被清空（实际 '%s'）" % _ev.hud.event_text)
	_ev.cancel()

	# ---------- 双词缀装配 ----------
	print("\n--- 双词缀装配 ---")
	# 直接走装配入口：猎杀的词缀是随机抽的，数值断言需要一个固定组合
	var plain: Node = _wm.spawn_special_enemy("zombie", Vector2(150, 150), [], 1.0, 1.0)
	var dual: Node = _wm.spawn_special_enemy("zombie", Vector2(250, 150), ["haster", "shielded"], 1.0, 1.0)
	await process_frame
	await process_frame
	_check(plain != null and dual != null, "同层同类型怪可用于对照（无词缀 / 双词缀）")
	if plain != null and dual != null:
		_check(String(dual.elite_affix) == "haster" and _secondary_affix(dual) == "shielded",
			"两个词缀都真实装配（%s + %s）" % [dual.elite_affix, _secondary_affix(dual)])
		var ctrl_a = dual.get_node_or_null("AffixController")
		var ctrl_b = dual.get_node_or_null("AffixController2")
		_check(ctrl_a != null and ctrl_b != null, "双词缀挂两个可区分控制器")
		if ctrl_a != null and ctrl_b != null:
			_check(String(ctrl_a.affix_id) == "haster" and String(ctrl_b.affix_id) == "shielded",
				"主词缀占 AffixController，第二词缀占 AffixController2")
			var icon_a = ctrl_a.get_node_or_null("AffixIcon")
			var icon_b = ctrl_b.get_node_or_null("AffixIcon")
			_check(icon_a != null and icon_b != null
				and absf(icon_a.position.x - icon_b.position.x) > 1.0,
				"两个词缀图标错开槽位（x %.0f / %.0f）" % [icon_a.position.x, icon_b.position.x])
			var ring_a = ctrl_a.get_node_or_null("AffixRing")
			var ring_b = ctrl_b.get_node_or_null("AffixRing")
			_check(ring_a != null and ring_b != null
				and absf(ring_a.scale.x - ring_b.scale.x) > 0.01,
				"两个光环半径可区分（%.2f / %.2f）" % [ring_a.scale.x, ring_b.scale.x])
		# 统一加成每只精英只结算一次：若每词缀各乘一次，血量会是 ×1.35²
		var plain_hp: float = float(plain.max_hp)
		var expect_hp: float = plain_hp * GC.ELITE_AFFIX_HP_MULT * (1.0 + GC.AFFIX_SHIELD_RATIO)
		_check(absf(float(dual.max_hp) - expect_hp) < 0.5,
			"统一血量加成只结算一次 + 一份护盾（%.0f ≈ %.0f）" % [dual.max_hp, expect_hp])
		_check(absf(float(dual.affix_shield_hp)
			- plain_hp * GC.ELITE_AFFIX_HP_MULT * GC.AFFIX_SHIELD_RATIO) < 0.5,
			"第二词缀血盾盾量正确（%.0f）" % dual.affix_shield_hp)
		_check(absf(float(dual.contact_damage)
			- float(plain.contact_damage) * GC.ELITE_AFFIX_DAMAGE_MULT) < 0.01,
			"接触伤害只乘一次（%.1f）" % dual.contact_damage)
		_check(int(dual.silver_value)
			== int(round(float(plain.silver_value) * GC.ELITE_AFFIX_SILVER_MULT)),
			"银币只乘一次（%d）" % dual.silver_value)
		_check(int(dual.xp_value)
			== int(round(float(plain.xp_value) * GC.ELITE_AFFIX_XP_MULT)),
			"经验只乘一次（%d）" % dual.xp_value)
		var plain_sprite := plain.get_node("Sprite2D") as Sprite2D
		var dual_sprite := dual.get_node("Sprite2D") as Sprite2D
		_check(absf(dual_sprite.scale.x / plain_sprite.scale.x - GC.ELITE_AFFIX_SCALE_MULT) < 0.02,
			"体型只放大一次（×%.2f）" % (dual_sprite.scale.x / plain_sprite.scale.x))
		# 第二词缀（shielded 挂在 AffixController2 上）的护盾必须真实生效
		var shield: float = float(dual.affix_shield_hp)
		_check(shield > 0.0, "第二词缀血盾有实盾量（%.0f）" % shield)
		dual.take_damage(float(dual.max_hp) - shield * 0.5)
		await physics_frame
		await physics_frame
		_check(float(dual.affix_shield_hp) <= 0.0,
			"AffixController2 把第二词缀的盾打碎（剩 %.0f）" % dual.affix_shield_hp)
		_check(not dual.is_dead and float(dual.current_hp) > 0.0, "破盾后猎物仍存活")

	# ---------- 重复 / 非法词缀 id ----------
	print("\n--- 重复 / 非法词缀 id ---")
	var dup: Node = _wm.spawn_special_enemy("zombie", Vector2(400, 150), ["shielded", "shielded"], 1.0, 1.0)
	var bad: Node = _wm.spawn_special_enemy("zombie", Vector2(500, 150),
		["not_a_real_affix", "haster"], 1.0, 1.0)
	await process_frame
	await process_frame
	if plain != null and dup != null and bad != null:
		_check(dup.get_node_or_null("AffixController") != null
			and dup.get_node_or_null("AffixController2") == null,
			"相同 id 不产生重复控制器")
		_check(absf(float(dup.affix_shield_hp)
			- float(plain.max_hp) * GC.ELITE_AFFIX_HP_MULT * GC.AFFIX_SHIELD_RATIO) < 0.5,
			"相同 id 的护盾只结算一次（%.0f）" % dup.affix_shield_hp)
		_check(String(bad.elite_affix) == "haster" and _secondary_affix(bad).is_empty(),
			"非法 id 被丢弃，合法词缀补上主槽（%s / %s）" % [bad.elite_affix, _secondary_affix(bad)])
		_check(bad.get_node_or_null("AffixController") != null
			and bad.get_node_or_null("AffixController2") == null,
			"非法 id 不产生控制器")
	# 第三个合法 id 不得顶掉第二词缀
	var triple: Node = _wm.spawn_special_enemy("zombie", Vector2(600, 150),
		["haster", "shielded", "charger"], 1.0, 1.0)
	await process_frame
	await process_frame
	if triple != null:
		_check(String(triple.elite_affix) == "haster" and _secondary_affix(triple) == "shielded",
			"只取前两个不同合法词缀（%s / %s）" % [triple.elite_affix, _secondary_affix(triple)])
		var triple_ctrls: int = 0
		for child in triple.get_children():
			if child is Node2D and child.get("affix_id") != null:
				triple_ctrls += 1
		_check(triple_ctrls == 2, "第三个词缀不产生第三个控制器（%d 个）" % triple_ctrls)
		triple.queue_free()
	for n in [plain, dual, dup, bad]:
		if n != null and is_instance_valid(n):
			n.queue_free()
	await process_frame

	# ---------- 每层猎物都双词缀 ----------
	print("\n--- 每层猎物都双词缀 ---")
	var all_ids: Array = _affix_all_ids()
	var pair_ok: bool = true
	var pair_labels: Array = []
	for floor_i in [1, 2, 3]:
		_wm.floor_index = floor_i
		_ev._spawn_hunt_enemy()
		var hunter: Node = _ev._hunt_enemy
		if hunter == null:
			pair_ok = false
			pair_labels.append("%d:未出场" % floor_i)
			continue
		var a: String = String(hunter.elite_affix)
		var b: String = _secondary_affix(hunter)
		var pool: Array = GameConfig.get_elite_affix_pool(floor_i)
		# 主词缀必须在本层池内，第二词缀合法且不同——楼层不改变"双词缀"这个定义
		if a not in pool or b.is_empty() or b == a or b not in all_ids:
			pair_ok = false
		pair_labels.append("%d:%s+%s" % [floor_i, a, b])
		hunter.queue_free()
		_ev._hunt_enemy = null
	await process_frame
	_check(pair_ok, "每层猎物都是两个不同合法词缀（%s）" % str(pair_labels))
	_wm.floor_index = 1

	# ---------- 事件标记布局 ----------
	print("\n--- 事件标记布局 ---")
	# 事件标签（"猎 物"）和两个词缀图标都在敌人头顶：图标在 y=-52，
	# 标签原先在 y=-46，两者直接压在一起 → 玩家读到的是乱码。
	_ev.floor_fired = -1
	_ev._start_hunt()
	await _wait_until(func() -> bool:
		return _ev._hunt_enemy != null and is_instance_valid(_ev._hunt_enemy), 3.0)
	var tagged: Node = _ev._hunt_enemy
	if tagged != null and is_instance_valid(tagged):
		var tag := tagged.get_node_or_null("EventTag") as Label
		_check(tag != null, "猎物带事件标签")
		var icon_count: int = 0
		for ctrl_name in ["AffixController", "AffixController2"]:
			var ctrl := tagged.get_node_or_null(ctrl_name)
			if ctrl == null:
				continue
			var icon := ctrl.get_node_or_null("AffixIcon") as Sprite2D
			if icon == null:
				continue
			icon_count += 1
			if tag == null:
				continue
			# 词缀图标已从 Label 迁移为 24px Sprite2D，按实际贴图与缩放计算占位。
			var icon_size: Vector2 = icon.texture.get_size() * icon.scale
			var icon_rect := Rect2(icon.position - icon_size * 0.5, icon_size)
			var tag_rect := Rect2(tag.position, tag.size)
			_check(not icon_rect.intersects(tag_rect),
				"事件标签不压词缀图标（%s 图标 %s / 标签 %s）"
				% [ctrl_name, str(icon_rect), str(tag_rect)])
		_check(icon_count == 2, "猎物同时带事件标签与两个词缀图标（图标 %d 个）" % icon_count)
	else:
		_check(false, "猎物出场用于标记布局检查")
	_ev.cancel()
	await process_frame

	# ---------- 守卫 ----------
	print("\n--- 守卫事件 ---")
	_ev.floor_fired = -1
	var silver1: int = _ev.player.silver
	var xp1: int = _ev.player.current_xp
	_last_started_kind = ""
	_ev.event_started.connect(func(k: String): _last_started_kind = k)
	# 行为测试直接走启动线（绕过概率分支）
	_ev._start_guard()
	_check(_last_started_kind == "guard" and _ev.kind == "guard", "守卫事件启动")
	var chest: Node = _ev._chest
	_check(chest != null and is_instance_valid(chest), "宝箱出场")
	var guards: Array = []
	for n in _host.get_children():
		if n is Node2D and String(n.get("elite_affix") if "elite_affix" in n else "") == "" \
				and n != _player_ref and n != chest and n.get_node_or_null("EventTag") != null \
				and String(n.get_node("EventTag").text).contains("守"):
			guards.append(n)
	_check(guards.size() == GC.ROOM_EVENT_GUARD_COUNT,
		"守卫数量 = %d（实际 %d）" % [GC.ROOM_EVENT_GUARD_COUNT, guards.size()])
	if guards.size() > 0:
		var g0: Node = guards[0]
		_check(absf(g0.modulate.r - GC.ROOM_EVENT_GUARD_COLOR.r) < 0.05
			and absf(g0.modulate.g - GC.ROOM_EVENT_GUARD_COLOR.g) < 0.05,
			"守卫染成金色标记")
		_check(g0.hp_scale >= GC.ROOM_EVENT_GUARD_HP_MULT - 0.01,
			"守卫血量倍率到位（hp_scale=%.2f）" % g0.hp_scale)
	# 全清守卫 → 开箱奖励
	for g in guards:
		if is_instance_valid(g):
			g.take_damage(999999.0)
	await process_frame
	await process_frame
	_check(_ev.player.silver - silver1 == GC.ROOM_EVENT_GUARD_SILVER,
		"开箱给 %d 银币（实际 +%d）" % [GC.ROOM_EVENT_GUARD_SILVER, _ev.player.silver - silver1])
	_check(_ev.player.current_xp - xp1 == GC.ROOM_EVENT_GUARD_XP,
		"开箱给 %d 经验（实际 +%d）" % [GC.ROOM_EVENT_GUARD_XP, _ev.player.current_xp - xp1])
	_check(_ev.kind == "", "开箱后事件关闭")

	# ---------- 宝箱不与玩家重合 ----------
	print("\n--- 宝箱位置 ---")
	# 玩家站在房间正中央时，宝箱不能刷在同一个点上（会互相遮挡、也读不出"守卫圈"）
	_player_ref.global_position = Vector2(640, 360)
	_ev.floor_fired = -1
	_ev._start_guard()
	var center_chest: Node = _ev._chest
	if center_chest != null:
		_check(center_chest.global_position.distance_to(_player_ref.global_position) > 40.0,
			"玩家在房间中心时宝箱错开（%.0fpx）"
			% center_chest.global_position.distance_to(_player_ref.global_position))
	# 清掉本次守卫，避免污染后面的取消测试
	for g in _host.get_children():
		if g is Node2D and g.get_node_or_null("EventTag") != null \
				and String(g.get_node("EventTag").text).contains("守"):
			g.queue_free()
	_ev.cancel()

	# ---------- 守卫 / 宝箱异常路径 ----------
	print("\n--- 守卫异常路径 ---")
	# 守卫全刷失败：宝箱不能留在场上（玩家会对着一个永远打不开的箱子发呆）
	# 直接数场景里的宝箱节点：只查 _ev._chest 会因为 _end() 把它置空而恒真。
	# 先等两帧，让前面 cancel() 延迟释放的宝箱结算完，基线才是干净的。
	await process_frame
	await process_frame
	var chests_before: int = _count_chests()
	var saved_scenes: Dictionary = _wm.enemy_scenes
	_wm.enemy_scenes = {}
	_ev.floor_fired = -1
	_ev._start_guard()
	await process_frame
	await process_frame
	_check(_ev.kind == "", "守卫刷不出来时事件结束")
	_check(_count_chests() == chests_before,
		"守卫刷不出来时宝箱被回收（场上 %d → %d 个）"
		% [chests_before, _count_chests()])
	_wm.enemy_scenes = saved_scenes

	# wave_manager 缺失：_spawn_guards 的早退路径同样不能留下宝箱
	# （早退直接 _end，宝箱回收必须收敛到 _end 才不漏）
	await process_frame
	await process_frame
	var chests_wmnull_before: int = _count_chests()
	var saved_wm: Node = _ev.wave_manager
	_ev.wave_manager = null
	_ev.floor_fired = -1
	_ev._start_guard()
	await process_frame
	await process_frame
	_check(_ev.kind == "", "wave_manager 缺失时事件结束")
	_check(_count_chests() == chests_wmnull_before,
		"wave_manager 缺失时宝箱被回收（场上 %d → %d 个）"
		% [chests_wmnull_before, _count_chests()])
	_ev.wave_manager = saved_wm

	# 换层：on_floor_changed 自己 cancel 进行中的事件（不依赖换房流程先调 cancel）
	await process_frame
	await process_frame
	var chests_floor_before: int = _count_chests()
	_ev.floor_fired = -1
	_ev._start_guard()
	_check(_ev.kind == "guard", "换层前事件进行中")
	_ev.on_floor_changed(_wm.floor_index + 1)
	await process_frame
	await process_frame
	_check(_ev.kind == "", "on_floor_changed 取消进行中的事件")
	_check(_count_chests() == chests_floor_before,
		"换层时宝箱被回收（场上 %d → %d 个）"
		% [chests_floor_before, _count_chests()])
	_ev.on_floor_changed(_wm.floor_index)
	# 守卫本身是普通敌人，换层由 main 的清场回收；这里只清理测试宿主，避免污染后续用例
	for g in _host.get_children():
		if g is Node2D and g.get_node_or_null("EventTag") != null \
				and String(g.get_node("EventTag").text).contains("守"):
			g.queue_free()

	# 换房 cancel() 之后守卫再死：不能再开箱发奖励
	_ev.floor_fired = -1
	_ev._start_guard()
	var late_guards: Array = []
	for g in _host.get_children():
		if g is Node2D and g.get_node_or_null("EventTag") != null \
				and String(g.get_node("EventTag").text).contains("守"):
			late_guards.append(g)
	var silver_late: int = _ev.player.silver
	var xp_late: int = _ev.player.current_xp
	_ev.cancel()
	# 同上：cancel 的事件结束先计入，之后守卫死亡不能再追加
	var finishes_late: int = _finish_log.size()
	for g in late_guards:
		if is_instance_valid(g):
			g.take_damage(999999.0)
	await process_frame
	await process_frame
	_check(_ev.player.silver == silver_late and _ev.player.current_xp == xp_late,
		"cancel 后守卫死亡不发奖励")
	_check(_finish_log.size() == finishes_late,
		"cancel 后守卫死亡不追加事件结束（%d 次）" % (_finish_log.size() - finishes_late))

	# ---------- 跨房清理 ----------
	print("\n--- 跨房清理 ---")
	_ev.floor_fired = -1
	_ev._start_guard()
	_check(_ev.kind == "guard", "再次启动守卫事件（测换房）")
	var cancelled_chest: Node = _ev._chest
	_ev.cancel()
	_check(_ev.kind == "", "换房后事件立即取消")
	await process_frame
	_check(not is_instance_valid(cancelled_chest), "换房后上锁宝箱节点也被回收（不跨房残留）")

	# ---------- 同屏上限豁免 ----------
	print("\n--- 同屏上限豁免 ---")
	# 场上塞满假敌人（超过第 1 层上限 16），spawn_special_enemy 仍能出场
	for i in range(20):
		var filler := Node2D.new()
		filler.add_to_group("enemies")
		_host.add_child(filler)
	var special: Node = _wm.spawn_special_enemy("bat", Vector2(300, 300), [], 1.0, 1.0)
	_check(special != null and is_instance_valid(special),
		"同屏超上限时事件敌人仍可出场（不读 enemies_alive 计数）")
	if special:
		special.queue_free()

	# ---------- HUD ----------
	print("\n--- HUD 事件标签 ---")
	var hud_scene: PackedScene = load("res://scenes/ui/hud.tscn")
	var live_hud: Node = hud_scene.instantiate()
	_host.add_child(live_hud)
	await process_frame
	_check(live_hud.has_method("set_event_status"), "HUD 提供 set_event_status 接口")
	var ev_label = live_hud.event_label
	_check(ev_label != null and is_instance_valid(ev_label), "真实 HUD 场景创建了 event_label")
	if ev_label != null:
		# 事件行必须是独立节点：复用 wave_label 会让波次编号和倒计时互相覆盖
		_check(ev_label != live_hud.get_node("MarginContainer/VBoxContainer/TopBar/WaveLabel"),
			"event_label 是独立节点（不复用 wave_label）")
		_check(not ev_label.visible, "无事件时 event_label 默认隐藏")
		live_hud.set_event_status("猎杀 12 秒")
		_check(ev_label.visible and ev_label.text == "猎杀 12 秒",
			"非空状态显示事件行（'%s'）" % ev_label.text)
		live_hud.set_event_status("")
		_check(not ev_label.visible, "空字符串隐藏事件行（不是留空行占位）")
	live_hud.queue_free()
	await process_frame

	# ---------- 事件状态写入真实 HUD ----------
	print("\n--- 事件状态写入真实 HUD ---")
	# 开场信息原先走 hud.show_toast()，而复用 wave_banner 的位置：
	# 事件与 "Wave N 开始" 同帧时两者互相覆盖。开场信息必须写独立 event_label。
	var real_hud: Node = hud_scene.instantiate()
	_host.add_child(real_hud)
	await process_frame
	_ev.setup(_wm, _player_ref, real_hud)
	var real_label = real_hud.event_label
	var real_banner = real_hud.wave_banner
	_check(real_label != null and real_banner != null, "真实 HUD 提供事件行与波次横幅")

	_ev.floor_fired = -1
	_ev._start_hunt()
	_check(real_label != null and real_label.visible and real_label.text.contains("猎"),
		"猎杀开场信息写进独立事件行（'%s'）" % (real_label.text if real_label else ""))
	_check(real_banner != null and not real_banner.visible,
		"猎杀开场信息不占用 wave_banner（不与波次横幅互相覆盖）")
	# 倒计时继续正常更新同一行
	await _wait_until(func() -> bool:
		return _ev._hunt_enemy != null and is_instance_valid(_ev._hunt_enemy), 3.0)
	var saw_countdown: bool = await _wait_until(func() -> bool:
		return real_label != null and real_label.visible and real_label.text.contains("猎杀"), 2.0)
	_check(saw_countdown, "猎物出场后事件行切换为倒计时（'%s'）"
		% (real_label.text if real_label != null else ""))
	_ev.cancel()
	await process_frame

	_ev.floor_fired = -1
	_ev._start_guard()
	_check(real_label != null and real_label.visible and real_label.text.contains("宝 箱"),
		"守卫开场信息写进独立事件行（'%s'）" % (real_label.text if real_label else ""))
	_check(real_banner != null and not real_banner.visible,
		"守卫开场信息不占用 wave_banner")
	# 状态行每 0.2 秒刷一次；不留一拍的话，"守卫苏醒"会在第一次刷新时
	# 被"守卫 ×5"顶掉，开场信息等于没显示（等 0.3s 确保至少跨过一次刷新）
	await create_timer(0.3).timeout
	_check(real_label != null and real_label.visible and real_label.text.contains("宝 箱"),
		"守卫开场信息在一次状态刷新后仍可读（'%s'）"
		% (real_label.text if real_label != null else ""))
	var saw_guard_status: bool = await _wait_until(func() -> bool:
		return real_label != null and real_label.visible and real_label.text.contains("守卫 ×"), 2.5)
	_check(saw_guard_status, "守卫事件行继续显示剩余数量（'%s'）"
		% (real_label.text if real_label != null else ""))
	_ev.cancel()
	await process_frame
	_check(real_label != null and not real_label.visible, "事件结束后事件行隐藏")
	_ev.setup(_wm, _player_ref, _hud)
	real_hud.queue_free()
	await process_frame

	# ---------- 收尾 ----------
	# FakeHUD 不在树上：SceneTree 退出时不会替我们释放它，不显式 free 会留下
	# Node + GDScript + GDScriptNativeClass 三个 ObjectDB 泄漏（--verbose 可复现）。
	_ev.hud = null
	if _hud != null and is_instance_valid(_hud):
		_hud.free()
	_hud = null
	# 本测试打死不少敌人 → 掉落的经验宝石进了 ObjectPool（已 remove_child 的孤儿节点）。
	# 池子不主动清的话，退出检查会把这些 Area2D/Sprite2D/CollisionShape2D 当成泄漏。
	var pool: Node = root.get_node_or_null("ObjectPool")
	if pool != null:
		pool.clear_all()
	await process_frame
	await process_frame
	# 本测试让敌人受伤/死亡，AudioManager 的 SFX 若还在响，Ogg playback 资源会被
	# 带进退出检查（间歇性出现）。停掉播放器并清空 stream，再等一次混音。
	await _stop_audio()

	_finish()
