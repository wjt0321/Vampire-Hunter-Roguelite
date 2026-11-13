# 炼金亲王 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为炼金亲王双单位 Boss 交付完整垂直切片：10 张专属动作表接线、双单位 `_die` 自救修复、真实房间预览、回归与台账闭环。

**Architecture:** 亲王（boss_stage.gd 子类）与巨像（enemy_base.gd 子类）各接一套动画状态机，机制照搬织血母皇/墓穴守望者已验证的模式；`_die()` 自救移植同模式并按双单位死亡时序契约适配；打包/测试/预览/回归/交付完全镜像前三批（第四层 Boss 房，floor_index=3）。

**Tech Stack:** Godot 4.7.2 GDScript、Python 3.14（Pillow 打包/回归驱动）、MiniMax 图像生成 connector（mcode-tools）。

## Global Constraints

- 单格 128×128；每张表统一 768×128 / 6 帧。
- **动画零行为改动**：掷瓶冷却 2.2s(pair)/1.3s(solo)、puddle 伤害 10、亲王移速 78(140 solo)、接触 12、巨像 220HP/移速 36(70 enraged)/接触 18、砸地 <90px 16 伤害/1.6s、XP 20 全部保持现状。
- 死亡时序契约不改：亲王先倒须留尸（invisible）至巨像倒下；双倒时 `_finish_fight()` 发 `boss_defeated` 的时点不动。
- 死亡演出统一：`_die()` 起点 remove_from_group("enemies") + 关碰撞，death 条带 tween 0→6 帧 0.6s，<0.8s 自回收；巨像 linked_nodes 由亲王 `_exit_tree` 连带清理的现状不变。
- cast/solo_shift/slam/enrage 均为表现层时钟 0.6s，与对应行为同帧置位、同帧起播，不改判定/生成时点。
- 保留 CRLF；不提交 artifacts/（补 `/artifacts/alchemist_prince/` 规则行）；每任务本地 commit；批次完成后阶段性推送（本批用户已授权推送节奏）。
- 素材授权口径维持"AI 生成、待核实"。

---

### Task 1: 失败的行为回归（双单位机制 + 死亡自回收）

**Files:**
- Create: `tools/alchemist_prince_animation_test.gd`

- [ ] **Step 1: 写失败测试骨架**（SceneTree，仿守望者测试：_pass/_fail、内存纹理注入、`_test_interfaces_exist()` 探针防假绿）。覆盖：pair 掷瓶冷却 2.2s→命中 puddle；巨像砸地 16 伤害与 1.6s 冷却；enrage 后移速 70；colossus_fell 后亲王 solo（移速 140、冷却 1.3s）；巨像先倒 0.8s 内自回收且亲王可 solo_shift；亲王先倒留尸不 queue_free、巨像 enrage；双倒 boss_defeated 发出且双单位 0.8s 内自回收（当前实现：巨像立即 queue_free 零演出——自回收断言应针对"death 条带播放后"，`using_placeholder` 下有 0.4s 淡出兜底，断言 is_dead 后 <0.8s not is_instance_valid）。
- [ ] **Step 2: 跑测试确认失败形态**——死亡演出相关断言 FAIL（当前零演出/立即回收），既有行为断言 PASS。
- [ ] **Step 3: Commit** `test: 炼金亲王双单位行为与死亡清理回归`。

---

### Task 2: 双单位 `_die` 自救与死亡自回收

**Files:**
- Modify: `scripts/enemies/alchemist_prince.gd`、`scripts/enemies/alchemist_colossus.gd`

- [ ] **Step 1: 巨像 `_die()` 改造**——起点 `remove_from_group("enemies")` + 关碰撞 + `_show_animation("death")` 起播，tween_method 0→6 帧 0.6s 后 queue_free；sprite==null/using_placeholder 时 0.4s modulate 淡出兜底后 queue_free；`colossus_fell()` 通知时点不动（仍在 _die 开头）。
- [ ] **Step 2: 亲王 `_die()` 改造**——起点自救退组 + 关碰撞；death 条带 0.6s 播完后 invisible（替代立即 invisible）；巨像存活时契约不变（不 queue_free、照常 enrage）；巨像已死时 _finish_fight 后条带播完自行 queue_free（替代 main 清场回收）。
- [ ] **Step 3: 跑 Task 1 测试转绿 + 复跑 gameplay_slice/floor_expansion 防回归。**
- [ ] **Step 4: Commit** `fix: 炼金亲王双单位死亡演出自救`。

---

### Task 3: 十张动作表生成与打包

**Files:**
- Create: `tools/pack_alchemist_sprites.py`、`assets/sprites/boss/alchemist_prince/`（5 PNG + .import + production.json）、`assets/sprites/boss/alchemist_colossus/`（5 PNG + .import + production.json）、`artifacts/alchemist_prince/`
- Modify: `scripts/core/asset_slots.gd`、`.gitignore`

- [ ] **Step 1: 生成两张原图**（mcode-tools-master 技能 + 图像 connector，参考图垫绿底 ≤4:1）：prince 6×5（idle/move/cast/solo_shift/death，绿金炼金术师），colossus 6×5（idle/move/slam/enrage/death，青铜熔炉魔像）；风格锚 blood_lord idle.png；两角色不得串味；Pillow 逐格校验非绿占比与绿底纯度，不合格 regenerate；node_id 记入 production.json。
- [ ] **Step 2: 打包**——pack 脚本复用母皇管线（色键/切格/去碎片/最近邻/脚底锚点 y=119），行映射 5 行，两个输出目录；校验 10 张 768×128 RGBA；Godot --import 生成 sidecar；.gitignore 补 `/artifacts/alchemist_prince/`。
- [ ] **Step 3: asset_slots 更新**——alchemist_prince → [idle, move, cast, solo_shift, death]；alchemist_colossus → [idle, move, slam, enrage, death]；blurb 不动。
- [ ] **Step 4: Commit** `feat: 炼金亲王双单位十张专属动作表`。

---

### Task 4: 双单位动画状态机接线

**Files:**
- Modify: `scripts/enemies/alchemist_prince.gd`、`scripts/enemies/alchemist_colossus.gd`、`tools/alchemist_prince_animation_test.gd`

- [ ] **Step 1: 亲王动画层**——照搬守望者 `_animation_textures`/`_show_animation`/`_tick_sprite`/`_set_animation_frame` 机制；`_animation_for_state()` 优先级 death > intro(idle) > cast > solo_shift > move > idle；`_toss()` 同帧 `_cast_visual_remaining=0.6`；`colossus_fell()` 同帧 `_solo_shift_visual_remaining=0.6`；sprite 朝向 velocity（boss_stage 既有模式）。
- [ ] **Step 2: 巨像动画层**——enemy_base 已有 `_tick_sprite`/`use_placeholder_sprite`/`_present_sprite`；补 `_show_animation`/`_set_animation_frame`/`_animation_textures` 同款（参照亲王实现）；优先级 death > slam > enrage > move > idle；砸地判定帧同帧 `_slam_visual_remaining=0.6`；`enrage()` 同帧 `_enrage_visual_remaining=0.6`；占位回退 furnace_golem idle + tint。
- [ ] **Step 3: 测试补帧断言 + --real-assets**——10 状态映射、帧推进、暂停冻结、10 张 PNG 768×128 且 using_placeholder==false；不削弱 Task 1 断言。
- [ ] **Step 4: 双模式测试 + 防回归**（gameplay_slice、floor_expansion）。
- [ ] **Step 5: Commit** `feat: 炼金亲王双单位动画状态机`。

---

### Task 5: 真实房间预览录像

**Files:**
- Create: `tools/alchemist_prince_preview.gd`、`artifacts/alchemist_prince/`（AVI、scene_*.png、preview_capture.json）

- [ ] **Step 1: 写预览脚本**——照搬守望者预览；真实 Main 第四层 Boss 房（floor_index=3）；顺序 pair idle→move→cast（玩家吃一瓶）→slam（巨像砸地）→打爆巨像（亲王 solo_shift）→打爆亲王（death 条带播完才倒下）→收尾；每状态首帧截图；capture json 断言 cast_shown/slam_shown/solo_shift_shown/prince_death_shown/colossus_death_shown，failures=0；结束清 BGM/SFX；无摘组 workaround。
- [ ] **Step 2: 录制**（--write-movie artifacts/alchemist_prince/alchemist_prince_preview.avi，run_in_background）。
- [ ] **Step 3: Commit** `feat: 炼金亲王真实房间预览脚本`。

---

### Task 6: 全量回归、台账与交付包

**Files:**
- Create: `artifacts/alchemist_prince/run_checks.py`、`validation_results.json`、`alchemist_prince_delivery.zip`
- Modify: `docs/animation-asset-inventory.md`、`docs/asset-licenses.md`

- [ ] **Step 1: 回归驱动**——cases = 前三批全部 + alchemist_prince_animation_test（real-assets 组加本批）。
- [ ] **Step 2: 五层烟测**（run_dungeon_smoke，RESULT fail=0）。
- [ ] **Step 3: 台账与授权**——inventory 两行改已完成，PNG 240→250、表 64→74，第十五节验收记录；licenses 登记 10 张表。
- [ ] **Step 4: ZIP 并校验**（testzip + 条目断言）。
- [ ] **Step 5: Commit** `docs: 炼金亲王切片验收记录与回归驱动`。

---

## Self-Review 记录

- Spec 覆盖：双单位死亡修复（Task 1/2）、素材（Task 3）、动画（Task 4）、预览（Task 5）、闭环（Task 6）。
- 与前三批的主动差异：双单位 → 两张图集 10 表、两条 `_die` 修复、预览只演示「巨像先倒」顺序（亲王先倒路线的 enrage 由测试覆盖）。
- 测试文件单一（alchemist_prince_animation_test.gd 覆盖双单位），行为断言在 Task 1 针对既有机制即应 PASS，死亡演出为 RED→GREEN。
