extends SceneTree
## 炼金亲王双单位行为回归 + 死亡演出契约 + 动画状态机（Task 4）：
## pair/solo 掷瓶冷却与 puddle 落地、巨像砸地 16 伤害与 1.6s 冷却（enraged && <90px）、
## enrage 移速 70、colossus_fell 后亲王 solo（移速 140、冷却 1.3s）、
## 巨像先倒 0.8s 内自回收 + boss_phase_changed(1)、
## 亲王先倒留尸不 queue_free + 巨像 enrage + boss_phase_changed(2)、
## 双倒 boss_defeated 发出且双单位 <0.8s 内各自回收。
## 动画层：亲王 death > intro(idle) > cast > solo_shift > move > idle；
## 巨像 death > slam > enrage > move > idle；帧推进、同帧起播、暂停冻结。
## -- --real-assets 模式校验 10 张真实 PNG（768×128）且双单位不使用占位图。
## godot --headless --path . --script res://tools/alchemist_prince_animation_test.gd [-- --real-assets]
##
## 玩家替身：与守望者测试同一模式 —— Target(CharacterBody2D) 命名 "Player"
## 并加入 "player" 组；_new_pair() 显式 unit.player = _target，不依赖延迟一帧的
## _find_player。注意 potion_puddle 按距离（半径 70）掉血，砸地 hp 记账的用例里
## 用 prince._timer=9999 压住掷瓶，避免 puddle 干扰。
## fixture 模式注入内存纹理（亲王/巨像各 5 状态，按键名分开，重叠状态不串）；
## 注入后重置 _animation_state 并手动 tick 一次，行为断言不依赖自动帧。

const PRINCE_STATES := ["idle", "move", "cast", "solo_shift", "death"]
const COLOSSUS_STATES := ["idle", "move", "slam", "enrage", "death"]
const Slots = preload("res://scripts/core/asset_slots.gd")

var _pass := 0
var _fail := 0
var _host: Node2D
var _target: Target
var _prince_textures: Dictionary = {}
var _colossus_textures: Dictionary = {}
var _real := false

class Target extends CharacterBody2D:
	var hp := 1000.0
	func take_damage(amount: float, _origin: Vector2 = Vector2.ZERO) -> void:
		hp -= amount

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, label: String) -> void:
	if ok:
		_pass += 1
		print("PASS " + label)
	else:
		_fail += 1
		print("FAIL " + label)

func _run() -> void:
	await process_frame
	_real = "--real-assets" in OS.get_cmdline_user_args()
	print("ALCHEMIST_PRINCE_ANIMATION mode=" + ("real-assets" if _real else "fixture"))
	for i in PRINCE_STATES.size():
		var state: String = PRINCE_STATES[i]
		if _real:
			var texture := Slots.boss_texture("alchemist_prince", state)
			_check(texture != null and texture.get_size() == Vector2(768, 128), "asset alchemist_prince/" + state + " is 768x128")
			if texture != null:
				_prince_textures[state] = texture
		else:
			var image := Image.create(768, 128, false, Image.FORMAT_RGBA8)
			image.fill(Color.from_hsv(float(i) / 10.0, 0.7, 0.8))
			_prince_textures[state] = ImageTexture.create_from_image(image)
	for i in COLOSSUS_STATES.size():
		var state: String = COLOSSUS_STATES[i]
		if _real:
			var texture := Slots.boss_texture("alchemist_colossus", state)
			_check(texture != null and texture.get_size() == Vector2(768, 128), "asset alchemist_colossus/" + state + " is 768x128")
			if texture != null:
				_colossus_textures[state] = texture
		else:
			var image := Image.create(768, 128, false, Image.FORMAT_RGBA8)
			image.fill(Color.from_hsv(float(5 + i) / 10.0, 0.7, 0.8))
			_colossus_textures[state] = ImageTexture.create_from_image(image)
	if _prince_textures.size() != 5 or _colossus_textures.size() != 5:
		_finish()
		return
	_host = Node2D.new()
	root.add_child(_host)
	current_scene = _host
	_target = Target.new()
	_target.name = "Player"
	_target.collision_layer = 0
	_target.collision_mask = 0
	_host.add_child(_target)
	_target.global_position = Vector2(200, 0)  # 亲王右侧 200px：移速/掷瓶断言都在这个方向
	_target.add_to_group("player")
	_test_interfaces_exist()
	await _test_enrage()
	await _test_colossus_slam()
	await _test_pair_toss()
	await _test_colossus_fell_solo()
	await _test_prince_falls_first()
	await _test_double_kill()
	_test_prince_state_mapping()
	_test_colossus_state_mapping()
	_test_frame_advance()
	await _test_visual_timers()
	await _test_death_animation()
	await _test_pause_freezes_animation()
	_test_real_assets_bootstrap()
	_host.queue_free()
	await process_frame
	_finish()

func _new_pair() -> Array:
	_target.hp = 1000.0
	_target.global_position = Vector2(200, 0)
	var prince = load("res://scenes/enemies/alchemist_prince.tscn").instantiate()
	prince.skip_intro = true
	_host.add_child(prince)  # _ready 里同步 _spawn_colossus，返回时 colossus 已在树上
	prince.global_position = Vector2(0, 0)
	prince.player = _target
	if not _real:
		prince._animation_textures = _prince_textures.duplicate()
		prince._animation_state = ""
		prince._tick_sprite(0.0)
	var colossus: Node = prince.colossus
	colossus.player = _target
	if not _real:
		colossus._animation_textures = _colossus_textures.duplicate()
		colossus._animation_state = ""
		colossus._tick_sprite(0.0)
	return [prince, colossus]

func _anim_pair() -> Array:
	## 帧断言专用：关掉自动处理（行为断言不依赖自动帧），手动推 _tick_sprite
	var pair := _new_pair()
	var prince = pair[0]
	var colossus = pair[1]
	prince.set_process(false)
	prince.set_physics_process(false)
	colossus.set_process(false)
	colossus.set_physics_process(false)
	return pair

func _pose(unit, textures: Dictionary, state: String, label: String) -> void:
	_check(unit._animation_state == state and unit.sprite.texture == textures.get(state) and not unit.using_placeholder, label + " [" + state + "]")

func _puddles() -> Array:
	var out: Array = []
	for child in _host.get_children():
		var s: Script = child.get_script()
		if s != null and s.resource_path == "res://scripts/map/potion_puddle.gd":
			out.append(child)
	return out

func _clear_units() -> void:
	for child in _host.get_children():
		if child != _target:
			child.free()

func _test_interfaces_exist() -> void:
	var prince = load("res://scenes/enemies/alchemist_prince.tscn").instantiate()
	var colossus = load("res://scenes/enemies/alchemist_colossus.tscn").instantiate()
	_check(prince.has_method("take_damage"), "prince exposes take_damage")
	_check(prince.has_method("colossus_fell"), "prince exposes colossus_fell")
	_check(prince.has_method("_finish_fight"), "prince exposes _finish_fight")
	_check(prince.has_method("_toss"), "prince exposes _toss")
	_check(colossus.has_method("enrage"), "colossus exposes enrage")
	_check(colossus.has_method("take_damage"), "colossus exposes take_damage")
	_check(prince.has_signal("boss_phase_changed"), "prince exposes boss_phase_changed")
	_check(prince.has_signal("boss_defeated"), "prince exposes boss_defeated")
	_check(prince.has_signal("enemy_died"), "prince exposes enemy_died")
	_check("colossus" in prince and "_mode" in prince, "prince exposes colossus/_mode")
	_check("enraged" in colossus, "colossus exposes enraged")
	_check(ResourceLoader.exists("res://scripts/map/potion_puddle.gd"), "potion_puddle script exists")
	_check(prince.has_method("_show_animation"), "prince exposes _show_animation")
	_check(prince.has_method("_tick_sprite"), "prince exposes _tick_sprite")
	_check(prince.has_method("_set_animation_frame"), "prince exposes _set_animation_frame")
	_check(prince.has_method("_animation_for_state"), "prince exposes _animation_for_state")
	_check(prince.has_method("_advance_death_frame"), "prince exposes _advance_death_frame")
	_check("_animation_textures" in prince, "prince exposes _animation_textures")
	_check(colossus.has_method("_show_animation"), "colossus exposes _show_animation")
	_check(colossus.has_method("_set_animation_frame"), "colossus exposes _set_animation_frame")
	_check(colossus.has_method("_animation_for_state"), "colossus exposes _animation_for_state")
	_check(colossus.has_method("_advance_death_frame"), "colossus exposes _advance_death_frame")
	_check("_animation_textures" in colossus, "colossus exposes _animation_textures")
	prince.free()
	colossus.free()

func _test_enrage() -> void:
	var pair := _new_pair()
	var colossus: Node = pair[1]
	colossus.enrage()
	_check(colossus.enraged == true, "enrage sets enraged flag")
	_check(is_equal_approx(colossus.move_speed, 70.0), "enrage sets move speed to 70")
	_check(is_equal_approx(colossus._timer, 0.4), "enrage resets slam timer to 0.4")
	_clear_units()

func _test_colossus_slam() -> void:
	var pair := _new_pair()
	var prince: Node = pair[0]
	var colossus: Node = pair[1]
	prince._timer = 9999.0  # 压住掷瓶：puddle 按距离掉血，会干扰砸地的 hp 记账
	_target.global_position = colossus.global_position + Vector2(50, 0)  # 砸地射程（<90px）内
	colossus._timer = 0.05
	await create_timer(0.15).timeout
	_check(_target.hp == 1000.0, "no slam while not enraged")
	colossus.enrage()
	colossus._timer = 0.05
	await create_timer(0.15).timeout
	_check(_target.hp == 984.0, "enraged slam deals 16 inside 90px")
	_check(colossus._timer > 1.4, "slam cooldown resets to 1.6")
	_target.global_position = colossus.global_position + Vector2(300, 0)  # 射程外
	colossus._timer = 0.05
	await create_timer(0.15).timeout
	_check(_target.hp == 984.0, "slam misses beyond 90px")
	_clear_units()

func _test_pair_toss() -> void:
	var pair := _new_pair()
	var prince: Node = pair[0]
	await create_timer(0.05).timeout
	_check(absf(prince.velocity.length() - 78.0) < 1.0, "pair mode moves at 78")
	var before := _puddles().size()
	prince._timer = 0.05
	await create_timer(0.15).timeout
	var puddles := _puddles()
	_check(puddles.size() == before + 1, "pair toss lands a puddle")
	if puddles.size() > before:
		var puddle: Node2D = puddles[puddles.size() - 1]
		_check(puddle.damage == 10.0, "puddle damage is 10")
		_check(puddle.global_position.distance_to(_target.global_position) < 1.0, "puddle lands at player position")
	_check(prince._timer > 2.05, "pair toss cooldown resets to 2.2")
	_clear_units()

func _test_colossus_fell_solo() -> void:
	var pair := _new_pair()
	var prince: Node = pair[0]
	var colossus: Node = pair[1]
	var phases: Array = []
	prince.boss_phase_changed.connect(func(p): phases.append(p))
	colossus.take_damage(1000000.0)
	_check(prince._mode == "solo_prince", "colossus fell switches prince to solo_prince")
	_check(phases == [1], "colossus fell emits boss_phase_changed(1)")
	await create_timer(0.2).timeout
	_check(is_instance_valid(colossus), "colossus death performance plays (still valid 0.2s after death)")
	await create_timer(0.6).timeout
	_check(not is_instance_valid(colossus), "colossus self-recycles within 0.8s of death")
	_check(absf(prince.velocity.length() - 140.0) < 1.0, "solo prince moves at 140")
	var before := _puddles().size()
	prince._timer = 0.05
	await create_timer(0.15).timeout
	_check(_puddles().size() == before + 1, "solo toss lands a puddle")
	_check(prince._timer > 1.15, "solo toss cooldown resets to 1.3")
	_clear_units()

func _test_prince_falls_first() -> void:
	var pair := _new_pair()
	var prince: Node = pair[0]
	var colossus: Node = pair[1]
	var phases: Array = []
	var defeated := [false]
	prince.boss_phase_changed.connect(func(p): phases.append(p))
	prince.boss_defeated.connect(func(): defeated[0] = true)
	prince.take_damage(1000000.0)
	_check(prince.is_dead, "prince dies when hp depleted")
	await create_timer(0.3).timeout
	_check(is_instance_valid(prince), "prince corpse stays while colossus alive")
	_check(colossus.enraged == true, "colossus enrages when prince falls first")
	_check(phases == [2], "prince falling first emits boss_phase_changed(2)")
	await create_timer(0.5).timeout
	_check(prince.visible == false, "prince corpse ends up invisible")
	colossus.take_damage(1000000.0)
	_check(defeated[0] == true, "boss_defeated fires when both are down")
	await create_timer(0.8).timeout
	_check(not is_instance_valid(prince), "prince self-recycles within 0.8s after colossus falls")
	_clear_units()

func _test_double_kill() -> void:
	var pair := _new_pair()
	var prince: Node = pair[0]
	var colossus: Node = pair[1]
	var defeated := [false]
	prince.boss_defeated.connect(func(): defeated[0] = true)
	colossus.take_damage(1000000.0)
	await create_timer(0.8).timeout
	_check(not is_instance_valid(colossus), "double kill: colossus recycled within 0.8s")
	prince.take_damage(1000000.0)
	_check(defeated[0] == true, "double kill: boss_defeated fires")
	await create_timer(0.8).timeout
	_check(not is_instance_valid(prince), "double kill: prince recycled within 0.8s")
	_clear_units()

func _test_prince_state_mapping() -> void:
	## 亲王 5 状态映射与优先级 death > intro(idle) > cast > solo_shift > move > idle
	var pair := _anim_pair()
	var prince = pair[0]
	_pose(prince, _prince_textures, "idle", "prince spawn has dedicated idle")
	prince.velocity = Vector2(10.0, 0.0)
	prince._tick_sprite(0.0)
	_pose(prince, _prince_textures, "move", "prince moving selects move")
	prince.velocity = Vector2.ZERO
	prince._cast_visual_remaining = prince.CAST_VISUAL
	prince._solo_shift_visual_remaining = prince.SOLO_SHIFT_VISUAL
	prince._tick_sprite(0.0)
	_pose(prince, _prince_textures, "cast", "cast visual selects cast")
	prince._cast_visual_remaining = 0.0
	prince._tick_sprite(0.0)
	_pose(prince, _prince_textures, "solo_shift", "cast outranks solo_shift, then solo_shift shows")
	prince.intro_invulnerable = true
	prince._tick_sprite(0.0)
	_pose(prince, _prince_textures, "idle", "intro pins idle above action visuals")
	prince.intro_invulnerable = false
	_check(prince._animation_for_state() == "solo_shift", "solo_shift resumes when intro lifts")
	prince._solo_shift_visual_remaining = 0.0
	prince.velocity = Vector2(10.0, 0.0)
	prince.is_dead = true
	_check(prince._animation_for_state() == "death", "prince death outranks everything")
	_clear_units()

func _test_colossus_state_mapping() -> void:
	## 巨像 5 状态映射与优先级 death > slam > enrage > move > idle
	var pair := _anim_pair()
	var colossus = pair[1]
	_pose(colossus, _colossus_textures, "idle", "colossus spawn has dedicated idle")
	colossus.velocity = Vector2(10.0, 0.0)
	colossus._tick_sprite(0.0)
	_pose(colossus, _colossus_textures, "move", "colossus moving selects move")
	colossus.velocity = Vector2.ZERO
	colossus._slam_visual_remaining = colossus.SLAM_VISUAL
	colossus._enrage_visual_remaining = colossus.ENRAGE_VISUAL
	colossus._tick_sprite(0.0)
	_pose(colossus, _colossus_textures, "slam", "slam outranks enrage")
	colossus._slam_visual_remaining = 0.0
	colossus._tick_sprite(0.0)
	_pose(colossus, _colossus_textures, "enrage", "enrage visual selects enrage")
	colossus._enrage_visual_remaining = 0.0
	colossus.velocity = Vector2(10.0, 0.0)
	colossus._tick_sprite(0.0)
	_pose(colossus, _colossus_textures, "move", "colossus falls back to move after enrage visual")
	colossus.is_dead = true
	_check(colossus._animation_for_state() == "death", "colossus death outranks everything")
	_clear_units()

func _test_frame_advance() -> void:
	## sprite.frame 随计时推进：idle/move 8fps 循环，动作条带按 0.6s 表现时钟匀速走帧
	var pair := _anim_pair()
	var prince = pair[0]
	_check(prince.sprite.frame == 0, "prince idle starts at frame 0")
	prince._tick_sprite(0.13)
	_check(prince.sprite.frame == 1, "prince idle loop advances with time")
	prince._cast_visual_remaining = prince.CAST_VISUAL
	prince._tick_sprite(0.0)
	_check(prince.sprite.frame == 0, "prince cast strip starts at frame 0")
	prince._tick_sprite(0.1)
	_check(prince.sprite.frame == 1, "prince cast strip advances on its own clock")
	prince._tick_sprite(0.2)
	_check(prince.sprite.frame == 3, "prince cast reaches mid frames on schedule")
	prince._cast_visual_remaining = 0.0
	prince._solo_shift_visual_remaining = prince.SOLO_SHIFT_VISUAL
	prince._tick_sprite(0.0)
	_check(prince.sprite.frame == 0, "prince solo_shift strip starts at frame 0")
	prince._tick_sprite(0.31)
	_check(prince.sprite.frame == 3, "prince solo_shift advances on SOLO_SHIFT_VISUAL clock")
	var colossus = pair[1]
	_check(colossus.sprite.frame == 0, "colossus idle starts at frame 0")
	colossus._tick_sprite(0.13)
	_check(colossus.sprite.frame == 1, "colossus idle loop advances with time")
	colossus._slam_visual_remaining = colossus.SLAM_VISUAL
	colossus._tick_sprite(0.0)
	_check(colossus.sprite.frame == 0, "colossus slam strip starts at frame 0")
	colossus._tick_sprite(0.31)
	_check(colossus.sprite.frame == 3, "colossus slam advances on SLAM_VISUAL clock")
	colossus._slam_visual_remaining = 0.0
	colossus._enrage_visual_remaining = colossus.ENRAGE_VISUAL
	colossus._tick_sprite(0.0)
	_check(colossus.sprite.frame == 0, "colossus enrage strip starts at frame 0")
	colossus._tick_sprite(0.31)
	_check(colossus.sprite.frame == 3, "colossus enrage advances on ENRAGE_VISUAL clock")
	_clear_units()

func _test_visual_timers() -> void:
	## cast/solo_shift/slam/enrage 表现时钟：行为同帧置位起播、tick 递减、到期回落
	var pair := _anim_pair()
	var prince = pair[0]
	prince._toss(_target.global_position)
	_check(prince._cast_visual_remaining == prince.CAST_VISUAL, "toss starts cast visual same frame")
	_pose(prince, _prince_textures, "cast", "toss selects cast strip immediately")
	prince._tick_sprite(0.4)
	_check(prince._cast_visual_remaining > 0.0, "cast visual outlives mid strip")
	prince._tick_sprite(0.3)
	_check(prince._cast_visual_remaining == 0.0, "cast visual expires on schedule")
	_pose(prince, _prince_textures, "idle", "prince falls back to idle after cast visual")
	prince.colossus_fell()
	_check(prince._solo_shift_visual_remaining == prince.SOLO_SHIFT_VISUAL, "colossus fell starts solo_shift visual same frame")
	_pose(prince, _prince_textures, "solo_shift", "colossus fell selects solo_shift strip immediately")
	prince._tick_sprite(0.65)
	_check(prince._solo_shift_visual_remaining == 0.0, "solo_shift visual expires on schedule")
	_clear_units()
	# slam/enrage 走真实物理路径：enrage 同帧起播，砸地判定帧同帧置位 slam
	var pair2 := _new_pair()
	var prince2: Node = pair2[0]
	var colossus = pair2[1]
	prince2._timer = 9999.0  # 压住掷瓶：只记砸地的 hp 账
	colossus.enrage()
	_check(colossus._enrage_visual_remaining == colossus.ENRAGE_VISUAL, "enrage starts enrage visual same frame")
	_check(colossus._animation_state == "enrage", "enrage selects enrage strip immediately")
	_target.global_position = colossus.global_position + Vector2(50, 0)
	colossus._timer = 0.05
	await create_timer(0.15).timeout
	_check(colossus._slam_visual_remaining > 0.0, "slam starts slam visual same frame as hit window")
	_check(colossus._animation_state == "slam", "slam selects slam strip immediately")
	_check(_target.hp == 984.0, "slam dealt 16 through the real physics path")
	_clear_units()

func _test_death_animation() -> void:
	## death 条带 0 起播、tween 推帧可见、~0.6s 收口。
	## 顺序1（巨像先倒）：巨像条带完整播放后自回收；亲王随后倒下走同款条带再自回收。
	var pair := _new_pair()
	var prince: Node = pair[0]
	var colossus: Node = pair[1]
	colossus.take_damage(1000000.0)
	_pose(colossus, _colossus_textures, "death", "colossus death selects dedicated strip")
	_check(colossus.sprite.frame == 0, "colossus death begins at first frame")
	await create_timer(0.24).timeout
	_check(is_instance_valid(colossus) and colossus.sprite.frame >= 2, "colossus death advances visibly over strip")
	await create_timer(0.45).timeout
	_check(not is_instance_valid(colossus), "colossus frees itself at ~0.6s")
	prince.take_damage(1000000.0)
	_pose(prince, _prince_textures, "death", "prince death selects dedicated strip")
	_check(prince.sprite.frame == 0, "prince death begins at first frame")
	await create_timer(0.24).timeout
	_check(is_instance_valid(prince) and prince.sprite.frame >= 2, "prince death advances visibly over strip")
	await create_timer(0.45).timeout
	_check(not is_instance_valid(prince), "prince frees itself at ~0.6s in colossus-first order")
	_clear_units()
	## 顺序2（亲王先倒）：亲王留尸条带播完转 invisible；巨像后倒的条带由亲王
	## _exit_tree 经 linked_nodes 连带清理截断（Task 2 已定契约，不断言巨像条带进度）。
	var pair2 := _new_pair()
	var prince2: Node = pair2[0]
	var colossus2: Node = pair2[1]
	prince2.take_damage(1000000.0)
	_pose(prince2, _prince_textures, "death", "prince-first death selects dedicated strip")
	await create_timer(0.24).timeout
	_check(is_instance_valid(prince2) and prince2.sprite.frame >= 2, "prince-first death advances visibly over strip")
	await create_timer(0.45).timeout
	_check(is_instance_valid(prince2) and prince2.visible == false, "prince corpse turns invisible after strip")
	colossus2.take_damage(1000000.0)
	await create_timer(0.3).timeout
	_check(not is_instance_valid(colossus2), "colossus cleaned via prince linked_nodes (standing contract)")
	_check(not is_instance_valid(prince2), "prince recycles once colossus falls")
	_clear_units()

func _test_pause_freezes_animation() -> void:
	## 树暂停冻结表现时钟；恢复后继续走帧（沿用基类 tick 链，不新造计时源）
	var pair := _anim_pair()
	var prince = pair[0]
	prince.set_process(true)
	prince._tick_sprite(0.13)
	var frame: int = prince.sprite.frame
	var elapsed: float = prince._animation_elapsed
	paused = true
	await create_timer(0.18, true).timeout
	_check(prince.sprite.frame == frame and prince._animation_elapsed == elapsed, "tree pause freezes prince animation clock")
	paused = false
	await create_timer(0.1).timeout
	_check(prince._animation_elapsed > elapsed, "prince animation clock resumes after unpause")
	var colossus = pair[1]
	colossus.set_process(true)
	colossus._tick_sprite(0.13)
	var cframe: int = colossus.sprite.frame
	var celapsed: float = colossus._animation_elapsed
	paused = true
	await create_timer(0.18, true).timeout
	_check(colossus.sprite.frame == cframe and colossus._animation_elapsed == celapsed, "tree pause freezes colossus animation clock")
	paused = false
	await create_timer(0.1).timeout
	_check(colossus._animation_elapsed > celapsed, "colossus animation clock resumes after unpause")
	_clear_units()

func _test_real_assets_bootstrap() -> void:
	## --real-assets：10 张真实 PNG 全部进缓存，双单位启动即非占位
	if not _real:
		return
	var pair := _new_pair()
	var prince: Node = pair[0]
	var colossus: Node = pair[1]
	_check(prince.using_placeholder == false, "real assets boot prince without placeholder")
	_check(prince._animation_textures.size() == 5, "all five prince strips cached at boot")
	_check(colossus.using_placeholder == false, "real assets boot colossus without placeholder")
	_check(colossus._animation_textures.size() == 5, "all five colossus strips cached at boot")
	_clear_units()

func _finish() -> void:
	print("ALCHEMIST_PRINCE_ANIMATION RESULT passed=%d failed=%d" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
