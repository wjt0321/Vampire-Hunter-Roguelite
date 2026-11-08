extends SceneTree
## 开发用：四种精英词缀的外观截图（光环颜色 / 头顶图标 / 体型）
## 用法: godot --path . --script res://tools/affix_shot.gd   （必须带窗口）

func _initialize() -> void:
	_run()

func _spawn(type: String, affix: String, pos: Vector2) -> Node:
	var scene: PackedScene = load("res://scenes/enemies/%s.tscn" % type)
	var e = scene.instantiate()
	e.spawn_wave = 1
	e.floor_index = 1
	e.elite_affix = affix
	e.position = pos
	current_scene.add_child(e)
	# 冻结，避免它们冲向玩家把构图打散
	e.set_physics_process(false)
	return e

func _run() -> void:
	await process_frame
	var main_scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	current_scene = main_scene
	await create_timer(1.6).timeout

	var p: Vector2 = main_scene.player.global_position
	_spawn("vampire", "shielded", p + Vector2(-180, -80))
	_spawn("skeleton_archer", "charger", p + Vector2(-60, -80))
	_spawn("zombie", "splitter", p + Vector2(60, -80))
	_spawn("werewolf", "haster", p + Vector2(180, -80))
	await create_timer(0.6).timeout

	var img: Image = root.get_texture().get_image()
	img.save_png("res://affix_shot.png")
	print("词缀截图: %s" % str(img.get_size()))
	quit()
