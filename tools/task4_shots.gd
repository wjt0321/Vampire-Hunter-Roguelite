extends SceneTree
## Task 4 可视化验收：主菜单 / 升级 / 暂停（含设置与放弃确认）/ Boss
##
## 用法：godot --path . --script res://tools/task4_shots.gd   （必须带窗口，不能 --headless）
##
## 为什么不在 ui_interaction_test 里截图：那个脚本是 --headless 的，
## 无渲染器时 root.get_texture() 拿不到真实画面，截出来是空的。
## 断言和看图分开跑，"测试绿了但字被截断"这种问题才有人发现。

## 放 tools/evidence/iteration/：这里是本轮的验收取证目录，已在 .gitignore 里
## （`/tools/evidence/`），不会把 720p 大图塞进仓库。
const OUT_DIR := "res://tools/evidence/iteration/"
const SHOT_SIZE := Vector2i(1280, 720)

var _fail: int = 0

func _initialize() -> void:
	_run()

func _shot(name: String) -> void:
	await process_frame
	await process_frame
	var img: Image = root.get_texture().get_image()
	if img == null:
		printerr("[task4_shots] %s 取图失败" % name)
		_fail += 1
		return
	var path := OUT_DIR + "task4_" + name + ".png"
	if img.save_png(path) != OK:
		printerr("[task4_shots] %s 保存失败" % name)
		_fail += 1
		return
	print("[task4_shots] OK %-16s %s" % [name, str(img.get_size())])

func _run() -> void:
	await process_frame
	DisplayServer.window_set_size(SHOT_SIZE)
	await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))

	var cat = load("res://scripts/core/item_catalog.gd")

	# ================= 主菜单 =================
	var menu = load("res://scenes/ui/main_menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await create_timer(1.2).timeout
	await _shot("menu")
	menu.queue_free()
	await process_frame
	await create_timer(0.3).timeout

	# ================= 局内 =================
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await create_timer(2.5).timeout
	main.weapon_manager.add_weapon(cat.create_weapon("shotgun"))
	main.player.add_passive_item(cat.create_passive("shield"))
	main.player.add_passive_item(cat.create_passive("blood_edge"))
	main.player.add_silver(64)
	# 等敌人进场：截"第 N 波"横幅 + 中文化 TopBar 都比空房间有信息量
	await create_timer(8.0).timeout
	await _shot("gameplay_hud")

	# 三条横幅同时在场：验证它们不再互相覆盖（这是本次的核心改动之一）
	main.hud.update_wave(4)
	main.hud.show_evolution_banner("血刃 → 血之刃")
	main.hud.show_toast("攻击 ×1.20 → ×1.30")
	await process_frame
	await process_frame
	await _shot("banners")

	# ================= 升级三选一 =================
	main.upgrade_ui.show_upgrade(main.player, main.weapon_manager)
	await create_timer(0.9).timeout
	await _shot("upgrade")
	main.upgrade_ui.visible = false
	main.upgrade_ui._close_and_emit()
	await create_timer(0.4).timeout

	# ================= 暂停菜单 + 设置 + 放弃确认 =================
	var pause_menu = main.get_node("PauseMenu")
	pause_menu._pause()
	await create_timer(0.5).timeout
	await _shot("pause")

	pause_menu._on_settings_pressed()
	await create_timer(0.5).timeout
	await _shot("pause_settings")
	pause_menu._on_settings_back_pressed()
	await create_timer(0.3).timeout

	pause_menu._on_abandon_pressed()
	await create_timer(0.4).timeout
	await _shot("pause_abandon_confirm")
	pause_menu._disarm_abandon()
	pause_menu._resume()
	await create_timer(0.4).timeout

	# ================= Boss =================
	main._enter_boss_room()
	await create_timer(3.4).timeout
	await _shot("boss")

	print("[task4_shots] DONE fail=%d" % _fail)
	quit(1 if _fail > 0 else 0)
