extends SceneTree
## 经验宝石回归测试
##
## 覆盖：菱形贴图 / 三档尺寸颜色 / 加色材质 / 30px 合并 / 不跨距离合并 /
##       不抢已被吸附的宝石 / 对象池重置 / 拾取时 tween 不与呼吸动画打架
##
## 用法: godot --headless --path . --script res://tools/xp_gem_test.gd
##
## 注意：不能用 `ProjectileVisuals.xxx` 这种静态引用——`--script` 模式下本脚本
## 在 autoload 注册前编译，静态引用会把整条依赖链拖进编译并全部失败。

var _pass: int = 0
var _fail: int = 0
var _visuals = null
var _gem_scene: PackedScene = null

func _initialize() -> void:
	_run()

func _check(ok: bool, label: String) -> void:
	if ok:
		_pass += 1
		print("✅ %s" % label)
	else:
		_fail += 1
		print("❌ %s" % label)

func _vis():
	if _visuals == null:
		_visuals = load("res://scripts/core/projectile_visuals.gd")
	return _visuals

func _spawn(pos: Vector2, value: int) -> Area2D:
	var gem := _gem_scene.instantiate() as Area2D
	gem.position = pos
	gem.xp_value = value
	current_scene.add_child(gem)
	gem.set_physics_process(false)   # 冻结吸附，避免测试过程中宝石被吸走
	return gem

func _run() -> void:
	await process_frame
	_gem_scene = load("res://scenes/player/xp_gem.tscn")

	# 需要一个 current_scene 当父节点
	var host := Node2D.new()
	root.add_child(host)
	current_scene = host

	print("\n=== 1. 贴图 ===")
	var tex: Texture2D = _vis().get_gem_texture()
	_check(tex != null and tex.get_size() == Vector2(48, 48), "菱形贴图 48x48（%s）" % str(tex.get_size() if tex else null))
	var img: Image = tex.get_image()
	_check(img.get_pixel(24, 24).a > 0.9, "宝石中心不透明（a=%.2f）" % img.get_pixel(24, 24).a)
	_check(img.get_pixel(1, 1).a < 0.02, "四角透明（不是方块）(a=%.2f)" % img.get_pixel(1, 1).a)
	var mid: Color = img.get_pixel(24, 24)
	var edge: Color = img.get_pixel(24, 20)
	_check(mid.r >= edge.r - 0.01, "中心比边缘亮（%.2f ≥ %.2f）" % [mid.r, edge.r])

	print("\n=== 2. 三档尺寸与颜色 ===")
	var cases := [
		{"value": 3, "size": 14.0, "name": "小怪"},
		{"value": 12, "size": 19.0, "name": "中怪"},
		{"value": 25, "size": 26.0, "name": "精英"},
		{"value": 100, "size": 26.0, "name": "Boss"},
	]
	var gems: Array = []
	for c in cases:
		var g := _spawn(Vector2(400 + gems.size() * 120, 200), int(c["value"]))
		gems.append(g)
		await process_frame
		var spr := g.get_node("Sprite2D") as Sprite2D
		var expect_scale: float = float(c["size"]) / 48.0
		# 呼吸 tween 会在此刻把 scale 拉到 base*(1+pulse) 之间，所以给一个区间
		_check(spr.scale.x >= expect_scale - 0.001 and spr.scale.x <= expect_scale * 1.20,
			"%s（%d XP）基准尺寸 %.0fpx，实际缩放 %.3f（基准 %.3f）"
			% [c["name"], int(c["value"]), float(c["size"]), spr.scale.x, expect_scale])
		_check(spr.material is CanvasItemMaterial
			and (spr.material as CanvasItemMaterial).blend_mode == CanvasItemMaterial.BLEND_MODE_ADD,
			"%s 使用加色材质" % c["name"])

	var green: Color = (gems[0].get_node("Sprite2D") as Sprite2D).modulate
	var blue: Color = (gems[1].get_node("Sprite2D") as Sprite2D).modulate
	var gold: Color = (gems[2].get_node("Sprite2D") as Sprite2D).modulate
	_check(green.g > green.b and green.g > green.r, "小怪档偏绿 %s" % str(green))
	_check(blue.b > blue.r and blue.g > blue.r, "中怪档偏蓝 %s" % str(blue))
	_check(gold.r > gold.b and gold.g > gold.b, "精英档偏金 %s" % str(gold))

	print("\n=== 3. 合并 ===")
	for g in [gems[0], gems[1], gems[2], gems[3]]:
		g.queue_free()
	await process_frame

	var base := _spawn(Vector2(200, 400), 3)
	await process_frame
	for i in range(4):
		_spawn(Vector2(200, 400) + Vector2(float(i - 2) * 6.0, 4.0), 3)
	await process_frame
	var alive: Array = get_nodes_in_group("xp_gems")
	var total: int = 0
	for g in alive:
		total += int(g.xp_value)
	_check(alive.size() == 1, "5 枚挤在 8px 内合并成 1 枚（实际 %d 枚）" % alive.size())
	_check(total == 15, "合并后经验累加为 15（实际 %d）" % total)
	var survivor: Area2D = alive[0]
	var merged_scale: float = (survivor.get_node("Sprite2D") as Sprite2D).scale.x
	_check(merged_scale > 19.0 / 48.0, "合并后档位升级（缩放 %.3f > 蓝档 0.396）" % merged_scale)

	# 距离外的不能合并
	var far := _spawn(Vector2(200 + 120, 400), 3)
	await process_frame
	_check(int(far.xp_value) == 3, "120px 外的宝石不参与合并（自身仍为 %d）" % int(far.xp_value))
	_check(int(survivor.xp_value) == 15, "远处掉落不影响已有宝石（%d）" % int(survivor.xp_value))

	# 已被吸附的不抢：先摆一枚标记为被吸附，再在旁边掉一枚新的
	var attracted := _spawn(Vector2(600, 400), 7)
	await process_frame
	attracted.is_attracted = true
	var newcomer := _spawn(Vector2(604, 402), 7)
	await process_frame
	_check(int(attracted.xp_value) == 7, "已被吸附的宝石不被新掉落吞掉（%d）" % int(attracted.xp_value))
	_check(int(newcomer.xp_value) == 7, "新掉落也不会顺走被吸附的宝石（%d）" % int(newcomer.xp_value))

	print("\n=== 4. 对象池重置 ===")
	base.reset_for_pool()
	_check(int(base.xp_value) == 0, "reset_for_pool 清空 xp_value")
	_check(base.scale == Vector2.ONE, "reset_for_pool 复原 scale")
	_check(not base.is_attracted, "reset_for_pool 清空吸附状态")

	print("\n=== 5. 拾取不与呼吸动画打架 ===")
	var pick := _spawn(Vector2(600, 500), 6)
	await process_frame
	_check(pick._pulse != null, "宝石带呼吸 tween")
	pick.xp_value = 6
	pick.player = null
	pick._collect()
	await create_timer(0.25).timeout
	_check(pick._pulse == null, "拾取时呼吸 tween 已被 kill（否则两个 tween 抢 scale）")
	# 拾取动画 0.1s 后 tween_callback → ObjectPool.release → reset_for_pool 把 scale 复原成 1，
	# 所以"已进池"才是正确的终态，不能要求 scale 停在 0
	_check(pick.has_meta("_in_pool") and bool(pick.get_meta("_in_pool")) or not pick.is_inside_tree(),
		"拾取后已归还对象池（in_pool=%s）" % str(pick.get_meta("_in_pool", false)))

	# 顺手验证经验确实进了玩家
	var main_scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	current_scene = main_scene
	await create_timer(0.6).timeout
	var p2 = main_scene.player
	var gem2 := _spawn(p2.global_position + Vector2(30, 0), 9)
	gem2.set_physics_process(true)
	await create_timer(0.5).timeout
	_check(not is_instance_valid(gem2) or not gem2.is_inside_tree(), "吸附范围内的宝石被自动拾取")

	print("\n=== 6. 对象池复用后还能吸附（玩家反馈：经验点有时候捡不到）===")
	# 回归点：_collect() 会 set_physics_process(false)，而池化复用不重跑 _ready。
	# 旧版没有在 _enter_tree 里重新打开，导致"被捡过一次"的宝石回到池里就永久僵死。
	var pool := root.get_node_or_null("/root/ObjectPool")
	_check(pool != null, "ObjectPool 自动加载可用")
	if pool != null:
		# 手动模拟一枚"捡完回池"的宝石
		var recycled := _gem_scene.instantiate() as Area2D
		recycled.xp_value = 3
		host.add_child(recycled)
		recycled.set_physics_process(false)      # 这就是 _collect() 留下的状态
		pool.release(recycled)
		await process_frame
		await process_frame

		var again: Area2D = pool.acquire(_gem_scene)
		again.xp_value = 3
		again.player = null
		host.add_child(again)                     # 入树 → _enter_tree 应当重新开物理帧
		_check(again.is_physics_processing(), "池化复用后入树即恢复物理帧（否则宝石永远躺地上）")
		again.queue_free()

	print("\n=== 7. 换波/换房时未拾取的经验会被结算，而不是凭空消失 ===")
	var wm = main_scene.wave_manager
	p2.current_xp = 0
	p2.xp_to_next_level = 9999                    # 别让结算顺带升级，好断言数值
	var leftover := _spawn(p2.global_position + Vector2(500, 0), 11)
	await process_frame
	var saved: int = wm.settle_xp_gems()
	# 前面的用例还留了几枚宝石在地上，所以只断言"至少把这一枚收回来了"
	_check(saved >= 11, "结算返回未拾取的经验总量（%d）" % saved)
	await process_frame
	_check(p2.current_xp == saved, "经验确实进了玩家（current_xp=%d / 结算 %d）" % [p2.current_xp, saved])
	_check(not is_instance_valid(leftover) or not leftover.is_inside_tree(), "结算后的宝石已回收")
	_check(wm.settle_xp_gems() == 0, "重复结算不会再发一次经验")

	print("\n========================================")
	print("通过 %d / 失败 %d" % [_pass, _fail])
	print("========================================")
	quit(0 if _fail == 0 else 1)
