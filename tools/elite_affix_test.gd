extends SceneTree
## 精英词缀回归测试
##
## 覆盖：词缀表随机 / 逐层概率 / 四项加成 / 血盾当 HP 用 / 裂变不无限裂 /
##       冲锋前摇-突进-收招与物理帧归还 / 急速光环加速与恢复 / 体型与掉落
##
## 用法: godot --headless --path . --script res://tools/elite_affix_test.gd
##
## 注意：不要静态引用 `EliteAffix` / `EliteAffixController` 这类 class_name。
## `--script` 模式下测试脚本在 autoload 注册前编译，静态引用会把依赖链拖进编译。

const SHIELDED := "shielded"
const SPLITTER := "splitter"
const CHARGER := "charger"
const HASTER := "haster"

var _pass: int = 0
var _fail: int = 0
var _affix = null
var _host: Node2D = null
var _dummy_player: CharacterBody2D = null

func _initialize() -> void:
	_run()

func _check(ok: bool, label: String) -> void:
	if ok:
		_pass += 1
		print("✅ %s" % label)
	else:
		_fail += 1
		print("❌ %s" % label)

func _aff():
	if _affix == null:
		_affix = load("res://scripts/enemies/elite_affix.gd")
	return _affix

func _spawn_enemy(type: String, affix_id: String, pos: Vector2, hp_scale: float = 1.0, suppress: bool = false) -> Node:
	var scene: PackedScene = load("res://scenes/enemies/%s.tscn" % type)
	var e = scene.instantiate()
	e.spawn_wave = 1
	e.floor_index = 1
	e.hp_scale = hp_scale
	e.suppress_affix = suppress
	e.elite_affix = affix_id
	e.position = pos
	_host.add_child(e)
	return e

func _run() -> void:
	await process_frame
	_host = Node2D.new()
	root.add_child(_host)
	current_scene = _host
	_dummy_player = CharacterBody2D.new()
	_dummy_player.add_to_group("player")
	_dummy_player.position = Vector2(400, 300)
	_host.add_child(_dummy_player)
	await process_frame

	print("\n=== 1. 词缀表 ===")
	var ids: Array = _aff().all_ids()
	_check(ids.size() == 4, "四个词缀（%s）" % str(ids))
	var seen := {}
	for i in range(400):
		var r: String = _aff().roll()
		_check_once(r in ids, seen, "roll 只返回合法 id")
		if r.is_empty():
			_fail += 1
			print("❌ roll 返回空")
	for id in ids:
		_check(not String(_aff().display_name(id)).is_empty(), "%s 有中文名（%s）" % [id, _aff().display_name(id)])
		_check(not String(_aff().icon(id)).is_empty(), "%s 有图标（%s）" % [id, _aff().icon(id)])
	var only_excluded: bool = true
	for i in range(100):
		if String(_aff().roll([SHIELDED, CHARGER, SPLITTER])) == SHIELDED:
			only_excluded = false
	_check(only_excluded, "exclude 生效（排除项不会出现）")

	print("\n=== 2. 逐层概率 ===")
	var c1: float = GameConfig.get_elite_affix_chance(1)
	var c2: float = GameConfig.get_elite_affix_chance(2)
	var c3: float = GameConfig.get_elite_affix_chance(3)
	_check(c1 < c2 and c2 < c3, "概率逐层递增（%.2f < %.2f < %.2f）" % [c1, c2, c3])
	_check(is_equal_approx(GameConfig.get_elite_affix_chance(9), c3), "超出层数时取最后一层的概率")

	print("\n=== 3. 统一加成 ===")
	var normal := _spawn_enemy("vampire", "", Vector2(100, 100))
	var elite := _spawn_enemy("vampire", SHIELDED, Vector2(200, 100))
	await process_frame
	await process_frame
	var expect_hp: float = float(normal.max_hp) * GameConfig.ELITE_AFFIX_HP_MULT
	var expect_total: float = expect_hp * (1.0 + GameConfig.AFFIX_SHIELD_RATIO)
	_check(absf(float(elite.max_hp) - expect_total) < 0.5,
		"血盾把护盾算进 max_hp（%.0f ≈ %.0f）" % [elite.max_hp, expect_total])
	_check(absf(float(elite.affix_shield_hp) - expect_hp * GameConfig.AFFIX_SHIELD_RATIO) < 0.5,
		"护盾量 = 加成后血量 × %.2f（%.0f）" % [GameConfig.AFFIX_SHIELD_RATIO, elite.affix_shield_hp])
	_check(is_equal_approx(float(elite.current_hp), float(elite.max_hp)), "护盾怪满血出生")
	_check(absf(float(elite.contact_damage) - float(normal.contact_damage) * GameConfig.ELITE_AFFIX_DAMAGE_MULT) < 0.01,
		"接触伤害 ×%.2f（%.1f）" % [GameConfig.ELITE_AFFIX_DAMAGE_MULT, elite.contact_damage])
	_check(int(elite.silver_value) == int(normal.silver_value * 4), "银币 ×4（%d）" % elite.silver_value)
	_check(int(elite.xp_value) == int(normal.xp_value * 2), "经验 ×2（%d）" % elite.xp_value)
	var normal_scale: float = (normal.get_node("Sprite2D") as Sprite2D).scale.x
	var elite_scale: float = (elite.get_node("Sprite2D") as Sprite2D).scale.x
	_check(elite_scale > normal_scale * 1.1, "体型更大（%.3f > %.3f）" % [elite_scale, normal_scale])
	_check(elite.has_node("AffixController"), "词缀控制器已挂载")
	_check(elite.get_node("AffixController").has_node("AffixIcon"), "头顶词缀图标存在")
	var ring = elite.get_node("AffixController").get_node_or_null("AffixRing")
	_check(ring != null, "光环存在")
	if ring != null:
		# 曾经把控制器写成 extends Node，光环/图标全画在世界原点（父节点不是 CanvasItem 就不继承变换）
		_check(ring.global_position.distance_to(elite.global_position) < 6.0,
			"光环跟着敌人走（环 %s / 敌 %s）" % [str(ring.global_position), str(elite.global_position)])

	print("\n=== 4. 血盾：护盾未破不掉血 ===")
	var hp_before: float = float(elite.current_hp)
	elite.take_damage(float(elite.affix_shield_hp) * 0.5)
	await physics_frame
	_check(absf(float(elite.affix_shield_hp) - expect_hp * GameConfig.AFFIX_SHIELD_RATIO) < 0.5,
		"打掉一半护盾时护盾值不变（护盾就是 HP）")
	_check(float(elite.current_hp) < hp_before, "但血量读数确实下降了（%.0f → %.0f）" % [hp_before, elite.current_hp])
	# 打掉 1.5 倍护盾量：留一口气，才能观测到"盾被打空"这个瞬间
	elite.take_damage(float(elite.affix_shield_hp) * 1.5)
	await physics_frame
	await physics_frame
	_check(float(elite.affix_shield_hp) <= 0.0, "护盾击穿后清零（%.0f）" % elite.affix_shield_hp)

	print("\n=== 5. 裂变 ===")
	var splitter := _spawn_enemy("vampire", SPLITTER, Vector2(600, 400))
	await process_frame
	await process_frame
	var children_before: int = _count_splitlings()
	splitter.take_damage(999999.0)
	await process_frame
	await process_frame
	await process_frame
	var children_after: int = _count_splitlings()
	_check(children_after - children_before == GameConfig.AFFIX_SPLIT_COUNT,
		"死亡裂出 %d 只（实际 %d）" % [GameConfig.AFFIX_SPLIT_COUNT, children_after - children_before])
	var kids: Array = _get_splitlings()
	var kids_ok: bool = true
	for k in kids:
		if not String(k.elite_affix).is_empty() or not bool(k.suppress_affix):
			kids_ok = false
	_check(kids_ok, "裂变体不带词缀（否则无限裂变）")
	if not kids.is_empty():
		_check(absf(float(kids[0].hp_scale) - GameConfig.AFFIX_SPLIT_HP_RATIO) < 0.01,
			"裂变体继承 %.2f 血量倍率" % GameConfig.AFFIX_SPLIT_HP_RATIO)

	print("\n=== 6. 冲锋：前摇 → 突进 → 收招 ===")
	var charger := _spawn_enemy("vampire", CHARGER, Vector2(400, 300) + Vector2(0, -200))
	await process_frame
	await process_frame
	var ctrl = charger.get_node("AffixController")
	_check(ctrl != null, "冲锋词缀挂了控制器")
	# 首次延迟 1.6s 内不该动
	var pos0: Vector2 = charger.global_position
	var max_speed_seen: float = 0.0
	for i in range(55):
		await physics_frame
		max_speed_seen = maxf(max_speed_seen, charger.velocity.length())
	_check(max_speed_seen < float(charger.move_speed) * 2.0,
		"首次延迟内只是正常追近，没有突进（峰值 %.0f px/s）" % max_speed_seen)
	# 等到进入前摇
	var saw_windup: bool = false
	var physics_disabled_in_windup: bool = false
	for i in range(60):
		await physics_frame
		if int(ctrl._charge_state) == 1:
			saw_windup = true
			physics_disabled_in_windup = not charger.is_physics_processing()
			break
	_check(saw_windup, "进入前摇（地面预警已出）")
	_check(physics_disabled_in_windup, "前摇期间剥夺宿主物理帧（否则覆写了 _physics_process 的敌人照样会动）")
	# 前摇期间不该位移
	var pos_windup: Vector2 = charger.global_position
	await create_timer(GameConfig.AFFIX_CHARGE_WINDUP * 0.5).timeout
	_check(charger.global_position.distance_to(pos_windup) < 12.0, "前摇期间原地不动（%.1fpx）"
		% charger.global_position.distance_to(pos_windup))
	# 突进
	var saw_dash: bool = false
	var dash_speed: float = 0.0
	for i in range(40):
		await physics_frame
		if int(ctrl._charge_state) == 2:
			saw_dash = true
			await physics_frame
			dash_speed = charger.velocity.length()
			break
	_check(saw_dash, "进入突进")
	_check(dash_speed > float(charger.move_speed) * 2.0,
		"突进速度是散步的 %.1f 倍（%.0f px/s）" % [dash_speed / maxf(charger.move_speed, 1.0), dash_speed])
	# 收招后物理帧必须还回去，否则这只怪会僵到死
	var restored: bool = false
	for i in range(120):
		await physics_frame
		if int(ctrl._charge_state) == 0:
			restored = charger.is_physics_processing()
			break
	_check(restored, "收招后物理帧已归还（不会僵在原地）")

	print("\n=== 7. 急速光环 ===")
	# 先摆好小怪并把"原速"记下来，再放加速者——否则第一个物理帧就被加速，基准读到的已是加速后的值
	var neighbor := _spawn_enemy("zombie", "", Vector2(940, 300))
	var far_away := _spawn_enemy("zombie", "", Vector2(900, 700))
	await process_frame
	await process_frame
	var base_speed: float = float(neighbor.move_speed)
	var far_base: float = float(far_away.move_speed)
	_check(base_speed > 0.0 and is_equal_approx(base_speed, far_base),
		"两只小怪初始同速（%.1f）" % base_speed)

	var haster := _spawn_enemy("vampire", HASTER, Vector2(900, 300))
	await create_timer(0.7).timeout
	_check(absf(float(neighbor.move_speed) - base_speed * GameConfig.AFFIX_HASTE_MULT) < 0.5,
		"光环内的小怪被加速（%.1f → %.1f，期望 %.1f）"
		% [base_speed, neighbor.move_speed, base_speed * GameConfig.AFFIX_HASTE_MULT])
	_check(absf(float(far_away.move_speed) - far_base) < 0.01,
		"光环外的小怪不受影响（%.1f）" % far_away.move_speed)

	# 加速者死掉，光环消失后加速必须自动过期
	haster.queue_free()
	await create_timer(GameConfig.AFFIX_HASTE_DURATION + 0.6).timeout
	_check(absf(float(neighbor.move_speed) - base_speed) < 0.5,
		"加速者消失后移速复原（%.1f ≈ %.1f）" % [neighbor.move_speed, base_speed])

	print("\n=== 8. 精英吸血鬼走统一词缀 ===")
	var ev := _spawn_enemy("elite_vampire", "", Vector2(200, 650))
	await process_frame
	await process_frame
	_check(not String(ev.elite_affix).is_empty(), "精英吸血鬼自动带词缀（%s）" % String(ev.elite_affix))
	_check(not String(ev.get_affix_name()).is_empty(), "get_affix_name 返回中文（%s）" % String(ev.get_affix_name()))
	var ev2 := _spawn_enemy("elite_vampire", "", Vector2(260, 650), 1.0, true)
	await process_frame
	_check(String(ev2.elite_affix).is_empty(), "suppress_affix 时不继承词缀")

	print("\n========================================")
	print("通过 %d / 失败 %d" % [_pass, _fail])
	print("========================================")
	quit(0 if _fail == 0 else 1)

func _check_once(cond: bool, seen: Dictionary, label: String) -> void:
	if seen.has(label):
		return
	seen[label] = true
	_check(cond, label)

func _count_splitlings() -> int:
	return _get_splitlings().size()

func _get_splitlings() -> Array:
	var out: Array = []
	for e in get_nodes_in_group("enemies"):
		if is_instance_valid(e) and "suppress_affix" in e and bool(e.suppress_affix):
			out.append(e)
	return out
