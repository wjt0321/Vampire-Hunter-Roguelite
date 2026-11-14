extends SceneTree
## 开发用：本轮新增 12 种敌人专属动作条 + 血铠幼虫专属资产的实机截图。
##
## 这张图是验收证据：证明动作条在游戏里真的被读到并播放（不是只有文件躺在磁盘上）。
## 做法：实例化 13 个新敌人 → 逐个调用与行为点相同的 play_action_strip 入口 → 在动作条播到中段时截图。
##
## 用法: godot --path . --script res://tools/iter_action_shot.gd   （必须带窗口）
##
## 输出：artifacts/iteration_assets/iter_action_shot.png

const IDS: Array = [
	["shield_guard", "guard"],
	["blood_hound", "pounce"],
	["blood_priest", "cast"],
	["web_weaver", "cast"],
	["burrower", "burrow"],
	["gem_leech", "steal"],
	["coffin_guard", "revive"],
	["lantern_wraith", "beam"],
	["alchemist_pitcher", "throw"],
	["furnace_golem", "charge"],
	["resonance_mage", "cast"],
	["moon_wing", "dive"],
	["blood_larva", "pounce"],
]


func _initialize() -> void:
	_run()


func _spawn(enemy_id: String, pos: Vector2) -> Node:
	var scene: PackedScene = load("res://scenes/enemies/%s.tscn" % enemy_id)
	if scene == null:
		return null
	var e := scene.instantiate()
	e.position = pos
	current_scene.add_child(e)
	e.set_physics_process(false)
	return e


func _run() -> void:
	await process_frame
	var stage := Node2D.new()
	root.add_child(stage)
	current_scene = stage
	await process_frame

	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.07, 0.09, 1.0)
	bg.size = Vector2(1280, 720)
	bg.z_index = -100
	stage.add_child(bg)

	var label := Label.new()
	label.text = "iter action strips: 12 enemies + blood_larva"
	label.position = Vector2(16, 12)
	label.add_theme_color_override("font_color", Color(0.85, 0.78, 0.55))
	stage.add_child(label)

	var enemies: Array = []
	var ok_ids: Array = []
	for i in range(IDS.size()):
		var pair: Array = IDS[i]
		var e := _spawn(String(pair[0]), Vector2(110 + (i % 6) * 200, 200 + (i / 6) * 200))
		if e != null:
			enemies.append(e)
	await create_timer(1.0).timeout

	# 对照图：还没触发动作条时的样子（待机条）。
	var img_idle: Image = root.get_texture().get_image()
	img_idle.save_png("res://artifacts/iteration_assets/iter_action_idle_shot.png")
	print("待机对照截图: %s" % str(img_idle.get_size()))

	# 触发动作条：与各敌人行为点调用的是同一个入口。
	var failed: Array = []
	for i in range(enemies.size()):
		var pair2: Array = IDS[i]
		var e2: Node = enemies[i]
		var played: bool = e2.call("play_action_strip", String(pair2[0]), String(pair2[1]), "once")
		if played:
			ok_ids.append(String(pair2[0]))
		else:
			failed.append(String(pair2[0]))
	print("动作条触发成功 %d / %d" % [ok_ids.size(), IDS.size()])
	if failed.size() > 0:
		print("未触发：%s" % str(failed))

	# 等到动作条播到中段再截图（6 帧 8fps ≈ 0.75s 一轮）。
	await create_timer(0.35).timeout

	var img: Image = root.get_texture().get_image()
	img.save_png("res://artifacts/iteration_assets/iter_action_shot.png")
	print("动作条截图: %s" % str(img.get_size()))
	quit()
