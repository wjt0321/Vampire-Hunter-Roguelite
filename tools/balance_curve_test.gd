extends SceneTree
## 数值曲线回归测试（试玩反馈：怪一开始血量太厚、不线性）
##
## 断言的是**曲线形状**而不是某一格的数字：
##   - 波次倍率必须线性（逐波增量恒定），不是复利；
##   - 第一间房（wave 1 / 第 1 层）的杂兵 TTK 必须落在 0.4~1.5 秒；
##   - 同一层内不同敌人的血量差距不能超过 4 倍（否则"同样是杂兵，一个一下死、一个打不动"）；
##   - 楼层台阶不能一步跳太多。
##
## 改数值时先跑这个，别只看单点手感。
##
## 用法: godot --headless --path . --script res://tools/balance_curve_test.gd
##
## 注意：`--script` 模式下不能静态引用 class_name（autoload 未注册），一律运行时 load。

## 一层实际会出现的敌人（与 dungeon_manager.floors_data[0].enemies 对应）
const FLOOR1_ENEMIES := [
	["vampire", "vampire.gd"],
	["bat", "bat.gd"],
	["zombie", "zombie.gd"],
	["skeleton_archer", "skeleton_archer.gd"],
	["werewolf", "werewolf.gd"],
]

## 开局 DPS：手枪 4 伤害 / 0.25 秒
const START_DPS: float = 16.0

var _pass: int = 0
var _fail: int = 0
var _config = null

func _initialize() -> void:
	_run()

func _check(ok: bool, label: String) -> void:
	if ok:
		_pass += 1
		print("✅ %s" % label)
	else:
		_fail += 1
		print("❌ %s" % label)

func _cfg():
	if _config == null:
		_config = load("res://scripts/core/game_config.gd")
	return _config

func _read_base_hp(file_name: String) -> float:
	var text := FileAccess.get_file_as_string("res://scripts/enemies/" + file_name)
	var re := RegEx.new()
	re.compile("base_hp\\s*=\\s*([0-9]+(?:\\.[0-9]+)?)")
	var m := re.search(text)
	return float(m.get_string(1)) if m else -1.0

func _run() -> void:
	await process_frame
	print("\n========== 数值曲线回归 ==========")

	print("\n=== 1. 波次血量倍率是线性的 ===")
	_check(is_equal_approx(_cfg().get_enemy_hp_multiplier(1), 1.0),
		"第 1 波不加成（%.2f）" % _cfg().get_enemy_hp_multiplier(1))
	var step12: float = _cfg().get_enemy_hp_multiplier(2) - _cfg().get_enemy_hp_multiplier(1)
	var step34: float = _cfg().get_enemy_hp_multiplier(4) - _cfg().get_enemy_hp_multiplier(3)
	var step1112: float = _cfg().get_enemy_hp_multiplier(12) - _cfg().get_enemy_hp_multiplier(11)
	_check(is_equal_approx(step12, step34) and is_equal_approx(step34, step1112),
		"逐波增量恒定（%.3f / %.3f / %.3f）——复利会越涨越快" % [step12, step34, step1112])
	var h12: float = _cfg().get_enemy_hp_multiplier(12)
	_check(h12 > 2.0 and h12 < 2.6, "单局末波（12）血量倍率 %.2f 落在 2.0~2.6" % h12)
	_check(is_equal_approx(_cfg().get_enemy_hp_multiplier(0), 1.0), "波次 0 也不加成为负数")

	print("\n=== 2. 楼层台阶 ===")
	var f1: float = _cfg().get_floor_hp_multiplier(1)
	var f2: float = _cfg().get_floor_hp_multiplier(2)
	var f3: float = _cfg().get_floor_hp_multiplier(3)
	_check(is_equal_approx(f1, 1.0), "第 1 层无额外加成")
	_check(f2 / f1 <= 1.45 and f2 / f1 >= 1.25, "1→2 层台阶 ×%.2f（不要一步跳太狠）" % (f2 / f1))
	_check(f3 / f2 <= 1.45 and f3 / f2 >= 1.25, "2→3 层台阶 ×%.2f" % (f3 / f2))
	var eff12: float = h12 * f3
	_check(eff12 > 4.0 and eff12 < 4.8, "第 3 层末波等效血量倍率 ×%.2f（旧版复利 ×4.98）" % eff12)

	print("\n=== 3. 第一间房的杂兵 TTK（玩家 16 DPS）===")
	var min_hp: float = 1e9
	var max_hp: float = -1.0
	for entry in FLOOR1_ENEMIES:
		var hp: float = _read_base_hp(String(entry[1]))
		_check(hp > 0.0, "%s 的 base_hp 可读（%.0f）" % [entry[0], hp])
		var ttk: float = hp * _cfg().get_enemy_hp_multiplier(1) * f1 / START_DPS
		_check(ttk <= 1.6, "%s 开局 TTK %.2fs ≤ 1.6s" % [entry[0], ttk])
		min_hp = minf(min_hp, hp)
		max_hp = maxf(max_hp, hp)
	_check(max_hp / min_hp <= 4.0,
		"一层杂兵血量差距 %.2f 倍 ≤ 4 倍（旧版蝙蝠7 / 僵尸40 = 5.7 倍）" % (max_hp / min_hp))

	print("\n=== 4. 第 1 层不会出现带盾怪 ===")
	var pool1: Array = _cfg().get_elite_affix_pool(1)
	_check(not ("shielded" in pool1), "第 1 层词缀池不含血盾（%s）" % str(pool1))
	for i in range(3):
		var pool: Array = _cfg().get_elite_affix_pool(i + 1)
		var chance: float = _cfg().get_elite_affix_chance(i + 1)
		_check(chance <= 0.20, "第 %d 层词缀概率 %.0f%% ≤ 20%%" % [i + 1, chance * 100.0])
		if i > 0:
			_check("shielded" in pool, "第 %d 层词缀池含血盾（正常解锁）" % (i + 1))

	print("\n=========================================")
	print("通过 %d / 失败 %d" % [_pass, _fail])
	print("=========================================")
	quit(0 if _fail == 0 else 1)
