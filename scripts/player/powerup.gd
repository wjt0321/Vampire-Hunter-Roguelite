extends Node2D
## 战斗中的临时增益（地面掉落物）
##
## 和银币/经验宝石共用"Node2D + 距离判定"这套最省的方案，不挂 Area2D。
## 为什么需要它：战斗房里除了"杀与被杀"没有任何中场事件，
## 玩家 30 秒里只有输出循环，没有"现在该不该冲过去拿"的判断。
## 一个有代价的增益（要走位去吃）能把站桩输出变成小决策。
##
## 三种增益各有用途：
##   ❤️ 血露   —— 立即回血，把"残血但还能打"变成可选项
##   ⚔️ 狂暴   —— 8 秒伤害 ×1.5，鼓励在有怪时开
##   🧲 磁力   —— 立刻收走全屏经验与银币，解决"清完场要跑图捡钱"

const KINDS: Dictionary = {
	"heal": {"icon": "血", "color": Color(1.0, 0.36, 0.42), "label": "血露"},
	"frenzy": {"icon": "狂", "color": Color(1.0, 0.62, 0.2), "label": "狂暴"},
	"magnet": {"icon": "磁", "color": Color(0.52, 0.8, 1.0), "label": "磁力"},
}

## 增益类型（生成前设置）
var kind: String = "heal"

var attraction_speed: float = 300.0
var base_attraction_range: float = 86.0
## 存活上限：到点消失，不自动拾取（不然等于白送，失去"要不要过去"的决策）
var lifetime: float = 16.0

var _player: Node2D = null
var _age: float = 0.0
var _attracted: bool = false
var _sprite: Sprite2D = null

func _ready() -> void:
	add_to_group("powerups")
	var data: Dictionary = KINDS.get(kind, KINDS["heal"])
	var color: Color = data["color"]

	# 底：菱形宝石（和经验宝石同一套贴图，玩家已经认得"地上发光的东西"）
	_sprite = Sprite2D.new()
	_sprite.name = "PowerupSprite"
	add_child(_sprite)
	ProjectileVisuals.style_gem(_sprite, color, 34.0)

	# 图标：用中文字而不是 emoji。
	# 项目字体是 NotoSansCJKsc（不含 emoji 字形），emoji 在这台机器上渲染成空白方块，
	# 玩家完全分不出三种增益——这个坑只有截图能看出来，无头测试永远发现不了。
	var icon := Label.new()
	icon.text = String(data["icon"])
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon.size = Vector2(34, 34)
	icon.position = Vector2(-17, -18)
	icon.add_theme_font_size_override("font_size", 16)
	icon.add_theme_color_override("font_color", Color(1, 1, 1, 0.98))
	icon.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.04, 0.95))
	icon.add_theme_constant_override("outline_size", 4)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(icon)

	# 名称：颜色跟类型走，和图标形成"双编码"，色盲玩家也能靠字认出来
	var name_label := Label.new()
	name_label.text = String(data["label"])
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.size = Vector2(60, 14)
	name_label.position = Vector2(-30, 16)
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.add_theme_color_override("font_color", color)
	name_label.add_theme_color_override("font_outline_color", Color(0.04, 0.02, 0.03, 0.9))
	name_label.add_theme_constant_override("outline_size", 3)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(name_label)

	# 呼吸：和宝石一样，静止物必须有轻微脉动才不会被当成背景贴图
	var pulse := create_tween()
	pulse.set_loops()
	pulse.tween_property(_sprite, "scale", Vector2(1.14, 1.14), 0.8).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(_sprite, "scale", Vector2.ONE, 0.8).set_trans(Tween.TRANS_SINE)

	print("✨ 场上出现增益：%s" % String(data["label"]))

func _process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return

	if _player == null or not is_instance_valid(_player):
		var players := get_tree().get_nodes_in_group("player")
		if players.is_empty():
			return
		_player = players[0]
		return

	var dist := global_position.distance_to(_player.global_position)
	var range_now := base_attraction_range
	if "pickup_range" in _player:
		range_now += float(_player.pickup_range) * 0.4

	if dist < 20.0:
		_collect()
		return
	if dist < range_now:
		_attracted = true
	if _attracted:
		global_position = global_position.move_toward(_player.global_position, attraction_speed * delta)

func _collect() -> void:
	if _player != null and is_instance_valid(_player):
		match kind:
			"heal":
				_apply_heal()
			"frenzy":
				_apply_frenzy()
			"magnet":
				_apply_magnet()
	var vfx := get_node_or_null("/root/VFXManager")
	if vfx:
		var color: Color = KINDS.get(kind, KINDS["heal"])["color"]
		vfx.spawn_hit_particles(global_position, color, 3)
	queue_free()

func _apply_heal() -> void:
	var amount: float = float(_player.max_hp) * GameConfig.POWERUP_HEAL_RATIO
	if _player.has_method("heal"):
		_player.heal(amount)
	print("❤️ 血露：恢复 %.0f 生命" % amount)

func _apply_frenzy() -> void:
	if _player.has_method("apply_powerup_buff"):
		_player.apply_powerup_buff(GameConfig.POWERUP_FRENZY_MULT, GameConfig.POWERUP_FRENZY_DURATION)

func _apply_magnet() -> void:
	## 直接把全场经验/银币拉向玩家一次，而不是原地收走：
	## 让玩家看到"钱被吸过来"的动画，比数字突然跳一下更有反馈
	var pulled := 0
	var origin: Vector2 = _player.global_position
	for group in ["xp_gems", "silver_coins"]:
		for node in get_tree().get_nodes_in_group(group):
			if not is_instance_valid(node):
				continue
			var d: float = node.global_position.distance_to(origin)
			# 只吸 900px 内的，屏幕上看得见的那些
			if d > 900.0:
				continue
			node.global_position = origin + (node.global_position - origin).normalized() * randf_range(6.0, 24.0)
			pulled += 1
	print("🧲 磁力脉冲：吸取 %d 个掉落物" % pulled)
