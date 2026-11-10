extends SceneTree
## Task 5：战斗画面可读性回归
## 用法: godot --headless --path . --script res://tools/readability_test.gd
##
## 覆盖：
##   ① 背景过滤策略：有成品背景图时不叠程序网格；兜底纯色地板才画网格且对齐 64px
##   ② 敌方弹丸暗边：加色亮芯之外必须有一圈不发光、比地板暗的轮廓
##   ③ 敌人轮廓 + 地面投影：不换素材也能从地板里分离出来
##   ④ 柱子 / 道具 / 装饰生成不重叠，不压玩家出生点，不堵边缘刷怪点
##   ⑤ 开火挤压不被姿态切换吃掉（与 feedback_v2_test / phase17_test 同一根因）
##   ⑥ _passive_capped(null) 安全返回 0
##
## 这些断言都直接读节点与颜色，不靠"看起来还行"。

const GRID_SIZE := 64.0
const PLACEMENT_TOLERANCE := 1.0

var _fail: int = 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ✅ %s" % msg)
	else:
		print("  ❌ %s" % msg)
		_fail += 1

func _initialize() -> void:
	_run()

func _make_room(width: float = 1280.0, height: float = 768.0) -> Node2D:
	var room := Node2D.new()
	room.set_script(load("res://scripts/map/game_room.gd"))
	room.room_width = width
	room.room_height = height
	room.name = "GameRoom"
	return room

func _tm():
	## --script 模式下 autoload 名字不是编译期标识符，运行时取节点
	return root.get_node_or_null("/root/TextureManager")

func _luminance(c: Color) -> float:
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b

func _is_additive(item: CanvasItem) -> bool:
	if item == null:
		return false
	var mat := item.material as CanvasItemMaterial
	return mat != null and mat.blend_mode == CanvasItemMaterial.BLEND_MODE_ADD

func _run() -> void:
	await process_frame
	print("")
	print("====== 战斗画面可读性回归测试 ======")

	var args := OS.get_cmdline_user_args()
	var only: String = args[0] if not args.is_empty() else ""
	if only.is_empty() or only == "background": await _test_background_policy()
	if only.is_empty() or only == "projectile": await _test_projectile_rim()
	if only.is_empty() or only == "enemy": await _test_enemy_layers()
	if only.is_empty() or only == "player_layers": await _test_player_layers()
	if only.is_empty() or only == "placement": await _test_placement()
	if only.is_empty() or only == "spawn": await _test_real_spawn_positions()
	if only.is_empty() or only == "punch": await _test_fire_punch()
	if only.is_empty() or only == "pose": await _test_punch_survives_pose_change()
	if only.is_empty() or only == "passive": await _test_passive_cap_null()

	print("")
	if _fail == 0:
		print("✅ 全部通过")
	else:
		print("❌ 失败 %d 项" % _fail)
	# 测试显式拆除根节点下的场景与 autoload，避免把待删对象直接交给引擎退出阶段。
	for child in root.get_children():
		child.queue_free()
	await process_frame
	await process_frame
	quit(1 if _fail > 0 else 0)

# ==================================================
# ① 背景过滤策略 / 调试网格
# ==================================================
func _test_background_policy() -> void:
	print("")
	print("--- ① 背景过滤策略 与 调试网格 ---")

	# 主题映射是显式的：每个房间主题都必须落到一张真实背景图上
	var theme_map: Dictionary = {
		"dungeon": "standard",
		"castle": "hall",
		"cave": "standard",
		"boss": "boss",
	}
	var missing: Array = []
	for theme in theme_map:
		var tex = _tm().get_background(String(theme_map[theme]))
		if tex == null or tex.get_width() <= 0:
			missing.append(theme)
	_check(missing.is_empty(), "四个房间主题都有背景图（缺失：%s）" % str(missing))

	# 有成品背景：不得再叠一层跟砖缝错位的程序网格
	var room := _make_room()
	root.add_child(room)
	await process_frame
	var floor_sprite := room.get_node_or_null("FloorSprite") as Sprite2D
	_check(floor_sprite != null and floor_sprite.texture != null,
		"dungeon 房间使用成品背景贴图")
	_check(room.get_node_or_null("GridOverlay") == null,
		"成品背景上不再生成调试网格 GridOverlay")
	var line_count := 0
	for child in room.get_children():
		if child is Line2D:
			line_count += 1
	_check(line_count == 0, "房间子节点里没有任何网格线（实际 %d 条）" % line_count)
	_check(floor_sprite != null and floor_sprite.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR,
		"背景采样方式是显式的（LINEAR，而不是继承项目默认）")
	_check(floor_sprite != null and floor_sprite.z_index <= -10,
		"背景固定在最底层（z=%d）" % (floor_sprite.z_index if floor_sprite else 0))
	room.queue_free()
	await process_frame

	# 兜底纯色地板：网格保留，但必须对齐 64px 且铺满整间房
	var saved = _tm().background_textures.get("standard", null)
	_tm().background_textures["standard"] = null
	var plain := _make_room()
	root.add_child(plain)
	await process_frame
	var fallback := plain.get_node_or_null("Floor") as ColorRect
	_check(fallback != null, "缺贴图时回退到纯色地板")
	var grid := plain.get_node_or_null("GridOverlay")
	_check(grid != null, "纯色地板保留网格辅助线")
	var aligned := true
	var max_x := 0.0
	var max_y := 0.0
	var grid_lines := 0
	if grid != null:
		for line in grid.get_children():
			if not (line is Line2D):
				continue
			grid_lines += 1
			var pts: PackedVector2Array = (line as Line2D).points
			if pts.size() < 2:
				aligned = false
				continue
			var a := pts[0]
			var b := pts[1]
			var is_vertical := absf(b.x - a.x) < 0.01
			var fixed := a.x if is_vertical else a.y
			if absf(fmod(fixed, GRID_SIZE)) > 0.01:
				aligned = false
			max_x = maxf(max_x, maxf(a.x, b.x))
			max_y = maxf(max_y, maxf(a.y, b.y))
	_check(grid_lines > 0, "网格线实际生成了 %d 条" % grid_lines)
	_check(aligned, "兜底网格的每条线都落在 64px 的整数倍上（不再错位）")
	_check(is_equal_approx(max_x, plain.room_width) and is_equal_approx(max_y, plain.room_height),
		"网格铺满房间边界（%.0f×%.0f）" % [max_x, max_y])
	plain.queue_free()
	_tm().background_textures["standard"] = saved
	await process_frame

# ==================================================
# ② 敌方弹丸暗边 + 对比度
# ==================================================
func _sample_floor_colors(count: int = 64) -> Array:
	## 从真实背景图的地板区域采样，作为"弹丸必须能被分辨出来"的底色分布
	var tex = _tm().get_background("standard")
	var out: Array = []
	if tex == null:
		return out
	var img: Image = tex.get_image()
	if img == null:
		return out
	var w := img.get_width()
	var h := img.get_height()
	var x0 := int(w * 0.25)
	var x1 := int(w * 0.75)
	var y0 := int(h * 0.56)
	var y1 := int(h * 0.90)
	var step := maxi(1, int(sqrt(float((x1 - x0) * (y1 - y0)) / float(count))))
	var x := x0
	while x < x1 and out.size() < count:
		var y := y0
		while y < y1 and out.size() < count:
			out.append(img.get_pixel(x, y))
			y += step
		x += step
	return out

func _test_projectile_rim() -> void:
	print("")
	print("--- ② 敌方弹丸：亮芯 + 暗边 ---")
	var proj = load("res://scenes/enemies/enemy_projectile.tscn").instantiate()
	proj.direction = Vector2.RIGHT
	root.add_child(proj)
	await process_frame

	var core := proj.get_node_or_null("Sprite2D") as Sprite2D
	var outline := proj.get_node_or_null("Outline") as Sprite2D
	_check(core != null and _is_additive(core), "亮芯保持加色混合（原本的发光感）")
	_check(outline != null, "弹丸带一圈暗边节点 Outline")
	if outline == null or core == null:
		proj.queue_free()
		return
	_check(not _is_additive(outline), "暗边不参与加色混合（否则会被亮芯一起点糊）")
	var outline_w: float = outline.texture.get_width() * outline.scale.x if outline.texture else 0.0
	var core_w: float = core.texture.get_width() * core.scale.x if core.texture else 0.0
	_check(outline_w > core_w * 1.10,
		"暗边比亮芯大一圈（%.1fpx vs %.1fpx）" % [outline_w, core_w])
	_check(outline.get_index() < core.get_index(), "暗边画在亮芯之后面（先画的是它）")
	var rim_lum := _luminance(outline.modulate)
	_check(rim_lum < 0.22, "暗边本身足够暗（亮度 %.2f）" % rim_lum)

	# 真·对比度：把暗边/亮芯分别叠在采样到的地板色上，算亮度差
	# 地板实测：p25=0.167 / 中位 0.227 / p75=0.336 / p90=0.424（room_standard.png 下半区）。
	# 单一手段在两端都会失效：暗边在暗地板没有差值，亮芯在亮石砖上炸成一团光。
	# 因此判据是"两者互补，任取一块地板至少有一样拉得开"。
	var samples := _sample_floor_colors()
	_check(samples.size() >= 32, "采到 %d 个地板色样本" % samples.size())
	var min_rim_delta := 1.0
	var min_core_delta := 1.0
	var worst_covered := 1.0
	var bright_floor_count := 0
	var bright_rim_ok := 0
	for bg in samples:
		var bg_col: Color = bg
		var rim_over := Color(
			bg_col.r * (1.0 - outline.modulate.a) + outline.modulate.r * outline.modulate.a,
			bg_col.g * (1.0 - outline.modulate.a) + outline.modulate.g * outline.modulate.a,
			bg_col.b * (1.0 - outline.modulate.a) + outline.modulate.b * outline.modulate.a)
		var core_over := Color(
			minf(bg_col.r + core.modulate.r, 1.0),
			minf(bg_col.g + core.modulate.g, 1.0),
			minf(bg_col.b + core.modulate.b, 1.0))
		var bg_lum := _luminance(bg_col)
		var rim_delta: float = bg_lum - _luminance(rim_over)
		var core_delta: float = _luminance(core_over) - bg_lum
		min_rim_delta = minf(min_rim_delta, rim_delta)
		min_core_delta = minf(min_core_delta, core_delta)
		worst_covered = minf(worst_covered, maxf(rim_delta, core_delta))
		if bg_lum >= 0.30:
			bright_floor_count += 1
			if rim_delta >= 0.12:
				bright_rim_ok += 1
	_check(worst_covered >= 0.15,
		"任意地板色上至少有一层拉得开（最差 %.2f，要求 ≥ 0.15）" % worst_covered)
	_check(min_core_delta >= 0.20,
		"亮芯在暗地板上足够亮（最小 +%.2f）" % min_core_delta)
	_check(bright_floor_count >= 8, "采到 %d 块亮石砖样本" % bright_floor_count)
	_check(bright_rim_ok == bright_floor_count,
		"亮石砖上暗边全部压得下去（%d/%d，最小 %.2f）" % [bright_rim_ok, bright_floor_count, min_rim_delta])

	# Task 2 的判定口径不能被视觉改动破坏
	var shape := proj.get_node("CollisionShape2D").shape as RectangleShape2D
	_check(shape.size == Vector2(12, 7), "碰撞体保持 12×7（Task 2 手感不变）")
	_check(shape.size.x <= core_w, "碰撞体不超过亮芯视觉（%.0f ≤ %.0f）" % [shape.size.x, core_w])
	proj.queue_free()
	await process_frame

# ==================================================
# ③ 敌人轮廓 + 地面投影
# ==================================================
func _test_enemy_layers() -> void:
	print("")
	print("--- ③ 敌人：亮轮廓 + 地面投影 ---")
	var enemy = load("res://scenes/enemies/vampire.tscn").instantiate()
	root.add_child(enemy)
	await process_frame

	var body := enemy.get_node_or_null("Sprite2D") as Sprite2D
	var rim := enemy.find_child("RimSprite", true, false) as Sprite2D
	var shadow := enemy.find_child("GroundShadow", true, false) as Sprite2D
	_check(body != null and body.texture != null, "敌人本体贴图已加载")
	_check(rim != null, "敌人带轮廓 RimSprite（复用贴图，不改素材）")
	_check(shadow != null, "敌人带地面投影 GroundShadow")
	if body == null or rim == null or shadow == null:
		enemy.queue_free()
		return

	# 两层是互补的：暗地板靠亮轮廓描出剪影，亮石砖靠地面投影分层
	_check(rim.texture != null and rim.texture != body.texture,
		"轮廓用烘出来的剪影贴图，不是本体贴图本身")

	# 剪影必须真的"是那个颜色"，而不是本体贴图乘一个色。
	# 这是这条链路上最容易假绿的地方：旧实现直接复用本体贴图 + modulate，
	# 节点、层级、缩放全对，断言也全绿，但渲染出来描边像素差值实测 = 0
	# （深色贴图 × 冷蓝 = 更深的蓝，在深色地板上看不见）。
	var sil: Image = rim.texture.get_image()
	if sil != null and sil.is_compressed():
		sil.decompress()
	var sil_colors: Dictionary = {}
	var sil_solid := 0
	for y in range(0, sil.get_height(), 2):
		for x in range(0, sil.get_width(), 2):
			var px := sil.get_pixel(x, y)
			if px.a < 0.5:
				continue
			sil_solid += 1
			sil_colors["%.2f_%.2f_%.2f" % [px.r, px.g, px.b]] = true
	_check(sil_solid > 200, "剪影有 %d 个实心像素" % sil_solid)
	_check(sil_colors.size() <= 4,
		"剪影颜色单一（%d 种），不随本体贴图明暗变化" % sil_colors.size())
	var rim_rgb := Color(rim.rim_color.r, rim.rim_color.g, rim.rim_color.b)
	var sample_ok := true
	for key in sil_colors:
		var parts: PackedStringArray = String(key).split("_")
		var c := Color(float(parts[0]), float(parts[1]), float(parts[2]))
		if not c.is_equal_approx(rim_rgb):
			sample_ok = false
	_check(sample_ok, "剪影像素色 == 轮廓色（%s）" % str(rim_rgb))
	_check(rim.show_behind_parent, "轮廓画在本体之后面")
	_check(not _is_additive(rim), "轮廓不参与加色混合（否则白边会糊成一团光）")
	# 颜色在 rim_color 上（剪影贴图自带色），modulate 只负责整体 alpha
	_check(_luminance(rim.rim_color) >= 0.55,
		"轮廓比地板亮（亮度 %.2f，地板中位 0.23）" % _luminance(rim.rim_color))
	_check(rim.rim_color.a < 1.0, "轮廓半透明（alpha %.2f），不盖住本体细节" % rim.rim_color.a)
	_check(rim.scale.x > 1.03 and rim.scale.y > 1.03,
		"轮廓比本体大一圈（%.2f）" % rim.scale.x)
	_check(shadow.texture != null and _luminance(shadow.modulate) < 0.25,
		"投影是暗色（亮度 %.2f）" % _luminance(shadow.modulate))
	_check(shadow.scale.y < shadow.scale.x, "投影压成椭圆（%.2f : %.2f）" % [shadow.scale.x, shadow.scale.y])
	_check(shadow.position.y > 0.0, "投影落在脚下（y=%.1f）" % shadow.position.y)
	_check(shadow.z_index < body.z_index, "投影画在本体后面（z=%d）" % shadow.z_index)

	# 换姿态/换贴图时轮廓必须跟着换（否则会出现"上一个动作的白色剪影"）
	var run_tex = _tm().get_player_texture("idle", "hunter")
	if run_tex != null:
		enemy.use_sprite(run_tex, "loop")
		await process_frame
		await process_frame
		_check(rim.texture != null and rim.texture != body.texture,
			"use_sprite 换图后轮廓仍是剪影贴图")
	_check(rim.hframes == body.hframes and rim.frame == body.frame, "轮廓帧与本体帧同步")

	var shape := enemy.get_node("CollisionShape2D").shape as RectangleShape2D
	_check(shape.size == Vector2(14, 20), "敌人碰撞体不变（战斗手感不动）")
	enemy.queue_free()
	await process_frame

	# Boss 也走同一套（Boss 覆写了 _ready，不走 EnemyBase 的完整流程）
	var boss = load("res://scenes/enemies/vampire_lord.tscn").instantiate()
	root.add_child(boss)
	await process_frame
	_check(boss.find_child("RimSprite", true, false) != null, "Boss 也有轮廓")
	_check(boss.find_child("GroundShadow", true, false) != null, "Boss 也有地面投影")
	boss.queue_free()
	await process_frame

# ==================================================
# ③b 玩家也得能从怪堆里认出来
# ==================================================
func _test_player_layers() -> void:
	print("")
	print("--- ③b 玩家：与敌人区分 ---")
	var player = load("res://scenes/player/player.tscn").instantiate()
	root.add_child(player)
	await process_frame
	await process_frame

	var body := player.get_node_or_null("Sprite2D") as Sprite2D
	var rim := player.find_child("RimSprite", true, false) as Sprite2D
	var shadow := player.find_child("GroundShadow", true, false) as Sprite2D
	_check(body != null and body.texture != null, "玩家本体贴图已加载")
	_check(shadow != null, "玩家也有地面投影（和敌人一样从地板里分出来）")
	_check(rim != null, "玩家也有轮廓")
	if body == null or rim == null or shadow == null:
		player.queue_free()
		await process_frame
		return

	# 关键：玩家轮廓必须是**冷色**。敌人是暖红/暗红，玩家用冷蓝才能一眼分开；
	# 都用同一个颜色的话，"谁的剪影"这件事又回到靠数量猜。
	var rim_col: Color = rim.rim_color
	_check(rim_col.b > rim_col.r, "玩家轮廓偏冷（r%.2f < b%.2f），与暖红敌人区分" % [rim_col.r, rim_col.b])
	_check(rim.show_behind_parent, "玩家轮廓画在本体后面")

	# 敌人轮廓是暖白，两者不能撞色
	var enemy = load("res://scenes/enemies/vampire.tscn").instantiate()
	root.add_child(enemy)
	await process_frame
	var enemy_rim := enemy.find_child("RimSprite", true, false) as Sprite2D
	_check(enemy_rim != null and enemy_rim.rim_color.r > enemy_rim.rim_color.b,
		"敌人轮廓偏暖（r%.2f > b%.2f）——玩家/敌人轮廓色相反" % [
			enemy_rim.rim_color.r if enemy_rim else -1.0,
			enemy_rim.rim_color.b if enemy_rim else -1.0])

	# 挤压与轮廓互不干扰：轮廓是子节点，跟着本体缩放走
	var base: Vector2 = player._sprite_base_scale
	player.apply_recoil(Vector2.RIGHT)
	_check(player.sprite.scale != base, "玩家挤压仍生效（%s）" % str(player.sprite.scale))
	_check(rim.scale.x > 1.03 and rim.scale.x < 1.20,
		"轮廓自身缩放不被挤压改写（%s）" % str(rim.scale))
	_check(rim.get_parent() == body, "轮廓挂在本体贴图下，自动继承缩放")

	# 视觉优先级：HUD > 危险弹丸 > 玩家 > 敌人 > 地板。
	# 截图里 Boss 站在玩家正前方时把玩家整个盖住——两人 z 都是 0，
	# 谁后进场景树谁在前，玩家直接消失。这条断言把它钉死在层级上。
	var enemy_body := enemy.get_node("Sprite2D") as Sprite2D
	_check(enemy_body.z_index == ReadabilityVisuals.Z_ENEMY,
		"敌人显式钉在可读性图层上（z=%d == Z_ENEMY）" % enemy_body.z_index)
	_check(body.z_index > enemy_body.z_index,
		"玩家画在敌人之上（玩家 z=%d > 敌人 z=%d）" % [body.z_index, enemy_body.z_index])
	var proj = load("res://scenes/enemies/enemy_projectile.tscn").instantiate()
	proj.direction = Vector2.RIGHT
	root.add_child(proj)
	# 弹丸和玩家子弹都会在飞满 max_range 后自己 queue_free。这里只验证层级，
	# 让它继续飞的话，中途的 await 可能正好把它送走，收尾再 queue_free 就打在
	# 已释放实例上（"Nonexistent function 'queue_free' in base 'previously freed'"）。
	proj.set_physics_process(false)
	await process_frame
	var proj_core := proj.get_node("Sprite2D") as Sprite2D
	_check(proj_core.z_index > body.z_index,
		"危险弹丸画在玩家之上（弹丸 z=%d > 玩家 z=%d）" % [proj_core.z_index, body.z_index])
	var proj_outline := proj.get_node("Outline") as Sprite2D
	_check(proj_outline.z_index < proj_core.z_index,
		"弹丸暗边仍在亮芯之下（%d < %d）" % [proj_outline.z_index, proj_core.z_index])
	var player_bullet = load("res://scenes/player/bullet.tscn").instantiate()
	root.add_child(player_bullet)
	player_bullet.set_physics_process(false)
	await process_frame
	var bullet_spr := player_bullet.get_node("Sprite2D") as Sprite2D
	_check(bullet_spr.z_index > body.z_index,
		"玩家弹道也画在玩家之上（%d > %d）" % [bullet_spr.z_index, body.z_index])
	_check(shadow.z_index < enemy_body.z_index,
		"玩家投影压在敌人之下（%d < %d）" % [shadow.z_index, enemy_body.z_index])
	# 即便上面关掉了物理，仍然逐个判有效性：这个用例踩过一次
	# "对已释放节点调用 queue_free"，不能靠"应该还在"来收尾。
	for n in [proj, player_bullet, enemy, player]:
		if is_instance_valid(n):
			n.queue_free()
	await process_frame

	await _test_ground_layer()

# ==================================================
# ③c 地面层：预警圈 / 传送门必须画在角色脚下
# ==================================================
func _test_ground_layer() -> void:
	print("")
	print("--- ③c 地面层（预警圈 / 传送门）在角色之下 ---")
	var vfx = root.get_node_or_null("VFXManager")
	if vfx == null:
		_check(false, "缺少 VFXManager autoload")
		return

	# 地面预警：注释写的是"压在地板之上、角色之下"，
	# 旧实现写的是 z=2——比玩家(1)还高，预警圈盖在角色身上。
	var scene_root := Node2D.new()
	root.add_child(scene_root)
	current_scene = scene_root
	await process_frame
	var marker = vfx.spawn_ground_marker(Vector2(400, 300), 60.0, Color(1, 0.2, 0.2), 3.0)
	_check(marker != null and is_instance_valid(marker), "地面预警标记已生成")
	if marker != null and is_instance_valid(marker):
		_check(marker.z_index < ReadabilityVisuals.Z_ENEMY,
			"地面预警压在地板之上、角色之下（z=%d < 敌人 Z_ENEMY=%d）"
				% [marker.z_index, ReadabilityVisuals.Z_ENEMY])
		_check(marker.z_index < ReadabilityVisuals.Z_PLAYER,
			"地面预警不盖住玩家（z=%d < Z_PLAYER=%d）"
				% [marker.z_index, ReadabilityVisuals.Z_PLAYER])
		_check(marker.z_index > -10,
			"地面预警仍在地板贴图之上（z=%d > 地板 -10）" % marker.z_index)
		if is_instance_valid(marker):
			marker.queue_free()
	await process_frame

	# 传送门：同样是地面上的记号，旧实现 z=2（玩家之上）。
	var room := _make_room(1280.0, 768.0)
	scene_root.add_child(room)
	var player: Node2D = load("res://scenes/player/player.tscn").instantiate()
	player.position = Vector2(640, 384)
	scene_root.add_child(player)
	await physics_frame
	await physics_frame
	room.spawn_portal()
	var portal := room.get_node_or_null("Portal") as Area2D
	_check(portal != null, "普通传送门已生成")
	if portal != null:
		_check(portal.z_index < ReadabilityVisuals.Z_PLAYER,
			"传送门画在脚下，不盖住走进去的玩家（z=%d < Z_PLAYER=%d）"
				% [portal.z_index, ReadabilityVisuals.Z_PLAYER])
		_check(portal.z_index > -10, "传送门仍在地板之上（z=%d）" % portal.z_index)

	var choice := room.call("_build_choice_portal", Vector2(500, 500),
		{"type": "event", "color": Color(0.7, 0.5, 1.0)}) as Area2D
	_check(choice != null, "岔路传送门可生成")
	if choice != null:
		_check(choice.z_index < ReadabilityVisuals.Z_PLAYER,
			"岔路传送门同样在角色之下（z=%d < Z_PLAYER=%d）"
				% [choice.z_index, ReadabilityVisuals.Z_PLAYER])

	# 传送门协程延迟 0.5s 才启用碰撞，先让它收尾再拆场景
	await create_timer(0.6).timeout
	current_scene = null
	scene_root.queue_free()
	await process_frame

# ==================================================
# ④ 柱子 / 道具 / 装饰 不重叠
# ==================================================
func _collect_obstacle_rects(room: Node2D) -> Array:
	## 只收集"家具"（柱子/道具/内墙），跳过四条边界墙：
	## 边界墙在四角必然互相重叠，算进去就永远有 4 处"穿模"。
	var out: Array = []
	for child in room.get_children():
		if child is StaticBody2D and child.is_in_group("walls") and not child.is_in_group("room_bounds"):
			var body := child as StaticBody2D
			for sub in body.get_children():
				if sub is CollisionShape2D and (sub as CollisionShape2D).shape is RectangleShape2D:
					var shape_node := sub as CollisionShape2D
					var rect_shape := shape_node.shape as RectangleShape2D
					var center: Vector2 = body.position + shape_node.position
					out.append(Rect2(center - rect_shape.size * 0.5, rect_shape.size))
	return out

func _collect_decoration_rects(room: Node2D) -> Array:
	var out: Array = []
	for child in room.get_children():
		if child is Sprite2D and child.is_in_group("mirrorable"):
			var spr := child as Sprite2D
			if spr.texture == null:
				continue
			var size := Vector2(spr.texture.get_width() * spr.scale.x, spr.texture.get_height() * spr.scale.y)
			out.append(Rect2(spr.position - size * 0.5, size))
	return out

func _count_overlaps(rects: Array) -> Array:
	var pairs: Array = []
	for i in rects.size():
		for j in range(i + 1, rects.size()):
			var a: Rect2 = rects[i]
			var b: Rect2 = rects[j]
			var shrunk := a.grow(-PLACEMENT_TOLERANCE)
			if shrunk.intersects(b.grow(-PLACEMENT_TOLERANCE)):
				pairs.append([i, j])
	return pairs

func _test_placement() -> void:
	print("")
	print("--- ④ 柱子 / 道具 / 装饰 生成不重叠 ---")

	var worst_obstacle_pairs := 0
	var worst_decoration_pairs := 0
	var worst_center_violations := 0
	var pillar_shortfall := 0
	var prop_shortfall := 0

	for round_index in 12:
		var room := _make_room()
		root.add_child(room)
		await process_frame
		room.add_pillars(6)
		room.add_props(4)
		room.add_decorations(5)
		await process_frame

		# 读房间自己的计数器，而不是按节点名统计：
		# 重名道具会被引擎改名成 @Prop_coffin@2，按前缀统计会漏掉。
		if room.pillar_count < 6:
			pillar_shortfall += 1
		if room.prop_count < 4:
			prop_shortfall += 1

		var obstacles := _collect_obstacle_rects(room)
		var decorations := _collect_decoration_rects(room)
		worst_obstacle_pairs = maxi(worst_obstacle_pairs, _count_overlaps(obstacles).size())
		var mixed: Array = obstacles.duplicate()
		mixed.append_array(decorations)
		worst_decoration_pairs = maxi(worst_decoration_pairs,
			_count_overlaps(mixed).size() - _count_overlaps(obstacles).size())

		# 玩家出生点在房间正中，柱子/道具不能压在上面
		var center: Vector2 = room.get_center()
		for rect in obstacles:
			var r: Rect2 = rect
			if r.grow(24.0).has_point(center):
				worst_center_violations += 1
				break

		# 真实刷怪点不能落在障碍里。
		# 这里刻意不走 get_spawn_position_on_edge()——那是生产代码零调用的函数，
		# 拿它断言等于测了个死代码（真实路径是 WaveManager._get_spawn_position）。
		# 由 _test_real_spawn_positions() 覆盖。
		room.queue_free()
		await process_frame

	_check(pillar_shortfall == 0, "12 轮里柱子都放满 6 根（失败轮数 %d）" % pillar_shortfall)
	_check(prop_shortfall == 0, "12 轮里道具都放满 4 个（失败轮数 %d）" % prop_shortfall)
	_check(worst_obstacle_pairs == 0, "柱子 / 道具之间没有一对重叠（最差 %d 对）" % worst_obstacle_pairs)
	_check(worst_decoration_pairs == 0, "装饰不与柱子/道具穿模（最差 %d 处）" % worst_decoration_pairs)
	_check(worst_center_violations == 0, "没有障碍压住玩家出生点（最差 12 轮中 %d 轮）" % worst_center_violations)

	# 特殊房间：固定摆件之后补的装饰也必须避开
	var shop := _make_room()
	root.add_child(shop)
	await process_frame
	shop.setup_shop_room()
	await process_frame
	var shop_mixed: Array = _collect_obstacle_rects(shop)
	shop_mixed.append_array(_collect_decoration_rects(shop))
	_check(_count_overlaps(shop_mixed).is_empty(),
		"商店房固定摆件 + 装饰无重叠（%d 处）" % _count_overlaps(shop_mixed).size())
	shop.queue_free()
	await process_frame

# ==================================================
# ④b 真实刷怪点不落在柱子/道具里
# ==================================================
func _test_real_spawn_positions() -> void:
	print("")
	print("--- ④b 真实刷怪点（WaveManager._get_spawn_position） ---")
	## 走生产路径：WaveManager._get_spawn_position()。
	## 旧测试用 get_spawn_position_on_edge() 断言"刷怪点不堵"，
	## 但那个函数生产代码零调用——真正刷怪走的是 wave_manager 的
	## "玩家周围 600px 圆环 + 钳进房间"，完全没有避障查询。
	var room := _make_room()
	var main := Node2D.new()
	main.name = "Main"
	root.add_child(main)
	main.add_child(room)
	current_scene = main
	await process_frame
	room.add_pillars(6)
	room.add_props(4)
	await process_frame

	var player = load("res://scenes/player/player.tscn").instantiate()
	player.global_position = room.to_global(room.get_center())
	main.add_child(player)
	await physics_frame
	await physics_frame

	var wm = load("res://scripts/managers/wave_manager.gd").new()
	main.add_child(wm)
	wm.player = player
	await physics_frame

	var blocked := 0
	var total := 200
	var samples: Array = []
	for i in total:
		var pos: Vector2 = wm._get_spawn_position()
		samples.append(pos)
		if not room.is_position_clear_at(pos, 22.0):
			blocked += 1
	# 判据是"一个都不能落进去"：房间是 1280×768、只有 6 柱 4 道具，
	# 空地足够多，落进障碍说明根本没做避障查询，不是"运气不好"。
	_check(blocked == 0, "真实刷怪点没有一个落在障碍里（%d/%d 失败）" % [blocked, total])
	# 诊断信息：把最差的一个点打出来，出问题时能直接定位
	if blocked > 0:
		for pos in samples:
			if not room.is_position_clear_at(pos, 22.0):
				print("    ↳ 样本落点卡在障碍里：%s" % str(pos))
				break

	# 无论如何都不能刷到房间外
	var bounds: Rect2 = room.get_room_bounds()
	var outside := 0
	for pos in samples:
		var local: Vector2 = room.to_local(pos)
		if not bounds.has_point(local):
			outside += 1
	_check(outside == 0, "刷怪点都在房间内部（越界 %d/%d）" % [outside, total])

	wm.queue_free()
	player.queue_free()
	# room 是 main 的子节点，随 main 一起释放
	main.queue_free()
	current_scene = null
	await process_frame

# ==================================================
# ⑤ 开火挤压不被姿态切换吃掉
# ==================================================
func _test_fire_punch() -> void:
	print("")
	print("--- ⑤ 开火挤压（视觉反馈） ---")
	var player = load("res://scenes/player/player.tscn").instantiate()
	root.add_child(player)
	await process_frame
	await process_frame

	var base: Vector2 = player._sprite_base_scale
	_check(base != Vector2.ZERO, "记录到精灵基准缩放 %s" % str(base))
	player.apply_recoil(Vector2.RIGHT)
	_check(player.sprite.scale != base,
		"开火瞬间精灵被挤压（实际 %s，基准 %s）" % [str(player.sprite.scale), str(base)])
	_check(player.sprite.scale.y < base.y, "横向开火时纵向压扁（%.3f < %.3f）" % [player.sprite.scale.y, base.y])
	await create_timer(0.2).timeout
	_check(player.sprite.scale.is_equal_approx(base),
		"0.2s 内回到基准（%s）" % str(player.sprite.scale))

	# 连续开火时挤压仍然生效（不能被上一次的补间"锁"在基准上）
	player.apply_recoil(Vector2.RIGHT)
	await process_frame
	player.apply_recoil(Vector2.DOWN)
	_check(player.sprite.scale != base, "第二次开火仍能挤压（实际 %s）" % str(player.sprite.scale))
	player.queue_free()
	await process_frame

# ==================================================
# ⑤b 挤压中切姿态：受击/护盾不能把挤压冻死
# ==================================================
func _test_punch_survives_pose_change() -> void:
	print("")
	print("--- ⑤b 挤压中切姿态（受击 / 护盾） ---")
	var player = load("res://scenes/player/player.tscn").instantiate()
	root.add_child(player)
	await process_frame
	await process_frame

	var base: Vector2 = player._sprite_base_scale
	_check(base != Vector2.ZERO, "记录到精灵基准缩放 %s" % str(base))

	# 开火 → 立刻受击（hurt 是一次性姿态，走 _apply_player_pose 重算基准）。
	# 旧实现在 _apply_player_pose 里无条件 kill 挤压补间：
	# 补间没了，进度永远停在第 0 帧，角色就**一直**保持压扁状态直到下次开火。
	player.apply_recoil(Vector2.RIGHT)
	var squashed: Vector2 = player.sprite.scale
	_check(squashed != base, "开火瞬间被挤压（%s）" % str(squashed))
	player._play_one_shot("hurt")
	_check(player.sprite.scale != base,
		"受击瞬间挤压仍在（不能被姿态切换还原成基准）— 实际 %s" % str(player.sprite.scale))
	await create_timer(0.2).timeout
	_check(player.sprite.scale.is_equal_approx(base),
		"挤压中受击：0.2s 后仍能回到基准（实际 %s）" % str(player.sprite.scale))

	# 护盾同理（shield 姿态、较长 hold）
	player.apply_recoil(Vector2.DOWN)
	_check(player.sprite.scale != base, "再次开火被挤压（%s）" % str(player.sprite.scale))
	player._play_one_shot("shield")
	await create_timer(0.2).timeout
	_check(player.sprite.scale.is_equal_approx(base),
		"挤压中开盾：0.2s 后仍能回到基准（实际 %s）" % str(player.sprite.scale))

	# 边界：连续两次开火都要回弹，不能因为互相 kill 卡住
	player.apply_recoil(Vector2.RIGHT)
	await process_frame
	player.apply_recoil(Vector2.LEFT)
	await create_timer(0.25).timeout
	_check(player.sprite.scale.is_equal_approx(base),
		"连续开火后也能回弹（实际 %s）" % str(player.sprite.scale))
	player.queue_free()
	await process_frame

# ==================================================
# ⑥ _passive_capped(null) 安全返回
# ==================================================
func _test_passive_cap_null() -> void:
	print("")
	print("--- ⑥ 被动上限的空值保护 ---")
	var player = load("res://scenes/player/player.tscn").instantiate()
	root.add_child(player)
	await process_frame

	# 关键点：GDScript 对 null 取属性会打印运行时错误并**中断函数**，
	# 于是返回值是 null 而不是 0.0。旧实现靠 float(null)==0 侥幸通过，
	# 但控制台每次都刷一条 "Invalid access to property 'item_id' on Nil"。
	# 所以断言看返回类型，而不是 float() 之后的数值——那样永远绿。
	var null_result = player._passive_capped(null)
	_check(typeof(null_result) == TYPE_FLOAT and is_equal_approx(float(null_result), 0.0),
		"_passive_capped(null) 返回 float 0.0（实际 %s）" % type_string(typeof(null_result)))
	var bogus := Resource.new()
	var bogus_result = player._passive_capped(bogus)
	_check(typeof(bogus_result) == TYPE_FLOAT and is_equal_approx(float(bogus_result), 0.0),
		"没有 item_id / get_scaled_value 的对象返回 0.0（实际 %s）" % type_string(typeof(bogus_result)))

	var catalog = load("res://scripts/core/item_catalog.gd")
	var shield = catalog.create_passive("shield")
	var capped: float = player._passive_capped(shield)
	_check(capped > 0.0, "正常道具仍走上限表（护盾冷却 %.1fs）" % capped)
	var frozen = catalog.create_passive("frozen_heart")
	_check(player._passive_capped(frozen) <= GameConfig.cap_passive_value("frozen_heart", 99.0) + 0.0001,
		"正常道具仍受上限约束（冻结 %.3f）" % player._passive_capped(frozen))
	player.queue_free()
	await process_frame
