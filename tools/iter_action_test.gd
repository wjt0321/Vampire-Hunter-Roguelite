extends SceneTree
## 迭代新增敌人专属动作条 + 血铠幼虫这一轮的回归：
##  · 12 个新增敌人各有一条专属行为动作条，6 帧且相邻帧真的不同
##  · 血铠幼虫有全套专属资产（idle / pounce / death），不再是借蝙蝠染色的占位图
##  · 动作条都接在行为触发点上（脚本里确实调了 play_action_strip）
##  · asset_slots 的 ENEMIES 登记表与磁盘上的状态一致
##
## 用法: godot --headless --path . --script res://tools/iter_action_test.gd

const AssetSlots = preload("res://scripts/core/asset_slots.gd")
const Sheet = preload("res://scripts/core/sprite_sheet.gd")

const ENEMY_ROOT := "res://assets/sprites/enemies"

## 敌人 -> 本轮新增的动作条状态名
const ACTION_STRIPS := {
	"shield_guard": "guard",
	"blood_hound": "pounce",
	"blood_priest": "cast",
	"web_weaver": "cast",
	"burrower": "burrow",
	"gem_leech": "steal",
	"coffin_guard": "revive",
	"lantern_wraith": "beam",
	"alchemist_pitcher": "throw",
	"furnace_golem": "charge",
	"resonance_mage": "cast",
	"moon_wing": "dive",
}

## 每个动作条接在哪个敌人脚本里（读文件确认真的接了）
const WIRING := {
	"shield_guard": "shield_guard.gd",
	"blood_hound": "blood_hound.gd",
	"blood_priest": "blood_priest.gd",
	"web_weaver": "web_weaver.gd",
	"burrower": "burrower.gd",
	"gem_leech": "gem_leech.gd",
	"coffin_guard": "coffin_guard.gd",
	"lantern_wraith": "lantern_wraith.gd",
	"alchemist_pitcher": "alchemist_pitcher.gd",
	"furnace_golem": "furnace_golem.gd",
	"resonance_mage": "resonance_mage.gd",
	"moon_wing": "moon_wing.gd",
	"blood_larva": "blood_larva.gd",
}

var _fail: int = 0
var _pass: int = 0


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


func _run() -> void:
	print("\n====== 12 个新增敌人的专属动作条 ======")
	for enemy_id in ACTION_STRIPS.keys():
		var state: String = ACTION_STRIPS[enemy_id]
		var path := _strip_path(enemy_id, state)
		var tex := _load_tex(path)
		if tex == null:
			_check(false, "%s/%s 有专属动作条" % [enemy_id, state])
			continue
		_check(true, "%s/%s 有专属动作条" % [enemy_id, state])
		var size := tex.get_size()
		_check(size.y == 56.0, "%s/%s 单格高 56（实际 %d）" % [enemy_id, state, int(size.y)])
		var frames := Sheet.frame_count(tex)
		_check(frames == 6, "%s/%s 是 6 帧（实际 %d）" % [enemy_id, state, frames])
		if frames != 6:
			continue
		var img := tex.get_image()
		var min_diff := 1.0
		for i in range(frames - 1):
			min_diff = minf(min_diff, _frame_diff(img, i, i + 1, 56))
		_check(min_diff > 0.03, "%s/%s 相邻帧确实不同（最小差异 %.1f%%）" % [
			enemy_id, state, min_diff * 100.0])

	print("\n====== 血铠幼虫全套专属资产 ======")
	for state in ["idle", "pounce", "death"]:
		var tex := _load_tex(_strip_path("blood_larva", state))
		if tex == null:
			_check(false, "blood_larva/%s 有专属精灵条" % state)
			continue
		_check(true, "blood_larva/%s 有专属精灵条" % state)
		var size := tex.get_size()
		_check(size.y == 56.0, "blood_larva/%s 单格高 56（实际 %d）" % [state, int(size.y)])
		_check(Sheet.frame_count(tex) >= 4, "blood_larva/%s 帧数能被识别（实际 %d）" % [
			state, Sheet.frame_count(tex)])
	var larva_script := _read_script("blood_larva.gd")
	_check(not larva_script.contains('use_placeholder_sprite("bat"'),
		"blood_larva 不再借蝙蝠飞帧染色")
	_check(larva_script.contains('use_dedicated_sprite("blood_larva"'),
		"blood_larva 用自己的专属 idle")

	print("\n====== 接线点真的接上了 ======")
	for enemy_id in WIRING.keys():
		var src := _read_script(WIRING[enemy_id])
		if src.is_empty():
			_check(false, "%s 脚本可读" % WIRING[enemy_id])
			continue
		var state: String = ACTION_STRIPS.get(enemy_id, "pounce")
		_check(src.contains('play_action_strip("%s", "%s"' % [enemy_id, state]),
			"%s 调了 play_action_strip(%s, %s)" % [enemy_id, enemy_id, state])

	print("\n====== asset_slots 登记表与磁盘一致 ======")
	for enemy_id in ACTION_STRIPS.keys():
		var entry: Dictionary = AssetSlots.ENEMIES.get(enemy_id, {})
		var states: Array = entry.get("states", [])
		_check(states.has(ACTION_STRIPS[enemy_id]),
			"%s 的登记表里有 %s" % [enemy_id, ACTION_STRIPS[enemy_id]])
	var larva_states: Array = AssetSlots.ENEMIES.get("blood_larva", {}).get("states", [])
	for state in ["idle", "pounce", "death"]:
		_check(larva_states.has(state), "blood_larva 的登记表里有 %s" % state)

	print("\n====== play_action_strip 缺文件时不崩 ======")
	var base_script := _read_script("enemy_base.gd")
	_check(base_script.contains("func play_action_strip("), "enemy_base 提供 play_action_strip")
	_check(base_script.contains("return false"), "play_action_strip 缺文件时返回 false 而不是崩")

	print("\n通过 %d / 失败 %d" % [_pass, _fail])
	if _fail == 0:
		print("✅ 全部通过")
	else:
		print("❌ 有 %d 项没过" % _fail)
	quit(0 if _fail == 0 else 1)
