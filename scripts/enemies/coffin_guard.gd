extends "res://scripts/enemies/enemy_base.gd"
## 棺卫。第一次倒下会留下棺材，不打掉就会爬起来一次。随机精英词缀不叠在它身上。
## 立绘未到，借用石像鬼待机图并染成棺木棕。

var blocks_random_affix: bool = true
var revives_left: int = 1
var _coffin: Node = null
var _downed: bool = false

func _ready() -> void:
	base_hp = 22.0
	move_speed = 48.0
	base_contact_damage = 11.0
	xp_value = 8
	silver_value = 2
	super._ready()

func _load_sprite_texture() -> void:
	use_dedicated_sprite("coffin_guard", "idle", Color(0.55, 0.4, 0.28))

func _get_enemy_type() -> String:
	return "coffin_guard"

func _die() -> void:
	if _downed:
		return
	if revives_left > 0 and not _downed:
		revives_left -= 1
		_downed = true
		is_dead = true
		visible = false
		set_physics_process(false)
		if collision_shape:
			collision_shape.set_deferred("disabled", true)
		var contact := get_node_or_null("ContactArea/ContactShape") as CollisionShape2D
		if contact:
			contact.set_deferred("disabled", true)
		_coffin = preload("res://scripts/enemies/coffin_shell.gd").new()
		_coffin.owner_guard = self
		_coffin.global_position = global_position
		var parent := get_parent()
		if parent != null:
			parent.add_child(_coffin)
		return
	_finish()

func confirm_coffin_destroyed() -> void:
	_coffin = null
	_finish()

func revive_from_coffin() -> void:
	if not _downed:
		return
	_coffin = null
	_downed = false
	is_dead = false
	visible = true
	current_hp = max_hp * 0.55
	set_physics_process(true)
	if collision_shape:
		collision_shape.disabled = false
	var contact := get_node_or_null("ContactArea/ContactShape") as CollisionShape2D
	if contact:
		contact.disabled = false

func _finish() -> void:
	if not is_inside_tree():
		return
	_downed = true
	is_dead = false
	visible = true
	super._die()
