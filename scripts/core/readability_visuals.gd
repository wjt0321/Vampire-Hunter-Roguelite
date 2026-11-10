extends RefCounted
class_name ReadabilityVisuals
## 战斗可读性层：轮廓 + 地面投影（纯程序化，不引入任何新美术资源）
##
## 为什么需要：
##   敌人贴图本身是"深色剪影 + 局部红光"，站在同样是深灰石砖的地板上，
##   玩家要靠颜色猜位置。地板亮度实测中位数只有 0.23，最亮处 0.54——
##   单一手段始终有一半场景失效，所以这里用互补的两层：
##
##   · 轮廓（rim）：在本体后面垫一张放大 6% 的同款贴图，偏暖白。
##     深色地面上把剪影"描"出来，靠的是**提亮**而不是加黑。
##   · 地面投影（shadow）：本体脚下压一枚椭圆暗影。
##     亮色地面上靠它把角色和地板**分层**，同时也交代"脚在哪里"。
##
##   两者都是子节点，自动跟随本体的缩放/挤压/精英体型倍率，
##   不需要在每个敌人子类里重复同步。

const SHADOW_SIZE := 64
## 投影半透明度。太高会像"站在一个黑洞上"，太低则在亮地板上看不见。
const SHADOW_ALPHA := 0.45
## 投影宽/高比例：压扁的椭圆才读作"地面上的影子"而不是"另一个光环"
const SHADOW_SQUASH := 0.42
## 轮廓缩放。1.06 在 56px 的角色上只有 1.7px，实测渲染后 (b-r) 差值为 0，
## 也就是"做了但看不见"。1.12 给到每边 ~3.4px：足够读成描边，
## 又不会大到变成一圈光晕（1.18 在 56px 上已经 5px，偏厚）。
const RIM_SCALE := 1.12

## 视觉优先级（z_index）。纯表现层，不参与任何物理判定。
## 排序依据：HUD(100+) > 危险弹丸 > 玩家 > 敌人 > 地面层 > 地板。
##   · 玩家必须高于敌人：Boss 站在玩家正前方时两人原本都是 z=0，
##     谁后进场景树谁在前，玩家被整个盖住（720p 截图里玩家直接消失）。
##   · 危险弹丸必须高于玩家：够不够得着是走位判断，被玩家身体挡住就是不公平。
##   · 地面层必须**低于敌人和玩家**：预警圈、传送门是画在地板上的记号，
##     压在角色身上会把人像糊掉——玩家看的是"圈在哪"，不是"圈盖住谁"。
const Z_ENEMY := 0
const Z_PLAYER := 1
const Z_PROJECTILE := 2
## 地面层：地板(-10)之上、敌人(0)/玩家(1)之下。地面预警圈和传送门都用这一层。
## 取 -2 而不是 -1：敌人投影已经占了 -1，同层的话谁在前取决于入树顺序。
const Z_GROUND := -2
## 敌人轮廓：暖白。深色石砖上靠它把剪影"描"出来。
## 敌人轮廓用暖琥珀而不是纯白：纯白 + 高 alpha 会读成"贴纸描边"，
## 调成偏暖的低 alpha 才像轮廓光，和火把/烛光的环境色也更协调。
const RIM_COLOR := Color(1.0, 0.80, 0.52, 0.52)
## 玩家轮廓：冷蓝。与敌人的暖白相反，怪堆里靠色相一眼分出谁是玩家——
## 两者都是 56px，光凭体型分不出。
const PLAYER_RIM_COLOR := Color(0.52, 0.80, 1.0, 0.72)

const RimLayerScript = preload("res://scripts/core/rim_layer.gd")

static var _shadow_texture: Texture2D = null
static var _shadow_material: CanvasItemMaterial = null

## 柔边椭圆阴影：中心实、外缘按 pow 衰减。
## 用"圆形渐变 + 压扁缩放"而不是烘椭圆，这样不同体型的角色共用一张贴图。
static func get_shadow_texture() -> Texture2D:
	if _shadow_texture != null:
		return _shadow_texture
	var img := Image.create(SHADOW_SIZE, SHADOW_SIZE, false, Image.FORMAT_RGBA8)
	var center := SHADOW_SIZE * 0.5
	for y in SHADOW_SIZE:
		for x in SHADOW_SIZE:
			var d := Vector2(float(x) + 0.5 - center, float(y) + 0.5 - center).length() / center
			var alpha := 0.0
			if d < 1.0:
				alpha = pow(1.0 - d, 1.7)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	_shadow_texture = ImageTexture.create_from_image(img)
	return _shadow_texture

static func _get_shadow_material() -> CanvasItemMaterial:
	## 投影是"遮住地板"，不能用加色混合（加色只会更亮，根本压不出暗影）
	if _shadow_material == null:
		_shadow_material = CanvasItemMaterial.new()
		_shadow_material.blend_mode = CanvasItemMaterial.BLEND_MODE_MIX
	return _shadow_material

## 轮廓贴图缓存：{ 源贴图路径 + 颜色: 剪影贴图 }
## 每个姿态每种颜色烘一次，之后换姿态只是查表，不重复算像素。
static var _silhouette_cache: Dictionary = {}

## 把一张贴图烘成"纯色剪影"：只保留 alpha 形状，颜色一律用传入的 rim color。
##
## 为什么不能直接 modulate 本体贴图：
##   敌人和玩家的贴图本身就是深色（亮度 0.2 上下）。modulate 是**乘算**，
##   深色 × 冷蓝 = 更深的蓝，在同样是深色的地板上完全读不出来（实测描边像素差值 0）。
##   先按 alpha 重建成实心剪影，颜色就与源图的明暗彻底解耦。
static func get_silhouette_texture(source: Texture2D, color: Color) -> Texture2D:
	if source == null:
		return null
	var key := "%s|%s" % [source.resource_path, color.to_html()]
	if _silhouette_cache.has(key):
		return _silhouette_cache[key]
	var img: Image = source.get_image()
	if img == null:
		return null
	img = img.duplicate()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	out.fill(Color(color.r, color.g, color.b, 0.0))
	for y in h:
		for x in w:
			var a: float = img.get_pixel(x, y).a
			if a > 0.06:
				# 边缘保留原始 alpha 的软过渡，内部一律实心：
				# 这样剪影外侧仍有抗锯齿，不会出现硬台阶。
				out.set_pixel(x, y, Color(color.r, color.g, color.b, color.a * minf(a * 3.0, 1.0)))
	var tex := ImageTexture.create_from_image(out)
	_silhouette_cache[key] = tex
	return tex

## 本体贴图渲染后的实际尺寸（考虑横条帧数与缩放）
static func body_size(body: Sprite2D) -> Vector2:
	if body == null or body.texture == null:
		return Vector2.ZERO
	var tex_size := body.texture.get_size()
	var cols := maxf(float(body.hframes), 1.0)
	var rows := maxf(float(body.vframes), 1.0)
	var cell := Vector2(tex_size.x / cols, tex_size.y / rows)
	return Vector2(absf(cell.x * body.scale.x), absf(cell.y * body.scale.y))

## 给角色挂/更新地面投影。owner 是角色根节点（要让影子跟着走、但不跟着挤压）。
## 返回投影节点，方便测试与调试。
static func ensure_ground_shadow(owner: Node2D, body: Sprite2D) -> Sprite2D:
	if owner == null or body == null or not is_instance_valid(body):
		return null
	var shadow := owner.get_node_or_null("GroundShadow") as Sprite2D
	if shadow == null:
		shadow = Sprite2D.new()
		shadow.name = "GroundShadow"
		shadow.texture = get_shadow_texture()
		shadow.material = _get_shadow_material()
		shadow.centered = true
		# 角色根节点本身不画东西，所以插到 0 号位就等于"画在本体之前"
		owner.add_child(shadow)
		owner.move_child(shadow, 0)
	shadow.modulate = Color(0.03, 0.015, 0.05, SHADOW_ALPHA)
	shadow.z_index = -1
	var size := body_size(body)
	if size == Vector2.ZERO:
		return shadow
	var diameter: float = maxf(maxf(size.x, size.y) * 0.86, 18.0)
	var sx: float = diameter / float(SHADOW_SIZE)
	var sy: float = sx * SHADOW_SQUASH
	shadow.scale = Vector2(sx, sy)
	# 落在脚下：本体中心往下 42%，视觉上脚底刚好压住影子中心
	shadow.position = body.position + Vector2(0.0, size.y * 0.42)
	return shadow

## 给本体贴图挂/确认轮廓层。
static func ensure_body_rim(body: Sprite2D, color: Color = RIM_COLOR) -> Sprite2D:
	if body == null or not is_instance_valid(body) or body.texture == null:
		return null
	var rim := body.get_node_or_null("RimSprite") as Sprite2D
	if rim == null:
		rim = Sprite2D.new()
		rim.name = "RimSprite"
		rim.set_script(RimLayerScript)
		rim.set("body", body)
		body.add_child(rim)
	# 颜色写进剪影贴图本身，不是 modulate：
	# modulate 会乘上源图的明暗（源图是深色），深色 × 冷蓝 在深色地板上读不出来。
	# 剪影贴图按 alpha 重建，颜色与源图明暗彻底解耦。
	rim.set("rim_color", color)
	rim.modulate = Color(1.0, 1.0, 1.0, color.a)
	rim.scale = Vector2(RIM_SCALE, RIM_SCALE)
	return rim
