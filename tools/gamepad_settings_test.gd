extends SceneTree
## 阶段 2 产品件回归：手柄走位/瞄准/焦点开关/升级热键、主音量与震屏开关持久化、
## 首局引导只触发一次、成就通知不再压顶部血条。

var _pass := 0
var _fail := 0

func _check(ok: bool, label: String) -> void:
	if ok:
		_pass += 1
		print("✅ %s" % label)
	else:
		_fail += 1
		print("❌ %s" % label)

func _wait(test: Callable, seconds: float) -> bool:
	var elapsed := 0.0
	while elapsed < seconds:
		if test.call():
			return true
		await create_timer(0.05, true).timeout
		elapsed += 0.05
	return bool(test.call())

func _pad_motion(axis: int, value: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value
	Input.parse_input_event(ev)

func _pad_button(index: int) -> void:
	var ev := InputEventJoypadButton.new()
	ev.button_index = index
	ev.pressed = true
	Input.parse_input_event(ev)
	await process_frame
	ev = InputEventJoypadButton.new()
	ev.button_index = index
	ev.pressed = false
	Input.parse_input_event(ev)

func _initialize() -> void:
	_run()

func _run() -> void:
	await process_frame
	var save: Node = root.get_node("SaveManager")
	save.use_test_save_path("gamepad_settings_test")
	var game: Node = load("res://scenes/main.tscn").instantiate()
	game.debug_force_character = "hunter"
	root.add_child(game)
	current_scene = game
	_check(await _wait(func(): return game.wave_manager.is_active, 15.0), "局正常开起来")
	game.wave_manager.stop()
	for e in get_nodes_in_group("enemies"):
		e.queue_free()
	await process_frame
	var player: Node = game.player

	# --- 手柄走位 ---
	var x0: float = player.global_position.x
	_pad_motion(0, 1.0)
	for i in 20:
		await process_frame
	_pad_motion(0, 0.0)
	_check(player.global_position.x > x0 + 10.0, "左摇杆右推玩家真的右移（%.1f → %.1f）" % [x0, player.global_position.x])

	# --- 右摇杆瞄准接管与回退 ---
	_pad_motion(2, 1.0)
	await process_frame
	var aim: Vector2 = player.aim_direction_from(player.global_position)
	_check(aim.distance_to(Vector2.RIGHT) < 0.01, "右摇杆右推瞄准向右（%s）" % str(aim))
	_pad_motion(2, 0.0)
	await process_frame
	var mouse_aim: Vector2 = player.aim_direction_from(player.global_position)
	_check(mouse_aim.distance_to(Vector2.RIGHT) > 0.01, "松开摇杆回退鼠标方向")

	# --- 焦点开关 ---
	game.upgrade_ui.show_upgrade(player, game.weapon_manager)
	await process_frame
	_pad_motion(0, 0.6)
	await process_frame
	_pad_motion(0, 0.0)
	await process_frame
	var any_focusable := false
	for b in game.upgrade_ui.find_children("", "Button", true):
		if b.focus_mode == Control.FOCUS_ALL:
			any_focusable = true
	_check(any_focusable or root.gui_get_focus_owner() != null, "手柄活动后按钮开焦点")
	var key := InputEventKey.new()
	key.keycode = KEY_W
	key.pressed = true
	Input.parse_input_event(key)
	await process_frame
	var all_none := true
	for b in game.upgrade_ui.find_children("", "Button", true):
		if b.focus_mode != Control.FOCUS_NONE:
			all_none = false
	_check(all_none, "键鼠活动立即恢复 FOCUS_NONE（Space 铁律保住）")

	# --- 升级界面手柄热键 ---
	var silver_before: int = player.silver
	await _pad_button(JOY_BUTTON_B)
	_check(await _wait(func(): return not game.upgrade_ui.visible, 2.0) and player.silver == silver_before + GameConfig.SKIP_SILVER_REWARD,
		"手柄 B 跳过升级换银币")
	game.upgrade_ui.show_upgrade(player, game.weapon_manager)
	await process_frame
	await _pad_button(JOY_BUTTON_X)
	_check(game.upgrade_ui.visible, "手柄 X 重抽后界面仍在（选项已换）")
	game.upgrade_ui._on_skip()
	_check(await _wait(func(): return not game.upgrade_ui.visible, 2.0), "跳过关闭并解除暂停")

	# --- 主音量与震屏开关 ---
	root.get_node("AudioManager").set_master_volume(0.5)
	var db: float = AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master"))
	_check(absf(db - (-6.0206)) < 0.05, "主音量 0.5 落到 Master 总线约 -6dB（%.2f）" % db)
	_check(absf(float(save.save_data["audio_settings"]["master_volume"]) - 0.5) < 0.001, "主音量持久化进存档")
	save.save_data["settings"]["screen_shake"] = false
	var cam: Camera2D = get_first_node_in_group("camera") as Camera2D
	if cam != null:
		cam.offset = Vector2.ZERO
		var vfx: Node = root.get_node("VFXManager")
		vfx.screen_shake(8.0, 0.2)
		await process_frame
		await process_frame
		_check(cam.offset == Vector2.ZERO, "震屏关时 screen_shake 不动相机")
		save.save_data["settings"]["screen_shake"] = true
		vfx.screen_shake(8.0, 0.2)
		await process_frame
		await process_frame
		_check(cam.offset != Vector2.ZERO, "震屏开时相机真的震")
		cam.offset = Vector2.ZERO

	# --- 首局引导 ---
	var ob: Node = game.onboarding
	_check(ob != null, "主场景挂了 onboarding")
	save.save_data["onboarding_done"] = false
	ob.setup(save)
	ob.hint("gems", "测试提示一")
	var toast_text: String = game.hud._toast_banner.text
	_check(toast_text == "测试提示一", "首局提示走 HUD 飘字")
	ob.hint("gems", "测试提示二")
	_check(game.hud._toast_banner.text == "测试提示一", "同一卡点不重复飘")
	ob.finish(save)
	_check(bool(save.save_data["onboarding_done"]), "结算落 onboarding_done 标记")
	ob.hint("portal", "不该出现")
	_check(game.hud._toast_banner.text == "测试提示一", "标记后不再飘新手提示")

	# --- 成就通知位置 ---
	var notif: Node = load("res://scenes/ui/achievement_notification.tscn").instantiate()
	root.add_child(notif)
	await process_frame
	_check(notif.panel.position.y > 500.0, "成就通知落在屏幕下方（y=%.0f），不压顶部血条" % notif.panel.position.y)
	notif.queue_free()

	print("\nRESULT gamepad_settings pass=%d fail=%d" % [_pass, _fail])
	game.queue_free()
	await process_frame
	quit(1 if _fail else 0)