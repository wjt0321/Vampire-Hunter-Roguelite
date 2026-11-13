extends SceneTree
## 墓穴守望者行为回归：扫击窗与方向锁定、复苏被结界门控、死亡连带清理。
## -- --real-assets 模式校验 6 张真实 PNG（768×128）（素材任务交付后启用）。
## godot --headless --path . --script res://tools/tomb_warden_animation_test.gd [-- --real-assets]
##
## 预期 RED：仅 _test_death_frees_ward 的两条自回收断言失败
## （boss_stage._die() 不自回收，本 harness 也没有 main 的清场）；
## 扫击/复苏/结界断言全部针对既有行为，必须一开始就 PASS。
##
## 玩家替身：与织血母皇测试同一模式 —— Target(CharacterBody2D) 命名 "Player"
## 并加入 "player" 组；_new_warden() 显式 warden.player = _target，
## 不依赖 _find_player 的延迟一帧，扫击断言前 player 必非空。

const STATES := ["idle", "move", "lantern_sweep", "revive", "ward_break", "death"]
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

func _new_warden() -> Node:
	var warden = load("res://scenes/enemies/tomb_warden.tscn").instantiate()
	warden.skip_intro = true
	_host.add_child(warden)
	warden.player = _target
	if not _real and "_animation_textures" in warden:
		warden._animation_textures = _textures.duplicate()
		warden._animation_state = ""
		warden._tick_sprite(0.0)
	return warden

func _run() -> void:
	await process_frame
	_real = "--real-assets" in OS.get_cmdline_user_args()
	print("TOMB_WARDEN_ANIMATION mode=" + ("real-assets" if _real else "fixture"))
	for state in STATES:
		if _real:
			var texture := Slots.boss_texture("tomb_warden", state)
			_check(texture != null and texture.get_size() == Vector2(768, 128), "asset " + state + " is 6 x 128px")
			if texture != null:
				_textures[state] = texture
		else:
			var image := Image.create(768, 128, false, Image.FORMAT_RGBA8)
			image.fill(Color.from_hsv(float(STATES.find(state)) / 6.0, 0.7, 0.8))
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
	_target.global_position = Vector2(200, 0)  # 守望者右侧 200px：扫击锁定方向之内
	_target.add_to_group("player")
	_test_interfaces_exist()
	await _test_sweep_window_and_lock()
	await _test_revive_gated_by_ward()
	await _test_death_frees_ward()
	_host.queue_free()
	await process_frame
	_finish()

func _test_interfaces_exist() -> void:
	var warden = load("res://scenes/enemies/tomb_warden.tscn").instantiate()
	_check(warden.has_method("_sweep_hits"), "warden exposes _sweep_hits")
	_check(warden.has_method("can_revive"), "warden exposes can_revive")
	_check(warden.has_method("ward_broken"), "warden exposes ward_broken")
	_check("ward" in warden, "warden exposes ward")
	_check(ResourceLoader.exists("res://scripts/enemies/ward_core.gd"), "ward_core script exists")
	_check(ResourceLoader.exists("res://scenes/enemies/zombie.tscn"), "zombie scene exists")
	warden.free()

func _test_sweep_window_and_lock() -> void:
	var warden = _new_warden()
	await process_frame
	_check(warden.ward != null, "ward spawns with warden")
	warden._sweep_dir = Vector2.RIGHT
	warden._sweep_left = 0.55
	var player = _host.get_node_or_null("Player")
	# 玩家在锁定方向 200px 处：命中
	_check(warden._sweep_hits() == true, "sweep hits player inside locked sector")
	# 玩家在反方向：不命中（方向已锁定）
	warden._sweep_dir = Vector2.LEFT
	_check(warden._sweep_hits() == false, "sweep misses player behind locked direction")

func _test_revive_gated_by_ward() -> void:
	var warden = _new_warden()
	await process_frame
	_check(warden.can_revive() == true, "can revive while ward alive")
	warden.ward.take_damage(99.0)
	await process_frame
	_check(warden.can_revive() == false, "cannot revive after ward broken")
	_check(warden.ward == null, "ward reference cleared on break")

func _test_death_frees_ward() -> void:
	var warden = _new_warden()
	await process_frame
	var ward: Node = warden.ward
	_check(ward != null, "ward exists before death")
	warden.take_damage(100000.0)
	await create_timer(0.8).timeout
	_check(not is_instance_valid(warden), "warden frees after death strip")
	_check(not is_instance_valid(ward), "ward freed with warden via linked_nodes")

func _finish() -> void:
	print("TOMB_WARDEN_ANIMATION RESULT passed=%d failed=%d" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
