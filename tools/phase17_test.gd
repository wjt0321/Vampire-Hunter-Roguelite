extends SceneTree
## Phase 17.2 ~ 17.5 回归测试（开发用）
## 用法: godot --headless --path . --script res://tools/phase17_test.gd
## 覆盖:
##   17.2 升级重抽/跳过（免费次数、银币扣费、跳过补偿、队列）
##   17.3 进化事件化（满级+被动+宝箱）、HUD 三态、三种行为级差异
##   17.4 打击感（枪口闪光、命中冻帧、开火挤压——零位移）
##   17.5 地面预警（标记生成 + Boss 前摇状态）

var _fail: int = 0
var _upgrade_selected_count: int = 0
## 注意：测试脚本不能用 `ItemCatalog.xxx` 这种静态引用。
## --script 模式下本脚本会在 autoload 注册之前被编译，静态引用会把
## weapon_manager → AudioLib/ObjectPool 整条依赖链拖进编译，全部失败。
## 所以统一走运行时 load()。
var _catalog = null

func _cat():
	if _catalog == null:
		_catalog = load("res://scripts/core/item_catalog.gd")
	return _catalog

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ✅ %s" % msg)
	else:
		print("  ❌ %s" % msg)
		_fail += 1

func _initialize() -> void:
	_run()

func _count_projectiles() -> int:
	## 统计当前场景里的弹丸节点（按脚本路径判断，不依赖节点名）
	var n := 0
	for c in current_scene.get_children():
		var scr = c.get_script()
		if scr == null:
			continue
		var path: String = String(scr.resource_path)
		if path.contains("bullet") or path.contains("bolt"):
			n += 1
	return n

func _make_enemy(hp: float, pos: Vector2):
	var scene = load("res://scenes/enemies/bat.tscn")
	if scene == null:
		return null
	var e = scene.instantiate()
	current_scene.add_child(e)
	e.global_position = pos
	e.max_hp = hp
	e.current_hp = hp
	return e

func _run() -> void:
	await process_frame
	print("")
	print("====== Phase 17.2~17.5 回归测试 ======")

	var main_scene = load("res://scenes/main.tscn").instantiate()
	# 固定成猎人再进场景树：存档里选的角色会改变初始武器（女祭司是法球），
	# 本套断言是围绕手枪开局写的，不固定就会因为"上次玩的是谁"而随机变红。
	main_scene.debug_force_character = "hunter"
	root.add_child(main_scene)
	current_scene = main_scene
	await create_timer(3.2).timeout

	var player = main_scene.player
	var wm = main_scene.weapon_manager
	var ui = main_scene.upgrade_ui
	var hud = main_scene.hud
	var vfx = root.get_node_or_null("VFXManager")
	_check(player != null and wm != null and ui != null, "主场景依赖节点就绪")
	if player == null or wm == null or ui == null:
		_finish()
		return

	# ==================================================
	print("")
	print("--- 17.2 重抽 / 跳过 ---")
	# ==================================================
	ui.upgrade_selected.connect(func(): _upgrade_selected_count += 1)
	ui.show_upgrade(player, wm)
	_check(paused, "打开升级界面后暂停")
	_check(ui.visible, "升级界面可见")
	_check(ui.rerolls_left == GameConfig.REROLL_FREE_COUNT,
		"每局免费重抽 = %d（实际 %d）" % [GameConfig.REROLL_FREE_COUNT, ui.rerolls_left])
	_check(ui.current_options.size() == 3, "三选一：%d 张" % ui.current_options.size())
	_check(ui.options_container.get_child_count() == 3,
		"容器里正好 3 张卡（%d）" % ui.options_container.get_child_count())

	player.silver = 0
	player.silver_changed.emit(0)
	var silver_before = player.silver
	for i in range(GameConfig.REROLL_FREE_COUNT):
		_check(ui._on_reroll(), "第 %d 次免费重抽成功" % (i + 1))
	_check(ui.rerolls_left == 0, "免费次数用完（%d）" % ui.rerolls_left)
	_check(player.silver == silver_before, "免费重抽不扣银币（%d）" % player.silver)
	_check(ui.options_container.get_child_count() == 3,
		"重抽后仍是 3 张卡，没有叠加旧卡（%d）" % ui.options_container.get_child_count())

	_check(not ui._on_reroll(), "没钱时重抽被拒")
	player.add_silver(GameConfig.REROLL_SILVER_COST + 5)
	var silver_before_paid: int = player.silver
	_check(ui._on_reroll(), "有银币后付费重抽成功")
	_check(player.silver == silver_before_paid - GameConfig.REROLL_SILVER_COST,
		"付费重抽扣 %d（%d → %d）" % [GameConfig.REROLL_SILVER_COST, silver_before_paid, player.silver])

	var silver_before_skip: int = player.silver
	ui._on_skip()
	await create_timer(0.3).timeout
	_check(player.silver == silver_before_skip + GameConfig.SKIP_SILVER_REWARD,
		"跳过补偿 +%d（%d → %d）" % [GameConfig.SKIP_SILVER_REWARD, silver_before_skip, player.silver])
	_check(not ui.visible, "跳过后界面关闭")
	_check(not paused, "跳过后解除暂停")
	_check(_upgrade_selected_count == 1, "upgrade_selected 发一次（%d）" % _upgrade_selected_count)

	# 连续升级队列：一次吃多颗宝石不能丢升级
	print("")
	var pending_before: int = main_scene._pending_upgrades
	player.level_up.emit(player.current_level)
	player.level_up.emit(player.current_level)
	player.level_up.emit(player.current_level)
	_check(main_scene._pending_upgrades == pending_before + 2,
		"三次升级：弹一次、排队两次（队列 %d）" % main_scene._pending_upgrades)
	ui._on_skip()
	await create_timer(0.35).timeout
	_check(ui.visible, "关掉第一个后自动弹下一个")
	ui._on_skip()
	await create_timer(0.35).timeout
	_check(ui.visible, "第二个之后还弹第三个")
	ui._on_skip()
	await create_timer(0.35).timeout
	_check(not ui.visible and not paused, "队列清空后正常恢复")

	# ==================================================
	print("")
	print("--- 17.3 进化事件化 ---")
	# ==================================================
	var pistol = null
	for w in wm.weapons:
		if w.weapon_id == "pistol":
			pistol = w
			break
	_check(pistol != null, "初始武器存在（pistol）")
	if pistol == null:
		_finish()
		return

	# 先确认满级之前不会进入任何进化状态
	_check(wm.get_evolution_status([]).get("state", "") == "none", "未满级时状态 = none")

	pistol.current_level = pistol.max_level
	wm._create_weapon_evolution(pistol)
	_check(wm.weapon_evolutions.has("pistol"), "满级后生成进化条目")

	var status_waiting: Dictionary = wm.get_evolution_status([])
	_check(String(status_waiting.get("state", "")) == "waiting",
		"满级但没被动 → waiting（%s）" % status_waiting.get("text", ""))
	_check(String(status_waiting.get("text", "")).contains("幸运四叶草"),
		"HUD 提示写明缺哪个被动（%s）" % status_waiting.get("text", ""))

	_check(wm.try_evolve_from_chest([]).is_empty(), "条件不足时开宝箱不进化")
	_check(not wm.is_weapon_evolved("pistol"), "条件不足确实没进化")

	player.add_passive_item(_cat().create_passive("lucky_clover"))
	var status_ready: Dictionary = wm.get_evolution_status(player.get_owned_passive_items())
	_check(String(status_ready.get("state", "")) == "ready",
		"满级 + 被动齐 → ready（%s）" % status_ready.get("text", ""))

	var damage_before: float = pistol.base_damage
	var evolved: Array = wm.try_evolve_from_chest(player.get_owned_passive_items())
	_check(evolved.size() == 1, "宝箱进化 1 把武器（%d）" % evolved.size())
	_check(wm.is_weapon_evolved("pistol"), "pistol 已进化")
	_check(pistol.base_damage > damage_before,
		"进化后伤害提升（%.1f → %.1f）" % [damage_before, pistol.base_damage])
	_check(wm.try_evolve_from_chest(player.get_owned_passive_items()).is_empty(),
		"同一把武器不会二次进化")
	_check(String(wm.get_evolution_status(player.get_owned_passive_items()).get("state", "")) == "none",
		"没有待进化武器后状态回落 none")

	# HUD 三态
	hud.update_evolution("ready", "宝箱可进化：测试")
	_check(hud.evolution_label != null and hud.evolution_label.text.contains("宝箱可进化"),
		"HUD 显示 ready 文案")
	hud.update_evolution("waiting", "进化 XX：还差 YY")
	_check(hud.evolution_label.text.contains("还差"), "HUD 显示 waiting 文案")
	hud.update_evolution("none", "")
	_check(hud.evolution_label.text == "", "HUD 无待进化时清空")

	# ---------- 行为级差异 ----------
	print("")
	print("--- 17.3 三种进化行为 ---")
	var dummy = _make_enemy(9999.0, player.global_position + Vector2(320, 0))
	_check(dummy != null, "测试假人已生成")

	# 双管：一次开火正好 2 发（未进化时 Lv5 是 3 发）
	pistol.auto_aim = true
	var before_db := _count_projectiles()
	wm._fire_weapon(pistol)
	var after_db := _count_projectiles()
	_check(after_db - before_db == 2,
		"双管齐射：一次发射 2 发（实际 %d）" % (after_db - before_db))

	# 环形弹幕：魔法书一次 8 发、方向散开
	var book = wm._create_weapon_by_id("magic_book")
	wm.add_weapon(book)
	book.current_level = book.max_level
	wm._create_weapon_evolution(book)
	player.add_passive_item(_cat().create_passive("magnet"))
	wm.try_evolve_from_chest(player.get_owned_passive_items())
	_check(wm.is_weapon_evolved("magic_book"), "魔法书已进化")
	var before_radial := _count_projectiles()
	wm._fire_weapon(book)
	var radial_count := _count_projectiles() - before_radial
	_check(radial_count == 8, "环形弹幕：一次 8 发（实际 %d）" % radial_count)

	# 刀阵环绕：不再发射弹丸，改为 6 把环绕刀
	var knife = _cat().create_weapon("throwing_knife")
	wm.add_weapon(knife)
	knife.current_level = knife.max_level
	wm._create_weapon_evolution(knife)
	player.add_passive_item(_cat().create_passive("swift_boots"))
	wm.try_evolve_from_chest(player.get_owned_passive_items())
	_check(wm.is_weapon_evolved("throwing_knife"), "飞刀已进化")
	wm._fire_weapon(knife)
	await process_frame
	var blade_count: int = wm._orbit_blades.size()
	_check(blade_count == 6, "刀阵生成 6 把环绕刀（实际 %d）" % blade_count)
	var before_orbit_shots := _count_projectiles()
	wm._fire_weapon(knife)
	_check(_count_projectiles() == before_orbit_shots, "刀阵模式不再发射直线飞刀")
	wm._fire_weapon(knife)
	_check(wm._orbit_blades.size() == 6, "重复开火不会叠加刀阵（%d）" % wm._orbit_blades.size())

	# 环绕刀真的能打到人
	var victim = _make_enemy(9999.0, player.global_position + Vector2(92, 0))
	var hp_before: float = victim.current_hp
	await create_timer(0.25).timeout
	_check(is_instance_valid(victim) and victim.current_hp < hp_before,
		"环绕刀造成伤害（%.1f → %.1f）" % [hp_before, victim.current_hp if is_instance_valid(victim) else -1.0])

	# ==================================================
	print("")
	print("--- 17.4 打击感 ---")
	# ==================================================
	var flash = vfx.spawn_muzzle_flash(player.global_position, Vector2.RIGHT)
	_check(flash != null and is_instance_valid(flash), "枪口闪光节点已生成")
	_check(flash.get_child_count() > 0, "闪光有可见多边形")
	await create_timer(0.25).timeout
	_check(not is_instance_valid(flash), "闪光在 60ms 后自动销毁")

	var victim2 = _make_enemy(9999.0, player.global_position + Vector2(200, 0))
	victim2.hit_stun_timer = 0.0
	victim2.take_damage(1.0)
	_check(victim2.hit_stun_timer >= GameConfig.HIT_FREEZE_DURATION * 0.9,
		"命中冻帧生效（%.3fs）" % victim2.hit_stun_timer)

	# 开火反馈：用户反馈"发射的时候人物轻微回退"，所以现在必须是零位移的纯视觉挤压。
	# 详细断言在 tools/feedback_v2_test.gd，这里只做不回归检查。
	wm.set_process(false)
	var pos_before: Vector2 = player.global_position
	var base_scale: Vector2 = player._sprite_base_scale
	for i in range(6):
		player.apply_recoil(Vector2.LEFT)
	_check(player.global_position.distance_to(pos_before) < 0.5,
		"开火反馈不产生位移（%.2f px）" % player.global_position.distance_to(pos_before))
	_check(player.sprite.scale != base_scale, "开火瞬间精灵挤压（视觉反馈仍在）")
	await create_timer(GameConfig.PLAYER_FIRE_PUNCH_TIME * 3.0).timeout
	_check(player.sprite.scale.is_equal_approx(base_scale), "挤压在 0.08s 内回到基准")
	wm.set_process(true)

	# ==================================================
	print("")
	print("--- 17.5 地面预警 ---")
	# ==================================================
	var marker = vfx.spawn_ground_marker(player.global_position, 80.0, Color(1, 0.2, 0.2), 0.2)
	_check(marker != null and is_instance_valid(marker), "地面预警标记已生成")
	_check(marker.get_child_count() >= 2, "标记包含填充 + 描边")
	await create_timer(0.7).timeout
	_check(not is_instance_valid(marker), "预警结束后自动清理")

	# ==================================================
	print("")
	print("--- 宝箱房真实流程 ---")
	# ==================================================
	# 把经验需求拉高，避免 gain_xp 触发升级弹窗把测试卡在暂停里
	player.current_xp = 0
	player.xp_to_next_level = 999999
	var crossbow = _cat().create_weapon("crossbow")
	wm.add_weapon(crossbow)
	crossbow.current_level = crossbow.max_level
	wm._create_weapon_evolution(crossbow)
	player.add_passive_item(_cat().create_passive("lucky_clover"))  # 已有，确保条件齐
	_check(not wm.is_weapon_evolved("crossbow"), "进宝箱前弩未进化")
	main_scene._enter_treasure_room()
	await create_timer(0.2).timeout
	_check(wm.is_weapon_evolved("crossbow"), "进宝箱房后自动进化（事件触发）")

	_finish()

func _finish() -> void:
	print("")
	if _fail == 0:
		print("✅ 全部通过")
	else:
		print("❌ 失败 %d 项" % _fail)
	quit(1 if _fail > 0 else 0)
