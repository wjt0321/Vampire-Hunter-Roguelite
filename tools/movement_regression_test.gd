extends SceneTree

var _fail: int = 0
var _pass: int = 0

func _initialize() -> void:
	_run()

func _check(ok: bool, label: String) -> void:
	if ok:
		_pass += 1
		print("✅ %s" % label)
	else:
		_fail += 1
		print("❌ %s" % label)

func _run() -> void:
	await process_frame
	var player : Variant = load("res://scenes/player/player.tscn").instantiate()
	player.position = Vector2(500, 300)
	root.add_child(player)
	player.set_physics_process(false)
	var wolf : Variant = load("res://scenes/enemies/werewolf.tscn").instantiate()
	wolf.position = Vector2(300, 300)
	root.add_child(wolf)
	await process_frame
	wolf.charge_timer = wolf.charge_interval
	wolf._physics_process(0.016)
	await create_timer(0.08).timeout
	_check(wolf.is_charging, "狼人进入冲刺")
	var locked: Vector2 = wolf.velocity.normalized()
	player.position += Vector2(0, 180)
	await create_timer(0.08).timeout
	_check(wolf.velocity.normalized().dot(locked) > 0.99,
		"冲刺方向在起步后锁定，玩家横向移动可躲")
	wolf.charge_elapsed = wolf.charge_duration
	wolf._physics_process(0.016)
	wolf._physics_process(0.016)
	_check(not wolf.is_charging, "冲刺到时后结束")
	_check(wolf.charge_timer < wolf.charge_interval and not wolf.is_charging,
		"结束后重新计时，不会下一帧立即再冲刺")
	_check(wolf.velocity.length() <= wolf.move_speed + 1.0,
		"收招后恢复普通移速（实际 %.1f）" % wolf.velocity.length())
	wolf.queue_free()
	await process_frame

	var zombie : Variant = load("res://scenes/enemies/zombie.tscn").instantiate()
	zombie.position = Vector2(400, 300)
	root.add_child(zombie)
	await process_frame
	zombie._start_lunge()
	var zombie_dir: Vector2 = zombie.lunge_direction
	player.position += Vector2(-180, 0)
	await create_timer(0.08).timeout
	_check(zombie.lunge_direction.dot(zombie_dir) > 0.99,
		"僵尸扑击方向也保持固定")
	await create_timer(0.45).timeout
	_check(not zombie.is_lunging and zombie.velocity.length() <= zombie.move_speed + 1.0,
		"僵尸扑击后能收招并恢复普通移速")
	zombie.queue_free()
	player.queue_free()
	await process_frame
	print("通过 %d / 失败 %d" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
