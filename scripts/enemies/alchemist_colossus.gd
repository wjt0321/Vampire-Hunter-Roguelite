extends "res://scripts/enemies/enemy_base.gd"
## 炼金巨像。和亲王互相改招：亲王先倒，巨像改砸地；巨像先倒，亲王改成贴脸。

var prince: Node = null
var enraged: bool = false
var _timer: float = 1.5

func _ready() -> void:
	base_hp = 220.0
	move_speed = 36.0
	base_contact_damage = 18.0
	xp_value = 20
	super._ready()
	add_to_group("boss_add")

func _load_sprite_texture() -> void:
	use_placeholder_sprite("furnace_golem", "idle", Color(0.25, 0.55, 0.32))
	_present_sprite(96.0)

func _get_enemy_type() -> String:
	return "alchemist_colossus"

func enrage() -> void:
	enraged = true
	move_speed = 70.0
	_timer = 0.4

func _physics_process(delta: float) -> void:
	if is_dead or player == null:
		return
	var to_player := player.global_position - global_position
	velocity = to_player.normalized() * move_speed
	move_and_slide()
	_timer -= delta
	if not enraged or _timer > 0.0:
		return
	_timer = 1.6
	if to_player.length() < 90.0 and player.has_method("take_damage"):
		player.take_damage(16.0)

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
	# 保住死亡演出不被立刻清场（巨像无人代清，自救是唯一回收路径）。
	remove_from_group("enemies")
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	if _contact_area != null:
		_contact_area.set_deferred("monitoring", false)
		_contact_area.set_deferred("monitorable", false)
	if prince != null and is_instance_valid(prince) and prince.has_method("colossus_fell"):
		prince.colossus_fell()
	enemy_died.emit(self)
	_play_death_visual()

func _play_death_visual() -> void:
	# TASK4 WIRE：真实 death 条带（_show_animation 起播 + _advance_death_frame 推 0→6 帧，
	# 0.6s）由 Task 4 接线并替换本占位淡出；本任务只保住 <0.8s 自回收契约：
	# 0.4s modulate 淡出后 queue_free（绑定本节点的 tween 随场景销毁取消）。
	if sprite == null:
		queue_free()
		return
	var tween := create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.4)
	tween.tween_callback(queue_free)
