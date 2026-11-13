extends Node
## 这一局的复盘。结算时给一段能读的摘要，不在战斗里偷偷改难度。

var damage_taken: float = 0.0
var rooms: Array = []
var build_events: Array = []
var shop_spent: int = 0
var shop_rerolls: int = 0
var carried_silver_notes: Array = []

func _ready() -> void:
	add_to_group("run_log")

func note_room(floor_index: int, room_type: String, variant_id: String, template_id: String) -> void:
	rooms.append({
		"floor": floor_index,
		"type": room_type,
		"variant": variant_id,
		"template": template_id,
	})

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

func summary() -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("复盘")
	if not build_events.is_empty():
		lines.append("构筑：" + "，".join(build_events))
	var last_room := "无"
	if not rooms.is_empty():
		var room: Dictionary = rooms[rooms.size() - 1]
		last_room = "第 %d 层 %s" % [int(room.get("floor", 1)), String(room.get("type", ""))]
		if String(room.get("variant", "")) != "":
			last_room += "·" + String(room.get("variant", ""))
	lines.append("最后一间：%s" % last_room)
	lines.append("商店花费 %d 银，重抽 %d 次" % [shop_spent, shop_rerolls])
	if not carried_silver_notes.is_empty():
		lines.append("离开商店时银币 %d" % int(carried_silver_notes[carried_silver_notes.size() - 1]))
	return "\n".join(lines)
