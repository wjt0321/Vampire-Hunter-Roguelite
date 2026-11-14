class_name PropIdleAnim
extends Node2D
## 单帧道具的程序动效。
## 战斗房里没有序列帧的道具（书架/雕像/金币堆/招牌…）是死的：
## 整场只有角色和弹幕在动，静态摆件把房间衬得更僵（试玩反馈"动态帧僵硬"）。
## 这个脚本按 anim_style 给单帧贴图一个很轻的活气：
## 摆幅全部压在 2~3px / 2~3° 以内，一眼看不出在动，但房间不再是照片。
## 每件道具用随机相位，避免全场同步呼吸。

## breathe  : 轻微缩放呼吸（重家具/棺材/睡袋）
## shimmer  : 亮度微闪（金币堆，像火光扫过）
## glow     : 淡紫光脉动（祭坛）
## alpha_pulse : 透明度慢脉动（血迹，像刚渗开）
## swing    : 小角度摆动（悬挂招牌）
## sway     : 更轻的摇摆（蛛网）

var anim_style: String = "breathe"
var base_position: Vector2 = Vector2.ZERO
var base_scale: Vector2 = Vector2.ONE
var base_modulate: Color = Color.WHITE
var phase: float = 0.0

func _ready() -> void:
	base_position = position
	base_scale = scale
	base_modulate = modulate
	phase = randf() * TAU
	set_process(true)

func _process(_delta: float) -> void:
	var t: float = Time.get_ticks_msec() / 1000.0 + phase
	match anim_style:
		"shimmer":
			var s: float = 1.0 + 0.07 * sin(t * 2.3) * sin(t * 0.9 + 1.7)
			modulate = Color(base_modulate.r * s, base_modulate.g * s, base_modulate.b * s, base_modulate.a)
		"glow":
			var k: float = 0.5 + 0.5 * sin(t * 1.6)
			modulate = base_modulate.lerp(base_modulate * Color(1.15, 0.95, 1.35), k * 0.5)
		"alpha_pulse":
			modulate = Color(base_modulate.r, base_modulate.g, base_modulate.b,
				base_modulate.a * (0.82 + 0.18 * sin(t * 0.8)))
		"swing":
			rotation = deg_to_rad(2.4) * sin(t * 1.3)
		"sway":
			rotation = deg_to_rad(1.2) * sin(t * 0.9 + 0.6)
		_:
			var b: float = 1.0 + 0.012 * sin(t * 1.1)
			scale = base_scale * b
