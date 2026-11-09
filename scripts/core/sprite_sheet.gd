extends RefCounted
class_name SpriteSheet
## 角色精灵的横条播放。
##
## 一格是正方形，横着紧贴排列，帧数 = 宽 / 高。
## 现在仓库里的图几乎都是方的单张（1024 或 256）。单张不切帧，
## 调用方用轻微浮动代替循环，等横条换上来之后同一套逻辑会自动播。

const LOOP_FPS: float = 8.0
const BOB_PIXELS: float = 1.0
const BOB_PERIOD: float = 1.2

static func frame_count(texture: Texture2D) -> int:
	if texture == null:
		return 1
	var size := texture.get_size()
	if size.y <= 1.0 or size.x <= size.y + 0.5:
		return 1
	var cells := int(round(size.x / size.y))
	if cells < 2:
		return 1
	# 宽必须是高的整数倍，否则不是紧贴的正方形格子，整张当一帧
	if absf(size.x - size.y * float(cells)) > 0.5:
		return 1
	return cells

static func cell_size(texture: Texture2D) -> float:
	## 横条用格子边长（图高）。单张沿用原来的“长边”，避免 16×24 这种占位图被拉变形口径。
	var size := texture.get_size()
	if frame_count(texture) > 1:
		return size.y
	return maxf(size.x, size.y)

static func apply(sprite: Sprite2D, texture: Texture2D, target_size: float, scale_mult: float = 1.0) -> Vector2:
	sprite.texture = texture
	sprite.vframes = 1
	sprite.hframes = frame_count(texture)
	sprite.frame = 0
	var factor := target_size / maxf(cell_size(texture), 1.0) * scale_mult
	var scale := Vector2(factor, factor)
	sprite.scale = scale
	# 48 像素的格子放大到 56 时用最近邻，避免线性过滤把像素糊掉
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return scale

static func advance(sprite: Sprite2D, wait: float, delta: float) -> float:
	## 循环播放。返回更新后的等待时间。单帧不动。
	if sprite == null or sprite.hframes <= 1:
		return 0.0
	wait += delta
	var step := 1.0 / LOOP_FPS
	while wait >= step:
		wait -= step
		sprite.frame = (sprite.frame + 1) % sprite.hframes
	return wait

static func advance_once(sprite: Sprite2D, wait: float, delta: float) -> Array:
	## 播到最后一格就停。返回 [等待时间, 是否已经播完]。
	if sprite == null or sprite.hframes <= 1:
		return [0.0, true]
	wait += delta
	var step := 1.0 / LOOP_FPS
	var finished := false
	while wait >= step and not finished:
		wait -= step
		if sprite.frame >= sprite.hframes - 1:
			finished = true
			wait = 0.0
		else:
			sprite.frame += 1
	return [wait, finished]

static func bob_offset(time: float) -> float:
	return sin(time * TAU / BOB_PERIOD) * BOB_PIXELS
