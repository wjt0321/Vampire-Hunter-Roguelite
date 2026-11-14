extends Node
## 这一局的复盘。结算时给一段能读的摘要，不在战斗里偷偷改难度。

var damage_taken: float = 0.0
var rooms: Array = []
var build_events: Array = []
var shop_spent: int = 0
var shop_rerolls: int = 0
var carried_silver_notes: Array = []
var dealt_by_source: Dictionary = {}
var hit_by_source: Dictionary = {}
var last_kill_source: String = ""
var last_kill_target: String = ""
var last_hit_source: String = ""
var peaks: Dictionary = {}
var events: Array = []
var _room_started_ms: int = 0

func _ready() -> void:
	add_to_group("run_log")

func note_room(floor_index: int, room_type: String, variant_id: String, template_id: String) -> void:
	_close_room_timer()
	rooms.append({
		"floor": floor_index,
		"type": room_type,
		"variant": variant_id,
		"template": template_id,
		"ms": 0,
	})
	_room_started_ms = Time.get_ticks_msec()

func note_damage(amount: float) -> void:
	damage_taken += maxf(amount, 0.0)

func note_build(kind: String, detail: String) -> void:
	build_events.append("%s %s" % [kind, detail])
	if build_events.size() > 12:
		build_events.pop_front()

func note_shop(kind: String, amount: int) -> void:
	if kind == "reroll":
		shop_rerolls += 1
	shop_spent += maxi(amount, 0)

func note_silver_left(amount: int) -> void:
	carried_silver_notes.append(amount)

func note_dealt(source: String, amount: float) -> void:
	var key := source if source != "" else "攻击"
	dealt_by_source[key] = float(dealt_by_source.get(key, 0.0)) + maxf(amount, 0.0)

func note_hit(source: String, amount: float) -> void:
	var key := source if source != "" else "未知"
	hit_by_source[key] = float(hit_by_source.get(key, 0.0)) + maxf(amount, 0.0)
	last_hit_source = key

func note_kill(source: String, enemy_type: String) -> void:
	last_kill_source = source if source != "" else "攻击"
	last_kill_target = enemy_type

func note_peak(kind: String, amount: int) -> void:
	peaks[kind] = maxi(int(peaks.get(kind, 0)), amount)

func note_event(kind: String, success: bool) -> void:
	events.append("%s%s" % [kind, "完成" if success else "未完成"])
	if events.size() > 8:
		events.pop_front()

func summary() -> String:
	_close_room_timer()
	var lines: PackedStringArray = PackedStringArray()
	lines.append("复盘")
	if not build_events.is_empty():
		lines.append("构筑：" + "，".join(build_events))
	var top_source := _top_key(dealt_by_source)
	if top_source != "":
		lines.append("主要输出：%s %.0f" % [top_source, float(dealt_by_source[top_source])])
	if last_kill_target != "":
		lines.append("最后一击：%s 打死 %s" % [last_kill_source, last_kill_target])
	if last_hit_source != "":
		lines.append("最后受伤来自：%s" % last_hit_source)
		lines.append(_dodge_advice())
	var build_hint := _build_hint()
	if build_hint != "":
		lines.append(build_hint)
	var last_room := "无"
	if not rooms.is_empty():
		var room: Dictionary = rooms[rooms.size() - 1]
		last_room = "第 %d 层 %s" % [int(room.get("floor", 1)), String(room.get("type", ""))]
		if String(room.get("variant", "")) != "":
			last_room += "·" + String(room.get("variant", ""))
		if int(room.get("ms", 0)) > 0:
			last_room += " %.0f 秒" % (float(room.get("ms", 0)) / 1000.0)
	lines.append("最后一间：%s" % last_room)
	lines.append("商店花费 %d 银，重抽 %d 次" % [shop_spent, shop_rerolls])
	if not carried_silver_notes.is_empty():
		lines.append("离开商店时银币 %d" % int(carried_silver_notes[carried_silver_notes.size() - 1]))
	if not events.is_empty():
		lines.append("事件：" + "，".join(events))
	if int(peaks.get("enemies", 0)) > 0:
		lines.append("同屏敌人峰值 %d" % int(peaks.get("enemies", 0)))
	var unlock := _next_unlock_text()
	if unlock != "":
		lines.append(unlock)
	return "\n".join(lines)

func _close_room_timer() -> void:
	if rooms.is_empty() or _room_started_ms == 0:
		return
	rooms[rooms.size() - 1]["ms"] = Time.get_ticks_msec() - _room_started_ms
	_room_started_ms = 0

func _build_hint() -> String:
	var tree := get_tree()
	if tree == null:
		return ""
	var weapons := tree.get_first_node_in_group("weapon_manager")
	if weapons != null and weapons.has_method("next_build_hint"):
		return String(weapons.next_build_hint())
	return ""

func _dodge_advice() -> String:
	var ranged := ["skeleton", "skeleton_archer", "vampire_mage", "lantern_wraith", "alchemist_pitcher", "moon_wing", "resonance_mage", "blood_priest"]
	if last_hit_source in ranged:
		return "这一下是直线弹道，横向走开比站着打更有用"
	return "给自己留一条后退的路，别贴着%s" % last_hit_source

func _top_key(book: Dictionary) -> String:
	var best := ""
	var best_amount := 0.0
	for key in book.keys():
		var amount := float(book[key])
		if amount > best_amount:
			best = String(key)
			best_amount = amount
	return best

func _next_unlock_text() -> String:
	var saves := get_node_or_null("/root/SaveManager")
	if saves != null and saves.has_method("next_unlock_text"):
		return String(saves.next_unlock_text())
	return ""
