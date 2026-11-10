# Gameplay And Readability Iteration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修复审查确认的战斗规则、Build、UI 与可读性问题，并用自动化及实机验证完整交付。

**Architecture:** 沿用现有 Main/Manager/Player/Enemy/UI 分层，不引入新框架。战斗规则在各自拥有状态的对象内修复；共享问题复用 RoomLookup、GameConfig、ItemCatalog 和 UiFx；测试继续使用 `tools/*_test.gd`。

**Tech Stack:** Godot 4.7.2、GDScript、现有 Python/PIL 资产工具。

**Spec:** `docs/superpowers/specs/2026-11-10-gameplay-iteration-design.md`

## Global Constraints

- 不修改音频占位内容，不新增依赖，不做 Git 提交。
- 子代理使用 `minimax-cn-coding-plan/MiniMax-M3`，除非其限额不可用。
- 每个行为修复先添加或扩展能失败的 Godot 回归测试，再实现并运行至通过。
- 测试存档与真实玩家存档隔离；不得回滚用户已有改动。

---

### Task 1: 测试存档隔离

**Files:** `scripts/managers/save_manager.gd`，相关 `tools/*test.gd` / `tools/run_dungeon_smoke.gd`。

- [ ] 找出 SaveManager 可注入的存档路径或增加仅供测试使用的路径设置。
- [ ] 在测试入口初始化后切换到 `user://test_<suite>.json`，删除仅属于该测试的临时数据。
- [ ] 运行一个会保存成就的冒烟测试，确认日志不再使用真实存档，且测试通过。

### Task 2: 战斗规则闭环

**Files:** `scripts/map/game_room.gd`、`scripts/player/player.gd`、`scripts/enemies/enemy_base.gd`、`scripts/enemies/enemy_projectile.gd`、`scripts/weapons/weapon_manager.gd`、`scenes/enemies/*.tscn`、`scenes/player/*.tscn`、`tools/feel_fix_test.gd`、`tools/combat_visual_test.gd`。

**Interfaces:** 保留现有武器和伤害公共接口；击退使用玩家私有独立速度；非 `auto_aim` 武器读取现有 `shoot` action。

- [ ] 添加墙层/mask、持续接触伤害、玩家击退、射速倍率、手动开火和传送门安全位置的失败断言。
- [ ] 运行新增断言，确认在当前实现上失败。
- [ ] 成组修复碰撞层；按 0.5 秒无敌帧实现接触持续结算；叠加并衰减击退；把射速倍率应用到计时器。
- [ ] 非自动瞄准武器仅在按住射击时开火；自动瞄准武器保持自动。
- [ ] 普通传送门选择离玩家足够远且不在障碍中的点；保持岔路门接口不变。
- [ ] 运行战斗、体验和既有 XP/武器测试至通过。

### Task 3: Build 与敌人规则

**Files:** `scripts/ui/upgrade_ui.gd`、`scripts/player/player.gd`、`scripts/core/item_catalog.gd`、`scripts/enemies/exploder.gd`、`scripts/enemies/summoner.gd`、`scripts/enemies/enemy_base.gd`、`scripts/enemies/vampire_lord.gd`、`scripts/managers/main.gd`、`scripts/managers/dungeon_manager.gd`、`tools/roguelite_ops_test.gd`、`tools/elite_affix_test.gd`、`tools/phase17_test.gd`。

- [ ] 为属性卡 5 级上限、补给卡可达、自爆掉落、召唤物计数、战斗房解锁和 Boss 弹幕前摇添加失败测试。
- [ ] 实现最小改动；每日模式把局内 RNG 传入升级抽卡，普通模式保持原行为。
- [ ] 掉落钳制复用 `RoomLookup.find_room(self)` 与统一 bounds，银币合并前也保证落点有效。
- [ ] 运行 Build、词缀、Boss、数值曲线与三层冒烟测试。

### Task 4: HUD、暂停与升级交互

**Files:** `scripts/ui/hud.gd`、`scripts/ui/upgrade_ui.gd`、`scripts/ui/pause_menu.gd`、`scripts/ui/main_menu.gd`、`scripts/ui/ui_fx.gd`、`scripts/ui/room_shop.gd`、`scripts/ui/blood_pact_ui.gd`、`scripts/ui/mutation_altar_ui.gd`、`scenes/ui/*.tscn`、`tools/feedback_v2_test.gd`、`tools/_shot_ui_fx.gd`。

- [ ] 添加暂停所有权、独立 toast/进化横幅、升级预览和 UiFx 无 meta 错误的回归验证。
- [ ] 用计数式暂停控制或等价单一入口替换互相覆盖的 `paused` 写入。
- [ ] HUD 统一 Wave/Phase 中文，增强 720p 字号与对比；Boss 战隐藏无关波次信息。
- [ ] 新被动只展示当前效果，升级才显示前后值；分离 toast、进化和波次横幅。
- [ ] 修复 `ui_fx.gd:40` 缺失 meta 错误及重复 hover tween；暂停菜单加入设置和放弃本局确认。
- [ ] 运行 UI 测试并捕获主菜单、升级、暂停和 Boss 截图检查。

### Task 5: 战斗画面可读性

**Files:** `scripts/map/game_room.gd`、`scripts/enemies/enemy_projectile.gd`、`scenes/enemies/enemy_projectile.tscn`、必要的现有视觉管理器与 `tools/combat_visual_test.gd`。

- [ ] 固定背景过滤策略，移除或默认关闭不对齐的调试网格。
- [ ] 不批量重做资产；通过轮廓、亮芯/暗边、尺寸和背景层级提升敌方弹丸与敌人的辨识度。
- [ ] 保留各房间主题，检查柱子/道具底座和生成点不穿模。
- [ ] 生成 1280×720 战斗与 Boss 截图，确认玩家、敌人、危险弹丸和 HUD 的视觉优先级。

### Task 6: 完整验收

- [ ] 运行项目 README 中所有相关断言、数值曲线、200 次结构验算、三层冒烟和本轮新增回归。
- [ ] 检查控制台无本轮新增 ERROR；修复可定位的资源释放问题。
- [ ] 实机走通主菜单→选角→战斗→升级→商店→暂停→设置→返回。
- [ ] 检查 `git status`，删除验证产生且不需要的临时文件，保留计划、测试和正式截图。
- [ ] 汇总改动、测试结果、仍需资产重制或正式音频处理的边界。
