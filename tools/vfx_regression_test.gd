extends SceneTree

var _fail: int = 0

func _initialize() -> void:
	_run()

func _check(ok: bool, label: String) -> void:
	if ok:
		print("✅ %s" % label)
	else:
		_fail += 1
		print("❌ %s" % label)

func _run() -> void:
	await process_frame
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var main: Variant = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	main.floor_banner.force_hide()
	main.weapon_manager.set_process(false)
	var enemy: Variant = load("res://scenes/enemies/zombie.tscn").instantiate()
	enemy.position = main.player.global_position + Vector2(160, 0)
	main.add_child(enemy)
	await process_frame
	enemy.set_physics_process(false)
	main.floor_banner.force_hide()

	var wm = main.weapon_manager
	var poison = wm.create_poison_cloud()
	wm._spawn_poison_cloud(poison)
	var poison_node := _find_named(main, "PoisonCloud")
	_check(poison_node != null, "毒雾区域已生成")
	if poison_node != null:
		_check(poison_node.sprite.texture == root.get_node("/root/TextureManager").get_effect_texture("poison_spread"),
			"毒雾使用真实雾团贴图，不再生成纯色矩形")
		if poison_node.sprite.texture != null:
			var visual_size: Vector2 = poison_node.sprite.texture.get_size() * poison_node.sprite.scale * poison_node.scale
			_check(visual_size.x <= 140.0 and visual_size.y <= 140.0,
				"普通毒雾视觉尺寸与 128px 判定区匹配（%s）" % str(visual_size))

	var blood = wm.create_blood_burst()
	wm._spawn_blood_burst(blood)
	await process_frame
	var explosion := _find_named(main, "Fx_explosion")
	_check(explosion != null, "血爆爆炸贴图已生成")
	if explosion != null:
		var size: Vector2 = explosion.texture.get_size() * explosion.scale
		_check(maxf(size.x, size.y) <= 220.0,
			"血爆最大视觉边长不超过 220px（实际 %s）" % str(size))
		var mat := explosion.material as CanvasItemMaterial
		_check(mat == null or mat.blend_mode != CanvasItemMaterial.BLEND_MODE_ADD,
			"血爆不再使用加色叠加烧成一片白红")
	var blood_node: Variant = null
	for child in main.get_children():
		if child.get_script() == load("res://scripts/player/poison_cloud.gd") and child.tick_interval == 0.12:
			blood_node = child
	_check(blood_node != null and blood_node.sprite.modulate.a <= 0.35,
		"血爆持续区域低透明度，不遮住角色和敌人")
	_check(blood_node != null and blood_node.tick_interval == 0.12 and blood_node.base_damage == blood.get_scaled_damage(),
		"血爆伤害与结算频率保持不变")

	await create_timer(0.15).timeout
	main.floor_banner.force_hide()
	await process_frame
	var img := root.get_texture().get_image()
	var out := "res://tools/evidence/iteration/vfx_blood_poison.png"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out.get_base_dir()))
	_check(img != null and img.save_png(out) == OK, "保存血爆与毒雾验收截图")

	await create_timer(6.0).timeout
	_check(_find_named(main, "PoisonCloud") == null, "毒雾/血爆到期后无贴图残留")
	_check(_find_named(main, "Fx_explosion") == null, "爆炸贴图演出结束后回收")
	main.queue_free()
	await process_frame
	await process_frame
	print("视觉回归：失败 %d 项" % _fail)
	quit(0 if _fail == 0 else 1)

func _find_named(parent: Node, wanted: String) -> Node:
	for child in parent.get_children():
		if child.name == wanted:
			return child
	return null
