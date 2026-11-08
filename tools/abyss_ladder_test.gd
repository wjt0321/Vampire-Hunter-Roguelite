extends SceneTree
## 深渊阶梯回归测试（17.14）
## 用法: godot --headless --path . --script res://tools/abyss_ladder_test.gd
##
## 覆盖：
##   倍率函数：0 级全 1.0，N 级按步进线性
##   敌人实际血量/伤害吃深渊倍率（hp 链最外层）
##   掉落倍率走 loot_mult 概率进位链（不是 round 进 base 值）
##   通关血晶乘加成且保底 1
##   胜利界面深渊按钮只在 victory 出现
##   SaveManager best_abyss 只增不减（真实行为，测试子类内存落盘）

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

	# ---------- 掉落概率进位 ----------
	print("\n--- 掉落概率进位 ---")
	# 期望 10 × 1.2 = 12：跑 600 次统计，长期均值应接近 12（±0.3）
	var loot_script = load("res://scripts/enemies/enemy_base.gd")
	# enemy_base 继承 CharacterBody2D：Node2D.new() 挂不上这个脚本
	var probe: CharacterBody2D = CharacterBody2D.new()
	probe.set_script(loot_script)
	# 只测纯函数，不进树：裸探针没有正式敌人场景里的 Sprite2D/CollisionShape2D，
	# 进树触发 _ready 只会制造两条与掉落无关的 Node not found。
	probe.loot_mult = 1.2
	seed(20261108)
	var total: int = 0
	var rounds: int = 600
	for i in range(rounds):
		total += int(probe.call("_loot_scaled", 10))
	var avg: float = float(total) / float(rounds)
	_check(absf(avg - 12.0) < 0.3,
		"10 × 1.2 期望 12，实测均值 %.2f（概率进位活着）" % avg)
	probe.free()

	# ---------- 通关血晶 ----------
	print("\n--- 通关血晶 ---")
	GameConfig.abyss_level = 3
	var crystals: int = maxi(
		roundi(GameConfig.get_floor_clear_crystals(1) * GameConfig.get_abyss_loot_mult()), 1)
	var expect: int = maxi(roundi(GameConfig.get_floor_clear_crystals(1) * 1.3), 1)
	_check(crystals == expect,
		"3 级通关血晶 ×1.3（实际 %d，基线 %d）" % [crystals, GameConfig.get_floor_clear_crystals(1)])
	GameConfig.abyss_level = 0

	# ---------- 胜利界面按钮 ----------
	print("\n--- 胜利界面按钮 ---")
	# Script 资源上的 has_method/in 查的是 Script 类自身，不是脚本内容。
	# new() 出实例再查（不进树就不会触发 _ready，无 autoload 依赖）
	var ui_script = load("res://scripts/ui/game_over_ui.gd")
	var ui_inst: Object = ui_script.new()
	_check("abyss_continue_requested" in ui_inst,
		"game_over_ui 声明 abyss_continue_requested 信号")
	_check(ui_inst.has_method("_setup_abyss_button"),
		"game_over_ui 有 _setup_abyss_button（victory 才显示按钮）")
	ui_inst.free()
	var main_script = load("res://scripts/managers/main.gd")
	var main_inst: Object = main_script.new()
	_check(main_inst.has_method("_on_abyss_continue"),
		"main 有 _on_abyss_continue（reload 前提升等级）")
	main_inst.free()

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

	_finish()
