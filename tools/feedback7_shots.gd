extends SceneTree
## 本轮 7 条实机反馈的验收取证（问题1 毒雾 / 问题2 ESC 菜单 / 问题3 图鉴 /
## 问题4 骷髅射手 / 问题5 错误贴图 / 问题6 动态帧 / 问题7 楼层 BGM）
##
## 用法：godot --path . --script res://tools/feedback7_shots.gd   （必须带窗口，不能 --headless）
## 截图落在 tools/evidence/feedback7/（已 gitignore），不往仓库塞大图。

const OUT_DIR := "res://tools/evidence/feedback7/"
const SHOT_SIZE := Vector2i(1280, 720)

var _fail: int = 0

func _initialize() -> void:
	_run()

func _shot(name: String) -> void:
	await process_frame
	await process_frame
	var img: Image = root.get_texture().get_image()
	if img == null:
		printerr("[feedback7] %s 取图失败" % name)
		_fail += 1
		return
	var path := OUT_DIR + name + ".png"
	if img.save_png(path) != OK:
		printerr("[feedback7] %s 保存失败" % name)
		_fail += 1
		return
	print("[feedback7] OK %-18s %s" % [name, str(img.get_size())])

func _run() -> void:
	await process_frame
	DisplayServer.window_set_size(SHOT_SIZE)
	await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))

	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await create_timer(3.0).timeout

	# ---------- 问题5：房间事件地面标记（原来是硬边实心蓝圆盘） ----------
	if main.room_events != null:
		main.room_events._start_seals()
	await create_timer(0.9).timeout
	await _shot("seal_marker")

	# ---------- 问题1：毒雾瓶（换房清场 + 提亮 + 正式贴图） ----------
	var cloud = load("res://scenes/player/poison_cloud.tscn").instantiate()
	cloud.global_position = main.player.global_position + Vector2(150, 30)
	main.add_child(cloud)
	await create_timer(1.0).timeout
	await _shot("poison_cloud")

	# ---------- 问题2/3：ESC 菜单 + 图鉴 + 返回 ----------
	var pause_menu = main.get_node("PauseMenu")
	pause_menu._pause()
	await create_timer(0.6).timeout
	await _shot("pause_menu")
	pause_menu._show_codex()
	await create_timer(0.7).timeout
	await _shot("codex")
	pause_menu._on_codex_back_pressed()
	await create_timer(0.5).timeout
	await _shot("codex_back_to_menu")
	pause_menu._resume()
	await create_timer(0.3).timeout

	# ---------- 问题7：每层一首 BGM + Boss 专属曲 ----------
	var audio_lib = root.get_node_or_null("AudioLib")
	var audio_mgr = root.get_node_or_null("AudioManager")
	if audio_lib != null:
		var seen: Array[String] = []
		for f in range(1, 6):
			var s = audio_lib.get_floor_bgm(f)
			var rp := "" if s == null else str(s.resource_path)
			seen.append(rp)
			print("[feedback7] floor %d -> %s" % [f, rp])
		var uniq: Dictionary = {}
		for rp in seen:
			uniq[rp] = true
		if uniq.size() != 5:
			printerr("[feedback7] 楼层 BGM 不是 5 首互不相同：%s" % str(uniq.keys()))
			_fail += 1
	if audio_mgr != null:
		main._enter_boss_room()
		await create_timer(2.2).timeout
		var p = audio_mgr.get("_bgm_player")
		var cur := "" if p == null else str(p.stream.resource_path if p.stream != null else "")
		print("[feedback7] boss BGM -> %s" % cur)
		if not cur.ends_with("boss.ogg"):
			printerr("[feedback7] Boss 战不是专属 BGM：%s" % cur)
			_fail += 1
		await _shot("boss")

	print("[feedback7] DONE fail=%d" % _fail)
	quit(1 if _fail > 0 else 0)
