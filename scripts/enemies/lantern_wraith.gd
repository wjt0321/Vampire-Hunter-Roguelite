extends "res://scripts/enemies/enemy_base.gd"
## 摄魂灯鬼。提灯发出一条直线光束，站在光束里会持续掉血。墙能挡住。

var _beam_timer: float = 1.2
var _beam_left: float = 0.0
var _beam_tick: float = 0.0
var _beam_dir: Vector2 = Vector2.RIGHT

func _ready() -> void:
	base_hp = 14.0
	move_speed = 48.0
	base_contact_damage = 5.0
	xp_value = 8
	super._ready()

func _load_sprite_texture() -> void:
	use_dedicated_sprite("lantern_wraith", "idle", Color(0.95, 0.72, 0.35))

func _get_enemy_type() -> String:
	return "lantern_wraith"

func _move_towards_player(delta: float) -> void:
	super._move_towards_player(delta)
	if player == null:
		return
	_beam_timer -= delta
	if _beam_left > 0.0:
		_beam_left -= delta
		_beam_tick -= delta
		if _beam_tick <= 0.0 and _beam_hits_player():
			_beam_tick = 0.25
			player.take_damage(7.0)
		return
	if _beam_timer <= 0.0:
		_beam_dir = (player.global_position - global_position).normalized()
		_beam_left = 0.7
		_beam_timer = 2.4
		# 提灯放光束：播光束动作条
		play_action_strip("lantern_wraith", "beam", "once")

func _beam_hits_player() -> bool:
	if player == null:
		return false
	var to_player: Vector2 = player.global_position - global_position
	if to_player.length() > 280.0:
		return false
	if absf(_beam_dir.angle_to(to_player)) > 0.18:
		return false
	return not _wall_between(player.global_position)

func _wall_between(dest: Vector2) -> bool:
	var world := get_world_2d()
	if world == null:
		return false
	var query := PhysicsRayQueryParameters2D.create(global_position, dest)
	query.exclude = [get_rid()]
	query.collision_mask = GameConfig.LAYER_WALL
	return not world.direct_space_state.intersect_ray(query).is_empty()
