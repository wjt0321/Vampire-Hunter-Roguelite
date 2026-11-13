extends "res://scripts/enemies/boss_stage.gd"
## 炼金亲王。和巨像是两个目标。先倒下一个，另一个会换一套招，而不是只加快。

var colossus: Node = null
var _mode: String = "pair"
var _timer: float = 1.2

func _ready() -> void:
	boss_title = "炼金亲王"
	asset_id = "alchemist_prince"
	boss_tier = 4
	move_speed = 78.0
	base_contact_damage = 12.0
	sprite_tint = Color(0.4, 0.78, 0.48)
	_boot_boss()
	_spawn_colossus()

func _get_enemy_type() -> String:
	return "alchemist_prince"

func _spawn_colossus() -> void:
	var parent := get_parent()
	if parent == null:
		return
	colossus = preload("res://scenes/enemies/alchemist_colossus.tscn").instantiate()
	colossus.prince = self
	parent.add_child(colossus)
	colossus.global_position = global_position + Vector2(140, 20)
	linked_nodes.append(colossus)

func colossus_fell() -> void:
	colossus = null
	if is_dead:
		_finish_fight()
		# 留尸路线的最终回收点：此时死亡条带早已播完（0.4s < 等待时长），
		# 双标志俱备 → 立即自回收，不再重播演出。
		_try_self_recycle()
		return
	_mode = "solo_prince"
	boss_phase_changed.emit(1)

func _physics_process(delta: float) -> void:
	if is_dead or intro_invulnerable or player == null:
		return
	var to_player := player.global_position - global_position
	velocity = to_player.normalized() * (140.0 if _mode == "solo_prince" else move_speed)
	move_and_slide()
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = 2.2 if _mode == "pair" else 1.3
	_toss(player.global_position)

func _toss(at: Vector2) -> void:
	var puddle = preload("res://scripts/map/potion_puddle.gd").new()
	puddle.damage = 10.0
	puddle.global_position = at
	var parent := get_parent()
	if parent:
		parent.add_child(puddle)

# 死亡演出播完标志：条带（本任务为占位淡出）播完置 true。
var _death_visual_done: bool = false
# _finish_fight 已发生标志：boss_defeated 必须先于亲王 queue_free 发出。
var _finish_fight_called: bool = false
# TASK4 WIRE：以下为 Task 4 动画层的占位预留（与守望者/母皇同名接口对齐），
# 本任务不实现动画机制；注入的表不参与任何渲染路径。
var _animation_textures: Dictionary = {}
func _show_animation(_state: String) -> void:
	pass
func _advance_death_frame(_progress: float) -> void:
	pass

func _die() -> void:
	if is_dead:
		return
	is_dead = true
	# main 的 boss_defeated 会同步清空 enemies 组；先退组 + 关碰撞，
	# 保住死亡演出不被立刻清场（退组后 main 清场扫不到，回收责任移到这里）。
	remove_from_group("enemies")
	_set_boss_collisions(false)
	if _contact_area != null:
		_contact_area.set_deferred("monitoring", false)
		_contact_area.set_deferred("monitorable", false)
	set_physics_process(false)
	if colossus != null and is_instance_valid(colossus) and colossus.get("is_dead") != true:
		# 留尸契约：巨像存活时亲王不 queue_free，照常 enrage，契约一行不动。
		colossus.call("enrage")
		boss_phase_changed.emit(2)
		_play_death_visual()
		return
	_finish_fight()
	_play_death_visual()

func _play_death_visual() -> void:
	# TASK4 WIRE：真实 death 条带 0→6 帧（0.6s）播完转 invisible 由 Task 4 接线；
	# 本任务用 0.4s 占位淡出，播完 invisible（替代旧实现的立即 invisible），
	# 再走 _on_death_visual_finished 统一收口。
	if sprite == null:
		_on_death_visual_finished()
		return
	var tween := create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.4)
	tween.tween_callback(_on_death_visual_finished)

func _on_death_visual_finished() -> void:
	visible = false
	_death_visual_done = true
	_try_self_recycle()

func _try_self_recycle() -> void:
	# 统一收口：演出播完且战斗已结算（_finish_fight 已发 boss_defeated）才自行回收。
	if _death_visual_done and _finish_fight_called:
		queue_free()

func _finish_fight() -> void:
	_finish_fight_called = true
	boss_defeated.emit()
	enemy_died.emit(self)
