extends SceneTree
## 开发用：跑一局并截图，检查 HUD 布局（护盾条 / 武器等级面板 / 升级卡片角标）
## 用法: godot --path . --script res://tools/hud_shot.gd   （必须带窗口，不能 --headless）

func _initialize() -> void:
	_run()

func _run() -> void:
	await process_frame
	var cat = load("res://scripts/core/item_catalog.gd")
	var main_scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	current_scene = main_scene
	await create_timer(3.0).timeout

	# 造一点内容：护盾 + 第二把武器 + 一个被动
	main_scene.player.add_passive_item(cat.create_passive("shield"))
	main_scene.player.add_passive_item(cat.create_passive("magnet"))
	main_scene.weapon_manager.add_weapon(cat.create_weapon("shotgun"))
	main_scene.weapon_manager.add_weapon(cat.create_weapon("shotgun"))
	main_scene.player.add_silver(64)
	await create_timer(1.2).timeout

	var img: Image = root.get_texture().get_image()
	img.save_png("res://hud_shot_hud.png")
	print("HUD 截图: %s" % str(img.get_size()))

	# 升级界面：给足等级，让卡片出现"Lv.N → Lv.N+1"
	main_scene.upgrade_ui.show_upgrade(main_scene.player, main_scene.weapon_manager)
	await create_timer(0.8).timeout
	var img2: Image = root.get_texture().get_image()
	img2.save_png("res://hud_shot_upgrade.png")
	print("升级界面截图: %s" % str(img2.get_size()))
	quit()
