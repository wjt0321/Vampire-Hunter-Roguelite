extends SceneTree
## 敌人动态帧实况审计（问题6 定位用）。
##
## 逐个实例化敌人场景，看它在实机里到底有没有在动：
##   · sprite.hframes —— 一次显示几帧（1 = 完全没有动态帧）
##   · 0.6 秒内 sprite.frame 有没有变过 —— 变了才算真的在播
##   · 当前贴图尺寸 —— 用来判断贴的是横条还是单张
##
## 用法: godot --headless --path . --script res://tools/enemy_anim_audit.gd

const SCENES := {
	"vampire": "res://scenes/enemies/vampire.tscn",
	"werewolf": "res://scenes/enemies/werewolf.tscn",
	"bat": "res://scenes/enemies/bat.tscn",
	"zombie": "res://scenes/enemies/zombie.tscn",
	"skeleton_archer": "res://scenes/enemies/skeleton_archer.tscn",
	"exploder": "res://scenes/enemies/exploder.tscn",
	"gargoyle": "res://scenes/enemies/gargoyle.tscn",
	"vampire_mage": "res://scenes/enemies/vampire_mage.tscn",
	"summoner": "res://scenes/enemies/summoner.tscn",
	"vampire_prince": "res://scenes/enemies/vampire_prince.tscn",
	"elite_vampire": "res://scenes/enemies/elite_vampire.tscn",
	"shield_guard": "res://scenes/enemies/shield_guard.tscn",
	"blood_hound": "res://scenes/enemies/blood_hound.tscn",
	"blood_priest": "res://scenes/enemies/blood_priest.tscn",
	"web_weaver": "res://scenes/enemies/web_weaver.tscn",
	"burrower": "res://scenes/enemies/burrower.tscn",
	"gem_leech": "res://scenes/enemies/gem_leech.tscn",
	"coffin_guard": "res://scenes/enemies/coffin_guard.tscn",
	"lantern_wraith": "res://scenes/enemies/lantern_wraith.tscn",
	"alchemist_pitcher": "res://scenes/enemies/alchemist_pitcher.tscn",
	"furnace_golem": "res://scenes/enemies/furnace_golem.tscn",
	"resonance_mage": "res://scenes/enemies/resonance_mage.tscn",
	"moon_wing": "res://scenes/enemies/moon_wing.tscn",
	"blood_larva": "res://scenes/enemies/blood_larva.tscn",
}

var static_frames := 0
var moving := 0
var total := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	for id in SCENES.keys():
		var path: String = SCENES[id]
		if not ResourceLoader.exists(path):
			print("%-18s 场景不存在" % id)
			continue
		var scene: PackedScene = load(path)
		var enemy: Node = scene.instantiate()
		root.add_child(enemy)
		await process_frame
		await process_frame
		var sprite: Sprite2D = enemy.get_node_or_null("Sprite2D")
		if sprite == null:
			print("%-18s 没有 Sprite2D" % id)
			enemy.queue_free()
			continue
		var tex_size: Vector2 = sprite.texture.get_size() if sprite.texture != null else Vector2.ZERO
		var frame_a: int = sprite.frame
		await create_timer(0.6).timeout
		var frame_b: int = sprite.frame
		var animating: bool = sprite.hframes > 1 and frame_b != frame_a
		total += 1
		if animating:
			moving += 1
		else:
			static_frames += 1
		print("%-18s tex=%-10s hframes=%d  %s" % [
			id, str(tex_size), sprite.hframes, "在动" if animating else "★静止★"])
		enemy.queue_free()
		await process_frame
	print("--- 合计 %d 个敌人：在动 %d，静止 %d ---" % [total, moving, static_frames])
	quit(0)
