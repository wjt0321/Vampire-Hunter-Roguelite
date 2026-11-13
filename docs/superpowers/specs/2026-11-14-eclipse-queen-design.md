# 月蚀女王（eclipse_queen）垂直切片设计

> 2026-11-14。第五批（最后一批 P0 Boss）动作表垂直切片，管线与验收口径完全沿用前四批。

## 1. 目标与范围

为第五层 Boss 月蚀女王交付完整垂直切片：
- 6 张专属动作表（idle / move / blink / appear / phase_change / death），统一 768×128 / 6 帧 RGBA；
- 动画状态机接线（boss_stage 层，照搬守望者模式）；
- `_die` 自救修复（与母皇/守望者/亲王同款的 main 清场吞死亡演出问题）；
- 真实房间预览录像（第五层 Boss 房）；
- 回归、台账、授权登记与交付包闭环。

## 2. 现有机制（不改数值）

代码现状 `scripts/enemies/eclipse_queen.gd`（继承 boss_stage.gd）：
- 祭坛：`_ready` 生成 moon_altar（40 HP，位于守望者式偏移 -130,50，登记 linked_nodes）；打掉 → `altar_destroyed()` → moon_phase=1、发 `boss_phase_changed(1)`；
- 闪烁换位：`_timer` 1.4s 冷却到点 → `_blinking=true`、`_blink_to=玩家位置`（标落点），0.45s 后瞬移到位；落点后冷却 0.7s（月相 0）/ 0.4s（月相 ≥1）；
- 二阶段：current_hp < 40% → moon_phase=2、发 `boss_phase_changed(2)`（_physics_process 内联判定）；
- 安全圈：safe_radius() 150（月相 0）/ 90（≥1），由场景侧 moon_well 表现（圈外玩家持续掉血，本批不动 moon_well）；
- tier 5、移速 80、接触伤害 14、紫 tint (0.62, 0.48, 0.95)；
- 死亡：未覆写 `_die`，main 清场同步回收——死亡演出播不出（前四批同款问题，本切片修复）。

**硬约束：动画零行为改动。** 闪烁冷却/瞬移时点、月相推进条件、安全圈半径、移速、接触伤害全部保持现状；动画层只做表现。

## 3. 动画状态设计

| 状态 | 触发 | 时长口径 | 说明 |
|---|---|---|---|
| idle | 无移动、无闪烁 | 循环 | 待机，月华环绕 |
| move | velocity 非零 | 循环 | 飘移追击 |
| blink | `_blinking==true` | 0.45s 前摇全程 | 化作月影消散（伤害窗无，纯表现；落点标记由既有代码负责） |
| appear | 瞬移到位帧 | 0.35s 表现时钟 | 月影凝聚成形（visual-only timer，瞬移帧同帧置位） |
| phase_change | `altar_destroyed()` 或月相 2 判定帧 | 0.6s | 月相推进爆发表现（两处接线同帧置位，判定逻辑不动） |
| death | `is_dead` | tween 0→6 帧 0.6s 后 queue_free | 沿用前批死亡模式 |

状态优先级：death > intro(idle) > blink > appear > phase_change > move > idle。
暂停冻结、占位降级沿用基类与前几批机制。

## 4. `_die` 自救修复

照搬墓穴守望者 `748a4b6` 的修复：覆写 `_die()`，在 `super._die()` 之前 `remove_from_group("enemies")` + 关碰撞，death 条带 0.6s 播完自行 queue_free；祭坛随 linked_nodes 在 `_exit_tree` 连带清理（现状不变）。

## 5. 素材生成

- 一张 6 列 × 5 行动作图集？——否，统一 6 列 × 6 行（单格正方形、纯 #00FF00 绿底、无网格无文字），行序 idle / move / blink / appear / phase_change / death；
- 角色：月蚀女王，紫银长袍、月冕、幽紫月火，purple/silver palette（accent 对齐 tint 0.62/0.48/0.95）；blink 行呈消散/月影化，appear 行呈凝聚成形，两行动态互逆不串味；
- 风格锚继续 assets/sprites/boss/blood_lord/idle.png；参考图垫绿底 ≤4:1 同前批；
- 打包复用 tools/pack_blood_matriarch_sprites.py 逻辑（色键/切格/去碎片/最近邻/脚底锚点 y=119），改行映射与输出目录 assets/sprites/boss/eclipse_queen/；
- asset_slots.gd：eclipse_queen 条目扩为 [idle, move, blink, appear, phase_change, death]（blurb 不动）。

## 6. 测试

新建 `tools/eclipse_queen_animation_test.gd`（SceneTree，仿守望者测试）：
- 行为：闪烁周期（1.4s 冷却→0.45s 前摇→瞬移到玩家位置）；落点后冷却 0.7/0.4 随月相切换；祭坛 40HP 打掉后 can 安全圈半径 150→90（safe_radius() 返回值）与 phase 信号；hp<40% 月相 2 信号；祭坛随女王死亡连带清理（linked_nodes）；
- 死亡：`_die` 自救后 0.8s 内自回收、死亡演出播放中（0.2s 时）仍 valid；
- 动画：6 状态映射、帧推进、暂停冻结、`-- --real-assets`：6 张 PNG 768×128 且 using_placeholder==false。

既有回归不得破坏（gameplay_slice 第五层断言、floor_expansion）。

## 7. 预览与交付

- `tools/eclipse_queen_preview.gd`：真实 Main 第五层 Boss 房（floor_index=4）；顺序 idle→move→blink（瞬移换位）→appear→phase_change（脚本打掉祭坛）→death；每状态首帧截图；capture json 断言 blink_shown/appear_shown/phase_change_shown/death_shown，failures=0；结束清 BGM/SFX；无摘组 workaround；
- 回归驱动 `artifacts/eclipse_queen/run_checks.py`：cases = 前四批全部 + eclipse_queen_animation_test（real-assets 组加本批）；
- 台账：eclipse_queen 行改已完成，PNG 250→256、表 74→80，追加第十六节验收记录；licenses 登记 6 张表（AI 生成、待核实）；
- 交付 ZIP：`artifacts/eclipse_queen/eclipse_queen_delivery.zip`（testzip + 条目断言）。

## 8. 不做（YAGNI）

- 不改 moon_well / moon_altar 的数值与表现；
- 不给闪烁加落点新标记（既有"标出落点"由 _blink_to 代码路径负责，本批只保证 blink/appear 动画语义）；
- 不补 P1/P2 特效帧；
- 不做炼金投手/熔炉魔像等小怪动画。
