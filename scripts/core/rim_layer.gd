extends Sprite2D
## 轮廓层：在本体精灵背后垫一层"纯色剪影"，比本体大一圈。
##
## 挂在角色本体 Sprite2D 下面、show_behind_parent = true：
## 于是本体的缩放（精英体型倍率）、挤压（开火后坐）、翻转都自动继承，
## 每个敌人子类都不需要单独同步一次轮廓。
##
## 为什么贴图是"烘出来的剪影"而不是直接复用本体贴图 + modulate：
##   角色贴图本身是深色（亮度约 0.2）。modulate 是乘算，深色 × 冷蓝 = 更深的蓝，
##   放在同样深色的石砖地板上实测描边像素差值为 0——做了等于没做。
##   所以每张贴图按 alpha 重建成实心剪影（见 ReadabilityVisuals.get_silhouette_texture），
##   颜色只由 rim_color 决定，与源图明暗无关。
##
## 必须每帧跟的只有：来源贴图（换姿态）、当前帧（横条）、透明度（受击闪白/死亡淡出）。
## 全部"变了才写"，空转开销就是几次比较。

const ReadabilityLib = preload("res://scripts/core/readability_visuals.gd")

var body: Sprite2D = null
## 轮廓色。换色会重新取/烘一张剪影贴图。
var rim_color: Color = Color(1.0, 0.94, 0.88, 0.55):
	set(value):
		rim_color = value
		_source_texture = null  # 逼下一帧重新取剪影
## 剪影是从哪张源贴图烘出来的（用来判断换图）
var _source_texture: Texture2D = null
## 剪影自身的 alpha 基准，每帧乘上本体的 alpha，
## 保证死亡淡出/瞬移淡入时轮廓一起消失，不会留一块彩色残影。
var _base_alpha: float = 1.0

func _ready() -> void:
	show_behind_parent = true
	centered = true
	z_as_relative = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_base_alpha = modulate.a
	set_process(true)
	_sync()

func _process(_delta: float) -> void:
	_sync()

func _sync() -> void:
	if body == null or not is_instance_valid(body):
		body = get_parent() as Sprite2D
		if body == null:
			return
	if body.texture != _source_texture:
		_source_texture = body.texture
		texture = ReadabilityLib.get_silhouette_texture(_source_texture, rim_color)
	if hframes != body.hframes:
		hframes = body.hframes
	if vframes != body.vframes:
		vframes = body.vframes
	if frame != body.frame:
		frame = body.frame
	if offset != body.offset:
		offset = body.offset
	if flip_h != body.flip_h:
		flip_h = body.flip_h
	if flip_v != body.flip_v:
		flip_v = body.flip_v
	# 剪影贴图自己已经带 alpha，这里只叠本体的淡出进度
	var want_alpha: float = body.modulate.a
	if not is_equal_approx(modulate.a, want_alpha):
		modulate.a = want_alpha
