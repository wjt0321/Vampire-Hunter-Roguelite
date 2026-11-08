extends SceneTree
## 开发用：三种战斗增益的外观截图（颜色 / emoji / 呼吸脉动幅度）
## 用法: godot --path . --script res://tools/powerup_shot.gd   （必须带窗口）

func _initialize() -> void:
	_run()

func _spawn(kind: String, pos: Vector2) -> void:
	var node := Node2D.new()
	node.set_script(load("res://scripts/player/powerup.gd"))
	node.kind = kind
	node.lifetime = 999.0
	current_scene.add_child(node)
	node.global_position = pos

func _run() -> void:
	await process_frame
	var main_scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	current_scene = main_scene
	await create_timer(2.0).timeout

	var p: Vector2 = main_scene.player.global_position
	_spawn("heal", p + Vector2(-150, -70))
	_spawn("frenzy", p + Vector2(0, -70))
	_spawn("magnet", p + Vector2(150, -70))
	await create_timer(1.0).timeout

	var img: Image = root.get_texture().get_image()
	img.save_png("res://powerup_shot.png")
	print("增益截图: %s" % str(img.get_size()))
	quit()
