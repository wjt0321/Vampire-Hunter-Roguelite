extends CharacterBody2D

const SpriteSheetLib = preload("res://scripts/core/sprite_sheet.gd")
## 可读性层（轮廓 + 地面投影）。玩家和敌人共用同一套：
## 敌人轮廓暖白、玩家轮廓冷蓝，颜色相反才是"一眼分出谁是谁"的关键，
## 光靠体型（两者都是 56px）在怪堆里分不出来。
## 玩家角色脚本
## 处理移动、生命值、经验升级等核心逻辑
## 射击由 WeaponManager 独立处理

const LightningChainScene = preload("res://scenes/player/lightning_chain.tscn")

# 缓存的 AudioLibrary 实例
var _audio_lib: AudioLibrary = null

# === 移动属性 ===
@export var move_speed: float = 200.0

# === 生命属性 ===
@export var max_hp: float = 100.0
var current_hp: float = max_hp
var is_invincible: bool = false
@export var invincible_duration: float = 0.5

# === 受击击退 ===
## 独立于移动速度的一份速度：受击时被推开，之后按 KNOCKBACK_DECAY 衰减。
var knockback_velocity: Vector2 = Vector2.ZERO
const KNOCKBACK_DECAY: float = 900.0

# === 经验与升级 ===
var current_xp: int = 0
var _xp_remainder: float = 0.0
var current_level: int = 1
var xp_to_next_level: int = 20

# === 战斗属性（可被升级修改） ===
var damage_multiplier: float = 1.0
var speed_multiplier: float = 1.0
var shoot_speed_multiplier: float = 1.0
var pickup_range_bonus: float = 0.0
var armor: float = 0.0  # 护甲值，通过百分比公式换算减伤

func get_total_damage_multiplier() -> float:
	## 获取总伤害倍率（包含狂战士之血效果 + 狂暴增益）
	var total := damage_multiplier
	# 狂战士之血：生命值低于30%时增加伤害
	if berserker_bonus > 0 and current_hp / max_hp < 0.3:
		total += berserker_bonus
	return total * powerup_damage_mult

## 狂暴增益：临时伤害倍率（地面掉落物用）。独立于 damage_multiplier，
## 这样到期复位时不会把玩家自己吃的"攻击强化"卡一起减掉。
var powerup_damage_mult: float = 1.0
var _powerup_time_left: float = 0.0
var _powerup_glow: Node2D = null

func apply_powerup_buff(multiplier: float, duration: float) -> void:
	if multiplier <= 1.0 or duration <= 0.0:
		return
	powerup_damage_mult = maxf(powerup_damage_mult, multiplier)
	_powerup_time_left = maxf(_powerup_time_left, duration)
	if _powerup_glow == null or not is_instance_valid(_powerup_glow):
		_powerup_glow = ProjectileVisuals.attach_glow(self, Color(1.0, 0.42, 0.18), 76.0)
		if _powerup_glow != null:
			_powerup_glow.z_index = 1
	print("⚔️ 狂暴：伤害 ×%.1f，持续 %.0fs" % [multiplier, duration])

func is_powerup_active() -> bool:
	return _powerup_time_left > 0.0

func _process_powerup(delta: float) -> void:
	if _powerup_time_left <= 0.0:
		return
	_powerup_time_left -= delta
	if _powerup_time_left > 0.0:
		return
	_powerup_time_left = 0.0
	powerup_damage_mult = 1.0
	if _powerup_glow != null and is_instance_valid(_powerup_glow):
		_powerup_glow.queue_free()
	_powerup_glow = null
	print("⚔️ 狂暴结束")

# === 被动道具 ===
var passive_items: Array = []
var magnet_multiplier: float = 1.0
## 磁力被动已经贡献过的拾取加成（升级时只补差额，见 _apply_passive_effect）
var _magnet_bonus_applied: float = 0.0
var has_shield: bool = false
var has_shield_item: bool = false
var shield_cooldown: float = 30.0
var shield_timer: float = 0.0
var regen_rate: float = 0.0
var regen_timer: float = 0.0
# 新被动道具
var _greed_bonus_applied: float = 0.0
var xp_bonus_multiplier: float = 0.0  # 贪婪戒指
var berserker_bonus: float = 0.0  # 狂战士之血
var freeze_chance: float = 0.0  # 冰冻之心
var lightning_retaliate_damage: float = 0.0  # 闪电护符
var dodge_chance: float = 0.0  # 影子披风
var lifesteal_chance: float = 0.0  # 吸血獠牙触发几率
var lifesteal_amount: float = 0.03  # 吸血量（最大生命百分比）
var move_speed_bonus_multiplier: float = 0.0  # 疾风靴移速加成
var crit_chance: float = 0.0  # 幸运四叶草暴击几率
var crit_damage: float = 2.0  # 暴击伤害倍率
# 状态修饰器（17.13）：这三个字段由敌人基类的 _after_damage_taken 读取，
# 所以任何武器、任何伤害来源都自动生效，不需要在武器里逐个接线。
var bleed_chance: float = 0.0  # 血刃：命中时流血几率
var slow_chance: float = 0.0  # 霜缚：命中时减速几率
var drain_ratio: float = 0.0  # 汲取：伤害转治疗比例
## 汲取的零头水池：攒够 DRAIN_HEAL_THRESHOLD 才回一次血
var _drain_pool: float = 0.0

# === 角色特性 ===
var character_id: String = "hunter"
var character_passive_timer: float = 0.0
var character_passive_interval: float = 10.0  # 牧师被动每10秒触发

# === 局内货币（银币） ===
## 只在本局有效，结算清零。血晶是局外 Meta 货币，两者不要混。
var silver: int = 0

# === 开火反馈（纯视觉，绝不产生位移） ===
## 早期版本这里存的是"向后速度"，会被加进 velocity 里真正推着人走，
## 用户的反馈就是"发射的时候人物有轻微回退"。
## 现在改成精灵挤压回弹：位置不动，只有 0.08s 的形变，收枪感还在，位移没有了。
var _sprite_base_scale: Vector2 = Vector2.ONE
var _fire_punch_tween: Tween = null
## 挤压进度 0..1（0 = 压到最扁，1 = 回弹到基准）。用进度而不是绝对缩放，
## 这样中途换姿态重算基准时形变不会丢。
var _punch_progress: float = 1.0
var _punch_amount: float = 1.0
var _punch_axis_vertical: bool = false
var _player_pose: String = ""
var _wants_move: bool = false
var _sprite_rest_pos: Vector2 = Vector2.ZERO
var _sprite_rest_ready: bool = false
var _sprite_anim_time: float = 0.0
var _sprite_frame_wait: float = 0.0
# 一次性动作（attack / hurt / shield）：播完自动回 idle / run。
# 这类动作只借 pose 的横条，不碰任何数值与位移——手感仍由 _fire_punch 的挤压负责。
var _one_shot_pose: String = ""
var _one_shot_left: float = 0.0
# 死亡后不再让 _sync_player_pose 抢回 idle；death 横条由 _die() 自己推进
var _player_dead: bool = false
# 护盾光环节点（有护盾时才存在）
var _shield_aura: Sprite2D = null
var _shield_pulse: Tween = null

# === 信号 ===
signal damage_received(amount: float)
signal hp_changed(current: float, maximum: float)
signal xp_changed(current_xp: int, xp_needed: int, level: int)
signal level_up(new_level: int)
signal player_died
signal silver_changed(amount: int)

# === 节点引用 ===
@onready var sprite: Sprite2D = $Sprite2D
@onready var invincible_timer: Timer = $InvincibleTimer
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	add_to_group("player")
	current_hp = max_hp
	xp_to_next_level = GameConfig.get_xp_required(current_level)
	# 视觉优先级：玩家画在敌人之上、危险弹丸之下（见 ReadabilityVisuals）。
	# 不改这条的话，Boss 站到玩家正前方就会把玩家整个盖住。
	if sprite != null:
		sprite.z_index = ReadabilityVisuals.Z_PLAYER
	# 初始化 AudioLib 缓存
	_audio_lib = AudioLib
	# 加载精灵图纹理
	_load_sprite_texture()
	invincible_timer.wait_time = invincible_duration
	invincible_timer.one_shot = true
	invincible_timer.timeout.connect(_on_invincible_timer_timeout)
	hp_changed.emit(current_hp, max_hp)
	xp_changed.emit(current_xp, xp_to_next_level, current_level)

## 取当前角色的精灵：牧师有自己的图，其他角色回退到通用玩家图。
func _player_tex(state: String) -> Texture2D:
	if TextureManager.instance == null:
		return null
	return TextureManager.instance.get_player_texture(state, character_id)

func _load_sprite_texture() -> void:
	## 加载玩家精灵图。开局先贴待机，移动后再换成 run。
	if sprite == null:
		return
	if not _sprite_rest_ready:
		_sprite_rest_pos = sprite.position
		_sprite_rest_ready = true
	var texture := _player_tex("idle")
	if texture:
		sprite.modulate = Color.WHITE
		_apply_player_pose("idle", texture)
	else:
		var img := Image.create(16, 24, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_apply_player_pose("idle", ImageTexture.create_from_image(img))

func _apply_player_pose(pose: String, texture: Texture2D) -> void:
	_player_pose = pose
	sprite.position = _sprite_rest_pos
	# 记下基准缩放：开火挤压是"在基准上乘一个系数再回到基准"。
	_sprite_base_scale = SpriteSheetLib.apply(sprite, texture, 56.0)
	_sprite_frame_wait = 0.0
	# 这里**不能** kill `_fire_punch_tween`。
	# 挤压补间是独立的，只驱动 `_punch_progress` 从 0 走到 1，
	# 每帧把形变乘到**当前** `_sprite_base_scale` 上（见 `_apply_punch_scale`）。
	# 杀掉它等于把进度永远冻在第 0 帧：开火瞬间受击/开盾，
	# 角色就保持压扁状态直到下一次开火。谁建 tween 谁负责 kill（`_fire_punch`）。
	# SpriteSheetLib.apply 写的是**基准**缩放，开火挤压是在它之上再乘一个系数，
	# 如果换了姿态却只留基准值，玩家就看不到后坐（旧实现正是这样把挤压抹掉了）。
	# 所以换完图立刻按当前挤压进度把形变重新贴回去，动作与后坐可以同时存在。
	_apply_punch_scale()
	# 可读性层：冷蓝轮廓 + 地面投影。跟敌人共用同一套节点，
	# 颜色相反（敌人暖白）才能在怪堆里分清谁是玩家。
	ReadabilityVisuals.ensure_body_rim(sprite, ReadabilityVisuals.PLAYER_RIM_COLOR)
	ReadabilityVisuals.ensure_ground_shadow(self, sprite)

func _adjust_sprite_scale() -> void:
	## 保留给外部在换图之后调用。按当前纹理重算一格缩放。
	if sprite and sprite.texture:
		sprite.position = _sprite_rest_pos
		_sprite_base_scale = SpriteSheetLib.apply(sprite, sprite.texture, 56.0)
		_sprite_frame_wait = 0.0

func apply_character_data(char_data: Resource) -> void:
	## 应用角色数据到玩家
	if char_data == null:
		return
	var prev_id := character_id
	character_id = char_data.char_id
	# 每个角色的精灵不同，切人要重新贴图（开局 apply_character_data 在 _ready 之后调用）
	if character_id != prev_id and is_inside_tree():
		_one_shot_pose = ""
		_load_sprite_texture()
	max_hp = char_data.base_hp
	current_hp = max_hp
	move_speed = char_data.base_speed
	damage_multiplier = char_data.base_damage_mult
	# 猎人直觉：拾取范围 +20%
	if character_id == "hunter":
		pickup_range_bonus += 20.0
	hp_changed.emit(current_hp, max_hp)
	print("🎭 应用角色: %s (HP:%.0f 速度:%.0f 伤害:x%.2f)" % [
		char_data.char_name, max_hp, move_speed, damage_multiplier
	])

func _physics_process(delta: float) -> void:
	_handle_movement(delta)
	_handle_rotation()
	_sync_player_pose()
	_tick_player_sprite(delta)
	_process_passive_items(delta)
	_process_character_passive(delta)
	_process_powerup(delta)

func apply_recoil(backward_dir: Vector2, speed: float = -1.0) -> void:
	## 名字保留（外部/测试都按这个接口调用），但语义已经改成"开火挤压"。
	## backward_dir 只用来决定挤压方向，不参与任何位移计算。
	_fire_punch(backward_dir)

func _fire_punch(direction: Vector2) -> void:
	## 开火反馈：沿开火轴的垂直方向压扁一点点，再弹回。
	## 53px 的精灵压 6% ≈ 3px 的视觉变化，读作"枪有后劲"，但角色坐标一动不动。
	if sprite == null or not is_instance_valid(sprite):
		return
	if _sprite_base_scale == Vector2.ONE:
		_sprite_base_scale = sprite.scale
	# 竖直方向开火时压在横轴上，横向开火时压在纵轴上，观感更贴近"后坐"
	var axis_vertical: bool = absf(direction.normalized().y) > absf(direction.normalized().x)
	_punch_axis_vertical = axis_vertical
	_punch_amount = GameConfig.PLAYER_FIRE_PUNCH_SCALE
	_punch_progress = 0.0

	if _fire_punch_tween != null and _fire_punch_tween.is_valid():
		_fire_punch_tween.kill()
	# 开火姿态先切：它会换贴图并重算基准缩放，
	# 顺序反过来的话下面刚建好的回弹 tween 会被换姿态顺手 kill 掉（挤压就卡在最扁的状态）。
	_play_one_shot("attack")
	_apply_punch_scale()
	# 挤压进度从 0% 补到 100%，回调里逐帧把形变乘到**当前**基准上。
	# 不用 tween_property(sprite, "scale") 直接写死目标值：
	# 那样 tween 会把"当时算出的绝对缩放"当成目标，中途换姿态（attack 姿态换图重设基准）
	# 就会打回旧值，动作一切换挤压就消失——这正是"开火没有后坐感"的老 bug。
	_fire_punch_tween = create_tween()
	_fire_punch_tween.tween_method(_set_punch_progress, 0.0, 1.0,
		GameConfig.PLAYER_FIRE_PUNCH_TIME).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

func _set_punch_progress(value: float) -> void:
	_punch_progress = clampf(value, 0.0, 1.0)
	_apply_punch_scale()

func _apply_punch_scale() -> void:
	## 把"当前挤压进度"乘到基准缩放上。进度 1.0 = 完全回弹 = 基准。
	if sprite == null or not is_instance_valid(sprite):
		return
	if _punch_progress >= 1.0:
		sprite.scale = _sprite_base_scale
		return
	var punch: float = _punch_amount + (1.0 - _punch_amount) * _punch_progress
	var factor := Vector2(1.0, 1.0)
	if _punch_axis_vertical:
		factor = Vector2(punch, 2.0 - punch)
	else:
		factor = Vector2(2.0 - punch, punch)
	sprite.scale = factor * _sprite_base_scale

func _handle_movement(delta: float) -> void:
	var input_dir := Vector2.ZERO
	input_dir.x = Input.get_axis("move_left", "move_right")
	input_dir.y = Input.get_axis("move_up", "move_down")
	input_dir = input_dir.normalized()
	var total_speed_mult := speed_multiplier * (1.0 + move_speed_bonus_multiplier)
	# 注意：这里只由输入决定速度。开火反馈是纯视觉的，不许再往 velocity 里塞东西。
	_wants_move = input_dir != Vector2.ZERO
	# 受击击退走独立速度：早期直接写进 velocity，而这一行每帧覆盖 velocity，
	# 结果受击后人物根本没被推开。现在叠加在移动速度上，并按摩擦衰减。
	velocity = input_dir * move_speed * total_speed_mult + knockback_velocity
	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, KNOCKBACK_DECAY * delta)
	move_and_slide()

func _sync_player_pose() -> void:
	## 常驻姿态只有 idle / run 两种；attack / hurt / shield 是一次性动作，由 _play_one_shot 接管。
	if sprite == null or TextureManager.instance == null:
		return
	if _player_dead or _one_shot_pose != "":
		return
	var pose := "run" if _wants_move else "idle"
	if pose == _player_pose:
		return
	var texture := _player_tex(pose)
	if texture == null and pose != "idle":
		texture = _player_tex("idle")
		pose = "idle"
	if texture == null or pose == _player_pose:
		return
	_apply_player_pose(pose, texture)

func _tick_player_sprite(delta: float) -> void:
	if sprite == null or sprite.texture == null:
		return
	if sprite.hframes > 1:
		sprite.position = _sprite_rest_pos
		_sprite_frame_wait = SpriteSheetLib.advance(sprite, _sprite_frame_wait, delta)
		if _one_shot_pose != "":
			_one_shot_left -= delta
			if _one_shot_left <= 0.0:
				_end_one_shot()
		return
	_sprite_anim_time += delta
	sprite.position = _sprite_rest_pos + Vector2(0.0, SpriteSheetLib.bob_offset(_sprite_anim_time))


func _play_one_shot(pose: String, hold: float = 0.0) -> void:
	## 播一次 attack / hurt / shield，播完自动回 idle/run。
	## hold 传 0 表示按素材实际长度算（帧数 ÷ 8fps），这样换素材不用回来改时间。
	## 素材缺失时静默跳过，不影响原有程序特效（挤压仍会照常触发）。
	if _player_dead or sprite == null:
		return
	if TextureManager.instance == null:
		return
	var texture := _player_tex(pose)
	if texture == null:
		return
	if hold <= 0.0:
		hold = float(SpriteSheetLib.frame_count(texture)) / SpriteSheetLib.LOOP_FPS
	_one_shot_pose = pose
	_one_shot_left = maxf(hold, 0.1)
	_apply_player_pose(pose, texture)


func _end_one_shot() -> void:
	_one_shot_pose = ""
	_one_shot_left = 0.0
	_player_pose = ""  # 清掉记录，逼 _sync_player_pose 真的切一次
	_sync_player_pose()

func _handle_rotation() -> void:
	var mouse_pos := get_global_mouse_position()
	var direction := mouse_pos - global_position
	if direction.x < 0:
		sprite.flip_h = true
	else:
		sprite.flip_h = false

# === 经验值相关 ===
func is_dead() -> bool:
	return _player_dead

func gain_xp(amount: int) -> void:
	# 死亡动画期间宝石还会飞过来。再入账会在结算页上面再弹出三选一，
	# 升级层比结算层高，玩家点不到「重开」。
	if _player_dead:
		return
	# 应用贪婪戒指加成
	var exact := amount * (1.0 + xp_bonus_multiplier) + _xp_remainder
	var final_amount := int(floor(exact + 0.000001))
	_xp_remainder = maxf(exact - final_amount, 0.0)
	current_xp += final_amount
	while current_xp >= xp_to_next_level:
		current_xp -= xp_to_next_level
		_level_up()
	xp_changed.emit(current_xp, xp_to_next_level, current_level)

func _level_up() -> void:
	current_level += 1
	xp_to_next_level = GameConfig.get_xp_required(current_level)
	level_up.emit(current_level)
	# 升级光效
	var vfx := get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.spawn_levelup_particles(global_position)
	# 播放升级音效
	AudioManager.play_sfx(_audio_lib.get_sound("level_up"))

# === 银币（局内货币） ===
func add_silver(amount: int) -> void:
	if amount <= 0:
		return
	silver += amount
	silver_changed.emit(silver)

func spend_silver(amount: int) -> bool:
	## 够就扣并返回 true；不够返回 false（调用方据此禁用按钮/提示）
	if amount <= 0:
		return true
	if silver < amount:
		return false
	silver -= amount
	silver_changed.emit(silver)
	return true

# === 升级效果应用 ===
## 基础属性卡的等级（每张卡各自计数）。
## 属性卡有等级上限：满级后既不再进池，也不再叠数值——
## 否则属性卡可以无限叠，"Build 选择"就退化成纯数值膨胀。
var stat_levels: Dictionary = {}

func get_stat_level(stat_id: String) -> int:
	return int(stat_levels.get(stat_id, 0))

func get_stat_max_level() -> int:
	return GameConfig.MAX_STAT_LEVEL

func get_total_stat_level() -> int:
	## 本局所有属性卡等级之和
	var total: int = 0
	for key in stat_levels:
		total += int(stat_levels[key])
	return total

func get_total_stat_max_level() -> int:
	## 属性卡的共享总预算（所有属性卡等级之和的上限）
	return GameConfig.MAX_TOTAL_STAT_LEVEL

func is_stat_budget_exhausted() -> bool:
	## 总预算是否已经用满
	return get_total_stat_level() >= get_total_stat_max_level()

func is_stat_maxed(stat_id: String) -> bool:
	return get_stat_level(stat_id) >= get_stat_max_level()

func apply_upgrade(upgrade_type: String) -> void:
	# 满级后不再生效。升级界面本来就不会再发满级的卡，
	# 这里再挡一道：别的地方直接调 apply_upgrade 时也不会把数值叠穿。
	if is_stat_maxed(upgrade_type):
		return
	# 共享总预算用满后同样不再生效。
	# 单卡上限管的是"这一张最多 5 级"，总预算管的是"这一局总共能堆多少属性"——
	# 两道闸都要有，否则玩家换个方向照样能把属性叠穿预算。
	if is_stat_budget_exhausted():
		return
	stat_levels[upgrade_type] = get_stat_level(upgrade_type) + 1
	match upgrade_type:
		"damage":
			damage_multiplier += GameConfig.UPGRADE_DAMAGE_MULT
		"speed":
			speed_multiplier += GameConfig.UPGRADE_SPEED_MULT
		"shoot_speed":
			shoot_speed_multiplier += GameConfig.UPGRADE_SHOOT_SPEED_MULT
		"max_hp":
			max_hp += GameConfig.UPGRADE_MAX_HP
			current_hp += GameConfig.UPGRADE_MAX_HP
			hp_changed.emit(current_hp, max_hp)
		"armor":
			armor += GameConfig.UPGRADE_ARMOR
		"pickup_range":
			pickup_range_bonus += GameConfig.UPGRADE_PICKUP_RANGE

# === 生命值相关 ===
func spend_hp(amount: float) -> bool:
	## 变异房献血。不走 take_damage：护甲、闪避、无敌帧都会把“赌注”变成折扣，
	## 而且扣到 0 会直接死亡。这里保证至少留下 1 点。
	if amount <= 0.0:
		return true
	if current_hp - amount < 1.0:
		return false
	current_hp -= amount
	hp_changed.emit(current_hp, max_hp)
	return true

func take_damage(amount: float, source_position: Vector2 = Vector2.ZERO) -> float:
	# 死亡保护：玩家已经死了（或血量已经归零）就不再吃伤害。
	# 旧版没有这道闸，玩家死后残留的接触伤害、弹幕会反复触发 _die()，
	# 结算界面被重复触发多次。
	if _player_dead or current_hp <= 0.0 or amount <= 0.0:
		return 0.0
	if is_invincible:
		return 0.0
	amount = GameConfig.scale_incoming_damage(amount)

	# 护盾抵挡伤害
	if has_shield:
		_break_shield()
		_start_invincibility()
		_flash_damage()
		return 0.0

	# 影子披风闪避检查
	if dodge_chance > 0 and randf() < dodge_chance:
		print("🌑 闪避成功!")
		# 闪避视觉效果
		var vfx := get_node_or_null("/root/VFXManager")
		if vfx:
			vfx.spawn_dodge_effect(global_position)
		return 0.0

	# 护甲改为百分比减伤（上限 75%），避免后期固定减伤导致免疫
	var reduction: float = GameConfig.calculate_damage_reduction(armor)
	var actual_damage: float = maxf(amount * (1.0 - reduction), 1.0)
	var hp_before := current_hp
	current_hp = clampf(current_hp - actual_damage, 0.0, max_hp)
	# Capture this hit before signals or retaliation can synchronously heal.
	var effective_damage := maxf(hp_before - current_hp, 0.0)
	if effective_damage > 0.0:
		damage_received.emit(effective_damage)
	hp_changed.emit(current_hp, max_hp)
	_start_invincibility()
	_flash_damage()
	# 受击姿态：只有 2 帧，播完立刻回 idle/run；闪红仍由 _flash_damage 负责
	_play_one_shot("hurt")

	# 受击击退：写进独立速度，不碰移动速度（见 _handle_movement）
	if source_position != Vector2.ZERO:
		var knockback_dir := (global_position - source_position).normalized()
		knockback_velocity += knockback_dir * 300.0

	# 播放受击音效
	AudioManager.play_sfx(_audio_lib.get_sound("player_hurt"))

	# 闪电护符反击
	if lightning_retaliate_damage > 0:
		_lightning_retaliate()

	# 受击屏幕震动 + 粒子
	var vfx := get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.screen_shake(4.0, 0.15)
		vfx.spawn_hit_particles(global_position, Color(0.9, 0.1, 0.1), 6)

	if current_hp <= 0:
		_die()
	return effective_damage

func _lightning_retaliate() -> void:
	## 闪电护符反击
	var enemies := get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		return
	
	# 找到最近的敌人
	var nearest_enemy = null
	var nearest_dist: float = INF
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy.get("is_dead") == true:
			continue
		var dist := global_position.distance_squared_to(enemy.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest_enemy = enemy
	
	if nearest_enemy and nearest_dist < 300 * 300:  # 300范围内
		# 创建闪电效果
		var lightning := LightningChainScene.instantiate()
		lightning.global_position = global_position
		lightning.base_damage = lightning_retaliate_damage
		lightning.damage_multiplier = 1.0
		lightning.max_jumps = 1
		lightning._current_damage = lightning_retaliate_damage
		get_tree().current_scene.add_child(lightning)

		# 身上爆一圈电光，让"反击"这个被动有可见的触发点
		var vfx := get_node_or_null("/root/VFXManager")
		if vfx:
			vfx.spawn_texture_fx("lightning_retaliate", global_position,
				{"scale_from": 0.5, "scale_to": 1.3, "duration": 0.35,
				 "color": Color(1.15, 1.1, 0.8, 1.0)})

		# 播放音效
		AudioManager.play_sfx(_audio_lib.get_sound("lightning_chain"))

func heal(amount: float) -> void:
	# 每日「枯井」：治疗全灭，包括休息房、商店和吸血。升级加的上限不走这里。
	if amount > 0.0 and GameConfig.has_daily("no_heal"):
		return
	current_hp = clampf(current_hp + amount, 0.0, max_hp)
	hp_changed.emit(current_hp, max_hp)
	if amount > 0 and _audio_lib != null:
		AudioManager.play_sfx(_audio_lib.get_sound("heal"))

func change_max_hp(delta_value: float) -> void:
	## 增减最大生命上限（深渊契约这类"临时上限"用）。
	## 故意不动 current_hp 的语义：扣上限时当前血量被 clamp 下去，
	## 还上限时也不会凭空把血补回来——不然契约就是个零成本的血包。
	## 调用方想补血请显式 heal()。
	max_hp = maxf(max_hp + delta_value, 1.0)
	current_hp = clampf(current_hp, 0.0, max_hp)
	hp_changed.emit(current_hp, max_hp)

func roll_crit() -> bool:
	## 暴击判定
	return crit_chance > 0 and randf() < crit_chance

func _on_enemy_died(_enemy: Node2D) -> void:
	## 敌人死亡时触发的效果（吸血等）
	if lifesteal_chance > 0 and randf() < lifesteal_chance:
		var heal_amount := max_hp * lifesteal_amount
		heal(heal_amount)
		print("🦷 吸血触发，恢复 %.1f 生命" % heal_amount)
		var vfx := get_node_or_null("/root/VFXManager")
		if vfx:
			vfx.spawn_hit_particles(global_position, Color(0.8, 0.1, 0.1), 4)

func _start_invincibility() -> void:
	is_invincible = true
	invincible_timer.start()

func _on_invincible_timer_timeout() -> void:
	is_invincible = false
	sprite.modulate = Color.WHITE

func _flash_damage() -> void:
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color(1.0, 0.3, 0.3, 1.0), 0.05)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.05)
	tween.tween_property(sprite, "modulate", Color(1.0, 0.3, 0.3, 0.7), 0.05)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.05)

func _die() -> void:
	if _player_dead:
		return
	# 先打上死亡标记再发信号。player_died 的监听者会同步停波、关界面，
	# 这些回调里如果还有经验结算，必须已经看得到「已死亡」。
	_player_dead = true
	player_died.emit()
	set_physics_process(false)
	collision_shape.set_deferred("disabled", true)
	# 死亡强烈震动
	var vfx := get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.screen_shake(12.0, 0.5)

	# 死亡横条本身就是渐隐的（末帧全透明），所以逐帧播完后直接销毁，
	# 不再叠一层 modulate 淡出——叠了会双重变淡，角色在播到一半时就没了。
	# 注意 physics 已停，不能靠 _tick_player_sprite 推进，得用 tween 手动走帧。
	var death_texture: Texture2D = _player_tex("death")
	if death_texture != null and sprite != null:
		_apply_player_pose("death", death_texture)
		var total: int = maxi(sprite.hframes, 1)
		var step: float = 1.0 / maxf(SpriteSheetLib.LOOP_FPS, 1.0)
		var tw := create_tween()
		for i in range(1, total):
			tw.tween_interval(step)
			tw.tween_callback(sprite.set_frame.bind(i))
		tw.tween_interval(step * 1.5)
		tw.tween_callback(queue_free)
		return

	# 兜底：素材缺失时退回旧的整体淡出
	var tween := create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)

# === 被动道具处理 ===
func _process_passive_items(delta: float) -> void:
	# 护盾计时（只有拿到护盾道具才计时）
	if has_shield_item:
		shield_timer += delta
		if shield_timer >= shield_cooldown and not has_shield:
			_grant_shield()
	
	# 回血计时
	if regen_rate > 0:
		regen_timer += delta
		if regen_timer >= 5.0:  # 每5秒回血
			regen_timer = 0.0
			_heal_regen()

func _process_character_passive(delta: float) -> void:
	## 处理角色专属被动
	match character_id:
		"hunter":
			# 猎人直觉：拾取范围 +20%（只需设置一次即可）
			pass
		"priestess":
			# 神圣庇护：每10秒恢复5%最大生命
			character_passive_timer += delta
			if character_passive_timer >= character_passive_interval:
				character_passive_timer = 0.0
				heal(max_hp * 0.05)
				print("✨ 神圣庇护触发，恢复 %.0f 生命" % (max_hp * 0.05))

func _grant_shield() -> void:
	has_shield = true
	shield_timer = 0.0
	print("🛡️ 护盾生成!")
	# 护盾展开姿态：播一次就回 idle；持续脉冲仍由 _shield_aura 那圈程序光环负责
	_play_one_shot("shield")
	_spawn_shield_aura()
	var vfx := get_node_or_null("/root/VFXManager")
	if vfx:
		vfx.spawn_hit_particles(global_position, GameConfig.SHIELD_AURA_COLOR, 8)

func _spawn_shield_aura() -> void:
	## 护盾的"实体"表现：一圈青蓝色光环。
	## 早期版本是给 sprite 挂一个 set_loops() 的 modulate 循环 —— 有两个致命问题：
	## ① 那个 tween 从来没有被 kill，护盾破了人物还在一直闪蓝；
	## ② modulate 和受击闪红抢同一个属性，挨打时护盾完全看不出来。
	## 现在光环是独立子节点，护盾破时整圈扩散淡出，谁也不会覆盖谁。
	if _shield_aura != null and is_instance_valid(_shield_aura):
		return
	_shield_aura = ProjectileVisuals.make_ring_sprite(GameConfig.SHIELD_AURA_RADIUS, GameConfig.SHIELD_AURA_COLOR)
	_shield_aura.name = "ShieldAura"
	add_child(_shield_aura)
	_shield_aura.modulate.a = 0.0
	var fade_in := create_tween()
	fade_in.tween_property(_shield_aura, "modulate:a", 0.9, 0.16)
	_shield_pulse = create_tween().set_loops()
	_shield_pulse.tween_property(_shield_aura, "modulate:a", 0.5, 0.55)
	_shield_pulse.tween_property(_shield_aura, "modulate:a", 0.9, 0.55)

func _break_shield() -> void:
	has_shield = false
	shield_timer = 0.0
	print("💥 护盾破碎!")
	# 播放护盾破碎音效
	AudioManager.play_sfx(_audio_lib.get_sound("shield_break"))
	_break_shield_aura()
	var vfx := get_node_or_null("/root/VFXManager")
	if vfx:
		# 碎环贴图 + 碎屑，比单纯粒子更像"盾碎了"
		vfx.spawn_shield_break(global_position)
		vfx.spawn_hit_particles(global_position, GameConfig.SHIELD_AURA_COLOR, 10)
		vfx.screen_shake(3.0, 0.12)

func _break_shield_aura() -> void:
	if _shield_pulse != null and _shield_pulse.is_valid():
		_shield_pulse.kill()
	_shield_pulse = null
	if _shield_aura == null or not is_instance_valid(_shield_aura):
		_shield_aura = null
		return
	var ring: Sprite2D = _shield_aura
	_shield_aura = null
	ring.modulate = Color(1.6, 1.9, 2.0, 1.0)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", ring.scale * 1.5, 0.26)
	tw.tween_property(ring, "modulate:a", 0.0, 0.26)
	tw.chain().tween_callback(ring.queue_free)

func get_shield_status() -> Dictionary:
	## 给 HUD 用：是否拥有护盾道具 / 当前是否顶着护盾 / 充能进度
	if not has_shield_item and not has_shield:
		return {"has_item": false, "active": false, "progress": 0.0, "remain": 0.0}
	var progress: float = 1.0
	var remain: float = 0.0
	if not has_shield:
		progress = clampf(shield_timer / maxf(shield_cooldown, 0.01), 0.0, 1.0)
		remain = maxf(shield_cooldown - shield_timer, 0.0)
	return {
		"has_item": has_shield_item,
		"active": has_shield,
		"progress": progress,
		"remain": remain,
	}

func _heal_regen() -> void:
	var heal_amount := max_hp * regen_rate
	heal(heal_amount)
	print("💚 恢复 %.1f 生命" % heal_amount)

func add_passive_item(item) -> void:
	# 检查是否已有相同道具
	for existing in passive_items:
		if existing.item_id == item.item_id:
			existing.level_up()
			_apply_passive_effect(existing)
			print("被动道具升级: %s Lv.%d" % [existing.item_name, existing.current_level])
			return
	
	passive_items.append(item)
	_apply_passive_effect(item)
	print("获得被动道具: %s" % item.item_name)

func _apply_passive_effect(item) -> void:
	match item.effect_type:
		0:  # MAGNET
			magnet_multiplier = item.get_scaled_value()
			# 只补"磁力这一项"的差额，不能直接赋值：
			# 直接写 pickup_range_bonus = 50×倍率 会把猎人自带的 +20 和
			# "拾取范围 +30" 升级一起冲掉，而且再升一级又会重算。
			var want_bonus: float = GameConfig.MAGNET_BASE_RANGE * magnet_multiplier
			pickup_range_bonus += want_bonus - _magnet_bonus_applied
			_magnet_bonus_applied = want_bonus
		1:  # SHIELD
			has_shield_item = true
			shield_cooldown = _passive_capped(item)
			shield_timer = 0.0
			# 拿到道具立刻亮一层：原来要空等 30 秒冷却，玩家会以为"这东西没生效"
			if GameConfig.SHIELD_FIRST_GRANT_IMMEDIATE and not has_shield:
				_grant_shield()
		2:  # REGENERATION
			regen_rate = item.get_scaled_value()
		3:  # GREED
			var want_bonus: float = item.get_scaled_value()
			xp_bonus_multiplier += want_bonus - _greed_bonus_applied
			_greed_bonus_applied = want_bonus
		4:  # BERSERKER
			berserker_bonus = item.get_scaled_value()
		5:  # FROZEN
			freeze_chance = _passive_capped(item)
		6:  # LIGHTNING_SHIELD
			lightning_retaliate_damage = item.get_scaled_value()
		7:  # SHADOW
			dodge_chance = _passive_capped(item)
		8:  # VAMPIRIC
			lifesteal_chance = _passive_capped(item)
		9:  # SWIFT
			move_speed_bonus_multiplier = item.get_scaled_value()
		10: # CLOVER
			crit_chance = _passive_capped(item)
		11: # BLEED
			bleed_chance = _passive_capped(item)
		12: # SLOW
			slow_chance = _passive_capped(item)
		13: # DRAIN
			drain_ratio = _passive_capped(item)

func _passive_capped(item) -> float:
	## 生效值一律经 GameConfig.cap_passive_value()。
	## 升级卡预览、满级判定、这里三处共用同一张上限表——
	## 分散成 minf 各处一份时，改上限必然漏掉一边。
	##
	## 空值必须显式返回：GDScript 对 null 取属性只会**报运行时错误并中断整个函数**，
	## 返回值变成 null，调用方 float(null) 侥幸是 0.0，控制台却每帧刷错误。
	if item == null:
		return 0.0
	if not (item.has_method("get_scaled_value") and "item_id" in item):
		return 0.0
	if item.has_method("effective_value"):
		return float(item.effective_value())
	return GameConfig.cap_passive_value(String(item.item_id), item.get_scaled_value())

func on_dealt_damage(amount: float) -> void:
	## 汲取的入账口。由敌人基类在每次受伤时回调。
	## 刻意不走 heal()：那会播治疗音效，高频武器等于持续"漏水声"。
	## 零头先攒着，攒够阈值再结算一次，血量变化看得清也有节奏。
	if GameConfig.has_daily("no_heal") or _player_dead or current_hp <= 0.0:
		_drain_pool = 0.0
		return
	if drain_ratio <= 0.0 or amount <= 0.0:
		return
	_drain_pool += amount * drain_ratio
	if _drain_pool < GameConfig.DRAIN_HEAL_THRESHOLD:
		return
	var gain: float = floorf(_drain_pool)
	_drain_pool -= gain
	if current_hp >= max_hp:
		_drain_pool = 0.0
		return
	current_hp = clampf(current_hp + gain, 0.0, max_hp)
	hp_changed.emit(current_hp, max_hp)

func get_owned_passive_items() -> Array[String]:
	## 获取已拥有的被动道具ID列表
	var items: Array[String] = []
	for item in passive_items:
		items.append(item.item_id)
	return items
