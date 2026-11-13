extends SceneTree
## 织血母皇行为回归：召唤上限、暴露停召、死亡连带清理。失败回归先行，红expected。
## godot --headless --path . --script res://tools/blood_matriarch_animation_test.gd

const STATES := ["idle", "move", "death"]
var _pass := 0
var _fail := 0
var _host: Node2D
var _textures: Dictionary = {}

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
	print("BLOOD_MATRIARCH_ANIMATION mode=fixture")
	for state in STATES:
		var image := Image.create(768, 128, false, Image.FORMAT_RGBA8)
		image.fill(Color.from_hsv(float(STATES.find(state)) / 6.0, 0.7, 0.8))
		_textures[state] = ImageTexture.create_from_image(image)
	_host = Node2D.new()
	root.add_child(_host)
	current_scene = _host
	_test_interfaces_exist()
	await _test_larva_isolation()
	await _test_summon_and_cap()
	await _test_expose_stops_summon()
	await _test_death_frees_larvae()
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

func _finish() -> void:
	print("BLOOD_MATRIARCH_ANIMATION RESULT passed=%d failed=%d" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
