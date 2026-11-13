extends SceneTree
## 织血母皇行为回归 + 动画状态机：召唤上限、暴露停召、死亡连带清理、
## 8 状态映射、帧推进、死亡 0.6s 自回收、暂停冻结。
## -- --real-assets 模式校验 8 张真实 PNG（768×128）且不使用占位图。
## godot --headless --path . --script res://tools/blood_matriarch_animation_test.gd [-- --real-assets]

const STATES := ["idle", "move", "lay_egg", "summon", "web_cast", "melee", "phase_change", "death"]
const Slots = preload("res://scripts/core/asset_slots.gd")
var _pass := 0
var _fail := 0
var _host: Node2D
var _target: Target
var _textures: Dictionary = {}
var _real := false

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

func _new_queen() -> Node:
	var queen = load("res://scenes/enemies/blood_matriarch.tscn").instantiate()
	queen.skip_intro = true
	_host.add_child(queen)
	queen.set_process(false)
	queen.set_physics_process(false)
	queen.player = _target
	if not _real and "_animation_textures" in queen:
		queen._animation_textures = _textures.duplicate()
		queen._animation_state = ""
		queen._tick_sprite(0.0)
	return queen

func _pose(queen, state: String, label: String) -> void:
	_check(queen._animation_state == state and queen.sprite.texture == _textures.get(state) and not queen.using_placeholder, label + " [" + state + "]")

func _run() -> void:
	await process_frame
	_real = "--real-assets" in OS.get_cmdline_user_args()
	print("BLOOD_MATRIARCH_ANIMATION mode=" + ("real-assets" if _real else "fixture"))
	for state in STATES:
		if _real:
			var texture := Slots.boss_texture("blood_matriarch", state)
			_check(texture != null and texture.get_size() == Vector2(768, 128), "asset " + state + " is 6 x 128px")
			if texture != null:
				_textures[state] = texture
		else:
			var image := Image.create(768, 128, false, Image.FORMAT_RGBA8)
			image.fill(Color.from_hsv(float(STATES.find(state)) / 8.0, 0.7, 0.8))
			_textures[state] = ImageTexture.create_from_image(image)
	if _textures.size() != 8:
		_finish()
		return
	_host = Node2D.new()
	root.add_child(_host)
	current_scene = _host
	_target = Target.new()
	_target.collision_layer = 0
	_target.collision_mask = 0
	_host.add_child(_target)
	_test_interfaces_exist()
	## 幼虫隔离测试要求组内只有 fake_player；_target 延后入组
	await _test_larva_isolation()
	_target.add_to_group("player")
	await _test_summon_and_cap()
	await _test_expose_stops_summon()
	await _test_death_frees_larvae()
	_test_state_mapping()
	_test_frame_advance()
	_test_melee_contact_frame()
	_test_phase_visual()
	await _test_death_strip()
	await _test_pause_freezes_animation()
	_test_real_assets_bootstrap()
	_host.queue_free()
	await process_frame
	_finish()

func _test_interfaces_exist() -> void:
	var queen = load("res://scenes/enemies/blood_matriarch.tscn").instantiate()
	_check(queen.has_method("summon_larva"), "queen exposes summon_larva")
	_check(queen.has_method("_living_larvae"), "queen exposes _living_larvae")
	_check(ResourceLoader.exists("res://scenes/enemies/blood_larva.tscn"), "blood_larva scene exists")
	queen.free()

func _test_summon_and_cap() -> void:
	var queen = load("res://scenes/enemies/blood_matriarch.tscn").instantiate()
	queen.skip_intro = true
	_host.add_child(queen)
	await process_frame
	var spawned := []
	for i in 4:
		var larva = queen.summon_larva()
		if larva != null:
			spawned.append(larva)
	_check(spawned.size() == 3, "summon stops at larva cap 3")
	_check(queen._living_larvae() == 3, "living larvae count is 3")
	_check(queen.summon_larva() == null, "summon beyond cap returns null")

func _test_expose_stops_summon() -> void:
	var queen = load("res://scenes/enemies/blood_matriarch.tscn").instantiate()
	queen.skip_intro = true
	_host.add_child(queen)
	await process_frame
	var egg: Node = queen.lay_egg()
	_check(egg != null, "egg lays before expose")
	egg.take_damage(99.0)
	_check(queen.exposed, "egg destroyed exposes queen")
	_check(queen.summon_larva() == null, "no summon after expose")
	_check(queen.lay_egg() == null, "no egg after expose")

func _test_death_frees_larvae() -> void:
	var queen = load("res://scenes/enemies/blood_matriarch.tscn").instantiate()
	queen.skip_intro = true
	_host.add_child(queen)
	await process_frame
	var larva: Node = queen.summon_larva()
	_check(larva != null, "larva spawns before death")
	queen.take_damage(100000.0)
	await create_timer(0.8).timeout
	_check(not is_instance_valid(queen), "queen frees after death strip")
	_check(not is_instance_valid(larva), "larva freed with queen via linked_nodes")

func _test_larva_isolation() -> void:
	## Task 2 隔离验证（不触碰上方三个 Task 1 行为测试体）：
	## 幼虫场景可实例化、初始为 ORBIT、玩家靠近进入 WINDUP、计时耗尽推进 POUNCE、再回 ORBIT。
	## 放在母皇侧测试之前：summon_larva 是 Task 3 的职责，这里不依赖它。
	var queen := Node2D.new()
	queen.global_position = Vector2(600, 300)
	var fake_player := CharacterBody2D.new()
	fake_player.add_to_group("player")
	fake_player.global_position = Vector2(900, 300)  # 警戒半径 160 之外
	_host.add_child(queen)
	_host.add_child(fake_player)
	var larva = load("res://scenes/enemies/blood_larva.tscn").instantiate()
	larva.queen = queen
	larva.player = fake_player
	larva.global_position = queen.global_position + Vector2(90, 0)
	_host.add_child(larva)
	await process_frame
	await physics_frame
	_check(larva.motion == larva.Motion.ORBIT, "larva starts in ORBIT")
	# 玩家贴进警戒半径 → 预警
	fake_player.global_position = larva.global_position + Vector2(50, 0)
	await physics_frame
	_check(larva.motion == larva.Motion.WINDUP, "larva enters WINDUP on proximity")
	# 预警计时耗尽 → 扑咬（手动推帧，不等 WINDUP_TIME 自然跑完）
	larva._move_towards_player(0.4)
	_check(larva.motion == larva.Motion.POUNCE, "larva transitions WINDUP to POUNCE")
	# 扑咬计时耗尽 → 回到巡逻
	larva._move_towards_player(0.35)
	_check(larva.motion == larva.Motion.ORBIT, "larva returns to ORBIT after pounce")
	larva.queue_free()
	queen.queue_free()
	fake_player.queue_free()
	await process_frame

func _test_state_mapping() -> void:
	## Step 2：8 个状态在触发条件下各自选中对应条带
	var queen = _new_queen()
	_pose(queen, "idle", "spawn has dedicated idle")
	queen.velocity = Vector2(10.0, 0.0)
	queen._tick_sprite(0.0)
	_pose(queen, "move", "moving selects move")
	queen.velocity = Vector2.ZERO
	queen._pending_kind = "summon"
	queen._pending_timer = queen.CONTACT_DELAY
	queen._tick_sprite(0.0)
	_pose(queen, "summon", "pending summon selects summon strip")
	queen._pending_kind = "egg"
	queen._tick_sprite(0.0)
	_pose(queen, "lay_egg", "pending egg selects lay_egg strip")
	queen._pending_kind = "web"
	queen._tick_sprite(0.0)
	_pose(queen, "web_cast", "pending web selects web_cast strip")
	queen._pending_kind = "melee"
	queen._tick_sprite(0.0)
	_pose(queen, "melee", "pending melee selects melee strip")
	queen._pending_kind = ""
	queen._expose()
	_pose(queen, "phase_change", "expose starts phase_change strip")
	queen.free()

func _test_frame_advance() -> void:
	## sprite.frame 随计时推进：待机 8fps 循环，动作条带按 ACTION_VISUAL 匀速走帧
	var queen = _new_queen()
	_check(queen.sprite.frame == 0, "idle starts at frame 0")
	queen._tick_sprite(0.13)
	_check(queen.sprite.frame == 1, "idle loop advances with time")
	queen._pending_kind = "summon"
	queen._pending_timer = queen.CONTACT_DELAY
	queen._tick_sprite(0.0)
	queen._tick_sprite(0.125)
	_check(queen.sprite.frame == 1, "summon strip advances on its own clock")
	queen._tick_sprite(0.125)
	_check(queen.sprite.frame == 3, "summon strip reaches mid frames on schedule")
	queen.free()

func _test_melee_contact_frame() -> void:
	## 挥击结算瞬间画面钉在接触帧 4；伤害时点仍由 _pending_timer 0.25s 保证
	var queen = _new_queen()
	queen.exposed = true
	_target.position = queen.global_position + Vector2(40, 0)
	_target.hp = 1000.0
	queen._pending_kind = "melee"
	queen._pending_timer = 0.001
	queen._physics_process(0.01)
	_check(is_equal_approx(_target.hp, 982.0), "melee resolves original 18 damage")
	_check(queen.sprite.frame == 4, "melee settlement lands on contact frame 4")
	_check(queen._animation_state == "melee" and queen._last_action == "melee", "melee strip persists after settlement")
	_check(queen._action_visual_remaining > 0.0, "action visual outlives settlement")
	queen._tick_sprite(0.3)
	_check(queen.sprite.frame == 5, "melee recovery advances to frame 5")
	queen._tick_sprite(0.3)
	_pose(queen, "move", "melee visual expires back to locomotion")
	queen.free()

func _test_phase_visual() -> void:
	## PHASE_VISUAL 0.6s 变身表现：期间速度为零，结束后恢复追击
	var queen = _new_queen()
	_target.position = queen.global_position + Vector2(200, 0)
	queen._expose()
	_check(queen.sprite.frame == 0, "phase_change begins at frame 0")
	queen._physics_process(0.016)
	_check(queen.velocity == Vector2.ZERO, "phase visual pins velocity to zero")
	queen._tick_sprite(0.3)
	_check(queen.sprite.frame == 3, "phase_change advances on its own clock")
	queen._tick_sprite(0.35)
	_check(not queen._in_phase_visual(), "phase visual ends after PHASE_VISUAL")
	queen._physics_process(0.016)
	_check(queen.velocity.length_squared() > 1.0, "chase resumes after phase visual")
	queen.free()

func _test_death_strip() -> void:
	## 条带死亡演出：0 起播、推进可见、~0.6s 自回收
	var queen = _new_queen()
	queen.take_damage(100000.0)
	_pose(queen, "death", "death selects dedicated strip")
	_check(queen.sprite.frame == 0, "death begins at first frame")
	await create_timer(0.24).timeout
	_check(is_instance_valid(queen) and queen.sprite.frame >= 2, "death advances visibly over strip")
	await create_timer(0.45).timeout
	_check(not is_instance_valid(queen), "death frees itself at ~0.6s")

func _test_pause_freezes_animation() -> void:
	## 树暂停冻结表现时钟；恢复后继续走帧
	var queen = _new_queen()
	queen.set_process(true)
	queen._tick_sprite(0.13)
	var frame: int = queen.sprite.frame
	var elapsed: float = queen._animation_elapsed
	paused = true
	await create_timer(0.18, true).timeout
	_check(queen.sprite.frame == frame and queen._animation_elapsed == elapsed, "tree pause freezes animation clock")
	paused = false
	await create_timer(0.1).timeout
	_check(queen._animation_elapsed > elapsed, "animation clock resumes after unpause")
	queen.free()

func _test_real_assets_bootstrap() -> void:
	## --real-assets：8 张真实 PNG 全部进缓存，启动即非占位
	if not _real:
		return
	var queen = _new_queen()
	_check(queen.using_placeholder == false, "real assets boot without placeholder")
	_check(queen._animation_textures.size() == 8, "all eight strips cached at boot")
	queen.free()

func _finish() -> void:
	print("BLOOD_MATRIARCH_ANIMATION RESULT passed=%d failed=%d" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
