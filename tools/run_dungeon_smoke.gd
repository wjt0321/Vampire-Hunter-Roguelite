extends SceneTree
## 地下城全流程冒烟测试（开发用）
## 用法: godot --headless --path . --script res://tools/run_dungeon_smoke.gd
## 作用: 真实加载 main.tscn，按"进房间 → 打 Boss → 进下一层"走完三层，
##       验证层推进、Boss 形态切换、通关判定都不报错。

var _fail: int = 0

func _initialize() -> void:
	_run()

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ✅ %s" % msg)
	else:
		print("  ❌ %s" % msg)
		_fail += 1

func _run() -> void:
	await process_frame
	print("")
	print("====== 地下城全流程冒烟测试 ======")

	var main_scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	# 手动挂载场景时不会自动设置 current_scene，这里补上（与真实启动一致）
	current_scene = main_scene
	# 等开场横幅播完、波次启动
	await create_timer(3.2).timeout

	var dungeon = main_scene.dungeon
	_check(dungeon != null, "DungeonManager 已创建")
	if dungeon == null:
		_print_result()
		return

	_check(dungeon.current_floor == 1, "起始楼层为 1")
	_check(dungeon.room_in_floor == 1, "起始已进入第 1 间房")
	_check(main_scene.room_events != null and main_scene.room_events.combat_room_count == 1,
		"首房已计入事件战斗房数（第 2 间战斗房才可触发）")
	# 首层 floor_started 必须在连接之后发出：否则"一层一次"的标记不会按层重置
	_check(main_scene.room_events != null and int(main_scene.room_events.last_floor_index) == 1,
		"首层 on_floor_changed 真实执行（last_floor_index=%s）"
		% str(main_scene.room_events.last_floor_index if main_scene.room_events else "null"))

	for floor_index in range(1, GameConfig.DUNGEON_FLOOR_COUNT + 1):
		var expected_rooms: int = dungeon.get_room_count()
		print("")
		print("--- 第 %d 层：%s (共 %d 间) ---" % [
			floor_index, dungeon.get_floor_name(), expected_rooms
		])
		_check(dungeon.current_floor == floor_index, "当前层号 = %d" % floor_index)

		# 走完本层所有非 Boss 房间
		var guard: int = 0
		while not dungeon.is_boss_room() and guard < 20:
			guard += 1
			main_scene._enter_next_room()
			# 商店房在淡入 0.5s 后弹货架并暂停整棵树；测试里等它弹完就关掉，
			# 否则 create_timer 永远不会走完（暂停时定时器不走）
			await create_timer(0.65).timeout
			if main_scene.room_shop != null and main_scene.room_shop.visible:
				_check(true, "进入商店房，货架已弹出")
				main_scene.room_shop.close()
				await create_timer(0.15).timeout
				_check(main_scene.current_room != null and main_scene.current_room.portal_spawned,
					"关闭商店后本房传送门已生成")
			await create_timer(0.1).timeout

		var wave_before_boss: int = main_scene.wave_manager.current_wave
		_check(wave_before_boss > 0, "进入 Boss 前已开过 %d 波" % wave_before_boss)

		# 进入 Boss 房
		var room_type: String = main_scene._enter_next_room()
		await create_timer(0.3).timeout
		_check(room_type == "boss", "最后一间是 Boss 房")

		var hud_text: String = main_scene.hud.room_label.text
		_check(hud_text.find("第%d层" % floor_index) >= 0, "HUD 显示层进度: %s" % hud_text)

		var bosses := get_nodes_in_group("boss")
		_check(bosses.size() == 1, "场上存在 1 个 Boss (实际 %d)" % bosses.size())

		var expected_name: String = dungeon.get_boss_name()
		if bosses.size() > 0:
			var boss = bosses[0]
			_check(boss.boss_variant == dungeon.get_boss_variant(),
				"Boss 形态 = %d (%s)" % [boss.boss_variant, expected_name])
			_check(boss.max_hp > 0.0, "Boss 血量为 %.0f" % boss.max_hp)
			_check(boss.floor_index == floor_index, "Boss 楼层标记正确")

		# 模拟击杀
		var old_floor: int = dungeon.current_floor
		main_scene._on_boss_defeated()

		if floor_index < GameConfig.DUNGEON_FLOOR_COUNT:
			# 等真实流程：层已肃清 → 新层横幅 → 自动进入新层第 1 间
			var waited: float = 0.0
			while waited < 15.0:
				if dungeon.current_floor == old_floor + 1 and dungeon.room_in_floor == 1:
					break
				await create_timer(0.2).timeout
				waited += 0.2
			_check(dungeon.current_floor == old_floor + 1,
				"击败 Boss 后进入第 %d 层" % (old_floor + 1))
			_check(dungeon.room_in_floor == 1, "新层已进入第 1 间房")
		else:
			await create_timer(6.0).timeout
			_check(dungeon.current_floor == GameConfig.DUNGEON_FLOOR_COUNT,
				"最终层 Boss 击败后不再推进")

	print("")
	_print_result()
	main_scene.queue_free()

func _print_result() -> void:
	print("")
	if _fail == 0:
		print("🎉 全流程通过：3 层推进、Boss 形态、通关判定均正常")
	else:
		print("⚠️ 失败 %d 项，请检查上方 ❌ 条目" % _fail)
	print("=================================")
	quit(1 if _fail > 0 else 0)
