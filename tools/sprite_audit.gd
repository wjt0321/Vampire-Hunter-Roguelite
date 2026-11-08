extends SceneTree
## 敌人精灵尺寸审计
## 实例化每种敌人，读取 Sprite2D 的纹理尺寸 × scale，找出实际渲染尺寸异常的敌人。
## 用法: godot --headless --path . --script res://tools/sprite_audit.gd

const SCENES := {
	"bat": "res://scenes/enemies/bat.tscn",
	"vampire": "res://scenes/enemies/vampire.tscn",
	"zombie": "res://scenes/enemies/zombie.tscn",
	"werewolf": "res://scenes/enemies/werewolf.tscn",
	"skeleton_archer": "res://scenes/enemies/skeleton_archer.tscn",
	"exploder": "res://scenes/enemies/exploder.tscn",
	"elite_vampire": "res://scenes/enemies/elite_vampire.tscn",
	"summoner": "res://scenes/enemies/summoner.tscn",
	"vampire_mage": "res://scenes/enemies/vampire_mage.tscn",
	"gargoyle": "res://scenes/enemies/gargoyle.tscn",
	"vampire_prince": "res://scenes/enemies/vampire_prince.tscn",
	"vampire_lord": "res://scenes/enemies/vampire_lord.tscn",
}

## 屏幕 1280x720，超过这个像素数就算异常
const MAX_REASONABLE_PX := 160.0

func _initialize() -> void:
	await process_frame

	var root_node := Node2D.new()
	get_root().add_child(root_node)

	print("")
	print("================ 敌人精灵尺寸审计 ================")
	print("场景              纹理尺寸      scale        实际像素")
	print("--------------------------------------------------")

	var bad: Array[String] = []

	for key in SCENES.keys():
		var path: String = SCENES[key]
		if not ResourceLoader.exists(path):
			print("%-16s [场景不存在]" % key)
			continue

		var inst = load(path).instantiate()
		root_node.add_child(inst)
		await process_frame
		await process_frame

		var sprite: Sprite2D = inst.get_node_or_null("Sprite2D")
		if sprite == null:
			print("%-16s [没有 Sprite2D]" % key)
			inst.queue_free()
			continue

		var tex_size := Vector2.ZERO
		if sprite.texture:
			tex_size = sprite.texture.get_size()
		var rendered := Vector2(tex_size.x * absf(sprite.scale.x), tex_size.y * absf(sprite.scale.y))
		var worst: float = maxf(rendered.x, rendered.y)

		var flag := ""
		if worst > MAX_REASONABLE_PX:
			flag = "  <== 异常！"
			bad.append(key)
		elif worst < 20.0:
			flag = "  <== 过小"

		print("%-16s %5dx%-5d %-12s %6.1fx%-6.1f%s" % [
			key, int(tex_size.x), int(tex_size.y),
			"(%.4f,%.4f)" % [sprite.scale.x, sprite.scale.y],
			rendered.x, rendered.y, flag
		])

		inst.queue_free()
		await process_frame

	print("--------------------------------------------------")
	if bad.is_empty():
		print("结论: 没有发现尺寸异常")
	else:
		print("结论: 以下敌人渲染尺寸异常 -> %s" % str(bad))
	print("==================================================")
	print("")

	root_node.queue_free()
	quit()
