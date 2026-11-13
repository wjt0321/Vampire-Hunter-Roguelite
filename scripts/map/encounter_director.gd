extends RefCounted
## 按楼层选一小队，而不是每只怪单独抽。
## 同一模板不连续出现。第 1 层只有一种核心组合。

const TEMPLATES := {
	"shield_wall": {
		"title": "盾墙推进",
		"reward": "经验",
		"core": "盾卫",
		"spawns": [
			{"type": "shield_guard", "side": "front", "core": true},
			{"type": "zombie", "side": "front", "core": false},
			{"type": "skeleton_archer", "side": "back", "core": false},
		],
	},
	"crossfire": {
		"title": "交叉夹击",
		"reward": "银币",
		"core": "血猎犬",
		"spawns": [
			{"type": "blood_hound", "side": "left", "core": true},
			{"type": "burrower", "side": "right", "core": false},
			{"type": "zombie", "side": "front", "core": false},
		],
	},
	"summon_rite": {
		"title": "召唤仪式",
		"reward": "经验",
		"core": "召唤者",
		"spawns": [
			{"type": "shield_guard", "side": "front", "core": false},
			{"type": "zombie", "side": "front", "core": false},
			{"type": "blood_priest", "side": "back", "core": true},
		],
	},
	"web_line": {
		"title": "织网夹击",
		"reward": "银币",
		"core": "织网者",
		"spawns": [
			{"type": "web_weaver", "side": "back", "core": true},
			{"type": "zombie", "side": "front", "core": false},
			{"type": "burrower", "side": "left", "core": false},
		],
	},
	"crypt_line": {
		"title": "墓道转火",
		"reward": "经验",
		"core": "棺卫",
		"spawns": [
			{"type": "coffin_guard", "side": "front", "core": true},
			{"type": "gem_leech", "side": "back", "core": false},
			{"type": "lantern_wraith", "side": "right", "core": false},
		],
	},
	"blast_chain": {
		"title": "爆破链",
		"reward": "银币",
		"core": "自爆者",
		"spawns": [
			{"type": "exploder", "side": "front", "core": true},
			{"type": "zombie", "side": "front", "core": false},
			{"type": "alchemist_pitcher", "side": "back", "core": false},
		],
	},
	"elite_guard": {
		"title": "护卫精英",
		"reward": "银币",
		"core": "炉心傀儡",
		"spawns": [
			{"type": "furnace_golem", "side": "front", "core": true, "elite": true},
			{"type": "zombie", "side": "left", "core": false},
			{"type": "resonance_mage", "side": "back", "core": false},
		],
	},
	"moon_hunt": {
		"title": "月翼俯冲",
		"reward": "经验",
		"core": "月翼兽",
		"spawns": [
			{"type": "moon_wing", "side": "left", "core": true},
			{"type": "moon_wing", "side": "right", "core": false},
			{"type": "gargoyle", "side": "front", "core": false},
		],
	},
}

static func template_ids_for_floor(floor_index: int) -> Array:
	match floor_index:
		1:
			return ["shield_wall"]
		2:
			return ["shield_wall", "crossfire", "summon_rite", "web_line"]
		3:
			return ["crossfire", "summon_rite", "crypt_line", "web_line"]
		4:
			return ["blast_chain", "elite_guard", "summon_rite"]
		_:
			return ["moon_hunt", "crossfire", "elite_guard"]

static func plan(floor_index: int, previous_id: String, rng: RandomNumberGenerator = null) -> Dictionary:
	var options: Array = []
	for template_id in template_ids_for_floor(floor_index):
		if template_id != previous_id:
			options.append(template_id)
	if options.is_empty():
		options = template_ids_for_floor(floor_index)
	var index := 0
	if rng != null:
		index = rng.randi_range(0, options.size() - 1)
	else:
		index = randi() % options.size()
	var first := String(options[index])
	var spawns: Array = _copy_spawns(first, floor_index)
	var second := ""
	if floor_index >= 2 and floor_index <= 3 and options.size() > 1:
		second = String(options[(index + 1) % options.size()])
		if second != first:
			spawns.append_array(_copy_spawns(second, floor_index))
	var info: Dictionary = TEMPLATES[first]
	return {
		"id": first,
		"second": second,
		"title": info["title"],
		"reward": info["reward"],
		"core": info["core"],
		"spawns": spawns,
	}

static func _copy_spawns(template_id: String, floor_index: int) -> Array:
	var result: Array = []
	for entry in TEMPLATES[template_id]["spawns"]:
		var copy: Dictionary = entry.duplicate()
		if floor_index < 4:
			copy["elite"] = false
		result.append(copy)
	return result

static func covers_enemy(enemy_id: String) -> bool:
	for template_id in TEMPLATES.keys():
		for entry in TEMPLATES[template_id]["spawns"]:
			if String(entry["type"]) == enemy_id:
				return true
	return false
