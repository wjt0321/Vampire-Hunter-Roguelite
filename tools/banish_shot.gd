extends SceneTree
## 开发用：三选一界面的「普通 / 放逐」两态截图
## 用法: godot --path . --script res://tools/banish_shot.gd   （必须带窗口）
##
## 为什么必须截：放逐模式改的是卡片的色调与角标文案，
## 无头断言只能验证状态位对不对，看不到"染红之后文字还读不读得出来"。

var _ui = null

func _initialize() -> void:
	_run()

func _wait_frames(n: int) -> void:
	for i in range(n):
		await process_frame

func _shot(path: String) -> void:
	var img: Image = root.get_texture().get_image()
	img.save_png(path)
	print("截图: %s %s" % [path, str(img.get_size())])

func _run() -> void:
	await process_frame
	var main_scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	current_scene = main_scene
	await create_timer(3.6).timeout

	_ui = main_scene.upgrade_ui
	_ui.show_upgrade(main_scene.player, main_scene.weapon_manager)
	await _wait_frames(24)
	await _shot("res://ui_normal.png")

	_ui._on_banish_toggle()
	await _wait_frames(24)
	await _shot("res://ui_banish.png")

	_ui._on_banish_toggle()
	paused = false
	quit()
