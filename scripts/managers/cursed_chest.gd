extends Node2D
## 受诅宝箱（局内事件 guard 的目标物）
##
## 房间中央的上锁宝箱：守卫全清后 open() 播放开箱动画并自我了结。
## 奖励本身由 room_event_manager 结算（保持"数值"与"演出"分离，
## 这样测试可以只断言数值，不用等动画）。
##
## 2026-11-09 第五轮：原来箱体是一个 ColorRect 纯色块 + 一个中文字"锁"，
## 场上根本不像宝箱。现在用美术贴图 assets/items/cursed_chest.png。

const AssetSlots = preload("res://scripts/core/asset_slots.gd")
const SpriteFramesLib = preload("res://scripts/core/sprite_frames_lib.gd")

var _opened: bool = false
var _chest: Node2D = null
var _chest_anim: AnimatedSprite2D = null

func _ready() -> void:
	add_to_group("event_chests")

	_chest = Node2D.new()
	_chest.name = "ChestVisual"
	add_child(_chest)

	# 箱体：优先用开箱序列帧（6 帧真的开一次），没有序列帧才退回单张美术贴图。
	var slot: Dictionary = AssetSlots.prop_sheet("cursed_chest")
	var sheet_path: String = String(slot.get("path", ""))
	var sheet_tex: Texture2D = null
	if sheet_path != "" and ResourceLoader.exists(sheet_path):
		sheet_tex = load(sheet_path) as Texture2D
	if sheet_tex != null:
		var cell: Array = slot.get("cell", [48, 40])
		var frames: int = int(slot.get("frames", 6))
		var anim := AnimatedSprite2D.new()
		anim.name = "ChestSheet"
		anim.sprite_frames = SpriteFramesLib.frames_from_strip(sheet_tex, int(cell[0]), int(cell[1]), frames, 10.0, false)
		anim.animation = "play"
		anim.frame = 0
		anim.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_chest.add_child(anim)
		_chest_anim = anim
	else:
		# 美术贴图（带锁、铁箍、木纹）
		var tex: Texture2D = TextureManager.instance.get_item_texture("cursed_chest")
		if tex != null:
			var spr := Sprite2D.new()
			spr.texture = tex
			spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			_chest.add_child(spr)
		else:
			# 回退：纯色块 + 金边（没有美术资源时的老样子）
			var box := ColorRect.new()
			box.color = Color(0.32, 0.2, 0.12)
			box.size = Vector2(40, 30)
			box.position = Vector2(-20, -15)
			box.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_chest.add_child(box)

			var edge := ColorRect.new()
			edge.color = Color(0.78, 0.6, 0.24)
			edge.size = Vector2(44, 4)
			edge.position = Vector2(-22, -17)
			edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_chest.add_child(edge)

	var name_label := Label.new()
	name_label.text = "受 诅 宝 箱"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.size = Vector2(80, 14)
	name_label.position = Vector2(-40, 18)
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.add_theme_color_override("font_color", Color(0.95, 0.72, 0.3))
	name_label.add_theme_color_override("font_outline_color", Color(0.04, 0.02, 0.03, 0.9))
	name_label.add_theme_constant_override("outline_size", 3)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(name_label)

	# 呼吸：静止物必须有轻微脉动才不会被当成背景贴图（同 powerup）
	var pulse := create_tween()
	pulse.set_loops()
	pulse.tween_property(_chest, "scale", Vector2(1.08, 1.08), 0.9).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(_chest, "scale", Vector2.ONE, 0.9).set_trans(Tween.TRANS_SINE)

func open() -> void:
	## 开箱演出：金色闪光、放大淡出。奖励在调用方结算。
	if _opened:
		return
	_opened = true
	AudioManager.play_sfx(AudioLib.get_sound("chest_open"))
	# 有开箱序列帧就先把它播完，再做闪光淡出
	if _chest_anim != null and is_instance_valid(_chest_anim):
		_chest_anim.play()
	var vfx := get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.spawn_hit_particles(global_position, Color(1.0, 0.85, 0.3), 5)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.3, 1.3), 0.35).set_trans(Tween.TRANS_BACK)
	tw.tween_property(self, "modulate:a", 0.0, 0.4)
	tw.tween_callback(queue_free)
	print("🔓 受诅宝箱开启")
