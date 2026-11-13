extends "res://scripts/enemies/enemy_base.gd"
## 主线 Boss 的共用登场、血条和死亡。每个 Boss 自己的状态机写在子类里。
## 不读 boss_variant。旧的三形态领主脚本不再服务新 Boss。

signal boss_hp_changed(current: float, max_val: float)
signal boss_defeated
signal boss_phase_changed(phase: int)
signal boss_intro_finished

var boss_title: String = "Boss"
var boss_tier: int = 1
var size_mult: float = 1.0
var skip_intro: bool = false
var intro_invulnerable: bool = true
var sprite_tint: Color = Color.WHITE

const INTRO_BAR_DELAY: float = 0.8
const INTRO_BAR_FILL: float = 0.9
const INTRO_DURATION: float = 1.9

func _boot_boss() -> void:
	base_hp = GameConfig.get_boss_hp(boss_tier)
	xp_value = 100
	silver_value = 12
	max_hp = base_hp * GameConfig.get_player_level_hp_scale(_get_player_level()) * GameConfig.get_abyss_hp_mult()
	loot_mult = GameConfig.get_abyss_loot_mult()
	current_hp = max_hp
	add_to_group("enemies")
	add_to_group("boss")
	_load_sprite_texture()
	_find_player()
	_contact_area = _find_contact_area()
	if skip_intro:
		intro_invulnerable = false
		boss_hp_changed.emit(current_hp, max_hp)
		boss_intro_finished.emit()
	else:
		_begin_intro()

func _load_sprite_texture() -> void:
	if sprite == null:
		return
	var texture: Texture2D = null
	if TextureManager.instance != null:
		texture = TextureManager.instance.get_boss_texture("idle")
	if texture != null:
		sprite.texture = texture
	else:
		_ensure_default_texture()
	sprite.modulate = sprite_tint
	using_placeholder = true
	placeholder_tint = sprite_tint
	_present_sprite(128.0 * size_mult)

func _begin_intro() -> void:
	intro_invulnerable = true
	current_hp = max_hp
	_set_boss_collisions(false)
	await get_tree().create_timer(INTRO_BAR_DELAY).timeout
	if is_dead:
		return
	boss_hp_changed.emit(0.0, max_hp)
	var tween := create_tween()
	tween.tween_method(_emit_intro_hp, 0.0, max_hp, INTRO_BAR_FILL)
	await get_tree().create_timer(maxf(INTRO_DURATION - INTRO_BAR_DELAY, 0.1)).timeout
	if is_dead or not intro_invulnerable:
		return
	intro_invulnerable = false
	_emit_intro_hp(max_hp)
	_set_boss_collisions(true)
	boss_intro_finished.emit()

func _emit_intro_hp(value: float) -> void:
	boss_hp_changed.emit(value, max_hp)

func _set_boss_collisions(enabled: bool) -> void:
	if collision_shape:
		collision_shape.set_deferred("disabled", not enabled)
	var contact := get_node_or_null("ContactArea/ContactShape") as CollisionShape2D
	if contact:
		contact.set_deferred("disabled", not enabled)

func take_damage(amount: float) -> void:
	if is_dead:
		return
	if intro_invulnerable:
		return
	amount = _subtract_hp(_direct_damage(amount))
	_after_damage_taken(amount)
	boss_hp_changed.emit(current_hp, max_hp)
	if current_hp <= 0.0:
		_die()
		return
	_flash_hit()

func take_damage_with_knockback(amount: float, _knockback_dir: Vector2, _knockback_force: float = 120.0, _stun_duration: float = 0.08) -> void:
	take_damage(amount)

func _die() -> void:
	if is_dead:
		return
	is_dead = true
	AudioManager.play_sfx(AudioLib.get_sound("enemy_death"))
	enemy_died.emit(self)
	boss_defeated.emit()
	_drop_xp_gem()
	_drop_silver()
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	set_physics_process(false)
	if sprite:
		var tween := create_tween()
		tween.tween_property(sprite, "modulate:a", 0.0, 0.4)
