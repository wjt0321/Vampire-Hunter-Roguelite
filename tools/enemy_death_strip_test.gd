extends SceneTree
## 12 种新敌人的专属死亡演出回归（2026-11-14 资产迭代）。
##
## 用法: godot --headless --path . --script res://tools/enemy_death_strip_test.gd
##
## 覆盖：
##   ① 12 种新敌人的专属死亡条都真的落盘，且是 6 帧横条（336×56）
##   ② 敌人死亡时切到专属死亡条并逐帧推进
##   ③ 播完才回收（不会一死就消失）
##
## 注意：--script 模式下 autoload 在编译期未注册，脚本里不能直接写单例名，
##       一律运行时 load()。

const Slots = preload("res://scripts/core/asset_slots.gd")
const SpriteSheetLib = preload("res://scripts/core/sprite_sheet.gd")

const NEW_ENEMIES: Array = [
	"shield_guard", "blood_priest", "web_weaver", "coffin_guard",
	"blood_hound", "furnace_golem", "burrower", "gem_leech",
	"lantern_wraith", "alchemist_pitcher", "resonance_mage", "moon_wing",
]

var _pass: int = 0
var _fail: int = 0
var _stage: Node2D = null


func _initialize() -> void:
	_run()


func _check(cond: bool, msg: String) -> void:
	if cond:
		_pass += 1
		print("  ✅ %s" % msg)
	else:
		_fail += 1
		print("  ❌ %s" % msg)


func _run() -> void:
	await process_frame
	# 敌人死亡会往 current_scene 里丢掉落物，没有主场景会直接报错中断 _die，
	# 所以这里搭一个空的 current_scene 当舞台。
	_stage = Node2D.new()
	get_root().add_child(_stage)
	current_scene = _stage
	await process_frame
	_test_assets_exist()
	await _test_death_performance()
	print("")
	print("通过 %d / 失败 %d" % [_pass, _fail])
	if _fail == 0:
		print("✅ 全部通过")
	else:
		print("❌ 失败 %d 项" % _fail)
	quit(0 if _fail == 0 else 1)


func _test_assets_exist() -> void:
	for enemy_id in NEW_ENEMIES:
		var tex: Texture2D = Slots.texture_at(Slots.enemy_path(enemy_id, "death"))
		if tex == null:
			_check(false, "%s 的专属死亡条已落盘" % enemy_id)
			continue
		var size := tex.get_size()
		var frames := SpriteSheetLib.frame_count(tex)
		_check(frames == 6 and size.x == 336.0 and size.y == 56.0,
			"%s 死亡条是 336×56 的 6 帧横条（实际 %s，%d 帧）" % [enemy_id, str(size), frames])


func _spawn(enemy_id: String) -> Node:
	var scene_path := "res://scenes/enemies/%s.tscn" % enemy_id
	if not ResourceLoader.exists(scene_path):
		return null
	var packed: PackedScene = load(scene_path)
	if packed == null:
		return null
	var node: Node = packed.instantiate()
	_stage.add_child(node)
	return node


func _wait(seconds: float) -> void:
	# 必须按真实时间等：headless 没有 vsync，按帧计数会几乎不流逝。
	await create_timer(seconds).timeout


func _test_death_performance() -> void:
	for enemy_id in NEW_ENEMIES:
		var enemy := _spawn(enemy_id)
		if enemy == null:
			_check(false, "%s 能被实例化" % enemy_id)
			continue
		await process_frame
		var sprite: Sprite2D = enemy.get_node_or_null("Sprite2D")
		if sprite == null:
			_check(false, "%s 有 Sprite2D 子节点" % enemy_id)
			continue
		enemy.call("_die")
		await process_frame
		# 棺卫第一次死亡是"倒下变棺材"，不是真死（可以被棺材打掉后起身）；
		# 死亡条要等棺材被毁、真正死透才播。所以这里先推进到最终死亡。
		if enemy.has_method("confirm_coffin_destroyed"):
			enemy.call("confirm_coffin_destroyed")
			await process_frame
		var switched := sprite.texture != null and SpriteSheetLib.frame_count(sprite.texture) == 6
		_check(switched, "%s 死亡时切到专属 6 帧死亡条" % enemy_id)
		await _wait(0.3)
		_check(sprite.frame > 0 or not is_instance_valid(enemy),
			"%s 死亡条帧会推进（当前第 %d 帧）" % [enemy_id, sprite.frame])
		# 6 帧 @8fps = 0.75s，再加 0.4s 淡出；1.0s 时还该活着
		await _wait(0.7)
		_check(is_instance_valid(enemy), "%s 播完前不会被立刻回收" % enemy_id)
		await _wait(1.0)
		_check(not is_instance_valid(enemy), "%s 播完后会自己回收" % enemy_id)
		if is_instance_valid(enemy):
			enemy.queue_free()
