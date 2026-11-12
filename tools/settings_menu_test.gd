extends SceneTree

var _fail: int = 0

func _initialize() -> void:
	_run()

func _check(ok: bool, label: String) -> void:
	if ok:
		print("✅ %s" % label)
	else:
		_fail += 1
		print("❌ %s" % label)

func _run() -> void:
	await process_frame
	var save = root.get_node("SaveManager")
	_check(save.is_tool_run and save.save_path == "user://test_settings_menu_test.json", "设置测试使用隔离档")
	if not save.is_tool_run or not save.save_path.begins_with("user://test_"):
		quit(1)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var menu: Variant = load("res://scenes/ui/main_menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await process_frame
	await process_frame
	menu._on_settings_pressed()
	await create_timer(0.3).timeout

	var panel: PanelContainer = menu.settings_panel
	var style := panel.get_theme_stylebox("panel") as StyleBoxTexture
	_check(style != null, "设置面板使用九宫格纹理")
	if style != null:
		_check(style.content_margin_left >= 40.0 and style.content_margin_right >= 40.0,
			"左右内容边距至少 40px（实际 %.1f / %.1f）" % [style.content_margin_left, style.content_margin_right])
		_check(style.content_margin_top >= 48.0 and style.content_margin_bottom >= 28.0,
			"上下内容边距避开装饰（实际 %.1f / %.1f）" % [style.content_margin_top, style.content_margin_bottom])
	for node_name in ["MusicLabel", "SFXLabel", "FullscreenCheck"]:
		var control := panel.get_node("VBoxContainer/" + node_name) as Control
		_check(control.global_position.x >= panel.global_position.x + 40.0,
			"%s 不越过左侧边框（x=%.1f，面板 x=%.1f）" % [node_name, control.global_position.x, panel.global_position.x])

	var has_window: bool = DisplayServer.get_name() != "headless"
	if has_window:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		await process_frame
		menu._on_settings_pressed()
		_check(menu.fullscreen_check.button_pressed,
			"外部进入全屏后，打开设置会同步勾选状态")
		menu._on_fullscreen_toggled(false)
		await process_frame
		_check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED,
			"关闭全屏后恢复窗口模式")
		DisplayServer.window_set_size(Vector2i(1280, 720))
		await create_timer(0.3).timeout
		await process_frame

		var img := root.get_texture().get_image()
		var out := "res://tools/evidence/iteration/settings_menu.png"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out.get_base_dir()))
		_check(img != null and img.save_png(out) == OK, "保存设置面板验收截图")
	else:
		print("ℹ️ headless：跳过窗口模式与截图检查")

	var pause_menu: Variant = load("res://scenes/ui/pause_menu.tscn").instantiate()
	root.add_child(pause_menu)
	await process_frame
	pause_menu._pause()
	pause_menu._on_settings_pressed()
	await create_timer(0.25).timeout
	var pause_style: Variant = pause_menu.settings_panel.get_theme_stylebox("panel")
	_check(pause_style is StyleBoxTexture and pause_style.texture != null,
		"局内设置使用与主菜单一致的正式边框")
	_check(pause_style is StyleBoxTexture and pause_style.content_margin_left >= 40.0,
		"局内设置为文字保留边框内容边距")
	await process_frame
	if has_window:
		var pause_img := root.get_texture().get_image()
		var pause_out := "res://tools/evidence/iteration/pause_settings_menu.png"
		_check(pause_img != null and pause_img.save_png(pause_out) == OK,
			"保存局内设置验收截图")
	# Real paused settings slider must survive a music transition.
	var audio = root.get_node("AudioManager")
	var lib = root.get_node("AudioLib")
	audio.set_music_volume(0.8, false)
	audio.play_bgm(lib.get_battle_bgm(), false)
	audio.play_bgm(lib.get_shop_bgm())
	await create_timer(0.2).timeout
	pause_menu.music_slider.value = 0.2
	await create_timer(1.1).timeout
	_check(is_equal_approx(audio.get_music_volume(), 0.2) and is_equal_approx(audio._bgm_player.volume_db, -13.9794),
		"暂停设置滑块在切曲完成后仍保持新音量")
	_check(is_equal_approx(save.save_data.audio_settings.music_volume, 0.2), "音量设置写入隔离档")
	pause_menu._resume()
	audio.play_bgm(lib.get_menu_bgm())
	await create_timer(0.2).timeout
	menu.music_slider.value = 0.0
	var max_db := -1000.0
	var deadline := Time.get_ticks_msec() + 1200
	while Time.get_ticks_msec() < deadline:
		await process_frame
		max_db = maxf(max_db, audio._bgm_player.volume_db)
	_check(max_db <= -80.0, "主菜单滑块静音后整个过渡保持静音")
	pause_menu.queue_free()
	menu.queue_free()
	await process_frame
	await process_frame
	print("设置菜单回归：失败 %d 项" % _fail)
	quit(0 if _fail == 0 else 1)
