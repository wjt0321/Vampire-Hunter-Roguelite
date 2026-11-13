extends "res://scripts/enemies/enemy_base.gd"
## 盾卫。正面减伤，慢慢往前顶。绕到侧面或背后、或者用范围伤害，减伤就不生效。
## 立绘未到，借用僵尸行走图并染成铁灰。

var _hit_dir: Vector2 = Vector2.ZERO

func _ready() -> void:
	base_hp = 28.0
	move_speed = 38.0
	base_contact_damage = 12.0
	xp_value = 8
	silver_value = 2
	super._ready()

func _load_sprite_texture() -> void:
	use_placeholder_sprite("shield_guard", "idle", Color(0.62, 0.7, 0.82))

func _get_enemy_type() -> String:
	return "shield_guard"

func facing() -> Vector2:
	if player != null and is_instance_valid(player):
		var toward := player.global_position - global_position
		if toward.length_squared() > 1.0:
			return toward.normalized()
	return Vector2.LEFT

func is_frontal_hit(incoming: Vector2) -> bool:
	## 子弹飞行方向和「盾卫看向玩家」相反，说明打在盾面上。
	if incoming.length_squared() < 0.001:
		return false
	return facing().dot(incoming.normalized()) < -0.35

func take_damage_with_knockback(amount: float, knockback_dir: Vector2, knockback_force: float = 120.0, stun_duration: float = 0.08) -> void:
	_hit_dir = knockback_dir
	super.take_damage_with_knockback(amount, knockback_dir, knockback_force, stun_duration)
	_hit_dir = Vector2.ZERO

func _direct_damage(amount: float) -> float:
	amount = super._direct_damage(amount)
	if is_frontal_hit(_hit_dir):
		amount *= 0.25
	return amount
