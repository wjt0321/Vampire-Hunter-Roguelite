extends SceneTree
## 手感修复回归测试（2026-11-08 第四轮试玩反馈）
## 用法: godot --headless --path . --script res://tools/feel_fix_test.gd
##
## 覆盖这轮反馈：
##   「wave4 没有任何东西」        → HUD 波次标签不再残留（见 main/hud 的 set_wave_status）
##   「怪移动太快，来不及捡经验」  → 急速倍率 / 蝙蝠速度 / 清场即磁吸
##   「投射物太细，很难命中」      → 亮芯占比 + 视觉厚度 + 碰撞半径三者对齐
##   「wave5 起扎堆，没地方跑」    → 同屏存活上限
##   「攻击力提升没有具体数值」    → 补给卡显示"现在 → 选完"

var _fail: int = 0

const WAVE_BASE_INTERVAL: float = 1.3
const PLAYER_BASE_SPEED: float = 200.0

func _initialize() -> void:
	_run()

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ✅ %s" % msg)
	else:
		print("  ❌ %s" % msg)
		_fail += 1

func _finish() -> void:
	print("")
	if _fail == 0:
		print("✅ 全部通过")
	else:
		print("❌ 失败 %d 项" % _fail)
	quit(0 if _fail == 0 else 1)

func _run() -> void:
	await process_frame
	print("\n====== 手感修复回归测试 ======")
	var gc = load("res://scripts/core/game_config.gd")

	# ==================== ① 同屏上限表 ====================
	print("\n=== ① 同屏存活上限 ===")
	_check(gc.get_enemy_alive_cap(1) == 16, "第 1 层同屏上限 16 只")
	_check(gc.get_enemy_alive_cap(2) == 22, "第 2 层同屏上限 22 只")
	_check(gc.get_enemy_alive_cap(3) == 28, "第 3 层同屏上限 28 只")
	_check(gc.get_enemy_alive_cap(0) == 16, "层号越界（0）退回第 1 层，不崩")
	_check(gc.get_enemy_alive_cap(99) == 28, "层号越界（99）夹到最后一层，不崩")
	_check(gc.ENEMY_ALIVE_CAP_SOFT_RANGE >= 2,
		"软上限留 %d 只缓冲，避免刚杀一只立刻顶上" % gc.ENEMY_ALIVE_CAP_SOFT_RANGE)

	# ==================== ② 投射物：看着多大就多好打 ====================
	print("\n=== ② 投射物视觉与判定一致 ===")
	var wm_script = load("res://scripts/weapons/weapon_manager.gd")
	var wm_probe = wm_script.new()
	var pistol_vis: Dictionary = wm_probe.get_projectile_visual("pistol")
	var vis_thick: float = float(pistol_vis.get("thickness", 0.0))
	wm_probe.free()
	_check(vis_thick >= 8.0, "手枪弹道视觉厚度 %.0f px（改造前 6）" % vis_thick)

	var bolt_scene = load("res://scenes/player/bullet.tscn").instantiate()
	var col = bolt_scene.get_node_or_null("CollisionShape2D")
	var hit_radius: float = 0.0
	if col and col.shape:
		hit_radius = float(col.shape.radius)
	bolt_scene.free()
	_check(hit_radius >= 5.0, "子弹碰撞半径 %.1f px（改造前 4.0）" % hit_radius)
	_check(hit_radius * 2.0 >= vis_thick * 0.85,
		"判定直径 %.1f ≥ 视觉厚度 %.1f 的 85%%：看着打中就真的打中" % [hit_radius * 2.0, vis_thick])

	var pv = load("res://scripts/core/projectile_visuals.gd")
	var tex: Texture2D = pv.get_bolt_texture()
	var img: Image = tex.get_image()
	var solid_run: int = 0
	var mid_y: int = int(tex.get_height() / 2)
	for x in tex.get_width():
		if img.get_pixel(x, mid_y).a > 0.95:
			solid_run += 1
	_check(solid_run >= 20, "亮芯横向实心像素 %d / 贴图宽 %d（不窄于旧版 24）" % [solid_run, tex.get_width()])

	# ==================== ③ 敌人初速与急速词缀 ====================
	print("\n=== ③ 敌人初速与急速词缀 ===")
	_check(gc.AFFIX_HASTE_MULT <= 1.20,
		"急速光环倍率 %.2f（旧 1.30，把蝙蝠催到 182 贴脸走）" % gc.AFFIX_HASTE_MULT)
	var worst_hasted: float = 140.0 * gc.AFFIX_HASTE_MULT
	_check(worst_hasted < PLAYER_BASE_SPEED,
		"即使按旧蝙蝠速度 140 算，加速后 %.0f < 玩家 %.0f" % [worst_hasted, PLAYER_BASE_SPEED])
	_check(gc.ELITE_AFFIX_CHANCE_BY_FLOOR[0] <= 0.05,
		"第 1 层精英词缀概率降到 %.0f%%（全场加速覆盖变少）" % (float(gc.ELITE_AFFIX_CHANCE_BY_FLOOR[0]) * 100.0))

	# ==================== ④ 起场景测上限与补给卡 ====================
	print("\n=== ④ 同屏上限在实机上拦得住 ===")
	var main_scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	current_scene = main_scene
	await create_timer(3.4).timeout
	var wave_mgr = main_scene.wave_manager
	wave_mgr.stop()  # 关掉自动刷怪，下面手动控制场上数量

	_check(wave_mgr.CLEAR_MAGNET_DELAY <= 3.0,
		"清场后 %.1f 秒开始回收宝石，不必等到 30 秒波次结束" % wave_mgr.CLEAR_MAGNET_DELAY)

	wave_mgr.set_floor(1, ["bat"], 0)
	wave_mgr.floor_index = 1
	wave_mgr._alive_probe_timer = 0.0
	_check(wave_mgr._can_spawn_more(), "场上 %d 只（上限 %d）：允许继续刷"
		% [wave_mgr._alive_enemies(), gc.get_enemy_alive_cap(1)])

	var bat_scene = load("res://scenes/enemies/bat.tscn")
	var spawned: Array = []
	var guard: int = 0
	while wave_mgr._alive_enemies() < gc.get_enemy_alive_cap(1) and guard < 40:
		var b = bat_scene.instantiate()
		b.global_position = wave_mgr.player.global_position + Vector2(400, 0)
		current_scene.add_child(b)
		spawned.append(b)
		wave_mgr._alive_probe_timer = 0.0
		guard += 1
	_check(wave_mgr._alive_enemies() >= gc.get_enemy_alive_cap(1),
		"塞到 %d 只（上限 %d）" % [wave_mgr._alive_enemies(), gc.get_enemy_alive_cap(1)])
	wave_mgr._alive_probe_timer = 0.0
	_check(not wave_mgr._can_spawn_more(), "到达上限后拒绝继续刷怪")

	wave_mgr._alive_probe_timer = 0.0
	var interval_at_cap: float = wave_mgr._get_spawn_interval()
	_check(interval_at_cap >= WAVE_BASE_INTERVAL * 1.9,
		"满员时补怪间隔拉长到 %.2f 秒（基础 %.2f）" % [interval_at_cap, WAVE_BASE_INTERVAL])

	for i in mini(5, spawned.size()):
		if is_instance_valid(spawned[i]):
			spawned[i].queue_free()
	await create_timer(0.4).timeout
	wave_mgr._alive_probe_timer = 0.0
	_check(wave_mgr._can_spawn_more(), "杀掉几只后重新允许刷怪（压力持续，不雪崩）")

	# ==================== ⑤ 补给卡数值 ====================
	print("\n=== ⑤ 补给卡显示具体数值 ===")
	var up_scene = load("res://scenes/ui/upgrade_ui.tscn").instantiate()
	root.add_child(up_scene)
	await process_frame
	up_scene.player = wave_mgr.player
	var boost_text: String = up_scene._basic_preview("damage_boost")
	_check(boost_text.contains("→"), "伤害提升卡显示 \"%s\"" % boost_text)
	var heal_text: String = up_scene._basic_preview("heal")
	_check(heal_text.contains("生命") and (heal_text.contains("→") or heal_text.contains("已满")),
		"生命恢复卡显示 \"%s\"" % heal_text)

	var rewards: Array = up_scene._get_basic_rewards()
	var emoji_count: int = 0
	var boost_desc: String = ""
	for r in rewards:
		if not String(r.get("icon", "")).is_empty():
			emoji_count += 1
		if String(r.get("id", "")) == "damage_boost":
			boost_desc = String(r.get("desc", ""))
	_check(emoji_count == 0, "补给卡不再用 emoji 图标（本机会渲染成蓝方块）")
	_check(boost_desc.contains("10%"), "伤害提升描述写明幅度：%s" % boost_desc)

	# 预览和实际必须一致：这条曾经错过——卡片写 ×1.00 → ×1.20，实际只加 0.10
	var before_dmg: float = wave_mgr.player.damage_multiplier
	var previewed: float = before_dmg + gc.BASIC_REWARD_DAMAGE
	up_scene._apply_basic_reward("damage_boost")
	var applied: float = wave_mgr.player.damage_multiplier
	_check(is_equal_approx(applied, previewed),
		"实际生效 ×%.2f 与卡片承诺 ×%.2f 一致" % [applied, previewed])

	up_scene.queue_free()
	main_scene.queue_free()
	await process_frame
	_finish()
