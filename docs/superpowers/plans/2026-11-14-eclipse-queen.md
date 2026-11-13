# 月蚀女王 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为月蚀女王交付完整垂直切片：6 张专属动作表接线、`_die` 自救修复、真实房间预览、回归与台账闭环。

**Architecture:** 女王控制器 `scripts/enemies/eclipse_queen.gd`（继承 boss_stage.gd）照搬墓穴守望者的动画状态机模式（动画层只做表现，零行为改动）；`_die()` 自救移植守望者 `748a4b6` 的修复；打包/测试/预览/回归/交付完全镜像前四批（第五层 Boss 房，floor_index=4）。

**Tech Stack:** Godot 4.7.2 GDScript、Python 3.14（Pillow 打包/回归驱动）、MiniMax 图像生成 connector（mcode-tools）。

## Global Constraints

- 单格 128×128；6 张动作表统一 768×128 / 6 帧。
- **动画零行为改动**：闪烁冷却 1.4s、前摇 0.45s、落点后冷却 0.7(月相0)/0.4(≥1)、月相推进（祭坛 40HP 打掉→月相 1；hp<40%→月相 2）、safe_radius 150/90、移速 80、接触 14 全部保持现状。
- blink 动画 = `_blinking` 全程（0.45s），appear 表现时钟 0.35s 瞬移帧同帧置位，phase_change 表现时钟 0.6s（`altar_destroyed()` 与月相 2 判定帧两处接线），均不改判定/瞬移时点。
- 死亡：`_die()` 自救（remove_from_group("enemies") + 关碰撞，先于 super._die()）+ tween_method 0→6 帧 0.6s 后 queue_free；祭坛随 linked_nodes 由 boss_stage `_exit_tree` 连带清理（现状不变）。
- 保留 CRLF；不提交 artifacts/（补 `/artifacts/eclipse_queen/` 规则行）；每任务本地 commit；批次完成后阶段性推送（用户已授权推送节奏）。
- 素材授权口径维持"AI 生成、待核实"。

---

### Task 1: 失败的行为回归（闪烁周期 / 月相门控 / 死亡清理）

**Files:**
- Create: `tools/eclipse_queen_animation_test.gd`

- [ ] **Step 1: 写失败测试骨架**（SceneTree，仿守望者测试：_pass/_fail、内存纹理注入、`_test_interfaces_exist()` 探针）。覆盖：闪烁周期（1.4s 冷却→`_blinking`→0.45s 后 global_position==玩家位置）；落点后冷却随月相（0.7/0.4，直接置 moon_phase 验证 safe_radius() 150/90 与信号）；祭坛 40HP 打掉→altar_destroyed→moon_phase=1+phase(1)；hp<40%→moon_phase=2+phase(2)；祭坛随女王死亡连带清理（linked_nodes，RED 前即应 PASS）；女王死亡自救回收（RED：0.2s 时仍 valid、0.8s 内 queue_free——当前 main 清场模式 headless 下留尸，FAIL）。
- [ ] **Step 2: 跑测试确认失败形态**——死亡演出断言 FAIL，其余 PASS。
- [ ] **Step 3: Commit** `test: 月蚀女王闪烁月相与死亡清理回归`。

---

### Task 2: `_die` 自救与死亡自回收

**Files:**
- Modify: `scripts/enemies/eclipse_queen.gd`

- [ ] **Step 1: 移植自救**——照搬 tomb_warden.gd `_die()` 段：is_dead 守卫 → remove_from_group("enemies") + `_set_boss_collisions(false)` + 感应区 set_deferred 关闭 → super._die()；`_play_death_visual` placeholder 0.4s 淡出兜底 + TASK4 WIRE 注释预留。
- [ ] **Step 2: 跑 Task 1 测试转绿 + 复跑 gameplay_slice/floor_expansion 防回归。**
- [ ] **Step 3: Commit** `fix: 月蚀女王死亡演出从 main 清场中自救`。

---

### Task 3: 六张动作表生成与打包

**Files:**
- Create: `tools/pack_eclipse_queen_sprites.py`、`assets/sprites/boss/eclipse_queen/`（6 PNG + .import + production.json）、`artifacts/eclipse_queen/`
- Modify: `scripts/core/asset_slots.gd`、`.gitignore`

- [ ] **Step 1: 生成原图**（mcode-tools-master 技能 + 图像 connector，参考图垫绿底 ≤4:1）：6 列 × 6 行，行序 idle/move/blink/appear/phase_change/death；紫银月蚀女王（accent 对齐 tint 0.62/0.48/0.95）；blink 行月影消散、appear 行凝聚成形，互逆不串味；风格锚 blood_lord idle.png；Pillow 逐格校验，不合格 regenerate；node_id 记入 production.json。
- [ ] **Step 2: 打包**——复用母皇管线（色键/切格/去碎片/最近邻/脚底锚点 y=119），行映射 6 行，输出 assets/sprites/boss/eclipse_queen/；校验 6 张 768×128 RGBA；Godot --import；.gitignore 补 `/artifacts/eclipse_queen/`。
- [ ] **Step 3: asset_slots 更新**——eclipse_queen → [idle, move, blink, appear, phase_change, death]，blurb 不动。
- [ ] **Step 4: Commit** `feat: 月蚀女王六张专属动作表`。

---

### Task 4: 动画状态机接线

**Files:**
- Modify: `scripts/enemies/eclipse_queen.gd`、`tools/eclipse_queen_animation_test.gd`

- [ ] **Step 1: 动画层**——照搬守望者机制（`_animation_textures`/`_show_animation`/`_tick_sprite`/`_set_animation_frame`）；`_animation_for_state()` 优先级 death > intro(idle) > blink > appear > phase_change > move > idle；瞬移帧同帧 `_appear_visual_remaining=0.35`；`altar_destroyed()` 与月相 2 判定帧同帧 `_phase_visual_remaining=0.6`；两时钟在 `_tick_sprite` 递减。
- [ ] **Step 2: 测试补帧断言 + --real-assets**——6 状态映射、帧推进、暂停冻结、6 张 PNG 768×128 且 using_placeholder==false；不削弱 Task 1 断言。
- [ ] **Step 3: 双模式测试 + 防回归**（gameplay_slice、floor_expansion）。
- [ ] **Step 4: Commit** `feat: 月蚀女王动画状态机`。

---

### Task 5: 真实房间预览录像

**Files:**
- Create: `tools/eclipse_queen_preview.gd`、`artifacts/eclipse_queen/`（AVI、scene_*.png、preview_capture.json）

- [ ] **Step 1: 写预览脚本**——照搬守望者预览；真实 Main 第五层 Boss 房（floor_index=4，按守望者批次 current_floor 下标语义核对）；顺序 idle→move→blink（脚本置 `_timer=0` 触发真实闪烁）→appear→phase_change（脚本打掉祭坛）→death；每状态首帧截图；capture json 断言 blink_shown/appear_shown/phase_change_shown/death_shown，failures=0；结束清 BGM/SFX；无摘组 workaround。
- [ ] **Step 2: 录制**（--write-movie artifacts/eclipse_queen/eclipse_queen_preview.avi，run_in_background）。
- [ ] **Step 3: Commit** `feat: 月蚀女王真实房间预览脚本`。

---

### Task 6: 全量回归、台账与交付包（本批为最终批，全量测试后推送）

**Files:**
- Create: `artifacts/eclipse_queen/run_checks.py`、`validation_results.json`、`eclipse_queen_delivery.zip`
- Modify: `docs/animation-asset-inventory.md`、`docs/asset-licenses.md`

- [ ] **Step 1: 回归驱动**——cases = 前四批全部 + eclipse_queen_animation_test（real-assets 组加本批）。
- [ ] **Step 2: 五层烟测**（RESULT fail=0）。
- [ ] **Step 3: 台账与授权**——eclipse_queen 行改已完成，PNG 250→256、表 74→80，第十六节验收记录；licenses 登记 6 张表。
- [ ] **Step 4: ZIP 并校验**（testzip + 条目断言）。
- [ ] **Step 5: Commit** `docs: 月蚀女王切片验收记录与回归驱动`。
- [ ] **Step 6: 批次终审通过后：文档补提交（spec+plan+.uid）→ git push origin master（全部三个 Boss 批次收尾）。**

---

## Self-Review 记录

- Spec 覆盖：机制零改动 + `_die` 修复（Task 1/2）、素材（Task 3）、动画（Task 4）、预览（Task 5）、闭环+推送（Task 6）。
- 与前批差异：appear/phase_change 两个纯表现时钟（blink 期间 `_physics_process` 提前 return，瞬移帧之后的表现在代码里无锚点，需要新增 visual timer——属表现层新增，不改瞬移时点）。
- 测试文件单一（eclipse_queen_animation_test.gd），行为断言在 Task 1 针对既有机制即应 PASS，仅死亡自救回收为 RED→GREEN。
