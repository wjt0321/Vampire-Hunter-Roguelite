extends SceneTree
## 战斗表现回归测试（开发用）
## 用法: godot --headless --path . --script res://tools/combat_visual_test.gd
## 覆盖: ① 程序化弹道贴图 ② 玩家子弹 / 敌人投射物的外观与加色混合
##       ③ Boss 登场无敌 + 血条从 0 填满，结束后可正常掉血

var _fail: int = 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ✅ %s" % msg)
	else:
		print("  ❌ %s" % msg)
		_fail += 1

func _initialize() -> void:
	_run()

func _run() -> void:
	await process_frame
	print("")
	print("====== 战斗表现回归测试 ======")

	# ---------- ① 程序化弹道贴图 ----------
	print("")
	print("--- 弹道贴图 ---")
	var bolt := ProjectileVisuals.get_bolt_texture()
	var orb := ProjectileVisuals.get_orb_texture()
	_check(bolt != null and bolt.get_size() == Vector2(48, 20), "长条弹贴图 48x20")
	_check(orb != null and orb.get_size() == Vector2(48, 48), "圆形弹贴图 48x48")
	var bolt_img := bolt.get_image()
	var orb_img := orb.get_image()
	_check(bolt_img.get_pixel(24, 10).a > 0.9, "长条弹中心是实心亮芯")
	_check(bolt_img.get_pixel(0, 0).a < 0.05, "长条弹四角透明（有柔光过渡）")
	_check(orb_img.get_pixel(24, 24).a > 0.9, "圆形弹中心是实心亮芯")
	_check(orb_img.get_pixel(1, 1).a < 0.05, "圆形弹四角透明")

	# ---------- ② 玩家子弹 ----------
	print("")
	print("--- 玩家子弹 ---")
	var bullet = load("res://scenes/player/bullet.tscn").instantiate()
	root.add_child(bullet)
	await process_frame
	var bullet_spr := bullet.get_node("Sprite2D") as Sprite2D
	_check(bullet_spr.texture == bolt, "子弹使用发光长条贴图")
	_check(_is_additive(bullet_spr), "子弹使用加色混合（深色地板上会发光）")
	var bullet_len: float = bullet_spr.scale.x * 48.0
	var bullet_thick: float = bullet_spr.scale.y * 20.0
	_check(bullet_len >= 14.0 and bullet_thick >= 5.0,
		"子弹视觉尺寸 %.1fx%.1f px（改造前 6x6）" % [bullet_len, bullet_thick])
	# 换色（对象池复用时武器管理器会重新上色）
	bullet.apply_visual_style(Color(0.72, 0.42, 1.0), 26.0, 8.0)
	_check(is_equal_approx(bullet_spr.modulate.r, 0.72) and bullet_spr.scale.x * 48.0 > 24.0,
		"apply_visual_style 可换色换尺寸")
	bullet.queue_free()

	# ---------- ③ 敌人投射物 ----------
	print("")
	print("--- 敌人投射物 ---")
	var proj = load("res://scenes/enemies/enemy_projectile.tscn").instantiate()
	proj.direction = Vector2.RIGHT
	root.add_child(proj)
	await process_frame
	var proj_spr := proj.get_node("Sprite2D") as Sprite2D
	_check(proj_spr.texture == orb, "敌人投射物使用发光圆形贴图")
	_check(_is_additive(proj_spr), "敌人投射物使用加色混合")
	var proj_len: float = proj_spr.scale.x * 48.0
	_check(proj_len >= 14.0, "敌人投射物视觉直径 %.1f px（改造前 8x4）" % proj_len)
	var shape := proj.get_node("CollisionShape2D").shape as RectangleShape2D
	_check(shape.size.x <= proj_len, "碰撞体(%.0f) 不超过视觉(%.0f)：看着大、判定不吃亏" % [shape.size.x, proj_len])
	proj.queue_free()

	# ---------- ④ Boss 登场无敌 ----------
	print("")
	print("--- Boss 登场演出 ---")
	var arena := Node2D.new()
	root.add_child(arena)
	current_scene = arena
	var boss = load("res://scenes/enemies/vampire_lord.tscn").instantiate()
	arena.add_child(boss)
	await process_frame

	var bar_seq: Array = []
	boss.boss_hp_changed.connect(func(cur, _mx): bar_seq.append(cur))

	_check(boss.intro_invulnerable, "Boss 登场时处于无敌状态")
	_check(boss.collision_shape.disabled, "登场期间本体碰撞关闭（子弹直接穿过）")
	var contact_shape := boss.get_node_or_null("ContactArea/ContactShape") as CollisionShape2D
	_check(contact_shape != null and contact_shape.disabled, "登场期间接触伤害关闭")
	var hp_before: float = boss.current_hp
	boss.take_damage(200.0)
	boss.take_damage_with_knockback(200.0, Vector2.RIGHT)
	_check(is_equal_approx(boss.current_hp, hp_before), "无敌期间伤害完全免疫（血量保持 %.0f）" % hp_before)

	# 等血条填满 + 演出结束
	await create_timer(2.9).timeout
	_check(not boss.intro_invulnerable, "2.9 秒后解除无敌")
	_check(not boss.collision_shape.disabled, "碰撞体已重新启用")
	_check(contact_shape == null or not contact_shape.disabled, "接触伤害已重新启用")
	_check(bar_seq.size() >= 2 and is_zero_approx(bar_seq[0]),
		"血条从 0 开始填充（收到 %d 次血量信号，首个值 %.0f）" % [bar_seq.size(), bar_seq[0] if bar_seq.size() > 0 else -1.0])
	_check(not is_instance_valid(boss._intro_shield), "护盾光环已清除")

	var hp_before2: float = boss.current_hp
	boss.take_damage(200.0)
	_check(boss.current_hp < hp_before2, "开战后伤害正常生效（%.0f → %.0f）" % [hp_before2, boss.current_hp])
	var last_bar: float = boss.max_hp
	if bar_seq.size() > 0:
		last_bar = bar_seq[bar_seq.size() - 1]
	_check(last_bar < boss.max_hp, "扣血后血条同步刷新（当前 %.0f / %.0f）" % [last_bar, boss.max_hp])

	print("")
	if _fail == 0:
		print("✅ 全部通过")
	else:
		print("❌ 失败 %d 项" % _fail)
	quit(1 if _fail > 0 else 0)

func _is_additive(sprite: Sprite2D) -> bool:
	var mat := sprite.material as CanvasItemMaterial
	return mat != null and mat.blend_mode == CanvasItemMaterial.BLEND_MODE_ADD
