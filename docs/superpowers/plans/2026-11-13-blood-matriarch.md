# 织血母皇 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为织血母皇交付完整垂直切片：幼虫召唤玩法、8 张专属动作表接线、真实房间预览、回归与资产台账闭环。

**Architecture:** 母皇控制器 `scripts/enemies/blood_matriarch.gd`（继承 boss_stage.gd）照搬血铠领主的动画状态机模式（_animation_textures / _show_animation / _tick_sprite / _set_animation_frame），动作循环扩为 召唤→产卵→铺网 优先级轮换，卵巢清空后 phase_change 转近战。幼虫是独立敌人 `scripts/enemies/blood_larva.gd`（继承 enemy_base.gd，覆写 `_move_towards_player`），巡逻绕母皇、预警后扑咬；幼虫加入 enemies 组（换房/BOSS 死亡清场）并登记进母皇 `linked_nodes`（母皇销毁时连带 free，沿用 boss_stage._exit_tree 既有机制，**不需要改 main.gd**）。

**Tech Stack:** Godot 4.7.2 GDScript、Python 3.14（Pillow 打包/回归驱动）、MiniMax 图像生成 connector（mcode-tools）。

## Global Constraints

- 单格 128×128；8 张动作表统一 768×128 / 6 帧（idle 也做 6 帧，与血铠领主管线一致，台账同步修正）。
- 动画不改变既有伤害判定：接触伤害仍走 enemy_base 接触区；近战挥击沿用血铠领主 `_strike` 的 96px / 0.7rad / 18 伤害参数。
- 关键接触帧对齐：lay_egg 第 3 帧出卵、summon 第 4 帧出幼虫、web_cast 第 3 帧出网、melee 第 4 帧结算伤害；延迟生成用 `_pending_timer` 在 0.25s 触发，不在动作第 0 帧生成。
- 幼虫上限 3、每次召唤 1 只；暴露后 `summon_larva()` 与 `lay_egg()` 都返回 null。
- 保留 CRLF；不提交 AVI/ZIP（.gitignore 已排除 artifacts/blood_matriarch/）；每任务本地 commit，推送等用户要求。
- 素材授权口径维持“AI 生成、待核实”，不宣称 CC0/Apache-2.0。

---

### Task 1: 失败的行为回归（召唤 / 上限 / 暴露停召 / 清理）

**Files:**
- Create: `tools/blood_matriarch_animation_test.gd`
- Modify: `tools/gameplay_slice_test.gd`（在现有织血母皇段后追加）

**Interfaces:**
- Produces（后续任务实现，本任务只写测试）：`summon_larva() -> Node`（上限/暴露时返回 null）；`_living_larvae() -> int`；`blood_larva.gd` 场景 `res://scenes/enemies/blood_larva.tscn`；幼虫 `queen: Node` 变量。

- [ ] **Step 1: 写失败测试骨架**

`tools/blood_matriarch_animation_test.gd` 头部与血铠领主测试一致（SceneTree 脚本、_pass/_fail 计数、内存纹理 768×128 6 帧注入），先写行为用例：

```gdscript
func _test_summon_and_cap() -> void:
	var queen = load("res://scenes/enemies/blood_matriarch.tscn").instantiate()
	queen.skip_intro = true
	_host.add_child(queen)
	await process_frame
	var spawned := []
	for i in 4:
		var larva = queen.summon_larva()
		if larva != null:
			spawned.append(larva)
	_check(spawned.size() == 3, "summon stops at larva cap 3")
	_check(queen._living_larvae() == 3, "living larvae count is 3")
	_check(queen.summon_larva() == null, "summon beyond cap returns null")

func _test_expose_stops_summon() -> void:
	var queen = load("res://scenes/enemies/blood_matriarch.tscn").instantiate()
	queen.skip_intro = true
	_host.add_child(queen)
	await process_frame
	var egg: Node = queen.lay_egg()
	_check(egg != null, "egg lays before expose")
	egg.take_damage(99.0)
	_check(queen.exposed, "egg destroyed exposes queen")
	_check(queen.summon_larva() == null, "no summon after expose")
	_check(queen.lay_egg() == null, "no egg after expose")

func _test_death_frees_larvae() -> void:
	var queen = load("res://scenes/enemies/blood_matriarch.tscn").instantiate()
	queen.skip_intro = true
	_host.add_child(queen)
	await process_frame
	var larva: Node = queen.summon_larva()
	_check(larva != null, "larva spawns before death")
	queen.take_damage(100000.0)
	await create_timer(0.8).timeout
	_check(not is_instance_valid(queen), "queen frees after death strip")
	_check(not is_instance_valid(larva), "larva freed with queen via linked_nodes")
```

`tools/gameplay_slice_test.gd` 在现有 `queen.lay_egg()` 段后追加：

```gdscript
	var orphans_before_larva: Array = Node.get_orphan_node_ids()
	var larva: Node = queen.summon_larva()
	_check(Node.get_orphan_node_ids() == orphans_before_larva, "召唤幼虫不会遗留未挂树的孤立节点")
	_check(larva != null and queen._living_larvae() == 1, "幼虫计入母皇附属物")
	larva.free()
```

- [ ] **Step 2: 跑测试确认失败**

Run: `./.tools/godot/Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tools/blood_matriarch_animation_test.gd`
Expected: FAIL（`summon_larva` 方法不存在 / 场景不存在）

- [ ] **Step 3: Commit**

```bash
git add tools/blood_matriarch_animation_test.gd tools/gameplay_slice_test.gd
git commit -m "test: 织血母皇召唤与清理的失败回归"
```

---

### Task 2: 幼虫控制器与场景

**Files:**
- Create: `scripts/enemies/blood_larva.gd`
- Create: `scenes/enemies/blood_larva.tscn`
- Modify: `scripts/core/asset_slots.gd`（ENEMIES 增加 blood_larva 条目）

**Interfaces:**
- Consumes: enemy_base 的 `_move_towards_player(delta)` 钩子（bat.gd 同款覆写方式）、`use_placeholder_sprite(source_type, state, tint)`。
- Produces: `res://scenes/enemies/blood_larva.tscn`；幼虫变量 `queen: Node`；三态 Motion { ORBIT, WINDUP, POUNCE }。

- [ ] **Step 1: 写幼虫脚本**

```gdscript
extends "res://scripts/enemies/enemy_base.gd"
## 织血母皇的幼虫。绕母皇巡逻，玩家靠近就预警后扑咬，不替母皇挡远程弹道。

enum Motion { ORBIT, WINDUP, POUNCE }

const ORBIT_RADIUS := 90.0
const ALERT_RADIUS := 160.0
const WINDUP_TIME := 0.35
const POUNCE_SPEED := 260.0
const POUNCE_TIME := 0.3

var queen: Node = null
var motion: Motion = Motion.ORBIT
var _motion_timer: float = 0.0
var _pounce_dir: Vector2 = Vector2.RIGHT
var _orbit_angle: float = 0.0

func _ready() -> void:
	base_hp = 30.0
	base_contact_damage = 8.0
	move_speed = 90.0
	xp_value = 5
	silver_value = 1
	_orbit_angle = randf() * TAU
	super._ready()

func _get_enemy_type() -> String:
	return "blood_larva"

func _load_sprite_texture() -> void:
	# 专属幼虫表还没做；借蝙蝠飞帧染绛红，登记在 asset_slots 后可 drop-in 替换。
	use_placeholder_sprite("bat", "fly", Color(0.78, 0.22, 0.42))
	_adjust_sprite_scale()

func _move_towards_player(delta: float) -> void:
	if queen == null or not is_instance_valid(queen):
		return
	var to_player := player.global_position - global_position if player != null and is_instance_valid(player) else Vector2.ZERO
	match motion:
		Motion.ORBIT:
			_orbit_angle += delta * move_speed / ORBIT_RADIUS
			var target: Vector2 = queen.global_position + Vector2(cos(_orbit_angle), sin(_orbit_angle)) * ORBIT_RADIUS
			var to_target := target - global_position
			velocity = to_target.normalized() * move_speed if to_target.length() > 8.0 else Vector2.ZERO
			if to_player.length() <= ALERT_RADIUS:
				motion = Motion.WINDUP
				_motion_timer = WINDUP_TIME
				velocity = Vector2.ZERO
		Motion.WINDUP:
			velocity = Vector2.ZERO
			_motion_timer -= delta
			if _motion_timer <= 0.0:
				motion = Motion.POUNCE
				_motion_timer = POUNCE_TIME
				_pounce_dir = to_player.normalized() if to_player.length_squared() > 1.0 else Vector2.RIGHT
		Motion.POUNCE:
			velocity = _pounce_dir * POUNCE_SPEED
			_motion_timer -= delta
			if _motion_timer <= 0.0:
				motion = Motion.ORBIT
	move_and_slide()
	if velocity.length_squared() > 1.0 and sprite != null:
		sprite.flip_h = velocity.x < 0.0
```

- [ ] **Step 2: 写场景**

`scenes/enemies/blood_larva.tscn` 仿 blood_matriarch.tscn，碰撞体改小（RectangleShape2D size = Vector2(18, 18)），ContactArea 保留：

```
[gd_scene load_steps=3 format=3 uid="uid://boss_blood_larva"]

[ext_resource type="Script" path="res://scripts/enemies/blood_larva.gd" id="1_script"]

[sub_resource type="RectangleShape2D" id="RectangleShape2D_larva"]
size = Vector2(18, 18)

[node name="BloodLarva" type="CharacterBody2D"]
collision_layer = 2
collision_mask = 17
script = ExtResource("1_script")

[node name="Sprite2D" type="Sprite2D" parent="."]

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("RectangleShape2D_larva")

[node name="ContactArea" type="Area2D" parent="."]
collision_layer = 2
collision_mask = 1

[node name="ContactShape" type="CollisionShape2D" parent="ContactArea"]
shape = SubResource("RectangleShape2D_larva")

[connection signal="body_entered" from="ContactArea" to="." method="_on_contact_area_body_entered"]
```

- [ ] **Step 3: asset_slots 登记**

`scripts/core/asset_slots.gd` ENEMIES 表加一行：

```gdscript
	"blood_larva": {"states": ["idle"], "blurb": "绕母皇巡逻，靠近就扑咬"},
```

- [ ] **Step 4: 跑 Task 1 测试确认通过**

Run: `./.tools/godot/Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tools/blood_matriarch_animation_test.gd`
Expected: summon/cap 相关 FAIL 转为 PASS（母皇 `summon_larva` 在 Task 3 实现，本步允许剩母皇侧失败；先单独验证幼虫场景可实例化、可巡逻、可扑咬——在测试里加 `larva.motion == larva.Motion.ORBIT` 与手动置 WINDUP→POUNCE 的推进断言）。

- [ ] **Step 5: Commit**

```bash
git add scripts/enemies/blood_larva.gd scenes/enemies/blood_larva.tscn scripts/core/asset_slots.gd tools/blood_matriarch_animation_test.gd
git commit -m "feat: 织血母皇幼虫控制器与场景"
```

---

### Task 3: 母皇动作循环与召唤接线

**Files:**
- Modify: `scripts/enemies/blood_matriarch.gd`

**Interfaces:**
- Consumes: Task 2 的幼虫场景；`linked_nodes`（boss_stage._exit_tree 统一 free）。
- Produces: `summon_larva() -> Node`、`_living_larvae() -> int`、`_expose()` 内 phase_change 触发、延迟生成 `_pending_kind/_pending_timer`。

- [ ] **Step 1: 实现召唤与轮换**

在现有 blood_matriarch.gd 上改：

```gdscript
const LARVA_CAP := 3
const LarvaScene = preload("res://scenes/enemies/blood_larva.tscn")

var _larvae: Array = []
var _pending_kind: String = ""
var _pending_timer: float = -1.0
const CONTACT_DELAY := 0.25  # 6 帧动作的接触帧（第 3~4 帧）

func summon_larva() -> Node:
	if exposed or _living_larvae() >= LARVA_CAP:
		return null
	if get_parent() == null:
		return null
	var larva := LarvaScene.instantiate()
	larva.queen = self
	get_parent().add_child(larva)
	larva.global_position = global_position + Vector2(randf_range(-70, 70), randf_range(-40, 50))
	_larvae.append(larva)
	linked_nodes.append(larva)  # 母皇销毁时连带清理
	return larva

func _living_larvae() -> int:
	var count := 0
	for larva in _larvae:
		if is_instance_valid(larva) and larva.get("is_dead") != true:
			count += 1
	return count

func larva_destroyed(larva: Node) -> void:
	_larvae.erase(larva)
	linked_nodes.erase(larva)
```

动作轮换（替换现有 _physics_process 的产卵/铺网分支）：

```gdscript
	if _action_timer > 0.0 or exposed:
		return
	_action_timer = 2.4
	if _living_larvae() < LARVA_CAP:
		_pending_kind = "summon"
	elif _living_eggs() < EGG_CAP and eggs_laid < EGG_CAP + 1:
		_pending_kind = "egg"
	else:
		_pending_kind = "web"
	_pending_timer = CONTACT_DELAY
```

`_physics_process` 开头推进延迟生成：

```gdscript
	if _pending_timer >= 0.0:
		_pending_timer -= delta
		if _pending_timer < 0.0:
			match _pending_kind:
				"summon": summon_larva()
				"egg": lay_egg()
				"web": drop_web()
			_pending_kind = ""
```

暴露近战：`exposed` 且距离 <= 100 时置 `_pending_kind = "melee"`，接触帧结算：

```gdscript
func _melee_strike() -> void:
	_show_animation("melee")
	if not using_placeholder:
		_set_animation_frame(4)
	var forward := (player.global_position - global_position).normalized()
	for enemy in get_tree().get_nodes_in_group("player"):
		if not (enemy is Node2D):
			continue
		var offset: Vector2 = (enemy as Node2D).global_position - global_position
		if offset.length() > 96.0 or absf(forward.angle_to(offset)) > 0.7:
			continue
		if enemy.has_method("take_damage"):
			enemy.take_damage(18.0)
```

- [ ] **Step 2: 跑 Task 1 全部行为测试**

Run: `./.tools/godot/Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tools/blood_matriarch_animation_test.gd`
Expected: passed>0 failed=0（动画帧断言允许占位阶段跳过，留给 Task 5）

- [ ] **Step 3: Commit**

```bash
git add scripts/enemies/blood_matriarch.gd tools/blood_matriarch_animation_test.gd
git commit -m "feat: 织血母皇召唤/产卵/铺网轮换与暴露近战"
```

---

### Task 4: 专属动作表生成与打包

**Files:**
- Create: `tools/pack_blood_matriarch_sprites.py`
- Create: `assets/sprites/boss/blood_matriarch/production.json`、8 张 PNG + .import
- Create: `artifacts/blood_matriarch/`（原图、清单）

**Interfaces:**
- Produces: `assets/sprites/boss/blood_matriarch/{idle,move,lay_egg,summon,web_cast,melee,phase_change,death}.png`，每张 768×128 RGBA 6 帧；`AssetSlots.boss_texture("blood_matriarch", state)` 可取。

- [ ] **Step 1: 生成原图（加载 mcode-tools-master 技能后用图像 connector）**

一张 6 列 × 8 行图集（单格正方形、纯 #00FF00 绿底、无网格无文字），行序：idle / move / lay_egg / summon / web_cast / melee / phase_change / death。角色：绛红甲壳的蜘蛛型母皇、臃肿腹部卵囊、多节肢、像素描边与暗金红项目风格一致；参考图用 `assets/sprites/boss/blood_lord/idle.png` 保持风格锚。原图存 `artifacts/blood_matriarch/blood_matriarch_action_atlas.png`，node_id 记入 production.json。

- [ ] **Step 2: 写打包脚本并出表**

`tools/pack_blood_matriarch_sprites.py` 复用 blood_lord 的色键/切格/去碎片/最近邻缩放/脚底锚点逻辑（读 `tools/pack_blood_lord_sprites.py` 改输入输出路径与行映射），产出 8 张 768×128。运行 `python tools/pack_blood_matriarch_sprites.py`，校验每张尺寸 768×128、6 帧非空、透明通道正常。

- [ ] **Step 3: asset_slots 更新母皇动作清单**

```gdscript
	"blood_matriarch": {"states": ["idle", "move", "lay_egg", "summon", "web_cast", "melee", "phase_change", "death"], "blurb": "产卵铺网召唤幼虫，清掉卵巢后改近身"},
```

- [ ] **Step 4: Commit**

```bash
git add assets/sprites/boss/blood_matriarch scripts/core/asset_slots.gd tools/pack_blood_matriarch_sprites.py
git commit -m "feat: 织血母皇八张专属动作表"
```

---

### Task 5: 动画状态机接线（真实素材）

**Files:**
- Modify: `scripts/enemies/blood_matriarch.gd`（动画层）
- Modify: `tools/blood_matriarch_animation_test.gd`（补帧断言与 --real-assets 模式）

**Interfaces:**
- Consumes: Task 4 的 8 张表；血铠领主 `_animation_textures/_show_animation/_tick_sprite/_set_animation_frame/_play_death_visual` 模式。

- [ ] **Step 1: 实现动画层**

照搬 blood_lord.gd 的动画机制，状态映射：

```gdscript
func _animation_for_state() -> String:
	if is_dead:
		return "death"
	if intro_invulnerable:
		return "idle"
	if _phase_visual_elapsed >= 0.0 and _phase_visual_elapsed < PHASE_VISUAL:
		return "phase_change"
	if _pending_kind != "" or _action_visual_remaining > 0.0:
		match _pending_kind if _pending_kind != "" else _last_action:
			"summon": return "summon"
			"egg": return "lay_egg"
			"web": return "web_cast"
			"melee": return "melee"
	if velocity.length_squared() > 1.0:
		return "move"
	return "idle"
```

`_expose()` 置 `_phase_visual_elapsed = 0.0`（PHASE_VISUAL := 0.6，期间 velocity 为零）；`_play_death_visual` 与血铠领主一致（tween_method 推 0→6 帧，0.6s 后 queue_free）。

- [ ] **Step 2: 测试补帧断言**

8 状态在触发时 `_animation_state` 正确、`sprite.frame` 随计时推进、死亡 0.6s 自回收、暂停冻结；`-- --real-assets` 模式下校验 8 张真实 PNG 尺寸 768×128 且 `using_placeholder == false`。

- [ ] **Step 3: 跑测试**

Run: `./.tools/godot/Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tools/blood_matriarch_animation_test.gd -- --real-assets`
Expected: passed 全绿 failed=0

- [ ] **Step 4: Commit**

```bash
git add scripts/enemies/blood_matriarch.gd tools/blood_matriarch_animation_test.gd
git commit -m "feat: 织血母皇动画状态机与死亡演出"
```

---

### Task 6: 真实房间预览录像

**Files:**
- Create: `tools/blood_matriarch_preview.gd`
- Create: `artifacts/blood_matriarch/`（AVI、scene_*.png、preview_capture.json）

**Interfaces:**
- Consumes: 血铠领主预览脚本模式（Godot `--write-movie`、每状态首帧截图、结束清理 BGM/SFX）。

- [ ] **Step 1: 写预览脚本**

照搬 `tools/blood_lord_preview.gd`：真实 Main 进入第 2 层 Boss 房，按  idle → move → summon（等幼虫出现）→ lay_egg → web_cast → 脚本清卵触发 phase_change → melee → death 顺序演示；player 用脚本走位到墙边演示幼虫扑咬；AVI 1280×720/30fps 写 `artifacts/blood_matriarch/blood_matriarch_preview.avi`；每状态首帧存 `scene_<state>.png`；结束打印 states/failures/wall... 对应断言（幼虫出现、phase_change 出现、death 出现）。

- [ ] **Step 2: 录制并检查日志**

Run: `./.tools/godot/Godot_v4.7.2-stable_win64_console.exe --verbose --path . --rendering-method gl_compatibility --audio-driver Dummy --disable-vsync --fixed-fps 30 --write-movie artifacts/blood_matriarch/blood_matriarch_preview.avi --script res://tools/blood_matriarch_preview.gd`
Expected: 退出码 0，日志无 ERROR/WARNING/泄漏；preview_capture.json `failures=0`、状态齐全。

- [ ] **Step 3: Commit（脚本）**

```bash
git add tools/blood_matriarch_preview.gd
git commit -m "feat: 织血母皇真实房间预览脚本"
```

---

### Task 7: 全量回归、台账与交付包

**Files:**
- Create: `artifacts/blood_matriarch/run_checks.py`、`validation_results.json`
- Modify: `docs/animation-asset-inventory.md`、`docs/asset-licenses.md`
- Create: `artifacts/blood_matriarch/blood_matriarch_delivery.zip`

- [ ] **Step 1: 回归驱动脚本**

复制 blood_lord 的 run_checks.py 到 `artifacts/blood_matriarch/run_checks.py`，cases 改为 `['blood_matriarch_animation_test', 'blood_lord_animation_test', 'floor_expansion_test', 'gameplay_slice_test', 'iteration_pack_test', 'sprite_sheet_test', 'lifecycle_cleanup_test']`，输出目录改 `artifacts/blood_matriarch`，blood_matriarch/blood_lord 两组加 `-- --real-assets`。

- [ ] **Step 2: 跑全量回归 + 五层烟测**

Run: `python artifacts/blood_matriarch/run_checks.py` 与 `./.tools/godot/Godot_v4.7.2-stable_win64_console.exe --headless --verbose --path . --script res://tools/run_dungeon_smoke.gd --log-file artifacts/blood_matriarch/dungeon_smoke_five_floors.log`
Expected: 全部 exit 0、issues 为空；烟测 RESULT fail=0。

- [ ] **Step 3: 更新台账与授权登记**

inventory：织血母皇行状态改“已完成（日期）”，PNG 总数 226→234、sprites 50→58，追加验收记录小节；licenses：按血铠领主条目格式登记 8 张表（来源、node_id、后处理、授权待核实）。

- [ ] **Step 4: 打包并校验**

ZIP 含：本轮代码/场景改动、8 张动作表、原图与修正版、production.json、回归结果与日志、scene_*.png、最终 AVI；`zipfile.testzip()` 通过、条目数与关键路径断言、排除临时帧与诊断录像。

- [ ] **Step 5: Commit**

```bash
git add docs/animation-asset-inventory.md docs/asset-licenses.md artifacts/blood_matriarch/run_checks.py
git commit -m "docs: 织血母皇切片验收记录与回归驱动"
```

---

## Self-Review 记录

- Spec 覆盖：机制（Task 1/3）、幼虫（Task 2）、8 表（Task 4）、动画接线（Task 5）、预览（Task 6）、回归/台账/交付（Task 7）——spec 各节均有对应任务。
- 类型一致：`summon_larva() -> Node`、`_living_larvae() -> int`、`queen: Node` 在 Task 1 测试、Task 2 场景、Task 3 实现间一致；`_pending_kind` 取值 summon/egg/web/melee 全文一致。
- 与 spec 的两处主动偏差（已确认更优）：① idle 由 4 帧改 6 帧统一管线；② 清理走 `linked_nodes` + enemies 组，不改 main.gd（spec 第 4 节写的 main.gd 登记经核实为多余，boss_stage 既有机制已覆盖）。
