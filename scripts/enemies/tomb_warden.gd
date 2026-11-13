extends "res://scripts/enemies/boss_stage.gd"
## 墓穴守望者。结界还在就能把棺材里的东西拉起来。结界被打掉后不再复苏。

var ward: Node = null
var _sweep_timer: float = 1.6
var _sweep_left: float = 0.0
var _sweep_dir: Vector2 = Vector2.RIGHT
var _revive_cd: float = 3.0

func _ready() -> void:
	boss_title = "墓穴守望者"
	asset_id = "tomb_warden"
	boss_tier = 3
	move_speed = 58.0
	base_contact_damage = 14.0
	sprite_tint = Color(0.55, 0.62, 0.68)
	_boot_boss()
	_spawn_ward()

func _get_enemy_type() -> String:
	return "tomb_warden"

func _spawn_ward() -> void:
	ward = preload("res://scripts/enemies/ward_core.gd").new()
	ward.owner_boss = self
	var parent := get_parent()
	if parent == null:
		return
	parent.add_child(ward)
	ward.global_position = global_position + Vector2(120, 40)
	linked_nodes.append(ward)

func ward_broken() -> void:
	ward = null
	boss_phase_changed.emit(1)

func _physics_process(delta: float) -> void:
	if is_dead or intro_invulnerable or player == null:
		return
	var to_player := player.global_position - global_position
	velocity = to_player.normalized() * move_speed * (1.2 if ward == null else 0.7)
	move_and_slide()
	_sweep_timer -= delta
	_revive_cd -= delta
	if _sweep_left > 0.0:
		_sweep_left -= delta
		if _sweep_hits():
			player.take_damage(9.0)
	elif _sweep_timer <= 0.0:
		_sweep_dir = to_player.normalized()
		_sweep_left = 0.55
		_sweep_timer = 2.8
	if ward != null and _revive_cd <= 0.0:
		_revive_cd = 6.0
		_raise_one()

func _sweep_hits() -> bool:
	if player == null:
		return false
	var offset: Vector2 = player.global_position - global_position
	return offset.length() < 260.0 and absf(_sweep_dir.angle_to(offset)) < 0.35

func _raise_one() -> void:
	if get_tree().get_nodes_in_group("enemies").size() > 12:
		return
	var zombie = load("res://scenes/enemies/zombie.tscn").instantiate()
	zombie.global_position = global_position + Vector2(-40, 30)
	var parent := get_parent()
	if parent:
		parent.add_child(zombie)

func can_revive() -> bool:
	return ward != null and is_instance_valid(ward) and ward.get("is_dead") != true

func _die() -> void:
	if is_dead:
		return
	# main 的 boss_defeated 会同步清空 enemies 组；先退组才能保住死亡条带不被立刻清场。
	remove_from_group("enemies")
	_set_boss_collisions(false)
	if _contact_area != null:
		_contact_area.set_deferred("monitoring", false)
		_contact_area.set_deferred("monitorable", false)
	super._die()

func _play_death_visual() -> void:
	# 同血铠领主/织血母皇：boss_stage._die 不会自毁，这里必须自己 free，
	# 结界才会经 linked_nodes 在 _exit_tree 连带清理（<0.8s 自回收契约）。
	# 绑定本节点的 tween 随暂停冻结、随场景销毁取消；不依赖死后停掉的 _process。
	if sprite == null:
		queue_free()
		return
	var tween := create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.4)
	tween.tween_callback(queue_free)
