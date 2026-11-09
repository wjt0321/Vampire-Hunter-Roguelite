extends Node2D
## 临时验收工具：把所有接线的贴图特效在固定网格上各播一次。
##
## 为什么要单独做场景：这些特效都是 0.2~0.9 秒的瞬时效果，
## 靠正常玩的时候截图基本抓不到（要正好卡在那一帧）。
## 这里给每张图 3 秒的停留时间，一次就能拍全。
##
## 用法：
##   godot --path . --write-movie shots/fx/f.png --fixed-fps 20 --quit-after 40 res://tools/_shot_fx.tscn

const FX_LIST: Array[String] = [
	"xp_collect", "levelup_aura", "boss_warning", "freeze_effect", "shield_break",
	"poison_spread", "chain_lightning", "thunder_wrath", "knife_tornado", "lightning_retaliate",
	"petrify_effect", "holy_light", "achievement_unlock", "wave_start", "dodge_afterimage",
]

func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.07, 0.09, 1.0)
	bg.size = Vector2(1280, 720)
	bg.z_index = -100
	add_child(bg)

	var vfx := get_node_or_null("/root/VFXManager")
	if vfx == null:
		push_error("VFXManager 不在")
		return

	const COLS := 5
	for i in FX_LIST.size():
		var name := FX_LIST[i]
		var col: int = i % COLS
		var row: int = i / COLS
		var pos := Vector2(140 + col * 250, 130 + row * 210)

		# 停留 3 秒不淡出，方便截帧
		vfx.spawn_texture_fx(name, pos, {
			"scale_from": 1.0, "scale_to": 1.0, "duration": 3.0, "fade_delay": 3.0,
		})

		var label := Label.new()
		label.text = name
		label.position = pos + Vector2(-70, 80)
		label.size = Vector2(140, 20)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", Color(0.85, 0.8, 0.7))
		add_child(label)
