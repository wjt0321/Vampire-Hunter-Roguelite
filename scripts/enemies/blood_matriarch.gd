extends "res://scripts/enemies/boss_stage.gd"
## 织血母皇。产卵、铺网，卵巢被清掉以后改成高机动近身，不再回到产卵阶段。
## 外观先用旧 Boss 待机图染成绛红。幼虫用现成的蝙蝠，数量有上限。

const EGG_CAP := 3
const WEB_CAP := 3
const LARVA_CAP := 3
const LarvaScene = preload("res://scenes/enemies/blood_larva.tscn")
## 6 帧动作的接触帧（第 3~4 帧）：动作第 0 帧只定种类，0.25s 后才真正落地
const CONTACT_DELAY := 0.25

var exposed: bool = false
var eggs_laid: int = 0
var _eggs: Array = []
var _larvae: Array = []
var _action_timer: float = 1.1
var _pending_kind: String = ""
var _pending_timer: float = -1.0

func _ready() -> void:
	boss_title = "织血母皇"
	asset_id = "blood_matriarch"
	boss_tier = 2
	move_speed = 62.0
	base_contact_damage = 12.0
	sprite_tint = Color(0.78, 0.22, 0.42)
	_boot_boss()

func _get_enemy_type() -> String:
	return "blood_matriarch"

func lay_egg() -> Node:
	if exposed or _living_eggs() >= EGG_CAP:
		return null
	var egg := preload("res://scripts/enemies/nest_egg.gd").new()
	egg.owner_boss = self
	var parent := get_parent()
	if parent == null:
		return null
	parent.add_child(egg)
	egg.global_position = global_position + Vector2(randf_range(-70, 70), randf_range(-40, 50))
	_eggs.append(egg)
	eggs_laid += 1
	return egg

func egg_destroyed(egg: Node) -> void:
	_eggs.erase(egg)
	if eggs_laid > 0 and _living_eggs() == 0:
		_expose()

func summon_larva() -> Node:
	if exposed or _living_larvae() >= LARVA_CAP:
		return null
	if get_parent() == null:
		return null
	var larva = LarvaScene.instantiate()
	larva.queen = self
	get_parent().add_child(larva)
	larva.global_position = global_position + Vector2(randf_range(-70, 70), randf_range(-40, 50))
	_larvae.append(larva)
	linked_nodes.append(larva)  # 母皇销毁时连带清理
	# 自然死亡钩子：enemy_base._die 发 enemy_died，这里做注销簿记；
	# 被直接 free 的幼虫由 _living_larvae 的 is_instance_valid 兜底。
	larva.connect("enemy_died", larva_destroyed)
	return larva

func _living_larvae() -> int:
	var count := 0
	for larva in _larvae:
		if is_instance_valid(larva) and larva.get("is_dead") != true:
			count += 1
	return count

func larva_destroyed(larva: Node) -> void:
	_larvae.erase(larva)
	linked_nodes.erase(larva)

func _expose() -> void:
	if exposed:
		return
	exposed = true
	move_speed = 120.0
	base_contact_damage = 18.0
	boss_phase_changed.emit(1)

func _living_eggs() -> int:
	var count := 0
	for egg in _eggs:
		if is_instance_valid(egg) and egg.get("is_dead") != true:
			count += 1
	return count

func drop_web() -> Node:
	if _web_count() >= WEB_CAP:
		return null
	var web := preload("res://scripts/enemies/web_patch.gd").new()
	var parent := get_parent()
	if parent == null:
		return null
	parent.add_child(web)
	web.global_position = global_position + Vector2(randf_range(-50, 50), 24)
	return web

func _web_count() -> int:
	var count := 0
	var script = preload("res://scripts/enemies/web_patch.gd")
	for node in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(node) and node.get_script() == script:
			count += 1
	return count

func _melee_strike() -> void:
	# 沿用血铠领主 _strike 的判定口径：96px / 0.7rad / 18 伤害。
	# 动画帧设置（_show_animation/_set_animation_frame）留给 Task 5 动画层。
	var forward := (player.global_position - global_position).normalized()
	for enemy in get_tree().get_nodes_in_group("player"):
		if not (enemy is Node2D):
			continue
		var offset: Vector2 = (enemy as Node2D).global_position - global_position
		if offset.length() > 96.0 or absf(forward.angle_to(offset)) > 0.7:
			continue
		if enemy.has_method("take_damage"):
			enemy.take_damage(18.0)

func _play_death_visual() -> void:
	# 同血铠领主的占位死亡：淡出 0.4s 后 queue_free（正式死亡动画由 Task 5 接上）。
	# boss_stage._die 不会自毁，这里必须自己 free，幼虫才会经 linked_nodes 连带清理。
	if sprite:
		var tween := create_tween()
		tween.tween_property(sprite, "modulate:a", 0.0, 0.4)
		tween.tween_callback(queue_free)

func _physics_process(delta: float) -> void:
	if is_dead or intro_invulnerable or player == null or not is_instance_valid(player):
		return
	# 延迟生成：动作第 0 帧只定种类，接触帧（0.25s 后）才真正召唤/产卵/铺网/挥击
	if _pending_timer >= 0.0:
		_pending_timer -= delta
		if _pending_timer < 0.0:
			match _pending_kind:
				"summon": summon_larva()
				"egg": lay_egg()
				"web": drop_web()
				"melee": _melee_strike()
			_pending_kind = ""
	var to_player := player.global_position - global_position
	var speed := move_speed * (1.35 if exposed else 0.7)
	if exposed or to_player.length() > 150.0:
		velocity = to_player.normalized() * speed
	else:
		velocity = (-to_player.normalized()) * speed * 0.8
	move_and_slide()
	_action_timer -= delta
	if _action_timer > 0.0:
		return
	_action_timer = 2.4
	if exposed:
		# 暴露后不再召唤/产卵/铺网，贴近（<=100px）就挥击
		if to_player.length() <= 100.0:
			_pending_kind = "melee"
			_pending_timer = CONTACT_DELAY
		return
	if _living_larvae() < LARVA_CAP:
		_pending_kind = "summon"
	elif _living_eggs() < EGG_CAP and eggs_laid < EGG_CAP + 1:
		_pending_kind = "egg"
	else:
		_pending_kind = "web"
	_pending_timer = CONTACT_DELAY
