extends SceneTree
## 开发用：旧 MVP 11 种敌人的实机截图（待机 + 死亡演出各一张）。
##
## 这些敌人的资产本轮全部换成了新风格（暗钢+旧金+深红），
## 这张图就是验收证据：看得出跟迭代新增的 12 种敌人是同一套美术。
##
## 用法: godot --path . --script res://tools/legacy_enemy_shot.gd   （必须带窗口）
##
## 输出：artifacts/iteration_assets/legacy_enemy_shot.png

const IDS: Array = [
	"vampire", "werewolf", "zombie", "bat", "skeleton_archer", "exploder",
	"gargoyle", "vampire_mage", "summoner", "vampire_prince", "elite_vampire",
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

	var enemies: Array = []
	for i in range(IDS.size()):
		var e := _spawn(String(IDS[i]), Vector2(110 + (i % 6) * 105, 150 + (i / 6) * 170))
		if e != null:
			enemies.append(e)
	await create_timer(1.2).timeout

	# 待机：先拍一张
	var img: Image = root.get_texture().get_image()
	img.save_png("res://artifacts/iteration_assets/legacy_enemy_idle.png")
	print("待机截图: %s" % str(img.get_size()))

	# 全部处决，拍死亡演出进行到一半的画面
	for e in enemies:
		if is_instance_valid(e):
			e.call("_die")
	await create_timer(0.5).timeout

	var img2: Image = root.get_texture().get_image()
	img2.save_png("res://artifacts/iteration_assets/legacy_enemy_shot.png")
	print("死亡演出截图: %s" % str(img2.get_size()))
	quit()
