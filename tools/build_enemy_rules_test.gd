extends SceneTree
## Build 与敌人规则回归测试（2026-11-10 玩法迭代 Task 3）
## 用法: godot --headless --path . --script res://tools/build_enemy_rules_test.gd
##
## 覆盖设计文档 2026-11-10-gameplay-iteration-design.md 第 5 条与"Boss 环形弹幕真实前摇"：
##   ① 属性卡 5 级上限：满级后不再进池、也不再叠数值
##   ② 属性卡全满后，既有补给卡（basic 分支）真的能被抽到
##   ③ 自爆者爆炸掉落经验与银币
##   ④ 掉落点钳制复用 RoomLookup：死在房间外的怪也要把掉落丢在房间里
##   ⑤ 银币合并前先保证落点有效
##   ⑥ 召唤物接上击杀信号（死了要计入击杀）+ 首次召唤有间隔
##   ⑦ 第一层远程敌人按"战斗房"解禁（商店/宝箱不吃掉解禁名额）
##   ⑧ Boss 环形弹幕有真实前摇（前摇期间不发弹）
##   ⑨ 每日升级抽卡使用局内固定 RNG（同种子同手牌）
##
## 注意：--script 模式下 autoload 在编译期未注册，脚本里不能直接写单例名，
##       也不能静态引用 class_name，一律运行时 load()。
##       本项目把"推断出 Variant"的警告当错误，所以每个变量都写死类型。

const GameConfigScript = preload("res://scripts/core/game_config.gd")

## 敌方弹丸物理层（2d_physics/layer_6）
const ENEMY_BULLET_LAYER: int = 32
## 属性卡等级上限（设计文档第 5 条：基础属性卡 5 级上限）
const STAT_MAX_LEVEL: int = 5
## 属性卡共享总预算（单卡 5 级 + 全局 12 级）
## 12 而不是 15：一局 12 波（3 层 × 4 战斗房）里玩家实际能拿到的属性升级就十几张，
## 15 级预算等于"这局摸不到顶"，专注属性的 Build 也就永远等不到补给卡。
## 12 级 ≈ 2.4 张卡拉满，专注型 Build 在 12 波内必然触顶并转投补给。
const TOTAL_STAT_BUDGET: int = 12

var _fail: int = 0
var _pass: int = 0
## 本测试建出来的场景根节点，收尾时统一释放
var _roots: Array = []
## 每日挑战的静态状态：测试结束后必须还原
var _daily_backup: Dictionary = {}

func _initialize() -> void:
	_run()

func _check(cond: bool, msg: String) -> void:
	if cond:
		_pass += 1
		print("  ✅ %s" % msg)
	else:
		_fail += 1
		print("  ❌ %s" % msg)

func _finish() -> void:
	print("")
	print("通过 %d / 失败 %d" % [_pass, _fail])
	if _fail == 0:
		print("✅ 全部通过")
	else:
		print("❌ 失败 %d 项" % _fail)
	quit(0 if _fail == 0 else 1)

func _run() -> void:
	await process_frame
	print("\n====== Build 与敌人规则回归测试 ======")
	await _test_stat_cap()
	await _test_supply_branch()
	await _test_exploder_drops()
	await _test_drop_clamping()
	await _test_silver_merge_clamp()
	await _test_summoner()
	await _test_ranged_unlock_by_combat_room()
	await _test_boss_barrage_windup()
	await _test_daily_upgrade_rng()
	await _test_banish_not_bypassed()
	await process_frame
	# 等最后一声音效播完：音效还在播放时退出会报"资源仍在使用"
	await create_timer(0.8).timeout
	_cleanup()
	await process_frame
	_finish()

# ==================== ⑩ 放逐不能被补给兜底绕过 ====================

func _test_banish_not_bypassed() -> void:
	print("\n=== ⑩ 放逐不能被补给兜底绕过 ===")
	var scene_root := _make_scene_root()
	var player: Variant = _instantiate("res://scenes/player/player.tscn")
	scene_root.add_child(player)
	var ui: Variant = _instantiate("res://scenes/ui/upgrade_ui.tscn")
	scene_root.add_child(ui)
	ui.set("player", player)
	await process_frame

	_check(ui.has_method("_available_basic_rewards"),
		"升级界面提供统一的补给卡出口 _available_basic_rewards()")

	# 用真实 apply_upgrade 把共享预算用满 → 补给卡才有资格进池
	var spent: int = _spend_stat_budget(player)
	_check(spent == TOTAL_STAT_BUDGET,
		"通过真实 apply_upgrade 路径用满 %d 级预算（实际 %d）" % [TOTAL_STAT_BUDGET, spent])

	var pool: Array = ui.call("_get_available_options")
	_check(_count_type(pool, "basic") > 0,
		"预算用满后补给卡进入可选池（实际 %d 张）" % _count_type(pool, "basic"))

	# 放逐一张补给卡
	_check(bool(ui.call("_on_banish_clicked", {"id": "heal", "name": "生命恢复", "desc": "", "type": "basic"})),
		"放逐补给卡成功")
	pool = ui.call("_get_available_options")
	_check(not _contains(pool, "basic", "heal"),
		"被放逐的补给卡不再出现在可选池里")

	if ui.has_method("_available_basic_rewards"):
		var basics: Array = ui.call("_available_basic_rewards")
		_check(not _contains(basics, "basic", "heal"),
			"补给兜底出口同样过滤了被放逐的卡（%s）" % str(basics))

	# 三张补给卡全放逐 → 连兜底也不能把它们放回来
	for id in ["gold", "damage_boost"]:
		ui.call("_on_banish_clicked", {"id": id, "name": id, "desc": "", "type": "basic"})
	if ui.has_method("_available_basic_rewards"):
		var basics: Array = ui.call("_available_basic_rewards")
		_check(basics.is_empty(),
			"补给卡全被放逐后兜底出口为空（%s）" % str(basics))

	# 实机路径：界面这一轮不能发出任何补给卡
	ui.call("_render_options")
	var shown: Array = ui.get("current_options")
	var leaked: bool = false
	for o in shown:
		if String(o.get("type", "")) == "basic":
			leaked = true
	_check(not leaked,
		"补给卡全被放逐后，界面这一轮不发补给卡（当前 %d 张）" % shown.size())

	_clear_roots()
	await process_frame

# ==================== 工具 ====================

func _make_scene_root() -> Node2D:
	var node := Node2D.new()
	root.add_child(node)
	current_scene = node
	_roots.append(node)
	return node

func _clear_roots() -> void:
	## 分段之间清场：残留的墙/玩家/敌人会串到下一段
	current_scene = null
	for node in _roots:
		if is_instance_valid(node):
			node.free()
	_roots.clear()
	_clear_object_pool()

func _cleanup() -> void:
	_clear_roots()
	_stop_all_sfx()
	_restore_daily()

func _clear_object_pool() -> void:
	var pool := root.get_node_or_null("ObjectPool")
	if pool != null and pool.has_method("clear_all"):
		pool.clear_all()

func _stop_all_sfx() -> void:
	var mgr := root.get_node_or_null("AudioManager")
	if mgr == null:
		return
	# BGM 也得停：主场景一启动就会播战斗 BGM，
	# 脚本退出时 AudioStreamMP3 还被播放器引用着 → 引擎报"资源仍在使用"。
	# 淡入淡出的 tween 也要先杀掉：它的回调会在稍后把 stream 又塞回去。
	var bgm_tween = mgr.get("_bgm_tween")
	if bgm_tween is Tween:
		(bgm_tween as Tween).kill()
	var bgm = mgr.get("_bgm_player")
	if bgm is AudioStreamPlayer:
		(bgm as AudioStreamPlayer).stop()
		(bgm as AudioStreamPlayer).stream = null
	var players = mgr.get("_sfx_players")
	if players == null:
		return
	for p in players:
		if p is AudioStreamPlayer:
			(p as AudioStreamPlayer).stop()
			(p as AudioStreamPlayer).stream = null

func _instantiate(scene_path: String) -> Variant:
	## 返回 Variant：测试里要访问各脚本自己的字段，静态类型会挡住动态调用
	var packed: PackedScene = load(scene_path)
	if packed == null:
		return null
	return packed.instantiate()

func _make_room(width: float, height: float) -> Variant:
	var room := Node2D.new()
	room.set_script(load("res://scripts/map/game_room.gd"))
	room.room_width = width
	room.room_height = height
	room.name = "GameRoom"
	return room

func _room_bounds(room: Variant) -> Rect2:
	return room.call("get_room_bounds")

func _count_type(opts: Array, type_name: String) -> int:
	var n := 0
	for o in opts:
		if String(o.get("type", "")) == type_name:
			n += 1
	return n

func _contains(opts: Array, type_name: String, id: String) -> bool:
	for o in opts:
		if String(o.get("type", "")) == type_name and String(o.get("id", "")) == id:
			return true
	return false

func _group_nodes(group: String) -> Array:
	return get_nodes_in_group(group)

func _count_enemy_bullets() -> int:
	## 统计当前场景里的敌方弹丸（Boss 弹幕、敌方投射物）
	var n := 0
	if current_scene == null:
		return n
	for c in current_scene.get_children():
		if c is Area2D and (c.collision_layer & ENEMY_BULLET_LAYER) != 0:
			n += 1
	return n

func _is_combat_room_type(t: String) -> bool:
	return t == "combat" or t == "fog" or t == "mirror"

func _max_all_stats(player: Variant, max_lv: int) -> bool:
	## 把玩家的全部属性卡等级拉满。
	## **只用于旧路径**；现在共享预算由真实 apply_upgrade 路径消耗，
	## 保留这个辅助函数只为在缺接口时安全退出。
	if player == null or not ("stat_levels" in player):
		return false
	var levels: Dictionary = {}
	for id in ["damage", "speed", "shoot_speed", "max_hp", "armor", "pickup_range"]:
		levels[id] = max_lv
	player.set("stat_levels", levels)
	return true

func _spend_stat_budget(player: Variant) -> int:
	## 通过**真实 apply_upgrade 路径**花满共享预算。
	## 早前的测试直接往 stat_levels 里塞字典，那是"测试自己造的状态"，
	## 走不到实机路径（真实玩家只能靠选卡升级），测不出补给卡到底可达不可达。
	## 注意：预算是 12，单卡 5 级，所以不能简单地"3 张卡拉满"（=15 会超），
	## 必须按预算逐个花——花到预算为止，剩下的申请应被判满并拒绝。
	if player == null or not player.has_method("apply_upgrade"):
		return -1
	var guard: int = 0
	for id in ["damage", "speed", "shoot_speed", "max_hp", "armor", "pickup_range"]:
		for i in range(STAT_MAX_LEVEL):
			if not player.has_method("is_stat_budget_exhausted"):
				break
			if bool(player.call("is_stat_budget_exhausted")):
				break
			player.apply_upgrade(id)
			guard += 1
			if guard > TOTAL_STAT_BUDGET + STAT_MAX_LEVEL:
				break
	if not player.has_method("get_total_stat_level"):
		return -1
	return int(player.call("get_total_stat_level"))

func _backup_daily() -> void:
	_daily_backup = {
		"active": GameConfigScript.daily_active,
		"date": GameConfigScript.daily_date,
		"seed": GameConfigScript.daily_seed,
		"mods": GameConfigScript.daily_modifier_ids.duplicate(),
	}

func _restore_daily() -> void:
	if _daily_backup.is_empty():
		return
	GameConfigScript.daily_active = bool(_daily_backup.get("active", false))
	GameConfigScript.daily_date = String(_daily_backup.get("date", ""))
	GameConfigScript.daily_seed = int(_daily_backup.get("seed", 0))
	GameConfigScript.daily_modifier_ids = _daily_backup.get("mods", [])
	_daily_backup.clear()

# ==================== ① 属性卡 5 级上限 ====================

func _test_stat_cap() -> void:
	print("\n=== ① 属性卡上限（单卡 5 级 + 共享预算 12 级） ===")
	var scene_root := _make_scene_root()
	var player: Variant = _instantiate("res://scenes/player/player.tscn")
	scene_root.add_child(player)
	var ui: Variant = _instantiate("res://scenes/ui/upgrade_ui.tscn")
	scene_root.add_child(ui)
	ui.set("player", player)
	await process_frame

	_check(player.has_method("get_stat_max_level"),
		"玩家提供属性卡等级上限接口 get_stat_max_level()")
	if player.has_method("get_stat_max_level"):
		_check(int(player.call("get_stat_max_level")) == STAT_MAX_LEVEL,
			"单张属性卡上限是 %d 级（当前 %d）"
			% [STAT_MAX_LEVEL, int(player.call("get_stat_max_level"))])

	_check(player.has_method("get_total_stat_max_level"),
		"玩家提供属性卡共享总预算接口 get_total_stat_max_level()")
	if player.has_method("get_total_stat_max_level"):
		_check(int(player.call("get_total_stat_max_level")) == TOTAL_STAT_BUDGET,
			"属性卡共享总预算是 %d 级（当前 %d）"
			% [TOTAL_STAT_BUDGET, int(player.call("get_total_stat_max_level"))])

	var has_level_api: bool = player.has_method("get_stat_level")
	_check(has_level_api, "玩家提供属性卡等级查询接口 get_stat_level()")
	_check(player.has_method("is_stat_maxed"),
		"玩家提供属性卡满级判断接口 is_stat_maxed()")
	_check(player.has_method("get_total_stat_level"),
		"玩家提供属性卡已用总级数接口 get_total_stat_level()")

	# 未升级时 6 张属性卡都在池子里
	var opts: Array = ui.call("_get_available_options")
	_check(_count_type(opts, "stat") == 6,
		"未升级时 6 张属性卡都在可选池中（实际 %d 张）" % _count_type(opts, "stat"))

	# 等级文案要同时给出"这张卡几级"和"这局属性点还剩多少"。
	# 只给前者的话，玩家看不出"还能买几张"，触顶才发现池子空了。
	var fresh_card: Dictionary = {"id": "damage", "name": "攻击强化", "desc": "", "type": "stat"}
	var fresh_text: String = String(ui.call("_decorate_option", fresh_card).get("level_text", ""))
	_check(fresh_text.contains("Lv.1/%d" % STAT_MAX_LEVEL),
		"未升级时属性卡文案带单卡等级（%s）" % fresh_text)
	_check(fresh_text.contains("属性点 0/%d" % TOTAL_STAT_BUDGET),
		"未升级时属性卡文案带共享预算用量 0/%d（%s）" % [TOTAL_STAT_BUDGET, fresh_text])

	if not has_level_api:
		_clear_roots()
		await process_frame
		return

	# 连点 5 次同一个属性卡
	var dmg_before: float = player.damage_multiplier
	for i in range(STAT_MAX_LEVEL):
		player.apply_upgrade("damage")
	var dmg_after: float = player.damage_multiplier
	_check(int(player.call("get_stat_level", "damage")) == STAT_MAX_LEVEL,
		"攻击强化记到 %d 级（实际 %d）"
		% [STAT_MAX_LEVEL, int(player.call("get_stat_level", "damage"))])
	_check(dmg_after > dmg_before,
		"%d 级攻击强化真的叠了数值（×%.2f → ×%.2f）" % [STAT_MAX_LEVEL, dmg_before, dmg_after])

	# 花掉 5 级后，另一张卡的文案应显示预算已用 5/12
	var mid_card: Dictionary = {"id": "speed", "name": "疾行", "desc": "", "type": "stat"}
	var mid_text: String = String(ui.call("_decorate_option", mid_card).get("level_text", ""))
	_check(mid_text.contains("属性点 %d/%d" % [STAT_MAX_LEVEL, TOTAL_STAT_BUDGET]),
		"花掉 %d 级后文案显示属性点 %d/%d（%s）"
		% [STAT_MAX_LEVEL, STAT_MAX_LEVEL, TOTAL_STAT_BUDGET, mid_text])

	# 第 6 次不再生效
	player.apply_upgrade("damage")
	_check(is_equal_approx(player.damage_multiplier, dmg_after),
		"满级后再选攻击强化不再叠数值（仍为 ×%.2f）" % player.damage_multiplier)
	_check(int(player.call("get_stat_level", "damage")) == STAT_MAX_LEVEL,
		"满级后等级不再增长（仍为 %d）" % int(player.call("get_stat_level", "damage")))

	# 满级的属性卡不再进池，其他属性卡还在
	opts = ui.call("_get_available_options")
	_check(not _contains(opts, "stat", "damage"),
		"满级的属性卡不再出现在可选池里")
	_check(_contains(opts, "stat", "speed"),
		"未满级的属性卡仍在可选池里")
	_check(_count_type(opts, "stat") == 5,
		"可选池里剩下 5 张属性卡（实际 %d 张）" % _count_type(opts, "stat"))

	# --- 共享预算：预算没满时，仍按单卡上限决定谁能进池 ---
	# 预算 12 = damage 5 + speed 5 + shoot_speed 2，故意让第三张卡半途卡在预算上
	for i in range(STAT_MAX_LEVEL):
		player.apply_upgrade("speed")
	for i in range(TOTAL_STAT_BUDGET - 1 - 2 * STAT_MAX_LEVEL):
		player.apply_upgrade("shoot_speed")
	var spent: int = int(player.call("get_total_stat_level")) if player.has_method("get_total_stat_level") else -1
	_check(spent == TOTAL_STAT_BUDGET - 1,
		"用真实 apply_upgrade 花掉 %d 级预算（实际 %d）" % [TOTAL_STAT_BUDGET - 1, spent])
	# 已用 11：damage 满、speed 满、shoot_speed 1 级 → 池里剩 4 张没满的卡
	# （shoot_speed + max_hp + armor + pickup_range）
	opts = ui.call("_get_available_options")
	_check(_count_type(opts, "stat") == 4,
		"预算还剩 1 级时池里剩 4 张属性卡（实际 %d 张）" % _count_type(opts, "stat"))
	_check(_contains(opts, "stat", "shoot_speed"),
		"预算未满时没满级的属性卡仍在池里")

	# --- 预算用满：所有属性卡出池，补给卡才能进场 ---
	player.apply_upgrade("shoot_speed")
	spent = int(player.call("get_total_stat_level")) if player.has_method("get_total_stat_level") else -1
	_check(spent == TOTAL_STAT_BUDGET,
		"预算用满后总级数为 %d（实际 %d）" % [TOTAL_STAT_BUDGET, spent])

	var armor_before: float = player.armor
	player.apply_upgrade("armor")
	_check(int(player.call("get_total_stat_level")) == TOTAL_STAT_BUDGET,
		"预算用满后再选属性卡不再加级")
	_check(is_equal_approx(player.armor, armor_before),
		"预算用满后护甲真的没涨（%.1f → %.1f）" % [armor_before, player.armor])

	opts = ui.call("_get_available_options")
	_check(_count_type(opts, "stat") == 0,
		"预算用满后属性卡全部出池（实际 %d 张）" % _count_type(opts, "stat"))

	# 卡片上要能看到等级（玩家才知道自己升到几级了）
	# 用一张还没升过的卡（pickup_range），满级的卡根本不会进池
	var stat_card: Dictionary = {"id": "pickup_range", "name": "磁力吸引", "desc": "", "type": "stat"}
	var decorated: Dictionary = ui.call("_decorate_option", stat_card)
	var level_text: String = String(decorated.get("level_text", ""))
	_check(level_text.contains("Lv.1/%d" % STAT_MAX_LEVEL),
		"属性卡卡片上标出了等级上限（%s）" % level_text)
	# 共享预算也必须可见：只写 "Lv.1/5" 时玩家不知道这局属性总共能买多少，
	# 会在"再练一张新卡"和"这条线练满"之间瞎猜，触顶才发现池子空了。
	_check(level_text.contains("%d/%d" % [TOTAL_STAT_BUDGET, TOTAL_STAT_BUDGET]),
		"属性卡卡片上标出了共享属性点预算（%s）" % level_text)

	_clear_roots()
	await process_frame

# ==================== ② 补给分支可达 ====================

func _test_supply_branch() -> void:
	print("\n=== ② 补给分支可达（属性预算用满后） ===")
	var scene_root := _make_scene_root()
	var player: Variant = _instantiate("res://scenes/player/player.tscn")
	scene_root.add_child(player)
	var ui: Variant = _instantiate("res://scenes/ui/upgrade_ui.tscn")
	scene_root.add_child(ui)
	ui.set("player", player)
	await process_frame

	# 属性卡还能升级时：补给卡不该进池（它只在池耗尽后启用）
	var opts: Array = ui.call("_get_available_options")
	_check(_count_type(opts, "basic") == 0,
		"属性卡还能升级时补给卡不进池（实际 %d 张）" % _count_type(opts, "basic"))

	# 用**真实 apply_upgrade 路径**把共享预算花满（不注入字典）
	var spent: int = _spend_stat_budget(player)
	_check(spent == TOTAL_STAT_BUDGET,
		"通过真实 apply_upgrade 路径用满 %d 级预算（实际 %d）" % [TOTAL_STAT_BUDGET, spent])

	opts = ui.call("_get_available_options")
	var basic_n: int = _count_type(opts, "basic")
	_check(basic_n > 0,
		"预算用满后补给卡进入可选池（实际 %d 张）" % basic_n)
	_check(_count_type(opts, "stat") == 0,
		"预算用满后池里不再有属性卡（实际 %d 张）" % _count_type(opts, "stat"))
	if ui.has_method("draw_options"):
		var drawn: Array = ui.call("draw_options", opts)
		_check(drawn.size() == mini(3, opts.size()),
			"补给分支抽卡返回 3 张（实际 %d 张）" % drawn.size())
	else:
		_check(false, "升级界面提供可单测的抽牌入口 draw_options()")

	# 实机路径：预算用满后真正渲染出来的这一轮，属性卡位必须已被补给卡取代。
	# 注意"取代"指的是属性卡那一档：池里还有武器与被动（合法选项），
	# 所以不能要求整手 3 张全是补给卡——只能要求这一轮一张属性卡都没有。
	ui.call("_render_options")
	var shown: Array = ui.get("current_options")
	_check(shown.size() > 0,
		"预算用满后界面仍然发得出卡（当前 %d 张）" % shown.size())
	var stat_leaked: int = 0
	for o in shown:
		if String(o.get("type", "")) == "stat":
			stat_leaked += 1
	_check(stat_leaked == 0,
		"预算用满后界面这一轮的选项里没有属性卡（实际 %d 张）" % stat_leaked)
	# 补给卡必须真的可被抽到：池里的补给卡数量 = 3 张全部
	if ui.has_method("_available_basic_rewards"):
		var basics: Array = ui.call("_available_basic_rewards")
		_check(basics.size() == 3,
			"预算用满后 3 张补给卡都能进池（实际 %d 张）" % basics.size())

	_clear_roots()
	await process_frame

# ==================== ③ 自爆者掉落 ====================

func _test_exploder_drops() -> void:
	print("\n=== ③ 自爆者经验 / 银币掉落 ===")
	var scene_root := _make_scene_root()
	var room: Variant = _make_room(1280.0, 768.0)
	scene_root.add_child(room)
	var player: Variant = _instantiate("res://scenes/player/player.tscn")
	player.position = Vector2(640, 400)
	scene_root.add_child(player)
	var exploder: Variant = _instantiate("res://scenes/enemies/exploder.tscn")
	exploder.position = Vector2(640, 400)
	scene_root.add_child(exploder)
	await process_frame
	await physics_frame

	var gems_before: int = _group_nodes("xp_gems").size()
	var coins_before: int = _group_nodes("silver_coins").size()

	exploder.call("_explode")
	await process_frame
	await process_frame
	await process_frame

	var gems_after: int = _group_nodes("xp_gems").size()
	var coins_after: int = _group_nodes("silver_coins").size()
	_check(gems_after > gems_before,
		"自爆者爆炸掉经验宝石（%d → %d）" % [gems_before, gems_after])
	_check(coins_after > coins_before,
		"自爆者爆炸掉银币（%d → %d）" % [coins_before, coins_after])

	_clear_roots()
	await process_frame

# ==================== ④ 掉落点钳制走 RoomLookup ====================

func _test_drop_clamping() -> void:
	print("\n=== ④ 掉落点钳制（RoomLookup） ===")
	var scene_root := _make_scene_root()
	var room: Variant = _make_room(1280.0, 768.0)
	scene_root.add_child(room)
	var player: Variant = _instantiate("res://scenes/player/player.tscn")
	player.position = Vector2(640, 400)
	scene_root.add_child(player)

	# 敌人死在房间外（被击退/冲撞推出墙）
	var bat: Variant = _instantiate("res://scenes/enemies/bat.tscn")
	bat.position = Vector2(1600.0, 1000.0)
	scene_root.add_child(bat)
	await process_frame
	await physics_frame

	bat.call("_die")
	await process_frame
	await process_frame
	await process_frame

	var bounds: Rect2 = _room_bounds(room)
	var gems: Array = _group_nodes("xp_gems")
	_check(gems.size() > 0, "房间外死亡的敌人也掉出了经验宝石（%d 枚）" % gems.size())
	if gems.size() > 0:
		var gp: Vector2 = (gems[0] as Node2D).global_position
		_check(bounds.has_point(gp),
			"经验宝石落点被钳回房间内（%.0f, %.0f，房间 %s）"
			% [gp.x, gp.y, str(bounds)])

	var coins: Array = _group_nodes("silver_coins")
	_check(coins.size() > 0, "房间外死亡的敌人也掉出了银币（%d 枚）" % coins.size())
	if coins.size() > 0:
		var cp: Vector2 = (coins[0] as Node2D).global_position
		_check(bounds.has_point(cp),
			"银币落点被钳回房间内（%.0f, %.0f，房间 %s）"
			% [cp.x, cp.y, str(bounds)])

	_clear_roots()
	await process_frame

# ==================== ⑤ 银币合并前保证落点有效 ====================

func _test_silver_merge_clamp() -> void:
	print("\n=== ⑤ 银币合并前的落点有效性 ===")
	var scene_root := _make_scene_root()
	var room: Variant = _make_room(1280.0, 768.0)
	scene_root.add_child(room)
	var player: Variant = _instantiate("res://scenes/player/player.tscn")
	player.position = Vector2(640, 400)
	scene_root.add_child(player)

	var bounds: Rect2 = _room_bounds(room)

	# 墙外死亡：银币必须先钳回有效落点，再谈合并
	var bat: Variant = _instantiate("res://scenes/enemies/bat.tscn")
	bat.position = Vector2(1500.0, 900.0)
	scene_root.add_child(bat)
	await process_frame
	await physics_frame
	bat.call("_die")
	await process_frame
	await process_frame
	await process_frame

	var coins: Array = _group_nodes("silver_coins")
	_check(coins.size() > 0, "墙外死亡掉出了银币（%d 枚）" % coins.size())
	if coins.size() > 0:
		var coin: Node2D = coins[0] as Node2D
		_check(bounds.has_point(coin.global_position),
			"合并前的银币落点已钳到房间内（%.0f, %.0f）"
			% [coin.global_position.x, coin.global_position.y])

	# 第二只怪死在墙外同一个位置：两笔银币应该合并成一枚，
	# 而且合并后这枚银币仍然必须落在房间里。
	# 旧实现里这两枚都掉在墙外（合并位置用的是没钳过的原始坐标），
	# 玩家站在墙里根本捡不到——"看起来合并成功了，钱却不见了"。
	var bat2: Variant = _instantiate("res://scenes/enemies/bat.tscn")
	bat2.position = Vector2(1510.0, 905.0)
	scene_root.add_child(bat2)
	await process_frame
	await physics_frame
	var coins_before_merge: int = _group_nodes("silver_coins").size()
	bat2.call("_die")
	await process_frame
	await process_frame
	var coins_after_merge: int = _group_nodes("silver_coins").size()
	_check(coins_after_merge == coins_before_merge,
		"近距离的两笔银币合并成一枚（%d → %d）" % [coins_before_merge, coins_after_merge])

	var merged: Array = _group_nodes("silver_coins")
	if merged.size() > 0:
		var merged_coin: Node2D = merged[0] as Node2D
		_check(bounds.has_point(merged_coin.global_position),
			"合并后的银币仍然落在房间内（%.0f, %.0f）"
			% [merged_coin.global_position.x, merged_coin.global_position.y])
		_check(int(merged_coin.get("value")) == 2,
			"合并后的银币金额相加（value=%d）" % int(merged_coin.get("value")))

	_clear_roots()
	await process_frame

# ==================== ⑥ 召唤物 ====================

func _test_summoner() -> void:
	print("\n=== ⑥ 召唤物击杀信号 / 首次召唤间隔 ===")
	var scene_root := _make_scene_root()
	var wm_script = load("res://scripts/managers/wave_manager.gd")
	var wm: Variant = wm_script.new()
	scene_root.add_child(wm)
	var player: Variant = _instantiate("res://scenes/player/player.tscn")
	player.position = Vector2(640, 400)
	scene_root.add_child(player)
	var summoner: Variant = _instantiate("res://scenes/enemies/summoner.tscn")
	summoner.position = Vector2(640, 400)
	scene_root.add_child(summoner)
	await process_frame
	await physics_frame

	# --- 6.1 首次召唤要有间隔：进场 1 秒内不该召出小怪 ---
	var bats_before: int = _count_bats()
	await create_timer(1.0).timeout
	var bats_after: int = _count_bats()
	_check(bats_after == bats_before,
		"召唤师进场后 1.0 秒内没有召唤（%d → %d 只）" % [bats_before, bats_after])

	# --- 6.2 首次召唤在 1.5 秒延迟后真的发生 ---
	await create_timer(1.4).timeout
	var bats_first: int = _count_bats()
	_check(bats_first > bats_before,
		"召唤师在 1.5 秒延迟后确实召唤了小怪（%d → %d 只）" % [bats_before, bats_first])

	# --- 6.3 后续召唤间隔 5 秒：首次召唤后 1 秒内不会再来一次 ---
	var bats_now: int = _count_bats()
	await create_timer(1.0).timeout
	var bats_later: int = _count_bats()
	_check(bats_later == bats_now,
		"首次召唤后 1 秒内不会再次召唤（%d → %d 只）" % [bats_now, bats_later])

	# --- 6.2 召唤的小怪必须接上击杀信号 ---
	summoner.call("_summon")
	await process_frame
	await process_frame
	var bats: Array = _bat_nodes()
	_check(bats.size() > 0, "召唤师召出了小怪（%d 只）" % bats.size())

	if bats.size() > 0:
		var kills_before: int = int(wm.get("total_kills"))
		var bat: Variant = bats[0]
		bat.call("_die")
		await process_frame
		await process_frame
		var kills_after: int = int(wm.get("total_kills"))
		_check(kills_after == kills_before + 1,
			"召唤的小怪死亡会计入击杀数（%d → %d）" % [kills_before, kills_after])

	_clear_roots()
	await process_frame

func _bat_nodes() -> Array:
	## 场上所有蝙蝠节点（按脚本判定，不依赖节点名）
	var out: Array = []
	for n in get_nodes_in_group("enemies"):
		var scr = n.get_script()
		if scr == null:
			continue
		if String(scr.resource_path).ends_with("bat.gd"):
			out.append(n)
	return out

func _count_bats() -> int:
	return _bat_nodes().size()

# ==================== ⑦ 远程敌人按战斗房解禁 ====================

func _test_ranged_unlock_by_combat_room() -> void:
	print("\n=== ⑦ 第一层远程解锁按战斗房 ===")
	var dm_script = load("res://scripts/map/dungeon_manager.gd")
	var dm: Variant = dm_script.new()
	root.add_child(dm)
	dm.start_dungeon()
	var plan: Array = dm.get_room_plan()

	# --- 7.1 计数口径：只算战斗房，商店/宝箱/休息房不吃掉解禁名额 ---
	var combat_before: int = 0
	var mismatch: int = 0
	var checked: int = 0
	for i in plan.size():
		var room_type: String = dm.consume_room()
		var raw = dm.get("combat_rooms_before_current")
		var reported: int = int(raw) if raw != null else -1
		if reported != combat_before:
			mismatch += 1
		checked += 1
		if _is_combat_room_type(room_type):
			combat_before += 1
	_check(mismatch == 0,
		"每间房的已清战斗房数都与战斗房口径一致（检查 %d 间，不一致 %d 间）"
		% [checked, mismatch])

	# --- 7.2 第 1 层：前 2 间战斗房纯近战，第 3 间战斗房开始出射手 ---
	# 阈值必须是 2 而不是 3：岔路可能把一间战斗房换成变异房（变异房没有战斗），
	# 本层战斗房就只剩 3 间，阈值 3 会让整层一个射手都不刷。
	var unlock_room: int = int(GameConfigScript.get_ranged_unlock_room(1))
	_check(unlock_room == 2,
		"第 1 层的远程解禁阈值是 2（当前 %d：前 N 间战斗房纯近战）" % unlock_room)
	_check(not GameConfigScript.is_ranged_allowed(1, 0),
		"第 1 层第 1 间战斗房不刷远程")
	_check(not GameConfigScript.is_ranged_allowed(1, 1),
		"第 1 层第 2 间战斗房不刷远程")
	_check(GameConfigScript.is_ranged_allowed(1, 2),
		"第 1 层第 3 间战斗房开始刷远程")

	# --- 7.3 主流程真的按战斗房计数（不是按房间序号） ---
	await _test_main_uses_combat_room_count()
	dm.queue_free()
	await process_frame

func _test_main_uses_combat_room_count() -> void:
	var main_scene: Variant = load("res://scenes/main.tscn").instantiate()
	# 断言以猎人为基准，不许读玩家真实存档里选的角色
	main_scene.debug_force_character = "hunter"
	root.add_child(main_scene)
	await process_frame
	await process_frame

	var dm = main_scene.get("dungeon")
	var wm = main_scene.get("wave_manager")
	if dm == null or wm == null:
		_check(false, "主场景提供地下城管理器与波次管理器")
		main_scene.queue_free()
		await process_frame
		return

	# 固定房间计划：战斗 / 宝箱 / 战斗 / 战斗
	dm.set("_room_plan", ["combat", "treasure", "combat", "combat"])
	dm.set("_forks", {})
	dm.set("room_in_floor", 0)
	# 战斗房计数也归零：主场景启动时已经吃掉过第一间房，
	# 不重置的话这里的第一间会被算成"第 2 间战斗房"。
	dm.set("combat_rooms_entered", 0)
	dm.set("combat_rooms_before_current", 0)
	# 别让宝箱房的经验触发升级弹窗（会把树暂停掉）
	main_scene.get("player").set("xp_to_next_level", 999999)

	var expected: Array = [0, 1, 1, 2]
	var labels: Array = ["第 1 间战斗房", "进宝箱房后", "第 2 间战斗房", "第 3 间战斗房"]
	for i in 4:
		main_scene.call("_enter_next_room", false)
		await process_frame
		var got: int = int(wm.get("floor_rooms_cleared"))
		_check(got == int(expected[i]),
			"%s：远程解禁计数 = %d（期望 %d）" % [labels[i], got, int(expected[i])])
		# 宝箱房的家具是"先摆好、再 add_child"建出来的（main._create_room），
		# 调用点还在场景树外。房间脚本若用绝对路径 get_node 取管理器，
		# 这里只会返回 null，宝箱/金币堆/商人一个都摆不出来，却只留下
		# 一串看起来像噪音的报错。房型对应的摆件数是这条链路的验收点。
		if i == 1:
			var treasure_room = main_scene.get("current_room")
			_check(treasure_room != null and int(treasure_room.get("prop_count")) > 0,
				"宝箱房真的摆出了家具（prop_count=%d）"
					% (int(treasure_room.get("prop_count")) if treasure_room else -1))
			_check(treasure_room != null and int(treasure_room.get("decoration_count")) > 0,
				"宝箱房真的摆出了装饰（decoration_count=%d）"
					% (int(treasure_room.get("decoration_count")) if treasure_room else -1))

	main_scene.queue_free()
	await process_frame
	await process_frame

# ==================== ⑧ Boss 环形弹幕前摇 ====================

func _test_boss_barrage_windup() -> void:
	print("\n=== ⑧ Boss 环形弹幕真实前摇 ===")
	var scene_root := _make_scene_root()
	var player: Variant = _instantiate("res://scenes/player/player.tscn")
	player.position = Vector2(640, 500)
	scene_root.add_child(player)
	var boss: Variant = _instantiate("res://scenes/enemies/vampire_lord.tscn")
	boss.position = Vector2(640, 300)
	scene_root.add_child(boss)
	await process_frame
	await physics_frame

	# 跳过登场演出，直接进入战斗
	boss.set("intro_invulnerable", false)
	boss.set("attack_state", 0)
	boss.set("attack_timer", 0.0)
	await physics_frame

	var barrage_count: int = int(boss.get("barrage_count"))
	var bullets_before: int = _count_enemy_bullets()
	boss.call("_attack_barrage")
	await process_frame
	var bullets_during: int = _count_enemy_bullets()
	_check(bullets_during == bullets_before,
		"前摇期间一发都没发（%d → %d）" % [bullets_before, bullets_during])

	# 前摇期间 Boss 必须站住（不能一边滑一边蓄力）
	var pos_at_windup: Vector2 = boss.global_position
	await create_timer(0.25).timeout
	var moved: float = boss.global_position.distance_to(pos_at_windup)
	_check(moved < 1.0, "前摇期间 Boss 站定不动（位移 %.1f 像素）" % moved)
	_check(_count_enemy_bullets() == bullets_before,
		"前摇 0.25 秒后仍然一发未发")

	# 等前摇结束，环形弹幕才发出来
	var deadline: int = Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < deadline and _count_enemy_bullets() == bullets_before:
		await process_frame
	var bullets_after: int = _count_enemy_bullets()
	_check(bullets_after - bullets_before == barrage_count,
		"前摇结束后发出完整一圈弹幕（%d 发，期望 %d 发）"
		% [bullets_after - bullets_before, barrage_count])

	_clear_roots()
	await process_frame

# ==================== ⑨ 每日抽卡固定 RNG ====================

func _test_daily_upgrade_rng() -> void:
	print("\n=== ⑨ 每日升级抽卡使用局内固定 RNG ===")
	var ui_script = load("res://scripts/ui/upgrade_ui.gd")
	var ui: Variant = ui_script.new()

	_check("rng" in ui, "升级界面提供可注入的随机源（rng）")
	_check(ui.has_method("draw_options"),
		"升级界面提供可单测的抽牌入口 draw_options()")

	if not ui.has_method("draw_options"):
		ui.free()
		return

	var ids: Array = ["a", "b", "c", "d", "e", "f", "g", "h", "i", "j"]

	var rng1 := RandomNumberGenerator.new()
	rng1.seed = 424242
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 424242
	var rng3 := RandomNumberGenerator.new()
	rng3.seed = 987654

	ui.set("rng", rng1)
	var first: Array = ui.call("draw_options", ids, 0)
	ui.set("rng", rng2)
	var second: Array = ui.call("draw_options", ids, 0)
	_check(first == second,
		"同一个种子抽到同一手牌（%s vs %s）" % [str(first), str(second)])

	ui.set("rng", rng3)
	var third: Array = ui.call("draw_options", ids, 0)
	_check(first != third,
		"不同种子抽到不同手牌")

	# 普通局（rng 为空）保持原行为
	ui.set("rng", null)
	var normal_a: Array = ui.call("draw_options", ids)
	_check(normal_a.size() == mini(3, ids.size()),
		"普通局抽牌照常返回一张 3 张的手牌（%d 张）" % normal_a.size())

	ui.free()

	# --- 9.2 每日局把固定 RNG 接进升级界面 ---
	_backup_daily()
	GameConfigScript.start_daily({
		"date": "2026-11-10",
		"seed": 20261110,
		"modifiers": [],
	})

	var main_scene: Variant = load("res://scenes/main.tscn").instantiate()
	main_scene.debug_force_character = "hunter"
	root.add_child(main_scene)
	await process_frame
	await process_frame

	var upgrade_ui = main_scene.get("upgrade_ui")
	if upgrade_ui == null:
		_check(false, "主场景提供升级界面")
	else:
		var injected = upgrade_ui.get("rng")
		_check(injected != null, "每日局把固定 RNG 接进了升级界面")
		if injected != null:
			var upgrade_seed: int = int(injected.get("seed"))
			var daily_seed: int = int(GameConfigScript.daily_seed)
			_check(upgrade_seed != 0, "升级抽卡的 RNG 种子有效（%d）" % upgrade_seed)
			_check(upgrade_seed != daily_seed,
				"升级抽卡用的是独立于地图 RNG 的随机流（seed=%d ≠ 地图 %d）"
				% [upgrade_seed, daily_seed])
			# 同一每日种子必须能复现同一手牌
			var r1 := RandomNumberGenerator.new()
			r1.seed = upgrade_seed
			var r2 := RandomNumberGenerator.new()
			r2.seed = upgrade_seed
			var hand_a: Array = _draw_with(r1, ui_script, ids)
			var hand_b: Array = _draw_with(r2, ui_script, ids)
			_check(hand_a == hand_b,
				"每日种子派生的 RNG 能复现同一手牌（%s）" % str(hand_a))

	main_scene.queue_free()
	await process_frame
	await process_frame
	_restore_daily()

func _draw_with(rng: RandomNumberGenerator, ui_script: GDScript, ids: Array) -> Array:
	## 用给定随机源走一遍升级界面的抽牌入口
	var ui: Variant = ui_script.new()
	ui.set("rng", rng)
	var out: Array = ui.call("draw_options", ids)
	ui.free()
	return out
