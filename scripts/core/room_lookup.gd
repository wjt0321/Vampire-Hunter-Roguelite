class_name RoomLookup
extends RefCounted
## 统一解析"当前战斗房间"节点与房间边界。
##
## 历史坑（"怪刷在地图边界外"的根因）：
## player 和 enemy 的父节点都是 Main（主场景根），**不是**房间。
## 旧代码写 `var room := player.get_parent()` 把它当房间用，
## 于是 `room.has_method("get_room_bounds")` 恒为 false →
## 整段边界钳制被**静默跳过**（不报错、不报警），刷怪点完全不受房间约束。
##
## 同一个坑复制在三处：
##   scripts/managers/wave_manager.gd   刷怪 / 增益落点越界
##   scripts/enemies/vampire_mage.gd    瞬移出界
##   scripts/weapons/weapon_manager.gd  子弹射程按 800 兜底（房间实际对角线 ~1900）
##
## 本文件是唯一的房间解析入口。

## 找带 get_room_bounds 的房间节点。找不到返回 null。
##
## from 通常传玩家或敌人节点。解析顺序：
##   1) from 的父链上如果有房间节点（房间被 reparent 过也能找到）
##   2) from 的父节点下的 GameRoom（main._create_room 动态创建，名字固定）
##   3) 当前场景下的 GameRoom
##   4) 当前场景的直接子节点里带 get_room_bounds 的
static func find_room(from: Node) -> Node:
	if from == null or not is_instance_valid(from):
		return null

	# 1) 父链
	var p: Node = from
	while p != null and is_instance_valid(p):
		if p.has_method("get_room_bounds"):
			return p
		p = p.get_parent()

	var roots: Array[Node] = []
	var pp := from.get_parent()
	if pp != null and is_instance_valid(pp):
		roots.append(pp)

	# 2) 当前场景
	var tree := from.get_tree()
	if tree != null:
		var scene := tree.current_scene
		if scene != null and is_instance_valid(scene) and not roots.has(scene):
			roots.append(scene)

	for root in roots:
		var room := root.get_node_or_null("GameRoom")
		if room != null and room.has_method("get_room_bounds"):
			return room
		for child in root.get_children():
			if child.has_method("get_room_bounds"):
				return child
	return null


## 房间内部的**全局**矩形（已扣掉墙厚）。找不到房间返回空矩形。
static func bounds_global(room: Node) -> Rect2:
	if room == null or not is_instance_valid(room):
		return Rect2()
	if not room.has_method("get_room_bounds"):
		return Rect2()
	var bounds: Rect2 = room.get_room_bounds()
	# bounds 是房间本地坐标；房间自身不在原点时要先转全局，
	# 否则又变成"拿本地 rect 去钳全局坐标"。
	if room is Node2D:
		bounds = Rect2((room as Node2D).to_global(bounds.position), bounds.size)
	return bounds


## 把全局坐标钳回房间内部。margin 是离墙的最小距离。
## 找不到房间时原样返回（不猜边界，宁可不动也不钳到错的地方）。
static func clamp_into_room(pos: Vector2, margin: float, from: Node) -> Vector2:
	var room := find_room(from)
	if room == null:
		return pos
	return clamp_into_bounds(pos, margin, bounds_global(room))


## 用现成的房间矩形钳制。区间反向时（房间比 2*margin 还小）退回房间中心。
static func clamp_into_bounds(pos: Vector2, margin: float, bounds: Rect2) -> Vector2:
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return pos
	var lo_x := bounds.position.x + margin
	var hi_x := bounds.end.x - margin
	var lo_y := bounds.position.y + margin
	var hi_y := bounds.end.y - margin
	if hi_x < lo_x:
		lo_x = bounds.get_center().x
		hi_x = lo_x
	if hi_y < lo_y:
		lo_y = bounds.get_center().y
		hi_y = lo_y
	return Vector2(
		clampf(pos.x, lo_x, hi_x),
		clampf(pos.y, lo_y, hi_y)
	)
