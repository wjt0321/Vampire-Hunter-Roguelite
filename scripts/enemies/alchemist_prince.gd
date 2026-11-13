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
	colossus = preload("res://scripts/enemies/alchemist_colossus.gd").new()
	colossus.prince = self
	var parent := get_parent()
	if parent == null:
		return
	parent.add_child(colossus)
	colossus.global_position = global_position + Vector2(140, 20)
	linked_nodes.append(colossus)

func colossus_fell() -> void:
	colossus = null
	if is_dead:
		_finish_fight()
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

func _die() -> void:
	if is_dead:
		return
	is_dead = true
	visible = false
	set_physics_process(false)
	if colossus != null and is_instance_valid(colossus) and colossus.get("is_dead") != true:
		colossus.call("enrage")
		boss_phase_changed.emit(2)
		return
	_finish_fight()

func _finish_fight() -> void:
	boss_defeated.emit()
	enemy_died.emit(self)
