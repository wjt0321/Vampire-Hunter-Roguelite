extends SceneTree

var _pass: int = 0
var _fail: int = 0

func _initialize() -> void:
	_run()

func _check(ok: bool, label: String) -> void:
	if ok:
		_pass += 1
		print("✅ %s" % label)
	else:
		_fail += 1
		print("❌ %s" % label)

func _run() -> void:
	await process_frame
	var audio := root.get_node_or_null("/root/AudioManager")
	var pool := root.get_node_or_null("/root/ObjectPool")
	_check(audio != null and pool != null, "AudioManager 与 ObjectPool 可用")
	if audio == null or pool == null:
		quit(1)
		return

	audio.play_bgm(load("res://assets/audio/bgm/bgm_battle.mp3"), false)
	var gem: Node = pool.acquire(load("res://scenes/player/xp_gem.tscn"))
	root.add_child(gem)
	pool.release(gem)
	await process_frame
	await process_frame
	var pooled_before: int = pool.get("_pools").values().size()
	_check(pooled_before > 0, "测试前对象池确实持有分离节点")

	# 无 current_scene 的启动/测试边界：VFX 不能创建后既不入树也不释放。
	var vfx := root.get_node_or_null("/root/VFXManager")
	current_scene = null
	vfx.set("_current_scene", null)
	var ring: Node = vfx.call("_create_ring", Vector2.ZERO, Color.RED, 20.0)
	var particle: Node = vfx.call("_create_particle_node", Vector2.ZERO, Color.WHITE, 4.0)
	await process_frame
	_check(not is_instance_valid(ring), "无 current_scene 时环形 VFX 被释放")
	_check(not is_instance_valid(particle), "无 current_scene 时粒子 VFX 被释放")
	if is_instance_valid(ring): ring.free()
	if is_instance_valid(particle): particle.free()

	var has_audio_cleanup: bool = audio.has_method("_exit_tree")
	var has_pool_cleanup: bool = pool.has_method("_exit_tree")
	_check(has_audio_cleanup, "AudioManager 提供退出清理")
	_check(has_pool_cleanup, "ObjectPool 提供退出清理")
	if has_audio_cleanup:
		audio.call("_exit_tree")
		_check(audio.get("_bgm_player").stream == null, "BGM stream 在退出时释放")
		var all_cleared: bool = true
		for player in audio.get("_sfx_players"):
			all_cleared = all_cleared and player.stream == null and not player.playing
		_check(all_cleared, "全部 SFX 停止并释放 stream")
	if has_pool_cleanup:
		pool.call("_exit_tree")
		_check(pool.get("_pools").is_empty(), "对象池退出时释放全部分离节点")
		_check(not is_instance_valid(gem), "池内节点被真正 free，而非仅脱离场景树")

	var rim_lib = load("res://scripts/core/readability_visuals.gd")
	var projectile_lib = load("res://scripts/core/projectile_visuals.gd")
	rim_lib.get_shadow_texture()
	projectile_lib.get_orb_texture()
	var texture_manager := root.get_node_or_null("/root/TextureManager")
	var has_texture_cleanup: bool = texture_manager.has_method("_exit_tree")
	_check(has_texture_cleanup, "TextureManager 提供静态视觉缓存退出清理")
	if has_texture_cleanup:
		texture_manager.call("_exit_tree")
		_check(rim_lib.get("_silhouette_cache").is_empty(), "轮廓剪影缓存退出时清空")
		_check(projectile_lib.get("_orb_texture") == null, "程序化弹丸贴图缓存退出时释放")

	print("通过 %d / 失败 %d" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
