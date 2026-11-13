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

func _die() -> void:
	if is_dead:
		return
	is_dead = true
	if prince != null and is_instance_valid(prince) and prince.has_method("colossus_fell"):
		prince.colossus_fell()
	enemy_died.emit(self)
	queue_free()
