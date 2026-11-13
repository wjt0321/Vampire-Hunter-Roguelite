# 墓穴守望者 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为墓穴守望者交付完整垂直切片：6 张专属动作表接线、`_die` 自救修复、真实房间预览、回归与台账闭环。

**Architecture:** 守望者控制器 `scripts/enemies/tomb_warden.gd`（继承 boss_stage.gd）照搬织血母皇的动画状态机模式（动画层只做表现，零行为改动）；`_die()` 自救移植织血母皇 `56fcddb` 的修复；打包脚本复用 `tools/pack_blood_matriarch_sprites.py`；测试/预览/回归/交付完全镜像织血母皇批次（第三层 Boss 房，floor_index=2）。

**Tech Stack:** Godot 4.7.2 GDScript、Python 3.14（Pillow 打包/回归驱动）、MiniMax 图像生成 connector（mcode-tools）。

## Global Constraints

- 单格 128×128；6 张动作表统一 768×128 / 6 帧（idle 不做 4 帧，统一管线，台账同步修正）。
- **动画零行为改动**：扫击冷却 2.8s / 伤害窗 0.55s / 射程 260px / 半角 0.35rad / 伤害 9；复苏 6s / 12 上限；结界 48 HP；移速 58（0.7→1.2 系数）全部保持现状。
- lantern_sweep 动画起点 = 伤害窗起点（`_sweep_left` 置位帧），方向同帧锁定为 `_sweep_dir`；提灯与挥击方向必须同向（生成提示词写死灯笼同侧）。
- revive 不改僵尸生成时点（`_raise_one()` 调用即生成，动画同帧开始）；ward_break 0.6s 纯表现。
- 死亡：`_die()` 自救（remove_from_group("enemies") + 关碰撞，先于 super._die()）+ tween_method 推 0→6 帧 0.6s 后 queue_free；ward 随 linked_nodes 清理。
- 保留 CRLF；不提交 AVI/ZIP/artifacts（.gitignore 已排除 artifacts/tomb_warden/，需补规则行）；每任务本地 commit，推送等用户要求。
- 素材授权口径维持"AI 生成、待核实"。

---

### Task 1: 失败的行为回归（扫击 / 复苏 / 结界门控 / 死亡清理）

**Files:**
- Create: `tools/tomb_warden_animation_test.gd`

**Interfaces:**
- Produces（后续任务实现，本任务只写测试）：`_die()` 自救使守望者 0.8s 内自回收；其余断言针对既有行为（扫击窗/复苏/结界）与既有 `ward` 变量。

- [ ] **Step 1: 写失败测试骨架**

`tools/tomb_warden_animation_test.gd` 头部与织血母皇测试一致（SceneTree、_pass/_fail、内存纹理 768×128 6 帧注入、`_test_interfaces_exist()` 探针防假绿）：

```gdscript
func _test_sweep_window_and_lock() -> void:
	var warden = load("res://scenes/enemies/tomb_warden.tscn").instantiate()
	warden.skip_intro = true
	_host.add_child(warden)
	await process_frame
	_check(warden.ward != null, "ward spawns with warden")
	warden._sweep_dir = Vector2.RIGHT
	warden._sweep_left = 0.55
	var player = _host.get_node_or_null("Player")
	# 玩家在锁定方向 200px 处：命中
	_check(warden._sweep_hits() == true, "sweep hits player inside locked sector")
	# 玩家在反方向：不命中（方向已锁定）
	warden._sweep_dir = Vector2.LEFT
	_check(warden._sweep_hits() == false, "sweep misses player behind locked direction")

func _test_revive_gated_by_ward() -> void:
	var warden = load("res://scenes/enemies/tomb_warden.tscn").instantiate()
	warden.skip_intro = true
	_host.add_child(warden)
	await process_frame
	_check(warden.can_revive() == true, "can revive while ward alive")
	warden.ward.take_damage(99.0)
	await process_frame
	_check(warden.can_revive() == false, "cannot revive after ward broken")
	_check(warden.ward == null, "ward reference cleared on break")

func _test_death_frees_ward() -> void:
	var warden = load("res://scenes/enemies/tomb_warden.tscn").instantiate()
	warden.skip_intro = true
	_host.add_child(warden)
	await process_frame
	var ward: Node = warden.ward
	_check(ward != null, "ward exists before death")
	warden.take_damage(100000.0)
	await create_timer(0.8).timeout
	_check(not is_instance_valid(warden), "warden frees after death strip")
	_check(not is_instance_valid(ward), "ward freed with warden via linked_nodes")
```

- [ ] **Step 2: 跑测试确认失败**
Run: `./.tools/godot/Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tools/tomb_warden_animation_test.gd`
Expected: `_test_death_frees_ward` FAIL（守望者不自回收）；其余行为断言 PASS（针对既有行为）。

- [ ] **Step 3: Commit**
```bash
git add tools/tomb_warden_animation_test.gd
git commit -m "test: 墓穴守望者扫击复苏与死亡清理的回归"
```

---

### Task 2: `_die` 自救与死亡自回收

**Files:**
- Modify: `scripts/enemies/tomb_warden.gd`

- [ ] **Step 1: 移植自救**
读 `scripts/enemies/blood_matriarch.gd:152-162`（或 blood_lord.gd 对应段）的 `_die()` 覆写，逐字同构移植到 tomb_warden.gd：

```gdscript
func _die() -> void:
	if is_dead:
		return
	remove_from_group("enemies")
	_set_boss_collisions(false)
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	super._die()
```

（以 blood_matriarch.gd 实际代码为准逐字照搬，含注释。）同时确认 boss_stage 的 `_die` 链与 tween 死亡表现如何让守望者最终 queue_free——若 boss_stage 基类只发信号不自毁，则本任务还需给守望者补 0.6s tween 自回收（照 blood_matriarch.gd 的 `_play_death_visual` 与 `_advance_death_frame` 完整移植，帧数 6）。

- [ ] **Step 2: 跑 Task 1 测试转绿**
Run: `./.tools/godot/Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tools/tomb_warden_animation_test.gd`
Expected: passed>0 failed=0

- [ ] **Step 3: Commit**
```bash
git add scripts/enemies/tomb_warden.gd
git commit -m "fix: 墓穴守望者死亡演出从 main 清场中自救"
```

---

### Task 3: 六张动作表生成与打包

**Files:**
- Create: `tools/pack_tomb_warden_sprites.py`、`assets/sprites/boss/tomb_warden/`（6 PNG + .import + production.json）、`artifacts/tomb_warden/`
- Modify: `scripts/core/asset_slots.gd`、`.gitignore`

- [ ] **Step 1: 生成原图（加载 mcode-tools-master 技能后用图像 connector）**
一张 6 列 × 6 行图集（单格正方形、纯 #00FF00 绿底、无网格无文字），行序 idle / move / lantern_sweep / revive / ward_break / death。
角色：披腐朽罩袍的墓穴守望者，**灯笼只出现在角色同一侧**（全 36 格同侧，写死进提示词），灰蓝调色板，tomb 主题；风格锚 `assets/sprites/boss/blood_lord/idle.png`。
原图存 `artifacts/tomb_warden/tomb_warden_action_atlas.png`，node_id 记入 production.json。Pillow 逐格校验非绿占比与绿底纯度，不合格 regenerate。

- [ ] **Step 2: 打包**
`tools/pack_tomb_warden_sprites.py` 复用 `tools/pack_blood_matriarch_sprites.py`（色键/切格/去碎片/最近邻/脚底锚点），改输入输出与行映射，产出 6 张 768×128 RGBA。
运行 + 校验尺寸/帧非空/alpha。`.gitignore` 补 `/artifacts/tomb_warden/`。
`.import` sidecar：跑 `./.tools/godot/Godot_v4.7.2-stable_win64_console.exe --headless --path . --import` 生成（与母皇批次同机制）。

- [ ] **Step 3: asset_slots 更新**
```gdscript
	"tomb_warden": {"states": ["idle", "move", "lantern_sweep", "revive", "ward_break", "death"], "blurb": "结界在就能复苏，打掉结界就停"},
```

- [ ] **Step 4: Commit**
```bash
git add assets/sprites/boss/tomb_warden scripts/core/asset_slots.gd tools/pack_tomb_warden_sprites.py .gitignore
git commit -m "feat: 墓穴守望者六张专属动作表"
```

---

### Task 4: 动画状态机接线（真实素材）

**Files:**
- Modify: `scripts/enemies/tomb_warden.gd`（动画层）、`tools/tomb_warden_animation_test.gd`（帧断言与 --real-assets）

- [ ] **Step 1: 动画层**
照搬 blood_matriarch.gd 的动画机制（`_animation_textures`/`_load_sprite_texture`/`_show_animation`/`_tick_sprite`/`_set_animation_frame`）。状态映射（`_animation_for_state()`）：

```gdscript
# 优先级：death > intro(idle) > lantern_sweep > revive > ward_break > move > idle
func _animation_for_state() -> String:
	if is_dead:
		return "death"
	if intro_invulnerable:
		return "idle"
	if _sweep_left > 0.0:
		return "lantern_sweep"
	if _revive_visual_remaining > 0.0:
		return "revive"
	if _ward_break_visual_remaining > 0.0:
		return "ward_break"
	if velocity.length_squared() > 1.0:
		return "move"
	return "idle"
```

接线点（只加表现，不改判定）：`_sweep_left` 置位帧 `_show_animation("lantern_sweep")` 开始且 sprite 朝向 `_sweep_dir`；`_raise_one()` 里 `_revive_visual_remaining = 0.6`；`ward_broken()` 里 `_ward_break_visual_remaining = 0.6`；两者在 `_physics_process` 或 `_tick_sprite` 中递减。暂停冻结沿用基类。

- [ ] **Step 2: 测试补帧断言**
6 状态映射、帧推进、暂停冻结、`-- --real-assets` 校验 6 张 PNG 768×128 且 using_placeholder==false。不削弱 Task 1 断言。

- [ ] **Step 3: 跑测试**
Run: `./.tools/godot/Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tools/tomb_warden_animation_test.gd -- --real-assets`（外加无参数模式）
Expected: 双模式 failed=0；并复跑 `tools/gameplay_slice_test.gd` 与 `tools/floor_expansion_test.gd` 防回归。

- [ ] **Step 4: Commit**
```bash
git add scripts/enemies/tomb_warden.gd tools/tomb_warden_animation_test.gd
git commit -m "feat: 墓穴守望者动画状态机"
```

---

### Task 5: 真实房间预览录像

**Files:**
- Create: `tools/tomb_warden_preview.gd`、`artifacts/tomb_warden/`（AVI、scene_*.png、preview_capture.json）

- [ ] **Step 1: 写预览脚本**
照搬 `tools/blood_matriarch_preview.gd`：真实 Main 第三层 Boss 房（floor_index=2，核对母皇预览的建房参数）；顺序 idle→move→sweep（玩家脚本走位吃一发扫击）→revive（等僵尸出现）→ward_break（脚本 `ward.take_damage(99)` 打爆结界）→death；每状态首帧截图；结束清 BGM/SFX；preview_capture.json 断言 sweep_shown/revive_shown/ward_break_shown/death_shown，failures=0。
死亡阶段不需要外部摘组 workaround（Task 2 已让游戏侧自愈）。

- [ ] **Step 2: 录制**
Run: `./.tools/godot/Godot_v4.7.2-stable_win64_console.exe --verbose --path . --rendering-method gl_compatibility --audio-driver Dummy --disable-vsync --fixed-fps 30 --write-movie artifacts/tomb_warden/tomb_warden_preview.avi --script res://tools/tomb_warden_preview.gd`
Expected: 退出码 0，日志无 ERROR/WARNING/leaked，capture json failures=0。长录制用 run_in_background。

- [ ] **Step 3: Commit（脚本）**
```bash
git add tools/tomb_warden_preview.gd
git commit -m "feat: 墓穴守望者真实房间预览脚本"
```

---

### Task 6: 全量回归、台账与交付包

**Files:**
- Create: `artifacts/tomb_warden/run_checks.py`、`validation_results.json`、`tomb_warden_delivery.zip`
- Modify: `docs/animation-asset-inventory.md`、`docs/asset-licenses.md`

- [ ] **Step 1: 回归驱动**
复制 `artifacts/blood_matriarch/run_checks.py`，cases 头部加 `'tomb_warden_animation_test'`，输出目录改 `artifacts/tomb_warden`，tomb_warden/blood_lord/blood_matriarch 三组带 `-- --real-assets`。跑全量。

- [ ] **Step 2: 五层烟测**
Run: `./.tools/godot/Godot_v4.7.2-stable_win64_console.exe --headless --verbose --path . --script res://tools/run_dungeon_smoke.gd --log-file artifacts/tomb_warden/dungeon_smoke_five_floors.log`
Expected: RESULT fail=0。

- [ ] **Step 3: 台账与授权**
inventory：tomb_warden 行 P0 改"已完成（2026-11-14）"，PNG 234→240、表 58→64，追加第十四节验收记录；licenses 按格式登记 6 张表（node_id、后处理、AI 生成待核实）。CRLF 保留。

- [ ] **Step 4: ZIP 并校验**
`artifacts/tomb_warden/tomb_warden_delivery.zip`：本轮代码/场景改动 + 6 张表 + production.json + 原图 + 回归结果与日志 + scene_*.png + AVI；testzip + 条目断言，排除诊断产物。

- [ ] **Step 5: Commit**
```bash
git add docs/animation-asset-inventory.md docs/asset-licenses.md artifacts/tomb_warden/run_checks.py
git commit -m "docs: 墓穴守望者切片验收记录与回归驱动"
```

---

## Self-Review 记录

- Spec 覆盖：机制零改动 + `_die` 修复（Task 1/2）、素材（Task 3）、动画（Task 4）、预览（Task 5）、闭环（Task 6）。
- 与台账的两处主动偏差（沿用母皇先例）：① idle 由 4 帧统一为 6 帧；② 不加扫击前摇，用「动画起点=伤害窗起点」满足提灯同向约束。
- 测试文件单一（tomb_warden_animation_test.gd），行为断言在 Task 1 针对既有机制即应 PASS，仅死亡自回收为 RED→GREEN。
