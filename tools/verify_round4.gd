extends SceneTree
## 第四轮补缺的无头验证：
##   1) 25 个成就徽章 / 2 个角色被动图标 / 8 个战场掉落物贴图是否都真实存在
##   2) ItemCatalog 里每件物品的图标贴图尺寸是否合规（不能是 1024 原图）
##   3) 成就数据里是否还残留共用字符图标（"★"）
##   4) 刷怪落点 / 增益落点是否 100% 落在房间内
##
## 用法: godot --headless --path . --script res://tools/verify_round4.gd

var _fail: int = 0
var _warn: int = 0

func _initialize() -> void:
	_run()

func _finish() -> void:
	print("")
	if _fail == 0:
		print("✅ 全部通过（%d 项警告）" % _warn)
	else:
		print("❌ 失败 %d 项（%d 项警告）" % [_fail, _warn])
	quit(0 if _fail == 0 else 1)

func _ok(cond: bool, msg: String) -> void:
	if cond:
		print("  ✅ %s" % msg)
	else:
		print("  ❌ %s" % msg)
		_fail += 1

func _warn_msg(cond: bool, msg: String) -> void:
	if not cond:
		print("  ⚠️  %s" % msg)
		_warn += 1


func _run() -> void:
	await process_frame
	print("")
	print("====== 第四轮补缺验证 ======")

	var tm = load("res://scripts/managers/texture_manager.gd")
	var tm_inst = tm.new()
	root.add_child(tm_inst)
	await process_frame

	# ---------- 1a. 成就徽章 ----------
	print("")
	print("--- 成就徽章（25 张专属）---")
	var ach_ids: Array = tm_inst.ACHIEVEMENT_IDS
	_ok(ach_ids.size() == 25, "成就条目数 = %d（期望 25）" % ach_ids.size())
	var ach_missing: Array = []
	var ach_badsize: Array = []
	for ach_id in ach_ids:
		var tex: Texture2D = tm_inst.get_achievement_icon(String(ach_id))
		if tex == null:
			ach_missing.append(ach_id)
			continue
		var sz := tex.get_size()
		if int(sz.x) != 48 or int(sz.y) != 48:
			ach_badsize.append("%s=%dx%d" % [ach_id, int(sz.x), int(sz.y)])
	_ok(ach_missing.is_empty(),
		"25 个成就徽章全部有贴图" if ach_missing.is_empty()
		else "缺贴图 %d 个: %s" % [ach_missing.size(), ", ".join(ach_missing)])
	_ok(ach_badsize.is_empty(),
		"徽章尺寸全部 48x48" if ach_badsize.is_empty()
		else "尺寸不对: %s" % ", ".join(ach_badsize))

	# ---------- 1b. 角色被动图标 ----------
	print("")
	print("--- 角色被动图标 ---")
	for key in ["hunter_instinct", "holy_ward"]:
		var tex: Texture2D = tm_inst.get_passive_icon(String(key))
		_ok(tex != null, "passive %s 有贴图" % key)
		if tex != null:
			var sz := tex.get_size()
			_ok(int(sz.x) == 48 and int(sz.y) == 48,
				"passive %s = %dx%d" % [key, int(sz.x), int(sz.y)])

	# ---------- 1c. 战场掉落物贴图 ----------
	print("")
	print("--- 战场地面掉落物贴图 ---")
	for key in ["silver_coin", "xp_gem_green", "xp_gem_blue", "xp_gem_gold",
			"powerup_heal", "powerup_frenzy", "powerup_magnet", "cursed_chest",
			"heal_potion_icon", "blood_crystal_icon"]:
		var tex: Texture2D = tm_inst.get_item_texture(String(key))
		_ok(tex != null, "items/%s 有贴图" % key)
		if tex != null:
			var sz := tex.get_size()
			print("      %s = %dx%d" % [key, int(sz.x), int(sz.y)])

	# ---------- 2. ItemCatalog 尺寸合规 ----------
	print("")
	print("--- ItemCatalog 图标尺寸 ---")
	var cat = load("res://scripts/core/item_catalog.gd")
	var groups: Array = [
		["weapon", cat.WEAPONS], ["passive", cat.PASSIVES],
		["stat", cat.STATS], ["consumable", cat.CONSUMABLES],
	]
	var oversize: Array = []
	var nulls: Array = []
	for g in groups:
		for item in g[1]:
			var iid := String(item.get("id", ""))
			var itype := String(item.get("type", g[0]))
			var tex: Texture2D = cat.get_icon_texture(iid, itype)
			if tex == null:
				nulls.append("%s:%s" % [g[0], iid])
				continue
			var sz := tex.get_size()
			if int(sz.x) > 64 or int(sz.y) > 64:
				oversize.append("%s=%dx%d" % [iid, int(sz.x), int(sz.y)])
	_ok(nulls.is_empty(),
		"全部物品有图标贴图" if nulls.is_empty()
		else "无贴图 %d 项: %s" % [nulls.size(), ", ".join(nulls)])
	_ok(oversize.is_empty(),
		"图标尺寸都 <=64px（没有拿 1024 原图当图标）" if oversize.is_empty()
		else "尺寸超标: %s" % ", ".join(oversize))

	# ---------- 3. 成就数据不再用共用字符 ----------
	print("")
	print("--- 成就数据 ---")
	var am = load("res://scripts/managers/achievement_manager.gd")
	var ach_dict: Dictionary = am.ACHIEVEMENTS
	var star_count: int = 0
	var no_icon: Array = []
	for k in ach_dict.keys():
		var info: Dictionary = ach_dict[k]
		var ic := String(info.get("icon", ""))
		if ic == "★" or ic.is_empty():
			star_count += 1
			no_icon.append(String(k))
	_ok(star_count == 0,
		"没有成就还在用共用字符图标" if star_count == 0
		else "仍有 %d 个成就用字符图标: %s" % [star_count, ", ".join(no_icon)])

	# ---------- 3b. 元进度商店 / 精英词缀图标 ----------
	print("")
	print("--- 元进度商店与精英词缀图标 ---")
	var cat2 = load("res://scripts/core/item_catalog.gd")
	for meta_id in ["damage", "max_hp", "speed", "armor", "magnet", "gold"]:
		var tex2: Texture2D = cat2.get_icon_texture(String(meta_id))
		_ok(tex2 != null, "元进度 %s 有图标贴图" % meta_id)
	for affix_id in ["shielded", "charger", "splitter", "haster"]:
		var tex3: Texture2D = tm_inst.get_affix_icon(String(affix_id))
		_ok(tex3 != null, "词缀 %s 有图标贴图（懒加载命中）" % affix_id)

	# ---------- 4. 刷怪 / 增益落点边界 ----------
	print("")
	print("--- 刷怪与增益落点边界 ---")
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
		var b: Rect2 = room.get_room_bounds()
		if room is Node2D:
			b = Rect2((room as Node2D).to_global(b.position), b.size)
		print("  房间内部 = %s" % str(b))

		var outside: int = 0
		var samples: int = 200
		for i in samples:
			var pos: Vector2 = wm._get_spawn_position()
			if not b.has_point(pos):
				outside += 1
		_ok(outside == 0,
			"刷怪落点 200 次采样全部在房间内" if outside == 0
			else "刷怪落点越界 %d/%d 次" % [outside, samples])

		# 增益落点：直接调 _spawn_powerup，验证生成位置
		var pw_outside: int = 0
		for i in 40:
			var before: int = get_nodes_in_group("powerups").size()
			wm._spawn_powerup()
			var now: Array = get_nodes_in_group("powerups")
			if now.size() > before:
				var node = now[now.size() - 1]
				if not b.has_point(node.global_position):
					pw_outside += 1
				node.queue_free()
		_ok(pw_outside == 0,
			"增益落点 40 次采样全部在房间内" if pw_outside == 0
			else "增益落点越界 %d/40 次" % pw_outside)

		# 房间解析：RoomLookup 必须能找到房间
		var rl = load("res://scripts/core/room_lookup.gd")
		var found = rl.find_room(player)
		_ok(found != null, "RoomLookup 能从玩家找到房间节点")
		_ok(found == room, "找到的房间就是当前房间")

	tm_inst.queue_free()

	# 直接在这里收尾并退出，不靠 SceneTree 的 _finish()：
	# 诊断期间主场景还在跑（敌人还在生成），退出时的释放顺序会让
	# 敌人访问到已被释放的 TextureManager，进程在打印结论前就崩了。
	_print_summary()
	quit(0 if _fail == 0 else 1)

func _print_summary() -> void:
	print("")
	if _fail == 0:
		print("✅ 全部通过（%d 项警告）" % _warn)
	else:
		print("❌ 失败 %d 项（%d 项警告）" % [_fail, _warn])
