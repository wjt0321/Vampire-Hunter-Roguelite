extends Node
## 通用对象池
## 复用频繁创建/销毁的游戏对象（子弹、经验宝石等），减少 GC 压力

var _pools: Dictionary = {}

func acquire(scene: PackedScene) -> Node:
	## 从对象池获取一个实例，池为空时创建新实例
	var key := scene.resource_path
	if _pools.has(key):
		var pool: Array = _pools[key]
		while pool.size() > 0:
			var node: Node = pool.pop_back()
			if is_instance_valid(node):
				node.visible = true
				node.process_mode = Node.PROCESS_MODE_INHERIT
				node.set_meta("_in_pool", false)
				if node is CollisionObject2D:
					node.monitoring = true
				return node
	return scene.instantiate()

func release(node: Node) -> void:
	## 将对象归还对象池，而非直接销毁
	if not is_instance_valid(node):
		return
	# 防止同一对象被重复归还
	if node.has_meta("_in_pool") and node.get_meta("_in_pool"):
		return
	var key := node.scene_file_path
	if key.is_empty():
		# 无场景路径的对象无法复用，直接释放
		node.queue_free()
		return
	
	node.set_meta("_in_pool", true)
	# 避免在物理回调中直接移除碰撞体，延迟到下一帧处理
	if node is CollisionObject2D:
		node.set_deferred("monitoring", false)
	call_deferred("_do_release", node, key)

func _do_release(node: Node, key: String) -> void:
	if not is_instance_valid(node):
		return
	if node.get_parent():
		node.get_parent().remove_child(node)
	
	if node.has_method("reset_for_pool"):
		node.reset_for_pool()
	
	node.visible = false
	node.process_mode = Node.PROCESS_MODE_DISABLED
	
	if not _pools.has(key):
		_pools[key] = []
	_pools[key].append(node)

func clear_pool(scene: PackedScene) -> void:
	## 清空指定场景的池
	var key := scene.resource_path
	if not _pools.has(key):
		return
	for node in _pools[key]:
		if is_instance_valid(node):
			node.queue_free()
	_pools.erase(key)

func clear_all() -> void:
	## 清空所有对象池
	for key in _pools:
		for node in _pools[key]:
			if is_instance_valid(node):
				node.queue_free()
	_pools.clear()
