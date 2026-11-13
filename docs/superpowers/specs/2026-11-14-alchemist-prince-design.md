# 炼金亲王（alchemist_prince）垂直切片设计

> 2026-11-14。第四批 Boss 动作表垂直切片，管线与验收口径完全沿用前三批。本批为**双单位**（亲王 + 巨像），工作量最大。

## 1. 目标与范围

为第四层双单位 Boss 炼金亲王交付完整垂直切片：
- 两张动作图集共 10 张专属动作表（亲王 5 + 巨像 5），统一 768×128 / 6 帧 RGBA；
- 双单位动画状态机接线（亲王 boss_stage 层 + 巨像 enemy_base 层）；
- 双单位 `_die` 自救修复（亲王/巨像的死亡演出都会被 main 清场或即时回收吞掉，本切片一并修掉）；
- 真实房间预览录像（第四层 Boss 房）；
- 回归、台账、授权登记与交付包闭环。

## 2. 现有机制（不改数值）

亲王 `scripts/enemies/alchemist_prince.gd`（继承 boss_stage.gd）：
- 双人机制：`_mode` "pair"/"solo_prince"；巨像先倒 → `colossus_fell()` → solo（移速 78→140、掷瓶冷却 2.2s→1.3s），发 `boss_phase_changed(1)`；
- 掷瓶：`_timer` 冷却到点后 `_toss(player.global_position)`，药水瓶 puddle（damage 10，敌我都伤）；
- 亲王先倒：`_die()` → 立即 invisible + 关物理 → 巨像 `enrage()`，发 `boss_phase_changed(2)`；两者都倒 → `_finish_fight()` 发 `boss_defeated`；
- tier 4、移速 78、接触伤害 12、绿 tint (0.4, 0.78, 0.48)。

巨像 `scripts/enemies/alchemist_colossus.gd`（继承 enemy_base.gd）：
- 220 HP、移速 36、接触 18、XP 20；`add_to_group("boss_add")`；占位图 furnace_golem；
- `enrage()`：移速 36→70、`_timer=0.4`；砸地：enraged 且距玩家 <90px 每 1.6s 造成 16 伤害；
- `_die()`：通知亲王 `colossus_fell()` 后立即 `queue_free()`，零死亡演出。

**硬约束：动画零行为改动。** 掷瓶冷却/伤害、移速与 mode 系数、巨像砸地窗/伤害、enrage 数值、双单位死亡时序契约（亲王先倒须留尸至巨像倒下）全部保持现状；动画层只做表现。

## 3. 双单位 `_die` 修复（本批核心难点）

两条死亡演出被吞的路径，都用织血母皇/守望者已验证的自救模式修：
1. **巨像先倒**：巨像 `_die()` 立即 queue_free、零演出 → 改为 `remove_from_group("enemies")` + 关碰撞 → death 条带 tween 0→6 帧 0.6s → 自行 queue_free（<0.8s 自回收，linked_nodes 由亲王 _exit_tree 连带清理的现状不变）；
2. **亲王先倒**：亲王 `_die()` 立即 invisible → 改为自救退组 + death 条带 0.6s **播完后**再 invisible（战斗契约不变：不 queue_free、巨像照常 enrage）；
3. **双倒收尾**：此时 main `_on_boss_defeated` 的 enemies 组清场会吞演出——亲王/巨像在各自 `_die()` 起点就退组（先于 boss_defeated 信号），条带播完自行 queue_free；亲王尸体的最终回收从「main 清场」改为「_finish_fight 时若条带已播完即自行 queue_free」。

## 4. 动画状态设计

亲王 5 状态（6 列 × 5 行图集）：

| 状态 | 触发 | 说明 |
|---|---|---|
| idle | 无移动 | 待机，手持药水瓶 |
| move | velocity 非零 | 飘移/走动 |
| cast | `_toss()` 被调用 | 0.6s 掷瓶表现（不改生成时点） |
| solo_shift | `colossus_fell()` 被调用 | 0.6s 换招强化表现（巨像先倒） |
| death | `is_dead` | tween 0→6 帧 0.6s；先倒时播完转 invisible |

巨像 5 状态（6 列 × 5 行图集）：

| 状态 | 触发 | 说明 |
|---|---|---|
| idle | 无移动 | 待机，熔炉核心微光 |
| move | velocity 非零 | 沉重迈步 |
| slam | 砸地判定帧 | 0.6s 砸地表现（判定逻辑不动） |
| enrage | `enrage()` 被调用 | 0.6s 狂暴化表现（移速变化维持代码现状） |
| death | `is_dead` | tween 0→6 帧 0.6s 后 queue_free |

亲王优先级：death > intro(idle) > cast > solo_shift > move > idle。
巨像优先级：death > slam > enrage > move > idle（intro 概念不适用于 enemy_base）。
暂停冻结、占位降级沿用基类与前三批机制。

## 5. 素材生成

- 两张 6 列 × 5 行图集（单格正方形、纯 #00FF00 绿底、无网格无文字）：prince 行序 idle/move/cast/solo_shift/death；colossus 行序 idle/move/slam/enrage/death；
- 亲王：绿金炼金术师，长袍+药水瓶，green palette（accent 对齐 tint 0.4~0.78）；巨像：青铜熔炉魔像，furnace 主题，bronze/copper palette；两图集角色不得串味；
- 风格锚继续用 assets/sprites/boss/blood_lord/idle.png；参考图垫绿底解法同前三批（宽高比 ≤4:1）；
- 打包复用 tools/pack_blood_matriarch_sprites.py 逻辑，改行映射（5 行）与输出目录：assets/sprites/boss/alchemist_prince/ 与 assets/sprites/boss/alchemist_colossus/；
- asset_slots.gd：alchemist_prince 条目扩为 [idle, move, cast, solo_shift, death]；alchemist_colossus 条目扩为 [idle, move, slam, enrage, death]（现有 cast/slam 命名保留沿用）。

## 6. 测试

新建 `tools/alchemist_prince_animation_test.gd`（SceneTree，仿守望者测试）：
- 行为：pair 掷瓶冷却 2.2s / solo 1.3s 与移速 140；巨像砸地 16 伤害 <90px、冷却 1.6s；enrage 移速 36→70；mode 切换信号；
- 死亡：巨像先倒 → 亲王 solo_shift 且巨像 0.8s 内自回收；亲王先倒 → 巨像 enrage、亲王尸体保留（不 queue_free）、invisible 发生于条带播完后；双倒 → boss_defeated 发出且双单位条带不被清场吞掉、0.8s 内各自回收；
- 动画：10 状态映射、帧推进、暂停冻结、`-- --real-assets`：10 张 PNG 768×128 且 using_placeholder==false。

既有回归（gameplay_slice_test 第四层双目标断言、floor_expansion_test）不得破坏。

## 7. 预览与交付

- `tools/alchemist_prince_preview.gd`：真实 Main 第四层 Boss 房（floor_index=3）；顺序 pair idle/move → cast（吃一瓶）→ slam（巨像砸地）→ 打爆巨像（亲王 solo_shift）→ 打爆亲王（death 条带播完才倒下）→ 战斗收尾；每状态首帧截图；capture json 断言 cast_shown/slam_shown/solo_shift_shown/prince_death_shown/colossus_death_shown，failures=0；结束清 BGM/SFX；
- 注：一条预览只能演示一种死亡顺序（本预览用「巨像先倒」完整展示 solo_shift）；「亲王先倒→巨像 enrage」路线由测试断言覆盖；
- 回归驱动 `artifacts/alchemist_prince/run_checks.py`：cases = 前三批全部 + alchemist_prince_animation_test（带 -- --real-assets 的组加本批）；
- 台账：alchemist_prince 与 alchemist_colossus 两行改已完成，PNG 240→250、表 64→74，追加第十五节验收记录；licenses 登记 10 张表（AI 生成、待核实）；
- 交付 ZIP：`artifacts/alchemist_prince/alchemist_prince_delivery.zip`（testzip + 条目断言）。

## 8. 不做（YAGNI）

- 不改 potion_puddle / alchemist_pitcher（小怪的动画不在本批）；
- 不改双单位数值与死亡时序契约；
- 不做月蚀女王（下一批）；
- 不补 P1/P2 特效帧。
