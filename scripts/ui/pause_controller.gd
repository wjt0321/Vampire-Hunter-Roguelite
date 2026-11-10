class_name PauseController
extends RefCounted
## 世界暂停的唯一入口：按持有者计数，而不是让每个面板直接写 get_tree().paused。
##
## 为什么需要它：升级三选一、局内商店、变异祭坛、血之祭坛、暂停菜单、结算页
## 六个面板原来各自 `get_tree().paused = true/false`。只要两个面板同时开着
## （升级选完立刻开商店、祭坛上叠暂停菜单），先关的那个就会把另一个的暂停解掉：
## 面板还挂在屏幕上，世界却已经在跑，玩家一边读卡一边被小怪打死。
##
## 规则：
##   - acquire(owner) 只登记，不假设自己是不是第一个
##   - release(owner) 只注销自己那一份；计数归零才真正恢复世界
##   - 同一个 owner 重复 acquire 只算一份（面板里 open() 被连调两次不该锁死）
##   - owner 先被 free 掉时自动注销（tree_exiting 兜底），不留永久暂停

## owner 实例 id -> owner。用 Dictionary 而不是数组：注销是 O(1)，
## 且天然按 id 去重（同一个面板 acquire 两次不会变成两份）。
static var _holders: Dictionary = {}
## 计数变化前的世界状态。用来在最后一个持有者释放时决定是否真的要恢复：
## 如果进面板之前世界本来就是暂停的（比如编辑器里手动暂停），不能替它解。
static var _restore_to: bool = false

static func acquire(owner) -> void:
	# 形参不标 Node：已释放的实例过不了 `Node` 的类型检查，
	# 会在调用点直接抛 "previously freed is not a subclass of Node"，
	# 根本走不到下面这行 is_instance_valid。面板被打断销毁时正好会撞上。
	if owner == null or not is_instance_valid(owner):
		return
	var id: int = owner.get_instance_id()
	if _holders.has(id):
		return
	_prune()
	if _holders.is_empty():
		_restore_to = _tree_paused()
	_holders[id] = owner
	# 用 bind 后的同一个 Callable 判重：is_connected 比的是 Callable 本身，
	# 拿未 bind 的 _on_owner_tree_exiting 去问永远是 false，
	# 于是"面板关了又开"会给同一个 owner 挂上第二条连接，退出时回调两次。
	var hook := _on_owner_tree_exiting.bind(owner)
	if not owner.tree_exiting.is_connected(hook):
		owner.tree_exiting.connect(hook)
	_apply()

static func release(owner) -> void:
	# 已释放的 Node 不是 null（is_instance_valid 才是 false），
	# 对它调 get_instance_id() 会打 "previously freed instance" 错误。
	# 面板被打断销毁时 release 照样可能被调用，这里必须挡住。
	if owner == null or not is_instance_valid(owner):
		return
	_holders.erase(owner.get_instance_id())
	_apply()

## 仅限"场景即将被销毁 / 整体重载"这类可以确认所有面板都会一起消失的时刻。
## 平时不要调：它会把别人正需要的暂停一起解掉，那正是这个类要防的事。
## 名字里带 scene_change 是刻意的——force_release_all 读起来像"随时清一下"，
## 谁都能顺手在某个面板里加一行，然后另一个面板的暂停就没了。
static func reset_for_scene_change() -> void:
	_holders.clear()
	_restore_to = false
	_set_tree_paused(false)

static func holder_count() -> int:
	_prune()
	return _holders.size()

static func is_held_by(owner) -> bool:
	if owner == null or not is_instance_valid(owner):
		return false
	return _holders.has(owner.get_instance_id())

static func holders() -> Array:
	_prune()
	return _holders.values()

# ---------------------------------------------------------------- 内部

static func _on_owner_tree_exiting(owner: Node) -> void:
	## 面板在持有期间被销毁（换场景、玩家死亡打断升级）时自动注销。
	## 不做这一步的话，那个面板会把世界永久锁在暂停里，玩家只能重启游戏。
	_holders.erase(owner.get_instance_id())
	_apply()

static func _prune() -> void:
	## 已被释放但没走到 tree_exiting 的残留（queue_free 后的同一帧查询）。
	## 摘除之后必须重新 _apply()：这些 owner 对应的是本该恢复的暂停，
	## 只从字典里抹掉不改世界状态的话，世界会停在一个"零持有者但还暂停"的死状态，
	## 直到下一次有人 acquire 才被顺带修正。
	var dead: Array = []
	for id in _holders:
		var owner: Variant = _holders[id]
		if owner == null or not is_instance_valid(owner):
			dead.append(id)
	if dead.is_empty():
		return
	for id in dead:
		_holders.erase(id)
	_apply()

static func _apply() -> void:
	## 有持有者 = 一定暂停；没有持有者 = 回到"第一个持有者进来之前"的状态。
	## 直接写 false 是不对的：进面板之前世界本来就是暂停的场合（编辑器手动暂停、
	## 结算页先暂停再叠面板）会被我们替它解掉。
	if _holders.is_empty():
		_set_tree_paused(_restore_to)
	else:
		_set_tree_paused(true)

static func _tree_paused() -> bool:
	var tree := _scene_tree()
	return tree != null and tree.paused

static func _set_tree_paused(value: bool) -> void:
	var tree := _scene_tree()
	if tree != null:
		tree.paused = value

static func _scene_tree() -> SceneTree:
	var loop := Engine.get_main_loop()
	return loop as SceneTree
