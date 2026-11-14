extends SceneTree
## 开发用：13 个敌人受击条（hurt）的实机截图。
##
## 做法：实例化 13 个敌人 → 对每个调用真实的 take_damage（和游戏里被子弹打中同一条路径）
## → 在受击条播到中段时截图。左边是挨打前，右边是挨打中。
##
## 用法: godot --path . --script res://tools/iter_hurt_shot.gd   （必须带窗口）
##
## 输出：artifacts/iteration_assets/iter_hurt_idle_shot.png
##       artifacts/iteration_assets/iter_hurt_shot.png

const IDS: Array = [
	"shield_guard", "blood_hound", "blood_priest", "web_weaver", "burrower",
	"gem_leech", "coffin_guard", "lantern_wraith", "alchemist_pitcher",
	"furnace_golem", "resonance_mage", "moon_wing", "blood_larva",
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
	e.set("current_hp", 999.0)
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
	label.text = "hurt reaction: 13 enemies"
	label.position = Vector2(16, 12)
	label.add_theme_color_override("font_color", Color(0.85, 0.78, 0.55))
	stage.add_child(label)

	var enemies: Array = []
	for i in range(IDS.size()):
		var e := _spawn(String(IDS[i]), Vector2(110 + (i % 6) * 200, 200 + (i / 6) * 200))
		if e != null:
			enemies.append(e)
	await create_timer(1.0).timeout

	var img_idle: Image = root.get_texture().get_image()
	img_idle.save_png("res://artifacts/iteration_assets/iter_hurt_idle_shot.png")
	print("挨打前截图: %s" % str(img_idle.get_size()))

	# 走真实受击路径：和被子弹打中同一条代码。
	var hurt_count := 0
	for e in enemies:
		if is_instance_valid(e):
			e.call("take_damage", 1.0)
			hurt_count += 1
	print("触发受击: %d / %d" % [hurt_count, enemies.size()])

	# 受击条 6 帧 12fps ≈ 0.5 秒。0.34 秒时命中特效已淡出、受击条还在踉跄段，
	# 早一点会被命中火花盖住，晚一点受击条已经快回待机了。
	await create_timer(0.34).timeout
	var img: Image = root.get_texture().get_image()
	img.save_png("res://artifacts/iteration_assets/iter_hurt_shot.png")
	print("受击中截图: %s" % str(img.get_size()))
	quit()
