extends SceneTree
## 敌人受击（hurt）动态帧的回归：2026-11-14 补齐这一轮。
##
## 覆盖：
##   ① 13 个敌人（12 个迭代新增 + 血铠幼虫）都有专属受击条，6 帧且相邻帧真的不同
##   ② asset_slots 的 ENEMIES 登记表里 13 个敌人都有 hurt 状态
##   ③ enemy_base 真的在受击路径上请求受击条（take_damage → _trigger_hurt_reaction）
##   ④ 运行时：挨打一下会切到受击条，播完自动回待机条
##   ⑤ 运行时：连击不会把受击条一遍遍从头播（否则敌人像在原地抽搐）
##   ⑥ 运行时：致死一击走死亡条，不会卡在受击条上
##   ⑦ 运行时：没有受击条的敌人不崩，play_hurt_strip 返回 false
##
## 用法: godot --headless --path . --script res://tools/iter_hurt_test.gd

const AssetSlots = preload("res://scripts/core/asset_slots.gd")
const Sheet = preload("res://scripts/core/sprite_sheet.gd")

const ENEMY_ROOT := "res://assets/sprites/enemies"

## 本轮补受击条的 13 个敌人
const HURT_ENEMIES: Array = [
	"shield_guard", "blood_hound", "blood_priest", "web_weaver", "burrower",
	"gem_leech", "coffin_guard", "lantern_wraith", "alchemist_pitcher",
	"furnace_golem", "resonance_mage", "moon_wing", "blood_larva",
]

## 没有受击条的敌人（旧 MVP 敌人，只做了待机/死亡），用来验「缺文件不崩」
const NO_HURT_ENEMY := "vampire"

var _fail: int = 0
var _pass: int = 0
var _stage: Node2D = null


func _initialize() -> void:
	_run()


func _check(ok: bool, label: String) -> void:
	if ok:
		_pass += 1
		print("✅ %s" % label)
	else:
		_fail += 1
		print("❌ %s" % label)


func _strip_path(enemy_id: String, state: String) -> String:
	return "%s/%s/%s.png" % [ENEMY_ROOT, enemy_id, state]


func _load_tex(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


func _frame_diff(img: Image, idx_a: int, idx_b: int, cell: int) -> float:
	var diff := 0
	for y in cell:
		for x in cell:
			var a := img.get_pixel(idx_a * cell + x, y)
			var b := img.get_pixel(idx_b * cell + x, y)
			if absf(a.r - b.r) > 0.12 or absf(a.g - b.g) > 0.12 or absf(a.b - b.b) > 0.12:
				diff += 1
	return float(diff) / float(cell * cell)


func _read_script(file_name: String) -> String:
	var path := "res://scripts/enemies/%s" % file_name
	if not FileAccess.file_exists(path):
		return ""
	return FileAccess.get_file_as_string(path)


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


func _sprite_of(enemy: Node) -> Sprite2D:
	if enemy == null:
		return null
	var s = enemy.get("sprite")
	if s is Sprite2D:
		return s
	return null


func _tex_path(sprite: Sprite2D) -> String:
	if sprite == null or sprite.texture == null:
		return ""
	return str(sprite.texture.resource_path)


func _run() -> void:
	await process_frame
	# 敌人死亡会往 current_scene 里丢掉落物，没有主场景会直接报错中断 _die，
	# 所以这里搭一个空的 current_scene 当舞台。
	_stage = Node2D.new()
	get_root().add_child(_stage)
	current_scene = _stage
	await process_frame

	await _test_assets()
	await _test_registry()
	await _test_wiring()
	await _test_runtime()
	await _test_no_replay()
	await _test_death_wins()
	await _test_missing_file()

	print("\n通过 %d / 失败 %d" % [_pass, _fail])
	if _fail == 0:
		print("✅ 全部通过")
	else:
		print("❌ 有 %d 项没过" % _fail)
	quit(0 if _fail == 0 else 1)


func _test_assets() -> void:
	print("\n====== 13 个敌人的受击条 ======")
	for enemy_id in HURT_ENEMIES:
		var path := _strip_path(enemy_id, "hurt")
		var tex := _load_tex(path)
		if tex == null:
			_check(false, "%s/hurt 受击条已落盘" % enemy_id)
			continue
		_check(true, "%s/hurt 受击条已落盘" % enemy_id)
		var size := tex.get_size()
		_check(size.x == 336.0 and size.y == 56.0,
			"%s/hurt 是 336×56 的横条（实际 %s）" % [enemy_id, str(size)])
		var frames := Sheet.frame_count(tex)
		_check(frames == 6, "%s/hurt 是 6 帧（实际 %d）" % [enemy_id, frames])
		if frames != 6:
			continue
		var img := tex.get_image()
		var min_diff := 1.0
		for i in range(frames - 1):
			min_diff = minf(min_diff, _frame_diff(img, i, i + 1, 56))
		_check(min_diff > 0.03, "%s/hurt 相邻帧确实不同（最小差异 %.1f%%）" % [
			enemy_id, min_diff * 100.0])


func _test_registry() -> void:
	print("\n====== asset_slots 登记表 ======")
	for enemy_id in HURT_ENEMIES:
		var states: Array = AssetSlots.ENEMIES.get(enemy_id, {}).get("states", [])
		_check(states.has("hurt"), "%s 的登记表里有 hurt" % enemy_id)


func _test_wiring() -> void:
	print("\n====== 受击接线 ======")
	var base := _read_script("enemy_base.gd")
	_check(base.contains("func play_hurt_strip("), "enemy_base 提供 play_hurt_strip")
	_check(base.contains("func _trigger_hurt_reaction("), "enemy_base 提供 _trigger_hurt_reaction")
	_check(base.contains("_trigger_hurt_reaction()"), "受击路径真的调了 _trigger_hurt_reaction")
	_check(base.contains('get_enemy_texture(enemy_id, "hurt")'), "受击条按 hurt 状态取图")
	var sheet := FileAccess.get_file_as_string("res://scripts/core/sprite_sheet.gd")
	_check(sheet.contains("func advance(sprite: Sprite2D, wait: float, delta: float, fps"),
		"advance 支持自定义帧率")
	_check(sheet.contains("func advance_once(sprite: Sprite2D, wait: float, delta: float, fps"),
		"advance_once 支持自定义帧率")


func _test_runtime() -> void:
	print("\n====== 运行时：挨打会切到受击条 ======")
	var enemy := _spawn("shield_guard")
	if enemy == null:
		_check(false, "盾卫能实例化")
		return
	enemy.set("current_hp", 999.0)
	await process_frame
	var sprite := _sprite_of(enemy)
	_check(sprite != null, "盾卫有精灵节点")
	if sprite == null:
		return
	var idle_path := _tex_path(sprite)
	enemy.call("take_damage", 1.0)
	await process_frame
	var hurt_path := _tex_path(sprite)
	_check(hurt_path.ends_with("hurt.png"), "挨打后切到受击条（实际 %s）" % hurt_path)
	_check(sprite.hframes == 6, "受击条是 6 帧（实际 %d）" % sprite.hframes)
	# 等受击条播完（6 帧 ÷ 12fps ≈ 0.5 秒）
	await create_timer(0.8).timeout
	var back_path := _tex_path(sprite)
	_check(not back_path.ends_with("hurt.png"), "受击条播完自动回待机（实际 %s）" % back_path)
	_check(back_path == idle_path, "回到的就是原来那张待机图")


func _test_no_replay() -> void:
	print("\n====== 运行时：连击不会反复从头播 ======")
	var enemy := _spawn("blood_hound")
	if enemy == null:
		_check(false, "血犬能实例化")
		return
	enemy.set("current_hp", 999.0)
	await process_frame
	var sprite := _sprite_of(enemy)
	if sprite == null:
		_check(false, "血犬有精灵节点")
		return
	enemy.call("take_damage", 1.0)
	await create_timer(0.22).timeout
	var frame_before := sprite.frame
	enemy.call("take_damage", 1.0)
	await process_frame
	_check(sprite.frame >= frame_before,
		"连击没有把受击条打回第一帧（之前第 %d 帧，现在第 %d 帧）" % [frame_before, sprite.frame])


func _test_death_wins() -> void:
	print("\n====== 运行时：致死一击走死亡条 ======")
	var enemy := _spawn("gem_leech")
	if enemy == null:
		_check(false, "宝石水蛭能实例化")
		return
	enemy.set("current_hp", 1.0)
	await process_frame
	var sprite := _sprite_of(enemy)
	if sprite == null:
		_check(false, "宝石水蛭有精灵节点")
		return
	enemy.call("take_damage", 999.0)
	await process_frame
	var path := _tex_path(sprite)
	_check(path.ends_with("death.png"), "致死一击直接走死亡条（实际 %s）" % path)
	_check(not path.ends_with("hurt.png"), "致死一击不会卡在受击条上")


func _test_missing_file() -> void:
	print("\n====== 没有受击条也不崩 ======")
	var enemy := _spawn(NO_HURT_ENEMY)
	if enemy == null:
		_check(false, "%s 能实例化" % NO_HURT_ENEMY)
		return
	enemy.set("current_hp", 999.0)
	await process_frame
	var sprite := _sprite_of(enemy)
	var before := _tex_path(sprite)
	var played: bool = enemy.call("play_hurt_strip")
	_check(played == false, "缺受击条时 play_hurt_strip 返回 false")
	enemy.call("take_damage", 1.0)
	await process_frame
	_check(is_instance_valid(enemy), "缺受击条时挨打不会崩")
	_check(not _tex_path(sprite).ends_with("hurt.png"),
		"缺受击条时不会换上不存在的贴图")
	_check(_tex_path(sprite) == before, "缺受击条时精灵保持原样")
