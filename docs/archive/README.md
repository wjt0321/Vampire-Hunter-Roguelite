# 归档文档

本目录存放**已不再维护**的历史文档。它们保留下来是为了追溯决策依据，
不是当前工作的依据。

## 归档规则

文档移到这里表示：它的内容已经被更新的文档取代，或者它记录的是一次已经结束的工作批次。

- **不要再往这里加新文档**——新写的规格、清单、台账一律放在 `docs/` 根目录。
- **这里的文档不保证链接有效**，也可能有指向旧路径的过时引用（保持原样以便追溯）。
- 引用归档内容时，注明「见 docs/archive/...」并说明它已被谁取代。

## 当前现行文档（不在本目录）

| 文档 | 作用 |
|---|---|
| [../GDD.md](../GDD.md) | 玩法规格与取舍说明 |
| [../ROADMAP.md](../ROADMAP.md) | 开发阶段与推进顺序 |
| [../asset-status.md](../asset-status.md) | 静态美术完成记录、验收数据与回退方式 |
| [../animation-asset-inventory.md](../animation-asset-inventory.md) | 动态帧覆盖、缺口与补帧规格 |
| [../asset-licenses.md](../asset-licenses.md) | 第三方素材授权与风险登记 |
| [../asset-source-list.md](../asset-source-list.md) | 可用素材站与作者链接 |
| [../art-assets-requirements.md](../art-assets-requirements.md) | 资源规格与命名规范 |

## 本目录内容

### reports/ —— 素材采集与整理（2026-06-15）

早期从公开素材站采集第三方资源的记录：分类报告（角色、Boss/UI、武器道具、瓦片、音频BGM、字体特效、综合汇总）、
采集计划，以及把 `assets-downloaded/` 整理进 `assets/` 的执行计划与报告。

**已被取代**：当前资产状态见 [../asset-status.md](../asset-status.md) 与
[../animation-asset-inventory.md](../animation-asset-inventory.md)；授权状态见 [../asset-licenses.md](../asset-licenses.md)。

### qa/ —— 音频适配前修复（2026-11-08）

音频工作开始之前的 50 项修复记录：分批任务报告（战斗、经济、生命周期/存档、音频）与全量回归验证记录。

**已被取代**：当前回归门槛以 `tools/` 下现存的测试脚本为准；
本目录的 `validation.md` 只证明当时那一次快照通过。

### gdd-revision-plan.md —— GDD 完善规划

从 MVP 推到可发布版本的数值审计与重构规划（前期难打 / 后期无伤 / 数值崩塌）。

**已被取代**：具体数值与系统取舍已写进 [../GDD.md](../GDD.md)；
阶段推进状态见 [../ROADMAP.md](../ROADMAP.md)。

### code-review-2026-02.md —— 早期代码审核报告

2026-02-23 的一次全项目代码审核（Godot 4.6 时期）。

**已被取代**：此后经过多轮玩法迭代与重构，结论只反映当时的代码状态。
