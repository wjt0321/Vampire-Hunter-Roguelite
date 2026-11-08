extends SceneTree
## 开发用：血之祭坛面板截图（验证布局与文字不溢出）
## 用法: godot --path . --script res://tools/pact_shot.gd   （必须带窗口）
##
## 为什么不用 open()：open 会 pop 树，暂停后 SceneTreeTimer 不再推进，
## 截图脚本会卡在 await 上。这里直接构面板 + 显示，测的是"排版"不是"流程"。

func _initialize() -> void:
	_run()

func _run() -> void:
	await process_frame
	var main_scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	current_scene = main_scene
	await create_timer(2.0).timeout

	var pact = main_scene.blood_pact
	pact.player = main_scene.player
	if not pact._built:
		pact._build_ui()
	pact._refresh()
	pact.visible = true

	await create_timer(0.4).timeout
	var img: Image = root.get_texture().get_image()
	img.save_png("res://pact_shot.png")
	print("祭坛截图: %s" % str(img.get_size()))
	quit()
