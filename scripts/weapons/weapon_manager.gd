extends Node
class_name WeaponManager
## 武器管理器

const WeaponDataScript = preload("res://scripts/weapons/weapon_data.gd")
const WeaponEvolutionScript = preload("res://scripts/weapons/weapon_evolution.gd")
const OrbitBladeScript = preload("res://scripts/weapons/orbit_blade.gd")

# 场景预加载常量
const KnifeBulletScene = preload("res://scenes/player/knife_bullet.tscn")
const PoisonCloudScene = preload("res://scenes/player/poison_cloud.tscn")
const LightningChainScene = preload("res://scenes/player/lightning_chain.tscn")
const CrossbowBoltScene = preload("res://scenes/player/crossbow_bolt.tscn")
const HolyBoltScene = preload("res://scenes/player/holy_bolt.tscn")

var weapons: Array = []
var weapon_evolutions: Dictionary = {}  # weapon_id -> WeaponEvolution
var shoot_timers: Dictionary = {}
var player: CharacterBody2D = null
var bullet_scene: PackedScene = preload("res://scenes/player/bullet.tscn")
## 环绕刀刃实例（进化飞刀）。同一时间只保留一组，避免重复叠加。
var _orbit_blades: Array = []

# 缓存的 AudioLibrary 实例
var _audio_lib: AudioLibrary = null

# 缓存当前场景根节点，避免频繁 get_tree().current_scene
var _current_scene: Node = null

# 敌人方向缓存（降低每帧扫描开销）
var _nearest_enemy_dir: Vector2 = Vector2.ZERO
var _nearest_enemy_pos: Vector2 = Vector2.ZERO
var _enemy_cache_timer: float = 0.0
const ENEMY_CACHE_INTERVAL: float = 0.15

signal weapon_added(weapon: Resource)
signal weapon_leveled_up(weapon: Resource)
signal weapon_evolved(weapon: Resource, evolution: WeaponEvolution)

# 进化条件配置
# 进化 = 武器满级 + 指定被动至少 Lv1 + 打开宝箱（事件触发）。
# 以前是"击杀数 50 自动进化"，玩家看不见进度、也无法为它做取舍，已废弃。
# behavior 是"行为级差异"，不是数值堆叠：
#   double_barrel → 双管齐射（并排两发，横向覆盖）
#   orbit         → 刀阵环绕（飞刀围绕玩家旋转，持续接触伤害）
#   radial        → 环形弹幕（放弃瞄准，向四周均匀喷射）
const EVOLUTION_CONFIG: Dictionary = {
	"pistol": {
		"evolution_name": "神圣双管",
		"evolution_description": "并排双发，横向覆盖翻倍",
		"evolution_icon": "✨",
		"required_passive_items": ["lucky_clover"],
		"damage_multiplier": 2.4,
		"fire_rate_multiplier": 0.45,
		"size_multiplier": 1.3,
		"special_effect": "双管齐射",
		"behavior": "double_barrel",
	},
	"shotgun": {
		"evolution_name": "毁灭者",
		"evolution_description": "散射更多子弹，覆盖更广范围",
		"evolution_icon": "💥",
		"required_passive_items": ["berserker_blood"],
		"damage_multiplier": 2.5,
		"fire_rate_multiplier": 0.4,
		"size_multiplier": 1.3,
		"special_effect": "额外散射",
		"behavior": "",
	},
	"magic_book": {
		"evolution_name": "大魔导书",
		"evolution_description": "放弃瞄准，向四周倾泻环形弹幕",
		"evolution_icon": "📚",
		"required_passive_items": ["magnet"],
		"damage_multiplier": 2.2,
		"fire_rate_multiplier": 0.5,
		"size_multiplier": 1.4,
		"special_effect": "环形弹幕",
		"behavior": "radial",
	},
	"throwing_knife": {
		"evolution_name": "刀阵旋风",
		"evolution_description": "飞刀不再掷出，而是环绕你旋转绞杀",
		"evolution_icon": "🌪️",
		"required_passive_items": ["swift_boots"],
		"damage_multiplier": 2.0,
		"fire_rate_multiplier": 0.5,
		"size_multiplier": 1.5,
		"special_effect": "刀阵环绕",
		"behavior": "orbit",
	},
	"poison_cloud": {
		"evolution_name": "瘟疫之源",
		"evolution_description": "更大范围的致命毒雾",
		"evolution_icon": "☣️",
		"required_passive_items": ["regeneration"],
		"damage_multiplier": 2.5,
		"fire_rate_multiplier": 0.5,
		"size_multiplier": 2.0,
		"special_effect": "范围扩大",
		"behavior": "",
	},
	"lightning_chain": {
		"evolution_name": "雷神之怒",
		"evolution_description": "全屏闪电链",
		"evolution_icon": "🌩️",
		"required_passive_items": ["lightning_shield"],
		"damage_multiplier": 3.0,
		"fire_rate_multiplier": 0.4,
		"size_multiplier": 1.5,
		"special_effect": "全屏连锁",
		"behavior": "",
	},
	"crossbow": {
		"evolution_name": "圣光弩",
		"evolution_description": "穿透力更强的神圣弩箭",
		"evolution_icon": "🏹",
		"required_passive_items": ["lucky_clover"],
		"damage_multiplier": 2.5,
		"fire_rate_multiplier": 0.4,
		"size_multiplier": 1.3,
		"special_effect": "穿透强化",
		"behavior": "",
	},
	"holy_wand": {
		"evolution_name": "大天使之杖",
		"evolution_description": "自动追踪多个敌人的圣光弹",
		"evolution_icon": "✨",
		"required_passive_items": ["regeneration"],
		"damage_multiplier": 2.5,
		"fire_rate_multiplier": 0.4,
		"size_multiplier": 1.4,
		"special_effect": "神圣追踪",
		"behavior": "",
	},
	"kunai": {
		"evolution_name": "影刃风暴",
		"evolution_description": "高速投掷的暗影苦无",
		"evolution_icon": "🗡️",
		"required_passive_items": ["shadow_cloak"],
		"damage_multiplier": 1.8,
		"fire_rate_multiplier": 0.6,
		"size_multiplier": 1.2,
		"special_effect": "极速连投",
		"behavior": "",
	},
	"flame_thrower": {
		"evolution_name": "地狱火",
		"evolution_description": "永不熄灭的烈焰喷流",
		"evolution_icon": "🔥",
		"required_passive_items": ["berserker_blood"],
		"damage_multiplier": 2.0,
		"fire_rate_multiplier": 0.7,
		"size_multiplier": 1.6,
		"special_effect": "持续灼烧",
		"behavior": "",
	},
	"blood_burst": {
		"evolution_name": "血海",
		"evolution_description": "以血为引的范围爆发",
		"evolution_icon": "🩸",
		"required_passive_items": ["vampiric_fang"],
		"damage_multiplier": 2.2,
		"fire_rate_multiplier": 0.7,
		"size_multiplier": 1.8,
		"special_effect": "血腥爆发",
		"behavior": "",
	},
}

func setup(player_node: CharacterBody2D, initial_weapon_id: String = "pistol") -> void:
	player = player_node
	_audio_lib = AudioLib
	_ensure_current_scene()
	var initial_weapon = _create_weapon_by_id(initial_weapon_id)
	if initial_weapon:
		add_weapon(initial_weapon)
	else:
		var pistol := _create_pistol()
		add_weapon(pistol)

func _ensure_current_scene() -> void:
	if _current_scene == null or not is_instance_valid(_current_scene):
		_current_scene = get_tree().current_scene

func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	
	# 定期刷新最近敌人缓存
	_enemy_cache_timer += delta
	if _enemy_cache_timer >= ENEMY_CACHE_INTERVAL:
		_enemy_cache_timer = 0.0
		_refresh_enemy_cache()
	
	for weapon in weapons:
		var timer_key: String = weapon.weapon_id
		if shoot_timers.has(timer_key):
			var timer: Timer = shoot_timers[timer_key]
			if timer.is_stopped():
				_fire_weapon(weapon)
				timer.start(weapon.get_scaled_fire_rate())

func add_weapon(weapon_data) -> void:
	if weapon_data == null:
		# ItemCatalog 里不存在的 id（例如起始武器 "pistol"）会造出 null，
		# 直接往下走会崩在 existing.weapon_id 上，这里挡一道。
		push_warning("add_weapon 收到 null，已忽略")
		return
	for existing in weapons:
		if existing.weapon_id == weapon_data.weapon_id:
			if existing.level_up():
				weapon_leveled_up.emit(existing)
				if existing.is_max_level():
					# 满级时创建进化数据
					_create_weapon_evolution(existing)
				print("武器升级: %s Lv.%d" % [existing.weapon_name, existing.current_level])
			return
	weapons.append(weapon_data)

	# 记录武器使用类型（成就统计）
	var ach_mgr := get_node_or_null("/root/AchievementManager")
	if ach_mgr:
		ach_mgr.record_weapon_used(weapon_data.weapon_id)

	var timer := Timer.new()
	timer.wait_time = weapon_data.get_scaled_fire_rate()
	timer.one_shot = true
	add_child(timer)
	shoot_timers[weapon_data.weapon_id] = timer
	weapon_added.emit(weapon_data)
	print("获得武器: %s" % weapon_data.weapon_name)

func _create_weapon_evolution(weapon) -> void:
	## 为满级武器创建进化数据
	if weapon_evolutions.has(weapon.weapon_id):
		return
	
	var config: Dictionary = EVOLUTION_CONFIG.get(weapon.weapon_id, {})
	if config.is_empty():
		return
	
	var evolution := WeaponEvolutionScript.new()
	evolution.evolution_name = config.get("evolution_name", "进化武器")
	evolution.evolution_description = config.get("evolution_description", "")
	evolution.evolution_icon = config.get("evolution_icon", "✨")
	evolution.required_passive_items = config.get("required_passive_items", [])
	evolution.required_kill_count = config.get("required_kill_count", 50)
	# 进化倍率统一钳制到设计区间，避免单次进化让 DPS 指数爆炸
	evolution.damage_multiplier = clampf(
		config.get("damage_multiplier", 2.0),
		GameConfig.EVOLUTION_DAMAGE_MIN, GameConfig.EVOLUTION_DAMAGE_MAX)
	evolution.fire_rate_multiplier = clampf(
		config.get("fire_rate_multiplier", 0.8),
		GameConfig.EVOLUTION_FIRE_RATE_MIN, GameConfig.EVOLUTION_FIRE_RATE_MAX)
	evolution.size_multiplier = clampf(
		config.get("size_multiplier", 1.5),
		GameConfig.EVOLUTION_SIZE_MIN, GameConfig.EVOLUTION_SIZE_MAX)
	evolution.special_effect = config.get("special_effect", "")
	evolution.behavior = String(config.get("behavior", ""))
	
	weapon_evolutions[weapon.weapon_id] = evolution
	print("⚔️ %s 已达到满级，满足条件后可进化为 %s（需被动：%s）" % [
		weapon.weapon_name,
		evolution.evolution_name,
		_passive_names(evolution.required_passive_items)
	])

func _passive_names(ids: Array) -> String:
	var names: Array = []
	for id in ids:
		names.append(ItemCatalog.get_display_name(String(id)))
	return "、".join(names) if not names.is_empty() else "无"

func get_evolution_status(owned_passives: Array) -> Dictionary:
	## 进化准备度（HUD 三态）：
	##   none    —— 没有任何武器满级
	##   waiting —— 有满级武器，但缺被动（missing 给出名字）
	##   ready   —— 全部条件满足，开宝箱即可进化
	if weapon_evolutions.is_empty():
		return {"state": "none", "text": ""}

	for weapon_id in weapon_evolutions:
		var evolution: WeaponEvolution = weapon_evolutions[weapon_id]
		if evolution.is_evolved:
			continue
		var missing: Array = evolution.get_missing_passives(owned_passives)
		if missing.is_empty():
			return {
				"state": "ready",
				"weapon_id": weapon_id,
				"text": "宝箱可进化：%s" % evolution.evolution_name,
			}

	# 没有 ready 的，退回"缺被动"提示，取第一个满级未进化武器
	for weapon_id in weapon_evolutions:
		var evolution: WeaponEvolution = weapon_evolutions[weapon_id]
		if evolution.is_evolved:
			continue
		var missing: Array = evolution.get_missing_passives(owned_passives)
		return {
			"state": "waiting",
			"weapon_id": weapon_id,
			"text": "进化 %s：还差 %s" % [
				evolution.evolution_name,
				_passive_names(missing),
			],
		}

	return {"state": "none", "text": ""}

func get_ready_evolutions(owned_passives: Array) -> Array:
	## 返回所有"满级 + 被动齐"的 weapon_id
	var ready: Array = []
	for weapon_id in weapon_evolutions:
		var evolution: WeaponEvolution = weapon_evolutions[weapon_id]
		if evolution.is_evolved:
			continue
		if evolution.can_evolve(owned_passives):
			ready.append(weapon_id)
	return ready

func try_evolve_from_chest(owned_passives: Array) -> Array:
	## 打开宝箱时调用：把所有满足条件的武器进化掉。
	## 返回值供 UI/音效消费：[{weapon_id, name}]
	var evolved: Array = []
	for weapon_id in get_ready_evolutions(owned_passives):
		var evolution: WeaponEvolution = weapon_evolutions[weapon_id]
		var evo_name: String = evolution.evolution_name
		_evolve_weapon(weapon_id, evolution)
		evolved.append({"weapon_id": weapon_id, "name": evo_name})
		if evolution.behavior == "orbit":
			_spawn_orbit_blades(weapon_id)
	return evolved

func _evolve_weapon(weapon_id: String, evolution: WeaponEvolution) -> void:
	## 执行武器进化
	evolution.evolve()

	# 找到对应的武器
	for weapon in weapons:
		if weapon.weapon_id == weapon_id:
			# 更新武器属性
			weapon.base_damage = evolution.get_evolved_damage(weapon.base_damage)
			weapon.fire_rate = evolution.get_evolved_fire_rate(weapon.fire_rate)
			# 更新武器显示名称
			weapon.weapon_name = evolution.evolution_name
			weapon.description = evolution.evolution_description
			weapon.icon_emoji = evolution.evolution_icon

			# 更新计时器
			if shoot_timers.has(weapon_id):
				shoot_timers[weapon_id].wait_time = weapon.get_scaled_fire_rate()

			weapon_evolved.emit(weapon, evolution)
			print("✨ %s 已进化为 %s!" % [weapon_id, evolution.evolution_name])

			# 视觉与音效反馈
			var vfx := get_node_or_null("/root/VFXManager")
			if vfx and player and is_instance_valid(player):
				var theme_color := _get_evolution_color(weapon_id)
				vfx.spawn_evolution_effect(player.global_position, theme_color)
				vfx.screen_shake(6.0, 0.35)

			# 播放进化音效
			AudioManager.play_sfx(_audio_lib.get_sound("level_up"))
			break

func _get_evolution_color(weapon_id: String) -> Color:
	match weapon_id:
		"pistol":
			return Color(1.0, 0.9, 0.4, 0.9)   # 神圣金
		"shotgun":
			return Color(1.0, 0.4, 0.2, 0.9)   # 爆裂橙红
		"magic_book":
			return Color(0.8, 0.3, 0.9, 0.9)   # 魔导紫
		"throwing_knife":
			return Color(0.4, 0.9, 0.95, 0.9)  # 刀阵青
		"poison_cloud":
			return Color(0.4, 0.9, 0.3, 0.9)   # 瘟疫绿
		"lightning_chain":
			return Color(1.0, 0.95, 0.3, 0.9)  # 雷电黄
		"crossbow":
			return Color(0.95, 0.85, 0.4, 0.9) # 圣光金
		"holy_wand":
			return Color(0.9, 0.95, 1.0, 0.9)  # 圣洁白
		"kunai":
			return Color(0.45, 0.55, 0.75, 0.9) # 暗影蓝
		"flame_thrower":
			return Color(1.0, 0.45, 0.1, 0.9)   # 烈焰橙
		"blood_burst":
			return Color(0.7, 0.05, 0.1, 0.9)   # 血海红
	return Color(1.0, 0.85, 0.3, 0.9)

func get_projectile_visual(weapon_id: String) -> Dictionary:
	## 弹道外观配置：颜色 / 视觉长度 / 视觉厚度 / 是否圆形
	## 视觉尺寸刻意比碰撞体大一圈——"看着够大、判定不亏"，
	## 这是让玩家觉得弹道看得清、又不会因为贴图变大而变难的关键。
	## 2026-11-08 试玩反馈"自己的投射物太细，很难命中"：
	## 长条弹厚度 5~6 → 8~9，长度也各加 2px。配合 projectile_visuals 里
	## 亮芯占比 0.16→0.30，屏幕上的实心部分从不到 2px 变成 5px 左右。
	match weapon_id:
		"shotgun":
			return {"color": Color(1.0, 0.62, 0.22), "length": 13.0, "thickness": 9.0, "round": false}
		"magic_book":
			return {"color": Color(0.72, 0.42, 1.0), "length": 16.0, "thickness": 10.0, "round": true}
		"throwing_knife":
			return {"color": Color(0.75, 0.9, 1.0), "length": 24.0, "thickness": 8.0, "round": false}
		"crossbow":
			return {"color": Color(1.0, 0.93, 0.55), "length": 28.0, "thickness": 9.0, "round": false}
		"holy_wand":
			return {"color": Color(1.0, 0.97, 0.72), "length": 16.0, "thickness": 10.0, "round": true}
		"kunai":
			return {"color": Color(0.62, 0.74, 1.0), "length": 18.0, "thickness": 8.0, "round": false}
		"flame_thrower":
			return {"color": Color(1.0, 0.44, 0.12), "length": 14.0, "thickness": 9.0, "round": true}
	# 手枪 / 默认
	return {"color": Color(1.0, 0.86, 0.35), "length": 18.0, "thickness": 9.0, "round": false}

func get_weapon_evolution(weapon_id: String) -> WeaponEvolution:
	return weapon_evolutions.get(weapon_id, null)
func is_weapon_evolved(weapon_id: String) -> bool:
	if weapon_evolutions.has(weapon_id):
		return weapon_evolutions[weapon_id].is_evolved
	return false

func estimate_run_dps() -> float:
	## 粗略估算当前构筑的理论 DPS（不含暴击，由调用方再乘）。
	## 用途只有一个：给难度软挂钩当自变量，所以**只要单调、便宜**就够，
	## 不需要精确——毒雾/闪电链/刀阵这类特殊行为用统一公式近似。
	## 刻意不去统计真实伤害：take_damage 有 4 个子类覆写，打点必然漏，
	## 而漏掉的伤害会让"玩家明明很强却被判成弱"。
	var total: float = 0.0
	for i in range(weapons.size()):
		var w = weapons[i]
		if w == null:
			continue
		var interval: float = maxf(float(w.get_scaled_fire_rate()), 0.05)
		var per_cycle: float = float(w.get_scaled_damage()) * float(w.get_scaled_projectile_count())
		var dps: float = per_cycle / interval
		# 多武器收益递减，和实际伤害计算保持一致
		dps *= GameConfig.get_weapon_damage_multiplier(i)
		total += dps
	return total

func _fire_weapon(weapon) -> void:
	if player == null or not is_instance_valid(player):
		return
	
	# 进化行为「刀阵环绕」不靠开火，靠旋转持续伤害
	if _get_behavior(weapon.weapon_id) == "orbit":
		_ensure_orbit_blades(weapon.weapon_id)
		return
	
	# 特殊武器类型处理
	match weapon.weapon_id:
		"poison_cloud":
			_spawn_poison_cloud(weapon)
			return
		"lightning_chain":
			_spawn_lightning_chain(weapon)
			return
		"blood_burst":
			_spawn_blood_burst(weapon)
			return
	
	var origin: Vector2 = player.global_position
	var base_direction: Vector2
	if weapon.auto_aim:
		base_direction = _get_nearest_enemy_direction(origin)
	else:
		base_direction = (player.get_global_mouse_position() - origin).normalized()
	if base_direction == Vector2.ZERO:
		return

	# 打击感：枪口闪光 + 轻微后坐（每"次"开火一次，不是每颗子弹一次）
	_muzzle_flash(origin, base_direction, weapon.weapon_id)
	_apply_recoil(base_direction)

	# 进化行为：环形弹幕（放弃瞄准，向四周均匀喷射）
	if _get_behavior(weapon.weapon_id) == "radial":
		var ring_count: int = 8
		for i in range(ring_count):
			var ring_dir := Vector2.RIGHT.rotated(TAU * float(i) / float(ring_count))
			_spawn_bullet(origin, ring_dir, weapon)
		return

	# 进化行为：双管齐射（并排两发，横向覆盖）
	if _get_behavior(weapon.weapon_id) == "double_barrel":
		var perp: Vector2 = base_direction.orthogonal() * 9.0
		_spawn_bullet(origin + perp, base_direction, weapon)
		_spawn_bullet(origin - perp, base_direction, weapon)
		return

	var count: int = weapon.get_scaled_projectile_count()
	var total_spread: float = weapon.spread_angle
	for i in range(count):
		var angle_offset: float = 0.0
		if count > 1:
			angle_offset = lerp(-total_spread / 2.0, total_spread / 2.0, float(i) / float(count - 1))
		var direction := base_direction.rotated(angle_offset)
		_spawn_bullet(origin, direction, weapon)

func _get_behavior(weapon_id: String) -> String:
	## 已进化武器的行为标识；未进化返回空串
	var evo: WeaponEvolution = weapon_evolutions.get(weapon_id, null)
	if evo == null or not evo.is_evolved:
		return ""
	return evo.behavior

func _muzzle_flash(origin: Vector2, direction: Vector2, weapon_id: String) -> void:
	var vfx := get_node_or_null("/root/VFXManager")
	if vfx == null:
		return
	var vis: Dictionary = get_projectile_visual(weapon_id)
	vfx.spawn_muzzle_flash(origin + direction * 18.0, direction, vis["color"])

func _apply_recoil(direction: Vector2) -> void:
	## 开火反馈由玩家自己处理（纯视觉挤压），这里只负责把方向传过去。
	if player and player.has_method("apply_recoil"):
		player.apply_recoil(-direction)

func _ensure_orbit_blades(weapon_id: String) -> void:
	## 刀阵只需要存在一组；每帧 fire 都会被调用，所以这里必须幂等
	if not _orbit_blades.is_empty():
		var alive: bool = false
		for b in _orbit_blades:
			if is_instance_valid(b):
				alive = true
				break
		if alive:
			return
		_orbit_blades.clear()
	_spawn_orbit_blades(weapon_id)

func _spawn_orbit_blades(weapon_id: String) -> void:
	if player == null or not is_instance_valid(player):
		return
	if not _orbit_blades.is_empty():
		return

	var weapon = null
	for w in weapons:
		if w.weapon_id == weapon_id:
			weapon = w
			break
	if weapon == null:
		return

	var mult: float = 1.0
	if player.has_method("get_total_damage_multiplier"):
		mult = player.get_total_damage_multiplier()
	# 单把刀伤害刻意压到武器的 55%：6 把刀同时贴脸也不能比原来的穿透飞刀高太多
	var per_blade_damage: float = weapon.get_scaled_damage() * 0.55
	var blade_count: int = 6
	var tint: Color = _get_evolution_color(weapon_id)

	_ensure_current_scene()
	if _current_scene == null:
		return
	for i in range(blade_count):
		var blade = OrbitBladeScript.new()
		blade.init_orbit(
			player,
			TAU * float(i) / float(blade_count),
			92.0,
			per_blade_damage,
			mult,
			tint
		)
		_current_scene.add_child(blade)
		_orbit_blades.append(blade)
	print("🌪️ 刀阵环绕：%d 把飞刀（单把 %.1f 伤害）" % [blade_count, per_blade_damage])

func get_weapon_decay(weapon) -> float:
	## 多武器收益递减：第 N 把武器伤害 × 0.9^(N-1)
	var idx := weapons.find(weapon)
	if idx <= 0:
		return 1.0
	return GameConfig.get_weapon_damage_multiplier(idx)

func _spawn_bullet(origin: Vector2, direction: Vector2, weapon) -> void:
	# 根据武器类型创建不同的子弹
	var bullet: Area2D
	if weapon.weapon_id == "throwing_knife" or weapon.weapon_id == "kunai":
		bullet = ObjectPool.acquire(KnifeBulletScene)
		# 设置穿透数
		if bullet.has_method("set_pierce_count"):
			bullet.set_pierce_count(weapon.get_scaled_pierce_count())
	elif weapon.weapon_id == "crossbow":
		bullet = ObjectPool.acquire(CrossbowBoltScene)
		if bullet.has_method("set_pierce_count"):
			bullet.set_pierce_count(weapon.get_scaled_pierce_count())
	elif weapon.weapon_id == "holy_wand":
		bullet = ObjectPool.acquire(HolyBoltScene)
		bullet.homing = true
		bullet.homing_strength = 6.0
	else:
		bullet = ObjectPool.acquire(bullet_scene)

	bullet.global_position = origin + direction * 16.0
	bullet.direction = direction
	bullet.rotation = direction.angle()
	bullet.speed = weapon.bullet_speed
	bullet.base_damage = weapon.get_scaled_damage()
	# 根据房间大小限制子弹射程，避免穿越房间
	var room_size: float = 800.0
	if player and is_instance_valid(player):
		var room := player.get_parent()
		if room and room.has_method("get_room_size"):
			room_size = room.get_room_size()
	# 子弹射程不超过房间对角线的一半
	bullet.max_range = minf(weapon.bullet_range, room_size * 0.6)
	# 使用玩家的总伤害倍率（包含狂战士之血等被动效果），并叠加多武器递减
	var player_mult: float = player.damage_multiplier if player else 1.0
	if player and player.has_method("get_total_damage_multiplier"):
		player_mult = player.get_total_damage_multiplier()
	bullet.damage_multiplier = player_mult * get_weapon_decay(weapon)

	# 弹道外观：每把武器一个颜色/粗细，混战时也能一眼分出是谁在打
	# 注意：对象池复用的子弹不会重跑 _ready，所以必须在这里每次重新上色
	var vis: Dictionary = get_projectile_visual(weapon.weapon_id)
	if bullet.has_method("apply_visual_style"):
		bullet.apply_visual_style(vis["color"], vis["length"], vis["thickness"], vis["round"])

	# 进化后视觉强化
	var is_evolved: bool = is_weapon_evolved(weapon.weapon_id)
	if is_evolved and bullet.has_node("Sprite2D"):
		var spr := bullet.get_node("Sprite2D") as Sprite2D
		spr.modulate = _get_evolution_color(weapon.weapon_id)
		var evo: WeaponEvolution = weapon_evolutions.get(weapon.weapon_id, null)
		if evo:
			spr.scale *= evo.size_multiplier

	_ensure_current_scene()
	if _current_scene:
		_current_scene.add_child(bullet)

	# 播放射击音效
	_play_shoot_sound(weapon.weapon_id)

func _refresh_enemy_cache() -> void:
	## 刷新最近敌人方向和位置缓存
	if player == null or not is_instance_valid(player):
		_nearest_enemy_dir = Vector2.ZERO
		_nearest_enemy_pos = Vector2.ZERO
		return
	
	var origin := player.global_position
	var enemies := get_tree().get_nodes_in_group("enemies")
	var nearest_dist: float = INF
	var nearest_pos: Vector2 = Vector2.ZERO
	
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var dist := origin.distance_squared_to(enemy.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest_pos = enemy.global_position
	
	_nearest_enemy_pos = nearest_pos
	if nearest_pos != Vector2.ZERO:
		_nearest_enemy_dir = (nearest_pos - origin).normalized()
	else:
		_nearest_enemy_dir = Vector2.ZERO

func _get_nearest_enemy_direction(from: Vector2) -> Vector2:
	# 如果缓存有效直接返回，否则实时计算一次
	if _nearest_enemy_dir != Vector2.ZERO:
		return _nearest_enemy_dir
	
	var enemies := get_tree().get_nodes_in_group("enemies")
	var nearest_dist: float = INF
	var nearest_dir: Vector2 = Vector2.ZERO
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var dist := from.distance_squared_to(enemy.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest_dir = (enemy.global_position - from).normalized()
	return nearest_dir

func _create_pistol() -> Resource:
	var w = WeaponDataScript.new()
	w.weapon_name = "手枪"
	w.weapon_id = "pistol"
	w.description = "可靠的基础武器"
	w.icon_emoji = "🔫"
	w.base_damage = 4.0
	w.fire_rate = 0.25
	w.bullet_speed = 500.0
	w.bullet_range = 800.0
	w.projectile_count = 1
	w.spread_angle = 0.0
	w.auto_aim = false
	return w

static func create_shotgun() -> Resource:
	var script = preload("res://scripts/weapons/weapon_data.gd")
	var w = script.new()
	w.weapon_name = "散弹枪"
	w.weapon_id = "shotgun"
	w.description = "近距离扇形射击"
	w.icon_emoji = "💥"
	w.base_damage = 4.0
	w.fire_rate = 0.75
	w.bullet_speed = 400.0
	w.bullet_range = 400.0
	w.projectile_count = 3
	w.spread_angle = 0.5
	w.auto_aim = false
	return w

static func create_magic_book() -> Resource:
	var script = preload("res://scripts/weapons/weapon_data.gd")
	var w = script.new()
	w.weapon_name = "魔法书"
	w.weapon_id = "magic_book"
	w.description = "自动追踪最近的敌人"
	w.icon_emoji = "📖"
	w.base_damage = 4.0
	w.fire_rate = 0.6
	w.bullet_speed = 350.0
	w.bullet_range = 600.0
	w.projectile_count = 1
	w.spread_angle = 0.0
	w.auto_aim = true
	return w

func _play_shoot_sound(weapon_id: String) -> void:
	var sound_name: String = "shoot_pistol"
	match weapon_id:
		"shotgun":
			sound_name = "shoot_shotgun"
		"magic_book", "holy_wand":
			sound_name = "shoot_magic"
		"throwing_knife", "crossbow":
			sound_name = "knife_throw"
		"kunai":
			sound_name = "knife_throw"
		"flame_thrower":
			sound_name = "shoot_magic"
		"blood_burst", "poison_cloud":
			sound_name = "poison_cloud"
		"lightning_chain":
			sound_name = "lightning_chain"
	var sound := _audio_lib.get_sound(sound_name)
	AudioManager.play_sfx(sound)

static func create_throwing_knife() -> Resource:
	var script = preload("res://scripts/weapons/weapon_data.gd")
	var w = script.new()
	w.weapon_name = "飞刀"
	w.weapon_id = "throwing_knife"
	w.description = "穿透敌人的飞刀"
	w.icon_emoji = "🔪"
	w.base_damage = 6.0
	w.fire_rate = 0.5
	w.bullet_speed = 450.0
	w.bullet_range = 500.0
	w.projectile_count = 1
	w.spread_angle = 0.0
	w.auto_aim = true
	w.pierce_count = 3  # 基础穿透3个
	return w

static func create_poison_cloud() -> Resource:
	var script = preload("res://scripts/weapons/weapon_data.gd")
	var w = script.new()
	w.weapon_name = "毒雾瓶"
	w.weapon_id = "poison_cloud"
	w.description = "投掷毒雾造成持续伤害"
	w.icon_emoji = "☠️"
	w.base_damage = 2.5
	w.fire_rate = 1.5
	w.bullet_speed = 0.0
	w.bullet_range = 0.0
	w.projectile_count = 1
	w.spread_angle = 0.0
	w.auto_aim = true
	w.cloud_duration = 5.0
	w.cloud_size = 1.0
	return w

static func create_lightning_chain() -> Resource:
	var script = preload("res://scripts/weapons/weapon_data.gd")
	var w = script.new()
	w.weapon_name = "闪电法杖"
	w.weapon_id = "lightning_chain"
	w.description = "闪电在敌人之间跳跃"
	w.icon_emoji = "⚡"
	w.base_damage = 7.5
	w.fire_rate = 0.8
	w.bullet_speed = 0.0
	w.bullet_range = 0.0
	w.projectile_count = 1
	w.spread_angle = 0.0
	w.auto_aim = true
	w.lightning_jumps = 3
	return w

static func create_crossbow() -> Resource:
	var script = preload("res://scripts/weapons/weapon_data.gd")
	var w = script.new()
	w.weapon_name = "十字弩"
	w.weapon_id = "crossbow"
	w.description = "高伤害穿透弩箭"
	w.icon_emoji = "🏹"
	w.base_damage = 14.0
	w.fire_rate = 0.9
	w.bullet_speed = 650.0
	w.bullet_range = 700.0
	w.projectile_count = 1
	w.spread_angle = 0.0
	w.auto_aim = true
	w.pierce_count = 2
	return w

static func create_holy_wand() -> Resource:
	var script = preload("res://scripts/weapons/weapon_data.gd")
	var w = script.new()
	w.weapon_name = "圣光魔杖"
	w.weapon_id = "holy_wand"
	w.description = "自动追踪敌人的圣光弹"
	w.icon_emoji = "✨"
	w.base_damage = 5.0
	w.fire_rate = 0.5
	w.bullet_speed = 380.0
	w.bullet_range = 700.0
	w.projectile_count = 1
	w.spread_angle = 0.0
	w.auto_aim = true
	return w

func _create_weapon_by_id(weapon_id: String):
	match weapon_id:
		"pistol":
			return _create_pistol()
		"shotgun":
			return create_shotgun()
		"magic_book":
			return create_magic_book()
		"throwing_knife":
			return create_throwing_knife()
		"poison_cloud":
			return create_poison_cloud()
		"lightning_chain":
			return create_lightning_chain()
		"crossbow":
			return create_crossbow()
		"holy_wand":
			return create_holy_wand()
		"kunai":
			return create_kunai()
		"flame_thrower":
			return create_flame_thrower()
		"blood_burst":
			return create_blood_burst()
	return null

static func create_kunai() -> Resource:
	var script = preload("res://scripts/weapons/weapon_data.gd")
	var w = script.new()
	w.weapon_name = "苦无"
	w.weapon_id = "kunai"
	w.description = "极高速投掷的暗器"
	w.icon_emoji = "🗡️"
	w.base_damage = 3.2
	w.fire_rate = 0.16
	w.bullet_speed = 560.0
	w.bullet_range = 600.0
	w.projectile_count = 1
	w.spread_angle = 0.06
	w.auto_aim = true
	w.pierce_count = 1
	return w

static func create_flame_thrower() -> Resource:
	var script = preload("res://scripts/weapons/weapon_data.gd")
	var w = script.new()
	w.weapon_name = "火焰喷射器"
	w.weapon_id = "flame_thrower"
	w.description = "近距离持续火焰，几乎没有间隙"
	w.icon_emoji = "🔥"
	w.base_damage = 1.1
	w.fire_rate = 0.08
	w.bullet_speed = 330.0
	w.bullet_range = 230.0
	w.projectile_count = 1
	w.spread_angle = 0.3
	w.auto_aim = false
	return w

static func create_blood_burst() -> Resource:
	var script = preload("res://scripts/weapons/weapon_data.gd")
	var w = script.new()
	w.weapon_name = "血爆"
	w.weapon_id = "blood_burst"
	w.description = "在敌群中引爆一片血海"
	w.icon_emoji = "🩸"
	w.base_damage = 9.0
	w.fire_rate = 1.3
	w.bullet_speed = 0.0
	w.bullet_range = 0.0
	w.projectile_count = 1
	w.spread_angle = 0.0
	w.auto_aim = true
	w.cloud_duration = 1.0
	w.cloud_size = 1.5
	return w

func _spawn_poison_cloud(weapon) -> void:
	var cloud := PoisonCloudScene.instantiate()
	# 自动瞄准最近的敌人位置投掷
	var target_pos := _get_nearest_enemy_position(player.global_position)
	if target_pos == Vector2.ZERO:
		target_pos = player.global_position + Vector2(randf_range(-100, 100), randf_range(-100, 100))
	cloud.global_position = target_pos
	cloud.base_damage = weapon.get_scaled_damage()
	cloud.damage_multiplier = (player.get_total_damage_multiplier() if player else 1.0) * get_weapon_decay(weapon)
	cloud.duration = weapon.get_scaled_cloud_duration()
	cloud.set_size(weapon.get_scaled_cloud_size())
	_ensure_current_scene()
	if _current_scene:
		_current_scene.add_child(cloud)
	_play_shoot_sound(weapon.weapon_id)

func _spawn_blood_burst(weapon) -> void:
	## 血爆：在敌群中瞬间炸开一片血海（短时高频范围伤害）
	var cloud := PoisonCloudScene.instantiate()
	var target_pos := _get_nearest_enemy_position(player.global_position)
	if target_pos == Vector2.ZERO:
		target_pos = player.global_position + Vector2(randf_range(-80, 80), randf_range(-80, 80))
	cloud.global_position = target_pos
	cloud.base_damage = weapon.get_scaled_damage()
	cloud.damage_multiplier = (player.get_total_damage_multiplier() if player else 1.0) * get_weapon_decay(weapon)
	cloud.duration = weapon.get_scaled_cloud_duration()
	cloud.tick_interval = 0.12
	cloud.tint = Color(0.72, 0.06, 0.12, 0.6)
	cloud.set_size(weapon.get_scaled_cloud_size())
	_ensure_current_scene()
	if _current_scene:
		_current_scene.add_child(cloud)
	_play_shoot_sound(weapon.weapon_id)

func _spawn_lightning_chain(weapon) -> void:
	var lightning := LightningChainScene.instantiate()
	lightning.global_position = player.global_position
	lightning.base_damage = weapon.get_scaled_damage()
	lightning.damage_multiplier = (player.get_total_damage_multiplier() if player else 1.0) * get_weapon_decay(weapon)
	lightning.max_jumps = weapon.get_scaled_lightning_jumps()
	lightning._current_damage = lightning.base_damage
	_ensure_current_scene()
	if _current_scene:
		_current_scene.add_child(lightning)
	_play_shoot_sound(weapon.weapon_id)

func _get_nearest_enemy_position(from: Vector2) -> Vector2:
	# 优先使用缓存位置
	if _nearest_enemy_pos != Vector2.ZERO:
		return _nearest_enemy_pos
	
	var enemies := get_tree().get_nodes_in_group("enemies")
	var nearest_pos := Vector2.ZERO
	var nearest_dist: float = INF
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var dist := from.distance_squared_to(enemy.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest_pos = enemy.global_position
	return nearest_pos
