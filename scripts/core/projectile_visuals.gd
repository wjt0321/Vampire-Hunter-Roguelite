extends RefCounted
class_name ProjectileVisuals
## 弹道可视化工厂（程序化贴图，不依赖美术资源）
##
## 背景：早期所有弹丸都是 8x8 的纯色方块，在深色地板 + 二十只怪的同屏混战里
## 几乎看不清。这里用代码烘一张"亮芯 + 柔光"的贴图，配合加色混合，
## 让弹道在任何背景下都有一圈发光轮廓，同时保持 1 个 Sprite 的开销。
##
## 用法：
##   ProjectileVisuals.style_sprite(sprite, Color(1.0, 0.87, 0.35), 16.0, 6.0)
##   ProjectileVisuals.style_sprite(sprite, Color(1.0, 0.25, 0.2), 16.0, 10.0, true)

static var _bolt_texture: Texture2D = null
static var _orb_texture: Texture2D = null
static var _ring_texture: Texture2D = null
static var _gem_texture: Texture2D = null
static var _additive_material: CanvasItemMaterial = null

const BOLT_W := 48
const BOLT_H := 20
const ORB_SIZE := 48
const RING_SIZE := 96
const GEM_SIZE := 48

## 长条弹（子弹、弩箭、飞刀）—— 中间亮芯，四周柔光
static func get_bolt_texture() -> Texture2D:
	if _bolt_texture != null:
		return _bolt_texture
	var img := Image.create(BOLT_W, BOLT_H, false, Image.FORMAT_RGBA8)
	var center := Vector2(BOLT_W * 0.5, BOLT_H * 0.5)
	var core_half_len := BOLT_W * 0.25      # 亮芯占中间一半宽度
	# 亮芯厚度占比：0.16 时一根 6px 的子弹只有不到 2px 是实心的（试玩反馈"太细看不清"）。
	# 提到 0.30 后同样的 6px 有 3.6px 实心，光晕仍在外圈，不会糊成一块。
	var core_radius := BOLT_H * 0.30        # 亮芯厚度
	var halo_radius := BOLT_H * 0.48        # 光晕外缘
	for y in BOLT_H:
		for x in BOLT_W:
			var px := float(x) + 0.5
			var py := float(y) + 0.5
			# 到"中间线段"的距离，这样长条也能有均匀的胶囊光晕
			var dx := maxf(absf(px - center.x) - core_half_len, 0.0)
			var dist := Vector2(dx, py - center.y).length()
			var alpha := 0.0
			if dist <= core_radius:
				alpha = 1.0
			elif dist < halo_radius:
				var t := 1.0 - (dist - core_radius) / (halo_radius - core_radius)
				alpha = pow(t, 2.4) * 0.9
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	_bolt_texture = ImageTexture.create_from_image(img)
	return _bolt_texture

## 圆形弹（法术球、Boss 弹幕）—— 中心实心，向外柔和衰减
static func get_orb_texture() -> Texture2D:
	if _orb_texture != null:
		return _orb_texture
	var img := Image.create(ORB_SIZE, ORB_SIZE, false, Image.FORMAT_RGBA8)
	var center := Vector2(ORB_SIZE * 0.5, ORB_SIZE * 0.5)
	var core_radius := ORB_SIZE * 0.16
	var halo_radius := ORB_SIZE * 0.5
	for y in ORB_SIZE:
		for x in ORB_SIZE:
			var dist := (Vector2(float(x) + 0.5, float(y) + 0.5) - center).length()
			var alpha := 0.0
			if dist <= core_radius:
				alpha = 1.0
			elif dist < halo_radius:
				var t := 1.0 - (dist - core_radius) / (halo_radius - core_radius)
				alpha = pow(t, 2.2) * 0.95
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	_orb_texture = ImageTexture.create_from_image(img)
	return _orb_texture

## 加色混合材质：深色背景上会"发光"，浅色背景上也不会糊成一团
static func get_additive_material() -> CanvasItemMaterial:
	if _additive_material == null:
		_additive_material = CanvasItemMaterial.new()
		_additive_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _additive_material

## 空心圆环（护盾光环、地面预警圈）
## 环心镂空，所以不会把玩家整个人盖成一块蓝——这是"护盾存在感"的关键，
## 早期版本用 sprite.modulate 循环闪蓝，既看不出是护盾，又会和受击闪红打架。
static func get_ring_texture() -> Texture2D:
	if _ring_texture != null:
		return _ring_texture
	var img := Image.create(RING_SIZE, RING_SIZE, false, Image.FORMAT_RGBA8)
	var center := Vector2(RING_SIZE * 0.5, RING_SIZE * 0.5)
	var outer := RING_SIZE * 0.5
	var ring_mid := outer * 0.86
	var thickness := outer * 0.14
	for y in RING_SIZE:
		for x in RING_SIZE:
			var dist := (Vector2(float(x) + 0.5, float(y) + 0.5) - center).length()
			var alpha := 0.0
			var delta := absf(dist - ring_mid)
			if delta <= thickness:
				# 环带中心最亮，向内外两侧柔和衰减
				alpha = pow(1.0 - delta / thickness, 1.6)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	_ring_texture = ImageTexture.create_from_image(img)
	return _ring_texture

## 把一个 Sprite2D 变成指定直径的光环
static func make_ring_sprite(diameter: float, color: Color) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = get_ring_texture()
	sprite.material = get_additive_material()
	sprite.modulate = color
	var s: float = diameter / float(RING_SIZE)
	sprite.scale = Vector2(s, s)
	sprite.z_index = -1
	return sprite

## 菱形宝石（经验点、掉落物）
##
## 早期经验点就是一张 6x6 白方块缩到 0.6 倍（屏幕上约 3.6px），
## 在一片深色地板和二十只怪里基本等于隐形——用户反馈"经验点太小看不清"。
## 这里烘一张菱形：本体实心、中心偏亮、外圈一圈柔光，配合分档尺寸后
## 小怪掉的小宝石也有 12px 的可视面积，且形状不是"点"而是"宝石"。
static func get_gem_texture() -> Texture2D:
	if _gem_texture != null:
		return _gem_texture
	var img := Image.create(GEM_SIZE, GEM_SIZE, false, Image.FORMAT_RGBA8)
	var center := Vector2(GEM_SIZE * 0.5, GEM_SIZE * 0.5)
	var half := GEM_SIZE * 0.5
	for y in GEM_SIZE:
		for x in GEM_SIZE:
			var p := Vector2(float(x) + 0.5, float(y) + 0.5) - center
			# 曼哈顿距离 = 菱形（四点朝上下左右，看着像钻石而不是色块）
			var diamond := (absf(p.x) + absf(p.y)) / half
			var alpha := 0.0
			var bright := 1.0
			if diamond <= 0.62:
				# 宝石本体：越靠近中心越亮，模拟高光
				alpha = 1.0
				bright = lerpf(1.0, 0.80, diamond / 0.62)
			elif diamond <= 1.10:
				# 外圈柔光
				var t := 1.0 - (diamond - 0.62) / 0.48
				alpha = pow(t, 1.8) * 0.55
			if alpha > 0.0:
				img.set_pixel(x, y, Color(bright, bright, bright, alpha))
	_gem_texture = ImageTexture.create_from_image(img)
	return _gem_texture

## 把 Sprite2D 变成一枚指定屏幕尺寸的发光宝石
static func style_gem(sprite: Sprite2D, color: Color, size: float) -> void:
	if sprite == null:
		return
	var tex: Texture2D = get_gem_texture()
	sprite.texture = tex
	var s: float = maxf(size, 6.0) / float(GEM_SIZE)
	sprite.scale = Vector2(s, s)
	sprite.modulate = color
	sprite.material = get_additive_material()
	# 站在地板上、人物之下，但不会被地板盖住
	sprite.z_index = 0

## 把任意 Sprite2D 变形成一枚发光弹丸
## length / thickness 是"屏幕上想要的大小（像素）"，内部按贴图尺寸自动换算缩放
static func style_sprite(sprite: Sprite2D, color: Color, length: float, thickness: float, round_shape: bool = false) -> void:
	if sprite == null:
		return
	var tex: Texture2D = get_orb_texture() if round_shape else get_bolt_texture()
	sprite.texture = tex
	var tex_size: Vector2 = tex.get_size()
	sprite.scale = Vector2(
		maxf(length, 4.0) / maxf(tex_size.x, 1.0),
		maxf(thickness, 4.0) / maxf(tex_size.y, 1.0)
	)
	sprite.modulate = color
	sprite.material = get_additive_material()
	# 弹丸永远画在敌人之上，否则被怪堆埋掉
	sprite.z_index = 1

## 给一个"没有 Sprite 子节点"的动态弹丸临时挂上发光外观
static func attach_glow(node: Node2D, color: Color, size: float) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = "ProjectileGlow"
	node.add_child(sprite)
	style_sprite(sprite, color, size, size, true)
	return sprite
