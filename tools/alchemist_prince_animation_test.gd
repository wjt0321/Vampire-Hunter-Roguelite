extends SceneTree
## 炼金亲王双单位行为回归 + 死亡演出契约：pair/solo 掷瓶冷却与 puddle 落地、
## 巨像砸地 16 伤害与 1.6s 冷却（enraged && <90px）、enrage 移速 70、
## colossus_fell 后亲王 solo（移速 140、冷却 1.3s）、
## 巨像先倒 0.8s 内自回收 + boss_phase_changed(1)、
## 亲王先倒留尸不 queue_free + 巨像 enrage + boss_phase_changed(2)、
## 双倒 boss_defeated 发出且双单位 <0.8s 内各自回收。
## godot --headless --path . --script res://tools/alchemist_prince_animation_test.gd
##
## 预期 RED（当前实现零死亡演出，共 3 条）：
##   1. 巨像先倒：is_dead 后 0.2s 巨像仍 is_instance_valid（death 条带播放中）——
##      当前巨像 _die() 立即 queue_free，本条 FAIL；「0.8s 内回收」字面断言当前即 PASS。
##   2. 亲王先倒路线：巨像也倒后亲王 <0.8s 自回收——当前靠 main 清场，
##      headless 无 main，亲王留尸永存，本条 FAIL。
##   3. 双倒路线：同上，亲王 <0.8s 自回收 FAIL。
## 其余断言全部针对既有行为，必须一开始就 PASS。
##
## 玩家替身：与守望者测试同一模式 —— Target(CharacterBody2D) 命名 "Player"
## 并加入 "player" 组；_new_pair() 显式 unit.player = _target，不依赖延迟一帧的
## _find_player。注意 potion_puddle 按距离（半径 70）掉血，砸地 hp 记账的用例里
## 用 prince._timer=9999 压住掷瓶，避免 puddle 干扰。
## 内存纹理注入照抄守望者测试（fixture 模式）：动画层 Task 4 才接，
## "_animation_textures" 尚不存在时注入为空操作，不挡行为断言。

const PRINCE_STATES := ["idle", "move", "cast", "solo_shift", "death"]
const COLOSSUS_STATES := ["idle", "move", "slam", "enrage", "death"]

var _pass := 0
var _fail := 0
var _host: Node2D
var _target: Target
var _textures: Dictionary = {}

class Target extends CharacterBody2D:
	var hp := 1000.0
	func take_damage(amount: float, _origin: Vector2 = Vector2.ZERO) -> void:
		hp -= amount

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, label: String) -> void:
	if ok:
		_pass += 1
		print("PASS " + label)
	else:
		_fail += 1
		print("FAIL " + label)

func _run() -> void:
	await process_frame
	print("ALCHEMIST_PRINCE_ANIMATION mode=fixture")
	var all_states: Array = PRINCE_STATES + COLOSSUS_STATES
	for state in all_states:
		var image := Image.create(768, 128, false, Image.FORMAT_RGBA8)
		image.fill(Color.from_hsv(float(all_states.find(state)) / 10.0, 0.7, 0.8))
		_textures[state] = ImageTexture.create_from_image(image)
	_host = Node2D.new()
	root.add_child(_host)
	current_scene = _host
	_target = Target.new()
	_target.name = "Player"
	_target.collision_layer = 0
	_target.collision_mask = 0
	_host.add_child(_target)
	_target.global_position = Vector2(200, 0)  # 亲王右侧 200px：移速/掷瓶断言都在这个方向
	_target.add_to_group("player")
	_test_interfaces_exist()
	await _test_enrage()
	await _test_colossus_slam()
	await _test_pair_toss()
	await _test_colossus_fell_solo()
	await _test_prince_falls_first()
	await _test_double_kill()
	_host.queue_free()
	await process_frame
	_finish()

func _new_pair() -> Array:
	_target.hp = 1000.0
	var prince = load("res://scenes/enemies/alchemist_prince.tscn").instantiate()
	prince.skip_intro = true
	_host.add_child(prince)  # _ready 里同步 _spawn_colossus，返回时 colossus 已在树上
	prince.global_position = Vector2(0, 0)
	prince.player = _target
	if "_animation_textures" in prince:
		prince._animation_textures = _textures.duplicate()
	var colossus: Node = prince.colossus
	colossus.player = _target
	if "_animation_textures" in colossus:
		colossus._animation_textures = _textures.duplicate()
	return [prince, colossus]

func _puddles() -> Array:
	var out: Array = []
	for child in _host.get_children():
		var s: Script = child.get_script()
		if s != null and s.resource_path == "res://scripts/map/potion_puddle.gd":
			out.append(child)
	return out

func _clear_units() -> void:
	for child in _host.get_children():
		if child != _target:
			child.free()

func _test_interfaces_exist() -> void:
	var prince = load("res://scenes/enemies/alchemist_prince.tscn").instantiate()
	var colossus = load("res://scenes/enemies/alchemist_colossus.tscn").instantiate()
	_check(prince.has_method("take_damage"), "prince exposes take_damage")
	_check(prince.has_method("colossus_fell"), "prince exposes colossus_fell")
	_check(prince.has_method("_finish_fight"), "prince exposes _finish_fight")
	_check(prince.has_method("_toss"), "prince exposes _toss")
	_check(colossus.has_method("enrage"), "colossus exposes enrage")
	_check(colossus.has_method("take_damage"), "colossus exposes take_damage")
	_check(prince.has_signal("boss_phase_changed"), "prince exposes boss_phase_changed")
	_check(prince.has_signal("boss_defeated"), "prince exposes boss_defeated")
	_check(prince.has_signal("enemy_died"), "prince exposes enemy_died")
	_check("colossus" in prince and "_mode" in prince, "prince exposes colossus/_mode")
	_check("enraged" in colossus, "colossus exposes enraged")
	_check(ResourceLoader.exists("res://scripts/map/potion_puddle.gd"), "potion_puddle script exists")
	prince.free()
	colossus.free()

func _test_enrage() -> void:
	var pair := _new_pair()
	var colossus: Node = pair[1]
	colossus.enrage()
	_check(colossus.enraged == true, "enrage sets enraged flag")
	_check(is_equal_approx(colossus.move_speed, 70.0), "enrage sets move speed to 70")
	_check(is_equal_approx(colossus._timer, 0.4), "enrage resets slam timer to 0.4")
	_clear_units()

func _test_colossus_slam() -> void:
	var pair := _new_pair()
	var prince: Node = pair[0]
	var colossus: Node = pair[1]
	prince._timer = 9999.0  # 压住掷瓶：puddle 按距离掉血，会干扰砸地的 hp 记账
	_target.global_position = colossus.global_position + Vector2(50, 0)  # 砸地射程（<90px）内
	colossus._timer = 0.05
	await create_timer(0.15).timeout
	_check(_target.hp == 1000.0, "no slam while not enraged")
	colossus.enrage()
	colossus._timer = 0.05
	await create_timer(0.15).timeout
	_check(_target.hp == 984.0, "enraged slam deals 16 inside 90px")
	_check(colossus._timer > 1.4, "slam cooldown resets to 1.6")
	_target.global_position = colossus.global_position + Vector2(300, 0)  # 射程外
	colossus._timer = 0.05
	await create_timer(0.15).timeout
	_check(_target.hp == 984.0, "slam misses beyond 90px")
	_clear_units()

func _test_pair_toss() -> void:
	var pair := _new_pair()
	var prince: Node = pair[0]
	await create_timer(0.05).timeout
	_check(absf(prince.velocity.length() - 78.0) < 1.0, "pair mode moves at 78")
	var before := _puddles().size()
	prince._timer = 0.05
	await create_timer(0.15).timeout
	var puddles := _puddles()
	_check(puddles.size() == before + 1, "pair toss lands a puddle")
	if puddles.size() > before:
		var puddle: Node2D = puddles[puddles.size() - 1]
		_check(puddle.damage == 10.0, "puddle damage is 10")
		_check(puddle.global_position.distance_to(_target.global_position) < 1.0, "puddle lands at player position")
	_check(prince._timer > 2.05, "pair toss cooldown resets to 2.2")
	_clear_units()

func _test_colossus_fell_solo() -> void:
	var pair := _new_pair()
	var prince: Node = pair[0]
	var colossus: Node = pair[1]
	var phases: Array = []
	prince.boss_phase_changed.connect(func(p): phases.append(p))
	colossus.take_damage(1000000.0)
	_check(prince._mode == "solo_prince", "colossus fell switches prince to solo_prince")
	_check(phases == [1], "colossus fell emits boss_phase_changed(1)")
	await create_timer(0.2).timeout
	_check(is_instance_valid(colossus), "colossus death performance plays (still valid 0.2s after death)")
	await create_timer(0.6).timeout
	_check(not is_instance_valid(colossus), "colossus self-recycles within 0.8s of death")
	_check(absf(prince.velocity.length() - 140.0) < 1.0, "solo prince moves at 140")
	var before := _puddles().size()
	prince._timer = 0.05
	await create_timer(0.15).timeout
	_check(_puddles().size() == before + 1, "solo toss lands a puddle")
	_check(prince._timer > 1.15, "solo toss cooldown resets to 1.3")
	_clear_units()

func _test_prince_falls_first() -> void:
	var pair := _new_pair()
	var prince: Node = pair[0]
	var colossus: Node = pair[1]
	var phases: Array = []
	var defeated := [false]
	prince.boss_phase_changed.connect(func(p): phases.append(p))
	prince.boss_defeated.connect(func(): defeated[0] = true)
	prince.take_damage(1000000.0)
	_check(prince.is_dead, "prince dies when hp depleted")
	await create_timer(0.3).timeout
	_check(is_instance_valid(prince), "prince corpse stays while colossus alive")
	_check(colossus.enraged == true, "colossus enrages when prince falls first")
	_check(phases == [2], "prince falling first emits boss_phase_changed(2)")
	await create_timer(0.5).timeout
	_check(prince.visible == false, "prince corpse ends up invisible")
	colossus.take_damage(1000000.0)
	_check(defeated[0] == true, "boss_defeated fires when both are down")
	await create_timer(0.8).timeout
	_check(not is_instance_valid(prince), "prince self-recycles within 0.8s after colossus falls")
	_clear_units()

func _test_double_kill() -> void:
	var pair := _new_pair()
	var prince: Node = pair[0]
	var colossus: Node = pair[1]
	var defeated := [false]
	prince.boss_defeated.connect(func(): defeated[0] = true)
	colossus.take_damage(1000000.0)
	await create_timer(0.8).timeout
	_check(not is_instance_valid(colossus), "double kill: colossus recycled within 0.8s")
	prince.take_damage(1000000.0)
	_check(defeated[0] == true, "double kill: boss_defeated fires")
	await create_timer(0.8).timeout
	_check(not is_instance_valid(prince), "double kill: prince recycled within 0.8s")
	_clear_units()

func _finish() -> void:
	print("ALCHEMIST_PRINCE_ANIMATION RESULT passed=%d failed=%d" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
