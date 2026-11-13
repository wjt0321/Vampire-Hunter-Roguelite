extends CharacterBody2D
class_name EnemyBase

const SpriteSheetLib = preload("res://scripts/core/sprite_sheet.gd")
## 房间解析的唯一入口。用 preload 而不是直接写 class_name：
## 本脚本会被各敌人子类继承，preload 出来的常量在继承链上也能直接用。
const RoomLookupLib = preload("res://scripts/core/room_lookup.gd")
## 可读性层（轮廓 + 地面投影）使用全局类，子类共享同一套常量与视觉接口。
## 敌人基类脚本
## 所有敌人类型继承此类
## HP 和伤害随波次动态缩放，由 GameConfig 控制

# === 基础属性（子类设置，会被波次系数缩放） ===
@export var base_hp: float = 39.0
@export var base_contact_damage: float = 10.0
@export var move_speed: float = 80.0
@export var xp_value: int = 5
## 击杀掉落的银币数（局内货币）。精英/Boss 由子类覆盖为更高值。
@export var silver_value: int = 1
## 掉落倍率：由 wave_manager 在生成时注入（深渊契约的 +30% 走这里）。
## 与 silver_value/xp_value 分开，是为了让"这次生成的所有敌人"统一翻倍，
## 而不是去改每个子类手写的基数。
var loot_mult: float = 1.0

# 缩放后的实际属性
var max_hp: float
var contact_damage: float
var current_hp: float
var player: CharacterBody2D = null
var is_dead: bool = false
var spawn_wave: int = 1
## 所在楼层（1-based），用于叠加层难度倍率
var floor_index: int = 1
## 额外的 HP 倍率（召唤物/分裂体用），在 _ready 前设置
var hp_scale: float = 1.0
## 精灵显示倍率（相对归一化后的 56px）。分裂体设 <1，精英设 >1，在 _ready 前设置。
## 注意：绝对尺寸请永远通过这个变量表达，不要直接写 sprite.scale = Vector2(x, x)，
## 那会把归一化比例覆盖掉——精英吸血鬼曾因此变成 333px 的巨图。
var sprite_scale_mult: float = 1.0
## 精灵静止时的局部位置。单张图的上下浮动从这里加减，不推碰撞体。
var _sprite_rest_pos: Vector2 = Vector2.ZERO
var _sprite_rest_ready: bool = false
var _sprite_anim_time: float = 0.0
var _sprite_frame_wait: float = 0.0
## loop：一直循环。once：播完回到 loop 那张。hold：播完停在最后一格。
var _sprite_play: String = "loop"
var _sprite_loop_tex: Texture2D = null
var _sprite_target: float = 56.0
var _sprite_hold: bool = false

# === 精英词缀（在 _ready 之前由 WaveManager / 子类赋值） ===
## 主词缀。空字符串 = 普通怪。取值见 EliteAffix.DATA
var elite_affix: String = ""
## 第二词缀（深渊猎物的"双词缀"）。只提供自己的专属效果；
## 统一精英加成（血/伤/银/经验/体型）仍然只按主词缀结算一次。
var secondary_affix: String = ""
## 词缀护盾剩余量。**护盾是直接加到 max_hp 上的**，
## 所以任何覆写了 take_damage 的敌人（石像鬼、自爆鬼、亲王…）都不需要改一行代码就自带护盾。
var affix_shield_hp: float = 0.0
## 裂变体用：禁止继承词缀，否则会无限裂变
var suppress_affix: bool = false

## 移速修正的唯一出口（急速光环 / 霜缚减速都改这里，不要直接写 move_speed）。
## 谁先写谁就赢——以前急速用 `move_speed = base * mult` 再 await 还原本，
## 一旦中间被减速改过，两个效果会互相覆盖成"永久变慢"或"永久变快"。
var _speed_base: float = -1.0
var _haste_remaining: float = 0.0
var _slow_mult: float = 1.0
var _slow_remaining: float = 0.0

# === 持续状态（流血） ===
## 每秒流血伤害
var bleed_dps: float = 0.0
## 剩余时间
var bleed_remaining: float = 0.0
## tick 计时，每 BLEED_TICK 秒结算一次
var _bleed_tick_timer: float = 0.0
## 状态特效的内部冷却：高攻速武器每发都会命中，不加这个会 20 只怪同时滴血喷粒子
var _status_vfx_cd: float = 0.0

# === 接触伤害 ===
## 接触感应区。缓存下来，持续结算时不用每帧 get_node。
var _contact_area: Area2D = null
## 接触伤害的结算冷却。上一次结算后要等一个无敌帧才允许下一次。
var _contact_cd: float = 0.0

# 冻结状态
var is_frozen: bool = false
var freeze_timer: float = 0.0
## Boss 被冰冻之心命中后的再触发冷却。冷却内不再刷新减速。
var _boss_freeze_cd: float = 0.0

# 受击硬直与击退
var hit_stun_timer: float = 0.0
var knockback_velocity: Vector2 = Vector2.ZERO
const KNOCKBACK_FRICTION: float = 800.0

# === 信号 ===
signal enemy_died(enemy: Node2D)

# === 节点引用 ===
@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

# 缓存 VFXManager，避免每次受击/死亡都查询
var _vfx_manager: Node = null

func _ready() -> void:
	# 每日「狂奔」乘在基础移速上，赶在急速/减速把 _speed_base 记下来之前。
	# Boss 不走这里（它自己的 _ready 不调 super），冲刺速度不该被这条日常词缀改掉。
	var speed_mult := GameConfig.daily_enemy_speed_mult()
	if not is_equal_approx(speed_mult, 1.0):
		move_speed *= speed_mult
	# 根据波次缩放 HP 和伤害
	_apply_wave_scaling()
	# 词缀加成必须在这里做完：体型倍率要赶在 _load_sprite_texture 归一化之前生效，
	# 护盾量要赶在 current_hp = max_hp 之前加进 max_hp
	var affix_ids: Array = get_affix_ids()
	if not affix_ids.is_empty():
		_apply_elite_affix_stats(affix_ids)
	current_hp = max_hp
	add_to_group("enemies")
	_vfx_manager = get_node_or_null("/root/VFXManager")
	# 加载精灵图纹理
	_load_sprite_texture()
	# 查找玩家节点
	_find_player()
	# 缓存接触感应区：持续接触伤害靠它判断"现在还贴着玩家吗"
	_contact_area = _find_contact_area()
	# 表现与行为挂在子节点上：一半敌人自己覆写了 _physics_process，基类钩子对它们无效
	if not affix_ids.is_empty():
		_attach_affix_controllers(affix_ids)

func get_affix_ids() -> Array:
	## 主词缀在前，只保留合法且不重复的 id。
	## 装机入口只此一处：重复/非法 id 不会长出第二个控制器，
	## 也不会把护盾结算两次。
	var out: Array = []
	for id in [elite_affix, secondary_affix]:
		var affix_id := String(id)
		if affix_id.is_empty() or affix_id in out:
			continue
		if EliteAffix.get_data(affix_id).is_empty():
			continue
		out.append(affix_id)
	return out

func _apply_elite_affix_stats(affix_ids: Array) -> void:
	## 词缀统一加成：更肉、更疼、掉更多。
	## **每只精英只结算一次**，与词缀数量无关——双词缀的第二条只提供
	## 自己的专属效果，否则血量会变成 ×1.35²，深渊猎物直接成数值墙。
	max_hp *= GameConfig.ELITE_AFFIX_HP_MULT
	contact_damage *= GameConfig.ELITE_AFFIX_DAMAGE_MULT
	silver_value = int(round(float(silver_value) * GameConfig.ELITE_AFFIX_SILVER_MULT))
	xp_value = int(round(float(xp_value) * GameConfig.ELITE_AFFIX_XP_MULT))
	sprite_scale_mult *= GameConfig.ELITE_AFFIX_SCALE_MULT
	# 护盾是专属效果：只按真正带血盾的那个词缀加一次（id 已去重）
	for id in affix_ids:
		if String(id) == EliteAffix.SHIELDED:
			affix_shield_hp = max_hp * GameConfig.AFFIX_SHIELD_RATIO
			max_hp += affix_shield_hp

func _attach_affix_controllers(affix_ids: Array) -> void:
	for slot in range(affix_ids.size()):
		var id := String(affix_ids[slot])
		var controller := EliteAffixController.new()
		controller.setup(self, id, slot)
		add_child(controller)
		print("⚠️ 精英出现：%s·%s" % [EliteAffix.display_name(id), _get_enemy_type()])

func apply_haste(duration: float) -> void:
	## 急速光环：临时提速，到期自动还回原速。
	## 走"记剩余时间 + 统一刷新"，不再用 await 协程：
	## 一是被加速的可能是二十只怪，没必要各自挂一个协程；
	## 二是和霜缚减速叠加时，协程的"还原成原速"会把减速一起抹掉。
	if is_dead:
		return
	_haste_remaining = maxf(_haste_remaining, duration)
	_refresh_speed()

func apply_slow(mult: float, duration: float) -> void:
	## 霜缚减速：move_speed 乘以 mult（<1）。Boss 有抗性，否则控到死。
	if is_dead or mult >= 1.0:
		return
	if is_in_group("boss"):
		mult = lerpf(1.0, mult, GameConfig.SLOW_BOSS_RESIST)
	# 多个来源取最强的那个，不做相乘——相乘会让两次减速变成 0.49，直接冻死
	_slow_mult = minf(_slow_mult, mult) if _slow_remaining > 0.0 else mult
	_slow_remaining = maxf(_slow_remaining, duration)
	_refresh_speed()

func set_base_move_speed(value: float) -> void:
	_speed_base = value
	_refresh_speed()

func _refresh_speed() -> void:
	## 移速 = 基础 × 急速 × 减速。所有修正都从这里出去。
	if _speed_base <= 0.0:
		_speed_base = move_speed
	var s := _speed_base
	if _haste_remaining > 0.0:
		s *= GameConfig.AFFIX_HASTE_MULT
	if _slow_remaining > 0.0:
		s *= _slow_mult
	move_speed = s

func apply_bleed(dps: float, duration: float) -> void:
	## 流血：不叠层，取"更强的那一次"并刷新时间。
	## 叠层会让高攻速武器把流血堆成主要伤害来源，武器本身反而变成引信。
	if is_dead or dps <= 0.0:
		return
	# 弱流血既不叠层、也不续时间。
	# 只做 max() 但不拦时间的话，一把高频小弹能把"十字弩打出来的高伤流血"永久续着，
	# 等于免费获得了不属于它的收益。
	if dps < bleed_dps:
		return
	bleed_dps = dps
	bleed_remaining = maxf(bleed_remaining, duration)
	if _bleed_tick_timer <= 0.0:
		_bleed_tick_timer = GameConfig.BLEED_TICK

func is_bleeding() -> bool:
	return bleed_remaining > 0.0 and bleed_dps > 0.0

func _process(delta: float) -> void:
	## 状态 tick 放 _process 而不放 _physics_process：
	## 有一半敌人（bat 之外的 werewolf / zombie / 弓箭手…）自己覆写了 _physics_process，
	## 基类的物理帧对它们根本不会执行，状态会静默失效。
	## 目前没有任何子类覆写 _process，所以这里是安全的。
	if is_dead:
		return
	# 精灵浮动放 _process：Boss 覆写了物理帧，待机浮动不能跟着停。
	_tick_sprite(delta)
	if _status_vfx_cd > 0.0:
		_status_vfx_cd -= delta
	if is_frozen:
		freeze_timer -= delta
		if freeze_timer <= 0.0:
			_unfreeze()
	if _boss_freeze_cd > 0.0:
		_boss_freeze_cd -= delta
	_tick_speed_decay(delta)
	_tick_bleed(delta)
	_tick_contact_damage(delta)

func _find_contact_area() -> Area2D:
	## 找接触感应区。优先用约定的 "ContactArea"，没有就退而求其次找任意 Area2D 子节点。
	var named := get_node_or_null("ContactArea")
	if named is Area2D:
		return named
	for child in get_children():
		if child is Area2D:
			return child
	return null

func _tick_contact_damage(delta: float) -> void:
	## 接触中的敌人按玩家既有无敌帧持续结算伤害。
	## 旧实现只有 body_entered 一次性触发：贴住不动就再也不掉血，
	## 玩家只要站住不动就能白嫖无敌帧。现在按无敌帧节奏（0.5 秒）重复结算。
	if is_dead:
		return
	_contact_cd -= delta
	if _contact_cd > 0.0:
		return
	if _contact_area == null or not is_instance_valid(_contact_area):
		return
	var body := _find_contact_body()
	if body == null:
		return
	if not _can_damage_body(body):
		return
	# 玩家还在无敌帧里 → 这一轮不结算，等无敌结束再扣，
	# 否则冷却会被推后，节奏会变成"每 1 秒一次"而不是"每 0.5 秒一次"。
	if "is_invincible" in body and bool(body.get("is_invincible")):
		return
	_deal_contact_damage(body)
	_contact_cd = GameConfig.PLAYER_INVINCIBLE_DURATION

func _deal_contact_damage(body: Node2D) -> void:
	body.take_damage(contact_damage, global_position)

func _can_damage_body(body: Node2D) -> bool:
	if is_dead or is_frozen:
		return false
	if "is_petrified" in self and bool(get("is_petrified")):
		return false
	if "intro_invulnerable" in self and bool(get("intro_invulnerable")):
		return false
	## 目标还能挨打吗。
	## 玩家血量归零（或者已经死亡）时不再结算接触伤害：
	## 否则敌人会对着尸体反复结算，血条早就空了还会继续掉。
	if body == null or not is_instance_valid(body):
		return false
	if "current_hp" in body and float(body.get("current_hp")) <= 0.0:
		return false
	return true

func _find_contact_body() -> Node2D:
	## 当前还贴在感应区里的玩家
	for body in _contact_area.get_overlapping_bodies():
		if body.is_in_group("player") and body.has_method("take_damage"):
			return body
	return null

func _tick_speed_decay(delta: float) -> void:
	if _haste_remaining > 0.0:
		_haste_remaining -= delta
		if _haste_remaining <= 0.0:
			_haste_remaining = 0.0
			_refresh_speed()
	if _slow_remaining > 0.0:
		_slow_remaining -= delta
		if _slow_remaining <= 0.0:
			_slow_remaining = 0.0
			_slow_mult = 1.0
			_refresh_speed()

func _tick_bleed(delta: float) -> void:
	if bleed_remaining <= 0.0:
		return
	bleed_remaining -= delta
	_bleed_tick_timer -= delta
	if _bleed_tick_timer > 0.0:
		if bleed_remaining <= 0.0:
			bleed_dps = 0.0
			_bleed_tick_timer = 0.0
		return
	_bleed_tick_timer = GameConfig.BLEED_TICK
	dot_damage(bleed_dps * GameConfig.BLEED_TICK)
	# 一滴血点，够看出"它在流血"，又不至于二十只怪时糊屏
	var vfx := _get_vfx()
	if vfx and is_instance_valid(sprite):
		vfx.spawn_hit_particles(global_position + Vector2(0, 6), Color(0.85, 0.12, 0.16), 1)
	if bleed_remaining <= 0.0:
		bleed_dps = 0.0

func dot_damage(amount: float) -> void:
	## 持续伤害（流血）的统一入口。
	## 刻意不走 take_damage：
	##   1. take_damage 每次都闪白 + 触发"打中了"的冻帧，每 0.5 秒闪一次会把
	##      "这怪在流血"和"我刚打中它"完全混淆；
	##   2. 自爆鬼的 take_damage 里有"血量低于 30% 提前引爆"，流血把它推过线也算合理，
	##      但那属于子类语义 —— 这里用鸭子类型补上真正必须保留的两条（护甲 / 无敌）。
	if is_dead or amount <= 0.0:
		return
	# 子类独有的"不可伤害"状态：登场无敌的 Boss、石化中的石像鬼。
	# 必须用 get() 读，直接写标识符会让基类解析失败（这些字段只在子类里声明）。
	if "intro_invulnerable" in self and bool(get("intro_invulnerable")):
		return
	if "is_petrified" in self and bool(get("is_petrified")):
		return
	var actual := amount
	if "armor" in self:
		actual *= 1.0 - GameConfig.calculate_damage_reduction(float(get("armor")))
	actual = _subtract_hp(actual)
	_report_dealt_damage(actual)
	# Boss 的血条不刷新会显示成"打完没掉血"（take_damage 的 4 个覆写里这个是漏得最多的）。
	# 用 emit_signal 而不是直接写 boss_hp_changed.emit —— 基类没有声明这个信号，
	# 直接引用会让整个 EnemyBase 解析失败（连带所有子类一起炸）。
	if has_signal("boss_hp_changed"):
		emit_signal("boss_hp_changed", current_hp, max_hp)
	if current_hp <= 0.0:
		_die()

func _apply_wave_scaling() -> void:
	## 根据生成波次与所在楼层缩放敌人属性
	## 深渊阶梯：全层全局倍率，挂在链最外层（和波次/楼层正交）
	max_hp = base_hp * GameConfig.get_enemy_hp_multiplier(spawn_wave) * hp_scale \
		* GameConfig.get_player_level_hp_scale(_get_player_level()) \
		* GameConfig.get_floor_hp_multiplier(floor_index) \
		* GameConfig.get_abyss_hp_mult()
	contact_damage = _scaled_damage(base_contact_damage)
	# 掉落的深渊加成不在这乘：直接 round 进 silver_value 会让 1×1.1 永远是 1
	# （xp_gem_test 踩过的坑）。倍率由 wave_manager 乘进 loot_mult，
	# 走 _loot_scaled 的"小数部分概率进位"，长期期望才准确

func _scaled_damage(base: float) -> float:
	## 敌人伤害的统一口径：波次 × 楼层 × 深渊。
	## 接触伤害、二阶段重算、爆炸、法术都从这里取，避免各技能自己漏一个倍率。
	return base * GameConfig.get_enemy_damage_multiplier(spawn_wave) \
		* GameConfig.get_floor_damage_multiplier(floor_index) \
		* GameConfig.get_abyss_damage_mult()

func _get_player_level() -> int:
	## 读取玩家当前等级，用于 HP 橡皮筋缩放
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return 1
	var p = players[0]
	if p and "current_level" in p:
		return int(p.current_level)
	return 1

func _get_vfx() -> Node:
	if _vfx_manager == null or not is_instance_valid(_vfx_manager):
		_vfx_manager = get_node_or_null("/root/VFXManager")
	return _vfx_manager

func _load_sprite_texture() -> void:
	## 子类覆写此方法加载特定纹理
	_ensure_default_texture()
	# 根据碰撞体大小调整精灵缩放
	_adjust_sprite_scale()

func _adjust_sprite_scale() -> void:
	## 小怪统一缩到 56px。横条按一格算，单张仍按长边，见 SpriteSheet。
	_present_sprite(56.0)

func use_sprite(texture: Texture2D, mode: String = "loop") -> void:
	## mode：loop 记下这张当回家的姿态；once 播完回家；hold 播完停在末格。
	if sprite == null or texture == null:
		return
	if mode == "loop":
		_sprite_loop_tex = texture
		_sprite_play = "loop"
		_sprite_hold = false
	else:
		_sprite_play = mode
		_sprite_hold = false
	sprite.texture = texture
	_present_sprite(_sprite_target if _sprite_target > 0.0 else 56.0)

func _present_sprite(target_size: float) -> void:
	if sprite == null or sprite.texture == null:
		return
	# 显式钉住敌人所在的可读性图层：玩家(1) 与弹丸(2) 必须压在敌人(0) 之上，
	# 不依赖 Sprite2D 的默认 z_index。
	sprite.z_index = ReadabilityVisuals.Z_ENEMY
	_sprite_target = target_size
	if _sprite_loop_tex == null or _sprite_play == "loop":
		_sprite_loop_tex = sprite.texture
	if not _sprite_rest_ready:
		_sprite_rest_pos = sprite.position
		_sprite_rest_ready = true
	sprite.position = _sprite_rest_pos
	SpriteSheetLib.apply(sprite, sprite.texture, target_size, sprite_scale_mult)
	_sprite_frame_wait = 0.0
	# 可读性层：轮廓 + 地面投影。跟着缩放一起重算，
	# 精英体型倍率、Boss 形态倍率、换姿态都走这一处，不会漏。
	ReadabilityVisuals.ensure_body_rim(sprite)
	ReadabilityVisuals.ensure_ground_shadow(self, sprite)

func _tick_sprite(delta: float) -> void:
	if sprite == null or not is_instance_valid(sprite) or sprite.texture == null:
		return
	if not _sprite_rest_ready:
		_sprite_rest_pos = sprite.position
		_sprite_rest_ready = true
	if sprite.hframes > 1 and not _sprite_hold:
		sprite.position = _sprite_rest_pos
		if _sprite_play == "loop":
			_sprite_frame_wait = SpriteSheetLib.advance(sprite, _sprite_frame_wait, delta)
		else:
			var stepped: Array = SpriteSheetLib.advance_once(sprite, _sprite_frame_wait, delta)
			_sprite_frame_wait = float(stepped[0])
			if bool(stepped[1]):
				_sprite_hold = true
				if _sprite_play == "once" and _sprite_loop_tex != null:
					_sprite_play = "loop"
					_sprite_hold = false
					sprite.texture = _sprite_loop_tex
					_present_sprite(_sprite_target)
		return
	# 单张没有循环可播。1 像素、1.2 秒的浮动只是过渡，横条换上之后这条不再走。
	_sprite_anim_time += delta
	sprite.position = _sprite_rest_pos + Vector2(0.0, SpriteSheetLib.bob_offset(_sprite_anim_time))

func _ensure_default_texture() -> void:
	if sprite and sprite.texture == null:
		var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		sprite.texture = ImageTexture.create_from_image(img)

func _find_player() -> void:
	# 延迟一帧确保场景树已就绪
	await get_tree().process_frame
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0] as CharacterBody2D

func _physics_process(delta: float) -> void:
	if is_dead or player == null or not is_instance_valid(player):
		return

	# 处理冻结状态
	if is_frozen:
		return  # 冻结时不能移动

	# 处理受击硬直与击退
	if hit_stun_timer > 0:
		hit_stun_timer -= delta
		velocity = knockback_velocity
		move_and_slide()
		# 击退速度衰减
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, KNOCKBACK_FRICTION * delta)
		if hit_stun_timer <= 0 and knockback_velocity.length() < 10.0:
			knockback_velocity = Vector2.ZERO
		return

	_move_towards_player(delta)

func _move_towards_player(_delta: float) -> void:
	## 子类可以覆写此方法实现不同移动方式
	var direction := (player.global_position - global_position).normalized()
	velocity = direction * move_speed
	move_and_slide()
	# 翻转 Sprite 朝向玩家
	if direction.x < 0:
		sprite.flip_h = true
	else:
		sprite.flip_h = false

func take_damage(amount: float) -> void:
	if is_dead:
		return
	amount = _subtract_hp(_direct_damage(amount))
	_apply_hit_freeze()
	_flash_hit()
	_after_damage_taken(amount)
	if current_hp <= 0:
		_die()

func _direct_damage(amount: float) -> float:
	# Every direct weapon hit rolls once, including subclass damage handlers.
	if is_instance_valid(player) and player.has_method("roll_crit") and player.roll_crit():
		amount *= player.crit_damage
	return maxf(amount, 0.0)

func _subtract_hp(amount: float) -> float:
	var effective := minf(maxf(amount, 0.0), maxf(current_hp, 0.0))
	current_hp -= effective
	return effective

func _report_dealt_damage(amount: float) -> void:
	if amount > 0.0 and is_instance_valid(player) and player.has_method("on_dealt_damage"):
		player.on_dealt_damage(amount)

func _after_damage_taken(amount: float) -> void:
	# Drain includes lethal hits; surviving targets alone receive on-hit statuses.
	_report_dealt_damage(amount)
	if is_dead or current_hp <= 0.0 or amount <= 0.0:
		return
	var p := player
	if not is_instance_valid(p):
		return
	if "freeze_chance" in p and randf() < float(p.get("freeze_chance")):
		freeze(2.0)
	if not ("bleed_chance" in p):
		return

	if _status_vfx_cd > 0.0:
		return
	var applied := false
	var bleed_chance: float = float(p.get("bleed_chance"))
	if bleed_chance > 0.0 and randf() < bleed_chance:
		apply_bleed(amount * GameConfig.BLEED_DPS_RATIO, GameConfig.BLEED_DURATION)
		applied = true
	var slow_chance: float = float(p.get("slow_chance"))
	if slow_chance > 0.0 and randf() < slow_chance:
		apply_slow(GameConfig.SLOW_MULT, GameConfig.SLOW_DURATION)
		applied = true
	if applied:
		# 高攻速下每发都判定的话，这两个状态会一直是满覆盖率，
		# 既是数值失控也是屏幕负担 —— 同一敌人 0.3 秒内只判一次
		_status_vfx_cd = GameConfig.STATUS_VFX_COOLDOWN

func _apply_hit_freeze() -> void:
	## 命中冻帧：让受击者停 0.05 秒，给"打中了"一个物理层面的确认。
	## 刻意不用 Engine.time_scale —— 那会把玩家输入一起冻住，是廉价且容易失控的做法。
	## Boss 不冻（体型大、动作慢，冻了反而像卡顿）。
	if is_in_group("boss"):
		return
	hit_stun_timer = maxf(hit_stun_timer, GameConfig.HIT_FREEZE_DURATION)

func take_damage_with_knockback(amount: float, knockback_dir: Vector2, knockback_force: float = 120.0, stun_duration: float = 0.08) -> void:
	if is_dead:
		return
	var hp_before := current_hp
	take_damage(amount)
	if is_dead or current_hp >= hp_before:
		return
	hit_stun_timer = maxf(hit_stun_timer, maxf(stun_duration, GameConfig.HIT_FREEZE_DURATION))
	knockback_velocity += knockback_dir.normalized() * knockback_force

func _flash_hit() -> void:
	## 受击闪白效果
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color(10.0, 10.0, 10.0, 1.0), 0.03)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.07)
	# 受击粒子
	var vfx := _get_vfx()
	if vfx:
		vfx.spawn_hit_particles(global_position, sprite.modulate, 4)
	# 播放受击音效
	var audio_lib := AudioLib
	AudioManager.play_sfx(audio_lib.get_sound("hit_enemy"))

func _die() -> void:
	if is_dead:
		return
	is_dead = true
	enemy_died.emit(self)
	# 记录击杀成就
	_record_kill_for_achievement()
	# 死亡粒子
	var vfx := _get_vfx()
	if vfx:
		vfx.spawn_death_particles(global_position, sprite.modulate, 10)
	# 播放死亡音效
	var audio_lib := AudioLib
	AudioManager.play_sfx(audio_lib.get_sound("enemy_death"))
	# 掉落经验宝石
	_drop_xp_gem()
	# 掉落银币（局内货币）
	_drop_silver()
	# 禁用碰撞
	collision_shape.set_deferred("disabled", true)
	set_physics_process(false)
	# 状态 tick 也一起停：死后还在扣流血会重复走 _die 的判定链
	set_process(false)
	# 死亡动画
	var tween := create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.2)
	tween.tween_property(sprite, "scale", Vector2.ZERO, 0.2)
	tween.tween_callback(queue_free)

func _record_kill_for_achievement() -> void:
	## 子类覆写此方法返回敌人类型
	var enemy_type := _get_enemy_type()
	var ach_mgr := get_node_or_null("/root/AchievementManager")
	if ach_mgr:
		ach_mgr.record_kill(enemy_type)

func _get_enemy_type() -> String:
	## 子类覆写此方法返回敌人类型
	return "unknown"

func freeze(duration: float) -> void:
	## 冻结敌人。Boss 不进入硬控：领主的物理帧一看到 is_frozen 就整段返回，
	## 移动和出招一起停。高攻速再把 2 秒冻结刷新回去，Boss 会一直站着。
	if is_in_group("boss"):
		_chill_boss()
		return
	if is_frozen:
		# 如果已经在冻结中，延长冻结时间
		freeze_timer = maxf(freeze_timer, duration)
		return
	
	is_frozen = true
	freeze_timer = duration
	
	# 视觉冻结效果
	if sprite:
		sprite.modulate = Color(0.5, 0.8, 1.0, 1.0)  # 蓝色调
		# 冻结粒子效果
		var vfx := get_node_or_null("/root/VFXManager")
		if vfx:
			vfx.spawn_freeze_particles(global_position)

func _chill_boss() -> void:
	## 冰冻之心对 Boss 只剩一次短减速。冷却比减速更长，避免每发都续上。
	if is_dead or _boss_freeze_cd > 0.0:
		return
	apply_slow(GameConfig.BOSS_FREEZE_SLOW_MULT, GameConfig.BOSS_FREEZE_DURATION)
	_boss_freeze_cd = GameConfig.BOSS_FREEZE_COOLDOWN
	var vfx := get_node_or_null("/root/VFXManager")
	if vfx and vfx.has_method("spawn_freeze_particles"):
		vfx.spawn_freeze_particles(global_position)

func _unfreeze() -> void:
	## 解除冻结
	is_frozen = false
	freeze_timer = 0.0
	if sprite:
		sprite.modulate = Color.WHITE

func _drop_xp_gem() -> void:
	var gem_scene := preload("res://scenes/player/xp_gem.tscn")
	var gem := ObjectPool.acquire(gem_scene) as Area2D
	gem.global_position = _clamp_drop_position(global_position)
	gem.xp_value = _loot_scaled(xp_value)
	# 对象池复用时重新初始化掉落动画
	if gem.has_method("_setup_gem"):
		gem._setup_gem()
	get_tree().current_scene.call_deferred("add_child", gem)

func _clamp_drop_position(pos: Vector2) -> Vector2:
	## 掉落点必须落在可走区域里。
	## 冲锋/击退/自爆会把敌人推出墙外，死在墙里就掉在墙里——
	## 那枚宝石玩家永远走不到（吸附半径再大也够不着），正是"有经验点捡不到"的另一半来源。
	##
	## 旧实现沿父链找 get_room_bounds，但 enemy 的父节点是 Main（主场景根），
	## Main 没有这个方法 → 整段钳制**被静默跳过**（不报错、不报警），掉落照旧掉在墙外。
	## 现在统一走 RoomLookup：它是全项目唯一的房间解析入口
	## （wave_manager / vampire_mage / weapon_manager 用的都是它）。
	return RoomLookupLib.clamp_into_room(pos, 24.0, self)

func _loot_scaled(base_value: int) -> int:
	## 掉落倍率取整：按小数部分做概率进位，保证长期期望正好等于 base×mult。
	## 直接 round 的话 1×1.3=1.3 会一直是 1，"银币 +30%" 就等于没写。
	if is_equal_approx(loot_mult, 1.0) or base_value <= 0:
		return base_value
	var exact: float = float(base_value) * loot_mult
	var whole: int = int(floor(exact))
	if randf() < (exact - float(whole)):
		whole += 1
	return maxi(whole, 1)

func _drop_silver() -> void:
	## 银币掉落：附近已有银币就"合并金额"，避免同屏堆几十个节点
	var amount: int = _loot_scaled(silver_value)
	if amount <= 0:
		return
	## 先把落点钳回房间内，再谈合并。
	## 旧实现拿 global_position 直接比距离：怪死在墙外时，落点也在墙外，
	## 跟房里的银币永远差着半个房间，合并不了；而且新币也会掉在墙外够不着。
	var drop_pos: Vector2 = _clamp_drop_position(global_position)
	for coin in get_tree().get_nodes_in_group("silver_coins"):
		if is_instance_valid(coin) and coin.global_position.distance_squared_to(drop_pos) < 900.0:
			coin.value += amount
			return
	var packed: PackedScene = preload("res://scenes/player/silver_coin.tscn")
	var coin := packed.instantiate()
	coin.value = amount
	coin.global_position = drop_pos

	var parent: Node = get_tree().current_scene
	if parent == null:
		parent = get_parent()
	if parent == null:
		coin.queue_free()
		return
	parent.call_deferred("add_child", coin)

func _on_contact_area_body_entered(body: Node2D) -> void:
	## 碰到玩家时造成伤害
	if body.is_in_group("player") and body.has_method("take_damage"):
		if not _can_damage_body(body):
			return
		_deal_contact_damage(body)
		# 首次接触的这一次算进冷却：后续按无敌帧节奏继续结算
		_contact_cd = GameConfig.PLAYER_INVINCIBLE_DURATION
