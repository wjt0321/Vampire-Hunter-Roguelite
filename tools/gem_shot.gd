extends SceneTree
## 开发用：经验宝石外观截图（分档颜色 / 尺寸 / 合并效果）
## 用法: godot --path . --script res://tools/gem_shot.gd   （必须带窗口，不能 --headless）

func _initialize() -> void:
	_run()

func _spawn_gem(pos: Vector2, value: int) -> void:
	var scene = load("res://scenes/player/xp_gem.tscn")
	var gem = scene.instantiate()
	gem.position = pos
	gem.xp_value = value
	current_scene.add_child(gem)
	# 冻结吸附，否则 88px 内会被玩家吸走，截不到图
	gem.set_physics_process(false)

func _count_gems() -> int:
	return get_nodes_in_group("xp_gems").size()

func _run() -> void:
	await process_frame
	var main_scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	current_scene = main_scene
	await create_timer(2.0).timeout

	# 相机跟玩家，所以必须按玩家世界坐标摆，否则不在视野里
	var p: Vector2 = main_scene.player.global_position
	# 三档各一枚，横向摆开
	_spawn_gem(p + Vector2(-120, -90), 3)    # 蝙蝠/吸血鬼 → 绿 12px
	_spawn_gem(p + Vector2(-60, -90), 12)    # 僵尸/爆炸鬼 → 蓝 17px
	_spawn_gem(p + Vector2(20, -90), 25)     # 精英/法师 → 金 24px

	# 合并测试：12 枚小宝石挤在 24px 范围内
	var before := _count_gems()
	for i in range(12):
		var a := TAU * float(i) / 12.0
		_spawn_gem(p + Vector2(-60, 40) + Vector2(cos(a), sin(a)) * 18.0, 3)
	await create_timer(0.4).timeout
	var after := _count_gems()
	print("合并: 生成 12 枚后同屏 %d 枚（合并前 %d）" % [after, before + 12])

	var img: Image = root.get_texture().get_image()
	img.save_png("res://gem_shot.png")
	print("玩家屏幕位置 %s" % str(main_scene.player.get_global_transform_with_canvas().origin))
	print("宝石截图: %s" % str(img.get_size()))
	quit()
