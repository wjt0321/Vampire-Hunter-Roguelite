extends SceneTree
## 五层内容：新武器行为、新敌人、后三个 Boss。
## godot --headless --path . --script res://tools/floor_expansion_test.gd

var _pass: int = 0
var _fail: int = 0
var _host: Node2D


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
	print("通过 %d / 失败 %d" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)


func _spawn(kind: String, pos: Vector2) -> Node:
	var enemy = load("res://scenes/enemies/%s.tscn" % kind).instantiate()
	enemy.position = pos
	_host.add_child(enemy)
	return enemy


func _run() -> void:
	await process_frame
	_host = Node2D.new()
	root.add_child(_host)
	current_scene = _host
	_test_structure()
	await _test_golem_and_links()
	await _test_bosses()
	_test_spike_and_chain()
	_finish()


func _test_structure() -> void:
	var dungeon = load("res://scripts/map/dungeon_manager.gd").new()
	dungeon.start_dungeon()
	var combat := 0
	var floors := 0
	while true:
		floors += 1
		var plan: Array = dungeon.get_room_plan()
		_check(plan.size() == 7 and plan[0] == "combat" and plan[plan.size() - 1] == "boss",
			"第 %d 层是 7 节点且首战尾 Boss" % floors)
		var special := 0
		for room in plan:
			if room == "combat":
				combat += 1
			elif room in ["shop", "treasure", "rest"]:
				special += 1
		_check(special == 1, "第 %d 层只有 1 间特殊房" % floors)
		if not dungeon.advance_floor():
			break
	_check(floors == 5 and combat == 25, "完整流程 5 层、25 个战斗房")
	dungeon.free()


func _test_golem_and_links() -> void:
	var golem := _spawn("furnace_golem", Vector2(100, 100))
	await process_frame
	golem.armor_hp = 30.0
	golem.max_hp = 200.0
	golem.current_hp = 200.0
	golem.take_damage(20.0)
	_check(golem.armor_hp < 30.0 and golem.current_hp > 180.0, "炉心外甲吃掉大部分伤害")
	golem.take_damage(80.0)
	_check(golem.armor_hp <= 0.0 and golem.move_speed >= 140.0, "外甲破碎后傀儡加速")

	var mage := _spawn("resonance_mage", Vector2(400, 100))
	var a := _spawn("zombie", Vector2(460, 100))
	var b := _spawn("zombie", Vector2(520, 100))
	await process_frame
	a.max_hp = 100.0
	a.current_hp = 100.0
	b.max_hp = 100.0
	b.current_hp = 100.0
	mage.link_nearby()
	a.take_damage(20.0)
	_check(a.current_hp < 100.0 and b.current_hp < 100.0 and a.current_hp > 80.0,
		"共振把伤害分给被连接的同伴")
	mage.take_damage(9999.0)
	var hp_a: float = a.current_hp
	a.take_damage(10.0)
	_check(is_equal_approx(hp_a - a.current_hp, 10.0), "术士死后不再分摊")


func _test_bosses() -> void:
	var warden = load("res://scenes/enemies/tomb_warden.tscn").instantiate()
	warden.skip_intro = true
	warden.position = Vector2(200, 400)
	_host.add_child(warden)
	await process_frame
	_check(warden.can_revive(), "结界还在时守望者可以复苏")
	warden.ward.take_damage(999.0)
	_check(not warden.can_revive(), "结界被毁后不能再复苏")

	var prince = load("res://scenes/enemies/alchemist_prince.tscn").instantiate()
	prince.skip_intro = true
	prince.position = Vector2(500, 400)
	_host.add_child(prince)
	await process_frame
	_check(prince.colossus != null, "炼金亲王会带上巨像")
	var colossus: Node = prince.colossus
	_check(colossus.sprite is Sprite2D and colossus.sprite.texture != null,
		"召唤巨像具有已初始化贴图的精灵")
	_check(colossus.collision_shape is CollisionShape2D and colossus.collision_shape.shape != null,
		"召唤巨像具有实体碰撞形状")
	var contact := colossus.get_node_or_null("ContactArea") as Area2D
	_check(contact != null and contact.get_node_or_null("ContactShape") is CollisionShape2D
		and contact.body_entered.is_connected(colossus._on_contact_area_body_entered),
		"召唤巨像具有接触伤害感应区及信号连接")
	await physics_frame
	await physics_frame
	var query := PhysicsPointQueryParameters2D.new()
	query.position = colossus.global_position
	query.collision_mask = GameConfig.LAYER_ENEMY
	var hit_colossus := false
	for hit in _host.get_world_2d().direct_space_state.intersect_point(query):
		if hit.collider == colossus:
			hit_colossus = true
	_check(hit_colossus, "物理查询可以命中召唤巨像")
	prince.colossus.current_hp = 5.0
	prince.colossus.take_damage(20.0)
	_check(prince._mode == "solo_prince", "巨像先倒，亲王改成贴脸招式")
	# 死亡演出契约（本批次 Task 2）：巨像 0.4s 淡出后自回收，<0.8s；旧断言按 1 帧即释放已失效
	await create_timer(0.8).timeout
	_check(not is_instance_valid(colossus), "死亡巨像 0.8s 内自回收场景节点")

	var second = load("res://scenes/enemies/alchemist_prince.tscn").instantiate()
	second.skip_intro = true
	second.position = Vector2(1100, 400)
	_host.add_child(second)
	var survivor: Node = second.colossus
	var defeats: Array = []
	second.boss_defeated.connect(func(): defeats.append(true))
	second.take_damage(second.current_hp + 1.0)
	_check(survivor.enraged and not survivor.is_dead and defeats.is_empty(),
		"亲王先倒，巨像狂暴且战斗尚未结束")
	survivor.take_damage(survivor.current_hp + 1.0)
	_check(defeats.size() == 1, "两者都倒下才发出一次胜利信号")
	await create_timer(0.8).timeout
	_check(not is_instance_valid(survivor), "狂暴巨像死亡后 0.8s 内自回收节点")

	var interrupted = load("res://scenes/enemies/alchemist_prince.tscn").instantiate()
	interrupted.skip_intro = true
	_host.add_child(interrupted)
	var linked: Node = interrupted.colossus
	interrupted.queue_free()
	await process_frame
	await process_frame
	_check(not is_instance_valid(linked), "提前移除亲王时一并清理存活巨像")

	var queen = load("res://scenes/enemies/eclipse_queen.tscn").instantiate()
	queen.skip_intro = true
	queen.position = Vector2(800, 400)
	_host.add_child(queen)
	await process_frame
	_check(queen.moon_phase == 0 and queen.altar != null, "月蚀女王开场带着祭坛")
	queen.altar.take_damage(999.0)
	_check(queen.moon_phase == 1 and queen.safe_radius() == 90.0, "毁掉祭坛后月相推进，安全圈变小")


func _test_spike_and_chain() -> void:
	var foe := _spawn("zombie", Vector2(120, 700))
	foe.max_hp = 100.0
	foe.current_hp = 100.0
	var spike = load("res://scripts/player/ground_spike.gd").new()
	spike.global_position = foe.global_position
	spike.warn_time = 0.0
	spike.radius = 40.0
	spike.base_damage = 15.0
	spike.damage_multiplier = 1.0
	_host.add_child(spike)
	spike.advance(0.01)
	_check(foe.current_hp == 85.0, "预警结束地刺才造成伤害")

	var hound := _spawn("blood_hound", Vector2(300, 700))
	var dummy := CharacterBody2D.new()
	dummy.position = Vector2(360, 700)
	_host.add_child(dummy)
	hound.player = dummy
	hound._phase = "windup"
	hound._timer = 0.0
	hound._lunge_dir = Vector2.RIGHT
	hound._move_towards_player(0.01)
	_check(hound._phase == "lunge", "猎犬预警结束后沿锁定方向扑击")
