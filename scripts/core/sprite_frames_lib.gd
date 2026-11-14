extends RefCounted
## 矩形单格的序列帧播放器。
##
## SpriteSheet 那套按「宽 ÷ 高 = 帧数」推帧数，只对正方形单格成立。
## 特效和道具这批是矩形单格（火把 24×48、宝箱 48×40、商人 128×128），
## 帧数必须显式给，所以单独一套：AtlasTexture 切帧 + AnimatedSprite2D 播放。
##
## 贴图是「N 格横条」，第 i 帧的矩形是 (i*cell_w, 0, cell_w, cell_h)。

const DEFAULT_FPS := 12.0
const LOOP_FPS := 8.0


static func frames_from_strip(texture: Texture2D, cell_w: int, cell_h: int, count: int,
		fps: float = DEFAULT_FPS, loop: bool = true) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	frames.add_animation("play")
	frames.set_animation_speed("play", maxf(1.0, fps))
	frames.set_animation_loop("play", loop)
	if texture == null or count <= 0 or cell_w <= 0 or cell_h <= 0:
		return frames
	var usable := int(texture.get_width() / cell_w)
	var n: int = mini(count, maxi(0, usable))
	for i in n:
		var at := AtlasTexture.new()
		at.atlas = texture
		at.region = Rect2(float(i * cell_w), 0.0, float(cell_w), float(cell_h))
		at.filter_clip = true
		frames.add_frame("play", at)
	return frames


static func make_animated(texture: Texture2D, cell_w: int, cell_h: int, count: int,
		fps: float = DEFAULT_FPS, loop: bool = true) -> AnimatedSprite2D:
	var anim := AnimatedSprite2D.new()
	anim.sprite_frames = frames_from_strip(texture, cell_w, cell_h, count, fps, loop)
	anim.animation = "play"
	anim.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if anim.sprite_frames.get_frame_count("play") > 0:
		anim.autoplay = "play"
	return anim


static func strip_frame_count(texture: Texture2D, cell_w: int) -> int:
	if texture == null or cell_w <= 0:
		return 0
	return int(texture.get_width() / cell_w)
