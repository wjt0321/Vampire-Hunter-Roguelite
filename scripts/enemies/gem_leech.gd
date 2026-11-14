extends "res://scripts/enemies/enemy_base.gd"
## 吞晶虫。吃掉地上的经验后往远处跑。打死它会把经验吐出来，还多给一点。

var blocks_random_affix: bool = true
var stolen: int = 0

func _ready() -> void:
	base_hp = 12.0
	move_speed = 100.0
	base_contact_damage = 6.0
	xp_value = 4
	super._ready()

func _load_sprite_texture() -> void:
	use_dedicated_sprite("gem_leech", "idle", Color(0.85, 0.75, 0.25))

func _get_enemy_type() -> String:
	return "gem_leech"

func _move_towards_player(delta: float) -> void:
	if stolen <= 0:
		var gem := _nearest_gem()
		if gem != null:
			global_position = global_position.move_toward(gem.global_position, move_speed * delta)
			if global_position.distance_to(gem.global_position) < 18.0:
				stolen = int(gem.xp_value)
				gem.xp_value = 0
				gem.queue_free()
			return
	if player == null:
		return
	var away := (global_position - player.global_position).normalized()
	velocity = away * move_speed * 1.3
	move_and_slide()

func _die() -> void:
	if stolen > 0 and player != null and is_instance_valid(player) and player.has_method("gain_xp"):
		player.gain_xp(stolen + 4)
		stolen = 0
	super._die()

func _nearest_gem() -> Node2D:
	var best: Node2D = null
	var best_dist := INF
	for gem in get_tree().get_nodes_in_group("xp_gems"):
		if not is_instance_valid(gem) or int(gem.get("xp_value")) <= 0 or not (gem is Node2D):
			continue
		var dist := global_position.distance_squared_to((gem as Node2D).global_position)
		if dist < best_dist:
			best_dist = dist
			best = gem
	return best
