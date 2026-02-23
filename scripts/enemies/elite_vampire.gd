extends "res://scripts/enemies/enemy_base.gd"
class_name EliteVampire
## 精英吸血鬼 — 带有随机词缀的强化敌人

enum Affix { SPEED, ARMOR, SPLIT }

var affix: Affix = Affix.SPEED
var is_elite: bool = true
var glow_tween: Tween = null

# 词缀效果
const SPEED_MULTIPLIER: float = 1.5
const ARMOR_REDUCTION: float = 0.5
const SPLIT_COUNT: int = 2

func _ready() -> void:
	# 随机选择词缀
	affix = Affix.values().pick_random()
	
	# 基础属性提升
	max_hp = 60.0
	move_speed = 80.0
	contact_damage = 15.0
	xp_value = 25
	
	# 应用词缀效果
	_apply_affix()
	
	super._ready()
	
	# 添加精英视觉效果
	_add_elite_visuals()

func _apply_affix() -> void:
	match affix:
		Affix.SPEED:
			move_speed *= SPEED_MULTIPLIER
			print("⚡ 精英吸血鬼：速度词缀")
		Affix.ARMOR:
			print("🛡️ 精英吸血鬼：护甲词缀")
		Affix.SPLIT:
			print("👥 精英吸血鬼：分裂词缀")

func _add_elite_visuals() -> void:
	# 根据词缀设置不同颜色
	var elite_color: Color
	match affix:
		Affix.SPEED:
			elite_color = Color(0.3, 0.8, 1.0, 1.0)  # 青色
		Affix.ARMOR:
			elite_color = Color(1.0, 0.8, 0.2, 1.0)  # 金色
		Affix.SPLIT:
			elite_color = Color(0.8, 0.3, 0.8, 1.0)  # 紫色
	
	# 发光效果
	glow_tween = create_tween().set_loops()
	glow_tween.tween_property(sprite, "modulate", elite_color, 0.5)
	glow_tween.tween_property(sprite, "modulate", Color.WHITE, 0.5)
	
	# 增大体型
	sprite.scale = Vector2(1.3, 1.3)

func take_damage(amount: float) -> void:
	if is_dead:
		return
	
	# 护甲词缀减少伤害
	var actual_damage := amount
	if affix == Affix.ARMOR:
		actual_damage *= (1.0 - ARMOR_REDUCTION)
	
	current_hp -= actual_damage
	_flash_hit()
	
	if current_hp <= 0:
		_die()

func _die() -> void:
	if is_dead:
		return
	
	# 分裂词缀：死亡时分裂
	if affix == Affix.SPLIT:
		_split()
	
	# 停止发光动画
	if glow_tween and glow_tween.is_valid():
		glow_tween.kill()
	
	# 调用父类死亡逻辑
	super._die()

func _split() -> void:
	print("👥 精英吸血鬼分裂!")
	
	for i in range(SPLIT_COUNT):
		var mini_vampire := preload("res://scenes/enemies/vampire.tscn").instantiate()
		if mini_vampire:
			# 在死亡位置周围随机生成
			var offset := Vector2(randf_range(-30, 30), randf_range(-30, 30))
			mini_vampire.global_position = global_position + offset
			
			# 缩小体型
			if mini_vampire.has_node("Sprite2D"):
				mini_vampire.get_node("Sprite2D").scale = Vector2(0.6, 0.6)
			
			# 减少属性
			if mini_vampire.has_method("max_hp"):
				mini_vampire.max_hp *= 0.5
				mini_vampire.current_hp = mini_vampire.max_hp
			
			get_tree().current_scene.call_deferred("add_child", mini_vampire)

func get_affix_name() -> String:
	match affix:
		Affix.SPEED:
			return "疾速"
		Affix.ARMOR:
			return "铁甲"
		Affix.SPLIT:
			return "分裂"
	return "未知"
