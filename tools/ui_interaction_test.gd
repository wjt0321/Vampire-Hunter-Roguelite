extends SceneTree
## HUD / 暂停 / 升级交互回归测试
## 用法: godot --headless --path . --script res://tools/ui_interaction_test.gd
##
## 覆盖：
##   ① 暂停所有权：多个面板嵌套时，任何一个关闭都不得解掉别人的暂停
##   ② UiFx：重复接 hover 不再叠信号；动效不再打 "缺少 metadata" 错误
##   ③ HUD：Wave/Phase 中文化、720p 字号与描边、Boss 战隐藏波次
##   ④ 升级卡：新被动只写当前效果，升级才写"当前 → 下一级"
##   ⑤ 横幅分离：toast / 进化 / 波次三条各自独立，互不覆盖
##   ⑥ 暂停菜单：可进设置、放弃本局需要二次确认
##   ⑦ 焦点：面板按钮不吃 Space（Space 是开火键）
##
## 说明：
## - 和 feedback_v2_test 一样，--script 模式下不用 class_name 静态引用
##   （autoload 未注册时会把整条依赖链拖进编译），统一运行时 load()。
## - 每个待实现 API 都先 has_method / "prop" in 守卫再调用：
##   GDScript 在 null 或不存在的成员上调用会中止整个协程，
##   quit() 就永远走不到，headless 进程会挂到超时（踩过一次）。

var _fail: int = 0
var _pause_ctrl = null
var _ui_fx = null

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ✅ %s" % msg)
	else:
		print("  ❌ %s" % msg)
		_fail += 1

func _ctrl():
	if _pause_ctrl == null:
		_pause_ctrl = load("res://scripts/ui/pause_controller.gd")
	return _pause_ctrl

func _fx():
	if _ui_fx == null:
		_ui_fx = load("res://scripts/ui/ui_fx.gd")
	return _ui_fx

func _initialize() -> void:
	_watchdog()
	_run()

func _watchdog() -> void:
	create_timer(150.0).timeout.connect(func() -> void:
		push_error("ui_interaction_test 超时：中途有断言路径中止了协程")
		quit(2))

func _collect_buttons(node: Node, out: Array) -> void:
	## 收所有"能吃掉 Space"的控件，而不只是 Button：
	## HSlider / CheckButton 聚焦后同样会把 ui_accept 抢过去。
	for c in node.get_children():
		if c is BaseButton or c is Slider or c is LineEdit \
				or c is TextEdit or c is OptionButton or c is SpinBox:
			out.append(c)
		_collect_buttons(c, out)

func _collect_labels(node: Node, out: Array) -> void:
	for c in node.get_children():
		if c is Label:
			out.append(String(c.text))
		_collect_labels(c, out)

func _run() -> void:
	await process_frame
	print("")
	print("====== HUD / 暂停 / 升级交互 回归测试 ======")

	var main_scene = load("res://scenes/main.tscn").instantiate()
	main_scene.debug_force_character = "hunter"
	root.add_child(main_scene)
	current_scene = main_scene
	await create_timer(3.2).timeout

	var player = main_scene.player
	var wm = main_scene.weapon_manager
	var hud = main_scene.hud
	var ui = main_scene.upgrade_ui
	var shop = main_scene.room_shop
	var altar = main_scene.mutation_ui
	var pact = main_scene.blood_pact
	var pause_menu = main_scene.get_node_or_null("PauseMenu")
	var boss_bar = main_scene.get_node_or_null("BossHPBar")

	await _test_pause_ownership(player, wm, ui, shop, altar, pact, pause_menu)
	await _test_ui_fx(main_scene)
	await _test_hud(main_scene, hud, boss_bar)
	await _test_upgrade_cards(ui, player, wm, shop)
	await _test_banners(hud)
	await _test_pause_menu(pause_menu)
	await _test_focus(ui, player, wm, shop, altar, pact, pause_menu, main_scene)

	if _ctrl() != null:
		_ctrl().reset_for_scene_change()
	await process_frame

	print("")
	if _fail == 0:
		print("✅ 全部通过")
	else:
		print("❌ 失败 %d 项" % _fail)
	quit(0 if _fail == 0 else 1)

# ================================================================== ① 暂停

func _test_pause_ownership(player, wm, ui, shop, altar, pact, pause_menu) -> void:
	print("")
	print("--- ① 暂停所有权（嵌套面板） ---")
	if _ctrl() == null:
		_check(false, "缺少 scripts/ui/pause_controller.gd（计数式暂停入口未实现）")
		return
	if pause_menu == null:
		_check(false, "场景里缺少 PauseMenu 节点")
		return

	# 公开 API 的语义必须是"只给场景销毁前用"。叫 force_release_all 时它读起来
	# 像"随时可以清空"，谁都能顺手在面板里调一下，把别人的暂停一起解掉。
	_check(_ctrl().has_method("reset_for_scene_change"),
		"公开重置入口命名为 reset_for_scene_change")
	_check(not _ctrl().has_method("force_release_all"),
		"force_release_all 这个歧义名字已删除")
	if not _ctrl().has_method("reset_for_scene_change"):
		return

	_ctrl().reset_for_scene_change()
	await process_frame
	_check(_ctrl().holder_count() == 0 and not paused, "起点：无持有者、未暂停")

	ui.show_upgrade(player, wm)
	await process_frame
	_check(paused, "升级面板打开 → 世界暂停")
	_check(_ctrl().holder_count() == 1, "持有者 1（实际 %d）" % _ctrl().holder_count())

	player.add_silver(200)
	shop.open(player, wm)
	await process_frame
	_check(_ctrl().holder_count() == 2, "商店叠在升级上 → 持有者 2（实际 %d）" % _ctrl().holder_count())

	shop.close()
	await process_frame
	_check(paused, "商店关闭后世界仍然暂停（升级还开着）")
	_check(_ctrl().holder_count() == 1, "只剩升级持有（实际 %d）" % _ctrl().holder_count())

	pause_menu._pause()
	await process_frame
	_check(_ctrl().holder_count() == 2, "暂停菜单叠加 → 持有者 2（实际 %d）" % _ctrl().holder_count())
	pause_menu._resume()
	await process_frame
	_check(paused, "关掉暂停菜单不解除升级的暂停")
	_check(_ctrl().holder_count() == 1, "回到 1 个持有者（实际 %d）" % _ctrl().holder_count())

	# 升级面板走真实的收尾路径（淡出补间结束后才释放）
	ui._close_and_emit()
	await create_timer(0.35).timeout
	_check(not paused, "最后一个持有者释放后才恢复运行")
	_check(_ctrl().holder_count() == 0, "持有者清零（实际 %d）" % _ctrl().holder_count())

	# 祭坛 + 契约嵌套
	altar.open(player)
	await process_frame
	pact.open(player, 1)
	await process_frame
	_check(_ctrl().holder_count() == 2, "祭坛 + 契约同时持有 2（实际 %d）" % _ctrl().holder_count())
	altar.close()
	await process_frame
	_check(paused, "祭坛关闭不解契约的暂停")
	pact.close()
	await process_frame
	_check(not paused, "两者都关闭后才恢复")
	_check(_ctrl().holder_count() == 0, "持有者清零（实际 %d）" % _ctrl().holder_count())

	# 重复关闭必须幂等：不能把计数压成负数，也不能提前解暂停
	shop.open(player, wm)
	await process_frame
	shop.close()
	shop.close()
	await process_frame
	_check(_ctrl().holder_count() == 0 and not paused,
		"重复 close 幂等（持有者 %d）" % _ctrl().holder_count())

	# 同一个面板开了又开会走到第二次 acquire：tree_exiting 判重要用 bind 后的
	# Callable，否则会给同一个节点挂上第二条连接，销毁时回调两次。
	shop.open(player, wm)
	await process_frame
	shop.close()
	await process_frame
	shop.open(player, wm)
	await process_frame
	var exit_conns: int = shop.tree_exiting.get_connections().size()
	_check(exit_conns == 1, "反复开关后 tree_exiting 只挂 1 条（实际 %d）" % exit_conns)
	shop.close()
	await process_frame
	_check(not paused, "反复开关后仍能正常恢复")

	# 所有者先被销毁（玩家死亡打断升级 / 换场景）时必须自动放过暂停，
	# 否则世界永久冻结，玩家只能重启游戏。
	var probe := Node.new()
	probe.name = "PauseProbe"
	shop.add_child(probe)
	_ctrl().acquire(probe)
	await process_frame
	_check(_ctrl().holder_count() == 1 and paused, "探针持有 → 暂停")
	probe.queue_free()
	await process_frame
	await process_frame
	_check(_ctrl().holder_count() == 0, "所有者被销毁后自动注销（持有者 %d）"
		% _ctrl().holder_count())
	_check(not paused, "所有者被销毁后自动恢复运行（tree_exiting 兜底）")

	# release 传已被释放的对象：Node.is_instance_valid 为 false，
	# 但 `owner == null` 拦不住它（已释放实例不是 null），直接调 get_instance_id
	# 会打 "previously freed instance" 错误。
	var ghost := Node.new()
	shop.add_child(ghost)
	_ctrl().acquire(ghost)
	var ghost_id: int = ghost.get_instance_id()
	ghost.free()
	_ctrl().release(ghost)
	await process_frame
	_check(_ctrl().holder_count() == 0, "release 传已释放 owner 不报错、计数归零（%d）"
		% _ctrl().holder_count())
	_check(not paused, "release 传已释放 owner 之后仍能恢复")
	_check(ghost_id != 0, "已释放 owner 的 id 仍可读（%d）" % ghost_id)

# ================================================================== ② UiFx

func _test_ui_fx(main_scene) -> void:
	print("")
	print("--- ② UiFx 不重复接信号 / 不打 meta 错误 ---")
	if _fx() == null:
		_check(false, "缺少 scripts/ui/ui_fx.gd")
		return

	var probe := Button.new()
	probe.custom_minimum_size = Vector2(120, 40)
	main_scene.add_child(probe)
	await process_frame
	_fx().hover(probe)
	_fx().hover(probe)
	_fx().hover(probe, 1.03)
	var enter_conn: int = probe.mouse_entered.get_connections().size()
	var exit_conn: int = probe.mouse_exited.get_connections().size()
	var press_conn: int = probe.pressed.get_connections().size()
	_check(enter_conn == 1, "重复 hover 后 mouse_entered 只接 1 次（实际 %d）" % enter_conn)
	_check(exit_conn == 1, "重复 hover 后 mouse_exited 只接 1 次（实际 %d）" % exit_conn)
	_check(press_conn == 1, "重复 hover 后 pressed（涟漪）只接 1 次（实际 %d）" % press_conn)
	_check(is_equal_approx(float(probe.get_meta("ui_fx_amount", 0.0)), 1.03),
		"后一次 hover 的幅度会生效，不被静默忽略（实际 %.2f）"
			% float(probe.get_meta("ui_fx_amount", 0.0)))

	probe.mouse_entered.emit()
	await create_timer(0.25).timeout
	_check(probe.has_meta(_fx().META_TWEEN), "悬停后记录补间句柄，可被后续动效接管")
	var tween_meta = probe.get_meta(_fx().META_TWEEN) if probe.has_meta(_fx().META_TWEEN) else null
	_check(tween_meta is Tween, "句柄是 Tween（实际 %s）" % str(tween_meta))
	_check(probe.scale != Vector2.ONE, "悬停确实放大了（%s）" % str(probe.scale))

	# 连续两次悬停：前一条补间必须被接管，不得越跑越硬
	probe.mouse_exited.emit()
	probe.mouse_entered.emit()
	await create_timer(0.3).timeout
	_check(probe.scale.is_equal_approx(Vector2.ONE * 1.03),
		"连打 hover/leave 后稳定在悬停幅度（%s）" % str(probe.scale))
	probe.mouse_exited.emit()
	await create_timer(0.25).timeout
	_check(probe.scale.is_equal_approx(Vector2.ONE), "移出后回到 1.0（%s）" % str(probe.scale))
	probe.queue_free()

# ================================================================== ③ HUD

func _test_hud(main_scene, hud, boss_bar) -> void:
	print("")
	print("--- ③ HUD 中文化 / 字号 / Boss 隐藏波次 ---")
	if not hud.has_method("set_boss_mode"):
		_check(false, "HUD 缺少 set_boss_mode（Boss 战隐藏无关波次未实现）")
		return

	hud.set_boss_mode(false)
	hud.update_wave(3)
	await process_frame
	_check(hud.wave_label.text == "第 3 波", "波次标签中文：%s" % hud.wave_label.text)
	_check(not hud.wave_label.text.to_lower().contains("wave"), "不再出现英文 Wave")
	_check(hud.wave_banner.visible, "波次横幅可见")
	_check(hud.wave_banner.text.contains("第 3 波"), "波次横幅中文：%s" % hud.wave_banner.text)

	var wave_fs: int = hud.wave_label.get_theme_font_size("font_size")
	var kills_fs: int = hud.kills_label.get_theme_font_size("font_size")
	var time_fs: int = hud.time_label.get_theme_font_size("font_size")
	var room_fs: int = hud.room_label.get_theme_font_size("font_size")
	_check(wave_fs >= 18, "波次字号 ≥18（实际 %d）" % wave_fs)
	_check(kills_fs >= 16, "击杀字号 ≥16（实际 %d）" % kills_fs)
	_check(time_fs >= 16, "计时字号 ≥16（实际 %d）" % time_fs)
	_check(room_fs >= 16, "房间字号 ≥16（实际 %d）" % room_fs)
	var wave_outline: int = hud.wave_label.get_theme_constant("outline_size")
	var kills_outline: int = hud.kills_label.get_theme_constant("outline_size")
	var room_outline: int = hud.room_label.get_theme_constant("outline_size")
	_check(wave_outline >= 2, "波次有描边提升对比（%d）" % wave_outline)
	_check(kills_outline >= 2, "击杀有描边提升对比（%d）" % kills_outline)
	_check(room_outline >= 2, "房间有描边提升对比（%d）" % room_outline)
	_check(not hud.time_label.text.contains("⏱"), "计时去掉 emoji 前缀：%s" % hud.time_label.text)

	hud.update_kills(42)
	await process_frame
	_check(hud.kills_label.text.contains("42"), "击杀数仍然刷新：%s" % hud.kills_label.text)

	# Boss 战：波次信息必须让位
	hud.set_boss_mode(true)
	await process_frame
	_check(not hud.wave_label.visible, "Boss 战隐藏波次标签")
	_check(not hud.wave_banner.visible, "Boss 战隐藏波次横幅")
	_check(hud.time_label.visible and hud.room_label.visible and hud.kills_label.visible,
		"Boss 战仍保留计时/房间/击杀")
	hud.update_wave(9)
	await process_frame
	_check(not hud.wave_banner.visible, "Boss 战里 update_wave 不再弹横幅")
	_check(hud.wave_label.text != "第 9 波", "Boss 战里波次标签不写新波次（%s）" % hud.wave_label.text)
	# 进 Boss 房时 main 会先写占位文案 "BOSS"。退出 Boss 模式时如果只是
	# 把 visible 打开，会先闪一下这个已经没有意义的词，然后才被
	# "拾取战利品…" 覆盖。占位文案不复活。
	var gc = load("res://scripts/core/game_config.gd")
	# 常量表要用 get_script_constant_map()：直接写 gc.ROOM_LABEL_BOSS，
	# 在常量还不存在时是编译期错误/运行期中止，RED 阶段会连断言都看不到。
	var gc_consts: Dictionary = gc.get_script_constant_map()
	var boss_label: String = String(gc_consts.get("ROOM_LABEL_BOSS", ""))
	var room_labels: Dictionary = gc_consts.get("ROOM_LABELS", {})
	_check(not boss_label.is_empty(), "GameConfig 提供 ROOM_LABEL_BOSS 常量：%s" % boss_label)
	_check(String(room_labels.get("boss", "")) == boss_label and not boss_label.is_empty(),
		"房间名表的 boss 项与 ROOM_LABEL_BOSS 是同一个常量：%s" % String(room_labels.get("boss", "")))
	var main_src: String = FileAccess.get_file_as_string("res://scripts/managers/main.gd")
	_check(main_src.contains("GameConfig.ROOM_LABELS") and not main_src.contains('"boss": "BOSS"'),
		"main 的房间名表来自 GameConfig.ROOM_LABELS，不再自带 BOSS 字面量")
	var hud_src: String = FileAccess.get_file_as_string("res://scripts/ui/hud.gd")
	_check(hud_src.contains("GameConfig.ROOM_LABEL_BOSS") and not hud_src.contains(':= "BOSS"'),
		"HUD 的 Boss 占位文案引用同一常量，不再自写 BOSS 字面量")
	hud.set_boss_mode(true)
	hud.set_wave_status(boss_label)
	await process_frame
	_check(not hud.wave_label.visible, "Boss 房里占位文案不显示")
	hud.set_boss_mode(false)
	await process_frame
	_check(not hud.wave_label.visible and hud.wave_label.text != boss_label,
		"退出 Boss 模式不闪回占位 \"%s\"（text=%s）" % [boss_label, hud.wave_label.text])

	hud.update_wave(3)
	await process_frame
	_check(hud.wave_label.visible and hud.wave_label.text == "第 3 波",
		"之后正常波次照常显示")

	if boss_bar == null:
		_check(false, "场景里缺少 BossHPBar 节点")
		return
	boss_bar.show_boss_bar("血族女王")
	boss_bar.end_intro()
	await process_frame
	_check(boss_bar.phase_label.text.contains("阶段"), "Boss 阶段中文：%s" % boss_bar.phase_label.text)
	_check(not boss_bar.phase_label.text.contains("Phase"), "不再出现英文 Phase")
	boss_bar.update_phase(1)
	await process_frame
	_check(boss_bar.phase_label.text.contains("狂暴"), "Boss 二阶段中文：%s" % boss_bar.phase_label.text)
	boss_bar.visible = false

	# ---- 走真实的 _on_wave_completed ----
	# 之前只断言 set_wave_status 的入参，等于测试自己给测试喂答案：
	# 真正写 "Wave %d 已清" 的是 main 里那一行，测试根本没碰到它。
	if not main_scene.has_method("_on_wave_completed"):
		_check(false, "main 缺少 _on_wave_completed")
		return
	var room = main_scene.current_room
	if room == null:
		_check(false, "当前没有房间，无法驱动真实清波回调")
		return
	# 传送门已生成时 _open_room_exit 会直接返回，不会把文案改写成
	# "选路 · 左…/右…"，这样断言才能稳定读到清波文案本身。
	var portal_backup: bool = bool(room.portal_spawned)
	room.portal_spawned = true
	main_scene._on_wave_completed(4)
	await process_frame
	_check(hud.wave_label.text == "第 4 波已清 · 走传送门",
		"真实 _on_wave_completed 写中文清波文案：%s" % hud.wave_label.text)
	_check(not hud.wave_label.text.to_lower().contains("wave"),
		"清波文案不含英文 Wave")
	room.portal_spawned = portal_backup

# ================================================================== ④ 升级卡

func _test_upgrade_cards(ui, player, wm, shop) -> void:
	print("")
	print("--- ④ 升级卡：新被动只写当前效果 ---")
	ui.player = player
	ui.weapon_manager = wm

	var new_passive: Dictionary = ui._decorate_option(
		{"id": "blood_edge", "name": "血刃", "desc": "命中 25% 几率使敌人流血", "type": "passive"})
	var new_desc: String = String(new_passive.get("desc", ""))
	_check(String(new_passive.get("badge", "")) == "NEW", "新被动角标 = NEW")
	_check(String(new_passive.get("level_text", "")).contains("新被动"),
		"新被动等级行：%s" % String(new_passive.get("level_text", "")))
	_check(not new_desc.contains("→"), "新被动描述不写前后对比：%s" % new_desc)
	_check(new_desc.contains("25%"), "新被动描述带当前数值：%s" % new_desc)

	player.add_passive_item(load("res://scripts/core/item_catalog.gd").create_passive("blood_edge"))
	await process_frame
	var owned_passive: Dictionary = ui._decorate_option(
		{"id": "blood_edge", "name": "血刃", "desc": "命中 25% 几率使敌人流血", "type": "passive"})
	var owned_desc: String = String(owned_passive.get("desc", ""))
	_check(String(owned_passive.get("badge", "")) == "升级", "已有被动角标 = 升级")
	_check(owned_desc.contains("→"), "升级时才写前后对比：%s" % owned_desc)

	# 数值换算不能被"只留当前效果"改坏：护盾是秒、磁铁是百分比
	var shield_owned: Dictionary = ui._decorate_option(
		{"id": "shield", "name": "能量护盾", "desc": "定期生成护盾", "type": "passive"})
	_check(String(shield_owned.get("desc", "")).contains("30s"),
		"已有护盾升级文案带当前秒数：%s" % String(shield_owned.get("desc", "")))
	# 磁铁的倍率 1.0 实际给 50px 拾取范围，不是 "+0%"。
	# 卡面必须写这件道具现在到底给多少，否则新玩家会当成空卡。
	var magnet_new: Dictionary = ui._decorate_option(
		{"id": "magnet", "name": "经验磁铁", "desc": "经验吸附范围 +30%", "type": "passive"})
	_check(String(magnet_new.get("desc", "")).contains("+50"),
		"新磁铁文案写实际拾取范围：%s" % String(magnet_new.get("desc", "")))
	_check(not String(magnet_new.get("desc", "")).contains("+0%"),
		"新磁铁不写误导性的 +0%%：%s" % String(magnet_new.get("desc", "")))

	# 每件被动都要有自己的单位说法：落到 "效果 8%%" 这种兜底文案时，
	# 玩家既不知道 8% 是什么的 8%，也不知道这件道具值不值得再投一级。
	var vague: Array = []
	for pid in ["magnet", "shield", "regeneration", "greed_ring", "berserker_blood",
			"frozen_heart", "lightning_shield", "shadow_cloak", "vampiric_fang",
			"swift_boots", "lucky_clover", "blood_edge", "frost_bind", "blood_drain"]:
		var d: Dictionary = ui._decorate_option({"id": pid, "name": pid, "desc": "", "type": "passive"})
		var text := String(d.get("desc", ""))
		if text.begins_with("效果 ") or text.is_empty():
			vague.append("%s=%s" % [pid, text])
	_check(vague.is_empty(), "14 件新被动都有具体单位文案（含糊的：%s）" % " / ".join(vague))

	# 预览必须套用真实 cap。frozen_heart 满级 raw 值 0.2593 会被
	# PASSIVE_MAX_FREEZE(0.25) 截断，vampiric_fang 满级 raw 0.2912 被
	# PASSIVE_MAX_LIFESTEAL(0.28) 截断——卡面若照 raw 值写，
	# 玩家会为一级根本不存在的增益付钱。
	player.add_passive_item(load("res://scripts/core/item_catalog.gd").create_passive("frozen_heart"))
	player.add_passive_item(load("res://scripts/core/item_catalog.gd").create_passive("vampiric_fang"))
	await process_frame
	for p in player.passive_items:
		if String(p.item_id) in ["frozen_heart", "vampiric_fang"]:
			p.current_level = 5
	var frozen_max: Dictionary = ui._decorate_option(
		{"id": "frozen_heart", "name": "冰冻之心", "desc": "", "type": "passive"})
	var vamp_max: Dictionary = ui._decorate_option(
		{"id": "vampiric_fang", "name": "吸血獠牙", "desc": "", "type": "passive"})
	var frozen_text := String(frozen_max.get("desc", ""))
	var vamp_text := String(vamp_max.get("desc", ""))
	_check(frozen_text.contains("25%"),
		"冰冻之心满级预览套用上限 25%%：%s" % frozen_text)
	_check(not frozen_text.contains("30%"),
		"冰冻之心不再显示超过上限的 raw 值：%s" % frozen_text)
	_check(vamp_text.contains("28%"),
		"吸血獠牙满级预览套用上限 28%%：%s" % vamp_text)
	_check(not vamp_text.contains("34%"),
		"吸血獠牙不再显示超过上限的 raw 值：%s" % vamp_text)

	# ---- 方案 A：下一级没有实际增益的被动视为已满 ----
	# 上限是 player 侧截断的，被动自己的 is_max_level() 只认 5 级。
	# 一旦某件道具在某级就撞上限，"可选"就是假的：卡面写 "23% → 23%"，
	# 玩家付掉一次升级，数值一动不动。
	#
	# 注意：审查意见说 frozen_heart / vampiric_fang 的 Lv4→Lv5 因 cap 数值不变，
	# 实测不是——Lv4 还没撞顶（22.86% / 25.44%），Lv5 才被截到 25% / 28%。
	# 所以这里两边都断言：真实 Lv4 必须仍可升，人造的零增益状态必须出池。
	var pd = load("res://scripts/player/passive_item_data.gd")
	if pd == null:
		_check(false, "缺少 scripts/player/passive_item_data.gd")
	elif not ("create_frozen_heart" in pd):
		_check(false, "passive_item_data 缺少 create_frozen_heart")
	else:
		var saturated = pd.create_frozen_heart()
		saturated.base_value = 0.25          # 1 级就撞 PASSIVE_MAX_FREEZE，下一级零增益
		_check(saturated.has_method("is_effectively_maxed") and saturated.is_effectively_maxed(),
			"撞上限的被动下一级零增益 → 视为已满")
		var before_cap = pd.create_frozen_heart()
		before_cap.current_level = 4
		var lv4_gain: bool = before_cap.has_method("has_gain_at_next_level") \
			and before_cap.has_gain_at_next_level()
		_check(lv4_gain, "frozen_heart Lv4 下一级仍有真实增益（22.9%% → 25.0%%）")
		_check(before_cap.has_method("is_effectively_maxed") and not before_cap.is_effectively_maxed(),
			"有增益的 Lv4 不算已满，不该被池子丢掉")
		# 当前数值下**不应**有任何被动提前撞顶：一旦有，说明某件道具的
		# Lv5 增益已被上限吃掉，得回头调 base/增速，而不是靠判定把卡悄悄藏起来。
		var early_max: Array = []
		var ic = load("res://scripts/core/item_catalog.gd")
		for po in ic.PASSIVES:
			var inst = ic.create_passive(String(po["id"]))
			if inst == null or not inst.has_method("is_effectively_maxed"):
				continue
			inst.current_level = int(inst.MAX_LEVEL) - 1
			if inst.is_effectively_maxed():
				early_max.append(String(po["id"]))
		_check(early_max.is_empty(), "现有被动都能吃到 Lv5（提前撞顶的：%s）" % " / ".join(early_max))

	# 池子层面：把 player 身上那件 frozen_heart 临时改成"4 级就到顶"，
	# 看它会不会真的离开选池。直接断言 _is_passive_maxed 只证明谓词，
	# 证明不了池子有没有把谓词用上。
	var frozen_ref = null
	for p in player.passive_items:
		if String(p.item_id) == "frozen_heart":
			frozen_ref = p
	if frozen_ref == null:
		_check(false, "player 身上缺少 frozen_heart，无法验证选池过滤")
	else:
		var vpl_backup: float = frozen_ref.value_per_level
		var lv_backup: int = frozen_ref.current_level
		frozen_ref.current_level = 4
		frozen_ref.value_per_level = 0.0      # 制造"Lv4→Lv5 零增益"
		var maxed_without_gain: bool = ui._is_passive_maxed("frozen_heart")
		var pool_has_frozen := false
		for opt in ui._get_available_options():
			if String(opt.get("id", "")) == "frozen_heart":
				pool_has_frozen = true
		var shop_says_maxed: bool = shop._is_passive_maxed("frozen_heart")
		# 立刻还原：后面的断言和后续用例都要看到原本的被动状态
		frozen_ref.value_per_level = vpl_backup
		frozen_ref.current_level = lv_backup
		_check(maxed_without_gain, "下一级零增益的被动判定为已满")
		_check(not pool_has_frozen, "下一级零增益的被动不再进升级池")
		_check(shop_says_maxed, "商店按同一条规则过滤（不再出现两套满级判定）")

	# Task 3 的属性卡文案必须保留
	var stat_card: Dictionary = ui._decorate_option(
		{"id": "damage", "name": "攻击强化", "desc": "攻击力 +20%", "type": "stat"})
	var stat_text: String = String(stat_card.get("level_text", ""))
	_check(stat_text.contains("Lv.1/5"), "属性卡保留 Lv.N/5：%s" % stat_text)
	_check(stat_text.contains("属性点") and stat_text.contains("/12"),
		"属性卡保留属性点预算：%s" % stat_text)
	_check(stat_text.contains("→"), "属性卡仍写前后数值：%s" % stat_text)

# ================================================================== ⑤ 横幅

func _test_banners(hud) -> void:
	print("")
	print("--- ⑤ 横幅分离：toast / 进化 / 波次 ---")
	if not ("_evolution_banner" in hud) or not ("_toast_banner" in hud):
		_check(false, "HUD 缺少独立的 _evolution_banner / _toast_banner 节点")
		return
	if hud._evolution_banner == null or hud._toast_banner == null:
		_check(false, "进化 / toast 横幅节点未创建")
		return

	_check(hud._evolution_banner != hud.wave_banner and hud._toast_banner != hud.wave_banner,
		"三条横幅不是同一个 Label")

	hud.update_wave(4)
	hud.show_evolution_banner("血刃 → 血之刃")
	hud.show_toast("攻击 ×1.20 → ×1.30")
	await process_frame
	_check(hud.wave_banner.visible and hud.wave_banner.text.contains("第 4 波"),
		"波次横幅内容未被覆盖：%s" % hud.wave_banner.text)
	_check(hud._evolution_banner.visible and hud._evolution_banner.text.contains("血之刃"),
		"进化横幅内容独立：%s" % hud._evolution_banner.text)
	_check(hud._toast_banner.visible and hud._toast_banner.text.contains("×1.30"),
		"toast 内容独立：%s" % hud._toast_banner.text)
	_check(not hud.wave_banner.text.contains("×1.30"), "toast 不再借用波次横幅")
	_check(not hud.wave_banner.text.contains("进化"), "进化不再借用波次横幅")

# ================================================================== ⑥ 暂停菜单

func _test_pause_menu(pause_menu) -> void:
	print("")
	print("--- ⑥ 暂停菜单：设置 + 放弃确认 ---")
	if pause_menu == null:
		_check(false, "场景里缺少 PauseMenu 节点")
		return
	if not ("settings_panel" in pause_menu):
		_check(false, "暂停菜单缺少 settings_panel（设置入口未实现）")
		return

	_check(pause_menu.settings_panel != null, "暂停菜单有设置面板")
	_check(not pause_menu.settings_panel.visible, "设置面板默认收起")

	# 先进设置、再退出：确认放弃本局的上膛状态不应该跟着"进了一趟设置"活下来。
	# 否则「点放弃 → 反悔 → 看眼设置 → 关设置 → 不小心又点一下」就直接退出，
	# 二次确认等于失效。
	pause_menu._on_abandon_pressed()
	await process_frame
	_check(pause_menu._abandon_armed, "点放弃后上膛")
	pause_menu._on_settings_pressed()
	await process_frame
	_check(not pause_menu._abandon_armed, "进入设置会解除放弃确认的上膛")

	pause_menu._on_settings_pressed()
	await process_frame
	_check(pause_menu.settings_panel.visible, "点设置后展开")
	# 两块面板在同一个 CenterContainer 里，同时显示会重叠。
	# 截图验收时看到"放弃本局"从设置面板下方透出来，才发现这一条。
	_check(not pause_menu.panel.visible, "展开设置时暂停主面板收起，不与设置重叠")
	var settings_texts: Array = []
	_collect_labels(pause_menu.settings_panel, settings_texts)
	var settings_joined: String = " | ".join(settings_texts)
	_check(settings_joined.contains("音乐") and settings_joined.contains("音效"),
		"设置面板含音量项：%s" % settings_joined)
	_check(pause_menu.music_slider != null and pause_menu.sfx_slider != null,
		"设置面板挂了真实的音量滑块")
	pause_menu._on_settings_back_pressed()
	await process_frame
	_check(not pause_menu.settings_panel.visible, "返回后设置面板收起")
	_check(pause_menu.panel.visible, "返回后暂停主面板恢复")
	# 音量滑块要显示当前百分比：set_value_no_signal 不触发 value_changed，
	# 只同步滑块位置的话右边那格数字会一直空着。
	var pct_label: Label = pause_menu.music_slider.get_meta("value_label")
	_check(pct_label != null and pct_label.text.contains("%"),
		"音量滑块显示当前百分比（%s）" % (pct_label.text if pct_label else "null"))

	# 放弃本局：第一次只上膛，第二次才真的走
	if _ctrl() != null:
		_ctrl().reset_for_scene_change()
	var navigated: Dictionary = {"count": 0}
	pause_menu.go_to_main_menu = func() -> void: navigated["count"] += 1
	GameConfig.abyss_level = 3
	pause_menu._pause()
	await process_frame
	pause_menu._on_abandon_pressed()
	await process_frame
	_check(navigated["count"] == 0, "第一次点放弃不立刻退出（防止误点）")
	_check(pause_menu._abandon_armed, "进入待确认状态")
	_check(GameConfig.abyss_level == 3, "待确认阶段不动深渊等级")
	pause_menu._on_abandon_pressed()
	await process_frame
	_check(navigated["count"] == 1, "第二次点放弃才真正退出")
	_check(GameConfig.abyss_level == 0, "放弃本局会放弃深渊（实际 %d）" % GameConfig.abyss_level)
	_check(not paused, "放弃本局后世界不再暂停")
	GameConfig.abyss_level = 0

# ================================================================== ⑦ 焦点

## Space 是开火键。Godot 的 Button 默认 focus_mode = FOCUS_ALL，只要还有
## 控件吃到焦点，按 Space 就会先被 ui_accept 吞掉——玩家按一下以为自己开枪，
## 实际上把「放弃本局」/「选择角色」按了下去。所以**任何**界面上的按钮都必须是
## FOCUS_NONE，而不只是暂停/升级这类游戏内面板。
func _focus_violations(buttons: Array, label: String) -> void:
	var focusable: int = 0
	var samples: Array = []
	for b in buttons:
		if b.focus_mode != Control.FOCUS_NONE:
			focusable += 1
			if samples.size() < 4:
				var shown := String(b.text) if ("text" in b) else ""
				samples.append(shown if shown != "" else String(b.name))
	_check(focusable == 0,
		"%s：%d 个按钮全部 focus_mode = NONE（可聚焦 %d，例：%s）"
			% [label, buttons.size(), focusable, " / ".join(samples)])

func _test_focus(ui, player, wm, shop, altar, pact, pause_menu, main_scene) -> void:
	print("")
	print("--- ⑦ 面板按钮不吃 Space（Space = 开火） ---")
	ui.show_upgrade(player, wm)
	shop.open(player, wm)
	altar.open(player)
	pact.open(player, 1)
	await process_frame

	var buttons: Array = []
	_collect_buttons(pause_menu, buttons)
	_collect_buttons(ui, buttons)
	_collect_buttons(shop, buttons)
	_collect_buttons(altar, buttons)
	_collect_buttons(pact, buttons)
	_check(buttons.size() > 0, "收集到 %d 个面板按钮" % buttons.size())
	_focus_violations(buttons, "游戏内面板")

	shop.close()
	altar.close()
	pact.close()
	ui._close_and_emit()
	await create_timer(0.35).timeout

	await _test_focus_screens(main_scene)

# ============================================================ ⑦b 菜单类界面

func _test_focus_screens(main_scene) -> void:
	print("")
	print("--- ⑦b 主菜单 / 角色选择 / 结算界面同样不吃 Space ---")

	# --- 结算界面：深渊按钮是胜利时才动态创建的，不主动建出来就永远测不到 ---
	var game_over = main_scene.get_node_or_null("GameOverUI")
	if game_over == null:
		_check(false, "主场景里缺少 GameOverUI 节点")
	else:
		game_over.visible = true
		game_over.call("_setup_abyss_button", true)
		await process_frame
		var over_buttons: Array = []
		_collect_buttons(game_over, over_buttons)
		var has_abyss := false
		for b in over_buttons:
			if String(b.name) == "AbyssButton":
				has_abyss = true
		_check(has_abyss, "结算界面确实创建了动态深渊按钮（否则焦点断言是空跑）")
		_check(over_buttons.size() >= 3,
			"结算界面收集到 %d 个按钮（重新开始 / 返回 / 深渊）" % over_buttons.size())
		_focus_violations(over_buttons, "结算界面")
		game_over.visible = false
		await process_frame

	# --- 主菜单：角色卡按钮、每日挑战面板、元进度商店都是运行时建的 ---
	var menu = load("res://scenes/ui/main_menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	await process_frame

	var char_select = menu.get_node_or_null("CharacterSelect")
	if char_select != null:
		char_select.call("show_selection")
	var daily_panel = menu.get_node_or_null("DailyPanel")
	if daily_panel != null:
		daily_panel.call("open_today", menu.get("save_mgr"))
	var upgrade_shop = menu.get_node_or_null("UpgradeShop")
	if upgrade_shop != null:
		upgrade_shop.call("show_shop")
	await process_frame

	var menu_buttons: Array = []
	_collect_buttons(menu, menu_buttons)
	_check(menu_buttons.size() >= 8,
		"主菜单收集到 %d 个按钮（含角色卡 / 每日挑战 / 元进度商店）" % menu_buttons.size())
	_focus_violations(menu_buttons, "主菜单")

	# 角色选择是独立一层：单独断一次，出问题时定位得到是哪块
	if char_select == null:
		_check(false, "主菜单里缺少 CharacterSelect 节点")
	else:
		var char_buttons: Array = []
		_collect_buttons(char_select, char_buttons)
		_check(char_buttons.size() > 0,
			"角色选择界面收集到 %d 个按钮" % char_buttons.size())
		_focus_violations(char_buttons, "角色选择界面")

	if daily_panel != null:
		var daily_buttons: Array = []
		_collect_buttons(daily_panel, daily_buttons)
		_check(daily_buttons.size() > 0,
			"每日挑战面板收集到 %d 个按钮" % daily_buttons.size())
		_focus_violations(daily_buttons, "每日挑战面板")

	menu.queue_free()
	await process_frame
