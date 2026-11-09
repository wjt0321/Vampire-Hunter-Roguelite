extends SceneTree
## 三问题联合诊断（无头）：
##   1) 逐个物品解析图标贴图，列出"只有字没有图"的真实名单
##   2) 阶段地图（楼层）房间内掉落的地面道具是否有贴图
##   3) 刷怪落点是否越出房间边界
##
## 用法: godot --headless --path . --script res://tools/trio_diag.gd

var _fail: int = 0

func _initialize() -> void:
	_run()

func _finish() -> void:
	print("")
	if _fail == 0:
		print("✅ 全部通过")
	else:
		print("❌ 失败 %d 项" % _fail)
	quit(0 if _fail == 0 else 1)

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ✅ %s" % msg)
	else:
		print("  ❌ %s" % msg)
		_fail += 1


func _run() -> void:
	await process_frame
	print("")
	print("====== 三问题联合诊断 ======")

	var cat = load("res://scripts/core/item_catalog.gd")
	var tm = load("res://scripts/managers/texture_manager.gd")

	# ============ 问题 1：图标解析 ============
	print("")
	print("--- 问题1: 物品图标解析 ---")
	var groups: Array = [
		["WEAPON", cat.WEAPONS], ["PASSIVE", cat.PASSIVES],
		["STAT", cat.STATS], ["CONSUMABLE", cat.CONSUMABLES],
	]
	var missing: Array = []
	for g in groups:
		var gname: String = g[0]
		for item in g[1]:
			var iid: String = String(item.get("id", ""))
			var itype: String = String(item.get("type", ""))
			var tex: Texture2D = cat.get_icon_texture(iid, itype)
			if tex == null:
				missing.append("%s:%s" % [gname, iid])
				print("  ❌ %-12s %-18s -> 无贴图" % [gname, iid])
			else:
				var sz: Vector2 = tex.get_size()
				print("  ✅ %-12s %-18s -> %dx%d" % [gname, iid, int(sz.x), int(sz.y)])
	print("")
	if missing.is_empty():
		print("  结论: ItemCatalog 映射全部命中")
	else:
		print("  结论: 缺贴图 %d 项 -> %s" % [missing.size(), ", ".join(missing)])

	# 顺带查 TextureManager 里登记但文件不存在的（加载时静默 push_warning）
	print("")
	print("--- 问题1b: TextureManager 图标登记完整性 ---")
	var tm_inst = tm.new()
	root.add_child(tm_inst)
	await process_frame
	var wi: Dictionary = tm_inst.weapon_icons
	var bad_reg: Array = []
	for k in wi.keys():
		if wi[k] == null:
			bad_reg.append(k)
	print("  登记 %d 项, 贴图为 null 的 %d 项" % [wi.size(), bad_reg.size()])
	for k in bad_reg:
		print("    · %s" % k)
	tm_inst.queue_free()

	# ============ 问题 3：刷怪落点越界 ============
	print("")
	print("--- 问题3: 刷怪落点边界 ---")
	var main_scene = load("res://scenes/main.tscn").instantiate()
	main_scene.debug_force_character = "hunter"
	root.add_child(main_scene)
	current_scene = main_scene
	await create_timer(3.0).timeout

	var player = main_scene.player
	var wm = main_scene.wave_manager
	var room = main_scene.current_room
	if room == null:
		print("  ⚠ 没有当前房间，跳过")
	else:
		print("  房间尺寸 = %s" % str(room.get_room_size()))
		print("  房间节点 global_position = %s" % str(room.global_position))
		print("  玩家 parent = %s（是否就是房间？）" % player.get_parent().name)
		print("  玩家 parent 有 get_room_bounds? %s" % player.get_parent().has_method("get_room_bounds"))

		# 直接调用 _get_spawn_position 若干次，检查是否越界
		var outside: int = 0
		var samples: int = 200
		for i in samples:
			var pos: Vector2 = wm._get_spawn_position()
			var b: Rect2 = room.get_room_bounds()
			if room is Node2D:
				b = Rect2((room as Node2D).to_global(b.position), b.size)
			if not b.has_point(pos):
				outside += 1
		print("  采样 %d 次，越界 %d 次" % [samples, outside])
		if outside == 0:
			print("  ✅ 刷怪落点全部在房间内")
		else:
			print("  ❌ 刷怪落点越界 %d/%d 次" % [outside, samples])

		# 房间实际尺寸 vs 模板
		print("  room_width=%s room_height=%s wall=%s" % [
			str(room.room_width), str(room.room_height), str(room.wall_thickness)])
		print("  屏幕 1280x720，房间对角线 %s" % str(room.get_room_size()))

	# ============ 问题 2：地面掉落物有没有贴图 ============
	print("")
	print("--- 问题2: 地面掉落物贴图 ---")
	var gem_scene = load("res://scenes/player/xp_gem.tscn")
	var coin_scene = load("res://scenes/player/silver_coin.tscn")
	var gem = gem_scene.instantiate()
	var spr = gem.get_node_or_null("Sprite2D")
	if spr == null:
		print("  ❌ xp_gem 场景没有 Sprite2D")
	else:
		print("  xp_gem Sprite2D.texture = %s（运行时由 style_gem 程序化生成）" % str(spr.texture))
	var coin = coin_scene.instantiate()
	print("  silver_coin 场景子节点: %s" % str(coin.get_children()))
	var pw_script = load("res://scripts/player/powerup.gd")
	print("  powerup 用的图标 = 中文字（%s）" % "血/狂/磁")
	print("  受诅宝箱 = ColorRect 纯色块 + 中文字「锁」")
