extends SceneTree
## Real boss scene + deterministic physics stepping; --real-assets requires all shipped strips.
## godot --headless --path . --script res://tools/blood_lord_animation_test.gd -- --real-assets

const STATES := ["idle", "move", "guard", "sword_combo", "charge", "shield_break", "stunned", "enraged", "death", "broken_move", "broken_sword_combo", "guarded_stunned"]
const Slots = preload("res://scripts/core/asset_slots.gd")
var _pass := 0
var _fail := 0
var _host: Node2D
var _target: Target
var _textures: Dictionary = {}
var _real := false

class Target extends CharacterBody2D:
	var hp := 1000.0
	var hit_frames: Array = []
	var boss: Node
	func take_damage(amount: float, _origin: Vector2 = Vector2.ZERO) -> void:
		hp -= amount
		if is_instance_valid(boss):
			hit_frames.append(boss.sprite.frame)

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, label: String) -> void:
	if ok:
		_pass += 1
		print("PASS " + label)
	else:
		_fail += 1
		print("FAIL " + label)

func _new_boss(parent: Node = null):
	var boss = load("res://scenes/enemies/blood_lord.tscn").instantiate()
	boss.skip_intro = true
	(parent if parent != null else _host).add_child(boss)
	boss.set_process(false)
	boss.set_physics_process(false)
	boss.player = _target
	_target.boss = boss
	_target.position = Vector2(60, 0)
	_target.hp = 1000.0
	_target.hit_frames.clear()
	if not _real and "_animation_textures" in boss:
		boss._animation_textures = _textures.duplicate()
		boss._animation_state = ""
	boss._tick_sprite(0.0)
	return boss

func _step(boss, delta: float) -> void:
	boss._physics_process(delta)
	boss._tick_sprite(delta)

func _pose(boss, state: String, label: String) -> void:
	_check(boss.sprite.texture == _textures.get(state) and not boss.using_placeholder, label + " [" + state + "]")

func _run() -> void:
	await process_frame
	_real = "--real-assets" in OS.get_cmdline_user_args()
	print("BLOOD_LORD_ANIMATION mode=" + ("real-assets" if _real else "fixture"))
	for state in STATES:
		if _real:
			var texture := Slots.boss_texture("blood_lord", state)
			_check(texture != null and texture.get_size() == Vector2(768, 128), "asset " + state + " is 6 x 128px")
			if texture != null:
				_textures[state] = texture
		else:
			var image := Image.create(768, 128, false, Image.FORMAT_RGBA8)
			image.fill(Color.from_hsv(float(STATES.find(state)) / 12.0, 0.7, 0.8))
			_textures[state] = ImageTexture.create_from_image(image)
	if _textures.size() != 12:
		_finish()
		return
	_host = Node2D.new()
	root.add_child(_host)
	current_scene = _host
	_target = Target.new()
	_target.collision_layer = 0
	_target.collision_mask = 0
	_host.add_child(_target)
	_target.add_to_group("player")
	_test_movement_and_charge()
	_test_combo(false)
	_test_combo(true)
	_test_shield_and_fallback()
	_test_attack_priority()
	_test_interrupted_break()
	_test_stun_facing()
	await _test_pause_and_status()
	await _test_death()
	await _test_scene_cleanup()
	_host.queue_free()
	await process_frame
	_finish()

func _test_movement_and_charge() -> void:
	var boss = _new_boss()
	_pose(boss, "idle", "spawn has dedicated idle")
	boss._tick_sprite(0.13)
	_check(boss.sprite.frame == 1, "idle loop advances")
	_target.position = Vector2(-260, 0)
	_step(boss, 0.01)
	_pose(boss, "move", "real chase selects move")
	_check(boss.sprite.flip_h, "left chase flips sprite")
	_target.position = Vector2(260, 0)
	_step(boss, 0.01)
	_check(not boss.sprite.flip_h, "right chase flips back")
	boss._motion_timer = 0.001
	_step(boss, 0.01)
	_check(boss.motion == boss.Motion.WINDUP and is_equal_approx(boss._motion_timer, 0.45), "far chase enters original 0.45s windup")
	_pose(boss, "guard", "windup uses shield guard")
	_step(boss, 0.44)
	_check(boss.motion == boss.Motion.WINDUP and boss.sprite.frame == 5, "guard reaches final frame within original windup")
	_step(boss, 0.011)
	_check(boss.motion == boss.Motion.CHARGE and is_equal_approx(boss._motion_timer, 0.42), "windup enters original 0.42s charge")
	_pose(boss, "charge", "charge uses charge strip")
	_target.position = Vector2(-260, 0)
	_step(boss, 0.01)
	_check(not boss.sprite.flip_h and boss.velocity.x > 0.0, "charge keeps locked right direction after player crosses")
	_step(boss, 0.39)
	_check(boss.motion == boss.Motion.CHARGE and boss.sprite.frame == 5, "charge reaches final frame inside original 0.42s window")
	boss.notify_wall_contact()
	boss._tick_sprite(0.1)
	_pose(boss, "guarded_stunned", "unbroken wall stun retains shield")
	_check(is_equal_approx(boss._motion_timer, 1.35), "visual stun does not extend control")
	_check(is_zero_approx(boss.sprite.rotation), "shielded stun uses strip without fallback sway")
	_step(boss, 1.351)
	_check(boss.motion == boss.Motion.IDLE and is_equal_approx(boss._motion_timer, 0.45), "wall stun returns on original timer")
	_check(is_zero_approx(boss.sprite.rotation), "sway clears when stun ends")
	boss.free()

func _test_combo(broken: bool) -> void:
	var boss = _new_boss()
	if broken:
		boss._break_shield()
	boss._motion_timer = 0.001
	_step(boss, 0.01)
	var state := "broken_sword_combo" if broken else "sword_combo"
	var damage := 18.0 if broken else 14.0
	var count := 3 if broken else 2
	var impact := 2 if broken else 3
	var anticipation := 1 if broken else 2
	_pose(boss, state, "near chase starts correct combo")
	_check(boss.motion == boss.Motion.SWING and boss.sprite.frame == 0, "combo begins at windup frame 0")
	_step(boss, 0.1)
	_check(boss.sprite.frame == (0 if broken else 1) and _target.hp == 1000.0, "first strike 0.10s: anticipation only")
	_step(boss, 0.119)
	_check(boss.sprite.frame == anticipation and _target.hp == 1000.0, "first strike 0.219s: no early damage")
	_step(boss, 0.002)
	_check(_target.hp == 1000.0 - damage and boss.sprite.frame == impact and _target.hit_frames == [impact], "first strike at 0.22s applies HP on impact frame %d" % impact)
	for index in range(1, count):
		_step(boss, 0.06)
		_check(boss.sprite.frame == (3 if broken else 4), "combo enters recovery after impact")
		_step(boss, 0.081)
		_check(boss.sprite.frame == 0, "next swing restarts after recovery")
		_step(boss, 0.138)
		_check(boss.sprite.frame == anticipation and _target.hp == 1000.0 - damage * index, "next swing has no damage before 0.28s interval")
		_step(boss, 0.002)
		_check(_target.hp == 1000.0 - damage * (index + 1) and boss.sprite.frame == impact, "next swing hits at original 0.28s interval")
	_check(boss.motion == boss.Motion.IDLE and is_equal_approx(boss._motion_timer, 0.35 if broken else 0.7), "final strike keeps original recovery timer")
	_check(_target.hit_frames.count(impact) == count, "all actual damage callbacks observe impact frame %d" % impact)
	_step(boss, 0.1)
	_pose(boss, state, "last strike recovery survives transition to IDLE")
	_check(boss.sprite.frame == (4 if broken else 5), "last strike recovery advances without extra damage")
	_step(boss, 0.025)
	_check(boss.sprite.frame == 5, "last strike shows final recovery frame")
	_step(boss, 0.025)
	_pose(boss, "broken_move" if broken else "move", "chase resumes without restoring broken shield")
	boss.free()

func _test_shield_and_fallback() -> void:
	var boss = _new_boss()
	var hp: float = boss.current_hp
	boss.take_damage_with_knockback(20.0, Vector2.LEFT)
	_check(is_equal_approx(boss.current_hp, hp - 6.0) and is_equal_approx(boss.shield_hp, 81.0), "frontal damage keeps 70 percent reduction and shield damage")
	boss.take_damage_with_knockback(82.0, Vector2.RIGHT)
	boss._tick_sprite(0.0)
	_pose(boss, "shield_break", "back hit breaks shield immediately")
	_check(boss.phase == boss.Phase.BROKEN and is_equal_approx(boss.current_hp, hp - 88.0), "shield break preserves HP logic")
	boss._tick_sprite(0.16)
	var break_frame: int = boss.sprite.frame
	boss.take_damage(1.0)
	boss._break_shield()
	boss._tick_sprite(0.0)
	_check(boss.sprite.frame == break_frame and break_frame > 0, "repeated hits do not restart shield break")
	boss._tick_sprite(0.15)
	_pose(boss, "enraged", "shield break flows into visible enraged pose")
	boss._tick_sprite(0.4)
	_step(boss, 0.01)
	_pose(boss, "broken_move", "enraged chase uses unshielded move")
	boss.motion = boss.Motion.CHARGE
	boss.notify_wall_contact()
	boss._tick_sprite(0.0)
	_pose(boss, "stunned", "broken wall stun uses unshielded stunned strip")
	if "_animation_textures" in boss:
		boss._animation_textures.erase("stunned")
		boss._animation_state = ""
		boss._tick_sprite(0.0)
		_check(boss.sprite.texture != null and boss.using_placeholder and boss.sprite.texture != _textures["idle"], "missing action has visible honest fallback, not shielded idle")
		boss._animation_textures.clear()
		boss._animation_state = ""
		boss._tick_sprite(0.2)
		_check(boss.sprite.texture != null and boss.using_placeholder, "all missing strips retain visible fallback")
	else:
		_check(false, "missing action has visible honest fallback, not shielded idle")
	boss.free()

func _test_attack_priority() -> void:
	var boss = _new_boss()
	boss._motion_timer = 0.001
	_step(boss, 0.01)
	_step(boss, 0.1)
	boss.take_damage_with_knockback(91.0, Vector2.RIGHT)
	_pose(boss, "broken_sword_combo", "mid-swing shield break preserves attack telegraph")
	_check(boss.sprite.frame == 0 and is_equal_approx(boss._motion_timer, 0.12), "mid-swing break does not reset windup")
	_step(boss, 0.121)
	_check(_target.hp == 982.0 and _target.hit_frames == [2], "mid-swing break preserves hit time with broken damage")
	boss.free()
	boss = _new_boss()
	_target.position = Vector2(-260, 0)
	boss._motion_timer = 0.001
	_step(boss, 0.01)
	_step(boss, 0.451)
	_target.position = Vector2(260, 0)
	_step(boss, 0.01)
	_check(boss.sprite.flip_h and boss.velocity.x < 0.0, "left charge stays locked after player crosses right")
	boss.take_damage(91.0)
	_pose(boss, "broken_move", "mid-charge break cannot restore shielded charge strip")
	_check(boss.motion == boss.Motion.CHARGE and is_equal_approx(boss._motion_timer, 0.41), "break does not extend or cancel charge")
	_step(boss, 0.411)
	_check(boss.motion == boss.Motion.IDLE and is_equal_approx(boss._motion_timer, 0.55), "charge timeout keeps original recovery")
	boss.free()

func _test_interrupted_break() -> void:
	var boss = _new_boss()
	boss.motion = boss.Motion.CHARGE
	boss._charge_dir = Vector2.RIGHT
	boss._motion_timer = 0.01
	boss._break_shield()
	_pose(boss, "broken_move", "late charge break immediately removes shield")
	_step(boss, 0.011)
	_check(boss.motion == boss.Motion.IDLE and boss._animation_state != "shield_break", "charge expiry cannot replay shield-break shielded opening")
	boss.free()

	boss = _new_boss()
	boss._break_shield()
	boss._tick_sprite(0.02)
	_pose(boss, "shield_break", "break begins before attack interruption")
	boss._motion_timer = 0.001
	_step(boss, 0.01)
	_pose(boss, "broken_sword_combo", "attack interrupts active break animation")
	# Physics catch-up before the next render tick must not resurrect the shield.
	boss._physics_process(0.221)
	boss._physics_process(0.281)
	boss._physics_process(0.281)
	boss._physics_process(0.141)
	_check(boss.motion == boss.Motion.IDLE and boss._animation_state != "shield_break", "interrupted active break cannot resume its shielded opening")
	boss.free()

	boss = _new_boss()
	boss._motion_timer = 0.001
	_step(boss, 0.01)
	_step(boss, 0.221)
	_step(boss, 0.281)
	_step(boss, 0.13)
	boss._break_shield()
	_pose(boss, "broken_sword_combo", "break during final recovery keeps unshielded sword")
	_step(boss, 0.011)
	_check(boss._animation_state != "shield_break", "final recovery expiry cannot restore the shield")
	boss.free()

func _test_stun_facing() -> void:
	var boss = _new_boss()
	boss.motion = boss.Motion.CHARGE
	boss._charge_dir = Vector2.RIGHT
	boss.notify_wall_contact()
	_target.position = Vector2(-60, 0)
	boss._tick_sprite(0.0)
	var hp: float = boss.current_hp
	boss.take_damage_with_knockback(20.0, Vector2.RIGHT)
	_check(is_equal_approx(boss.current_hp, hp - 6.0), "stun keeps existing frontal damage reduction after player circles left")
	_check(boss.sprite.flip_h and boss.is_frontal_hit(Vector2.RIGHT), "stunned shield faces left where 20 damage is reduced to 6")
	_target.position = Vector2(60, 0)
	boss._tick_sprite(0.0)
	hp = boss.current_hp
	boss.take_damage_with_knockback(20.0, Vector2.LEFT)
	_check(not boss.sprite.flip_h and is_equal_approx(boss.current_hp, hp - 6.0), "stunned shield follows frontal blocking back to the right")
	boss.free()

func _test_pause_and_status() -> void:
	var boss = _new_boss()
	boss.set_process(true)
	boss.bleed_dps = 2.0
	boss.bleed_remaining = 1.0
	boss._bleed_tick_timer = 0.0
	var hp: float = boss.current_hp
	await process_frame
	await process_frame
	_check(boss.current_hp < hp, "inherited process still applies bleed")
	paused = true
	var frame: int = boss.sprite.frame
	var remaining: float = boss.bleed_remaining
	await create_timer(0.18, true).timeout
	_check(boss.sprite.frame == frame and boss.bleed_remaining == remaining, "tree pause freezes animation and status")
	paused = false
	boss.free()

func _test_death() -> void:
	var boss = _new_boss()
	var counts := {"defeated": 0, "died": 0}
	boss.enemy_died.connect(func(_enemy): counts.died += 1)
	boss.boss_defeated.connect(func():
		counts.defeated += 1
		for enemy in get_nodes_in_group("enemies"):
			enemy.queue_free()
	)
	boss.take_damage(100000.0)
	boss._die()
	_check(counts.defeated == 1 and counts.died == 1, "death settles both signals immediately exactly once")
	_check(not boss.is_in_group("enemies") and not boss.is_queued_for_deletion(), "death survives main enemy-group cleanup")
	_pose(boss, "death", "death selects dedicated strip")
	_check(boss.sprite.frame == 0, "death begins at first frame")
	await process_frame
	await process_frame
	if not is_instance_valid(boss):
		_check(false, "death remains alive to play animation")
		return
	_check(boss.get_node("ContactArea/ContactShape").disabled and boss.collision_shape.disabled and not boss.get_node("ContactArea").monitoring, "death disables body and contact area")
	paused = true
	var frame: int = boss.sprite.frame
	await create_timer(0.16, true).timeout
	_check(boss.sprite.frame == frame, "death tween freezes while paused")
	paused = false
	await create_timer(0.24).timeout
	_check(is_instance_valid(boss) and boss.sprite.frame >= 2 and boss.sprite.modulate.a > 0.9, "death advances visibly without base fade")
	await create_timer(0.5).timeout
	_check(not is_instance_valid(boss), "death frees itself after strip completes")
	if is_instance_valid(boss):
		boss.free()

func _wait_until(test: Callable, seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if test.call():
			return true
		await create_timer(0.05).timeout
	return bool(test.call())

func _spawn_main_boss(game, floor_index: int):
	game.dungeon.current_floor = floor_index
	game._create_room(2080.0, 1248.0, "boss")
	await process_frame
	await process_frame
	game._enter_boss_room()
	var bosses := get_nodes_in_group("boss")
	_check(bosses.size() == 1, "real main spawns one boss on floor %d" % floor_index)
	if bosses.size() != 1:
		return null
	var boss = bosses[0]
	boss.set_physics_process(false)
	var vulnerable := await _wait_until(func(): return not boss.intro_invulnerable, 3.0)
	_check(vulnerable, "real main boss finishes intro")
	_check(boss.get_parent() == game and boss.get_parent() != game.current_room, "real boss is current_scene child and room sibling")
	return boss

func _test_scene_cleanup() -> void:
	# Exercise production room creation/spawning rather than parenting a fixture boss to a room.
	var saves = root.get_node("SaveManager")
	_check(saves.is_tool_run, "real main integration uses isolated test save")
	if not saves.is_tool_run:
		return
	_target.remove_from_group("player")
	var game = load("res://scenes/main.tscn").instantiate()
	game.debug_loot_grace_seconds = 1
	root.add_child(game)
	current_scene = game
	var started := await _wait_until(func(): return game.wave_manager.is_active, 6.0)
	_check(started, "real main startup finishes")
	if not started:
		game.queue_free()
		await process_frame
		current_scene = _host
		_target.add_to_group("player")
		return
	game.wave_manager.stop()
	game.weapon_manager.set_process(false)
	game.player.set_physics_process(false)
	game.player.xp_to_next_level = 1000000
	for enemy in get_nodes_in_group("enemies"):
		enemy.queue_free()
	await process_frame
	await process_frame

	for replace_room in [true, false]:
		var boss = await _spawn_main_boss(game, 1)
		if boss == null:
			continue
		var room: Node = game.current_room
		var signals := {"defeated": 0}
		boss.boss_defeated.connect(func(): signals.defeated += 1)
		var achievements = root.get_node("AchievementManager")
		var crystals_before: int = achievements.run_stats.crystals_earned
		boss.take_damage(100000.0)
		boss._die()
		_check(signals.defeated == 1 and game._boss_defeat_handled, "real main settles boss once immediately")
		_check(achievements.run_stats.crystals_earned == crystals_before + game._floor_clear_crystals(1), "real main awards crystals once before death animation finishes")
		_check(is_instance_valid(boss) and not boss.is_queued_for_deletion() and boss.sprite.frame == 0, "real main cleanup preserves death start")
		# Cancel only the subsequent floor banner/transition; the real reward and cleanup ran above.
		game._run_token += 1
		if replace_room:
			game._create_room(1280.0, 720.0, "combat")
			await process_frame
			await process_frame
			_check(not is_instance_valid(room), "real main replacement frees original room")
			_check(not is_instance_valid(boss), "room replacement immediately frees sibling dying boss before 0.6s")
		else:
			await create_timer(0.25).timeout
			_check(is_instance_valid(boss) and boss.sprite.frame >= 2, "unchanged real room preserves visible death playback")
			await create_timer(0.45).timeout
			_check(not is_instance_valid(boss) and is_instance_valid(room), "normal death frees at 0.6s without destroying room")
		await create_timer(1.05).timeout

	# The room binding also cleans other boss controllers and their owned linked nodes.
	var other = await _spawn_main_boss(game, 2)
	game._create_room(1280.0, 720.0, "combat")
	await process_frame
	await process_frame
	_check(not is_instance_valid(other), "room replacement also cleans a living non-blood-lord boss")
	_check(get_nodes_in_group("boss").is_empty(), "no boss remains after real room replacements")
	game.queue_free()
	await process_frame
	await process_frame
	current_scene = _host
	_target.add_to_group("player")

func _finish() -> void:
	print("BLOOD_LORD_ANIMATION RESULT passed=%d failed=%d" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
