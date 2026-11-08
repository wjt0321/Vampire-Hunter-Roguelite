extends SceneTree
## 深渊阶梯回归测试（17.14）
## 用法: godot --headless --path . --script res://tools/abyss_ladder_test.gd
##
## 覆盖：
##   倍率函数：0 级全 1.0，N 级按步进线性
##   普通敌人实际血量/伤害吃深渊倍率（hp 链最外层）
##   Boss 形状的血量/伤害/掉落也吃深渊倍率（Boss 覆写 _ready，不走 EnemyBase 缩放）
##   掉落倍率走 loot_mult 概率进位链（不是 round 进 base 值）
##   通关血晶走 main 的真实结算函数（不是在测试里重抄公式）
##   胜利界面：真实 game_over_ui 场景的按钮文本 / 可见性 / 连接数
##   SaveManager best_abyss 只增不减（真实行为，测试子类内存落盘）
##   放弃深渊的唯一入口：暂停菜单返回主菜单会归零，深渊继续不会

var _fail: int = 0
var _pass: int = 0
var _host: Node2D = null


class FakeSave extends "res://scripts/managers/save_manager.gd":
	## 持久化全部走内存：save_game 是空操作，绝不读写 user:// 的真实玩家存档。
	## new() 不会触发 _ready（没进树），所以 load_game 也不会被调用。
	var save_calls: int = 0

	func save_game() -> void:
		save_calls += 1


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
	# 收尾：别把运行时等级泄漏给后续测试
	GameConfig.abyss_level = 0
	quit(0 if _fail == 0 else 1)


func _stop_audio() -> void:
	## 只清本测试触发过的播放器；AudioManager 的缓存是项目级资源，不动。
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
	# AudioServer 要等下一批混音才释放 playback：0.8s 是实测的稳定值
	await create_timer(0.8).timeout


class DamageProbe extends CharacterBody2D:
	## 站在 group("player") 里的替身：只记录最后一次受到多少伤害。
	## 必须是 CharacterBody2D——EnemyBase._find_player() 会 `as CharacterBody2D`，
	## 用 Node2D 会被转成 null，敌人根本拿不到玩家。
	var last_amount: float = 0.0
	var hits: int = 0

	func take_damage(amount: float, _from: Vector2 = Vector2.ZERO) -> void:
		last_amount = amount
		hits += 1


func _spawn(type: String, pos: Vector2, floor_idx: int = 1, wave: int = 1) -> Node:
	var scene: PackedScene = load("res://scenes/enemies/%s.tscn" % type)
	var e = scene.instantiate()
	e.spawn_wave = wave
	e.floor_index = floor_idx
	e.position = pos
	_host.add_child(e)
	return e


func _snapshot_area2d() -> Array:
	var seen: Array = []
	for child in _host.get_children():
		if child is Area2D:
			seen.append(child)
	return seen


func _find_new_boss_projectile(boss: Node, before: Array) -> Node:
	## 弹幕挂到 get_tree().current_scene；若该值为空，vampire_lord 会退回挂到 Boss 自身。
	## 用"新增 Area2D"而不是子节点下标区间，避免同帧 queue_free 造成下标漂移。
	for child in _host.get_children():
		if child is Area2D and not before.has(child):
			return child
	for child in boss.get_children():
		if child is Area2D:
			return child
	return null


func _run() -> void:
	await process_frame
	print("\n====== 深渊阶梯测试（17.14）======")
	_host = Node2D.new()
	_host.name = "TestHost"
	root.add_child(_host)
	current_scene = _host

	# ---------- 倍率函数 ----------
	print("\n--- 倍率函数 ---")
	GameConfig.abyss_level = 0
	_check(is_equal_approx(GameConfig.get_abyss_hp_mult(), 1.0)
		and is_equal_approx(GameConfig.get_abyss_damage_mult(), 1.0)
		and is_equal_approx(GameConfig.get_abyss_loot_mult(), 1.0),
		"0 级三个倍率都是 1.0")
	GameConfig.abyss_level = 2
	_check(is_equal_approx(GameConfig.get_abyss_hp_mult(), 1.30),
		"2 级血量 ×1.30（实际 %.2f）" % GameConfig.get_abyss_hp_mult())
	_check(is_equal_approx(GameConfig.get_abyss_damage_mult(), 1.20),
		"2 级伤害 ×1.20（实际 %.2f）" % GameConfig.get_abyss_damage_mult())
	_check(is_equal_approx(GameConfig.get_abyss_loot_mult(), 1.20),
		"2 级掉落 ×1.20（实际 %.2f）" % GameConfig.get_abyss_loot_mult())

	# ---------- 敌人属性 ----------
	print("\n--- 敌人属性 ---")
	GameConfig.abyss_level = 0
	var z0: Node = _spawn("zombie", Vector2(300, 300))
	await process_frame
	var hp0: float = z0.max_hp
	var dmg0: float = float(z0.contact_damage)
	var silver0: int = int(z0.silver_value)
	z0.queue_free()

	GameConfig.abyss_level = 2
	var z2: Node = _spawn("zombie", Vector2(600, 300))
	await process_frame
	# 敌人 base_hp 相同、波次/楼层缩放相同 → 差值全部来自深渊倍率
	_check(absf(z2.max_hp / hp0 - 1.30) < 0.01,
		"2 级僵尸血量 ×1.30（实际 ×%.2f）" % (z2.max_hp / hp0))
	_check(absf(float(z2.contact_damage) / dmg0 - 1.20) < 0.01,
		"2 级僵尸伤害 ×1.20（实际 ×%.2f）" % (float(z2.contact_damage) / dmg0))
	# 掉落不 round 进 base 值：silver_value 保持原值，倍率走 loot_mult
	_check(int(z2.silver_value) == silver0,
		"silver_value 不被深渊 round（掉落走 loot_mult 链，避免 1×1.2 永远 1）")
	z2.queue_free()
	GameConfig.abyss_level = 0

	# ---------- 普通刷怪的真实 loot_mult 路径 ----------
	print("\n--- 普通刷怪 loot_mult ---")
	# 直接走 wave_manager._spawn_enemy()：这是战斗里真正生成怪物的入口，
	# 深渊掉落倍率必须落在敌人的 loot_mult 上（而不是 round 进 silver_value）
	var WaveScript = load("res://scripts/managers/wave_manager.gd")
	var spawn_wm = Node.new()
	spawn_wm.set_script(WaveScript)
	_host.add_child(spawn_wm)
	var loot_player := DamageProbe.new()
	loot_player.position = Vector2(500, 500)
	loot_player.add_to_group("player")
	_host.add_child(loot_player)
	spawn_wm.player = loot_player
	spawn_wm.is_active = false
	spawn_wm.floor_index = 1
	spawn_wm.enemy_pool = ["zombie"]
	spawn_wm.current_wave = 1
	GameConfig.abyss_level = 2
	var before_children: int = _host.get_child_count()
	spawn_wm._spawn_enemy()
	await process_frame
	var spawned: Node = null
	for i in range(before_children, _host.get_child_count()):
		var n: Node = _host.get_child(i)
		if n != null and n.has_method("_get_enemy_type") \
				and String(n.call("_get_enemy_type")) == "zombie":
			spawned = n
	_check(spawned != null, "普通刷怪真的生成了敌人")
	if spawned != null:
		# 1.0（无契约修正）× 1.2（深渊 2 级）
		_check(absf(float(spawned.loot_mult) - 1.2) < 0.001,
			"普通刷怪的 loot_mult 含深渊倍率（%.3f ≈ 1.200）" % float(spawned.loot_mult))
		spawned.queue_free()
	GameConfig.abyss_level = 0
	spawn_wm.queue_free()
	loot_player.queue_free()
	await process_frame

	# ---------- 非接触伤害源（爆炸 / 法术） ----------
	print("\n--- 非接触伤害源 ---")
	var dmg_player := DamageProbe.new()
	dmg_player.position = Vector2(640, 360)
	dmg_player.add_to_group("player")
	_host.add_child(dmg_player)
	await process_frame

	# 自爆者：爆炸固定 30，规格上必须吃楼层与深渊伤害倍率
	# 2 层（×1.18）× 深渊 2 级（×1.20）→ 30 × 1.18 × 1.20 = 42.48
	GameConfig.abyss_level = 2
	var boom_hi: Node = _spawn("exploder", Vector2(600, 360), 2, 1)
	await process_frame
	await process_frame
	boom_hi._explode()
	await process_frame
	_check(absf(dmg_player.last_amount - 30.0 * 1.18 * 1.20) < 0.05,
		"爆炸伤害吃楼层与深渊倍率（%.2f ≈ 42.48）" % dmg_player.last_amount)
	await process_frame

	GameConfig.abyss_level = 0
	var boom_lo: Node = _spawn("exploder", Vector2(600, 360), 1, 1)
	await process_frame
	await process_frame
	boom_lo._explode()
	await process_frame
	_check(absf(dmg_player.last_amount - 30.0) < 0.05,
		"深渊 0 的 1 层爆炸保持 30.0（实际 %.2f）" % dmg_player.last_amount)

	# 法师：法术固定 15，同样要接楼层与深渊伤害倍率
	GameConfig.abyss_level = 2
	var mage: Node = _spawn("vampire_mage", Vector2(600, 360), 2, 1)
	await process_frame
	await process_frame
	mage._cast_spell()
	await process_frame
	var spells: Array = get_nodes_in_group("enemy_projectiles")
	_check(spells.size() == 1, "法师法术弹道生成（%d 发）" % spells.size())
	if spells.size() == 1:
		_check(absf(float(spells[0].damage) - 15.0 * 1.18 * 1.20) < 0.05,
			"法术伤害吃楼层与深渊倍率（%.2f ≈ 21.24）" % float(spells[0].damage))
	for s in spells:
		s.queue_free()
	mage.queue_free()
	GameConfig.abyss_level = 0
	dmg_player.queue_free()
	await process_frame

	# ---------- 血族亲王二阶段 ----------
	print("\n--- 血族亲王二阶段 ---")
	# 二阶段把 contact_damage 重算成 base × 波次时，曾丢掉楼层与深渊倍率。
	# 用真实场景走到 50% 血以下，期望值按 GDD 手算：
	# 二阶段 base 30 × 波次 1（×1.0）× 2 层（×1.18）× 深渊 2 级（×1.20）= 42.48
	var prince_player := DamageProbe.new()
	prince_player.position = Vector2(200, 200)
	prince_player.add_to_group("player")
	_host.add_child(prince_player)
	GameConfig.abyss_level = 2
	var prince_hi: Node = _spawn("vampire_prince", Vector2(600, 360), 2, 1)
	await process_frame
	await process_frame
	prince_hi.current_hp = float(prince_hi.max_hp) * 0.45
	prince_hi._physics_process(0.016)
	await process_frame
	_check(prince_hi.is_second_phase, "亲王在 50% 血以下进入二阶段")
	_check(absf(float(prince_hi.contact_damage) - 30.0 * 1.18 * 1.20) < 0.05,
		"二阶段接触伤害保留楼层与深渊倍率（%.2f ≈ 42.48）"
		% float(prince_hi.contact_damage))
	prince_hi.queue_free()
	await process_frame

	# 深渊 0 时楼层倍率也不能丢
	GameConfig.abyss_level = 0
	var prince_lo: Node = _spawn("vampire_prince", Vector2(600, 360), 2, 1)
	await process_frame
	await process_frame
	prince_lo.current_hp = float(prince_lo.max_hp) * 0.45
	prince_lo._physics_process(0.016)
	await process_frame
	_check(absf(float(prince_lo.contact_damage) - 30.0 * 1.18) < 0.05,
		"深渊 0 的二阶段仍含楼层倍率（%.2f ≈ 35.40）" % float(prince_lo.contact_damage))
	prince_lo.queue_free()
	prince_player.queue_free()
	await process_frame

	# ---------- Boss 属性 ----------
	print("\n--- Boss 属性 ---")
	# Boss 覆写 _ready 且不调 super._ready()，所以 EnemyBase 的深渊倍率对它完全无效。
	# 这里刷真场景做对照，血量/伤害/掉落三条链都要有。
	GameConfig.abyss_level = 0
	var b0: Node = _spawn("vampire_lord", Vector2(400, 300))
	await process_frame
	var boss_hp0: float = float(b0.max_hp)
	var boss_dmg0: float = float(b0.contact_damage)
	var boss_loot0: float = float(b0.loot_mult)
	b0.queue_free()
	await process_frame

	GameConfig.abyss_level = 2
	var b2: Node = _spawn("vampire_lord", Vector2(700, 300))
	await process_frame
	_check(absf(float(b2.max_hp) / boss_hp0 - 1.30) < 0.01,
		"2 级 Boss 血量 ×1.30（实际 ×%.2f）" % (float(b2.max_hp) / boss_hp0))
	_check(absf(float(b2.contact_damage) / boss_dmg0 - 1.20) < 0.01,
		"2 级 Boss 接触伤害 ×1.20（实际 ×%.2f）" % (float(b2.contact_damage) / boss_dmg0))
	_check(absf(float(b2.loot_mult) / boss_loot0 - 1.20) < 0.01,
		"2 级 Boss 掉落倍率 ×1.20（实际 ×%.2f，loot_mult 走概率进位链）"
		% (float(b2.loot_mult) / boss_loot0))
	# 狂暴/绝望只重算伤害，不能把深渊倍率丢掉。
	# 显式指定形态，期望值按 GDD 手算而不是复用生产公式：
	# 形态 1 狂暴 base = 30 + 1×4 = 34；波次 1（×1.0）× 深渊 2 级（×1.20）= 40.8
	GameConfig.abyss_level = 2
	var rage_scene: PackedScene = load("res://scenes/enemies/vampire_lord.tscn")
	var rage_boss = rage_scene.instantiate()
	rage_boss.boss_variant = 1
	rage_boss.spawn_wave = 1
	rage_boss.floor_index = 1
	rage_boss.position = Vector2(900, 300)
	_host.add_child(rage_boss)
	await process_frame
	rage_boss._enrage_effect()
	await process_frame
	_check(absf(float(rage_boss.contact_damage) - 34.0 * 1.20) < 0.01,
		"狂暴重算伤害仍含深渊倍率（%.2f ≈ 40.80，形态 1 base 34 × 1.20）"
		% float(rage_boss.contact_damage))
	rage_boss.queue_free()
	b2.queue_free()
	GameConfig.abyss_level = 0

	# ---------- Boss 弹幕伤害 ----------
	print("\n--- Boss 弹幕伤害 ---")
	# 弹幕是 Boss 主要的"非接触伤害源"，与爆炸/法术同一契约（波次 × 楼层 × 深渊）。
	# 期望值按 GDD 手算：基础 15 × 波次 1（×1.0）× 2 层（×1.18）× 深渊 2 级（×1.20）= 21.24
	var barrage_player := DamageProbe.new()
	barrage_player.position = Vector2(500, 500)
	barrage_player.add_to_group("player")
	_host.add_child(barrage_player)
	await process_frame

	GameConfig.abyss_level = 2
	var barrage_boss: Node = _spawn("vampire_lord", Vector2(700, 300), 2, 1)
	await process_frame
	await process_frame
	var barrage_before: Array = _snapshot_area2d()
	barrage_boss._spawn_boss_projectile(Vector2.RIGHT)
	await process_frame
	var bullet: Node = _find_new_boss_projectile(barrage_boss, barrage_before)
	_check(bullet != null, "Boss 弹幕节点生成")
	if bullet != null:
		# 不走物理帧：直接发 body_entered，验证命中结算用的数值
		bullet.body_entered.emit(barrage_player)
		await process_frame
		_check(absf(barrage_player.last_amount - 15.0 * 1.18 * 1.20) < 0.05,
			"弹幕伤害吃楼层与深渊倍率（%.2f ≈ 21.24）" % barrage_player.last_amount)
	barrage_boss.queue_free()
	await process_frame

	# 深渊 0 + 1 层：保持基础值 15（证明没有二次乘法）
	GameConfig.abyss_level = 0
	barrage_player.last_amount = 0.0
	var barrage_boss_lo: Node = _spawn("vampire_lord", Vector2(700, 300), 1, 1)
	await process_frame
	await process_frame
	var barrage_before_lo: Array = _snapshot_area2d()
	barrage_boss_lo._spawn_boss_projectile(Vector2.RIGHT)
	await process_frame
	var bullet_lo: Node = _find_new_boss_projectile(barrage_boss_lo, barrage_before_lo)
	_check(bullet_lo != null, "低倍率弹幕节点生成")
	if bullet_lo != null:
		bullet_lo.body_entered.emit(barrage_player)
		await process_frame
		_check(absf(barrage_player.last_amount - 15.0) < 0.05,
			"深渊 0 的 1 层弹幕保持 15.0（实际 %.2f，无二次乘法）" % barrage_player.last_amount)
	barrage_boss_lo.queue_free()
	barrage_player.queue_free()
	await process_frame

	# ---------- 掉落概率进位（非整数期望） ----------
	print("\n--- 掉落概率进位 ---")
	# 1 × 1.2 期望 1.2：整数值（10×1.2=12）用 roundi 也能对，
	# 抓不到"直接 round 进 base 值"的错误。用小数期望才有区分度：
	# roundi 逻辑会恒得 1（均值 1.0），概率进位才是 1.2。
	var loot_script = load("res://scripts/enemies/enemy_base.gd")
	# enemy_base 继承 CharacterBody2D：Node2D.new() 挂不上这个脚本
	var loot_probe: CharacterBody2D = CharacterBody2D.new()
	loot_probe.set_script(loot_script)
	# 只测纯函数，不进树：裸探针没有正式敌人场景里的 Sprite2D/CollisionShape2D，
	# 进树触发 _ready 只会制造两条与掉落无关的 Node not found。
	loot_probe.loot_mult = 1.2
	seed(20261108)
	var total: int = 0
	var rounds: int = 4000
	for i in range(rounds):
		total += int(loot_probe.call("_loot_scaled", 1))
	var avg: float = float(total) / float(rounds)
	# 二项分布 p=0.2、n=4000 → 标准差 0.0063；±0.05 是 8σ，不会 flake
	_check(absf(avg - 1.2) < 0.05,
		"1 × 1.2 期望 1.2，实测均值 %.3f（roundi 会得 1.0）" % avg)
	loot_probe.free()

	# ---------- 通关血晶（真实生产函数） ----------
	print("\n--- 通关血晶 ---")
	var main_script = load("res://scripts/managers/main.gd")
	var main_inst: Object = main_script.new()
	var base_crystals: int = GameConfig.get_floor_clear_crystals(1)
	# 直接 call 一个不存在的方法会中断整个协程（RED 阶段看不到后续断言），
	# 所以先判存在；缺函数本身作为一条失败断言报出来。
	var has_crystal_fn: bool = main_inst.has_method("_floor_clear_crystals")
	_check(has_crystal_fn, "main 提供真实通关血晶结算函数 _floor_clear_crystals")
	GameConfig.abyss_level = 0
	var crystals0: int = int(main_inst.call("_floor_clear_crystals", 1)) if has_crystal_fn else -1
	_check(crystals0 == base_crystals,
		"0 级通关血晶等于基线（%d）" % crystals0)
	GameConfig.abyss_level = 3
	var crystals3: int = int(main_inst.call("_floor_clear_crystals", 1)) if has_crystal_fn else -1
	# 规格：掉落每级 +10% → 3 级 ×1.3，四舍五入
	_check(crystals3 == roundi(float(base_crystals) * 1.3),
		"3 级通关血晶 ×1.3（实际 %d，基线 %d）" % [crystals3, base_crystals])
	GameConfig.abyss_level = 0

	# ---------- 深渊继续（真实推进函数） ----------
	print("\n--- 深渊继续 ---")
	var fake_save = FakeSave.new()
	GameConfig.abyss_level = 0
	GameConfig.best_abyss = 0
	main_inst.set("debug_save_manager", fake_save)
	var has_advance_fn: bool = main_inst.has_method("_advance_abyss")
	_check(has_advance_fn, "main 提供真实的深渊推进函数 _advance_abyss")
	var lv1: int = int(main_inst.call("_advance_abyss")) if has_advance_fn else -1
	_check(lv1 == 1 and GameConfig.abyss_level == 1,
		"深渊继续 +1 级（%d）" % GameConfig.abyss_level)
	_check(fake_save.get_best_abyss() == 1 and GameConfig.best_abyss == 1,
		"首次进入最深到达写入 1")
	var lv2: int = int(main_inst.call("_advance_abyss")) if has_advance_fn else -1
	_check(lv2 == 2 and fake_save.get_best_abyss() == 2,
		"再次继续 → 2 级，最深到达同步 2")
	# 深渊继续绝不能顺手归零：那是"放弃深渊"才做的事
	_check(GameConfig.abyss_level > 0, "深渊继续不会把等级清零")
	GameConfig.abyss_level = 0
	GameConfig.best_abyss = 0

	# ---------- 放弃深渊的唯一入口 ----------
	print("\n--- 放弃深渊 ---")
	# 暂停菜单"返回主菜单"是玩家最容易走到的退出路径，必须同样放弃深渊。
	# 导航出口做成可注入的 Callable：直接写死 change_scene_to_file 会把
	# "放弃深渊"这一步和场景加载绑死，测试也没法在不换场景的前提下驱动它。
	var pause_scene: PackedScene = load("res://scenes/ui/pause_menu.tscn")
	var pause_menu: Node = pause_scene.instantiate()
	_host.add_child(pause_menu)
	await process_frame
	var has_hook: bool = "go_to_main_menu" in pause_menu
	_check(has_hook, "暂停菜单提供可注入的导航出口 go_to_main_menu")
	var navigated: Dictionary = {"value": false}
	if has_hook:
		pause_menu.go_to_main_menu = func() -> void: navigated["value"] = true
		GameConfig.abyss_level = 3
		pause_menu._on_menu_pressed()
		_check(GameConfig.abyss_level == 0,
			"暂停菜单返回主菜单会放弃深渊（实际 %d）" % GameConfig.abyss_level)
		_check(bool(navigated["value"]), "暂停菜单仍然走真实的场景切换出口")
	# 主菜单是新一局的入口：即便从别的路径漏了归零，进主菜单也必须归零
	GameConfig.abyss_level = 2
	var menu_scene: PackedScene = load("res://scenes/ui/main_menu.tscn")
	var menu_inst: Node = menu_scene.instantiate()
	_host.add_child(menu_inst)
	await process_frame
	_check(GameConfig.abyss_level == 0,
		"进入主菜单会放弃深渊（实际 %d）" % GameConfig.abyss_level)
	menu_inst.queue_free()
	pause_menu.queue_free()
	await process_frame

	# ---------- 胜利界面按钮（真实场景） ----------
	print("\n--- 胜利界面按钮 ---")
	var ui_scene: PackedScene = load("res://scenes/ui/game_over_ui.tscn")
	var victory_ui: Node = ui_scene.instantiate()
	_host.add_child(victory_ui)
	await process_frame
	# 切掉 autoload 存档：按钮/文本与存档无关，测试不碰真实玩家数据
	victory_ui.save_mgr = null
	GameConfig.abyss_level = 2
	var restart_btn: Button = victory_ui.get_node(
		"CenterContainer/PanelContainer/VBoxContainer/RestartButton")
	var conns_before: int = restart_btn.mouse_entered.get_connections().size()
	victory_ui.show_game_over({
		"floors_cleared": 3, "rooms": 10, "wave": 5, "kills": 20,
		"level": 8, "survival_time": 100, "damage_taken": 50, "abyss_level": 2,
	}, true)
	paused = false
	var abyss_btn: Button = victory_ui.abyss_button
	_check(abyss_btn != null and abyss_btn.visible, "胜利界面显示深渊按钮")
	if abyss_btn != null:
		_check(abyss_btn.text.contains("深入深渊 3"),
			"按钮文本指向下一级（'%s'）" % abyss_btn.text)
		# 3 级的百分比是"下一轮总计"（3 × 15% / 10% / 10%），不是这一次的增量；
		# 文本必须写明口径，否则会被读成"+45% 以外的再加成"
		_check(abyss_btn.text.contains("下一轮总计"),
			"按钮文本标明百分比是下一轮总倍率（'%s'）" % abyss_btn.text)
		_check(abyss_btn.text.contains("血 +45%") and abyss_btn.text.contains("掉落 +30%"),
			"按钮文本给出 3 级的总倍率（'%s'）" % abyss_btn.text)
	# 旧按钮不得因为新按钮而重复连接（会让 hover 音效双播）
	_check(restart_btn.mouse_entered.get_connections().size() == conns_before,
		"旧按钮的音效连接数不因创建深渊按钮而变化（%d）" % conns_before)
	if abyss_btn != null:
		_check(abyss_btn.mouse_entered.get_connections().size() == 1,
			"深渊按钮只连接一次 hover 音效（%d）" % abyss_btn.mouse_entered.get_connections().size())
		_check(abyss_btn.pressed.get_connections().size() == 2,
			"深渊按钮 pressed = 自身回调 + 音效（%d）"
			% abyss_btn.pressed.get_connections().size())
	# 再次展示（同一实例）不能累加连接
	victory_ui.show_game_over({
		"floors_cleared": 3, "rooms": 10, "wave": 5, "kills": 20,
		"level": 8, "survival_time": 100, "damage_taken": 50, "abyss_level": 2,
	}, true)
	paused = false
	_check(restart_btn.mouse_entered.get_connections().size() == conns_before,
		"重复展示不重复连接旧按钮（%d）" % restart_btn.mouse_entered.get_connections().size())
	if abyss_btn != null:
		_check(abyss_btn.mouse_entered.get_connections().size() == 1,
			"重复展示不重复连接深渊按钮（%d）" % abyss_btn.mouse_entered.get_connections().size())
	victory_ui.queue_free()
	await process_frame

	# 失败界面：既不显示，也不该做无意义的按钮创建
	var defeat_ui: Node = ui_scene.instantiate()
	_host.add_child(defeat_ui)
	await process_frame
	defeat_ui.save_mgr = null
	defeat_ui.show_game_over({"floor": 2, "rooms": 6, "wave": 3, "kills": 9, "level": 4}, false)
	paused = false
	_check(defeat_ui.abyss_button == null, "失败界面不创建深渊按钮")
	defeat_ui.queue_free()
	await process_frame
	main_inst.free()
	fake_save.free()
	GameConfig.abyss_level = 0

	# ---------- SaveManager best_abyss ----------
	print("\n--- SaveManager best_abyss ---")
	# 真实行为测试：FakeSave 覆写 save_game 为内存计数器，整个用例不碰真实存档。
	var fake = FakeSave.new()
	_check(fake.has_method("get_best_abyss") and fake.has_method("set_best_abyss"),
		"SaveManager 提供 get/set_best_abyss")
	_check(fake.get_best_abyss() == 0, "默认 best_abyss = 0")
	fake.set_best_abyss(3)
	_check(fake.get_best_abyss() == 3 and fake.save_calls == 1,
		"首次写入生效并触发保存（内存）")
	fake.set_best_abyss(1)
	_check(fake.get_best_abyss() == 3 and fake.save_calls == 1,
		"更低值不覆盖、不写盘（只增不减）")
	fake.set_best_abyss(3)
	_check(fake.get_best_abyss() == 3 and fake.save_calls == 1,
		"相同值不重复保存")
	fake.set_best_abyss(5)
	_check(fake.get_best_abyss() == 5 and fake.save_calls == 2,
		"更高值覆盖并保存")
	fake.free()

	# 真实 UI 场景会触发 BGM（胜利/失败）与按钮音效；不显式停掉，
	# 退出检查会把这些 playback 当成泄漏（同 room_event_test 的处理）
	await _stop_audio()

	_finish()
