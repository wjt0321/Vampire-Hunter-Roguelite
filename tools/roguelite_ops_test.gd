extends SceneTree
## Roguelite 池子操作回归测试：放逐 Banish + 深渊契约
## 用法: godot --headless --path . --script res://tools/roguelite_ops_test.gd
##
## 为什么单独一套：这两个功能都是"玩家对局内资源做的不可逆操作"，
## 出错的方式很隐蔽（池子过滤漏一类、次数不递减、层结束不归还生命），
## 光靠玩很难复现，必须断言。
##
## 注意：不用 class_name 静态引用（--script 模式下先于 autoload 注册编译，
## 会把整条依赖链拖进编译），统一运行时 load()。

var _fail: int = 0
## GDScript 的 lambda 对局部变量是值拷贝（写不回外层），
## 所以信号参数只能用成员变量接
var _last_kind: String = ""

func _on_test_kind(kind: String) -> void:
	_last_kind = kind

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ✅ %s" % msg)
	else:
		print("  ❌ %s" % msg)
		_fail += 1

func _initialize() -> void:
	_run()

func _finish() -> void:
	paused = false
	print("")
	if _fail == 0:
		print("✅ 全部通过")
	else:
		print("❌ 失败 %d 项" % _fail)
	quit(0 if _fail == 0 else 1)

func _count_type(opts: Array, t: String) -> int:
	var n := 0
	for o in opts:
		if String(o.get("type", "")) == t:
			n += 1
	return n

func _contains(opts: Array, t: String, id: String) -> bool:
	for o in opts:
		if String(o.get("type", "")) == t and String(o.get("id", "")) == id:
			return true
	return false

func _run() -> void:
	await process_frame
	print("")
	print("====== Roguelite 池子操作回归测试 ======")

	var main_scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	current_scene = main_scene
	await create_timer(3.2).timeout

	var player = main_scene.player
	var wm = main_scene.weapon_manager
	var ui = main_scene.upgrade_ui
	var hud = main_scene.hud

	# ==================================================
	print("")
	print("--- ① 放逐：初始状态 ---")
	# ==================================================
	_check(ui.banish_left == 3, "每局放逐次数 = %d" % ui.banish_left)
	_check(ui.banished_keys.is_empty(), "开局放逐清单为空")
	_check(not ui.banish_mode, "默认不在放逐模式")

	var base_pool: Array = ui._get_available_options()
	var base_total := base_pool.size()
	_check(base_total > 10, "初始选池 %d 项" % base_total)
	_check(_count_type(base_pool, "stat") == 6, "属性卡 6 张")
	_check(_count_type(base_pool, "passive") == 11, "被动 11 项")

	# ==================================================
	print("")
	print("--- ② 放逐：从池中永久移除 ---")
	# ==================================================
	# 挑一张"一定在池里"的被动卡来放逐（初始武器手枪不在目录里，用被动最稳）
	var victim: Dictionary = {}
	for o in base_pool:
		if String(o.get("type", "")) == "passive" and String(o.get("id", "")) == "lucky_clover":
			victim = o
	_check(not victim.is_empty(), "找到待放逐目标：幸运四叶草")

	ui.show_upgrade(player, wm)
	await process_frame
	_check(ui.visible, "升级界面已打开")

	var rerolls_before: int = ui.rerolls_left
	ui._on_banish_toggle()
	_check(ui.banish_mode, "按 B 后进入放逐模式")
	_check(ui._on_banish_clicked(victim), "放逐成功返回 true")
	_check(ui.banish_left == 2, "放逐次数 3 → 2（当前 %d）" % ui.banish_left)
	_check(ui.banished_keys.size() == 1, "清单记录 1 项")
	_check(not ui.banish_mode, "放逐后自动退出放逐模式")
	_check(ui.rerolls_left == rerolls_before,
		"放逐**不**消耗重抽次数（%d → %d）" % [rerolls_before, ui.rerolls_left])

	var after_pool: Array = ui._get_available_options()
	_check(after_pool.size() == base_total - 1,
		"选池缩小 1 项（%d → %d）" % [base_total, after_pool.size()])
	_check(not _contains(after_pool, "passive", "lucky_clover"), "幸运四叶草已从池中消失")

	# 放逐后应立刻补一手新牌，且新手牌里不能再出现被 ban 的项
	_check(not ui.current_options.is_empty(), "放逐后自动重抽，当前展示 %d 张" % ui.current_options.size())
	var leaked := false
	for o in ui.current_options:
		if String(o.get("id", "")) == "lucky_clover":
			leaked = true
	_check(not leaked, "当前展示的卡片里没有刚被 ban 的项")

	# ==================================================
	print("")
	print("--- ③ 放逐：幂等与用尽 ---")
	# ==================================================
	_check(not ui._on_banish_clicked(victim), "重复放逐同一项被拒绝")

	# 连抽若干次，确认被 ban 的项永不再出现（属性卡可重复，但被动唯一）
	var leak_rounds := 0
	for i in range(40):
		ui._on_reroll()
		for o in ui.current_options:
			if String(o.get("id", "")) == "lucky_clover":
				leak_rounds += 1
	ui.rerolls_left = 3  # 还原，避免影响后续断言
	_check(leak_rounds == 0, "重抽 40 次，被 ban 的项 0 次出现（实际 %d）" % leak_rounds)

	# 用尽剩余次数
	ui._on_banish_toggle()
	var pool_now: Array = ui._get_available_options()
	ui._on_banish_clicked(pool_now[0])
	ui._on_banish_toggle()
	pool_now = ui._get_available_options()
	ui._on_banish_clicked(pool_now[0])
	_check(ui.banish_left == 0, "3 次用尽（当前 %d）" % ui.banish_left)
	_check(not ui.can_banish(), "can_banish() 返回 false")
	_check(not ui._on_banish_toggle(), "次数用尽后无法再进放逐模式")
	_check(not ui.banish_mode, "且不会误留在放逐模式")

	# 放逐后仍然能正常选卡（不能因为加了三态把主流程堵死）
	var pick: Dictionary = ui.current_options[0]
	ui._on_option_selected(pick)
	await create_timer(0.35).timeout
	_check(not ui.visible, "放逐之后仍可正常选卡并关闭界面")

	# ==================================================
	print("")
	print("--- ④ 深渊契约：UI 与禁选闸门 ---")
	# ==================================================
	var pact = main_scene.blood_pact
	_check(pact != null, "血之祭坛节点已创建")
	if pact == null:
		_finish()
		return

	player.current_hp = player.max_hp
	pact.open(player, 1)
	await process_frame
	_check(pact.visible, "祭坛面板已显示")
	_check(paused, "打开祭坛时世界暂停")
	_check(pact.can_pact(), "满血时可以缔约")

	var got_kind := ""
	pact.pact_chosen.connect(_on_test_kind)
	pact._choose("rest")
	_check(_last_kind == "rest", "选安息发出 pact_chosen(\"rest\")")
	_check(not pact.visible, "选完自动关闭")
	_check(not paused, "关闭后世界恢复")

	# 残血时禁止缔约（否则等于让玩家自己选了自杀）
	player.current_hp = player.max_hp * 0.15
	pact.open(player, 1)
	await process_frame
	_check(not pact.can_pact(), "残血 15%% 时祭坛拒绝缔约")
	pact.close()
	await process_frame
	player.current_hp = player.max_hp

	# ==================================================
	print("")
	print("--- ⑤ 深渊契约：收益与代价 ---")
	# ==================================================
	var base_max: float = player.max_hp
	var wm_mod = main_scene.wave_manager
	_check(is_equal_approx(wm_mod.spawn_count_mult, 1.0), "未缔约时数量倍率 = 1.0")

	main_scene._on_pact_chosen("pact")
	_check(main_scene.pact_active, "契约已生效")
	_check(is_equal_approx(player.max_hp, base_max * 0.8),
		"生命上限 %.0f → %.0f（-20%%）" % [base_max, player.max_hp])
	_check(is_equal_approx(wm_mod.spawn_count_mult, GameConfig.BLOOD_PACT_COUNT_MULT),
		"数量倍率 → ×%.2f" % wm_mod.spawn_count_mult)
	_check(is_equal_approx(wm_mod.loot_mult, GameConfig.BLOOD_PACT_LOOT_MULT),
		"掉落倍率 → ×%.2f" % wm_mod.loot_mult)

	# 同层重复缔约不能二次扣上限（否则连开两间休息房能卖到 64%）
	var after_first: float = player.max_hp
	main_scene._on_pact_chosen("pact")
	_check(is_equal_approx(player.max_hp, after_first),
		"同层二次缔约不再扣上限（%.0f）" % player.max_hp)

	# ==================================================
	print("")
	print("--- ⑥ 深渊契约：层末归还 ---")
	# ==================================================
	main_scene._expire_blood_pact()
	_check(not main_scene.pact_active, "层末契约已解除")
	_check(is_equal_approx(player.max_hp, base_max),
		"生命上限归还 %.0f → %.0f" % [after_first, player.max_hp])
	_check(is_equal_approx(wm_mod.spawn_count_mult, 1.0), "数量倍率回 1.0")
	_check(is_equal_approx(wm_mod.loot_mult, 1.0), "掉落倍率回 1.0")

	# 重复归还不能二次加血上限
	main_scene._expire_blood_pact()
	_check(is_equal_approx(player.max_hp, base_max), "重复归还不会白送上限")

	# ==================================================
	print("")
	print("--- ⑦ 敌人数量与掉落的实际效果 ---")
	# ==================================================
	# 数量：base=2（第 1 波）× 1.2 = 每批平均 2.4，10 批应当正好 24
	wm_mod.current_wave = 1
	wm_mod.set_run_modifiers(1.0, 1.0)
	_check(wm_mod._get_enemies_per_spawn() == 2, "基础每批 2 只")
	wm_mod.set_run_modifiers(GameConfig.BLOOD_PACT_COUNT_MULT, 1.0)
	var total_spawn: int = 0
	for i in range(10):
		total_spawn += wm_mod._get_enemies_per_spawn()
	_check(total_spawn == 24, "契约下 10 批共 %d 只（期望 24 = 2×1.2×10）" % total_spawn)
	wm_mod.set_run_modifiers(1.0, 1.0)

	# 掉落：1 枚银币 ×1.3，直接 round 会一直给 1 枚等于没生效，必须概率进位
	var probe = load("res://scenes/enemies/vampire.tscn").instantiate()
	probe.loot_mult = GameConfig.BLOOD_PACT_LOOT_MULT
	var sum_scaled: int = 0
	for i in range(2000):
		sum_scaled += probe._loot_scaled(1)
	var avg: float = float(sum_scaled) / 2000.0
	_check(absf(avg - 1.3) < 0.06, "1 银币 ×1.3 的 2000 次均值 %.3f（期望 1.30）" % avg)
	probe.loot_mult = 1.0
	_check(probe._loot_scaled(1) == 1, "无倍率时掉落原值 1")
	probe.free()

	# ==================================================
	print("")
	print("--- ⑧ 休息房真实流程 ---")
	# ==================================================
	# 手动把下一个房间改成 rest，走一遍真实的进房流程
	var dm = main_scene.dungeon
	dm._room_plan[mini(dm.room_in_floor, dm._room_plan.size() - 1)] = "rest"
	var rt: String = main_scene._enter_next_room(false)
	_check(rt == "rest", "进入的房间类型是 rest")

	# 等淡入 + 内部 0.5s 延迟。用帧轮询而不是 create_timer：
	# 祭坛一旦 open 就会暂停树，靠 timer 等容易卡住
	var frames := 0
	while not pact.visible and frames < 240:
		await process_frame
		frames += 1
	_check(pact.visible, "进休息房自动弹出祭坛（等了 %d 帧）" % frames)

	# 契约生效后 HUD 要有标记，否则玩家打半层才发现血上限少了
	main_scene._on_pact_chosen("pact")
	await process_frame
	_check(hud._pact_text != "", "HUD 显示契约状态（%s）" % hud._pact_text)
	main_scene._expire_blood_pact()
	await process_frame
	_check(hud._pact_text == "", "契约结束后 HUD 标记清除")

	_finish()
