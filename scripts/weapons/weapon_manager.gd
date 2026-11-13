extends Node
class_name WeaponManager
## 武器管理器

const WeaponDataScript = preload("res://scripts/weapons/weapon_data.gd")
const WeaponEvolutionScript = preload("res://scripts/weapons/weapon_evolution.gd")
const WeaponFusionScript = preload("res://scripts/weapons/weapon_fusion.gd")
const OrbitBladeScript = preload("res://scripts/weapons/orbit_blade.gd")
const RoomLookupScript = preload("res://scripts/core/room_lookup.gd")

# 场景预加载常量
const KnifeBulletScene = preload("res://scenes/player/knife_bullet.tscn")
const PoisonCloudScene = preload("res://scenes/player/poison_cloud.tscn")
const LightningChainScene = preload("res://scenes/player/lightning_chain.tscn")
const CrossbowBoltScene = preload("res://scenes/player/crossbow_bolt.tscn")
const HolyBoltScene = preload("res://scenes/player/holy_bolt.tscn")

var weapons: Array = []
var weapon_evolutions: Dictionary = {}  # weapon_id -> WeaponEvolution
## 本局是否已经融合过。融合只有一次。
var run_fused: bool = false
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
		"required_passive_items": ["regeneration"],
		"damage_multiplier": 2.5,
		"fire_rate_multiplier": 0.5,
		"size_multiplier": 2.0,
		"special_effect": "范围扩大",
		"behavior": "",
	},
	"lightning_chain": {
		"evolution_name": "雷神之怒",
		"evolution_description": "连锁更远，仍停在房间内",
		"required_passive_items": ["lightning_shield"],
		"damage_multiplier": 3.0,
		"fire_rate_multiplier": 0.4,
		"size_multiplier": 1.5,
		"special_effect": "加长连锁",
		"behavior": "",
	},
	"crossbow": {
		"evolution_name": "圣光弩",
		"evolution_description": "穿透力更强的神圣弩箭",
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
		"required_passive_items": ["vampiric_fang"],
		"damage_multiplier": 2.2,
		"fire_rate_multiplier": 0.7,
		"size_multiplier": 1.8,
		"special_effect": "血腥爆发",
		"behavior": "",
	},
	"scythe": {
		"evolution_name": "环镰",
		"evolution_description": "三把镰刀错开弧线往返",
		"required_passive_items": ["swift_boots"],
		"damage_multiplier": 1.8,
		"fire_rate_multiplier": 0.7,
		"size_multiplier": 1.3,
		"special_effect": "错峰往返",
		"behavior": "scythe_fan",
	},
	"thorn_whip": {
		"evolution_name": "荆棘回环",
		"evolution_description": "身前抽完，身后再抽一下",
		"required_passive_items": ["berserker_blood"],
		"damage_multiplier": 1.8,
		"fire_rate_multiplier": 0.6,
		"size_multiplier": 1.4,
		"special_effect": "前后抽击",
		"behavior": "both_sides",
	},
	"frost_bell": {
		"evolution_name": "霜返圣铃",
		"evolution_description": "霜环扩到尽头后留下一小段寒冷",
		"required_passive_items": ["frost_bind"],
		"damage_multiplier": 1.6,
		"fire_rate_multiplier": 0.7,
		"size_multiplier": 1.5,
		"special_effect": "霜环停留",
		"behavior": "frost_field",
	},
	"repeater": {
		"evolution_name": "贯穿末弹",
		"evolution_description": "点射的最后一发变成贯穿重弹",
		"required_passive_items": ["lucky_clover"],
		"damage_multiplier": 1.8,
		"fire_rate_multiplier": 0.7,
		"size_multiplier": 1.2,
		"special_effect": "末发贯穿",
		"behavior": "heavy_last",
	},
	"soul_lantern": {
		"evolution_name": "裂魂灯",
		"evolution_description": "魂火击杀后分裂一次，数量有上限",
		"required_passive_items": ["magnet"],
		"damage_multiplier": 1.7,
		"fire_rate_multiplier": 0.7,
		"size_multiplier": 1.3,
		"special_effect": "击杀分裂",
		"behavior": "split_kill",
	},
	"spike_tome": {
		"evolution_name": "连刺法典",
		"evolution_description": "地刺沿着来路再补两下",
		"required_passive_items": ["frost_bind"],
		"damage_multiplier": 1.8,
		"fire_rate_multiplier": 0.6,
		"size_multiplier": 1.4,
		"special_effect": "直线追刺",
		"behavior": "spike_line",
	},
	"chain_gun": {
		"evolution_name": "三连环",
		"evolution_description": "链带可以再连一个目标，仍然出不了房间",
		"required_passive_items": ["lightning_shield"],
		"damage_multiplier": 1.7,
		"fire_rate_multiplier": 0.65,
		"size_multiplier": 1.2,
		"special_effect": "第三目标",
		"behavior": "chain_three",
	},
}

func _enter_tree() -> void:
	add_to_group("weapon_manager")

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
				# 所有武器默认自动开火；auto_aim=false 只表示用鼠标指定方向。
				_fire_weapon(weapon)
				timer.start(get_fire_interval(weapon))

func _get_shoot_speed_multiplier() -> float:
	## 玩家当前的射速倍率（"射速 +20%" 这类升级和道具的汇总值）。
	## 实际冷却和 DPS 估算都从这里取值，避免两处口径不一致：
	## 冷却按倍率算、估算却按基础值算，难度软挂钩会低估玩家的强度。
	if player != null and is_instance_valid(player) and "shoot_speed_multiplier" in player:
		return maxf(float(player.get("shoot_speed_multiplier")), 0.05)
	return 1.0

func get_fire_interval(weapon) -> float:
	## 实际开火间隔 = 武器基础间隔 ÷ 玩家的射速倍率。
	## 早期 shoot_speed_multiplier 只存了个值，从不参与计算，
	## "射速 +20%" 这类卡拿在手里完全没有效果。
	var interval: float = weapon.get_scaled_fire_rate()
	return maxf(interval / _get_shoot_speed_multiplier(), 0.02)

func can_add_weapon(weapon_id: String) -> bool:
	if weapon_id.is_empty() or is_weapon_evolved(weapon_id):
		return false
	for existing in weapons:
		if existing.weapon_id == weapon_id:
			return not existing.is_max_level()
	return weapons.size() < GameConfig.MAX_WEAPON_SLOTS

func add_weapon(weapon_data) -> bool:
	if weapon_data == null or not can_add_weapon(weapon_data.weapon_id):
		return false
	for existing in weapons:
		if existing.weapon_id == weapon_data.weapon_id:
			if existing.level_up():
				weapon_leveled_up.emit(existing)
				if existing.is_max_level():
					_create_weapon_evolution(existing)
				print("武器升级: %s Lv.%d" % [existing.weapon_name, existing.current_level])
				return true
			return false
	weapons.append(weapon_data)

	# 记录武器使用类型（成就统计）
	var ach_mgr := get_node_or_null("/root/AchievementManager")
	if ach_mgr:
		ach_mgr.record_weapon_used(weapon_data.weapon_id)

	var timer := Timer.new()
	timer.wait_time = get_fire_interval(weapon_data)
	timer.one_shot = true
	add_child(timer)
	shoot_timers[weapon_data.weapon_id] = timer
	weapon_added.emit(weapon_data)
	print("获得武器: %s" % weapon_data.weapon_name)
	return true

func recast_choices() -> Array:
	## 还没进化、也没融合的武器，各给最多 3 个可见替换。
	var result: Array = []
	for weapon in weapons:
		if bool(weapon.get("fused")) or is_weapon_evolved(String(weapon.weapon_id)):
			continue
		var shown := 0
		for opt in ItemCatalog.WEAPONS:
			var next_id := String(opt.get("id", ""))
			if next_id == String(weapon.weapon_id) or bool(opt.get("upgrade_only", false)):
				continue
			result.append({
				"from": weapon.weapon_id,
				"to": next_id,
				"from_name": weapon.weapon_name,
				"to_name": opt.get("name", next_id),
				"level": maxi(1, int(weapon.current_level) - 1),
			})
			shown += 1
			if shown >= 3:
				break
	return result

func apply_recast(from_id: String, to_id: String) -> bool:
	var index := -1
	var old = null
	for i in range(weapons.size()):
		if String(weapons[i].weapon_id) == from_id:
			index = i
			old = weapons[i]
			break
	if old == null or bool(old.get("fused")) or is_weapon_evolved(from_id):
		return false
	var fresh = _create_weapon_by_id(to_id)
	if fresh == null:
		return false
	var target_level := maxi(1, int(old.current_level) - 1)
	while int(fresh.current_level) < target_level:
		if not fresh.level_up():
			break
	weapons[index] = fresh
	_drop_weapon_timer(from_id)
	var timer := Timer.new()
	timer.wait_time = get_fire_interval(fresh)
	timer.one_shot = true
	add_child(timer)
	shoot_timers[fresh.weapon_id] = timer
	if weapon_evolutions.has(from_id) and not weapon_evolutions[from_id].is_evolved:
		weapon_evolutions.erase(from_id)
	if fresh.is_max_level():
		_create_weapon_evolution(fresh)
	return true

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
			# 变种表在满级给出绝对数值，进化倍率叠在表上，不能改表里的数字。
			# base_damage / fire_rate 仍按旧接口写一份，给还在读基础字段的界面和测试。
			# 满级表已经盖过这两个字段，所以不会和 bonus_* 乘两次。
			weapon.bonus_damage_mult = evolution.damage_multiplier
			weapon.bonus_interval_mult = evolution.fire_rate_multiplier
			weapon.base_damage = evolution.get_evolved_damage(weapon.base_damage)
			weapon.fire_rate = evolution.get_evolved_fire_rate(weapon.fire_rate)
			weapon.weapon_name = evolution.evolution_name
			weapon.description = evolution.evolution_description

			# 更新计时器
			if shoot_timers.has(weapon_id):
				shoot_timers[weapon_id].wait_time = get_fire_interval(weapon)

			weapon_evolved.emit(weapon, evolution)
			print("✨ %s 已进化为 %s!" % [weapon_id, evolution.evolution_name])

			# 视觉与音效反馈
			var vfx := get_node_or_null("/root/VFXManager")
			if vfx and player and is_instance_valid(player):
				var theme_color := _get_evolution_color(weapon_id)
				vfx.spawn_evolution_effect(player.global_position, theme_color)
				vfx.screen_shake(6.0, 0.35)
				# 按武器系别补一张主题大图，让"进化"这件事有各自的辨识度
				match weapon_id:
					"crossbow", "holy_wand":
						vfx.spawn_holy_pillar(player.global_position)
					"lightning_chain":
						vfx.spawn_thunder_strike(player.global_position)
					_:
						pass

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
			return {"color": Color(0.72, 0.42, 1.0), "length": 18.0, "thickness": 14.0, "round": true}
		"throwing_knife":
			return {"color": Color(0.75, 0.9, 1.0), "length": 24.0, "thickness": 8.0, "round": false}
		"crossbow":
			return {"color": Color(1.0, 0.93, 0.55), "length": 28.0, "thickness": 9.0, "round": false}
		"holy_wand":
			return {"color": Color(1.0, 0.97, 0.72), "length": 18.0, "thickness": 14.0, "round": true}
		"kunai":
			return {"color": Color(0.62, 0.74, 1.0), "length": 18.0, "thickness": 8.0, "round": false}
		"flame_thrower":
			# 大火球 + 高频拖尾，配上粒子流就是"火舌"不是"点射"
			return {"color": Color(1.0, 0.5, 0.12), "length": 22.0, "thickness": 18.0, "round": true}
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
	var shoot_mult: float = _get_shoot_speed_multiplier()
	for i in range(weapons.size()):
		var w = weapons[i]
		if w == null:
			continue
		# 间隔要和真实开火一致（含射速倍率），
		# 否则玩家拿了一堆射速卡，估算 DPS 还是按基础间隔算，难度软挂钩会低估他。
		var interval: float = maxf(float(w.get_scaled_fire_rate()) / shoot_mult, 0.05)
		var per_cycle: float = float(w.get_scaled_damage()) * float(w.get_scaled_projectile_count())
		var dps: float = per_cycle / interval
		# 多武器收益递减，和实际伤害计算保持一致
		dps *= GameConfig.get_weapon_damage_multiplier(i)
		total += dps
	return total

func dismantle_warning(passive_id: String) -> String:
	var names: PackedStringArray = PackedStringArray()
	for weapon in weapons:
		var config: Dictionary = EVOLUTION_CONFIG.get(String(weapon.weapon_id), {})
		var required: Array = config.get("required_passive_items", [])
		if passive_id in required and not is_weapon_evolved(String(weapon.weapon_id)):
			names.append(String(config.get("evolution_name", weapon.weapon_name)))
	if names.is_empty():
		return ""
	return "拆掉后这些进化会失效：" + "、".join(names)

func _fire_weapon(weapon) -> void:
	if player == null or not is_instance_valid(player):
		return
	player.set_meta("outgoing_source", String(weapon.weapon_name))
	
	# 进化行为「刀阵环绕」不靠开火，靠旋转持续伤害
	if _get_behavior(weapon.weapon_id) == "orbit":
		_ensure_orbit_blades(weapon.weapon_id)
		return
	
	var kind := String(weapon.profile())
	# 特殊武器类型处理。融合后 weapon_id 换成融合名，开火仍走原来的形态。
	match kind:
		"poison_cloud":
			_spawn_poison_cloud(weapon)
			return
		"lightning_chain":
			_spawn_lightning_chain(weapon)
			return
		"blood_burst":
			_spawn_blood_burst(weapon)
			return
		"scythe":
			_spawn_scythes(weapon)
			return
		"thorn_whip":
			_spawn_whip(weapon)
			return
		"frost_bell":
			_spawn_frost(weapon)
			return
		"repeater":
			_spawn_repeater(weapon)
			return
		"soul_lantern":
			_spawn_souls(weapon)
			return
		"spike_tome":
			_spawn_spikes(weapon)
			return
		"chain_gun":
			_fire_chain_gun(weapon)
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
	_muzzle_flash(origin, base_direction, kind)
	_apply_recoil(base_direction)
	# 一次开火只播放一次，散弹/双管/环形弹幕共享这一声。
	_play_shoot_sound(kind)

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
	var total_spread: float = weapon.get_scaled_spread()
	if kind == "shotgun":
		var size_mult := _evolved_size(weapon.weapon_id)
		count = int(ceil(count * size_mult))
		total_spread *= size_mult
	for i in range(count):
		var angle_offset: float = 0.0
		if count > 1:
			angle_offset = lerp(-total_spread / 2.0, total_spread / 2.0, float(i) / float(count - 1))
		var direction := base_direction.rotated(angle_offset)
		_spawn_bullet(origin, direction, weapon)

func _evolved_size(weapon_id: String) -> float:
	var evo: WeaponEvolution = weapon_evolutions.get(weapon_id, null)
	return evo.size_multiplier if evo != null and evo.is_evolved else 1.0

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
		blade.weapon_manager = self
		blade.weapon = weapon
		_current_scene.add_child(blade)
		_orbit_blades.append(blade)
	print("🌪️ 刀阵环绕：%d 把飞刀（单把 %.1f 伤害）" % [blade_count, per_blade_damage])

	# 成型瞬间卷起一道旋风，之后才是刀刃自己转
	var vfx := get_node_or_null("/root/VFXManager")
	if vfx and player and is_instance_valid(player):
		vfx.spawn_knife_tornado(player.global_position)

func get_weapon_decay(weapon) -> float:
	## 多武器收益递减：第 N 把武器伤害 × 0.9^(N-1)
	var idx := weapons.find(weapon)
	if idx <= 0:
		return 1.0
	return GameConfig.get_weapon_damage_multiplier(idx)

func _spawn_bullet(origin: Vector2, direction: Vector2, weapon) -> void:
	# 根据武器类型创建不同的子弹
	var kind := String(weapon.profile())
	var bullet: Area2D
	if kind == "throwing_knife" or kind == "kunai":
		bullet = ObjectPool.acquire(KnifeBulletScene)
		# 设置穿透数
		if bullet.has_method("set_pierce_count"):
			bullet.set_pierce_count(weapon.get_scaled_pierce_count())
	elif kind == "crossbow":
		bullet = ObjectPool.acquire(CrossbowBoltScene)
		if bullet.has_method("set_pierce_count"):
			bullet.set_pierce_count(int(ceil(weapon.get_scaled_pierce_count() * _evolved_size(weapon.weapon_id))))
	elif kind == "holy_wand":
		bullet = ObjectPool.acquire(HolyBoltScene)
		bullet.homing = true
		bullet.homing_strength = 6.0
	else:
		bullet = ObjectPool.acquire(bullet_scene)
	if "bounces_left" in bullet:
		bullet.bounces_left = weapon.get_scaled_bounce_count()
	if "fusion_kind" in bullet:
		bullet.fusion_kind = String(weapon.fusion_kind)

	bullet.global_position = origin + direction * 16.0
	bullet.direction = direction
	bullet.rotation = direction.angle()
	bullet.speed = weapon.get_scaled_bullet_speed()
	if player != null and player.get("has_time_gear") == true:
		bullet.speed *= 0.72
		bullet.scale *= float(player.get("time_gear_scale"))
		if bullet.has_method("set_pierce_count"):
			var current_pierce := int(bullet.get("max_pierce"))
			bullet.set_pierce_count(current_pierce + 1)
	bullet.base_damage = weapon.get_scaled_damage()
	# 根据房间大小限制子弹射程，避免穿越房间
	# 旧写法 player.get_parent() 拿到的是 Main 不是房间 → 房间大小永远取不到，
	# 只能吃 800 的兜底值（真实房间对角线 ~1900），子弹射程被砍掉一大截。
	var room_size: float = 800.0
	if player and is_instance_valid(player):
		var room := RoomLookupScript.find_room(player)
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
	var vis: Dictionary = get_projectile_visual(kind)
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

	# 火焰喷射器：给子弹挂一条火焰粒子流。
	# 弹幕感的根源是"一颗颗点"，粒子流糊住间隙后读起来才是"持续喷火"。
	# 注意对象池复用：reset_for_pool 里会摘掉这个节点。
	if kind == "flame_thrower" and bullet.get_node_or_null("FlameTrail") == null:
		var fire := CPUParticles2D.new()
		fire.name = "FlameTrail"
		fire.amount = 26
		fire.lifetime = 0.32
		fire.local_coords = false  # 世界坐标：粒子留在原地，拖出火舌
		fire.spread = 180.0
		fire.gravity = Vector2.ZERO
		fire.initial_velocity_min = 4.0
		fire.initial_velocity_max = 26.0
		fire.scale_amount_min = 3.0
		fire.scale_amount_max = 6.5
		var ramp := Gradient.new()
		ramp.set_color(0, Color(1.0, 0.72, 0.25, 0.95))
		ramp.set_color(1, Color(0.85, 0.16, 0.04, 0.0))
		ramp.add_point(0.45, Color(1.0, 0.38, 0.08, 0.75))
		fire.color_ramp = ramp
		bullet.add_child(fire)


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
		if not is_instance_valid(enemy) or enemy.get("is_dead") == true:
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
	# Recheck living targets: a cached target can die between shots.
	
	var enemies := get_tree().get_nodes_in_group("enemies")
	var nearest_dist: float = INF
	var nearest_dir: Vector2 = Vector2.ZERO
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy.get("is_dead") == true:
			continue
		var dist := from.distance_squared_to(enemy.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest_dir = (enemy.global_position - from).normalized()
	return nearest_dir

static func _create_pistol() -> Resource:
	var w = WeaponDataScript.new()
	w.weapon_name = "手枪"
	w.weapon_id = "pistol"
	w.description = "可靠的基础武器"
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
		"magic_book":
			sound_name = "shoot_magic"
		"holy_wand":
			sound_name = "holy_wand"
		"throwing_knife":
			sound_name = "knife_throw"
		"crossbow":
			sound_name = "shoot_crossbow"
		"kunai":
			sound_name = "knife_throw"
		"flame_thrower":
			sound_name = "flame_thrower"
		"blood_burst":
			sound_name = "blood_burst"
		"poison_cloud":
			sound_name = "poison_cloud"
		"lightning_chain":
			sound_name = "lightning_chain"
		"scythe", "thorn_whip":
			sound_name = "knife_throw"
		"frost_bell", "soul_lantern":
			sound_name = "holy_wand"
		"repeater", "chain_gun":
			sound_name = "shoot_pistol"
		"spike_tome":
			sound_name = "shoot_magic"
	var sound := _audio_lib.get_sound(sound_name)
	AudioManager.play_sfx(sound)

static func create_throwing_knife() -> Resource:
	var script = preload("res://scripts/weapons/weapon_data.gd")
	var w = script.new()
	w.weapon_name = "飞刀"
	w.weapon_id = "throwing_knife"
	w.description = "穿透敌人的飞刀"
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
		"scythe":
			return create_scythe()
		"thorn_whip":
			return create_thorn_whip()
		"frost_bell":
			return create_frost_bell()
		"repeater":
			return create_repeater()
		"soul_lantern":
			return create_soul_lantern()
		"spike_tome":
			return create_spike_tome()
		"chain_gun":
			return create_chain_gun()
	return null

static func create_repeater() -> Resource:
	var script = preload("res://scripts/weapons/weapon_data.gd")
	var w = script.new()
	w.weapon_name = "连珠火铳"
	w.weapon_id = "repeater"
	w.description = "短点射之后有一段明显的停顿"
	w.base_damage = 3.6
	w.fire_rate = 0.95
	w.bullet_speed = 520.0
	w.bullet_range = 640.0
	w.projectile_count = 3
	w.burst_gap = 0.12
	w.auto_aim = false
	return w

static func create_soul_lantern() -> Resource:
	var script = preload("res://scripts/weapons/weapon_data.gd")
	var w = script.new()
	w.weapon_name = "魂引灯"
	w.weapon_id = "soul_lantern"
	w.description = "魂火自己找敌人，打完再飞回来"
	w.base_damage = 4.2
	w.fire_rate = 0.8
	w.bullet_speed = 240.0
	w.bullet_range = 220.0
	w.projectile_count = 1
	w.return_damage_mult = 0.5
	w.auto_aim = true
	return w

static func create_spike_tome() -> Resource:
	var script = preload("res://scripts/weapons/weapon_data.gd")
	var w = script.new()
	w.weapon_name = "地刺法典"
	w.weapon_id = "spike_tome"
	w.description = "敌人脚下先亮预警，再长出地刺"
	w.base_damage = 7.0
	w.fire_rate = 1.1
	w.projectile_count = 1
	w.cloud_size = 1.0
	w.cloud_duration = 0.55
	w.auto_aim = true
	return w

static func create_chain_gun() -> Resource:
	var script = preload("res://scripts/weapons/weapon_data.gd")
	var w = script.new()
	w.weapon_name = "锁链枪"
	w.weapon_id = "chain_gun"
	w.description = "命中后用链带扯到附近的第二个目标"
	w.base_damage = 6.5
	w.fire_rate = 0.55
	w.bullet_speed = 480.0
	w.bullet_range = 560.0
	w.projectile_count = 1
	w.whip_reach = 150.0
	w.return_damage_mult = 0.55
	w.auto_aim = true
	w.fusion_kind = "chain"
	return w

static func create_scythe() -> Resource:
	var script = preload("res://scripts/weapons/weapon_data.gd")
	var w = script.new()
	w.weapon_name = "回旋镰"
	w.weapon_id = "scythe"
	w.description = "沿弧线飞出再折返，去程回程都能砍到"
	w.base_damage = 5.5
	w.fire_rate = 0.72
	w.bullet_speed = 280.0
	w.bullet_range = 240.0
	w.projectile_count = 1
	w.auto_aim = true
	w.arc_width = 64.0
	w.return_damage_mult = 0.6
	return w

static func create_thorn_whip() -> Resource:
	var script = preload("res://scripts/weapons/weapon_data.gd")
	var w = script.new()
	w.weapon_name = "荆棘长鞭"
	w.weapon_id = "thorn_whip"
	w.description = "抽击身前扇形，把冲过来的敌人推开"
	w.base_damage = 3.4
	w.fire_rate = 0.42
	w.bullet_speed = 0.0
	w.bullet_range = 130.0
	w.projectile_count = 1
	w.auto_aim = false
	w.cone_angle = 0.9
	w.whip_reach = 130.0
	w.knockback_force = 90.0
	w.swing_count = 1
	return w

static func create_frost_bell() -> Resource:
	var script = preload("res://scripts/weapons/weapon_data.gd")
	var w = script.new()
	w.weapon_name = "寒霜圣铃"
	w.weapon_id = "frost_bell"
	w.description = "周期性发出霜环，伤害低，但会挂上霜缚"
	w.base_damage = 2.2
	w.fire_rate = 1.25
	w.bullet_speed = 0.0
	w.bullet_range = 120.0
	w.projectile_count = 1
	w.auto_aim = true
	w.ring_radius = 120.0
	w.slow_duration = 1.6
	return w

static func create_kunai() -> Resource:
	var script = preload("res://scripts/weapons/weapon_data.gd")
	var w = script.new()
	w.weapon_name = "苦无"
	w.weapon_id = "kunai"
	w.description = "极高速投掷的暗器"
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
	w.base_damage = 1.1
	w.fire_rate = 0.08
	# 2026-11-09 反馈"不该是弹幕效果"：弹速压低 + 射程收短，
	# 配合子弹上的火焰粒子流（_spawn_bullet），读起来是"喷出一条火舌"
	w.bullet_speed = 235.0
	w.bullet_range = 205.0
	w.projectile_count = 1
	w.spread_angle = 0.26
	w.auto_aim = false
	return w

static func create_blood_burst() -> Resource:
	var script = preload("res://scripts/weapons/weapon_data.gd")
	var w = script.new()
	w.weapon_name = "血爆"
	w.weapon_id = "blood_burst"
	w.description = "自动在最近的敌群中引爆血海"
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
	cloud.set_size(weapon.get_scaled_cloud_size() * _evolved_size(weapon.weapon_id))
	_ensure_current_scene()
	if _current_scene:
		_current_scene.add_child(cloud)
	# 落点先炸开一团毒雾贴图，玩家才看得出"扔到哪了"
	var vfx := get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.spawn_poison_burst(target_pos)
	_play_shoot_sound(weapon.weapon_id)

func _spawn_blood_burst(weapon) -> void:
	## 血爆：在敌群中瞬间炸开一片血海（短时高频范围伤害）
	## 2026-11-09 反馈两连：① 没敌人时也原地炸（desc 却写"敌群中引爆"）
	## ② 效果只是一片暗色，看不出"爆"。
	## 修：无敌人不开火（本次不消耗冷却逻辑上的开火），落点补血爆演出。
	var target_pos := _get_nearest_enemy_position(player.global_position)
	if target_pos == Vector2.ZERO:
		return  # 场上没敌人：不炸，等下一个目标
	var cloud := PoisonCloudScene.instantiate()
	cloud.global_position = target_pos
	cloud.base_damage = weapon.get_scaled_damage()
	cloud.damage_multiplier = (player.get_total_damage_multiplier() if player else 1.0) * get_weapon_decay(weapon)
	cloud.duration = weapon.get_scaled_cloud_duration()
	cloud.tick_interval = 0.12
	# 持续区域只保留淡红色范围提示，爆发瞬间由短时贴图承担。
	cloud.tint = Color(0.86, 0.12, 0.2, 0.28)
	cloud.set_size(weapon.get_scaled_cloud_size() * _evolved_size(weapon.weapon_id))
	_ensure_current_scene()
	if _current_scene:
		_current_scene.add_child(cloud)
	# 1024px 源图按世界尺寸缩小到约 184px；普通混合避免多次爆发烧成一片白红。
	var vfx := get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.spawn_texture_fx("explosion", target_pos,
			{"scale_from": 0.06, "scale_to": 0.18, "color": Color(1.0, 0.35, 0.4, 0.75),
			 "duration": 0.35, "additive": false})
		vfx.spawn_ground_marker(target_pos, 70.0, Color(0.8, 0.1, 0.18, 0.7), 0.5)
	_play_shoot_sound(weapon.weapon_id)

func _spawn_lightning_chain(weapon) -> void:
	var lightning := LightningChainScene.instantiate()
	lightning.global_position = player.global_position
	lightning.base_damage = weapon.get_scaled_damage()
	var player_mult: float = player.get_total_damage_multiplier() if player != null and player.has_method("get_total_damage_multiplier") else 1.0
	lightning.damage_multiplier = player_mult * get_weapon_decay(weapon)
	lightning.max_jumps = int(ceil(weapon.get_scaled_lightning_jumps() * _evolved_size(weapon.weapon_id)))
	lightning.acquire_range = GameConfig.LIGHTNING_ACQUIRE_RANGE
	lightning.jump_range = GameConfig.LIGHTNING_JUMP_RANGE
	if is_weapon_evolved(weapon.weapon_id):
		lightning.acquire_range = GameConfig.LIGHTNING_EVOLVED_ACQUIRE_RANGE
		lightning.jump_range = GameConfig.LIGHTNING_EVOLVED_JUMP_RANGE
	lightning.ranges_overridden = true
	var room := RoomLookupScript.find_room(player)
	if room != null:
		lightning.play_bounds = RoomLookupScript.bounds_global(room)
	lightning._current_damage = lightning.base_damage
	_ensure_current_scene()
	if _current_scene:
		_current_scene.add_child(lightning)
	# 进化「雷神之怒」：开火时偶尔天降一道竖雷（不每次都劈，避免刷屏）
	if is_weapon_evolved("lightning_chain") and randf() < 0.35:
		var vfx := get_node_or_null("/root/VFXManager")
		if vfx and player and is_instance_valid(player):
			vfx.spawn_thunder_strike(player.global_position)
	# 闪电节点找到首个目标时播放一次，空场不发声。

func get_fusion_offer() -> Dictionary:
	if run_fused:
		return {}
	var evolved: Array = []
	for weapon_id in weapon_evolutions.keys():
		var evolution: WeaponEvolution = weapon_evolutions[weapon_id]
		if evolution != null and evolution.is_evolved:
			evolved.append(String(weapon_id))
	return WeaponFusionScript.offer(weapons, evolved, run_fused)

func apply_fusion(recipe_id: String) -> bool:
	var recipe := WeaponFusionScript.recipe(recipe_id)
	if recipe.is_empty() or run_fused:
		return false
	var offer := get_fusion_offer()
	if offer.is_empty() or String(offer.get("id", "")) != recipe_id:
		return false
	var primary_id := String(recipe["primary"])
	var secondary_id := String(recipe["secondary"])
	var primary = null
	var secondary = null
	for weapon in weapons:
		if String(weapon.weapon_id) == primary_id:
			primary = weapon
		elif String(weapon.weapon_id) == secondary_id:
			secondary = weapon
	if primary == null or secondary == null:
		return false
	primary.stat_id = primary_id
	primary.attack_profile = primary_id
	primary.weapon_id = recipe_id
	primary.weapon_name = String(recipe["name"])
	primary.description = String(recipe["card"])
	primary.fusion_kind = String(recipe["kind"])
	primary.fused = true
	primary.bonus_damage_mult = float(recipe.get("damage_mult", 1.0))
	if recipe.has("interval"):
		primary.interval_override = float(recipe["interval"])
	weapons.erase(secondary)
	_drop_weapon_timer(secondary_id)
	_rekey_weapon_timer(primary_id, recipe_id, primary)
	weapon_evolutions.erase(primary_id)
	weapon_evolutions.erase(secondary_id)
	run_fused = true
	if shoot_timers.has(recipe_id):
		shoot_timers[recipe_id].wait_time = get_fire_interval(primary)
	print("融合：%s 吃掉了 %s" % [recipe["name"], secondary_id])
	return true

func _drop_weapon_timer(weapon_id: String) -> void:
	if not shoot_timers.has(weapon_id):
		return
	var timer: Timer = shoot_timers[weapon_id]
	shoot_timers.erase(weapon_id)
	if is_instance_valid(timer):
		timer.queue_free()

func _rekey_weapon_timer(old_id: String, new_id: String, weapon) -> void:
	if not shoot_timers.has(old_id):
		return
	var timer: Timer = shoot_timers[old_id]
	shoot_timers.erase(old_id)
	shoot_timers[new_id] = timer
	timer.wait_time = get_fire_interval(weapon)

func on_projectile_event(bullet: Node, reason: String) -> void:
	var kind := String(bullet.get("fusion_kind"))
	if kind == "":
		return
	match kind:
		"thunder":
			if reason != "hit":
				return
			bullet.fusion_kind = ""
			_spawn_thunder_jump(bullet.global_position)
		"miasma":
			bullet.fusion_kind = ""
			_spawn_fusion_cloud(bullet.global_position, WeaponFusionScript.POISON_MAX_DAMAGE, WeaponFusionScript.MIASMA_CLOUD_SCALE, WeaponFusionScript.MIASMA_CLOUD_DURATION, Color(0.25, 0.85, 0.3, 0.45), 0.5)
		"split":
			if reason != "range":
				return
			bullet.fusion_kind = ""
			_spawn_split_bolts(bullet)
		"burning":
			if reason != "hit":
				return
			_count_burning_hit(bullet.global_position)
		"chain":
			if reason != "hit":
				return
			bullet.fusion_kind = ""
			_chain_from(bullet.global_position, float(bullet.get("base_damage")) * float(bullet.get("damage_multiplier")))

func _spawn_thunder_jump(at: Vector2) -> void:
	var lightning := LightningChainScene.instantiate()
	lightning.global_position = at
	lightning.base_damage = WeaponFusionScript.thunder_jump_damage()
	lightning.damage_multiplier = 1.0
	lightning.max_jumps = 1
	lightning.acquire_range = WeaponFusionScript.THUNDER_JUMP_RANGE
	lightning.jump_range = WeaponFusionScript.THUNDER_JUMP_RANGE
	lightning.ranges_overridden = true
	var room := RoomLookupScript.find_room(player) if player else null
	if room == null:
		room = RoomLookupScript.find_room(self)
	if room != null:
		lightning.play_bounds = RoomLookupScript.bounds_global(room)
	_ensure_current_scene()
	if _current_scene:
		_current_scene.add_child(lightning)

func _spawn_fusion_cloud(at: Vector2, damage: float, cloud_scale: float, duration: float, tint: Color, tick: float) -> void:
	var cloud := PoisonCloudScene.instantiate()
	cloud.global_position = at
	cloud.base_damage = damage
	cloud.damage_multiplier = 1.0
	cloud.duration = duration
	cloud.tick_interval = tick
	cloud.tint = tint
	cloud.set_size(cloud_scale)
	_ensure_current_scene()
	if _current_scene:
		_current_scene.add_child(cloud)

func _spawn_split_bolts(bullet: Node) -> void:
	var direction: Vector2 = bullet.get("direction")
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	var half := float(bullet.get("base_damage")) * 0.5
	var mult := float(bullet.get("damage_multiplier"))
	for side in [-1.0, 1.0]:
		var dir := direction.rotated(side * 0.6)
		var child := ObjectPool.acquire(HolyBoltScene)
		child.global_position = bullet.global_position
		child.direction = dir
		child.rotation = dir.angle()
		child.speed = float(bullet.get("speed"))
		child.base_damage = half
		child.damage_multiplier = mult
		child.max_range = 160.0
		child.homing = true
		child.homing_strength = 4.0
		child.fusion_kind = ""
		var vis := get_projectile_visual("holy_wand")
		if child.has_method("apply_visual_style"):
			child.apply_visual_style(vis["color"], vis["length"], vis["thickness"], vis["round"])
		_ensure_current_scene()
		if _current_scene:
			_current_scene.add_child(child)

func _count_burning_hit(at: Vector2) -> void:
	for weapon in weapons:
		if String(weapon.fusion_kind) != "burning":
			continue
		weapon.fusion_hits += 1
		if weapon.fusion_hits < WeaponFusionScript.BURNING_HITS:
			return
		weapon.fusion_hits = 0
		_spawn_fusion_cloud(at, WeaponFusionScript.burning_damage(), WeaponFusionScript.BURNING_SCALE, 0.45, Color(0.86, 0.12, 0.2, 0.4), 0.12)
		return

func _live_count(group_name: String) -> int:
	var count := 0
	for node in get_tree().get_nodes_in_group(group_name):
		if is_instance_valid(node):
			count += 1
	return count

func _spawn_scythes(weapon) -> void:
	if _live_count("player_scythe") >= 6:
		return
	var origin := player.global_position
	var base_dir := _get_nearest_enemy_direction(origin)
	if base_dir == Vector2.ZERO:
		base_dir = Vector2.RIGHT
	var count: int = weapon.get_scaled_projectile_count()
	if _get_behavior(weapon.weapon_id) == "scythe_fan":
		count = maxi(count, 3)
	_play_shoot_sound("scythe")
	var player_mult: float = player.get_total_damage_multiplier() if player.has_method("get_total_damage_multiplier") else 1.0
	for i in range(count):
		if _live_count("player_scythe") >= 6:
			return
		var blade = preload("res://scripts/player/boomerang_scythe.gd").new()
		var spread: float = 0.0 if count == 1 else lerp(-0.35, 0.35, float(i) / float(count - 1))
		blade.direction = base_dir.rotated(spread)
		blade.origin = origin
		blade.origin_set = true
		blade.global_position = origin
		blade.travel = weapon.bullet_range
		blade.speed = maxf(weapon.bullet_speed, 220.0)
		blade.arc_width = weapon.get_scaled_arc_width()
		blade.base_damage = weapon.get_scaled_damage()
		blade.damage_multiplier = player_mult * get_weapon_decay(weapon)
		blade.return_damage_mult = weapon.get_scaled_return_mult()
		blade.lateral_sign = -1.0 if i % 2 == 1 else 1.0
		_ensure_current_scene()
		if _current_scene:
			_current_scene.add_child(blade)

func _spawn_whip(weapon) -> void:
	if _live_count("player_whip") >= 4:
		return
	var origin := player.global_position
	var direction := (player.get_global_mouse_position() - origin).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	var swings: int = weapon.get_scaled_swings()
	_play_shoot_sound("thorn_whip")
	var player_mult: float = player.get_total_damage_multiplier() if player.has_method("get_total_damage_multiplier") else 1.0
	for i in range(swings):
		var lash = preload("res://scripts/player/thorn_lash.gd").new()
		lash.origin = origin
		lash.direction = direction.rotated(0.18 if i == 1 else 0.0)
		lash.reach = weapon.get_scaled_whip_reach()
		lash.cone = weapon.get_scaled_cone()
		lash.base_damage = weapon.get_scaled_damage()
		lash.damage_multiplier = player_mult * get_weapon_decay(weapon)
		lash.knockback = weapon.get_scaled_knockback()
		lash.also_behind = _get_behavior(weapon.weapon_id) == "both_sides" and i == 0
		_ensure_current_scene()
		if _current_scene:
			_current_scene.add_child(lash)

func _spawn_frost(weapon) -> void:
	if _live_count("player_frost") >= 3:
		return
	var ring = preload("res://scripts/player/frost_ring.gd").new()
	ring.global_position = player.global_position
	ring.radius = weapon.get_scaled_ring_radius()
	ring.base_damage = weapon.get_scaled_damage()
	var player_mult: float = player.get_total_damage_multiplier() if player.has_method("get_total_damage_multiplier") else 1.0
	ring.damage_multiplier = player_mult * get_weapon_decay(weapon)
	ring.slow_duration = weapon.get_scaled_slow_duration()
	ring.linger = _get_behavior(weapon.weapon_id) == "frost_field"
	_ensure_current_scene()
	if _current_scene:
		_current_scene.add_child(ring)
	_play_shoot_sound("frost_bell")

func _get_nearest_enemy_position(from: Vector2) -> Vector2:
	# Recheck living targets before placing an attack.
	
	var enemies := get_tree().get_nodes_in_group("enemies")
	var nearest_pos := Vector2.ZERO
	var nearest_dist: float = INF
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy.get("is_dead") == true:
			continue
		var dist := from.distance_squared_to(enemy.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest_pos = enemy.global_position
	return nearest_pos

func _shot_direction(auto_aim: bool) -> Vector2:
	var origin := player.global_position
	var direction: Vector2 = _get_nearest_enemy_direction(origin) if auto_aim else (player.get_global_mouse_position() - origin).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	return direction

func _player_mult() -> float:
	if player != null and player.has_method("get_total_damage_multiplier"):
		return float(player.get_total_damage_multiplier())
	return 1.0

func _spawn_repeater(weapon) -> void:
	var direction := _shot_direction(bool(weapon.auto_aim))
	var count: int = weapon.get_scaled_projectile_count()
	var gap: float = weapon.get_scaled_burst_gap()
	var heavy: bool = _get_behavior(weapon.weapon_id) == "heavy_last"
	_play_shoot_sound("repeater")
	for i in range(count):
		var index := i
		var delay := gap * float(i)
		var fire := func() -> void:
			if not is_instance_valid(player) or not is_instance_valid(weapon):
				return
			_spawn_bullet(player.global_position, direction, weapon)
			if not heavy or index != count - 1:
				return
			var scene := _current_scene
			if scene == null:
				return
			var last: Node = scene.get_child(scene.get_child_count() - 1)
			if last != null and last.has_method("set_pierce_count"):
				last.set_pierce_count(4)
				last.base_damage = float(last.base_damage) * 1.6
		if delay <= 0.0:
			fire.call()
		else:
			get_tree().create_timer(delay).timeout.connect(fire)

func _spawn_souls(weapon) -> void:
	if _live_count("player_soul") >= 4:
		return
	var count: int = mini(weapon.get_scaled_projectile_count(), 4 - _live_count("player_soul"))
	_play_shoot_sound("soul_lantern")
	for i in range(count):
		var wisp = preload("res://scripts/player/soul_wisp.gd").new()
		wisp.global_position = player.global_position
		wisp.player = player
		wisp.base_damage = weapon.get_scaled_damage()
		wisp.damage_multiplier = _player_mult() * get_weapon_decay(weapon)
		wisp.return_damage_mult = weapon.get_scaled_return_mult()
		wisp.speed = maxf(weapon.bullet_speed, 180.0)
		wisp.can_split = _get_behavior(weapon.weapon_id) == "split_kill"
		_ensure_current_scene()
		if _current_scene:
			_current_scene.add_child(wisp)

func _spawn_spikes(weapon) -> void:
	var origin := player.global_position
	var aim := _get_nearest_enemy_position(origin)
	if aim == Vector2.ZERO:
		aim = origin + _shot_direction(true) * 120.0
	var count: int = weapon.get_scaled_projectile_count()
	var line: bool = _get_behavior(weapon.weapon_id) == "spike_line"
	if line:
		count = maxi(count, 3)
	var dir := (aim - origin).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	_play_shoot_sound("spike_tome")
	for i in range(count):
		var spike = preload("res://scripts/player/ground_spike.gd").new()
		spike.global_position = aim + dir * 54.0 * float(i)
		spike.warn_time = weapon.get_scaled_cloud_duration()
		spike.radius = 42.0 * weapon.get_scaled_cloud_size()
		spike.base_damage = weapon.get_scaled_damage()
		spike.damage_multiplier = _player_mult() * get_weapon_decay(weapon)
		_ensure_current_scene()
		if _current_scene:
			_current_scene.add_child(spike)

func _fire_chain_gun(weapon) -> void:
	var direction := _shot_direction(bool(weapon.auto_aim))
	_muzzle_flash(player.global_position, direction, "chain_gun")
	_play_shoot_sound("chain_gun")
	_spawn_bullet(player.global_position, direction, weapon)

func _chain_from(from_pos: Vector2, dealt: float) -> void:
	var weapon = null
	for owned in weapons:
		if String(owned.profile()) == "chain_gun":
			weapon = owned
			break
	if weapon == null:
		return
	var reach: float = weapon.get_scaled_whip_reach()
	var ratio: float = weapon.get_scaled_return_mult()
	var links: int = 2 if _get_behavior(weapon.weapon_id) == "chain_three" else 1
	var cursor := from_pos
	var seen: Dictionary = {}
	for _n in range(links):
		var next := _chain_target(cursor, reach, seen)
		if next == null:
			return
		seen[next.get_instance_id()] = true
		if next.has_method("take_damage"):
			next.take_damage(dealt * ratio)
		_draw_chain(cursor, next.global_position)
		cursor = next.global_position

func _chain_target(from_pos: Vector2, reach: float, seen: Dictionary) -> Node2D:
	var best: Node2D = null
	var best_dist := reach * reach
	var room := RoomLookupScript.find_room(player) if player != null else null
	var bounds := RoomLookupScript.bounds_global(room) if room != null else Rect2()
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.get("is_dead") == true or not (enemy is Node2D):
			continue
		if seen.has(enemy.get_instance_id()):
			continue
		if bounds.size.x > 0.0 and not bounds.has_point((enemy as Node2D).global_position):
			continue
		var dist := from_pos.distance_squared_to((enemy as Node2D).global_position)
		if dist < best_dist:
			best_dist = dist
			best = enemy
	return best

func _draw_chain(a: Vector2, b: Vector2) -> void:
	var line := Line2D.new()
	line.width = 3.0
	line.default_color = Color(0.85, 0.78, 0.45, 0.9)
	line.add_point(a)
	line.add_point(b)
	_ensure_current_scene()
	if _current_scene:
		_current_scene.add_child(line)
	var tween := line.create_tween()
	tween.tween_property(line, "modulate:a", 0.0, 0.18)
	tween.tween_callback(line.queue_free)
