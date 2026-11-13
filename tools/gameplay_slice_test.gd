extends SceneTree
## 武器变种、融合、新武器、新敌人和前两层 Boss。
## godot --headless --path . --script res://tools/gameplay_slice_test.gd

const WeaponDataScript = preload("res://scripts/weapons/weapon_data.gd")
const DungeonScript = preload("res://scripts/map/dungeon_manager.gd")

var WeaponManagerScript: GDScript

var _pass: int = 0
var _fail: int = 0
var _host: Node2D


class Dummy extends CharacterBody2D:
	var hazard_slow: float = 1.0
	var _sources: int = 0

	func add_hazard_slow() -> void:
		_sources += 1
		hazard_slow = 0.45

	func remove_hazard_slow() -> void:
		_sources = maxi(_sources - 1, 0)
		if _sources == 0:
			hazard_slow = 1.0


func _initialize() -> void:
	_run()


func _check(ok: bool, label: String) -> void:
	if ok:
		_pass += 1
		print("✅ %s" % label)
	else:
		_fail += 1
		print("❌ %s" % label)


func _finish() -> void:
	print("")
	print("通过 %d / 失败 %d" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)


func _snapshot(weapon) -> Dictionary:
	return {
		"damage": weapon.get_scaled_damage(),
		"fire_rate": weapon.get_scaled_fire_rate(),
		"projectile_count": weapon.get_scaled_projectile_count(),
		"pierce_count": weapon.get_scaled_pierce_count(),
		"bounce_count": weapon.get_scaled_bounce_count(),
		"cloud_duration": weapon.get_scaled_cloud_duration(),
		"cloud_size": weapon.get_scaled_cloud_size(),
		"lightning_jumps": weapon.get_scaled_lightning_jumps(),
		"spread_angle": weapon.get_scaled_spread(),
		"return_damage_mult": weapon.get_scaled_return_mult(),
		"arc_width": weapon.get_scaled_arc_width(),
		"cone_angle": weapon.get_scaled_cone(),
		"knockback_force": weapon.get_scaled_knockback(),
		"whip_reach": weapon.get_scaled_whip_reach(),
		"swing_count": weapon.get_scaled_swings(),
		"ring_radius": weapon.get_scaled_ring_radius(),
		"slow_duration": weapon.get_scaled_slow_duration(),
		"burst_gap": weapon.get_scaled_burst_gap(),
		"bullet_range": weapon.get_scaled_bullet_range(),
		"bullet_speed": weapon.get_scaled_bullet_speed(),
	}


func _make(id: String):
	match id:
		"pistol":
			return WeaponManagerScript._create_pistol()
		"shotgun":
			return WeaponManagerScript.create_shotgun()
		"magic_book":
			return WeaponManagerScript.create_magic_book()
		"throwing_knife":
			return WeaponManagerScript.create_throwing_knife()
		"poison_cloud":
			return WeaponManagerScript.create_poison_cloud()
		"lightning_chain":
			return WeaponManagerScript.create_lightning_chain()
		"crossbow":
			return WeaponManagerScript.create_crossbow()
		"holy_wand":
			return WeaponManagerScript.create_holy_wand()
		"kunai":
			return WeaponManagerScript.create_kunai()
		"flame_thrower":
			return WeaponManagerScript.create_flame_thrower()
		"blood_burst":
			return WeaponManagerScript.create_blood_burst()
		"scythe":
			return WeaponManagerScript.create_scythe()
		"thorn_whip":
			return WeaponManagerScript.create_thorn_whip()
		"frost_bell":
			return WeaponManagerScript.create_frost_bell()
		"repeater":
			return WeaponManagerScript.create_repeater()
		"soul_lantern":
			return WeaponManagerScript.create_soul_lantern()
		"spike_tome":
			return WeaponManagerScript.create_spike_tome()
		"chain_gun":
			return WeaponManagerScript.create_chain_gun()
	return null


func _near(a: float, b: float) -> bool:
	return is_equal_approx(a, b)


func _run() -> void:
	await process_frame
	WeaponManagerScript = load("res://scripts/weapons/weapon_manager.gd")
	_host = Node2D.new()
	_host.name = "SliceHost"
	root.add_child(_host)
	current_scene = _host
	_test_variant_tables()
	await _test_fusion()
	await _test_new_weapons()
	await _test_enemies()
	await _test_bosses()
	_test_blueprint()
	_finish()


func _test_variant_tables() -> void:
	var ids: Array = WeaponDataScript.LEVEL_STEPS.keys()
	_check(ids.size() == 18, "18 把武器都有变种表")
	var blank = WeaponDataScript.new()
	blank.weapon_id = "missing"
	_check(not blank.has_level_table() and not blank.level_up(), "没有变种表的武器不能升级")
	for id in ids:
		var weapon = _make(String(id))
		_check(weapon != null and weapon.has_level_table(), "%s 能从工厂造出来" % id)
		if weapon == null:
			continue
		var card: String = weapon.describe_next_level()
		_check(card != "" and card == String(weapon._step(2).get("card", "")), "%s 的 2 级卡片和表一致" % id)
		for level in range(2, 6):
			var before: Dictionary = _snapshot(weapon)
			var keys: Array = weapon.step_keys(level)
			_check(weapon.level_up(), "%s 升到 %d 级" % [id, level])
			var after: Dictionary = _snapshot(weapon)
			var changed: Array = []
			for key in before.keys():
				if not _near(float(before[key]), float(after[key])):
					changed.append(String(key))
			changed.sort()
			var expected: Array = []
			for key in keys:
				expected.append(String(key))
			expected.sort()
			_check(changed == expected, "%s 第 %d 级只改 %s" % [id, level, ", ".join(expected)])
			_check(weapon.describe_next_level() == String(weapon._step(level + 1).get("card", "")),
				"%s 升到 %d 级后的下一张卡片对得上" % [id, level])
	var pistol = _make("pistol")
	for _i in 4:
		pistol.level_up()
	_check(_near(pistol.get_scaled_damage(), 6.4) and _near(pistol.get_scaled_fire_rate(), 0.19) and pistol.get_scaled_projectile_count() == 3,
		"手枪 5 级伤害 6.4、间隔 0.19、弹道 3")
	var knife = _make("throwing_knife")
	for _i in 4:
		knife.level_up()
	_check(knife.get_scaled_pierce_count() == 5 and knife.get_scaled_bounce_count() == 1 and _near(knife.get_scaled_damage(), 9.6),
		"飞刀满级穿透 5、弹射 1，伤害仍是 9.6")


func _level_to_max(manager, id: String) -> void:
	for _i in 4:
		manager.add_weapon(_make(id))


func _test_fusion() -> void:
	var player := Dummy.new()
	player.position = Vector2(80, 80)
	_host.add_child(player)
	var manager = WeaponManagerScript.new()
	_host.add_child(manager)
	manager.set_process(false)
	manager.setup(player, "crossbow")
	_level_to_max(manager, "crossbow")
	_check(manager.get_fusion_offer().is_empty(), "只有一把满级武器时不出现融合")
	manager.add_weapon(_make("lightning_chain"))
	_level_to_max(manager, "lightning_chain")
	var offer: Dictionary = manager.get_fusion_offer()
	_check(String(offer.get("id", "")) == "thunder_bolt", "弩和闪电都满级时出现雷矢")
	manager.try_evolve_from_chest(["lightning_shield"])
	_check(manager.get_fusion_offer().is_empty(), "闪电已经宝箱进化后不再融合")
	manager.queue_free()
	await process_frame

	manager = WeaponManagerScript.new()
	_host.add_child(manager)
	manager.set_process(false)
	manager.setup(player, "crossbow")
	_level_to_max(manager, "crossbow")
	manager.add_weapon(_make("lightning_chain"))
	_level_to_max(manager, "lightning_chain")
	_check(manager.apply_fusion("thunder_bolt"), "选雷矢成功")
	_check(manager.weapons.size() == 1 and String(manager.weapons[0].weapon_id) == "thunder_bolt",
		"弩换成雷矢，闪电离槽")
	_check(manager.get_fusion_offer().is_empty(), "本局融合过一次后不再出现融合")
	manager.add_weapon(_make("shotgun"))
	_level_to_max(manager, "shotgun")
	manager.add_weapon(_make("poison_cloud"))
	_level_to_max(manager, "poison_cloud")
	_check(manager.get_fusion_offer().is_empty(), "另一对也满级，仍然没有第二次融合")
	var outside := _spawn("zombie", Vector2(900, 100))
	outside.max_hp = 100.0
	outside.current_hp = 100.0
	var inside := _spawn("zombie", Vector2(180, 100))
	inside.max_hp = 100.0
	inside.current_hp = 100.0
	var chain = load("res://scenes/player/lightning_chain.tscn").instantiate()
	chain.position = Vector2(100, 100)
	chain.base_damage = 10.0
	chain.max_jumps = 1
	chain.acquire_range = 200.0
	chain.jump_range = 200.0
	chain.ranges_overridden = true
	chain.play_bounds = Rect2(0, 0, 400, 400)
	_host.add_child(chain)
	await process_frame
	await process_frame
	_check(is_equal_approx(outside.current_hp, 100.0), "雷矢的跳跃打不中房间边界外的敌人")
	_check(inside.current_hp < 100.0, "房间内的敌人会被那一下跳打中")
	manager.queue_free()


func _spawn(kind: String, pos: Vector2) -> Node:
	var enemy = load("res://scenes/enemies/%s.tscn" % kind).instantiate()
	enemy.position = pos
	_host.add_child(enemy)
	return enemy


func _test_new_weapons() -> void:
	var foe := _spawn("zombie", Vector2(180, 100))
	foe.max_hp = 500.0
	foe.current_hp = 500.0
	var behind := _spawn("zombie", Vector2(20, 100))
	behind.max_hp = 500.0
	behind.current_hp = 500.0
	await process_frame
	var lash = load("res://scripts/player/thorn_lash.gd").new()
	lash.origin = Vector2(100, 100)
	lash.direction = Vector2.RIGHT
	lash.reach = 130.0
	lash.cone = 0.9
	lash.base_damage = 10.0
	lash.damage_multiplier = 1.0
	_host.add_child(lash)
	await process_frame
	_check(foe.current_hp < 500.0 and is_equal_approx(behind.current_hp, 500.0), "长鞭只打身前扇形")

	var chilled := _spawn("zombie", Vector2(140, 240))
	chilled.max_hp = 200.0
	chilled.current_hp = 200.0
	await process_frame
	var ring = load("res://scripts/player/frost_ring.gd").new()
	ring.position = Vector2(100, 240)
	ring.radius = 80.0
	ring.base_damage = 3.0
	ring.set_physics_process(false)
	_host.add_child(ring)
	for _i in 12:
		ring.advance(0.08)
	_check(chilled.current_hp < 200.0 and chilled._slow_mult < 1.0, "霜环造成伤害并挂上霜缚")

	var cut := _spawn("zombie", Vector2(160, 400))
	cut.max_hp = 400.0
	cut.current_hp = 400.0
	await process_frame
	var blade = load("res://scripts/player/boomerang_scythe.gd").new()
	blade.origin = Vector2(40, 400)
	blade.origin_set = true
	blade.direction = Vector2.RIGHT
	blade.travel = 200.0
	blade.speed = 400.0
	blade.arc_width = 0.0
	blade.base_damage = 8.0
	blade.return_damage_mult = 1.0
	blade.set_physics_process(false)
	_host.add_child(blade)
	var drops := 0
	var previous: float = cut.current_hp
	for _i in 40:
		blade.advance(0.05)
		if cut.current_hp < previous - 0.1:
			drops += 1
			previous = cut.current_hp
		if not is_instance_valid(blade):
			break
	_check(drops >= 2, "回旋镰去程和回程各命中一次（%d）" % drops)


func _test_enemies() -> void:
	var player := Dummy.new()
	player.position = Vector2(40, 1600)
	player.add_to_group("player")
	_host.add_child(player)
	var guard := _spawn("shield_guard", Vector2(200, 1600))
	await process_frame
	guard.player = player
	guard.max_hp = 200.0
	guard.current_hp = 200.0
	var before: float = guard.current_hp
	guard.take_damage_with_knockback(40.0, Vector2.RIGHT, 0.0, 0.0)
	var front_loss: float = before - guard.current_hp
	before = guard.current_hp
	guard.take_damage_with_knockback(40.0, Vector2.LEFT, 0.0, 0.0)
	var back_loss: float = before - guard.current_hp
	_check(is_equal_approx(front_loss, 10.0) and is_equal_approx(back_loss, 40.0),
		"盾卫正面减伤，背后全额")

	var priest := _spawn("blood_priest", Vector2(40, 2100))
	var ally := _spawn("zombie", Vector2(180, 2100))
	await process_frame
	ally.current_hp = ally.max_hp - 10.0
	var healed_from: float = ally.current_hp
	_check(priest.try_heal() and is_equal_approx(ally.current_hp, healed_from + 6.0), "血祭司治疗视线内的伤员")
	var wall := StaticBody2D.new()
	wall.collision_layer = GameConfig.LAYER_WALL
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(30, 120)
	shape.shape = rect
	wall.add_child(shape)
	wall.position = Vector2(110, 2100)
	_host.add_child(wall)
	await physics_frame
	await physics_frame
	ally.current_hp = ally.max_hp - 10.0
	var blocked_from: float = ally.current_hp
	_check(not priest.try_heal() and is_equal_approx(ally.current_hp, blocked_from), "墙挡住视线时祭司治不了")

	var weaver := _spawn("web_weaver", Vector2(400, 2600))
	await process_frame
	var web: Node = weaver.drop_web()
	player.global_position = web.global_position
	web._process(0.0)
	_check(is_equal_approx(player.hazard_slow, 0.45), "织网让站在网上的玩家减速")
	web.take_damage(99.0)
	_check(is_equal_approx(player.hazard_slow, 1.0), "网被打掉后减速消失")

	var coffin := _spawn("coffin_guard", Vector2(520, 3100))
	await process_frame
	coffin.current_hp = 5.0
	coffin.take_damage(20.0)
	_check(coffin.revives_left == 0 and coffin.is_dead and coffin._coffin != null, "棺卫第一次倒下留下棺材")
	var shell: Node = coffin._coffin
	shell.take_damage(99.0)
	await process_frame
	_check(coffin.is_dead, "棺材被打掉后棺卫真正死亡")

	var again := _spawn("coffin_guard", Vector2(640, 3600))
	await process_frame
	again.current_hp = 5.0
	again.take_damage(20.0)
	again.revive_from_coffin()
	_check(not again.is_dead and again.current_hp > 1.0 and again.revives_left == 0, "倒计时结束棺卫爬起来，且只有一次")


func _test_bosses() -> void:
	var player := Dummy.new()
	player.position = Vector2(40, 4200)
	_host.add_child(player)
	var lord = load("res://scenes/enemies/blood_lord.tscn").instantiate()
	lord.skip_intro = true
	lord.position = Vector2(220, 4200)
	_host.add_child(lord)
	await process_frame
	lord.player = player
	var before: float = lord.current_hp
	lord.take_damage_with_knockback(40.0, Vector2.RIGHT, 0.0, 0.0)
	var front_loss: float = before - lord.current_hp
	before = lord.current_hp
	lord.take_damage_with_knockback(40.0, Vector2.LEFT, 0.0, 0.0)
	var back_loss: float = before - lord.current_hp
	_check(front_loss < back_loss and int(lord.phase) == 0, "血铠领主正面盾挡，背后伤害更高")
	lord.motion = 2
	lord.notify_wall_contact()
	_check(int(lord.motion) == 3, "血铠领主撞墙后眩晕")
	for _i in 12:
		lord.take_damage_with_knockback(80.0, Vector2.LEFT, 0.0, 0.0)
	_check(int(lord.phase) == 1, "盾破之后进入猛攻，不看血量百分比")

	var queen = load("res://scenes/enemies/blood_matriarch.tscn").instantiate()
	queen.skip_intro = true
	queen.position = Vector2(800, 4200)
	_host.add_child(queen)
	await process_frame
	var egg: Node = queen.lay_egg()
	_check(egg != null and not queen.exposed, "织血母皇先产卵")
	egg.take_damage(99.0)
	_check(queen.exposed, "卵巢清掉后母皇暴露，改为近身阶段")
	_check(queen.lay_egg() == null, "暴露之后不再产卵")


func _test_blueprint() -> void:
	var dungeon = DungeonScript.new()
	_check(dungeon.floors_data.size() == 5, "主线是五层")
	_check(DungeonScript.FLOOR_BLUEPRINT.size() == 5, "五层蓝图已经列出来")
	_check(String(dungeon.floors_data[0]["boss_id"]) == "blood_lord", "第一层是血铠领主")
	_check(String(dungeon.floors_data[1]["boss_id"]) == "blood_matriarch", "第二层是织血母皇")
	_check(String(dungeon.floors_data[2]["boss_id"]) == "tomb_warden", "第三层是墓穴守望者")
	_check(String(dungeon.floors_data[3]["boss_id"]) == "alchemist_prince", "第四层是炼金亲王")
	_check(String(dungeon.floors_data[4]["boss_id"]) == "eclipse_queen", "第五层是月蚀女王")
	var combat_rooms := 0
	dungeon.start_dungeon()
	while true:
		for room in dungeon.get_room_plan():
			if room == "combat":
				combat_rooms += 1
		if not dungeon.advance_floor():
			break
	_check(combat_rooms == 25, "五层一共 25 个普通战斗房（%d）" % combat_rooms)
	dungeon.free()
