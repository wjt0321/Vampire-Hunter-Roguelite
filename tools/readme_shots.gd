extends SceneTree
## 开发用：一次性生成 README 展示图（docs/screenshots/*.png）
##
## 用法：godot --path . --script res://tools/readme_shots.gd   （必须带窗口，不能 --headless）
##
## 为什么单独写一个而不是手动截图：README 的图要反复更新，手动截六张
## 再对齐分辨率、再裁掉窗口边框，每次改美术都得重来一遍。
## 这里把「固定窗口尺寸 + 固定机位 + 固定内容」写成脚本，一条命令重录全套。
##
## 覆盖：主菜单 / 角色选择 / 元进度商店 / 局内战斗 / 升级三选一 / Boss 战

const OUT_DIR := "res://docs/screenshots/"
const SHOT_SIZE := Vector2i(1280, 720)

var _fail: int = 0

func _initialize() -> void:
	_run()

func _shot(name: String) -> void:
	# 等两帧：一帧让布局重算，一帧让新加的子节点真正画进 viewport
	await process_frame
	await process_frame
	var img: Image = root.get_texture().get_image()
	if img == null:
		printerr("[readme_shots] %s 取图失败" % name)
		_fail += 1
		return
	var path := OUT_DIR + name + ".png"
	var err := img.save_png(path)
	if err != OK:
		printerr("[readme_shots] %s 保存失败 err=%d" % [name, err])
		_fail += 1
		return
	print("[readme_shots] OK %-12s %s" % [name, str(img.get_size())])

func _run() -> void:
	await process_frame
	DisplayServer.window_set_size(SHOT_SIZE)
	await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))

	var cat = load("res://scripts/core/item_catalog.gd")

	# ================= 主菜单 / 选角 / 商店 =================
	var menu = load("res://scenes/ui/main_menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await create_timer(1.2).timeout
	await _shot("menu")

	menu.character_select.show_selection()
	await create_timer(0.9).timeout
	await _shot("characters")
	menu.character_select.visible = false
	await create_timer(0.3).timeout

	menu.upgrade_shop.show_shop()
	await create_timer(0.6).timeout
	var shop_scroll: ScrollContainer = menu.upgrade_shop.get_node("Panel/VBoxContainer/ScrollContainer")
	shop_scroll.scroll_vertical = 10000
	await create_timer(0.4).timeout
	await _shot("shop")
	menu.upgrade_shop.visible = false

	menu.queue_free()
	await process_frame
	await create_timer(0.3).timeout

	# ================= 局内 =================
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await create_timer(2.5).timeout

	# 造一点内容：两把武器 + 一个被动 + 一点银币，让 HUD 不是空的
	# （截图要展示「一局正在进行中」，而不是刚出生什么都没拿）
	main.weapon_manager.add_weapon(cat.create_weapon("shotgun"))
	main.weapon_manager.add_weapon(cat.create_weapon("magic_book"))
	main.player.add_passive_item(cat.create_passive("shield"))
	main.player.add_silver(64)

	# 等敌人从屏幕外走进来、武器自动开火。太短会在空房间里截，太长玩家会被打死
	await create_timer(9.5).timeout
	await _shot("gameplay")

	# ================= 升级三选一 =================
	main.upgrade_ui.show_upgrade(main.player, main.weapon_manager)
	await create_timer(0.8).timeout
	await _shot("upgrade")
	main.upgrade_ui.visible = false
	paused = false

	# ================= Boss =================
	# 直接进 Boss 房：正常要打穿 6 间房才能到，截图不需要走流程
	main._enter_boss_room()
	await create_timer(3.2).timeout
	await _shot("boss")

	print("[readme_shots] DONE fail=%d" % _fail)
	quit(1 if _fail > 0 else 0)
