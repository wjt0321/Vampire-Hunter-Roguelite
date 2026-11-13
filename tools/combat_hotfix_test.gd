extends SceneTree
## 冰冻之心 / 闪电链边界 / 磁力全屏拾取
## 用法: godot --headless --path . --script res://tools/combat_hotfix_test.gd

const GC = preload("res://scripts/core/game_config.gd")

var _pass: int = 0
var _fail: int = 0
var _host: Node2D


class Probe extends CharacterBody2D:
	var freeze_chance: float = 1.0
	var bleed_chance: float = 0.0
	var slow_chance: float = 0.0
	var drain_ratio: float = 0.0
	var crit_damage: float = 2.0
	var silver: int = 0
	var xp: int = 0

	func roll_crit() -> bool:
		return false

	func on_dealt_damage(_amount: float) -> void:
		pass

	func is_dead() -> bool:
		return false

	func add_silver(amount: int) -> void:
		silver += amount

	func gain_xp(amount: int) -> void:
		xp += amount


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
	quit(0 if _fail == 0 else 1)


func _spawn_enemy(kind: String, pos: Vector2, hp: float) -> Node:
	var enemy = load("res://scenes/enemies/%s.tscn" % kind).instantiate()
	enemy.position = pos
	_host.add_child(enemy)
	enemy.max_hp = hp
	enemy.current_hp = hp
	return enemy


func _run() -> void:
	await process_frame
	GC.clear_daily()
	_host = Node2D.new()
	_host.name = "HotfixHost"
	root.add_child(_host)
	current_scene = _host
	var player := Probe.new()
	player.add_to_group("player")
	player.position = Vector2(80, 360)
	_host.add_child(player)
	await process_frame
	await process_frame

	await _test_freeze(player)
	await _test_lightning()
	await _test_magnet(player)
	_finish()


func _test_freeze(player: Probe) -> void:
	print("\n=== 冰冻之心 ===")
	var trash = _spawn_enemy("zombie", Vector2(400, 800), 5000.0)
	await process_frame
	trash.player = player
	trash.take_damage(10.0)
	_check(trash.is_frozen and trash.freeze_timer > 1.5, "普通敌人仍会被冰冻之心硬控")

	var boss = _spawn_enemy("vampire_lord", Vector2(400, 400), 8000.0)
	await process_frame
	await process_frame
	boss.player = player
	boss.intro_invulnerable = false
	boss.max_hp = 8000.0
	boss.current_hp = 8000.0
	var base_speed: float = boss.move_speed
	var origin: Vector2 = boss.global_position
	boss.take_damage(10.0)
	var chilled: float = base_speed * lerpf(1.0, GC.BOSS_FREEZE_SLOW_MULT, GC.SLOW_BOSS_RESIST)
	_check(not boss.is_frozen, "Boss 被冰冻之心命中后不进入硬控")
	_check(absf(boss.move_speed - chilled) < 0.5,
		"Boss 只被短减速到 %.1f（实际 %.1f）" % [chilled, boss.move_speed])
	_check(boss._boss_freeze_cd > GC.BOSS_FREEZE_COOLDOWN - 0.05, "Boss 冰冻进入冷却")
	var slow_left: float = boss._slow_remaining
	boss.take_damage(10.0)
	_check(is_equal_approx(boss._slow_remaining, slow_left), "冷却内再次命中不刷新减速")

	boss.set_physics_process(true)
	await create_timer(0.25).timeout
	_check(not boss.is_frozen and boss.global_position.distance_to(origin) > 4.0,
		"减速期间 Boss 仍在移动（位移 %.1f）" % boss.global_position.distance_to(origin))
	boss.queue_free()
	trash.queue_free()


func _test_lightning() -> void:
	print("\n=== 闪电链边界 ===")
	var room = Node2D.new()
	room.name = "GameRoom"
	room.set_script(load("res://scripts/map/game_room.gd"))
	room.room_width = 1280.0
	room.room_height = 768.0
	_host.add_child(room)
	await process_frame
	var bounds: Rect2 = load("res://scripts/core/room_lookup.gd").bounds_global(room)
	_check(bounds.size.x > 100.0 and bounds.size.y > 100.0, "房间内框已解析")

	var chain_pos := Vector2(bounds.position.x + 80.0, bounds.get_center().y)
	var outside = _spawn_enemy("zombie", Vector2(bounds.position.x - 20.0, chain_pos.y), 500.0)
	var inside = _spawn_enemy("zombie", chain_pos + Vector2(220.0, 0.0), 500.0)
	var far_inside = _spawn_enemy("zombie", inside.position + Vector2(260.0, 0.0), 500.0)
	outside.set_physics_process(false)
	inside.set_physics_process(false)
	far_inside.set_physics_process(false)
	await process_frame

	var chain = load("res://scenes/player/lightning_chain.tscn").instantiate()
	chain.ranges_overridden = true
	chain.acquire_range = GC.LIGHTNING_ACQUIRE_RANGE
	chain.jump_range = GC.LIGHTNING_JUMP_RANGE
	chain.max_jumps = 3
	chain.base_damage = 10.0
	chain.position = chain_pos
	_host.add_child(chain)

	var outside_dist: float = chain.global_position.distance_to(outside.global_position)
	var inside_dist: float = chain.global_position.distance_to(inside.global_position)
	_check(outside_dist < inside_dist and outside_dist < GC.LIGHTNING_ACQUIRE_RANGE,
		"墙外目标更近（%.0f < %.0f），用来证明不是‘谁近打谁’" % [outside_dist, inside_dist])
	_check(is_equal_approx(outside.current_hp, 500.0), "墙外的敌人不被闪电链打到")
	_check(inside.current_hp < 500.0, "房间内的敌人被第一跳打到")
	_check(not chain._hit_enemies.has(outside), "墙外敌人不占用跳跃次数")

	var far_dist: float = inside.global_position.distance_to(far_inside.global_position)
	_check(far_dist > GC.LIGHTNING_JUMP_RANGE, "房间另一头超出跳跃半径（%.0f）" % far_dist)
	_check(is_equal_approx(far_inside.current_hp, 500.0), "房间内但超出跳跃半径的敌人打不到")

	chain.queue_free()
	outside.queue_free()
	inside.queue_free()
	far_inside.queue_free()
	room.queue_free()
	await process_frame


func _test_magnet(player: Probe) -> void:
	print("\n=== 磁力全屏 ===")
	var cam := Camera2D.new()
	cam.position = Vector2(640, 360)
	cam.enabled = true
	_host.add_child(cam)
	cam.make_current()
	await process_frame

	var magnet := Node2D.new()
	magnet.set_script(load("res://scripts/player/powerup.gd"))
	magnet.kind = "magnet"
	magnet.position = player.position
	_host.add_child(magnet)
	magnet.set_process(false)
	magnet._player = player
	var view: Rect2 = magnet.visible_world_rect()
	player.position = view.position + Vector2(48.0, view.size.y * 0.5)
	var on_screen := Vector2(view.end.x - 8.0, player.position.y)
	var off_screen := Vector2(view.end.x + 160.0, player.position.y)
	_check(view.has_point(on_screen) and not view.has_point(off_screen),
		"测试点一个在画面内、一个在画面外")
	_check(player.position.distance_to(on_screen) > 900.0,
		"画面内目标离玩家 %.0f px，旧的 900 圆会漏掉" % player.position.distance_to(on_screen))

	var gem_scene: PackedScene = load("res://scenes/player/xp_gem.tscn")
	var gem = gem_scene.instantiate()
	gem.xp_value = 5
	gem.position = on_screen
	_host.add_child(gem)
	var missed = gem_scene.instantiate()
	missed.xp_value = 7
	missed.position = off_screen
	_host.add_child(missed)
	var coin = load("res://scenes/player/silver_coin.tscn").instantiate()
	coin.value = 3
	coin.position = on_screen + Vector2(-20.0, 24.0)
	_host.add_child(coin)
	await process_frame

	var gem_before: float = gem.global_position.distance_to(player.global_position)
	magnet._apply_magnet()
	_check(gem.is_attracted and gem.attraction_speed >= GC.MAGNET_PULL_SPEED - 0.1,
		"画面内经验宝石开始被吸（速度 %.0f）" % gem.attraction_speed)
	_check(coin._attracted and coin.attraction_speed >= GC.MAGNET_PULL_SPEED - 0.1,
		"画面内银币开始被吸")
	_check(not missed.is_attracted, "画面外的经验宝石不被吸")

	await create_timer(0.35).timeout
	var gem_after: float = gem.global_position.distance_to(player.global_position)
	_check(gem_after < gem_before - 200.0,
		"掉落弹跳没有把宝石弹回去（距离 %.0f → %.0f）" % [gem_before, gem_after])
	var coin_after: float = coin.global_position.distance_to(player.global_position)
	_check(coin_after < 900.0 and coin.is_inside_tree(),
		"银币飞向玩家（剩余 %.0f）" % coin_after)

	cam.queue_free()
	magnet.queue_free()
	if is_instance_valid(gem):
		gem.queue_free()
	if is_instance_valid(missed):
		missed.queue_free()
	if is_instance_valid(coin):
		coin.queue_free()
