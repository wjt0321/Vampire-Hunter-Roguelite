extends SceneTree
## Real scenes; no Main, no automatic weapon firing, isolated tools save path.
var passed := 0
var failed := 0
var host: Node2D
var player: Node
var damage_events: Array[float] = []
const GC = preload("res://scripts/core/game_config.gd")
const PASSIVES = preload("res://scripts/player/passive_item_data.gd")

func _initialize() -> void:
	_run()

func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("PASS ", label)
	else:
		failed += 1
		print("FAIL ", label)

func spawn(kind: String, hp: float = 1000.0) -> Node:
	var enemy = load("res://scenes/enemies/%s.tscn" % kind).instantiate()
	enemy.position = Vector2(1000, 1000)
	host.add_child(enemy)
	enemy.player = player
	enemy.max_hp = hp
	enemy.current_hp = hp
	enemy.set_physics_process(false)
	enemy.set_process(false)
	return enemy

func _run() -> void:
	await process_frame
	GC.clear_daily()
	host = Node2D.new()
	root.add_child(host)
	current_scene = host
	player = load("res://scenes/player/player.tscn").instantiate()
	host.add_child(player)
	player.set_physics_process(false)
	player.max_hp = 100.0
	player.current_hp = 40.0
	player.add_passive_item(PASSIVES.create_blood_drain())
	var enemy = spawn("zombie")
	enemy.take_damage(100.0)
	check(is_equal_approx(player.current_hp, 42.0), "18 real 100 damage at 2% drains 2 HP")
	player._drain_pool = 0.0
	player.current_hp = 40.0
	var lethal = spawn("zombie", 100.0)
	lethal.take_damage(10000.0)
	check(is_equal_approx(player.current_hp, 42.0), "18 lethal drain clamps to remaining 100 HP")
	GC.daily_active = true
	GC.daily_modifier_ids = ["no_heal"]
	player._drain_pool = 0.0
	player.current_hp = 40.0
	enemy.take_damage(100.0)
	check(is_equal_approx(player.current_hp, 40.0), "19 no_heal blocks drain")
	GC.clear_daily()
	player._drain_pool = 0.0
	var dot_lethal = spawn("zombie", 100.0)
	dot_lethal.dot_damage(10000.0)
	check(is_equal_approx(player.current_hp, 42.0), "18 lethal DoT reports effective damage once")
	player.drain_ratio = 0.0
	var stone = spawn("gargoyle")
	stone.take_damage_with_knockback(100.0, Vector2.RIGHT)
	check(is_equal_approx(stone.current_hp, 1000.0 - 100.0 * (1.0 - GC.calculate_damage_reduction(stone.armor))), "14 knockback respects gargoyle armor")
	var exploder = spawn("exploder", 100.0)
	exploder.take_damage_with_knockback(75.0, Vector2.RIGHT)
	check(exploder.is_detonating, "14 knockback invokes exploder damage hook")
	exploder.queue_free()
	stone._petrify()
	var stone_hp: float = stone.current_hp
	stone.take_damage_with_knockback(100.0, Vector2.RIGHT)
	check(is_equal_approx(stone.current_hp, stone_hp), "14 petrification blocks knockback damage")
	stone.set_process(true)
	await create_timer(stone.petrify_duration + 0.15).timeout
	check(not stone.is_petrified, "02 real petrification timer expires")
	stone.set_physics_process(false)
	stone.set_process(false)
	for kind in ["werewolf", "skeleton_archer", "exploder", "vampire_lord"]:
		var frozen = spawn(kind)
		if kind == "vampire_lord":
			frozen.intro_invulnerable = false
			var speed_before: float = frozen.move_speed
			frozen.freeze(0.12)
			var boss_origin: Vector2 = frozen.position
			frozen._physics_process(0.05)
			check(not frozen.is_frozen and not frozen.position.is_equal_approx(boss_origin), "16 chilled vampire_lord keeps moving")
			check(frozen.move_speed < speed_before - 1.0, "16 chilled vampire_lord is slowed instead of rooted")
			frozen.set_process(true)
			await create_timer(0.18).timeout
			check(not frozen.is_frozen and frozen._slow_remaining > 0.5, "16 boss chill outlasts the old 0.12s root")
			frozen.queue_free()
			continue
		frozen.freeze(0.12)
		var origin: Vector2 = frozen.position
		frozen._physics_process(0.05)
		check(frozen.position.is_equal_approx(origin), "16 frozen %s does not move" % kind)
		frozen.set_process(true)
		await create_timer(0.18).timeout
		check(not frozen.is_frozen, "16 frozen %s thaws" % kind)
		frozen.queue_free()
	enemy.apply_bleed(20.0, 0.1)
	enemy._tick_bleed(0.2)
	enemy.apply_bleed(2.0, 1.0)
	check(is_equal_approx(enemy.bleed_dps, 2.0), "20 expired strong bleed accepts weaker new bleed")
	var prince = spawn("vampire_prince")
	prince.apply_slow(0.7, 0.1)
	prince._enter_second_phase()
	prince._tick_speed_decay(0.2)
	check(is_equal_approx(prince.move_speed, 90.0), "21 phase speed survives slow expiration")
	prince._start_charge()
	var charge_origin: Vector2 = prince.position
	prince._physics_process(0.1)
	check(not prince.is_charging and prince.position.is_equal_approx(charge_origin), "22 charge windup stays still")
	await create_timer(0.35).timeout
	check(prince.is_charging, "22 charge starts after windup")
	player.is_invincible = true
	prince.current_hp = 500.0
	prince._on_contact_area_body_entered(player)
	check(is_equal_approx(prince.current_hp, 500.0), "27 blocked player damage gives prince no healing")
	player.is_invincible = false
	player.current_hp = 100.0
	player.armor = 30.0
	prince._on_contact_area_body_entered(player)
	check(is_equal_approx(prince.current_hp - 500.0, (100.0 - player.current_hp) * prince.lifesteal_percent), "27 prince drains actual armored HP loss")
	var lord = spawn("vampire_lord")
	check(lord._contact_area != null, "23 lord caches contact area")
	prince.queue_free()
	player.current_hp = 100.0
	player.armor = 0.0
	player.is_invincible = false
	lord.position = player.position
	lord.set_process(true)
	await create_timer(2.9).timeout
	var contact_hp: float = player.current_hp
	await create_timer(0.65).timeout
	check(contact_hp < 100.0 and player.current_hp < contact_hp, "23 real lord overlap continues dealing damage after intro")
	lord.queue_free()
	await process_frame
	await _test_weapons(enemy)
	await _test_evolution_and_chain()
	_test_xp()
	await _test_review_combinations()
	_test_damage_signal()
	await process_frame
	await create_timer(0.8).timeout
	host.free()
	root.get_node("ObjectPool").clear_all()
	await process_frame
	for audio in root.get_node("AudioManager").get("_sfx_players"):
		audio.stop()
		audio.stream = null
	print("pre_audio_combat: %d passed / %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)

func _test_weapons(enemy: Node) -> void:
	player.current_hp = 100.0
	player.crit_chance = 1.0
	player.freeze_chance = 1.0
	player.bleed_chance = 0.0
	enemy.bleed_dps = 0.0
	enemy.bleed_remaining = 0.0
	enemy.current_hp = 1000.0
	var knife = load("res://scenes/player/knife_bullet.tscn").instantiate()
	host.add_child(knife)
	knife.base_damage = 10.0
	knife._on_body_entered(enemy)
	check(is_equal_approx(enemy.current_hp, 980.0) and enemy.is_frozen, "17 knife applies crit and freeze")
	knife.queue_free()
	var pool = root.get_node("ObjectPool")
	var scene = load("res://scenes/player/bullet.tscn")
	var bullet = pool.acquire(scene)
	host.add_child(bullet)
	pool.release(bullet)
	await process_frame
	bullet = pool.acquire(scene)
	host.add_child(bullet)
	bullet.base_damage = 10.0
	enemy.current_hp = 1000.0
	bullet._on_body_entered(enemy)
	check(is_equal_approx(enemy.current_hp, 980.0), "15 pooled bullet retains crit on reuse")
	enemy._unfreeze()
	player.bleed_chance = 1.0
	var cloud = load("res://scenes/player/poison_cloud.tscn").instantiate()
	host.add_child(cloud)
	cloud.base_damage = 10.0
	cloud._on_body_entered(enemy)
	enemy.current_hp = 1000.0
	cloud._deal_damage_to_enemies()
	check(is_equal_approx(enemy.current_hp, 990.0) and not enemy.is_frozen and not enemy.is_bleeding(), "17 cloud DoT cannot crit freeze or reapply bleed")
	cloud.duration = 0.1
	cloud._physics_process(0.11)
	var after_expiry: float = enemy.current_hp
	cloud._physics_process(1.0)
	cloud._deal_damage_to_enemies()
	check(is_equal_approx(enemy.current_hp, after_expiry), "47 expired cloud cannot deal more damage")
	check(not cloud.is_physics_processing(), "47 cloud stops processing on first expiry")
	player.crit_chance = 0.0
	player.freeze_chance = 0.0
	player.bleed_chance = 0.0
	var dead = spawn("zombie")
	dead.is_dead = true
	dead.position = Vector2(1, 0)
	var manager = load("res://scripts/weapons/weapon_manager.gd").new()
	host.add_child(manager)
	manager.setup(player)
	manager.set_process(false)
	dead.is_dead = false
	manager._refresh_enemy_cache()
	dead.is_dead = true
	check(not manager._get_nearest_enemy_direction(player.position).is_equal_approx(Vector2.RIGHT), "46 shooting rejects a target killed after cache refresh")
	manager._refresh_enemy_cache()
	check(manager._nearest_enemy_pos != dead.position, "46 weapon cache excludes dying enemies")
	var homing = load("res://scenes/player/bullet.tscn").instantiate()
	host.add_child(homing)
	check(homing._find_nearest_enemy() != dead, "46 homing ignores dying target")
	homing._homing_target = dead
	homing._update_homing(0.01)
	check(homing._homing_target != dead, "46 homing reacquires when tracked target dies")
	homing.queue_free()
	dead.queue_free()
	var coin = load("res://scenes/player/silver_coin.tscn").instantiate()
	host.add_child(coin)
	coin._player = player
	coin.position = player.position + Vector2(150, 0)
	player.pickup_range_bonus = 100.0
	coin._process(0.01)
	check(coin._attracted, "13 silver uses pickup_range_bonus")
	coin.queue_free()
	manager.queue_free()

func _test_xp() -> void:
	var p = load("res://scripts/player/player.gd").new()
	p.xp_to_next_level = 100000
	p.xp_bonus_multiplier = 0.2
	p.add_passive_item(PASSIVES.create_greed_ring())
	check(is_equal_approx(p.xp_bonus_multiplier, 0.2 + p.passive_items[0].get_scaled_value()), "31 greed preserves preexisting XP bonus")
	p.xp_bonus_multiplier += 0.1
	p.add_passive_item(PASSIVES.create_greed_ring())
	check(is_equal_approx(p.xp_bonus_multiplier, 0.3 + p.passive_items[0].get_scaled_value()), "31 greed upgrade preserves later external XP growth")
	p.xp_bonus_multiplier = 0.3
	for i in range(10):
		p.gain_xp(1)
	var separate: int = p.current_xp
	var merged = load("res://scripts/player/player.gd").new()
	merged.xp_to_next_level = 100000
	merged.xp_bonus_multiplier = 0.3
	merged.gain_xp(10)
	check(separate == merged.current_xp, "48 separate XP equals merged XP")
	p.free()
	merged.free()

func _test_damage_signal() -> void:
	check(player.has_signal("damage_received"), "damage_received signal exists")
	if not player.has_signal("damage_received"):
		return
	player.connect("damage_received", func(amount: float): damage_events.append(amount))
	player.current_hp = 100.0
	player.armor = 0.0
	player.is_invincible = false
	player.take_damage(10.0)
	player.take_damage(10.0)
	player.is_invincible = false
	player.has_shield = true
	player.take_damage(10.0)
	check(damage_events.size() == 1 and is_equal_approx(damage_events[0], 10.0), "damage_received counts actual HP loss only")
	player.is_invincible = false
	player.take_damage(0.0)
	check(damage_events.size() == 1, "zero damage does not emit damage_received")
	player.current_hp = 5.0
	player.take_damage(100.0)
	check(damage_events.size() == 2 and is_equal_approx(damage_events[-1], 5.0), "damage_received clamps lethal damage to remaining HP")

func _test_evolution_and_chain() -> void:
	# Put targets at distinct nonzero world positions to catch local/world errors.
	for old_enemy in get_nodes_in_group("enemies"):
		old_enemy.queue_free()
	await process_frame
	var first = spawn("zombie", 10000.0)
	var second = spawn("zombie", 10000.0)
	first.position = Vector2(440, 300)
	second.position = Vector2(540, 300)
	var lightning = load("res://scenes/player/lightning_chain.tscn").instantiate()
	lightning.position = Vector2(400, 300)
	lightning.base_damage = 10.0
	lightning.max_jumps = 2
	player.crit_chance = 1.0
	player.freeze_chance = 1.0
	host.add_child(lightning)
	check(is_equal_approx(first.current_hp, 9980.0) and first.is_frozen, "17 lightning applies direct-hit passives")
	check(is_equal_approx(second.current_hp, 9986.0), "26 chain damage decays per jump")
	check(lightning.line.points.size() == 12, "26 both chain segments remain visible")
	check(lightning.line.to_global(lightning.line.points[0]).is_equal_approx(Vector2(400, 300)), "26 first line vertex is correct world origin")
	check(lightning.line.to_global(lightning.line.points[-1]).is_equal_approx(second.position), "26 final line vertex reaches second target")
	player.crit_chance = 0.0
	player.freeze_chance = 0.0
	await create_timer(0.4).timeout
	for id in ["shotgun", "poison_cloud", "blood_burst", "lightning_chain", "crossbow", "throwing_knife"]:
		var manager = load("res://scripts/weapons/weapon_manager.gd").new()
		host.add_child(manager)
		manager.setup(player, id)
		manager.set_process(false)
		var weapon = manager.weapons[0]
		# Upgrade through the real manager, never assign max level directly.
		for level in range(1, weapon.max_level):
			manager.add_weapon(manager._create_weapon_by_id(id))
		var evo = manager.get_weapon_evolution(id)
		var size_mult: float = evo.size_multiplier
		var evolved: Array = manager.try_evolve_from_chest(evo.required_passive_items)
		check(evolved.size() == 1, "25 %s evolves after incremental upgrades and chest event" % id)
		var before: Array = host.get_children()
		# Mouse-less test still exercises normal weapon firing; auto-aim supplies direction.
		weapon.auto_aim = true
		manager._fire_weapon(weapon)
		var spawned: Array = []
		for child in host.get_children():
			if child not in before:
				spawned.append(child)
		match id:
			"shotgun":
				var bullets: Array = spawned.filter(func(n): return n is Area2D and "direction" in n)
				check(bullets.size() == int(ceil(weapon.get_scaled_projectile_count() * size_mult)), "25 shotgun count follows configured 1.3 multiplier")
				if bullets.size() > 1:
					var spread: float = absf(bullets[0].direction.angle_to(bullets[-1].direction))
					check(is_equal_approx(spread, weapon.spread_angle * size_mult), "25 shotgun spread follows configured multiplier")
			"poison_cloud", "blood_burst":
				var clouds: Array = spawned.filter(func(n): return "tick_interval" in n)
				check(clouds.size() == 1 and is_equal_approx(clouds[0].scale.x, weapon.get_scaled_cloud_size() * size_mult), "25 %s radius follows configured multiplier" % id)
			"crossbow":
				var bolts: Array = spawned.filter(func(n): return "max_pierce" in n)
				check(not bolts.is_empty() and bolts[0].max_pierce == int(ceil(weapon.get_scaled_pierce_count() * size_mult)), "25 crossbow penetration follows configured multiplier")
			"lightning_chain":
				var chains: Array = spawned.filter(func(n): return "max_jumps" in n)
				check(chains.size() == 1 and chains[0].max_jumps == int(ceil(weapon.get_scaled_lightning_jumps() * size_mult)), "25 lightning jump count follows configured multiplier")
				check(chains.size() == 1 and is_equal_approx(chains[0].jump_range, GC.LIGHTNING_EVOLVED_JUMP_RANGE), "25 evolved lightning uses the capped jump range")
				check(chains.size() == 1 and is_equal_approx(chains[0].acquire_range, GC.LIGHTNING_EVOLVED_ACQUIRE_RANGE), "25 evolved lightning uses the capped acquire range")
			"throwing_knife":
				var blade = manager._orbit_blades[0]
				for orbit in manager._orbit_blades:
					orbit.set_process(false)
				manager.weapons.push_front(manager._create_pistol())
				player.damage_multiplier = 2.0
				player.powerup_damage_mult = 1.5
				player.berserker_bonus = 0.5
				player.current_hp = 20.0
				var expected: float = weapon.get_scaled_damage() * 0.55 * 2.5 * 1.5 * GC.get_weapon_damage_multiplier(1)
				blade.global_position = first.global_position
				var hp_before: float = first.current_hp
				blade._strike(0.0)
				check(is_equal_approx(hp_before - first.current_hp, expected), "24 orbit uses live player multipliers and slot decay")
				player.current_hp = 100.0
				player.damage_multiplier = 1.0
				player.powerup_damage_mult = 1.0
				player.berserker_bonus = 0.0
				blade._cooldowns.clear()
				player.crit_chance = 1.0
				player.freeze_chance = 1.0
				first._unfreeze()
				hp_before = first.current_hp
				blade._strike(0.0)
				expected = weapon.get_scaled_damage() * 0.55 * GC.get_weapon_damage_multiplier(1) * 2.0
				check(is_equal_approx(hp_before - first.current_hp, expected) and first.is_frozen, "17/24 orbit updates after buff expiry and applies passives once")
				player.crit_chance = 0.0
				player.freeze_chance = 0.0
		for child in spawned:
			child.queue_free()
		for blade in manager._orbit_blades:
			if is_instance_valid(blade):
				blade.queue_free()
		manager.queue_free()
		await process_frame

func _test_review_combinations() -> void:
	for old_enemy in get_nodes_in_group("enemies"):
		old_enemy.queue_free()
	await process_frame
	var first = spawn("zombie", 500.0)
	var corpse = spawn("zombie", 500.0)
	var second = spawn("zombie", 500.0)
	first.position = Vector2(440, 300)
	corpse.position = Vector2(460, 300)
	second.position = Vector2(540, 300)
	corpse.take_damage(10000.0)
	check(corpse.is_dead and corpse.is_inside_tree() and corpse.is_in_group("enemies"), "46 real death remains in enemy group before animation ends")
	var chain = load("res://scenes/player/lightning_chain.tscn").instantiate()
	chain.position = Vector2(400, 300)
	chain.base_damage = 10.0
	chain.max_jumps = 2
	host.add_child(chain)
	check(is_equal_approx(first.current_hp, 490.0) and is_equal_approx(second.current_hp, 493.0), "46 chain skips corpse and deals second live hit at 7 damage")
	check(not chain._hit_enemies.has(corpse), "46 corpse consumes neither jump nor damage decay")
	first.queue_free()
	corpse.queue_free()
	second.queue_free()
	await process_frame

	var p = load("res://scenes/player/player.tscn").instantiate()
	p.position = Vector2(2000, 100)
	host.add_child(p)
	p.set_physics_process(false)
	p.current_hp = 40.0
	p.add_passive_item(PASSIVES.create_blood_drain())
	p.add_passive_item(PASSIVES.create_lightning_shield())
	var received: Array[float] = []
	p.damage_received.connect(func(amount: float): received.append(amount))
	var prince = spawn("vampire_prince", 1000.0)
	prince.player = p
	prince.position = Vector2(2100, 100)
	prince.current_hp = 580.0
	prince.take_damage(80.0)
	check(is_equal_approx(p._drain_pool, 1.6) and is_equal_approx(p.current_hp, 40.0), "27 natural 80 damage primes level-one drain to 1.6 HP")
	prince.contact_damage = 10.0
	prince._on_contact_area_body_entered(p)
	check(received.size() == 1 and is_equal_approx(received[0], 10.0) and is_equal_approx(p.current_hp, 32.0), "27 retaliation drains 2 HP after 10 actual incoming damage")
	check(is_equal_approx(prince.current_hp, 482.0), "27 prince heals 2 HP independently of synchronous player drain")
	prince.queue_free()
	p.queue_free()
	await process_frame
