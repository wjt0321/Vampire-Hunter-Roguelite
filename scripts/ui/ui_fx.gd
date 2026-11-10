class_name UiFx
extends RefCounted
## 界面交互小动效：悬停放大 / 按下回弹 / 点击涟漪 / 面板淡入。
##
## 为什么集中在一个静态工具里：这些按钮分散在主菜单、商店、选角、暂停、升级卡、
## 结算页六七处，每处都写一遍 tween 会各写各的时长和幅度，动效就不统一了。
##
## 为什么用 scale 而不是改 size：Control 的 scale 只是绘制变换，不参与容器排版，
## 套在 HBox/VBox/GridContainer 里也不会把兄弟节点挤开——这是能"无脑套"的前提。
## 代价是 pivot 必须手动设到中心，否则会按左上角放大、整块往右下跑。

const HOVER_SCALE := 1.05
const PRESS_SCALE := 0.96
const HOVER_TIME := 0.12
const PRESS_TIME := 0.07

const META_TWEEN := "ui_fx_tween"

## 给按钮接上悬停 / 按下 / 点击涟漪。重复调用是安全的（只挂一次信号），
## 但每次都更新悬停幅度：同一批按钮可能先被通用逻辑挂 1.05，
## 又被具体界面用 1.03 覆盖（三选一大卡放大会压边）。
## 之前是"已经有 meta 就 return"，后一次幅度被静默丢掉，界面看起来像没生效。
static func hover(btn: Control, amount: float = HOVER_SCALE) -> void:
	if btn == null:
		return
	btn.set_meta("ui_fx_amount", amount)
	if btn.has_meta("ui_fx_hover"):
		return
	btn.set_meta("ui_fx_hover", true)
	btn.mouse_entered.connect(func() -> void:
		_scale_to(btn, Vector2.ONE * _amount_of(btn, amount), HOVER_TIME))
	btn.mouse_exited.connect(func() -> void: _scale_to(btn, Vector2.ONE, HOVER_TIME))
	# BaseButton 才有按下状态；纯 Control（比如面板）只要悬停
	if btn is BaseButton:
		btn.button_down.connect(func() -> void:
			_scale_to(btn, Vector2.ONE * PRESS_SCALE, PRESS_TIME))
		btn.button_up.connect(func() -> void:
			_scale_to(btn, Vector2.ONE * _amount_of(btn, amount), HOVER_TIME))
		btn.pressed.connect(func() -> void: click_ripple(btn))

static func _amount_of(btn: Control, fallback: float) -> float:
	## 幅度存在 meta 上、每次悬停现读，而不是被 lambda 捕获死：
	## 捕获的话 hover(btn, 1.03) 只改 meta，补间仍然用第一次的 1.05。
	if btn == null or not is_instance_valid(btn):
		return fallback
	if not btn.has_meta("ui_fx_amount"):
		return fallback
	return float(btn.get_meta("ui_fx_amount"))

static func _scale_to(node: Control, target: Vector2, dur: float) -> void:
	if node == null or not is_instance_valid(node):
		return
	# get_meta(name, default) 在 Godot 4 里只有 default != Variant() 才会走到默认值，
	# 显式传 null 等于没传，会打 "does not have any 'meta' values with the key"。
	# 先 has_meta 再取，才是"可能没有"这个语义的正确写法。
	if node.has_meta(META_TWEEN):
		var prev: Variant = node.get_meta(META_TWEEN)
		if prev is Tween and prev.is_valid():
			prev.kill()
	if node.scale.is_equal_approx(target):
		return
	# 布局完成前 size 是 0，这时设 pivot 会得到 (0,0)，放大就从左上角开始
	node.pivot_offset = node.size * 0.5
	var tw := node.create_tween()
	# 暂停菜单是在 get_tree().paused 下弹出的，默认暂停模式会让补间直接不动
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(node, "scale", target, dur) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	node.set_meta(META_TWEEN, tw)

## 点击涟漪：在按钮内部铺一张 btn_click 贴图，放大淡出。
## 贴图是单帧，动效靠 tween —— 和场景里的特效同一个思路。
static func click_ripple(btn: Control) -> void:
	if btn == null or not is_instance_valid(btn):
		return
	if TextureManager.instance == null:
		return
	var tex: Texture2D = TextureManager.instance.get_effect_texture("btn_click")
	if tex == null:
		return
	# 贴图只有 64px，放到 480 就是 7 倍线性放大，糊成一片金光。
	# 收在 90~230 之间，既盖得住按钮，又还看得出是一圈光。
	var side: float = clampf(maxf(btn.size.x, btn.size.y) * 0.9, 90.0, 230.0)
	var ripple := TextureRect.new()
	ripple.texture = tex
	ripple.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ripple.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ripple.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ripple.size = Vector2(side, side)
	ripple.position = btn.size * 0.5 - ripple.size * 0.5
	ripple.pivot_offset = ripple.size * 0.5
	ripple.modulate = Color(1, 1, 1, 0.7)
	ripple.scale = Vector2(0.75, 0.75)
	ripple.pivot_offset = ripple.size * 0.5
	btn.add_child(ripple)

	var tw := ripple.create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.set_parallel(true)
	tw.tween_property(ripple, "scale", Vector2(1.15, 1.15), 0.32).set_ease(Tween.EASE_OUT)
	tw.tween_property(ripple, "modulate:a", 0.0, 0.32)
	tw.chain().tween_callback(ripple.queue_free)

## 面板淡入（可带一点从 0.96 放大）。
## 只动 modulate / scale：容器会覆盖 position 和 size，动它们等于白做。
static func pop_in(node: Control, dur: float = 0.18, from_scale: float = 1.0) -> void:
	if node == null or not is_instance_valid(node):
		return
	node.modulate = Color(node.modulate.r, node.modulate.g, node.modulate.b, 0.0)
	var tw := node.create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(node, "modulate:a", 1.0, dur).set_trans(Tween.TRANS_QUAD)
	if not is_equal_approx(from_scale, 1.0):
		node.pivot_offset = node.size * 0.5
		node.scale = Vector2.ONE * from_scale
		tw.parallel().tween_property(node, "scale", Vector2.ONE, dur) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## 把一批按钮一次性接上（省得每处 for 循环里再写一遍）
static func hover_all(nodes: Array, amount: float = HOVER_SCALE) -> void:
	for n in nodes:
		if n is Control:
			hover(n, amount)
