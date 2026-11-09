extends Node2D
class_name EliteAffixController
## 精英词缀控制器
##
## 必须 extends Node2D：光环与图标是 CanvasItem，父节点若不是 CanvasItem，
## 它们不会继承敌人的坐标，会全部画在世界原点（实机截图才发现的）。
##
## 为什么是"子节点"而不是写在敌人基类里：
## 现有敌人里有一半自己覆写了 `_physics_process`（吸血鬼后撤、狼人冲锋、石像鬼石化…），
## 基类里加的钩子对它们完全不生效。挂在子节点上、自己跑 `_physics_process`，
## 才能对所有敌人一视同仁；需要接管移动时用 `host.set_physics_process(false)` 让宿主让位。
##
## 各词缀职责：
##   shielded —— 护盾当 HP 用（见 enemy_base：护盾量直接加到 max_hp），
##               这里只负责"盾被打空"的破碎演出。这样任何覆写了 take_damage 的敌人
##               都不需要改一行代码就有护盾。
##   splitter —— 监听 enemy_died，死亡瞬间裂成两只小的（裂变体不再带词缀）。
##   charger  —— 前摇（地面预警）→ 突进 → 收招，前摇期间剥夺宿主的物理帧。
##   haster   —— 周期性给周围小怪上 `apply_haste`，优先集火目标。
##
## 多词缀（深渊猎物）：同一只敌人可以挂两个控制器。slot 0 保持旧名字
## `AffixController` 以兼容既有测试与外部查找；slot 1 用自己的名字、
## 图标位置和光环半径，避免两个图标叠成一个、两圈光环看起来像一圈。

var host: Node = null
var affix_id: String = ""
var color: Color = Color.WHITE
## 词缀槽位：0 = 主词缀，1 = 第二词缀
var slot: int = 0

var _ring: Sprite2D = null
var _ring_tween: Tween = null
var _host_physics_disabled: bool = false

# 冲锋状态机
const CHARGE_IDLE := 0
const CHARGE_WINDUP := 1
const CHARGE_DASH := 2
const CHARGE_RECOVER := 3
var _charge_state: int = CHARGE_IDLE
var _charge_timer: float = 0.0
var _charge_dir: Vector2 = Vector2.ZERO
var _charge_cd: float = 0.0

# 急速光环
var _aura_timer: float = 0.0

func setup(enemy: Node, id: String, affix_slot: int = 0) -> void:
	host = enemy
	affix_id = id
	slot = affix_slot
	color = EliteAffix.color(id)
	# 第一槽位必须叫 AffixController：既有测试和调试路径都按这个名字找节点
	name = "AffixController" if slot == 0 else "AffixController%d" % (slot + 1)
	# 宿主死了就一起消失，不用手动清理
	add_to_group("elite_affixes")

func _ready() -> void:
	if host == null or affix_id.is_empty():
		return
	_build_visuals()
	if is_affix("splitter"):
		if host.has_signal("enemy_died"):
			host.enemy_died.connect(_on_host_died)
	# 冲锋的第一次不要立刻触发，给玩家看见它的时间
	_charge_cd = GameConfig.AFFIX_CHARGE_FIRST_DELAY

func is_affix(id: String) -> bool:
	return affix_id == id

# ==================== 表现 ====================

func _build_visuals() -> void:
	# 光环：标出"这只是精英"，同时按词缀区分颜色（和地面预警同一套镂空圆环）
	# 第二词缀的环略大：两圈同心同径会互相盖住，看起来仍然只有一条词缀
	_ring = ProjectileVisuals.make_ring_sprite(78.0 + 14.0 * slot, color)
	_ring.name = "AffixRing"
	# 注意：不能沿用 make_ring_sprite 里的 z_index = -1。
	# 那只适用于"玩家脚底的光环"（父节点是自己画自己），这里是敌人的子节点，
	# z=-1 会钻到地板下面彻底看不见（实机截图验证过）。
	_ring.z_index = 0
	_ring.position = Vector2(0, 2)
	add_child(_ring)
	_ring_tween = create_tween().set_loops()
	_ring_tween.tween_property(_ring, "modulate:a", 0.35, 0.65).set_trans(Tween.TRANS_SINE)
	_ring_tween.tween_property(_ring, "modulate:a", 0.9, 0.65).set_trans(Tween.TRANS_SINE)

	# 图标：光靠颜色区分四种词缀太难，头顶给一个能一眼读懂的符号。
	# 2026-11-09 反馈"只有单字特别简陋"：换成手绘词缀图标（affix_icons.py，
	# 形状+颜色双通道识别）。
	# 旧版拿不到贴图再回退单字——那正是"只有字没有图标"的来源。
	# 现在拿不到贴图就不画图标：缺图一眼能看出来，
	# tools/verify_round4.gd 会把这种情况当成回归报出来。
	# 两个词缀时图标向左错开一格，叠在一起等于只显示了一个。
	var affix_tex: Texture2D = TextureManager.instance.get_affix_icon(affix_id) \
		if TextureManager.instance != null else null
	if affix_tex != null:
		var icon_spr := Sprite2D.new()
		icon_spr.name = "AffixIcon"
		icon_spr.texture = affix_tex
		icon_spr.scale = Vector2.ONE  # 24px 源图，实机显示约 20px 再由镜头缩放决定
		icon_spr.position = Vector2(-18.0 - 22.0 * slot, -66.0)
		icon_spr.z_index = 1
		add_child(icon_spr)

	# 出场：一圈扩散的光环，让"精英来了"在混战里也能被注意到
	var spawn_ring := ProjectileVisuals.make_ring_sprite(40.0, color)
	spawn_ring.name = "SpawnRing"
	spawn_ring.z_index = 0
	spawn_ring.position = Vector2(0, 2)
	add_child(spawn_ring)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(spawn_ring, "scale", spawn_ring.scale * 3.2, 0.45).set_ease(Tween.EASE_OUT)
	tw.tween_property(spawn_ring, "modulate:a", 0.0, 0.45)
	tw.chain().tween_callback(spawn_ring.queue_free)

# ==================== 每帧 ====================

func _physics_process(delta: float) -> void:
	if host == null or not is_instance_valid(host) or host.is_dead:
		return
	_tick_shield()
	if is_affix("haster"):
		_tick_aura(delta)
	if is_affix("charger"):
		_tick_charge(delta)

func _tick_shield() -> void:
	## 护盾量已经算进 max_hp，所以"血量掉到护盾线以下"就是"盾破了"
	if not is_affix("shielded"):
		return
	if float(host.get("affix_shield_hp")) <= 0.0:
		return
	var shield: float = float(host.get("affix_shield_hp"))
	if float(host.current_hp) <= float(host.max_hp) - shield + 0.01:
		_break_shield()

func _break_shield() -> void:
	host.set("affix_shield_hp", 0.0)
	print("🛡💥 %s 的护盾被击碎" % EliteAffix.display_name(affix_id))
	# 破碎演出：环瞬间放大 + 淡出
	if _ring != null and is_instance_valid(_ring):
		if _ring_tween != null and _ring_tween.is_valid():
			_ring_tween.kill()
		_ring_tween = null
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(_ring, "scale", _ring.scale * 2.0, 0.25).set_ease(Tween.EASE_OUT)
		tw.tween_property(_ring, "modulate:a", 0.0, 0.25)
		tw.chain().tween_callback(func():
			if is_instance_valid(_ring):
				_ring.queue_free()
			_ring = null
		)
	var vfx := get_node_or_null("/root/VFXManager")
	if vfx and is_instance_valid(host):
		vfx.spawn_freeze_particles(host.global_position)

# ==================== 急速光环 ====================

func _tick_aura(delta: float) -> void:
	_aura_timer -= delta
	if _aura_timer > 0.0:
		return
	_aura_timer = GameConfig.AFFIX_HASTE_TICK
	var radius_sq: float = GameConfig.AFFIX_HASTE_RADIUS * GameConfig.AFFIX_HASTE_RADIUS
	for e in get_tree().get_nodes_in_group("enemies"):
		if e == host or not is_instance_valid(e):
			continue
		if not (e is Node2D):
			continue
		if (e as Node2D).global_position.distance_squared_to(host.global_position) > radius_sq:
			continue
		if e.has_method("apply_haste"):
			e.apply_haste(GameConfig.AFFIX_HASTE_DURATION)

# ==================== 冲锋 ====================

func _tick_charge(delta: float) -> void:
	if host.is_frozen:
		_abort_charge()
		return
	match _charge_state:
		CHARGE_IDLE:
			_charge_cd = maxf(_charge_cd - delta, 0.0)
			if _charge_cd <= 0.0 and _player_distance() <= GameConfig.AFFIX_CHARGE_RANGE:
				_begin_windup()
		CHARGE_WINDUP:
			host.velocity = Vector2.ZERO
			_charge_timer -= delta
			# 前摇期间持续修正方向：玩家跑开时预警圈跟着转，但不会贴脸
			if host.player != null and is_instance_valid(host.player):
				_charge_dir = (host.player.global_position - host.global_position).normalized()
			if _charge_timer <= 0.0:
				_begin_dash()
		CHARGE_DASH:
			_charge_timer -= delta
			host.velocity = _charge_dir * float(host.move_speed) * GameConfig.AFFIX_CHARGE_SPEED_MULT
			host.move_and_slide()
			if _charge_timer <= 0.0:
				_charge_state = CHARGE_RECOVER
				_charge_timer = GameConfig.AFFIX_CHARGE_RECOVER
		CHARGE_RECOVER:
			host.velocity = Vector2.ZERO
			_charge_timer -= delta
			if _charge_timer <= 0.0:
				_end_charge()

func _player_distance() -> float:
	if host.player == null or not is_instance_valid(host.player):
		return 99999.0
	return host.global_position.distance_to(host.player.global_position)

func _begin_windup() -> void:
	_charge_state = CHARGE_WINDUP
	_charge_timer = GameConfig.AFFIX_CHARGE_WINDUP
	# 让宿主自己的 _physics_process 闭嘴：一半敌人覆写了它，光设 velocity 拦不住
	if not _host_physics_disabled:
		host.set_physics_process(false)
		_host_physics_disabled = true
	host.velocity = Vector2.ZERO
	if host.player != null and is_instance_valid(host.player):
		_charge_dir = (host.player.global_position - host.global_position).normalized()
	var vfx := get_node_or_null("/root/VFXManager")
	if vfx:
		var landing: Vector2 = host.global_position + _charge_dir * 190.0
		vfx.spawn_ground_marker(landing, 62.0, color, GameConfig.AFFIX_CHARGE_WINDUP)

func _begin_dash() -> void:
	_charge_state = CHARGE_DASH
	_charge_timer = GameConfig.AFFIX_CHARGE_DURATION

func _end_charge() -> void:
	_charge_state = CHARGE_IDLE
	_charge_cd = GameConfig.AFFIX_CHARGE_COOLDOWN
	_charge_timer = 0.0
	_restore_host_physics()

func _abort_charge() -> void:
	## 被冻结/眩晕打断：必须把物理帧还回去，否则这只怪会僵在原地直到死
	if _charge_state == CHARGE_IDLE:
		return
	_charge_state = CHARGE_IDLE
	_charge_cd = GameConfig.AFFIX_CHARGE_RECOVER
	_charge_timer = 0.0
	_restore_host_physics()

func _restore_host_physics() -> void:
	if _host_physics_disabled and host != null and is_instance_valid(host) and not host.is_dead:
		host.set_physics_process(true)
	_host_physics_disabled = false

# ==================== 裂变 ====================

func _on_host_died(_enemy: Node2D) -> void:
	if not is_affix("splitter") or host == null or not is_instance_valid(host):
		return
	_spawn_splitlings()

func _spawn_splitlings() -> void:
	var path: String = String(host.scene_file_path)
	if path.is_empty():
		return
	var scene := load(path) as PackedScene
	if scene == null:
		return
	var parent: Node = host.get_parent()
	if parent == null:
		return
	var count: int = GameConfig.AFFIX_SPLIT_COUNT
	for i in range(count):
		var child = scene.instantiate()
		if not ("elite_affix" in child):
			child.queue_free()
			continue
		# 裂变体不再带词缀，否则会无限裂变直到卡死
		child.suppress_affix = true
		child.elite_affix = ""
		if "secondary_affix" in child:
			child.secondary_affix = ""
		child.hp_scale = float(host.hp_scale) * GameConfig.AFFIX_SPLIT_HP_RATIO
		child.sprite_scale_mult = float(host.sprite_scale_mult) * GameConfig.AFFIX_SPLIT_SCALE
		child.spawn_wave = int(host.spawn_wave)
		child.floor_index = int(host.floor_index)
		child.xp_value = maxi(1, int(host.xp_value) / 3)
		child.silver_value = 0
		var angle := TAU * float(i) / float(maxi(count, 1))
		# 与宿主是同一个父节点，所以直接用相对坐标即可（不需要先入树）
		child.position = host.position + Vector2(cos(angle), sin(angle)) * 26.0
		var wm := get_tree().get_first_node_in_group("wave_manager")
		if wm != null and child.has_signal("enemy_died") and wm.has_method("_on_enemy_died"):
			child.enemy_died.connect(wm._on_enemy_died)
		parent.call_deferred("add_child", child)

func _exit_tree() -> void:
	# 宿主被释放时如果还欠着物理帧，还回去（避免池化/复用场景下留下僵尸状态）
	_restore_host_physics()
