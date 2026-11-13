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

func _finish() -> void:
	print("BLOOD_MATRIARCH_ANIMATION RESULT passed=%d failed=%d" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
