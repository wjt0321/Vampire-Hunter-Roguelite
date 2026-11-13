extends SceneTree
## 月蚀女王行为回归（Task 1）：闪烁周期、月相门控、祭坛推进、死亡清理。
## 闪烁 1.4s 冷却 → _blinking 前摇 0.45s → 落点 == 玩家位置；
## 落点后冷却 0.7（月相 0）/ 0.4（月相 ≥ 1），safe_radius() 150/90；
## 祭坛 40HP 打掉 → altar_destroyed → moon_phase=1 + boss_phase_changed(1)；
## hp<40% → moon_phase=2 + boss_phase_changed(2)；
## 祭坛随女王离场经 linked_nodes 连带清理（RED 前即应 PASS）；
## 女王死亡自救回收（RED：0.2s 时仍 valid、0.8s 内 queue_free——
## 当前 _die 不自回收，headless 下留尸，断言 FAIL）。
## godot --headless --path . --script res://tools/eclipse_queen_animation_test.gd [-- --real-assets]
##
## 同步原语：本 harness 下 create_timer（墙钟）与物理推进不同步，
## 所有物理驱动断言一律用 physics_frame 计数（tick = 1/physics_ticks_per_second）。
##
## 玩家替身：与守望者/亲王测试同一模式 —— Target(CharacterBody2D) 命名 "Player"
## 并加入 "player" 组；_new_queen() 显式 queen.player = _target，
## 不依赖延迟一帧的 _find_player。女王闪烁由 _physics_process 驱动，
## 本测试保持物理处理开启（不像守望者测试那样关停）。
## fixture 模式注入 6 状态内存纹理；Task 1 女王尚无 _animation_textures，
## 注入用 "in" 守卫，Task 4 接线后自动生效，行为断言不依赖动画帧。

const STATES := ["idle", "move", "blink", "appear", "phase_change", "death"]
const Slots = preload("res://scripts/core/asset_slots.gd")
var _pass := 0
var _fail := 0
var _host: Node2D
var _target: Target
var _textures: Dictionary = {}
var _real := false
var _tick: float = 1.0 / 60.0

class Target extends CharacterBody2D:
	var hp := 1000.0
	func take_damage(amount: float, _origin: Vector2 = Vector2.ZERO) -> void:
		hp -= amount

func _initialize() -> void:
	_tick = 1.0 / float(Engine.physics_ticks_per_second)
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
	_real = "--real-assets" in OS.get_cmdline_user_args()
	print("ECLIPSE_QUEEN_ANIMATION mode=" + ("real-assets" if _real else "fixture") + " tick=%.4f" % _tick)
	for i in STATES.size():
		var state: String = STATES[i]
		if _real:
			var texture := Slots.boss_texture("eclipse_queen", state)
			_check(texture != null and texture.get_size() == Vector2(768, 128), "asset eclipse_queen/" + state + " is 768x128")
			if texture != null:
				_textures[state] = texture
		else:
			var image := Image.create(768, 128, false, Image.FORMAT_RGBA8)
			image.fill(Color.from_hsv(float(i) / 6.0, 0.7, 0.8))
			_textures[state] = ImageTexture.create_from_image(image)
	if _textures.size() != 6:
		_finish()
		return
	_host = Node2D.new()
	root.add_child(_host)
	current_scene = _host
	_target = Target.new()
	_target.name = "Player"
	_target.collision_layer = 0
	_target.collision_mask = 0
	_host.add_child(_target)
	_target.global_position = Vector2(200, 0)  # 女王右侧 200px：闪烁落点断言在这个方向
	_target.add_to_group("player")
	_test_interfaces_exist()
	await _test_blink_cycle()
	await _test_moon_phase_gates_cooldown_and_radius()
	await _test_altar_destroyed_advances_phase()
	await _test_low_hp_advances_phase_two()
	await _test_altar_cleaned_with_queen_exit()
	await _test_death_self_recycle()
	_host.queue_free()
	await process_frame
	_finish()

func _new_queen() -> Node:
	_target.hp = 1000.0
	_target.global_position = Vector2(200, 0)
	var queen = load("res://scenes/enemies/eclipse_queen.tscn").instantiate()
	queen.skip_intro = true
	_host.add_child(queen)  # _ready 同步 _spawn_altar，返回时 altar 已在树上
	queen.global_position = Vector2(0, 0)
	queen.player = _target
	if not _real and "_animation_textures" in queen:
		queen._animation_textures = _textures.duplicate()
		queen._animation_state = ""
		queen._tick_sprite(0.0)
	return queen

func _clear_units() -> void:
	for child in _host.get_children():
		if child != _target:
			child.free()

func _await_blink_resolution(queen: Node) -> Dictionary:
	## 轮询物理帧直到 _blinking 起播并收口；返回 {frames, drift}
	var out := {"frames": 0, "drift": false}
	var guard := 0
	while not queen._blinking and guard < 10:
		await physics_frame
		guard += 1
	if not queen._blinking:
		return out
	var start_pos: Vector2 = queen.global_position
	var windup_frames := 0
	while queen._blinking and windup_frames < 40:
		await physics_frame
		windup_frames += 1
		if queen._blinking and queen.global_position != start_pos:
			out.drift = true
	out.frames = windup_frames
	return out

func _test_interfaces_exist() -> void:
	## 探针：后面协程要调的方法/属性逐个点名，缺失时在此留 FAIL，
	## 而不是中断协程造成 failed=0 假绿。
	var queen = load("res://scenes/enemies/eclipse_queen.tscn").instantiate()
	_check(queen.has_method("take_damage"), "queen exposes take_damage")
	_check(queen.has_method("altar_destroyed"), "queen exposes altar_destroyed")
	_check(queen.has_method("safe_radius"), "queen exposes safe_radius")
	_check(queen.has_signal("boss_phase_changed"), "queen exposes boss_phase_changed")
	_check(queen.has_signal("boss_defeated"), "queen exposes boss_defeated")
	_check(queen.has_signal("enemy_died"), "queen exposes enemy_died")
	_check("altar" in queen and "moon_phase" in queen, "queen exposes altar/moon_phase")
	_check("_blinking" in queen and "_blink_to" in queen and "_timer" in queen, "queen exposes blink internals")
	_check("linked_nodes" in queen, "queen exposes linked_nodes")
	_check("move_speed" in queen and "base_contact_damage" in queen, "queen exposes move_speed/base_contact_damage")
	_check("player" in queen and "skip_intro" in queen, "queen exposes player/skip_intro")
	_check(ResourceLoader.exists("res://scripts/enemies/moon_altar.gd"), "moon_altar script exists")
	queen.free()

func _test_blink_cycle() -> void:
	## 闪烁周期：1.4s 冷却 → _blinking 前摇 0.45s（27 tick）→ 落点 == 玩家位置 → 0.7s 冷却
	var queen = _new_queen()
	_check(is_equal_approx(queen._timer, 1.4), "blink cooldown starts at 1.4")
	_check(is_equal_approx(queen.move_speed, 80.0), "move speed is 80")
	_check(is_equal_approx(queen.base_contact_damage, 14.0), "contact damage is 14")
	_check(queen.safe_radius() == 150.0, "safe radius is 150 at moon phase 0")
	await physics_frame
	await physics_frame
	_check(absf(queen.velocity.length() - 80.0) < 1.0, "queen approaches player at speed 80")
	queen._timer = 0.02
	var res: Dictionary = await _await_blink_resolution(queen)
	_check(queen._blinking == false and res.frames > 0, "cooldown expiry enters and resolves _blinking windup")
	var expected := int(round(0.45 / _tick))
	_check(absi(res.frames - expected) <= 3, "windup lasts 0.45s (%d physics frames)" % expected)
	_check(not res.drift, "queen holds position through the windup")
	_check(queen.global_position.distance_to(_target.global_position) < 0.5, "blink lands on the player position")
	_check(queen._timer > 0.7 - _tick * 2.0, "post-landing cooldown is 0.7 at moon phase 0")
	_clear_units()

func _test_moon_phase_gates_cooldown_and_radius() -> void:
	## 月相门控：直接置 moon_phase=1，落点后冷却 0.4，safe_radius 90
	var queen = _new_queen()
	queen.moon_phase = 1
	_check(queen.safe_radius() == 90.0, "safe radius shrinks to 90 at moon phase >= 1")
	queen._timer = 0.02
	var res: Dictionary = await _await_blink_resolution(queen)
	_check(queen._blinking == false and res.frames > 0, "blink triggers and resolves at moon phase 1")
	_check(queen.global_position.distance_to(_target.global_position) < 0.5, "blink lands on the player at moon phase 1")
	_check(queen._timer > 0.4 - _tick * 2.0 and queen._timer <= 0.4 + _tick, "post-landing cooldown is 0.4 at moon phase >= 1")
	_clear_units()

func _test_altar_destroyed_advances_phase() -> void:
	## 祭坛 40HP：打掉 → altar_destroyed → moon_phase=1 + boss_phase_changed(1)
	var queen = _new_queen()
	var altar: Node = queen.altar
	_check(altar != null, "altar spawns with the queen")
	_check(is_equal_approx(altar.current_hp, 40.0), "altar has 40 hp")
	var phases: Array = []
	queen.boss_phase_changed.connect(func(p): phases.append(p))
	altar.take_damage(1000.0)
	_check(queen.altar == null, "altar reference cleared on destroy")
	_check(queen.moon_phase == 1, "moon phase advances to 1 when altar destroyed")
	_check(phases == [1], "altar destroyed emits boss_phase_changed(1)")
	_check(queen.safe_radius() == 90.0, "safe radius is 90 after altar destroyed")
	await process_frame
	_check(not is_instance_valid(altar), "altar frees itself after destruction")
	_clear_units()

func _test_low_hp_advances_phase_two() -> void:
	## hp<40% → moon_phase=2 + boss_phase_changed(2)（_physics_process 判定帧）
	var queen = _new_queen()
	var phases: Array = []
	queen.boss_phase_changed.connect(func(p): phases.append(p))
	queen.current_hp = queen.max_hp * 0.3
	for i in 6:
		await physics_frame
	_check(queen.moon_phase == 2, "moon phase advances to 2 below 40% hp")
	_check(phases == [2], "phase 2 emits boss_phase_changed(2)")
	_check(queen.safe_radius() == 90.0, "safe radius is 90 at moon phase 2")
	_clear_units()

func _test_altar_cleaned_with_queen_exit() -> void:
	## 祭坛随女王离场连带清理：linked_nodes 由 boss_stage._exit_tree 回收。
	## 测试自管离场（不经 _die），RED 修复前后都应 PASS。
	var queen = _new_queen()
	var altar: Node = queen.altar
	_check(altar != null, "altar exists before queen exits")
	_check(queen.linked_nodes.has(altar), "altar registered in queen linked_nodes")
	queen.queue_free()  # 离场帧删女王，_exit_tree 里 altar.queue_free 下一帧生效
	await process_frame
	await process_frame
	_check(not is_instance_valid(altar), "altar cleaned via linked_nodes when queen exits tree")
	_clear_units()

func _test_death_self_recycle() -> void:
	## RED：女王死亡自救回收——0.2s 时演出中仍 valid，0.8s 内自回收。
	## 现状 _die 只淡出 sprite 不 queue_free，headless 无 main 清场 → 留尸，
	## 仅最后一条断言 FAIL，其余全 PASS。
	var queen = _new_queen()
	var defeated := [false]
	queen.boss_defeated.connect(func(): defeated[0] = true)
	queen.take_damage(1000000.0)
	_check(queen.is_dead, "queen dies when hp depleted")
	_check(defeated[0], "boss_defeated fires on death")
	var frames := 0
	var valid_at := int(round(0.2 / _tick))  # 0.2s ≈ 12 tick
	while is_instance_valid(queen) and frames < valid_at:
		await physics_frame
		frames += 1
	_check(is_instance_valid(queen), "death performance plays (still valid 0.2s after death)")
	var limit := int(round(0.8 / _tick))  # 0.8s ≈ 48 tick
	var recycled := false
	while frames < limit + 4:
		await physics_frame
		frames += 1
		if not is_instance_valid(queen):
			recycled = true
			break
	_check(recycled, "queen self-recycles within 0.8s of death")
	_clear_units()

func _finish() -> void:
	print("ECLIPSE_QUEEN_ANIMATION RESULT passed=%d failed=%d" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
