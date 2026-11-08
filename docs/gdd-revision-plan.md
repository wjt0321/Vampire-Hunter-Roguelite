# GDD 完善规划
## 吸血鬼猎人 Roguelite — 从 MVP 到可发布版本

> 本文档基于对现有代码的完整数值审计制定，目标是解决"前期难打、后期无伤、数值崩塌"三大核心问题，并将游戏从原型推进到可发布状态。

---

## 一、现状诊断摘要

### 1.1 核心数值问题根因

| 症状 | 根因 | 代码证据 |
|------|------|---------|
| **前期难打** | 手枪基础 DPS 仅 ~7，吸血鬼 HP=33 需 5 发≈1.75s，僵尸 HP=132 需 53 发≈18.5s | `weapon_manager.gd:414` `base_damage=2.5` |
| **后期无伤** | 护甲固定减伤 `maxf(dmg-armor,1)` 可堆到免疫；闪避/吸血/护盾/恢复多重叠加 | `player.gd:216` |
| **数值崩塌** | 8 武器独立开火 + 进化伤害×2.5-3.0 + 射速×0.3-0.5 → DPS 指数爆炸 | `weapon_manager.gd:45-46` |
| **成长不线性** | 敌人 HP 固定（蝙蝠16.5→亲王350），玩家成长无上限 | `wave_manager.gd` 敌人静态数值 |

### 1.2 具体数值对比（当前）

```
玩家 DPS 估算（单手枪 Lv1）:
  2.5 dmg / 0.35s = 7.14 DPS
  击杀吸血鬼(33HP): ~1.75秒
  击杀僵尸(132HP): ~18.5秒  ← 明显不合理

玩家后期 DPS 估算（8武器全进化）:
  单武器进化后: 2.5×3.0 / (0.35×0.3) = 71.4 DPS
  8武器合计: ~500+ DPS
  Boss(1690HP): ~3.4秒  ← 数值崩塌
```

---

## 二、重构目标

### 2.1 体验目标

| 阶段 | 目标体验 | 时长 |
|------|---------|------|
| **前期（波次1-5）** | 紧张但有掌控感，2-3发击杀基础敌人 | 0-3分钟 |
| **中期（波次6-15）** | Build 成型，组合策略显现，需要走位 | 3-10分钟 |
| **后期（波次16-25）** | 高压挑战，Boss 战有史诗感，可能失败 | 10-20分钟 |
| **终局（波次26+）** | 极限生存，排行榜竞争 | 20分钟+ |

### 2.2 数值目标

| 指标 | 当前 | 目标 |
|------|------|------|
| 基础敌人击杀时间 | 1.75-18.5s | 0.3-1.0s |
| Boss 战时长 | ~3.4s | 60-120s |
| 单局时长 | 不稳定 | 15-25分钟 |
| 玩家 DPS 成长曲线 | 指数爆炸 | 对数/线性可控 |
| 防御叠加收益 | 无敌 | 递减收益 |

---

## 三、分阶段实施规划

### Phase A: 数值框架重构（1-2周）

**目标**: 建立可控的数值基础，替换现有硬编码

| 任务 | 优先级 | 产出 |
|------|--------|------|
| A1. 新建 `game_config.gd` 配置中心 | 🔴 高 | 所有数值集中管理 |
| A2. 重构敌人 HP/伤害公式 | 🔴 高 | 敌人随波次指数成长 |
| A3. 重构玩家 DPS 成长曲线 | 🔴 高 | 武器伤害公式重构 |
| A4. 护甲改为百分比减伤 | 🔴 高 | 避免固定减伤无敌 |
| A5. 经验/血晶公式重构 | 🟡 中 | 平滑成长曲线 |
| A6. 被动收益递减机制 | 🟡 中 | 避免后期无敌 |

### Phase B: 核心循环完善（2-3周）

**目标**: 让游戏"好玩"，而不仅是"能玩"

| 任务 | 优先级 | 产出 |
|------|--------|------|
| B1. 武器进化条件多样化 | 🔴 高 | 不同武器不同进化路径 |
| B2. Boss 战机制丰富化 | 🔴 高 | 多阶段+场地互动 |
| B3. 房间类型扩展 | 🟡 中 | 事件房/挑战房/隐藏房 |
| B4. 角色差异化强化 | 🟡 中 | 每个角色独特机制 |
| B5. 每日挑战模式 | 🟢 低 | 固定种子+排行榜 |

### Phase C: 内容扩展（3-4周）

**目标**: 增加可重玩性

| 任务 | 优先级 | 产出 |
|------|--------|------|
| C1. 新敌人×5（自爆者/召唤师/石像鬼/法师/亲王） | 🔴 高 | 已有场景，需调数值 |
| C2. 新武器×3（火焰喷射器/苦无/血爆） | 🟡 中 | 新机制 |
| C3. 新角色×3（刺客/法师/骑士） | 🟡 中 | 差异化 Build |
| C4. 多层地下城 | 🟡 中 | 每10房一层 |
| C5. 多 Boss（每层一个） | 🟢 低 | 最终 Boss 吸血鬼女王 |

### Phase D: 美术与音频（并行进行）

**目标**: 用 ComfyUI 建立可复用的美术生产管线

| 任务 | 优先级 | 产出 |
|------|--------|------|
| D1. 建立 ComfyUI 像素精灵工作流 | 🔴 高 | 标准化出图流程 |
| D2. 玩家角色动画（4方向×4动作） | 🔴 高 | 16 组精灵表 |
| D3. 敌人动画（11种×3-4动作） | 🔴 高 | 40+ 组精灵表 |
| D4. Boss 动画（6阶段） | 🟡 中 | 完整 Boss 表现 |
| D5. UI/图标/特效补全 | 🟡 中 | 统一视觉风格 |
| D6. 音频优化 | 🟢 低 | 已较完整，微调 |

### Phase E: 发布准备（1-2周）

| 任务 | 优先级 | 产出 |
|------|--------|------|
| E1. 本地化（中/英） | 🟡 中 | 国际化架构 |
| E2. 手柄支持 | 🟡 中 | 输入映射 |
| E3. 性能优化 | 🟡 中 | 大量敌人场景 |
| E4. Steam 集成（可选） | 🟢 低 | 成就/云存档 |

---

## 四、数值重构详细方案

### 4.1 敌人 HP 公式（替换固定值）

```gdscript
# 旧方案: 固定 HP（蝙蝠16.5, 吸血鬼33, 僵尸132...）
# 新方案: 基础 HP × 波次系数

const ENEMY_BASE_HP: Dictionary = {
    "bat": 12.0,
    "vampire": 25.0,
    "zombie": 80.0,
    "werewolf": 60.0,
    "skeleton_archer": 20.0,
    # ...
}

func get_scaled_hp(base_hp: float, wave: int) -> float:
    # 波次 1-10: 线性增长 (1.0 → 2.0)
    # 波次 11-20: 加速增长 (2.0 → 4.0)
    # 波次 21+: 指数增长
    var multiplier: float
    if wave <= 10:
        multiplier = 1.0 + (wave - 1) * 0.1
    elif wave <= 20:
        multiplier = 2.0 + (wave - 10) * 0.2
    else:
        multiplier = 4.0 * pow(1.1, wave - 20)
    return base_hp * multiplier
```

### 4.2 玩家 DPS 控制

```gdscript
# 旧方案: 每级 +20% 伤害，进化 ×2.5-3.0
# 新方案: 每级 +15% 伤害，进化 ×1.8-2.2，多武器收益递减

func get_scaled_damage() -> float:
    var level_mult = 1.0 + (current_level - 1) * 0.15
    var evolution_mult = 1.0
    if is_evolved:
        evolution_mult = 1.8  # 降低进化倍率
    return base_damage * level_mult * evolution_mult

# 多武器 DPS 递减: 第N个武器伤害 × (0.9^(N-1))
func get_weapon_damage_multiplier(weapon_index: int) -> float:
    return pow(0.9, weapon_index)
```

### 4.3 护甲改为百分比减伤

```gdscript
# 旧方案: actual_damage = maxf(amount - armor, 1.0)
# 新方案: 百分比减伤，上限 75%

func calculate_damage_reduction(armor: float) -> float:
    # armor / (armor + 100) → 100护甲=50%减伤，200护甲=66.7%，上限75%
    return minf(armor / (armor + 100.0), 0.75)

func take_damage(amount: float) -> void:
    var reduction = calculate_damage_reduction(armor)
    var actual_damage = amount * (1.0 - reduction)
    # ...
```

### 4.4 经验曲线重构

```gdscript
# 旧方案: 16 + (level-1)*8 → 线性，后期升级过快
# 新方案: 20 + (level-1)*12 + pow(level-1, 1.5) → 前期快后期慢

func get_xp_required(level: int) -> int:
    return 20 + (level - 1) * 12 + int(pow(level - 1, 1.5))
```

### 4.5 被动收益递减

```gdscript
# 旧方案: 线性叠加（闪避5%+3%×4=17%）
# 新方案: 递减叠加（第N级收益 × 0.8^(N-1)）

func get_scaled_value() -> float:
    var total = base_value
    for i in range(1, current_level):
        total += value_per_level * pow(0.8, i - 1)
    return total

# 闪避示例: 5% + 3% + 2.4% + 1.92% + 1.54% = ~13.9%（而非17%）
```

---

## 五、ComfyUI 美术生产管线

### 5.1 工作流选择

| 用途 | 推荐工作流 | 原因 |
|------|-----------|------|
| 角色/敌人精灵 | `图片_Qwen-Image2.1_文生图.json` | 质量高，可控性强 |
| 角色多朝向 | `图片_角色四视图出图.json` | 锁人设，一次出4图 |
| 快速原型 | `图片_Z-ImageTurbo_int8出图.json` | 8步快出 |
| 风格化调整 | `动漫_Anima出图.json` | 挂 turbo LoRA |

### 5.2 标准 Prompt 模板

```
# 角色精灵（正面）
pixel art, 32x32 sprite, [character_name], dark gothic style,
[color_scheme], transparent background, 2px black outline,
limited color palette 32 colors, front view, idle pose,
vampire hunter theme, detailed pixel shading

# 动画帧（跑步）
pixel art, 32x32 sprite, [character_name], running pose,
legs in motion, [frame_description], transparent background,
consistent character design, same color palette as reference
```

### 5.3 后处理流程

```
ComfyUI 生成 1024x1024
    ↓
Python PIL 下采样到 32x32/64x64
    ↓
调色板限制（32-64色）
    ↓
黑色描边强化（2px）
    ↓
拼合为精灵表（4帧/6帧/8帧）
    ↓
导入 Godot → TextureManager 加载
```

---

## 六、风险与缓解

| 风险 | 概率 | 缓解措施 |
|------|------|---------|
| 数值重构破坏现有存档 | 中 | 存档版本号+迁移逻辑 |
| ComfyUI 出图风格不统一 | 高 | 固定 seed + 参考图锁定 |
| 动画帧数不足 | 中 | 优先 4 帧，后续补 6/8 帧 |
| 多武器递减机制玩家反感 | 低 | 用 UI 明确显示递减比例 |

---

## 七、验收标准

### Phase A 验收
- [ ] 所有数值从 `game_config.gd` 读取
- [ ] 波次 1 玩家能在 30 秒内清场
- [ ] 波次 20 玩家仍可能死亡
- [ ] Boss 战时长 60-120 秒

### Phase B 验收
- [ ] 至少 3 种武器进化路径
- [ ] Boss 有 3 个可识别阶段
- [ ] 2 个角色体验明显不同

### Phase C 验收
- [ ] 总敌人类型 ≥ 15 种
- [ ] 总武器类型 ≥ 12 种
- [ ] 单局时长 15-25 分钟

### Phase D 验收
- [ ] 所有角色有 4 方向待机动画
- [ ] 所有敌人有移动+攻击动画
- [ ] UI 风格统一，无占位符

---

*本文档将随开发进度持续更新*
