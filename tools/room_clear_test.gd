extends SceneTree
## 换房清场回归：毒雾/药液不能飘进下一间房
## 用法：godot --headless --path . --script res://tools/room_clear_test.gd
##
## 为什么要单独测：上一轮的清理是写在 _transition_to_next_room() 里的一段
## for 循环，没有断言保护——删掉那三行也不会有任何测试变红，
## 而"效果会带到下一场景"正是用户实机反馈里的原话。

var _fail: int = 0

func _initialize() -> void:
	_run()

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ✅ %s" % msg)
	else:
		print("  ❌ %s" % msg)
		_fail += 1

func _run() -> void:
	await process_frame
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await create_timer(2.5).timeout

	# 房内先放一团毒雾
	var cloud = load("res://scenes/player/poison_cloud.tscn").instantiate()
	cloud.global_position = main.player.global_position
	main.add_child(cloud)
	await process_frame
	await process_frame

	var group := "ground_effects"
	var in_room := get_nodes_in_group(group).size()
	_check(in_room >= 1, "毒雾已挂进 ground_effects 组（房内 %d 个）" % in_room)

	# 换房
	main._transition_to_next_room()
	await create_timer(2.2).timeout

	var after := get_nodes_in_group(group).size()
	_check(after == 0, "换房后 ground_effects 已清空（剩 %d 个）" % after)

	# 换房之后新房间里还能再放（说明清理没有把功能打死）
	var cloud2 = load("res://scenes/player/poison_cloud.tscn").instantiate()
	cloud2.global_position = main.player.global_position
	main.add_child(cloud2)
	await process_frame
	await process_frame
	_check(get_nodes_in_group(group).size() >= 1, "新房间里仍能正常生成毒雾")

	print("")
	if _fail == 0:
		print("✅ 全部通过")
	else:
		print("❌ 失败 %d 项" % _fail)
	quit(0 if _fail == 0 else 1)
