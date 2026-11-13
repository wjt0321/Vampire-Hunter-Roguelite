# 墓穴守望者（tomb_warden）垂直切片设计

> 2026-11-14。第三批 Boss 动作表垂直切片，管线与验收口径完全沿用血铠领主/织血母皇两批。

## 1. 目标与范围

为第三层 Boss 墓穴守望者交付完整垂直切片：
- 6 张专属动作表（idle / move / lantern_sweep / revive / ward_break / death），统一 768×128 / 6 帧 RGBA；
- 动画状态机接线（照搬血铠领主模式）；
- `_die` 自救修复（与织血母皇同款的 main 清场吞死亡演出问题，本切片一并修掉）；
- 真实房间预览录像（第三层 Boss 房）；
- 回归、台账、授权登记与交付包闭环。

## 2. 现有机制（不改数值）

代码现状 `scripts/enemies/tomb_warden.gd`（73 行，继承 boss_stage.gd）：
- 提灯扫击：`_sweep_timer` 2.8s 冷却；触发时锁定 `_sweep_dir = 指向玩家的方向`，`_sweep_left = 0.55s` 伤害窗内每帧判定，射程 260px、半角 0.35rad，命中 `player.take_damage(9.0)`；
- 结界：`_ready` 生成 ward_core（48 HP，位于守望者 +120,40，登记 `linked_nodes`）；结界存活时 `_revive_cd` 6s 拉一只 zombie（enemies 组 >12 不拉）；
- 转阶段：结界被打掉 → `ward_broken()` → 移速系数 0.7 → 1.2，发 `boss_phase_changed`；
- 死亡：未覆写 `_die`，main 的 `_on_boss_defeated` 同步清 enemies 组会瞬间回收守望者——死亡演出在真实 gameplay 播不出（织血母皇批次同款问题，本切片修复）。

**硬约束：动画零行为改动。** 伤害窗、冷却、复苏时点、移速、结界 HP 全部保持现状；动画层只做表现。
**方向硬约束（台账原话）：提灯朝向和扫射预警必须同向。** 本设计不加额外前摇（伤害窗起点即扫击动画起点，方向在同一帧锁定），从机制上消灭不同向的可能。

## 3. 动画状态设计

| 状态 | 触发 | 时长口径 | 说明 |
|---|---|---|---|
| idle | 无移动、无扫击 | 循环 | 待机，提灯自然下垂 |
| move | velocity 非零 | 循环 | 提灯随步态晃动 |
| lantern_sweep | `_sweep_left > 0` | 0.55s 伤害窗全程 | 提灯沿锁定方向挥出弧光；`flip_h`/旋转必须朝向 `_sweep_dir` |
| revive | `_raise_one()` 被调用 | 0.6s | 提灯指向地面/棺材，亡者爬起与召唤同时点开始（不改生成时点） |
| ward_break | `ward_broken()` 被调用 | 0.6s | 守望者后仰/踉跄（结界碎裂在 ward_core 侧表现），期间移速变化维持代码现状 |
| death | `is_dead` | tween 0→6 帧 0.6s 后 queue_free | 沿用血铠领主/母皇死亡模式 |

状态优先级：death > intro(idle) > lantern_sweep > revive > ward_break > move > idle。
暂停冻结动画、占位降级（缺表时回退共用 boss_idle + 灰蓝 tint）沿用基类与血铠领主机制。

## 4. `_die` 自救修复

照搬织血母皇 `56fcddb` 的修复：覆写 `_die()`，在 `super._die()` 之前 `remove_from_group("enemies")` + 关碰撞，
使 main 的 Boss 清场扫不到守望者，0.6s 死亡 tween 播完后自行 queue_free；ward_core 随 `linked_nodes` 在 `_exit_tree` 连带清理。
修复后预览脚本不再需要外部摘组 workaround（沿用母皇模式：预览脚本照写无 workaround，因为游戏侧已自愈）。

## 5. 素材生成

- 一张 6 列 × 6 行动作图集（单格正方形、纯 #00FF00 绿底、无网格无文字）；
- 行序：idle / move / lantern_sweep / revive / ward_break / death；
- 角色：披腐朽罩袍的墓穴守望者，左手/右手固定一侧提一盏幽蓝灯笼，灰蓝调色板（accent 0.45~0.62），第三层 tomb 主题（墓穴、棺木、幽火）；像素密度与描边对齐血铠领主 idle.png（继续作风格锚）；
- **提灯同侧约束写进生成提示词**：全 48 格灯笼只出现在角色同一侧，sweep 行的灯笼沿挥击方向延展；
- 打包复用 `tools/pack_blood_matriarch_sprites.py` 的色键/切格/去碎片/脚底锚点逻辑，改行映射与输出目录为 `assets/sprites/boss/tomb_warden/`；
- asset_slots.gd 的 tomb_warden 条目扩为 6 states；台账 idle 4 帧建议按母皇先例统一为 6 帧（管线统一，台账同步修正）。

## 6. 测试

新建 `tools/tomb_warden_animation_test.gd`（SceneTree，仿母皇测试）：
- 行为：扫击窗内命中/窗外不命中、方向锁定后玩家离开扇区不再命中；复苏间隔与 12 上限；结界死亡后 `can_revive()==false` 且不再拉僵尸；守望者死亡后 ward 随 linked_nodes 清理；
- 动画：6 状态触发映射正确、帧随计时推进、暂停冻结、`_die` 自救后 0.8s 内自回收；
- `-- --real-assets`：6 张 PNG 768×128 且 `using_placeholder == false`。

既有回归（floor_expansion_test 的 _test_bosses、gameplay_slice_test 第三层断言）不得破坏。

## 7. 预览与交付

- `tools/tomb_warden_preview.gd`：真实 Main 第三层 Boss 房；顺序 idle→move→sweep→revive（僵尸出现）→ward_break（脚本打爆结界）→death；玩家脚本走位吃一发扫击；AVI 1280×720/30fps + scene_<state>.png + preview_capture.json（failures=0，断言 sweep_shown/revive_shown/ward_break_shown/death_shown）；结束清 BGM/SFX；
- 回归驱动 `artifacts/tomb_warden/run_checks.py`：cases = 母皇 7 组 + tomb_warden_animation_test，tomb_warden/blood_lord/blood_matriarch 三组带 `-- --real-assets`；
- 台账：tomb_warden 行改已完成，PNG 234→240、表 58→64，追加第十四节验收记录；licenses 登记 6 张表（AI 生成、待核实）；
- 交付 ZIP：`artifacts/tomb_warden/tomb_warden_delivery.zip`（testzip + 条目断言，排除诊断产物）。

## 8. 不做（YAGNI）

- 不给扫击加前摇/预警条（会改变伤害时点；方向同向约束用「动画起点=伤害窗起点」满足）；
- 不改 ward_core  visuals/数值；
- 不做炼金亲王/月蚀女王（后续批次）；
- 不补 P1/P2 特效帧。
