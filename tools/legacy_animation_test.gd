extends SceneTree
## 旧 MVP 资产「动起来」这一轮的回归：
##  · 11 个旧敌人的每个动作都有专属新风格精灵条（专属目录优先于旧平铺图）
##  · 死亡条是 6 帧，而且 6 帧真的不一样（不是同一张复制 6 遍）
##  · 特效 / 道具的序列帧文件在位，尺寸和登记表自洽
##  · 矩形单格（宽≠高）能被 SpriteFrames 正确切帧
##
## 用法: godot --headless --path . --script res://tools/legacy_animation_test.gd

const AssetSlots = preload("res://scripts/core/asset_slots.gd")
const Sheet = preload("res://scripts/core/sprite_sheet.gd")
const FramesLib = preload("res://scripts/core/sprite_frames_lib.gd")

const ENEMY_ROOT := "res://assets/sprites/enemies"

## 每个旧敌人游戏里真正会请求到的状态。
## 脚本里 get_enemy_texture(<id>, <state>) 会先找专属目录，所以这份表
## 就是「文件放对了就会自动生效」的清单。
const LEGACY := {
	"vampire": ["idle", "run", "death"],
	"werewolf": ["idle", "charge", "death"],
	"bat": ["fly", "death"],
	"zombie": ["idle", "walk", "death"],
	"skeleton": ["idle", "shoot", "death"],
	"exploder": ["idle", "walk", "explode", "death"],
	"gargoyle": ["idle", "petrify", "wake", "death"],
	"vampire_mage": ["idle", "cast", "teleport", "death"],
	"summoner": ["idle", "cast", "death"],
	"vampire_prince": ["idle", "dash", "rage", "death"],
	"elite_vampire": ["idle", "death"],
}

var _fail: int = 0
var _pass: int = 0


func _initialize() -> void:
	_run()


func _check(ok: bool, label: String) -> void:
	if ok:
		_pass += 1
		print("✅ %s" % label)
	else:
		_fail += 1
		print("❌ %s" % label)


func _strip_path(enemy_id: String, state: String) -> String:
	return "%s/%s/%s.png" % [ENEMY_ROOT, enemy_id, state]


func _load_tex(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


## 两帧之间不同的像素占比。
func _frame_diff(img: Image, idx_a: int, idx_b: int, cell: int) -> float:
	var diff := 0
	for y in cell:
		for x in cell:
			var a := img.get_pixel(idx_a * cell + x, y)
			var b := img.get_pixel(idx_b * cell + x, y)
			if absf(a.r - b.r) > 0.12 or absf(a.g - b.g) > 0.12 or absf(a.b - b.b) > 0.12:
				diff += 1
	return float(diff) / float(cell * cell)


func _run() -> void:
	print("\n====== 旧敌人动作条 ======")
	for enemy_id in LEGACY.keys():
		for state in LEGACY[enemy_id]:
			var path := _strip_path(enemy_id, state)
			var tex := _load_tex(path)
			if tex == null:
				_check(false, "%s/%s 有专属精灵条" % [enemy_id, state])
				continue
			_check(true, "%s/%s 有专属精灵条" % [enemy_id, state])
			var size := tex.get_size()
			_check(size.y == 56.0, "%s/%s 单格高 56（实际 %d）" % [enemy_id, state, int(size.y)])
			_check(size.x > size.y, "%s/%s 是多帧横条（%dx%d）" % [enemy_id, state, int(size.x), int(size.y)])
			_check(Sheet.frame_count(tex) >= 2, "%s/%s 帧数能被 SpriteSheet 识别" % [enemy_id, state])

	# 精英吸血鬼的贴图键是 elite_vampire，但 _get_enemy_type() 返回 "elite"，
	# 而死亡动画是按 _get_enemy_type() 找表的，两边都得有文件。
	var elite_death := _load_tex(_strip_path("elite", "death"))
	_check(elite_death != null, "elite/death 有死亡条（_get_enemy_type() 返回 elite）")

	print("\n====== 死亡条真的在演 ======")
	for enemy_id in LEGACY.keys():
		var tex := _load_tex(_strip_path(enemy_id, "death"))
		if tex == null:
			continue
		var img := tex.get_image()
		var frames := Sheet.frame_count(tex)
		_check(frames == 6, "%s 死亡条是 6 帧（实际 %d）" % [enemy_id, frames])
		if frames != 6:
			continue
		var min_diff := 1.0
		for i in range(frames - 1):
			min_diff = minf(min_diff, _frame_diff(img, i, i + 1, 56))
		_check(min_diff > 0.03, "%s 死亡条相邻帧确实不同（最小差异 %.1f%%）" % [enemy_id, min_diff * 100.0])

	print("\n====== 特效 / 道具序列帧 ======")
	for key in AssetSlots.EFFECT_SHEETS.keys():
		var slot: Dictionary = AssetSlots.EFFECT_SHEETS[key]
		var path := String(slot.get("path", ""))
		var tex := _load_tex(path)
		if tex == null:
			_check(false, "特效 %s 有序列帧文件" % key)
			continue
		_check(true, "特效 %s 有序列帧文件" % key)
		var cell: Array = slot.get("cell", [64, 64])
		var frames: int = int(slot.get("frames", 1))
		var size := tex.get_size()
		_check(size.x == float(int(cell[0]) * frames) and size.y == float(int(cell[1])),
			"特效 %s 尺寸 = 帧数×单格（%dx%d）" % [key, int(size.x), int(size.y)])

	for key in AssetSlots.PROP_SHEETS.keys():
		var slot: Dictionary = AssetSlots.PROP_SHEETS[key]
		var path := String(slot.get("path", ""))
		var tex := _load_tex(path)
		if tex == null:
			_check(false, "道具 %s 有序列帧文件" % key)
			continue
		_check(true, "道具 %s 有序列帧文件" % key)
		var cell: Array = slot.get("cell", [48, 48])
		var frames: int = int(slot.get("frames", 1))
		var size := tex.get_size()
		_check(size.x == float(int(cell[0]) * frames) and size.y == float(int(cell[1])),
			"道具 %s 尺寸 = 帧数×单格（%dx%d）" % [key, int(size.x), int(size.y)])

	print("\n====== 矩形单格播放器 ======")
	var img := Image.create(96, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	var tex := ImageTexture.create_from_image(img)
	_check(Sheet.frame_count(tex) == 2, "96×48 在方形规则下只算 2 帧（所以要另一套）")
	var frames := FramesLib.frames_from_strip(tex, 24, 48, 4, 10.0, true)
	_check(frames.get_frame_count("play") == 4, "按 24×48 切成 4 帧（实际 %d）" % frames.get_frame_count("play"))
	var atlas := frames.get_frame_texture("play", 2) as AtlasTexture
	_check(atlas != null and atlas.region == Rect2(48, 0, 24, 48), "第 3 帧的矩形是 (48,0,24,48)")
	_check(is_equal_approx(frames.get_animation_speed("play"), 10.0), "播放速度按登记的 fps")
	var host := Node2D.new()
	root.add_child(host)
	var anim := FramesLib.make_animated(tex, 24, 48, 4, 10.0, true)
	host.add_child(anim)
	_check(anim.animation == "play" and anim.sprite_frames.get_frame_count("play") == 4, "AnimatedSprite2D 拿到 4 帧")

	print("\n通过 %d / 失败 %d" % [_pass, _fail])
	if _fail == 0:
		print("✅ 全部通过")
	else:
		print("❌ 有 %d 项没过" % _fail)
	quit(0 if _fail == 0 else 1)
