extends SceneTree
## 精灵横条：帧数、按格缩放、单张浮动
## 用法: godot --headless --path . --script res://tools/sprite_sheet_test.gd

const Sheet = preload("res://scripts/core/sprite_sheet.gd")

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


func _tex(w: int, h: int) -> Texture2D:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	return ImageTexture.create_from_image(img)


func _run() -> void:
	print("\n====== 精灵横条 ======")
	var square := _tex(1024, 1024)
	_check(Sheet.frame_count(square) == 1, "1024 方图是 1 帧")
	_check(is_equal_approx(Sheet.cell_size(square), 1024.0), "方图格子按长边")

	var idle := _tex(192, 48)
	_check(Sheet.frame_count(idle) == 4, "192×48 是 4 帧")
	_check(is_equal_approx(Sheet.cell_size(idle), 48.0), "横条格子用图高")

	var run := _tex(288, 48)
	_check(Sheet.frame_count(run) == 6, "288×48 是 6 帧")

	var broken := _tex(100, 40)
	_check(Sheet.frame_count(broken) == 1, "不能整除的图不当成横条")

	var host := Node2D.new()
	root.add_child(host)
	var sprite := Sprite2D.new()
	host.add_child(sprite)
	var scale := Sheet.apply(sprite, idle, 56.0)
	_check(sprite.hframes == 4 and sprite.vframes == 1 and sprite.frame == 0, "贴上后 hframes=4，从第 0 格开始")
	_check(is_equal_approx(scale.x, 56.0 / 48.0), "56px 目标按 48 的格子缩放，不按 192 的整宽")

	var wait := 0.0
	wait = Sheet.advance(sprite, wait, 0.125)
	_check(sprite.frame == 1, "8 帧/秒，0.125 秒前进 1 格（实际 %d）" % sprite.frame)
	wait = Sheet.advance(sprite, wait, 0.125 * 3.0)
	_check(sprite.frame == 0, "4 格播完回到 0（实际 %d）" % sprite.frame)

	var single := Sprite2D.new()
	host.add_child(single)
	Sheet.apply(single, square, 56.0)
	var wait_single := Sheet.advance(single, 0.0, 1.0)
	_check(single.hframes == 1 and single.frame == 0 and is_zero_approx(wait_single), "单张不切帧")
	_check(is_equal_approx(Sheet.apply(single, square, 56.0).x, 56.0 / 1024.0), "方图缩放仍是 56/1024")

	_check(is_equal_approx(Sheet.BOB_PIXELS, 1.0), "单张浮动幅度 1 像素")
	_check(is_equal_approx(Sheet.BOB_PERIOD, 1.2), "单张浮动周期 1.2 秒")
	_check(is_zero_approx(Sheet.bob_offset(0.0)), "浮动从 0 开始")
	_check(Sheet.bob_offset(0.3) > 0.0, "前半周期离开原点")

	Sheet.apply(sprite, idle, 56.0)
	var once: Array = Sheet.advance_once(sprite, 0.0, 0.125 * 4.0)
	_check(sprite.frame == 3 and bool(once[1]), "播一次停在最后一格（实际 %d）" % sprite.frame)
	var held: Array = Sheet.advance_once(sprite, 0.0, 0.5)
	_check(sprite.frame == 3 and bool(held[1]), "已经播完就不再绕回第 0 格")

	print("")
	print("通过 %d / 失败 %d" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
