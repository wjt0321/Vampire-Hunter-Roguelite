extends SceneTree
## 状态修饰器回归测试（17.13）
## 用法: godot --headless --path . --script res://tools/status_effect_test.gd
##
## 覆盖：
##   流血 / 霜缚 / 汲取 三个"可挂任意武器"的词条
##   流血必须走 dot_damage（不闪白、不冻帧、不吃自爆阈值）
##   急速与减速共用一条速度修正链，任一到期不互相破坏
##   玩家侧字段接线（被动卡 → bleed_chance / slow_chance / drain_ratio）

var _fail: int = 0
var _pass: int = 0
var _host: Node2D = null
var _player = null          ## 假玩家：只提供 EnemyBase 会读的那几个字段
var _died_count: int = 0    ## 必须用成员变量：lambda 对局部变量是值拷贝


class FakePlayer extends CharacterBody2D:
	## 不用真实 player.tscn：那会带来自动开火（会打死被测的怪）
	## 和一堆 autoload 依赖。EnemyBase 只读三个字段 + 一个方法，这里照着实现即可。
	var bleed_chance: float = 0.0
	var slow_chance: float = 0.0
	var drain_ratio: float = 0.0
	var drained: float = 0.0

	func on_dealt_damage(amount: float) -> void:
		drained += amount


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


func _spawn(type: String, pos: Vector2) -> Node:
	var scene: PackedScene = load("res://scenes/enemies/%s.tscn" % type)
	var e = scene.instantiate()
	e.spawn_wave = 1
	e.floor_index = 1
	e.position = pos
	_host.add_child(e)
	return e


func _run() -> void:
	await process_frame
	print("\n====== 状态修饰器测试（17.13）======")
	var gc = load("res://scripts/core/game_config.gd")
	var P = load("res://scripts/player/passive_item_data.gd")
	var ItemCatalog = load("res://scripts/core/item_catalog.gd")

	_host = Node2D.new()
	_host.name = "TestHost"
	root.add_child(_host)
	current_scene = _host
	_player = FakePlayer.new()
	_player.add_to_group("player")
	_player.position = Vector2(80, 80)
	_host.add_child(_player)
	await process_frame
	await process_frame

	# ==================== ① 常量合理性 ====================
	print("\n=== ① 常量 ===")
	var bleed_total: float = gc.BLEED_DPS_RATIO * gc.BLEED_DURATION
	_check(bleed_total >= 0.5 and bleed_total <= 1.2,
		"流血总伤 = 一次命中的 %.2f 倍（落在 0.5~1.2，不能盖过武器本身）" % bleed_total)
	_check(gc.SLOW_MULT >= 0.60 and gc.SLOW_MULT <= 0.80,
		"霜缚减速到 %.2f（不要控到死）" % gc.SLOW_MULT)
	_check(gc.SLOW_BOSS_RESIST > 0.0 and gc.SLOW_BOSS_RESIST < 1.0,
		"Boss 减速抗性 %.2f（既不能全免也不能全吃）" % gc.SLOW_BOSS_RESIST)
	_check(gc.STATUS_VFX_COOLDOWN >= 0.2,
		"同一敌人的状态判定冷却 %.2fs（高攻速下不会满覆盖）" % gc.STATUS_VFX_COOLDOWN)

	# ==================== ② 流血 ====================
	print("\n=== ② 流血 ===")
	var z = _spawn("zombie", Vector2(700, 300))
	await process_frame
	await process_frame
	# 把血池拉满：这一段只测流血曲线，不能让它中途死掉（死了对象会被 free，
	# 后面的断言会报 "previously freed" 并且协程直接断掉、整个测试挂死）
	z.max_hp = 99999.0
	z.current_hp = 99999.0
	var hp0: float = z.current_hp
	_check(not z.is_bleeding(), "初始不流血")
	z.apply_bleed(10.0, 2.5)
	_check(z.is_bleeding(), "apply_bleed 后处于流血状态")
	_check(absf(z.bleed_dps - 10.0) < 0.01, "流血 DPS = 10.0")
	_check(z.hit_stun_timer <= 0.0, "上流血的瞬间不触发受击硬直")

	await create_timer(1.6).timeout
	var lost: float = hp0 - z.current_hp
	# 1.6 秒 ≈ 3 跳 × (10 × 0.5) = 15
	_check(lost >= 8.0 and lost <= 22.0,
		"1.6 秒内流血扣血 %.1f（期望约 15 = 3 跳 × 5）" % lost)
	_check(z.hit_stun_timer <= 0.0,
		"流血 tick 不产生受击硬直（走 dot_damage，不是 take_damage）")

	# 弱流血不能覆盖强流血
	z.apply_bleed(1.0, 2.5)
	_check(absf(z.bleed_dps - 10.0) < 0.01,
		"弱流血不覆盖强流血（仍是 %.1f）" % z.bleed_dps)

	await create_timer(2.2).timeout
	_check(is_instance_valid(z) and not z.is_bleeding(), "流血到期自动结束")
	if is_instance_valid(z):
		z.queue_free()

	# ==================== ③ 减速与急速共用一条链 ====================
	print("\n=== ③ 减速 / 急速 ===")
	var v = _spawn("vampire", Vector2(700, 500))
	await process_frame
	await process_frame
	var base: float = v.move_speed
	_check(base > 0.0, "吸血鬼基础移速 %.1f" % base)

	v.apply_slow(gc.SLOW_MULT, 2.0)
	_check(absf(v.move_speed - base * gc.SLOW_MULT) < 0.5,
		"减速后移速 %.1f（期望 %.1f）" % [v.move_speed, base * gc.SLOW_MULT])

	v.apply_haste(gc.AFFIX_HASTE_DURATION)
	var both: float = base * gc.SLOW_MULT * gc.AFFIX_HASTE_MULT
	_check(absf(v.move_speed - both) < 0.5,
		"急速叠在减速上 %.1f（期望 %.1f，不是两个倍率互相覆盖）" % [v.move_speed, both])

	# 让急速先到期：剩下的减速必须还在
	await create_timer(gc.AFFIX_HASTE_DURATION + 0.25).timeout
	_check(absf(v.move_speed - base * gc.SLOW_MULT) < 0.5,
		"急速到期后减速仍在 %.1f（期望 %.1f）" % [v.move_speed, base * gc.SLOW_MULT])

	await create_timer(gc.SLOW_DURATION).timeout
	_check(absf(v.move_speed - base) < 0.5,
		"减速也到期后完全复原 %.1f（期望 %.1f）" % [v.move_speed, base])

	# Boss 抗性
	var boss = _spawn("vampire_prince", Vector2(700, 200))
	await process_frame
	await process_frame
	var boss_base: float = boss.move_speed
	boss.add_to_group("boss")
	boss.apply_slow(gc.SLOW_MULT, 2.0)
	var boss_expect: float = boss_base * lerpf(1.0, gc.SLOW_MULT, gc.SLOW_BOSS_RESIST)
	_check(absf(boss.move_speed - boss_expect) < 0.5,
		"Boss 吃到抗性减速 %.1f（期望 %.1f，普通怪会是 %.1f）"
		% [boss.move_speed, boss_expect, boss_base * gc.SLOW_MULT])
	boss.queue_free()
	v.queue_free()

	# ==================== ④ 玩家侧字段接线 ====================
	print("\n=== ④ 被动卡 → 玩家字段 ===")
	var p_script = load("res://scripts/player/player.gd")
	var fake = p_script.new()
	fake.add_passive_item(P.create_blood_edge())
	_check(absf(fake.bleed_chance - 0.25) < 0.001,
		"血刃 Lv.1 → 流血几率 %.0f%%" % (fake.bleed_chance * 100.0))
	fake.add_passive_item(P.create_blood_edge())
	_check(absf(fake.bleed_chance - 0.33) < 0.001,
		"血刃 Lv.2 → 流血几率 %.0f%%（+8%%）" % (fake.bleed_chance * 100.0))

	fake.add_passive_item(P.create_frost_bind())
	_check(absf(fake.slow_chance - 0.30) < 0.001,
		"霜缚 Lv.1 → 减速几率 %.0f%%" % (fake.slow_chance * 100.0))

	fake.add_passive_item(P.create_blood_drain())
	_check(absf(fake.drain_ratio - 0.02) < 0.001,
		"汲取 Lv.1 → 伤害转治疗 %.1f%%" % (fake.drain_ratio * 100.0))
	_check(fake.drain_ratio <= gc.PASSIVE_MAX_DRAIN, "汲取不超过上限")

	# 汲取的零头水池：不足阈值不回血
	fake.max_hp = 100.0
	fake.current_hp = 50.0
	fake.on_dealt_damage(10.0)   # 10 × 2% = 0.2，不够 2 点阈值
	_check(absf(fake.current_hp - 50.0) < 0.01,
		"零头太少时先攒着，不回血（血量 %.1f）" % fake.current_hp)
	fake.on_dealt_damage(200.0)  # 再攒 4 点 → 总量 4.2，够阈值
	_check(fake.current_hp > 51.0,
		"攒够阈值后一次结算 %.0f 点（血量 %.1f）"
		% [floorf(4.2), fake.current_hp])
	fake.free()

	# ==================== ⑤ 端到端：命中 → 状态 ====================
	print("\n=== ⑤ 命中触发（假玩家 → 真敌人）===")
	_player.bleed_chance = 1.0
	_player.slow_chance = 0.0
	var e1 = _spawn("zombie", Vector2(900, 600))
	await process_frame
	await process_frame
	# 同样拉满血：这一段要连打三下 + 流血，僵尸基础血撑不住
	e1.max_hp = 99999.0
	e1.current_hp = 99999.0
	e1.take_damage(5.0)
	_check(e1.is_bleeding(), "命中后敌人进入流血（流血几率 100%）")
	_check(absf(e1.bleed_dps - 5.0 * gc.BLEED_DPS_RATIO) < 0.01,
		"流血 DPS 按这一下的伤害折算 %.2f" % e1.bleed_dps)

	# 状态冷却：第二次命中不应重复触发新的判定（用减速来验证，因为流血取 max 看不出来）
	_player.bleed_chance = 0.0
	_player.slow_chance = 1.0
	var before_slow: float = e1.move_speed
	e1.take_damage(5.0)
	_check(absf(e1.move_speed - before_slow) < 0.01,
		"0.3 秒冷却内第二次命中不重复判定（移速未变 %.1f）" % e1.move_speed)
	await create_timer(gc.STATUS_VFX_COOLDOWN + 0.1).timeout
	e1.take_damage(5.0)
	_check(e1.move_speed < before_slow - 0.5,
		"冷却过后再命中能触发减速（%.1f → %.1f）" % [before_slow, e1.move_speed])

	# 汲取：按伤害比例回调
	_player.slow_chance = 0.0
	_player.drain_ratio = 0.5
	_player.drained = 0.0
	await create_timer(gc.STATUS_VFX_COOLDOWN + 0.1).timeout
	e1.take_damage(10.0)
	_check(absf(_player.drained - 5.0) < 0.01,
		"汲取回调拿到 0.5 × 10 = %.1f" % _player.drained)
	_player.drain_ratio = 0.0
	e1.queue_free()

	# ==================== ⑥ 流血致死只死一次 ====================
	print("\n=== ⑥ 流血致死 ===")
	var e2 = _spawn("zombie", Vector2(900, 700))
	await process_frame
	await process_frame
	_died_count = 0
	e2.enemy_died.connect(func(_who): _died_count += 1)
	e2.apply_bleed(9999.0, 2.0)
	await create_timer(0.8).timeout
	# 死亡后 0.2 秒的缩放动画结束就 queue_free 了，所以要先判有效性再读 is_dead
	_check(not is_instance_valid(e2) or e2.is_dead, "高流血把敌人打死")
	_check(_died_count == 1, "enemy_died 只触发一次（实际 %d）" % _died_count)

	# ==================== ⑦ 卡池 ====================
	print("\n=== ⑦ 卡池与图标 ===")
	var ids := []
	for opt in ItemCatalog.PASSIVES:
		ids.append(String(opt["id"]))
	for want in ["blood_edge", "frost_bind", "blood_drain"]:
		_check(want in ids, "卡池包含 %s" % want)
	_check(ItemCatalog.create_passive("blood_edge") != null, "create_passive 能造出血刃")
	# 图标必须是文字：本机字体不含 emoji，Button 上会渲染成蓝方块（GDD 附录 D.4）
	var icon_text := String(ItemCatalog.find_passive("blood_edge").get("icon", ""))
	_check(icon_text.length() == 1, "血刃图标是单个文字「%s」而非 emoji" % icon_text)

	# ==================== ⑧ 圆形弹视觉 ====================
	print("\n=== ⑧ 圆形弹亮芯 ===")
	var PV = load("res://scripts/core/projectile_visuals.gd")
	var orb: Texture2D = PV.get_orb_texture()
	var img: Image = orb.get_image()
	var c: int = int(PV.ORB_SIZE / 2)
	var solid_row: int = 0
	for y in PV.ORB_SIZE:
		if img.get_pixel(c, y).a >= 0.99:
			solid_row += 1
	_check(solid_row >= 24,
		"圆形弹实心直径 %d px / 贴图 %d px（0.16 时只有 15px）" % [solid_row, PV.ORB_SIZE])

	_finish()
