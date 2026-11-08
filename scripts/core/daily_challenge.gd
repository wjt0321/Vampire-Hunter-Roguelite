extends RefCounted
class_name DailyChallenge
## 每日挑战（17.15）
##
## 同一 UTC 日期得到同一组词缀和同一颗地图种子。
## 种子只交给地下城房间序列和敌人种类/词缀，不锁暴击和走位——
## 否则排行榜比的是录像，不是同一套规则下谁走得更远。

static func today() -> String:
	var dt := Time.get_date_dict_from_system(true)
	return "%04d-%02d-%02d" % [int(dt.year), int(dt.month), int(dt.day)]

static func seed_for(date_key: String) -> int:
	## String.hash 在同一 Godot 版本里稳定。
	## 不要取绝对值：两个日期的哈希一正一负，取绝对值可能撞车。
	return int(date_key.hash())

static func build(date_key: String) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	var seed_value := seed_for(date_key)
	rng.seed = seed_value
	var pool: Array = []
	for entry in GameConfig.DAILY_MODIFIERS:
		pool.append(entry)
	var picked: Array = []
	for _i in range(mini(2, pool.size())):
		var index: int = rng.randi_range(0, pool.size() - 1)
		picked.append(pool[index])
		pool.remove_at(index)
	return {
		"date": date_key,
		"seed": seed_value,
		"modifiers": picked,
	}
