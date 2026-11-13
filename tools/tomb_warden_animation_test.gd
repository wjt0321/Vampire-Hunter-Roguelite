extends SceneTree
## 墓穴守望者行为回归 + 动画状态机：扫击窗与方向锁定、复苏被结界门控、死亡连带清理、
## 6 状态映射、帧推进、扫击朝向锁定、死亡 0.6s 自回收、暂停冻结。
## -- --real-assets 模式校验 6 张真实 PNG（768×128）且不使用占位图。
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
	# 动画帧断言手动推 _tick_sprite：关掉自动处理（行为断言不依赖自动帧）
	warden.set_process(false)
	warden.set_physics_process(false)
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
	_test_state_mapping()
	_test_frame_advance()
	_test_sweep_facing_lock()
	_test_visual_timers()
	await _test_death_animation()
	await _test_pause_freezes_animation()
	_test_real_assets_bootstrap()
	_host.queue_free()
	await process_frame
	_finish()

func _test_interfaces_exist() -> void:
	var warden = load("res://scenes/enemies/tomb_warden.tscn").instantiate()
	_check(warden.has_method("_sweep_hits"), "warden exposes _sweep_hits")
	_check(warden.has_method("can_revive"), "warden exposes can_revive")
	_check(warden.has_method("ward_broken"), "warden exposes ward_broken")
	_check("ward" in warden, "warden exposes ward")
	_check(warden.has_method("_show_animation"), "warden exposes _show_animation")
	_check(warden.has_method("_tick_sprite"), "warden exposes _tick_sprite")
	_check(warden.has_method("_set_animation_frame"), "warden exposes _set_animation_frame")
	_check(warden.has_method("_animation_for_state"), "warden exposes _animation_for_state")
	_check(warden.has_method("_advance_death_frame"), "warden exposes _advance_death_frame")
	_check("_animation_textures" in warden, "warden exposes _animation_textures")
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

func _pose(warden, state: String, label: String) -> void:
	_check(warden._animation_state == state and warden.sprite.texture == _textures.get(state) and not warden.using_placeholder, label + " [" + state + "]")

func _test_state_mapping() -> void:
	## Step 2：6 状态映射与优先级 death > intro(idle) > sweep > revive > ward_break > move > idle
	var warden = _new_warden()
	_pose(warden, "idle", "spawn has dedicated idle")
	warden.velocity = Vector2(10.0, 0.0)
	warden._tick_sprite(0.0)
	_pose(warden, "move", "moving selects move")
	warden.velocity = Vector2.ZERO
	warden._sweep_left = 0.55
	warden._sweep_dir = Vector2.LEFT
	warden._tick_sprite(0.0)
	_pose(warden, "lantern_sweep", "sweep window selects lantern_sweep")
	warden._revive_visual_remaining = warden.REVIVE_VISUAL
	warden._tick_sprite(0.0)
	_pose(warden, "lantern_sweep", "sweep outranks revive")
	warden._sweep_left = 0.0
	warden._tick_sprite(0.0)
	_pose(warden, "revive", "revive visual selects revive")
	warden._revive_visual_remaining = 0.0
	warden._ward_break_visual_remaining = warden.WARD_BREAK_VISUAL
	warden._tick_sprite(0.0)
	_pose(warden, "ward_break", "ward break visual selects ward_break")
	warden._ward_break_visual_remaining = 0.0
	warden._revive_visual_remaining = warden.REVIVE_VISUAL
	warden.intro_invulnerable = true
	warden._tick_sprite(0.0)
	_pose(warden, "idle", "intro pins idle above action visuals")
	warden.intro_invulnerable = false
	_check(warden._animation_for_state() == "revive", "revive resumes when intro lifts")
	warden.is_dead = true
	_check(warden._animation_for_state() == "death", "death outranks everything")
	warden.free()

func _test_frame_advance() -> void:
	## sprite.frame 随计时推进：待机 8fps 循环，动作条带按各自表现时钟匀速走帧
	var warden = _new_warden()
	_check(warden.sprite.frame == 0, "idle starts at frame 0")
	warden._tick_sprite(0.13)
	_check(warden.sprite.frame == 1, "idle loop advances with time")
	warden._sweep_left = 0.55
	warden._sweep_dir = Vector2.RIGHT
	warden._tick_sprite(0.0)
	_check(warden.sprite.frame == 0, "sweep strip starts at frame 0")
	warden._tick_sprite(0.1)
	_check(warden.sprite.frame == 1, "sweep strip advances on its own clock")
	warden._tick_sprite(0.2)
	_check(warden.sprite.frame == 3, "sweep reaches mid frames on schedule")
	warden._sweep_left = 0.0
	warden._revive_visual_remaining = warden.REVIVE_VISUAL
	warden._tick_sprite(0.0)
	_check(warden.sprite.frame == 0, "revive strip starts at frame 0")
	warden._tick_sprite(0.31)
	_check(warden.sprite.frame == 3, "revive advances on REVIVE_VISUAL clock")
	warden._revive_visual_remaining = 0.0
	warden._ward_break_visual_remaining = warden.WARD_BREAK_VISUAL
	warden._tick_sprite(0.0)
	_check(warden.sprite.frame == 0, "ward_break strip starts at frame 0")
	warden._tick_sprite(0.31)
	_check(warden.sprite.frame == 3, "ward_break advances on WARD_BREAK_VISUAL clock")
	warden.free()

func _test_sweep_facing_lock() -> void:
	## 台账硬约束：提灯朝向与扫射预警同向——sweep 期间 flip_h 锁定 _sweep_dir，不跟移动方向
	var warden = _new_warden()
	warden.velocity = Vector2(10.0, 0.0)
	warden._sweep_dir = Vector2.LEFT
	warden._sweep_left = 0.55
	warden._tick_sprite(0.0)
	_check(warden.sprite.flip_h == true, "sweep facing locks to left sweep dir")
	warden._sweep_dir = Vector2.RIGHT
	warden._tick_sprite(0.0)
	_check(warden.sprite.flip_h == false, "sweep facing follows locked right dir")
	warden._sweep_left = 0.0
	warden._tick_sprite(0.0)
	_check(warden.sprite.flip_h == false, "facing falls back to velocity after sweep")
	warden.velocity = Vector2(-10.0, 0.0)
	warden._tick_sprite(0.0)
	_check(warden.sprite.flip_h == true, "moving left flips sprite")
	warden.free()

func _test_visual_timers() -> void:
	## revive/ward_break 表现时钟：_raise_one/ward_broken 同帧起播、tick 递减、到期回落 idle
	var warden = _new_warden()
	warden._raise_one()
	_check(warden._revive_visual_remaining > 0.0, "raise starts revive visual same frame")
	_pose(warden, "revive", "raise selects revive strip immediately")
	warden._tick_sprite(0.4)
	_check(warden._revive_visual_remaining > 0.0, "revive visual outlives mid strip")
	warden._tick_sprite(0.3)
	_check(warden._revive_visual_remaining == 0.0, "revive visual expires on schedule")
	_pose(warden, "idle", "warden falls back to idle after revive visual")
	warden.ward_broken()
	_check(warden._ward_break_visual_remaining > 0.0, "ward broken starts ward_break visual same frame")
	_pose(warden, "ward_break", "ward broken selects ward_break strip immediately")
	warden._tick_sprite(0.65)
	_check(warden._ward_break_visual_remaining == 0.0, "ward_break visual expires on schedule")
	warden.free()

func _test_death_animation() -> void:
	## 真实素材分支：death 条带 0 起播、tween 推帧可见、~0.6s 自回收
	var warden = _new_warden()
	warden.take_damage(100000.0)
	_pose(warden, "death", "death selects dedicated strip")
	_check(warden.sprite.frame == 0, "death begins at first frame")
	await create_timer(0.24).timeout
	_check(is_instance_valid(warden) and warden.sprite.frame >= 2, "death advances visibly over strip")
	await create_timer(0.45).timeout
	_check(not is_instance_valid(warden), "death frees itself at ~0.6s")

func _test_pause_freezes_animation() -> void:
	## 树暂停冻结表现时钟；恢复后继续走帧（沿用基类 tick 链，不新造计时源）
	var warden = _new_warden()
	warden.set_process(true)
	warden._tick_sprite(0.13)
	var frame: int = warden.sprite.frame
	var elapsed: float = warden._animation_elapsed
	paused = true
	await create_timer(0.18, true).timeout
	_check(warden.sprite.frame == frame and warden._animation_elapsed == elapsed, "tree pause freezes animation clock")
	paused = false
	await create_timer(0.1).timeout
	_check(warden._animation_elapsed > elapsed, "animation clock resumes after unpause")
	warden.free()

func _test_real_assets_bootstrap() -> void:
	## --real-assets：6 张真实 PNG 全部进缓存，启动即非占位
	if not _real:
		return
	var warden = _new_warden()
	_check(warden.using_placeholder == false, "real assets boot without placeholder")
	_check(warden._animation_textures.size() == 6, "all six strips cached at boot")
	warden.free()

func _finish() -> void:
	print("TOMB_WARDEN_ANIMATION RESULT passed=%d failed=%d" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
