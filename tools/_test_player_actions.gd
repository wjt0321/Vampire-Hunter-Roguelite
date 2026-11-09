extends Node
## 临时验证：确认 player_attack / hurt / death / shield 四张横条真的会被切上去。
## 只看"没报错"不够 —— _play_one_shot 里有 null 保护，失败是静默的。

const SpriteSheetLib = preload("res://scripts/core/sprite_sheet.gd")

func _ready() -> void:
	print("=== 1. 六张玩家纹理与帧数 ===")
	var tm = TextureManager.instance
	if tm == null:
		print("FAIL: TextureManager.instance 为 null")
		get_tree().quit(1)
		return
	for pose in ["idle", "run", "attack", "hurt", "death", "shield"]:
		var t: Texture2D = tm.get_player_texture(pose)
		if t == null:
			print("FAIL %s: 纹理未加载" % pose)
		else:
			print("  OK %-7s %s frames=%d" % [pose, str(t.get_size()), SpriteSheetLib.frame_count(t)])

	print("=== 2. 实例化 player 并触发动作 ===")
	var p = load("res://scenes/player/player.tscn").instantiate()
	add_child(p)
	await get_tree().physics_frame
	await get_tree().physics_frame

	var sprite: Sprite2D = p.get_node_or_null("Sprite2D")
	if sprite == null:
		print("FAIL: 找不到 Sprite2D")
		get_tree().quit(1)
		return

	print("  初始        -> %s" % _name_of(sprite))

	p.apply_recoil(Vector2.RIGHT)
	print("  apply_recoil -> %s  (期望 attack)" % _name_of(sprite))

	await get_tree().physics_frame
	p.take_damage(1.0)
	print("  take_damage  -> %s  (期望 hurt)" % _name_of(sprite))

	await get_tree().physics_frame
	p._grant_shield()
	print("  grant_shield -> %s  (期望 shield)" % _name_of(sprite))

	print("=== 3. 播放结束后能否回到常驻姿态 ===")
	# attack/hurt/shield 都是 4 帧 ÷ 8fps = 0.5s，等够 0.8s
	for i in range(int(0.8 * 60)):
		await get_tree().physics_frame
	print("  0.8s 后     -> %s  (期望 idle)" % _name_of(sprite))

	print("=== 4. 死亡 ===")
	p._die()
	print("  _die()      -> %s  (期望 death)" % _name_of(sprite))

	await get_tree().create_timer(1.2).timeout
	print("  1.2s 后 player 是否已销毁: %s" % str(not is_instance_valid(p)))
	print("=== DONE ===")
	get_tree().quit(0)


func _name_of(s: Sprite2D) -> String:
	if s.texture == null:
		return "<null>"
	return s.texture.resource_path.get_file()
