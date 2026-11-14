extends SceneTree
## 开发用：12 种新敌人的死亡演出截图（每种截一帧死亡中途的画面）
## 用法: godot --path . --script res://tools/enemy_death_shot.gd   （必须带窗口）
##
## 输出：artifacts/iteration_assets/death_shot.png（一张拼图）

const IDS: Array = [
	"shield_guard", "blood_priest", "web_weaver", "coffin_guard",
	"blood_hound", "furnace_golem", "burrower", "gem_leech",
	"lantern_wraith", "alchemist_pitcher", "resonance_mage", "moon_wing",
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

	var enemies: Array = []
	for i in range(IDS.size()):
		var e := _spawn(String(IDS[i]), Vector2(120 + (i % 6) * 110, 140 + (i / 6) * 150))
		if e != null:
			enemies.append(e)
	await create_timer(0.6).timeout

	# 全部处决，拍死亡演出进行到一半的画面
	for e in enemies:
		if is_instance_valid(e):
			e.call("_die")
	await create_timer(0.45).timeout

	var img: Image = root.get_texture().get_image()
	img.save_png("res://artifacts/iteration_assets/death_shot.png")
	print("死亡演出截图: %s" % str(img.get_size()))
	quit()
