extends "res://scripts/enemies/boss_stage.gd"
## 月蚀女王。换位前会标出落点。祭坛被毁掉后月相推进，安全圈缩小。

var altar: Node = null
var moon_phase: int = 0
var _blink_to: Vector2 = Vector2.ZERO
var _blinking: bool = false
var _timer: float = 1.4

func _ready() -> void:
	boss_title = "月蚀女王"
	asset_id = "eclipse_queen"
	boss_tier = 5
	move_speed = 80.0
	base_contact_damage = 14.0
	sprite_tint = Color(0.62, 0.48, 0.95)
	_boot_boss()
	_spawn_altar()

func _get_enemy_type() -> String:
	return "eclipse_queen"

func _spawn_altar() -> void:
	altar = preload("res://scripts/enemies/moon_altar.gd").new()
	altar.owner_boss = self
	var parent := get_parent()
	if parent == null:
		return
	parent.add_child(altar)
	altar.global_position = global_position + Vector2(-130, 50)

func altar_destroyed() -> void:
	altar = null
	moon_phase = 1
	boss_phase_changed.emit(1)

func _physics_process(delta: float) -> void:
	if is_dead or intro_invulnerable or player == null:
		return
	_timer -= delta
	if _blinking:
		if _timer <= 0.0:
			global_position = _blink_to
			_blinking = false
			_timer = 0.7 if moon_phase == 0 else 0.4
		return
	if current_hp < max_hp * 0.4 and moon_phase < 2:
		moon_phase = 2
		boss_phase_changed.emit(2)
	var to_player := player.global_position - global_position
	velocity = to_player.normalized() * move_speed
	move_and_slide()
	if _timer > 0.0:
		return
	_blink_to = player.global_position
	_blinking = true
	_timer = 0.45

func safe_radius() -> float:
	return 150.0 if moon_phase == 0 else 90.0
