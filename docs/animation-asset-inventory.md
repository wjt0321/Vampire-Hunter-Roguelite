# 动态帧与动画资产清单

> 最后更新：2026-11-14
>
> 用途：记录现有动画覆盖、缺失动作、序列帧规格、代码使用位置、制作优先级与验收状态，作为后续动画迭代的任务台账。
>
> 2026-11-13 批次新增血铠领主 12 张专属透明横条（72 帧）；2026-11-14 批次新增织血母皇 8 张专属透明横条（48 帧）、墓穴守望者 6 张（36 帧）、炼金亲王 10 张（60 帧）与月蚀女王 6 张（36 帧），五批均完成状态接线、回归与真实房间录制，五名 Boss 专属动作全部完成。制作方法与验收证据见第十二至十六节。

## 一、文档分工与状态口径

- `asset-status.md`：静态美术的完成记录、来源、尺寸依据、历史验收和回退方式。
- 本文：动态帧覆盖、待补动作、动画接线、制作优先级和动画验收。两份文档对动画状态的描述冲突时，以本文为准。
- `reference-deconstruction.md`：未来玩法与 Boss 行为目标；其中规划不等于资产已经存在。
- `asset-licenses.md`：后续引入外部素材时同步登记授权；沿用现有自制资产不需要新增来源记录。

| 状态 | 含义 |
|---|---|
| 现有 / 已接线 | 文件存在，尺寸已核对，并找到实际代码使用位置；不代表本轮已完成游戏内视觉复验 |
| 仅注册 | 已在 `TextureManager` 登记，但本轮未查见直接播放或场景使用调用 |
| 待补 | 需要制作的序列帧或动作；当前没有对应成品文件 |
| 保留单帧 | 已有单帧配合 Tween、旋转、粒子或透明度过渡已足够，不进入序列帧制作队列 |
| 待验收 | 文件或接线已具备，但还要完成播放、节奏、遮挡和状态切换检查 |

优先级：**P0 = Boss 差异化必需；P1 = 高频战斗与常驻场景收益明显；P2 = 精修与低频演出。** 优先级不是当前完成状态。

## 二、当前资产快照

截至 2026-11-14 实际扫描到 **351 张 PNG**。下表是文件数量，不把音频、导入缓存、备份目录或设计文档计入。

| 目录 | PNG 数 | 动画管理口径 |
|---|---:|---|
| `assets/sprites/` | 144 | 全部为多帧横向精灵表；本文逐项登记 |
| `assets/effects/` | 34 | 11 条序列帧 + 23 张保留单帧 |
| `assets/ui/` | 74 | 图标、面板、按钮和徽章原则上不做序列帧；商人另列环境动画 |
| `assets/weapons/` | 51 | 武器图标与弹道贴图以旋转、拖尾、Tween 为主 |
| `assets/tiles/` | 31 | 墙体与地面保持静态；火把、营火、宝箱另列 |
| `assets/items/` | 12 | 掉落物以静态图和程序动效为主；受诅宝箱另列 |
| `assets/backgrounds/` | 5 | 整图背景保持静态，不把镜头运动误记为序列帧 |

`assets/sprites/` 的 144 张拆开看：敌人 84（23 个敌人目录）、Boss 48（6 名 Boss 目录）、玩家 12（2 角色 × 6 动作）。

### 已有精灵表的真实构成

| 分组 | 精灵表数 | 当前规格 |
|---|---:|---|
| 通用猎人 + 牧师塞西莉亚 | 12 | 每角色 6 动作；56×56 单格，2/4/6 帧 |
| 普通与特殊敌人 | 20 | 11 个敌人条目；56×56 单格，2/4/6 帧 |
| 旧共用 Boss | 6 | 128×128 单格，每张 4 帧；保留为未替换 Boss 的占位 |
| 血铠领主专属 | 12 | 128×128 单格，每张 6 帧；含持盾/无盾动作变体 |
| 织血母皇专属 | 8 | 128×128 单格，每张 6 帧；idle/move/lay_egg/summon/web_cast/melee/phase_change/death |
| 墓穴守望者专属 | 6 | 128×128 单格，每张 6 帧；idle/move/lantern_sweep/revive/ward_break/death |
| 炼金亲王专属 | 10 | 128×128 单格，每张 6 帧；亲王 idle/move/cast/solo_shift/death，巨像 idle/move/slam/enrage/death |
| 月蚀女王专属 | 6 | 128×128 单格，每张 6 帧；idle/move/blink/appear/phase_change/death |

通用播放器 `scripts/core/sprite_sheet.gd` 按**正方形单格、横向紧排**切帧，基础循环帧率为 **8 fps**。血铠领主的攻击、冲锋、转段和死亡按战斗计时单独映射帧，不套用统一循环。因此不能把已有的 4/6 帧角色表误记为静态图。

旧 `asset-status.md` 曾把 `werewolf_charge.png` 写为 6 帧；实际文件为 **224×56，即 4 帧**，本文按实际文件登记。

## 三、玩家动画：基础动作完整，不重复列为缺图

通用猎人与牧师各有一套同规格文件。下表的 `{player,priestess}` 表示两个前缀各有一张实际文件。

| 动作 | 文件 | 实际规格 | 当前使用位置 | 后续动作 | 状态 |
|---|---|---|---|---|---|
| 待机 | `{player,priestess}_idle.png` | 224×56 / 4 帧 | `player.gd` 常驻 idle，8 fps 循环 | 保留现有表 | 现有 / 已接线 |
| 移动 | `{player,priestess}_run.png` | 336×56 / 6 帧 | `_sync_player_pose()` 切换 run | 保留现有表 | 现有 / 已接线 |
| 攻击 | `{player,priestess}_attack.png` | 224×56 / 4 帧 | `_play_one_shot("attack")`，结束回 idle/run | 不为每把武器另画全身攻击；武器差异交给弹道与特效 | 现有 / 已接线 |
| 受击 | `{player,priestess}_hurt.png` | 112×56 / 2 帧 | `_play_one_shot("hurt")` | P2 可选扩为 4 帧；当前不是功能缺项 | 现有 / 已接线 |
| 死亡 | `{player,priestess}_death.png` | 336×56 / 6 帧 | `_die()` 停止常规逻辑后手动逐帧推进 | 保留现有表 | 现有 / 已接线 |
| 护盾 | `{player,priestess}_shield.png` | 224×56 / 4 帧 | 获得护盾时播放一次性动作 | 只有出现持续护盾姿态需求时才另加 `shield_loop`，不覆盖现有触发动作 | 现有 / 已接线 |

玩家基础六动作不进入 P0/P1 补帧队列。后续验收重点是动作切换、朝向翻转、攻击判定与画面接触帧是否一致，而不是盲目增加帧数。

## 四、普通与特殊敌人：主要缺口在移动、受击和死亡

所有现有文件均位于 `assets/sprites/enemies/`。当前 `enemy_base.gd` 已支持 loop、once、hold 三种播放方式；表中“待补”表示还要制作文件并在对应敌人的状态点接线。

> **本表已于 2026-11-14 更新。** 第十九节（旧 MVP 资产「动起来」）、第二十节
> （迭代新增敌人动作条）、第二十一节（受击条接线）三轮补完后，下面 11 个旧敌人的
> 待机、死亡与核心动作条都已到位，帧数按实际文件登记。
> `hurt` 的**请求点已由第二十一节接上**（挨打会播专属受击条），
> 但这 11 个旧敌人自己的 `hurt.png` 还没做——没有文件时静默跳过，表现与从前一致。

| 敌人 / 前缀 | 现有精灵表与实际帧数 | 当前动作覆盖 | 剩余缺口 | 优先级 |
|---|---|---|---|---|
| 吸血鬼 `vampire` | `idle` 4、`run` 6、`death` 6 | 待机、移动循环、真倒地 | `hurt` 2–4 帧（图未做）；近战 `attack` 4 帧为 P2 | P2 |
| 狼人 `werewolf` | `idle` 4、`charge` 6、`death` 6 | 待机、冲锋一次性动作、真倒地 | `run` 6 帧（移动仍播 idle）、`hurt` 2–4 | P2 |
| 蝙蝠 `bat` | `idle` 4、`fly` 6、`death` 6 | 待机、飞行循环、真倒地 | `hurt` 2 帧为 P2，避免高频受击闪烁过度 | P2 |
| 僵尸 `zombie` | `idle` 4、`walk` 6、`death` 6 | 待机、移动循环、真倒地 | `hurt` 2–4 帧；近战 `attack` 4 帧为 P2 | P2 |
| 骷髅弓手 `skeleton` | `idle` 4、`shoot` 6、`death` 6 | 待机、射箭一次性动作、真倒地 | `hurt` 2–4 帧；射击接触帧需对齐箭矢生成点 | P2 |
| 爆裂者 `exploder` | `idle` 4、`walk` 6、`explode` 6、`death` 6 | 待机、移动、爆炸蓄势/触发、真倒地 | `hurt` 2 帧为 P2 | P2 |
| 石像鬼 `gargoyle` | `idle` 4、`petrify` 6、`wake` 6、`death` 6 | 待机、石化保持、苏醒一次性动作、真倒地 | `hurt` 2 帧；无需为静止守卫硬加跑步 | P2 |
| 吸血鬼法师 `vampire_mage` | `idle` 4、`cast` 6、`teleport` 6、`death` 6 | 待机、施法、瞬移一次性动作、真倒地 | `hurt` 2–4 帧；移动表为 P2 | P2 |
| 召唤师 `summoner` | `idle` 4、`cast` 6、`death` 6 | 待机、施法一次性动作、真倒地 | `walk` 6 帧、`hurt` 2–4 帧 | P2 |
| 血族亲王敌人 `vampire_prince` | `idle` 4、`dash` 6、`rage` 6、`death` 6 | 待机、冲刺、狂暴循环、真倒地 | `run` 6、`hurt` 2–4 帧；近战 `attack` 4–6 为 P2 | P2 |
| 精英吸血鬼 `elite_vampire` | `idle` 4、`death` 6 | 待机兼移动、真倒地 | `run` 6、`attack` 4–6、`hurt` 2–4 帧 | P2 |

补充边界：`prince_idle/dash/rage.png` 属于当前特殊敌人组，不等同于楼层 Boss「血族亲王」已经拥有独立资产。新 Boss 的动作表按下节单独制作。

> `hurt` 自 2026-11-14 起不再是死数据：`enemy_base.take_damage()` 会请求受击条。
> 上表 11 个旧敌人的 `hurt.png` 尚未制作，缺文件时静默跳过。
> 把图放进 `assets/sprites/enemies/<enemy>/hurt.png` 即自动生效，不需要再改代码。

### 迭代新增 12 敌人：2026-11-14 补完专属动作条

这批敌人的「辨识度在行为上」，没有专属动作条就看不出它们在干什么。
第二十节给每个补了一条行为动作条：

| 敌人 / 前缀 | 专属动作条 | 帧数 | 行为语义 |
|---|---|---|---|
| 盾卫 `shield_guard` | `guard` | 6 | 举盾格挡（正面受击时播） |
| 血猎犬 `blood_hound` | `pounce` | 6 | 蓄力扑击 |
| 血祭司 `blood_priest` | `cast` | 6 | 抬手治疗 |
| 织网者 `web_weaver` | `cast` | 6 | 吐网 |
| 潜伏者 `burrower` | `burrow` | 6 | 钻回地下 |
| 吞晶虫 `gem_leech` | `steal` | 6 | 吞下宝石 |
| 棺卫 `coffin_guard` | `revive` | 6 | 从棺材爬起 |
| 摄魂灯鬼 `lantern_wraith` | `beam` | 6 | 提灯放光束 |
| 炼金投手 `alchemist_pitcher` | `throw` | 6 | 投掷药瓶 |
| 炉心傀儡 `furnace_golem` | `charge` | 6 | 外甲碎裂后冲锋 |
| 共振术士 `resonance_mage` | `cast` | 6 | 伸手连线 |
| 月翼兽 `moon_wing` | `dive` | 6 | 收翼俯冲 |
| 血铠幼虫 `blood_larva` | `idle` 4、`pounce` 6、`death` 6 | — | 全套专属资产，替换借蝙蝠染色的占位图 |

这些动作条都只在**行为触发点**播一次（`mode = "once"`），播完回待机条，
不常驻循环。接线细节与踩坑见第二十节。

2026-11-14 追加：这 13 个敌人（含血铠幼虫）各补了一条 `hurt` 受击条 6 帧，
并在 `enemy_base` 接上了受击请求点，见第二十一节。

### 敌人首批制作顺序

1. 先补高频近战与远程单位的 `death`：吸血鬼、僵尸、蝙蝠、骷髅弓手，验证死亡不再只有缩小、渐隐和通用粒子。
2. 再补明显缺少移动表现的动作：狼人 `run`、召唤师 `idle/walk`、法师 `idle`、精英吸血鬼 `run`。
3. 受击表统一最后接入，避免 2 帧受击动作与高频率白闪、击退叠加后反而看不清敌人。
4. 石像鬼和低频特殊攻击放到 P2，不为了凑数量给每个敌人制作整套相同动作。

## 五、Boss 动画：旧共用表退出正式阵容

### 当前共用资产

| 文件 | 实际规格 | 当前使用位置 | 处置 |
|---|---|---|---|
| `boss_idle.png` | 512×128 / 4 帧 | 旧 Boss 默认循环 | 保留至新 Boss 接线完成，之后退出正式阵容 |
| `boss_enraged.png` | 512×128 / 4 帧 | 旧 NORMAL → ENRAGED / DESPERATE | 不再供三名旧 Boss 共用 |
| `boss_attack1.png` | 512×128 / 4 帧 | 旧弹幕攻击 | 由各自专属攻击动作替换 |
| `boss_attack2.png` | 512×128 / 4 帧 | 旧召唤攻击 | 由各自专属攻击动作替换 |
| `boss_attack3.png` | 512×128 / 4 帧 | 旧新星/冲刺相关攻击 | 由各自专属攻击动作替换 |
| `boss_death.png` | 512×128 / 4 帧 | 旧 Boss 死亡 hold + 渐隐 | 每个 Boss 使用独立死亡表 |

这 6 张不是“没有动画”，而是**只有一套动画供三名 Boss 共用**。继续给它们换色或增加弹幕数量不算完成 Boss 差异化。

### 五名 Boss 的独立动作目标

新资产建议按 `assets/sprites/boss/<boss_id>/` 分目录管理，单格维持 **128×128**。基础循环 4–6 帧，关键攻击与转段 6–8 帧，死亡 6–8 帧；下表分别列出现有成品和仍待制作的目标。

| Boss / 目录 | 来源 | 首批必需动作表 | 帧数与演出约束 | 状态 |
|---|---|---|---|---|
| 血铠领主 `blood_lord` | 专属铁灰铠甲、暗红披风剑盾造型 | `idle`、`move`、`guard`、`sword_combo`、`charge`、`shield_break`、`stunned`、`enraged`、`death`，以及 `broken_move`、`broken_sword_combo`、`guarded_stunned` | 12 张均为 768×128 / 6 帧；伤害时间维持 0.22 / 0.28 秒，死亡 0.60 秒后回收 | P0 / 已完成（2026-11-13） |
| 织血母皇 `blood_matriarch` | 新增 | `idle`、`move`、`lay_egg`、`summon`、`web_cast`、`melee`、`phase_change`、`death` | 8 张均为 768×128 / 6 帧；卵巢生成、幼虫召唤与网区出现的接触帧已对齐逻辑 | P0 / 已完成（2026-11-14） |
| 墓穴守望者 `tomb_warden` | 新增 | `idle`、`move`、`lantern_sweep`、`revive`、`ward_break`、`death` | 6 张均为 768×128 / 6 帧；提灯朝向与扫射预警同向已对齐逻辑 | P0 / 已完成（2026-11-14） |
| 炼金亲王 `alchemist_prince` | 旧血族亲王重做 | 亲王 `idle/move/cast/solo_shift/death`；巨像 `idle/move/slam/enrage/death` | 10 张均为 768×128 / 6 帧；两单位分别管理，任一方死亡不带走另一方动作；death 条带 0.6s 播完自回收 | P0 / 已完成（2026-11-14） |
| 月蚀女王 `eclipse_queen` | 旧血族女王重做 | `idle`、`move`、`blink`、`appear`、`phase_change`、`death` | 6 张均为 768×128 / 6 帧；blink/appear 原地碎散与聚合互逆，转段行经补丁更正帧，死亡演出自回收 | P0 / 已完成（2026-11-14） |

制作顺序与玩法垂直切片一致：先血铠领主、织血母皇，再墓穴守望者、炼金亲王、月蚀女王。五套已全部完成，旧共用表仅保留为缺图降级时的显式占位。

## 六、特效：只给有明确收益的贴图补序列帧

> **本节已于 2026-11-14 更新。** 第十九节一轮把下表 11 条全部补齐并接线，
> 原单帧作为缺图降级保留。播放走 `vfx_manager.spawn_sheet_fx()`，
> 显式给帧数与单格尺寸（矩形单格不能用「宽 ÷ 高 = 帧数」推断）。

### 6.1 补帧候选（已全部完成）

| 当前文件 | 当前尺寸与使用位置 | 序列帧规格 | 状态 |
|---|---|---|---|
| `hit_effect.png` | 1024×1024 | 4 帧×64×64，一次性 | ✅ 已完成（`hit_effect_sheet.png`） |
| `death_explosion.png` | 1024×1024；以 `explosion` 播放 | 6 帧×128×128，一次性 | ✅ 已完成（`death_explosion_sheet.png`） |
| `portal.png` | 96×96 | 6 帧×96×96，循环 | ✅ 已完成（`portal_sheet.png`） |
| `shield_break.png` | 64×64 | 6 帧×64×64，一次性 | ✅ 已完成（`shield_break_sheet.png`） |
| `poison_spread.png` | 128×128 | 6 帧×128×128，慢速循环 | ✅ 已完成（`poison_spread_sheet.png`） |
| `levelup_aura.png` | 128×128 | 6 帧×128×128，一次性 | ✅ 已完成（`levelup_aura_sheet.png`） |
| `freeze_effect.png` | 48×48 | 6 帧×48×48，一次性 | ✅ 已完成（`freeze_effect_sheet.png`） |
| `petrify_effect.png` | 48×48 | 6 帧×48×48，一次性 | ✅ 已完成（`petrify_effect_sheet.png`） |
| `holy_light.png` | 128×128 | 6 帧×128×128，一次性 | ✅ 已完成（`holy_light_sheet.png`） |
| `chain_lightning.png` | 256×256 | 4 帧×128×128，一次性 | ✅ 已完成（`chain_lightning_sheet.png`） |
| `thunder_wrath.png` | 256×256 | 6 帧×128×128，一次性 | ✅ 已完成（`thunder_wrath_sheet.png`） |

登记与接线见 `scripts/core/asset_slots.gd` 的 `EFFECT_SHEETS`
与 `scripts/managers/vfx_manager.gd` 的 `spawn_sheet_fx()`。

### 6.2 明确保留单帧

这些资产不因为“缺少动态帧”而自动进入制作队列。

| 文件 | 当前用途 | 保留原因 | 状态 |
|---|---|---|---|
| `achievement_unlock.png` | 成就解锁金环 | 低频短促，缩放/淡出足够 | 保留单帧 |
| `boss_warning.png` | Boss 登场警告 | 已有扩散与程序圆环，优先保证预警清楚 | 保留单帧 |
| `btn_click.png` | UI 点击涟漪 | UI 动效已由 `UiFx` 负责 | 保留单帧 |
| `crit_text.png` | 仅注册，未查见直接播放调用 | 暴击文字不需要序列帧；后续先确认是否使用 | 保留单帧 |
| `dodge_afterimage.png` | 闪避残影 | 残影靠透明度和位移，不应变成第二套角色动画 | 保留单帧 |
| `knife_spin.png` | 仅注册，未查见直接播放调用 | 小刀适合旋转与拖尾 | 保留单帧 |
| `knife_tornado.png` | 刀阵旋风成型并旋转 | 旋转比逐帧重画更稳定 | 保留单帧 |
| `lightning_retaliate.png` | 闪电护符反击 | 瞬时闪光，现有 Tween 足够 | 保留单帧 |
| `lifesteal.png` | 仅注册，未查见直接播放调用 | 先确认汲取路径是否需要程序化连线，不补孤立序列帧 | 保留单帧 |
| `magic_trail.png` | 24×8；仅注册，未查见直接播放调用 | 拖尾应由运动路径驱动，不适合固定横条动画 | 保留单帧 |
| `wave_start.png` | 波次横幅底光 | UI 横幅已有透明度过渡 | 保留单帧 |
| `xp_collect.png` | 经验拾取 | 高频短促，控制粒子与性能比补帧更重要 | 保留单帧 |

## 七、环境、交互物与静态资产

### 7.1 环境动态候选（已全部完成）

> 第十九节一轮把这 5 条全部补齐并接线。

| 资产 | 序列帧规格 | 状态 |
|---|---|---|
| `tiles/props/torch.png` | 4 帧×24×48，循环；火盆根部固定，只让火焰变化 | ✅ `torch_sheet.png` |
| `tiles/props/campfire.png` | 4 帧×40×48，循环 | ✅ `campfire_sheet.png` |
| `tiles/props/chest.png` | 6 帧×48×40 开箱表，末帧保持打开 | ✅ `chest_sheet.png` |
| `items/cursed_chest.png` | 6 帧×48×40，开箱序列播完再闪光淡出 | ✅ `cursed_chest_sheet.png` |
| `ui/merchant.png` | 4 帧×128×128 待机；不移动、不做无意义大幅度呼吸 | ✅ `merchant_sheet.png` |

**矩形单格的播放器已经写好**：`scripts/core/sprite_frames_lib.gd`（AtlasTexture +
AnimatedSprite2D，显式单格切帧）。火把 24×48、宝箱 48×40、商人 128×128 都不是正方形，
不能套「宽 ÷ 高 = 帧数」的推断规则。登记见 `asset_slots.gd` 的 `PROP_SHEETS`。

接线点：`game_room.gd` 的 `_make_prop_visual()` / `_make_effect_visual()`、
`cursed_chest.gd` 的开箱序列、`poison_cloud.gd` 的毒雾地面。

### 7.2 不进入补帧队列的资产

- UI 图标、成就徽章、武器/被动图标、按钮三态、面板、血条、槽位：继续使用静态图与 UI Tween。
- 普通墙体、柱子、地板、血迹、蛛网、床铺等静物：不为“全部会动”而制作动画。
- 经验宝石、银币、治疗/狂暴/磁力掉落物：保留静态图和拾取动效。
- 武器图标和小尺寸弹道：使用旋转、翻转、拖尾、命中粒子；只有实际玩法新增持续区域或复杂弹道时再登记序列帧。
- 整张房间背景：环境变化优先用独立机关、火焰、雾层或光照节点，不重画整张背景序列帧。

## 八、命名、制作与接线规范

### 文件与目录

- 玩家继续沿用 `assets/sprites/player/<character_id>_<action>.png`，现有自动扫描会登记六个既定动作；新增动作名仍需同步代码白名单。
- 普通敌人继续沿用 `assets/sprites/enemies/<enemy_id>_<action>.png`，不要把动作序号写进动作名。
- 新 Boss 使用独立子目录，不再新增 `boss_attack4`、`boss_prince_attack1` 这类继续依赖共用控制器的命名。
- 单帧特效升级为序列帧时先保存为 `<effect>_sheet.png`，防止未接线的横条被旧 Tween 当成一整张图放大。
- 横向精灵表内每格等宽、等高、无间隔、无额外说明文字；交付 PNG 使用透明背景。

### 画面与节奏

- 角色统一脚底锚点、视觉中心、朝向和描边；相邻帧不能无意义上下跳动。
- 待机 4 帧、移动 6 帧、受击 2–4 帧、死亡 6 帧是当前基础规格；特殊攻击按判定需要 4–8 帧，不为统一而凑帧。
- 通用角色播放器基础循环为 8 fps；血铠领主关键动作由状态计时驱动。需要不同动作帧率时，应把它作为动画数据与代码改造单独验收，不在图片里复制大量相同帧骗时长。
- 攻击动作至少区分预备、接触、收招；逻辑伤害帧、投射物生成帧与画面接触帧必须一致。
- 循环表首尾衔接自然；一次性表播完回 idle/run；死亡表按需求 hold 或渐隐，不被默认循环抢回。
- 新序列帧保持现有暗金红、成熟比例、清晰剪影和小尺寸可读性，不能只在原图大画布上验收。

### 台账更新流程

1. 制作前在本文对应表写明目标动作、帧数、优先级和状态，状态从“待补”改为“制作中”。
2. 文件落盘后更新真实尺寸与帧数，状态改为“待接线”；不要只凭文件名推断帧数。
3. 完成 `TextureManager`、角色控制器或 VFX 播放路径后改为“待验收”，记录实际触发点。
4. 通过下节检查后改为“已完成”，记录验收日期；发现回退时退回“待补”或“待接线”，不留虚假的 DONE。
5. 新增外部素材时同步 `asset-licenses.md`；自制或从现有成品派生时记录源文件，不写外部来源。

## 九、动画验收清单

### 文件检查

- 实际尺寸 = 单格宽 × 帧数、单格高；所有帧非空，透明通道正常，无品红抠底残留。
- 逐帧缩略图检查身份、服装、武器、锚点和剪影一致；没有意外重复帧、跳帧或末帧闪回。
- 以游戏真实显示尺寸检查，不以 1024 原图细节代替 56/128 世界像素下的可读性。

### 播放与玩法检查

- idle/run/attack/hurt/shield/death 等状态切换正确，暂停时动画与伤害逻辑一起暂停。
- 一次性动作不会永久卡住，也不会在高频触发时不断重置到第 0 帧。
- 敌人死亡、Boss 转段、召唤物生成、双子之一死亡、换房和重开时，无旧动画、计时器或危险区域残留。
- 动画时长不改变实际无敌帧、伤害窗口和预警时长；若需要调整，先改玩法数据再配动画。
- 大量敌人同时死亡或触发特效时，敌方危险预警仍位于视觉优先级最高层。

### 本轮验收状态

- **文件与尺寸盘点：已完成。** 256 张 PNG、80 张角色/Boss 精灵表和 23 张特效均按实际文件登记。
- **代码路径盘点：已完成。** 玩家、敌人、旧 Boss、贴图特效、传送门与环境道具均核对了主要使用位置。
- **新增补帧：血铠领主、织血母皇、墓穴守望者、炼金亲王、月蚀女王已落盘。** 血铠领主 12 张透明横条、72 帧（2026-11-13）；织血母皇 8 张、48 帧（2026-11-14）；墓穴守望者 6 张、36 帧（2026-11-14）；炼金亲王 10 张、60 帧（亲王 5 张 + 巨像 5 张，2026-11-14）；月蚀女王 6 张、36 帧（2026-11-14）；P1/P2 缺口保持待补。
- **游戏内动画复验：已完成（2026-11-14）。** 织血母皇真实房间录像覆盖 8 种状态并含幼虫生成，墓穴守望者录像覆盖 6 种状态并含僵尸复苏生成，炼金亲王录像覆盖双单位 10 种状态，月蚀女王录像覆盖 6 种状态并含二阶段月相转段；十组回归 873 项通过、五层流程烟测 fail=0；过程与日志证据见第十二至十六节。

## 十、后续迭代入口

> **本节已于 2026-11-14 更新。** P0/P1-A/P1-B/P2 四批全部完成并接线，
> 下面是**接下来**真正剩下的缺口。

已完成的批次：

| 批次 | 内容 | 完成日期 |
|---|---|---|
| P0 | 血铠领主、织血母皇、墓穴守望者、炼金亲王、月蚀女王专属动作 | 2026-11-13 / 14 |
| P1-A | 旧敌人新风格立绘 + 11 死亡条 + 14 动作条；迭代 12 敌人专属动作条 | 2026-11-14 |
| P1-B | 11 条特效序列帧 | 2026-11-14 |
| P2 | 5 条低频进化特效 + 5 条道具序列帧 | 2026-11-14 |

接下来剩下的缺口：

1. ~~**敌人受击（hurt）状态——全缺。**~~ **已于 2026-11-14 第二十一节做完**：
   `enemy_base.take_damage()` 现在会请求受击条，13 个敌人（12 个迭代新增 + 血铠幼虫）
   各有一条 6 帧受击条。仍未做的是**旧 MVP 11 个敌人自己的 `hurt.png`**，
   缺文件时静默跳过，表现与从前一致。
2. **地面危险贴图。** 减速网、棺材、卵巢、药液、月蚀安全圈仍是半透明多边形和圆环，
   与敌人动作条的风格不统一（敌人已经是手绘像素风，地面还是程序几何）。
3. **旧敌人补跑动条。** 狼人、召唤师、精英吸血鬼移动时仍播待机条。
4. **零引用的四张特效图**（`crit_text` / `magic_trail` / `knife_spin` / `lifesteal`）：
   要用得先定「弹道改不改贴图」。

每批交付同时更新资产文件、代码触发点、本文状态和验收记录；只更新其中一项不算闭环。

## 十一、2026-11-13 玩法切片的占位图

这一轮先把行为做进游戏。下面这些还没有专属序列帧，代码借用现有精灵并染色，或者直接用色块和线条。正式图补上之后，替换对应调用，不要把占位当成完成。

> 2026-11-14 更新：下表中 12 种敌人的 idle/death 与 12 张武器/融合卡图标已经换成专属资产，详见第十七节；
> 各敌主的攻击动作表、地面危险贴图仍未做。

| 内容 | 现在用的替代 | 以后要换的正式资产 |
|------|----------------|--------------------|
| 盾卫 | 已换专属 idle + death（2026-11-14） | 盾卫推进动作 |
| 血祭司 | 已换专属 idle + death（2026-11-14） | 祭司治疗动作 |
| 织网者 | 已换专属 idle + death（2026-11-14） | 织网者移动 / 吐网 |
| 棺卫 | 已换专属 idle + death（2026-11-14） | 棺卫移动 / 复活 |
| 减速网、棺材、卵巢 | 纯色多边形 | 可破坏物件的单帧或短循环 |
| 血铠领主 | 已换专属 12 张动作表；缺图时才显式降级到旧图占位 | 正式文件与复现工具见第十二节 |
| 织血母皇 | 已换专属 8 张动作表；缺图时才显式降级到旧图占位 | 正式文件与复现工具见第十三节 |
| 墓穴守望者 | 已换专属 6 张动作表；缺图时才显式降级到旧图占位 | 正式文件与复现工具见第十四节 |
| 回旋镰、长鞭、霜环 | 三角色块、线段、圆环 | 弹道与挥击，不要求新的全身攻击 |
| 新武器 7 把与融合卡 5 张的图标 | 已换专属 48×48 图标（2026-11-14，共 12 张） | 无 |
| 连珠火铳、魂引灯、地刺、锁链枪 | 借用散弹、圣光、魔法书、弩的图标；弹道用现成子弹、三角色块和预警条 | 各自图标和弹道 |
| 血猎犬、潜伏者、吞晶虫、灯鬼、炼金投手、炉心巨像、共鸣术士、月翼兽 | 已换专属 idle + death（2026-11-14） | 各自的攻击动作表 |
| 炼金亲王 | 已换专属 10 张动作表（亲王 5 张 + 巨像 5 张）；缺图时才显式降级到旧图占位 | 正式文件与复现工具见第十五节 |
| 月蚀女王 | 已换专属 6 张动作表；缺图时才显式降级到旧图占位 | 正式文件与复现工具见第十六节 |
| 药液和月蚀安全圈 | 半透明多边形和圆环 | 地面危险的正式贴图 |

## 十二、2026-11-13 血铠领主切片收尾验收

### 交付范围与复核证据

- **范围：** 仅血铠领主完整垂直切片；另外四名 Boss 仍按前表待制作。
- **素材：** `assets/sprites/boss/blood_lord/` 下 12 张透明横条，共 72 帧；每张 768×128 RGBA、单格 128×128、6 帧。动作清单与生成配方见 `production.json`、`asset_manifest.json`。
- **实际房间预览：** `artifacts/blood_lord/blood_lord_preview.avi`，1280×720、30 fps、671 帧、22.37 秒。脚本动作演示 579 帧，覆盖 12 种状态，`failures=0`，墙撞眩晕断言通过；状态截图为同目录 `scene_*.png`。
- **自动回归：** `validation_results.json` 中六组结果均为 exit 0、issues 为空：血铠领主动画 122、楼层扩展 32、玩法切片 291、迭代包 40、精灵表 18、生命周期清理 13；合计 **516 项通过、0 项失败**。
- **端到端烟测：** `dungeon_smoke_five_floors.log` 完成五层真实流程，148 项通过、0 失败；真实 Boss 奖励只结算一次，最终胜利结算 UI 正常且终局提交一次。
- **日志与资源释放：** 最终录像和烟测日志未见 Godot `ERROR`、`WARNING`、对象泄漏或资源仍在使用记录。唯一环境诊断为 MbedTLS 跳过 6 张无法解析的 X509 证书，不影响上述运行。
- **手工画面检查：** 检查冲锋、持盾眩晕、破盾移动和死亡关键帧，确认人物姿态与状态一致；完整状态截图保留在 `artifacts/blood_lord/scene_*.png`。
- **授权边界：** AI 生成素材的商用、修改、署名及源文件分发权仍待按生成服务账号条款核实，详见 `docs/asset-licenses.md`；本次本地交付不代表已获发布授权。

### 复现与交付

- 回归入口：`python artifacts/blood_lord/run_checks.py`。
- 五层烟测入口：Godot 4.7.2 执行 `--headless --verbose --path . --script res://tools/run_dungeon_smoke.gd`。
- 最终预览由 Godot `--write-movie` 写出；录制后清理 BGM/SFX 播放流并等待混音缓冲，以确认退出时无音频资源泄漏。
- 完整交付 ZIP：`artifacts/blood_lord/blood_lord_delivery.zip`，包含本轮源码改动、12 张游戏内动作表、原始图集与修正版、制作/授权记录、回归结果、状态截图及最终 AVI。ZIP 清单在生成后逐项校验。

## 十三、2026-11-14 织血母皇切片收尾验收

### 交付范围与复核证据

- **范围：** 织血母皇完整玩法垂直切片（本体动作、召唤幼虫、产卵、铺网、转段、死亡演出）；幼虫 `blood_larva` 复用母皇动作表渲染；另外三名 Boss 仍按前表待制作。
- **素材：** `assets/sprites/boss/blood_matriarch/` 下 8 张透明横条（idle、move、lay_egg、summon、web_cast、melee、phase_change、death），共 48 帧；每张 768×128 RGBA、单格 128×128、6 帧。生成配方与资源 ID 见 `production.json`。
- **实际房间预览：** `artifacts/blood_matriarch/blood_matriarch_preview.avi`，30 fps、433 帧；脚本动作演示覆盖 8 种状态并确认幼虫生成（`preview_capture.json` 中 `larva_spawned=true`、`death_shown=true`、`phase_change_shown=true`、`failures=0`）；状态截图为同目录 `scene_*.png`。
- **自动回归：** `validation_results.json` 中七组结果均为 exit 0、issues 为空：织血母皇动画 55、血铠领主动画 122、楼层扩展 32、玩法切片 293、迭代包 40、精灵表 18、生命周期清理 13；合计 **573 项通过、0 项失败**。回归入口 `python artifacts/blood_matriarch/run_checks.py`。
- **端到端烟测：** `dungeon_smoke_five_floors.log` 完成五层真实流程，`RESULT dungeon_smoke fail=0`；第 5 层真实 Boss 奖励只结算一次，通关结算与成就解锁正常。
- **日志与资源释放：** 回归与烟测日志均未见 Godot `ERROR`、`WARNING`、对象泄漏或资源仍在使用记录；生命周期清理组确认贴图缓存退出时释放。
- **授权边界：** 8 张表为 AI 生成素材，登记为“AI 生成、待核实”，商用与分发条件依生成服务账号条款，详见 `docs/asset-licenses.md`；本次本地交付不代表已获发布授权。

### 复现与交付

- 回归入口：`python artifacts/blood_matriarch/run_checks.py`（织血母皇与血铠领主动画组自动附加 `-- --real-assets`）。
- 五层烟测入口：Godot 4.7.2 执行 `--headless --verbose --path . --script res://tools/run_dungeon_smoke.gd`。
- 完整交付 ZIP：`artifacts/blood_matriarch/blood_matriarch_delivery.zip`，包含本轮源码与场景改动、8 张游戏内动作表、原始图集与色键版、制作/授权记录、回归结果与日志、状态截图及最终 AVI；生成后经 `testzip()` 与关键路径断言校验。

## 十四、2026-11-14 墓穴守望者切片收尾验收

### 交付范围与复核证据

- **范围：** 墓穴守望者完整玩法垂直切片（提灯扫击、结界复苏、结界破碎、死亡演出）；另外两名 Boss 仍按前表待制作。
- **素材：** `assets/sprites/boss/tomb_warden/` 下 6 张透明横条（idle、move、lantern_sweep、revive、ward_break、death），共 36 帧；每张 768×128 RGBA、单格 128×128、6 帧。生成配方与资源 ID 见 `production.json`。
- **实际房间预览：** `artifacts/tomb_warden/tomb_warden_preview.avi`，30 fps、257 帧；脚本动作演示覆盖 6 种状态并确认僵尸复苏生成（`preview_capture.json` 中 `zombie_spawned=true`、`revive_shown=true`、`ward_break_shown=true`、`death_shown=true`、`failures=0`）；状态截图为同目录 `scene_*.png`。
- **自动回归：** `validation_results.json` 中八组结果均为 exit 0、issues 为空：墓穴守望者动画 65、织血母皇动画 55、血铠领主动画 122、楼层扩展 32、玩法切片 293、迭代包 40、精灵表 18、生命周期清理 13；合计 **638 项通过、0 项失败**。回归入口 `python artifacts/tomb_warden/run_checks.py`（墓穴守望者、织血母皇、血铠领主三组自动附加 `-- --real-assets`）。
- **端到端烟测：** `dungeon_smoke_five_floors.log` 完成五层真实流程，`RESULT dungeon_smoke fail=0`。
- **日志与资源释放：** 回归与烟测日志均落盘备查（每 case 一个 `.log`），未见 Godot `ERROR`、`WARNING`、对象泄漏或资源仍在使用记录。
- **授权边界：** 6 张表为 AI 生成素材，登记为“AI 生成、待核实”（原图集 node_id `463014719324531`），商用与分发条件依生成服务账号条款，详见 `docs/asset-licenses.md`；本次本地交付不代表已获发布授权。

### 本轮任务与审查结论

- `63a1400` 行为回归：扫击窗与方向锁定、复苏被结界门控、死亡连带清理，全部通过独立审查。
- `748a4b6` `_die` 自救：死亡演出从 main 清场中自救，通过独立审查。
- `f449833` 六张专属动作表：色键、切格、去碎片、最近邻归一化、脚底锚点，通过独立审查。
- `04bf00a` 动画状态机：6 状态映射、帧推进、扫击朝向锁定、死亡 0.6s 自回收、暂停冻结，通过独立审查。
- `81b0c76` 预览录像：257 帧 `failures=0`，通过独立审查。
- 本收尾批次：全量回归 638 项 0 失败、五层烟测 fail=0、台账与授权登记、交付 ZIP 校验。

### 复现与交付

- 回归入口：`python artifacts/tomb_warden/run_checks.py`。
- 五层烟测入口：Godot 4.7.2 执行 `--headless --verbose --path . --script res://tools/run_dungeon_smoke.gd`。
- 完整交付 ZIP：`artifacts/tomb_warden/tomb_warden_delivery.zip`，42 条目（本轮源码改动、6 张游戏内动作表与 `.import`、原始图集与色键版、制作/授权记录、回归结果与全部日志、状态截图与 `preview_capture.json`、最终 AVI），生成后经 `testzip()` 与关键路径断言校验。

## 十五、2026-11-14 炼金亲王切片收尾验收

### 交付范围与复核证据

- **范围：** 炼金亲王双单位完整玩法垂直切片（掷瓶与药液、巨像砸地、狂暴、巨像先倒后亲王 solo 转换、双单位死亡演出与自回收）；另外一名 Boss 仍按前表待制作。
- **素材：** `assets/sprites/boss/alchemist_prince/`（idle、move、cast、solo_shift、death）与 `assets/sprites/boss/alchemist_colossus/`（idle、move、slam、enrage、death）下共 10 张透明横条，共 60 帧；每张 768×128 RGBA、单格 128×128、6 帧。生成配方与资源 ID 见各自 `production.json`。
- **实际房间预览：** `artifacts/alchemist_prince/alchemist_prince_preview.avi`，30 fps、450 帧（15s；preview_capture.json 脚本计帧 357）；脚本动作演示覆盖双单位 10 种状态（`preview_capture.json` 中 `cast_shown=true`、`slam_shown=true`、`solo_shift_shown=true`、`prince_death_shown=true`、`colossus_death_shown=true`、`failures=0`）；状态截图为同目录 `scene_*.png`。
- **自动回归：** `validation_results.json` 中九组结果均为 exit 0、issues 为空：炼金亲王动画 122、墓穴守望者动画 65、织血母皇动画 55、血铠领主动画 122、楼层扩展 32、玩法切片 293、迭代包 40、精灵表 18、生命周期清理 13；合计 **760 项通过、0 项失败**。回归入口 `python artifacts/alchemist_prince/run_checks.py`（炼金亲王、墓穴守望者、织血母皇、血铠领主四组自动附加 `-- --real-assets`）。
- **端到端烟测：** `dungeon_smoke_five_floors.log` 完成五层真实流程，`RESULT dungeon_smoke fail=0`。
- **日志与资源释放：** 回归与烟测日志均落盘备查（每 case 一个 `.log`），未见 Godot `ERROR`、`WARNING`、对象泄漏或资源仍在使用记录。
- **授权边界：** 10 张表为 AI 生成素材，登记为“AI 生成、待核实”（亲王原图集 node_id `463027860746427`，巨像原图集 node_id `463035364217417`），商用与分发条件依生成服务账号条款，详见 `docs/asset-licenses.md`；本次本地交付不代表已获发布授权。

### 本轮任务与审查结论

- `27107ad` 行为回归：双单位行为与死亡清理契约（掷瓶冷却、砸地伤害窗、enrage 提速、巨像先倒自回收、亲王先倒留尸、双倒 boss_defeated），通过独立审查。
- `da51ea6` 双单位 `_die` 自救：死亡条带演出与 0.8s 内自回收，通过独立审查。
- `9e2c3d3` 十张专属动作表：色键、切格、去碎片、最近邻归一化、脚底锚点，通过独立审查。
- `318b0c0` 双单位动画状态机：10 状态映射、帧推进、表现层 0.6s 时钟、死亡 0.6s 自回收、暂停冻结，通过独立审查。
- `e08b2fe` 预览录像：AVI 450 帧 `failures=0`，通过独立审查。
- 本收尾批次：全量回归 760 项 0 失败、五层烟测 fail=0、台账与授权登记、交付 ZIP 校验。

### 复现与交付

- 回归入口：`python artifacts/alchemist_prince/run_checks.py`。
- 五层烟测入口：Godot 4.7.2 执行 `--headless --verbose --path . --script res://tools/run_dungeon_smoke.gd`。
- 完整交付 ZIP：`artifacts/alchemist_prince/alchemist_prince_delivery.zip`，64 条目（本轮源码改动、10 张游戏内动作表与 `.import`、两张原始图集与色键版、制作/授权记录、回归结果与全部日志、状态截图与 `preview_capture.json`、最终 AVI），生成后经 `testzip()` 与关键路径断言校验。

## 十六、2026-11-14 月蚀女王切片收尾验收

### 交付范围与复核证据

- **范围：** 月蚀女王完整玩法垂直切片（blink 换位、原地消散与凝聚、月相推进转段、死亡演出与自救回收）；五名 Boss 专属动作至此全部完成。
- **素材：** `assets/sprites/boss/eclipse_queen/` 下 6 张透明横条（idle、move、blink、appear、phase_change、death），共 36 帧；每张 768×128 RGBA、单格 128×128、6 帧。生成配方、再生与补丁记录见 `production.json`。
- **实际房间预览：** `artifacts/eclipse_queen/eclipse_queen_preview.avi`，30 fps、373 帧（12.4s；脚本计帧 280）脚本动作演示覆盖 6 种状态并确认二阶段月相转段（`preview_capture.json` 中 `appear_shown=true`、`blink_shown=true`、`phase_change_shown=true`、`death_shown=true`、`phase_two_reached=true`、`failures=0`）；状态截图为同目录 `scene_*.png`。
- **自动回归：** `validation_results.json` 中十组结果均为 exit 0、issues 为空：月蚀女王动画 113、炼金亲王动画 122、墓穴守望者动画 65、织血母皇动画 55、血铠领主动画 122、楼层扩展 32、玩法切片 293、迭代包 40、精灵表 18、生命周期清理 13；合计 **873 项通过、0 项失败**。回归入口 `python artifacts/eclipse_queen/run_checks.py`（五组动画测试自动附加 `-- --real-assets`）。
- **端到端烟测：** `dungeon_smoke_five_floors.log` 完成五层真实流程，`RESULT dungeon_smoke fail=0`。
- **日志与资源释放：** 回归与烟测日志均落盘备查（每 case 一个 `.log`），未见 Godot `ERROR`、`WARNING`、对象泄漏或资源仍在使用记录。
- **授权边界：** 6 张表为 AI 生成素材，登记为“AI 生成、待核实”（主图集 node_id `463056637256084`，phase_change 补丁 node_id `463052812194152`），商用与分发条件依生成服务账号条款，详见 `docs/asset-licenses.md`；本次本地交付不代表已获发布授权。

### 本轮任务与审查结论

- `2a630d2` 行为回归：闪烁月相与死亡清理契约，通过独立审查。
- `2bd8213` 月相 0 落点冷却断言补双侧上界（Task 1 审查 Should-Fix）。
- `5881d76` `_die` 自救：死亡演出从 main 清场中自救，通过独立审查。
- `7e07d86` 六张专属动作表：色键、切格、去碎片、最近邻归一化、脚底锚点，通过独立审查。
- `e807430` 动画状态机：6 状态映射、帧推进、appear/phase_change 表现层时钟、死亡自回收、暂停冻结，通过独立审查。
- `3d06cd0` 预览录像：280 帧 `failures=0`，通过独立审查。
- `6c9b09f` `production.json` 补授权口径字段（Task 3 审查 Should-Fix）。
- 本收尾批次：全量回归 873 项 0 失败、五层烟测 fail=0、台账与授权登记、交付 ZIP 校验。

### 复现与交付

- 回归入口：`python artifacts/eclipse_queen/run_checks.py`。
- 五层烟测入口：Godot 4.7.2 执行 `--headless --verbose --path . --script res://tools/run_dungeon_smoke.gd`。
- 完整交付 ZIP：`artifacts/eclipse_queen/eclipse_queen_delivery.zip`，49 条目（本轮源码改动、6 张游戏内动作表与 `.import`、采用版图集与色键版及转段补丁、制作/授权记录、回归结果与全部日志、状态截图与 `preview_capture.json`、最终 AVI），生成后经 `testzip()` 与关键路径断言校验。
## 十七、2026-11-14 迭代新增敌人与新武器图标专属资产

### 为什么做这一轮

新玩法切片（2026-11-13 玩法迭代）加了 12 种敌人、7 把新武器、5 张融合卡、3 个新被动，
但当时是「先做行为、图后面补」：这 12 种敌人在游戏里全部**借用 MVP 旧图再染色**
（texture_manager.gd 里注释写明「新敌人的专属序列帧还没到」），新武器图标也是借用
散弹/圣光/魔法书/弩的图。本轮把这些占位全部换成专属资产。

### 风格锚：MVP 已验收的那一套

风格基准不是新发明的，而是用户在 MVP 阶段明确认可过的那批源图：
E:\AI\ComfyUI\output\vhr_reskin\（36 张 1024×1024）。它的特征是
**正面前视、粗颗粒像素画、暗钢+旧金描边+深红宝石、品红抠底**。
本轮沿用同一套 ComfyUI 工作流、同一套抠底/量化/错帧脚本，只换画什么。

### 制作管线（复用 MVP 认可的管线，没有另起炉灶）

| 环节 | 做法 | 出处 |
|---|---|---|
| 出图 | 本机 ComfyUI + 图片_Qwen-Image2.1_文生图.json（立绘）/ 图片_Qwen-Image2.1_图像编辑.json（死亡姿态） | .workbuddy/comfy/reskin_pipeline.py |
| 死亡姿态 | 用立绘原图拼成 3×2 **品红底**网格当编辑源图，Edit 会把 6 格画成 6 个不同的倒地阶段；提示词逐格点名 | tools/gen_enemy_death_grid.py |
| 死亡帧序质检 | 量每格主体的"站高比"（本体连通域高/格高），必须大致单调下降，否则换种子重跑（最多 3 次） | tools/gen_enemy_death_grid.py judge() |
| 抠底 | 品红键控（阈值放宽到偏品红色相，保护角色自带的紫罗兰）+ 抗锯齿过渡带清理（紫边） | tools/death_repack.py / reskin_pipeline.purge_purple_edge |
| 缩格 | NEAREST 整数倍缩到 56×56 单格，脚底锚点固定 | reskin_pipeline.to_cell |
| 错帧 | 待机：下摆 1px 摆动；死亡：下沉 + 变暗 + 渐隐 | tools/build_pose_strips.py |
| 调色板 | 固定 32 色哥特色板（不按频次取色，避免一张偏暖一张偏冷） | .workbuddy/comfy/postprocess.py |

出图落盘统一在 E:\AI\ComfyUI\output\vhr_iter\，与 vhr_reskin / vhr_new / vhr_edit 同级。
网格类中间产物（3×2 姿态网格、死亡网格、特效网格）落在 E:\AI\ComfyUI\output\vhr_raw\ ——
2026-11-14 之前这几条管线没设输出子目录，几百张原图直接堆在 output 根目录，已归档并修好。

### 交付物

**敌人精灵（12 种 × 2 张 = 24 张横条）**

- 立绘 idle：224×56（4 帧），单格 56×56。
- 死亡 death：336×56（6 帧），单格 56×56，六帧是真的倒地过程，不是同一张尸体复制。
- 路径：assets/sprites/enemies/<enemy_id>/idle.png 与 .../death.png
  （走 asset_slots.gd 早就预留好的专属目录机制，文件一放进去就会被读到）。

| 敌人 | 中文名 | 状态 |
|---|---|---|
| shield_guard | 盾卫 | idle + death 已完成 |
| blood_priest | 血祭司 | idle + death 已完成 |
| web_weaver | 织网者 | idle + death 已完成 |
| coffin_guard | 棺卫 | idle + death 已完成 |
| blood_hound | 血猎犬 | idle + death 已完成 |
| furnace_golem | 炉心巨像 | idle + death 已完成 |
| burrower | 潜伏者 | idle + death 已完成 |
| gem_leech | 吞晶虫 | idle + death 已完成 |
| lantern_wraith | 灯鬼 | idle + death 已完成 |
| alchemist_pitcher | 炼金投手 | idle + death 已完成 |
| resonance_mage | 共鸣术士 | idle + death 已完成 |
| moon_wing | 月翼兽 | idle + death 已完成 |

**图标（15 张 48×48）**

- 新武器 7 张：assets/weapons/icons/{scythe,thorn_whip,frost_bell,repeater,soul_lantern,spike_tome,chain_gun}.png
- 融合卡 5 张：assets/weapons/icons/{thunder_bolt,miasma_shot,returning_blade,twin_chant,burning_blood}.png
- 新被动 3 张：assets/ui/passives/{execution_mark,time_gear,cold_blood}.png

图标走 ItemCatalog.get_icon_texture() 的专属目录优先分支，升级三选一 / 房间商店 /
元进度商店 / HUD 全部自动换成新图，不再借用别的武器的图标。

### 接线改动

| 文件 | 改动 |
|---|---|
| scripts/enemies/enemy_base.gd | 新增 use_dedicated_sprite()：专属目录有图就用它且不染色，没有才退回借用旧图并保留染色标记 |
| scripts/enemies/enemy_base.gd | _die() 优先播放专属死亡条（6 帧逐帧播完再淡出回收），没有死亡条才沿用原来的直接淡出 |
| scripts/enemies/<12 个敌人>.gd | use_placeholder_sprite(...) 改成 use_dedicated_sprite(...) |
| scripts/core/asset_slots.gd | 12 个敌人的状态表补上 death |

### 自动回归

| 组 | 断言 | 结果 |
|---|---|---|
| tools/enemy_death_strip_test.gd（新增） | 12 种敌人的死亡条都是 336×56 的 6 帧横条；死亡时切到专属条；帧会推进；播完才回收 | 60 / 60 通过 |
| tools/iteration_pack_test.gd | 12 种敌人专属图与死亡图已就位；没放进去的读不到；15 张新图标在 UI 统一入口都能取到 | 44 / 44 通过 |
| tools/sprite_sheet_test.gd | 精灵表播放口径 | 18 / 18 通过 |
| tools/verify_round4.gd | 既有玩法回归 | 全部通过 |

死亡演出截图（开发用工具 tools/enemy_death_shot.gd）：artifacts/iteration_assets/death_shot.png。

### 仍然没做的（边界）

1. **行走/攻击动作没有做**：这批只出了 idle 与 death。新敌人移动时播的是待机条
   （下摆 1px 摆动），近战扑击、施法、吐网、钻地这些专属动作仍是借用或程序表现。
2. **地面危险贴图没有做**：减速网、棺材、卵巢、药液、月蚀安全圈仍是半透明多边形和圆环。
3. **旧敌人的动作缺口没有动**：吸血鬼/狼人/僵尸等的 death、run、hurt 仍在第四节清单里待补。
4. 特效序列帧（P1-B）没有动。
5. 授权边界：全部为 AI 生成素材，登记为「AI 生成、待核实」，见 docs/asset-licenses.md。

### 复现

- 出图计划：artifacts/iteration_assets/plan_enemies.json、plan_icons.json
- 生成入口：python tools/gen_iteration_sprites.py --plan <plan>（立绘 + 图标）
- 死亡网格：python tools/gen_enemy_death_grid.py（后处理独立在 tools/death_repack.py，可只重跑后处理）
- 死亡演出回归：godot --headless --path . --script res://tools/enemy_death_strip_test.gd
- 死亡演出截图：godot --path . --script res://tools/enemy_death_shot.gd
- 审阅拼版：python tools/iteration_contact_sheet.py
### 踩坑记录：吞晶虫的死亡条三次都不合格（2026-11-14）

gem_leech 连续三次出图都被帧序质检判不合格，但目视那张图其实是**对的**：
宝石爆闪 → 倒地 → 碎裂 → 残骸，姿态完全对。

根因不在判据，也不在模型画得差，而在**提示词让模型画了地面**：
死亡语义里写着 "twisting flat and the crystal shell scraping the floor"、
"the rolled-out violet gem lying on the floor"，模型据此在**每一格**都铺了一片贴地的泥土。
泥土与角色连成一个连通域，"站高比"量到的永远是整个泥土+角色的总高，塌陷被完全抵消。

试过三种几何度量都无效（换连通域选取策略、忽略贴底行、只取密集像素行），
结果与原判据完全一致——因为泥地和角色在像素上就是连着的，纯几何分不开。

**修法在提示词，不在判据**：给该角色加专属约束 `EXTRA_RULES`，明令不许画地面泥土，
并把死亡语义从"在地上爬行"改写成"弓起 → 腿软前扑 → 砸落 → 壳碎 → 塌陷 → 残骸"。
换种子重出后一次通过（站高比 0.94 → 0.72 → 0.55 → 0.65 → 0.35 → 0.41，末格明显塌陷）。

教训：**质检指标测不出问题的时候，先怀疑被测量的东西是不是提示词自己引入的**。
几何判据没错，错在提示词让模型画了不该画的东西。
## 十八、2026-11-14 迭代新增内容专属音效与 BGM 重做

### 为什么做这一轮

图片批次完成后，迭代新增的内容在**听感上仍然是占位**：
12 种新敌人全部只复用通用 `hit_enemy` / `enemy_death`；
7 把新武器 + 5 张融合卡全部借用别的武器的音（连珠火铳/锁链枪→手枪，
回旋镰/长鞭→飞刀，霜环/魂引灯→圣光，地刺→魔法书）。
12 把武器共用 4 条音，玩家很快就会听出"这几把听起来一样"。

### 交付内容

| 类别 | 条数 | 内容 |
|---|---|---|
| 武器与融合卡发射音 | 12 | 7 把新武器各 1 条 + 5 张融合卡各 1 条 |
| 敌人受击音 | 12 | 12 种新敌人各 1 条，按材质区分（钢/血肉/甲壳/枯骨/热铁/土/水晶/空布/玻璃/奥术/毛/羽） |
| 敌人死亡音 | 12 | 12 种新敌人各 1 条，按各自死亡演出（甲片崩裂/烛火熄灭/丝囊破裂/棺板碎裂/炉火爆开/钻地/水晶碎/灯罩破/瓶碎/紫球爆/翼骨折） |
| 新被动触发音 | 3 | 处刑印记叠层、时滞齿轮上膛、寒血反应崩开 |
| BGM | 6 | 菜单/战斗/Boss/商店/胜利/失败，全部重做 |

新增 SFX 共 39 条，与既有 29 条共存，`assets/audio/generated/sfx/` 共 68 条；
6 首 BGM 全部替换为本轮新版本。

### 接入方式：映射表 + 显式回退

新增 `scripts/core/iteration_audio_map.gd` 作为唯一映射表：

- 敌人按 `_get_enemy_type()` 返回的 id 匹配 → 受击音与死亡音；
- 武器按 `weapon_id` 匹配 → 发射音；
- **融合卡按武器上的 `fusion_kind` 匹配**（不是 weapon_id）：
  融合卡不换主武器，主武器仍是 crossbow/shotgun 等，只是武器上多了一个 `fusion_kind`，
  按 weapon_id 匹配永远匹配不到；
- 3 个被动各有自己的触发点：处刑印记在叠层时、时滞齿轮在装备时、寒血反应在崩开时。

**表里没有就退回通用音**（`hit_enemy` / `enemy_death` / 原有武器映射），
所以旧敌人与旧武器完全不受影响。

### 自动回归

| 组 | 断言 | 结果 |
|---|---|---|
| tools/iteration_audio_test.gd（新增） | 12 种新敌人的受击/死亡都有专属键且键在目录中真实存在；专属音与通用音不是同一个文件；旧敌人仍走通用音；12 把武器与 5 张融合卡、3 个被动的键都能解码；映射表与键表无孤儿键 | 215 / 215 通过 |
| tools/iteration_audio_playback_test.gd（新增） | 端到端：真的建敌人、真的打死它、真的开一枪，抓 AudioManager 实际播放的流，确认播的是专属音而非通用音；旧敌人与旧武器仍走原来的音 | 11 / 11 通过 |
| tools/iteration_bgm_test.gd（新增） | 6 首 BGM 都是真实 OGG、时长足够、循环策略正确；循环曲播到结尾真的绕回开头并回到起始位置 | 34 / 34 通过 |
| tools/audio_assets_test.gd | 68 条 SFX 与 6 首 BGM 全部为真实 OGG、非空、循环策略正确 | 383 / 383 通过 |
| tools/iteration_pack_test.gd / tools/enemy_death_strip_test.gd / tools/verify_round4.gd | 既有玩法与资产回归未被音频改动波及 | 44 / 60 / 全通过 |

### 制作管线（沿用 2026-11-13 已跑通的那套）

| 环节 | 做法 | 出处 |
|---|---|---|
| SFX 出图 | 本机 ComfyUI + Stable Audio 3 Small SFX，3 秒源 | tools/render_iteration_audio.py |
| BGM 出图 | 本机 ComfyUI + YuE2（instrumental LoRA），60/20 秒源 | 同上 |
| 提示词 | 每条按主体单独写，不是按类别套模板 | tools/make_iteration_audio_manifest.py |
| 裁剪 | 找第一个真实瞬态（4ms RMS 阈值），不直接用原始前置静音 | tools/prepare_iteration_audio.py |
| 母带 | SFX 峰值归一到每条目标电平；BGM 归一到 -21 LUFS / -2 dBTP | 同上 |
| 循环 | 尾首线性交叠（战斗/Boss 0.65s，其余 1.25s），循环旋转保持采样连续 | 同上 |
| 编码 | 48kHz OGG；SFX 单声道，BGM 立体声 | 同上 |

试听：artifacts/game-audio-iteration/preview/ 下 4 条 sfx_reel（每条占固定 3 秒槽位，逐条可辨），
以及 loop_*.mp3（循环接缝试听，第 4 秒为尾头交接）。

### 重做 BGM 的循环接缝验证

重做后专门量了循环接缝：**接缝跳变只有曲目内部正常样点间变化的 3%~27%**，
（menu 0.096、shop 0.033、boss 0.086、battle 0.271），
远低于可听的咔哒阈值，循环处不会出声。
响度全部落在 -21 LUFS 附近（menu -20.6 / battle -20.9 / boss -21.0 / shop -21.0），
与上一版在同一水平线上。

### 授权边界

全部为 AI 生成素材，登记为「AI 生成、待核实」，见 docs/asset-licenses.md 第 12 条。
## 十九、2026-11-14 旧 MVP 资产「动起来」+ 旧敌人新风格重画

### 为什么做这一轮

用户问了三件事：旧 MVP 有没有做优化、旧 MVP 多数是静态帧能不能动起来、迭代清单是不是全做完了。

核查结论跟「旧 MVP 是静态帧」这个印象相反：

- **11 个旧敌人全是多帧横条**（2/4/6 帧，单格 56×56），不是静态帧；
- 全仓 295 张 PNG 里单帧的有 170 张，主要集中在 UI（59）、武器图标（49）、瓦片（24）、**特效（22）**；
- 真正没做完的是**迭代清单的 P1-A / P1-B / P2 三批**（特效序列帧、道具动画、旧敌人的动作与死亡缺口）。

本轮用户选定：**三批全做**，并且**旧敌人改用本轮新风格（暗钢 + 旧金 + 深红）重画**，
这样旧敌人和新敌人看起来是同一套美术，而不是两代画风混在一起。

### 范围

| 批次 | 内容 | 数量 |
|---|---|---|
| P1-A | 11 个旧敌人的新风格立绘 | 11 张 224×56（4 帧） |
| P1-A | 11 个旧敌人的死亡条 | 11 张 336×56（6 帧真倒地） |
| P1-A | 旧敌人的动作缺口（跑/冲锋/爬/飞/走/射/爆/石化/苏醒/施法/瞬移/召唤/冲刺/暴怒） | 14 张 336×56（6 帧真姿态） |
| P1-B | 特效序列帧（命中/死亡爆炸/传送门/护盾破碎/毒云/升级法阵） | 6 张 |
| P2 | 低频进化特效（冰冻/石化/圣光/连锁闪电/雷神之怒） | 5 张 |
| P2 | 道具（火把/营火/宝箱/受诅宝箱/商人） | 5 张 |

### 关键做法：3×2 网格 Edit 出「真姿态」

单张立绘只能出一帧。程序化错帧（下摆摆 1px、尸体下沉）出来的是**同一张图的几何变形**，
6 帧看起来几乎一样——本轮先做的 pilot 就是这个问题。

真正管用的做法是**把立绘原图拼成 3×2 品红底卡片当编辑源图**，
让 Qwen-Image-Edit 把每一格重画成不同姿态，再切格拼成横条：

| 环节 | 做法 | 出处 |
|---|---|---|
| 立绘 | 本机 ComfyUI + Qwen-Image-2.1 turbo 文生图，11 个敌人逐个写全造型描述 | tools/gen_iteration_sprites.py + artifacts/iteration_assets/plan_legacy_idle.json |
| 死亡条 | 立绘原图 → 3×2 品红底网格 → 图像编辑 → 切 3×2 → 缩到 56px → 拼 336×56 | tools/gen_legacy_death.py |
| 动作条 | 同上，提示词逐格点名这一帧是什么姿势 | tools/gen_pose_grid.py + tools/pose_grid_data.py |
| 特效/道具 | 现有单帧图 → N 格品红底卡片 → 图像编辑 → 切格 → 统一缩放拼横条 | tools/gen_effect_sheets.py + tools/effects_plan_data.py |
| 抠底 | 品红键控（放宽到偏品红色相，保护紫罗兰）+ 紫边清理 | tools/death_repack.py |
| 缩格 | NEAREST 整数倍缩到目标单格，脚底锚点固定 | tools/death_repack.py pack() |

**帧质检（两段判据）**：

- 严格判据：主体的「站高比」（本体连通域高 / 格高）必须大致单调下降，末帧明显低于首帧；
- 放宽判据：顶边明显下沉、**或**末两帧平均高度明显低于首两帧、**或**主体面积明显缩小。

严格判据对人形怪成立，对四足/矮趴的怪不成立——狼人趴下时本来就矮，
高度比掉不到 25%，于是被误判成不合格（连着三次重出图）。所以改成严格优先、放宽兜底，
并且**先扫已生成的原始网格**，能过就直接打包，不重复烧 GPU。

动作条用另一套判据：每格必须有内容，且**相邻两帧的差异必须超过阈值**——
这一条把「6 格复制同一张」直接判掉。

### 接线：专属目录优先，不用改敌人脚本

旧敌人的脚本本来就在请求具体状态：

    TextureManager.instance.get_enemy_texture("vampire", "run")

而 `get_enemy_texture` 早就**先找专属目录** `assets/sprites/enemies/<id>/<state>.png`，
找不到才退回旧的平铺图。所以本轮只要把文件放对位置，旧敌人自动就用上新资产，
**一行敌人脚本都没改**（唯一例外见下）。

| 敌人 | 落盘状态 |
|---|---|
| 吸血鬼 | idle / run / death |
| 狼人 | idle / charge / death |
| 蝙蝠 | fly / death |
| 僵尸 | idle / walk / death |
| 骨架弓手 | idle / shoot / death |
| 爆裂者 | idle / walk / explode / death |
| 石像鬼 | idle / petrify / wake / death |
| 血族法师 | idle / cast / teleport / death |
| 召唤师 | idle / cast / death |
| 血族王子 | idle / dash / rage / death |
| 精英吸血鬼 | idle / death |

**精英吸血鬼有两份**：它的贴图键是 `elite_vampire`，但 `_get_enemy_type()` 返回 `elite`，
而死亡动画是按 `_get_enemy_type()` 找表的。两边都得放文件，否则死亡时会退回淡出。

### 矩形单格播放器

特效和道具的单格不是正方形（火把 24×48、宝箱 48×40、商人 128×128），
而 `SpriteSheet` 那套用「宽 ÷ 高 = 帧数」推帧数，只对正方形单格成立
（96×48 在方形规则下只算 2 帧，实际是 4 帧）。

所以新增 `scripts/core/sprite_frames_lib.gd`：用 AtlasTexture 按显式单格尺寸切帧 +
AnimatedSprite2D 播放，帧数从登记表来，不再靠猜。

登记表在 `scripts/core/asset_slots.gd`：

- `EFFECT_SHEETS`：11 个特效（路径 / 帧数 / 单格尺寸 / once 或 loop）；
- `PROP_SHEETS`：5 个道具。

接入点：

| 位置 | 改动 |
|---|---|
| vfx_manager.gd | 新增 `spawn_sheet_fx()`；`spawn_texture_fx()` 先问序列帧，问不到才走单帧 |
| game_room.gd | 火把/营火/宝箱/商人/传送门改用序列帧（`_make_prop_visual` / `_make_effect_visual`） |
| poison_cloud.gd | 毒雾地面改用序列帧 |
| cursed_chest.gd | 受诅宝箱开箱播 6 帧开箱序列，播完再闪光淡出 |

### 自动回归

| 组 | 断言 | 结果 |
|---|---|---|
| tools/legacy_animation_test.gd（新增） | 11 个旧敌人的每个动作都有专属精灵条、单格 56、多帧可识别；死亡条恰好 6 帧且相邻帧确实不同；特效/道具序列帧文件在位且尺寸 = 帧数×单格；矩形单格能被 SpriteFrames 正确切帧 | 200 / 200 通过 |
| tools/enemy_death_strip_test.gd | 既有 12 种新敌人的死亡演出未被波及 | 60 / 60 通过 |
| tools/iteration_pack_test.gd | 玩法与图鉴未被波及 | 44 / 44 通过 |
| tools/sprite_sheet_test.gd | 既有横条播放未被波及 | 18 / 18 通过 |
| tools/verify_round4.gd | 全量场景回归 | 全通过 |

### 踩坑记录

1. **提示词让模型给每个格子加「暗底板 + 装饰边框」**（2026-11-14，特效批）
   早期提示词写成 "Draw the SAME effect in six separate square cells arranged in 3 columns
   and 2 rows"，模型理解成「画六个带暗底板和华丽边框的独立小画格」，
   每个格子里都多出一块黑色底板和一圈哥特画框。
   改成死亡条那套已验证的写法（"repeated in N identical cells on a magenta card"）
   之后，模型只重画内容、不再自己加板子。
   同时把画风词里的 "antique gold filigree trim, deep crimson gems" 去掉——
   这两个词就是模型画装饰边框的直接诱因。

2. **严格帧序判据对四足怪不成立**（2026-11-14，狼人/僵尸）
   见上文「帧质检（两段判据）」。

3. **`FluxKontextImageScale` 会把编辑源图硬拉到 ~1MP**（2026-11-14，特效批）
   19.5GB 的 Edit 模型在 8GB 显存上每一步都要搬权重，拉到 1MP 意味着单张 3 分钟。
   特效最终只有 64~128px 一格，不需要 1MP：拆掉这个节点、直接用卡片原图当 latent 输入，
   采样面积降到 1/5。敌人死亡/动作条因为要刻画角色细节，仍然走 1MP。

4. **GDScript 里 `tw2` 紧跟在 `tw` 后面声明会解析失败**（2026-11-14，vfx_manager.gd）
   报错是 `Identifier "w2" not declared in the current scope`，报错行号还差一行，
   很容易误判成别处的问题。改名 `life_tween` 即过。

### 授权边界

全部为 AI 生成素材，登记为「AI 生成、待核实」，见 docs/asset-licenses.md 第 13 条。
## 二十、2026-11-14 迭代新增敌人专属动作条 + 血铠幼虫专属资产

### 为什么做这一轮

上一轮把 12 个迭代新增敌人的立绘与死亡条做出来了，但它们只停在「待机 + 死亡」：
移动时播的是待机条（下摆 1px 摆动），而这些敌人的**辨识度恰恰在行为上**——
扑击、治疗、吐网、钻地、投掷、光束、俯冲……没有专属动作条，玩家看不出它们在干什么。

同时血铠幼虫（`blood_larva`）一直是借蝙蝠飞帧染绛红的占位图。

### 交付物

| 敌人 | 新增动作条 | 状态语义 | 接入点（脚本） |
|---|---|---|---|
| `shield_guard` | `guard` 6 帧 | 举盾格挡 | `shield_guard.gd` 正面受击时（`is_frontal_hit`） |
| `blood_hound` | `pounce` 6 帧 | 蓄力扑击 | `blood_hound.gd` 转入 windup 时 |
| `blood_priest` | `cast` 6 帧 | 抬手治疗 | `blood_priest.gd` `try_heal()` 成功时 |
| `web_weaver` | `cast` 6 帧 | 吐网 | `web_weaver.gd` `drop_web()` 之后 |
| `burrower` | `burrow` 6 帧 | 钻回地下 | `burrower.gd` 再次下潜时 |
| `gem_leech` | `steal` 6 帧 | 吞下宝石 | `gem_leech.gd` 吃到宝石时 |
| `coffin_guard` | `revive` 6 帧 | 从棺材爬起 | `coffin_guard.gd` `revive_from_coffin()` |
| `lantern_wraith` | `beam` 6 帧 | 提灯放光束 | `lantern_wraith.gd` 光束启动时 |
| `alchemist_pitcher` | `throw` 6 帧 | 投掷药瓶 | `alchemist_pitcher.gd` `toss()` 之后 |
| `furnace_golem` | `charge` 6 帧 | 外甲碎裂后冲锋 | `furnace_golem.gd` 外甲归零时 |
| `resonance_mage` | `cast` 6 帧 | 伸手连线 | `resonance_mage.gd` 连上同伴时 |
| `moon_wing` | `dive` 6 帧 | 收翼俯冲 | `moon_wing.gd` 转入 dive 时 |

血铠幼虫全套：

| 文件 | 规格 | 说明 |
|---|---|---|
| `blood_larva/idle.png` | 224×56 / 4 帧 | t2i 新角色立绘：绛红分节虫身、苍白骨肋、无眼钝头 |
| `blood_larva/pounce` | 336×56 / 6 帧 | 蜷缩蓄力 → 扑咬 |
| `blood_larva/death.png` | 336×56 / 6 帧 | 真倒地：躯体裂开、苍白骨肋外露 |

### 接线做法

新增 `enemy_base.gd` 的 `play_action_strip(enemy_id, state, mode)`：
取专属动作条 → `use_sprite(tex, mode)`。文件不存在时静默跳过，不影响原有表现。

- `mode = "once"`：播完自动回待机条（沿用 `enemy_base` 既有语义）。
- 动作条只在这 12 个敌人的**行为触发点**播一次，不做常驻循环。

`asset_slots.gd` 的 `ENEMIES` 登记表同步补上各敌人的新状态名，
这样暂停菜单的图鉴和 `get_enemy_texture()` 走同一份口径。

### 踩坑记录

1. **`link_nearby()` 原本没有返回值**（2026-11-14，`resonance_mage.gd`）
   接线时想「连上同伴才播连线动作」，但原函数是 `-> void`，
   只能改成「每次都播」——那样没有同伴时也会演一次空动作。
   改成 `-> bool`，两个分支各自返回 true/false。这是**唯一**改动的既有敌人行为签名。

2. **盾卫的格挡动作接在伤害路径上，不是移动路径上**（2026-11-14，`shield_guard.gd`）
   盾卫没有独立的「格挡」状态，它的减伤发生在 `_direct_damage()` 里。
   接在 `is_frontal_hit()` 成立时才播：玩家从正面打会看到举盾，
   绕到侧面打则不播——动作和减伤规则对齐，不是随便找个时机播。

3. **`coffin_guard` 的苏醒动作接在 `revive_from_coffin()`**（2026-11-14）
   这个函数由 `coffin_shell.gd` 在棺材倒计时结束时调用，
   接在这里能保证「棺材裂开 → 怪爬出来」在同一个时刻发生。

### 仍然没做的（边界）

- **敌人受击（hurt）状态仍然全缺**：游戏脚本从未请求过 hurt 状态，属死数据。
  要做必须先在 `enemy_base.gd` 加请求点，否则图做出来没人播。
  → **已在第二十一节解决**：请求点接好了，13 个敌人的受击条也做了。
  仍未做的是旧 MVP 11 个敌人的 `hurt.png`。
- **地面危险贴图仍然没有**：减速网、棺材、卵巢、药液、月蚀安全圈仍是半透明多边形和圆环。
- **`portal` 单帧版仍被商人脚下光晕使用**（`game_room.gd` 的 merchant glow）。

### 授权边界

全部为 AI 生成素材，登记为「AI 生成、待核实」，见 docs/asset-licenses.md 第 14 条。

---

## 二十一、敌人受击条（hurt）接线

### 为什么先接线再画图

之前 hurt 一直是死数据：脚本从不请求，图做出来也没人播。
这一轮先把请求点接进 `enemy_base.take_damage()`，再按这条路径出图，
所以 13 条受击条是**接得上、播得出**的，不是躺在磁盘上的文件。

### 交付物

| 敌人 | 受击条 | 帧数 | 受击语义 |
|---|---|---|---|
| `shield_guard` | `hurt` | 6 | 盾牌被撞开、后仰踉跄 |
| `blood_hound` | `hurt` | 6 | 四足被撞翻、侧向失衡 |
| `blood_priest` | `hurt` | 6 | 后仰、双臂甩开（脸始终可见） |
| `web_weaver` | `hurt` | 6 | 腿脚乱蹬、身体扭转 |
| `burrower` | `hurt` | 6 | 被撞退、铲形前肢甩起 |
| `gem_leech` | `hurt` | 6 | 小身板被震得翻滚 |
| `coffin_guard` | `hurt` | 6 | 棺盖震开、后仰 |
| `lantern_wraith` | `hurt` | 6 | 提灯甩出、躯体后弯 |
| `alchemist_pitcher` | `hurt` | 6 | 药瓶脱手、后仰踉跄 |
| `furnace_golem` | `hurt` | 6 | 沉重后仰、炉心闪动 |
| `resonance_mage` | `hurt` | 6 | 连线被打断、双臂甩开 |
| `moon_wing` | `hurt` | 6 | 双翼反射性张开、身体失衡 |
| `blood_larva` | `hurt` | 6 | 节段虫身蜷缩后弹开 |

规格：336×56 / 6 帧，落在 `assets/sprites/enemies/<enemy>/hurt.png`。
弧线固定为「挨打 → 后仰 → 踉跄 → 找回平衡 → 站稳 → 回到原姿势」，
最后一格回到原姿势，接回待机条才不跳。

### 接线做法

`enemy_base.gd` 新增三个东西：

| 接口 | 作用 |
|---|---|
| `play_hurt_strip()` | 按 `_get_enemy_type()` 取 `hurt.png`；文件不存在返回 false，静默跳过 |
| `_trigger_hurt_reaction()` | 受击路径上的实际请求点，带「正在播」与冷却双重保护 |
| `HURT_FPS` / `HURT_LOCK_TIME` | 受击条 12fps（约 0.5 秒）；播完 0.2 秒冷却 |

调用点在 `take_damage()` 里，顺序是：
**扣血 → 闪白 → 结算附加状态 → 判死 → 活着才播受击条**。
判死在前，所以致死一击直接走死亡条，不会先播一段受击再死。

播放语义复用既有的 `use_sprite(tex, mode, fps)`：
新增 `mode = "hurt"`（语义同 `once`，播完回待机）与第三个参数 `fps`
（0 表示默认帧率）。`SpriteSheet.advance()` / `advance_once()` 同步加了可选 `fps`。

### 四条踩坑

1. **连射会把受击条一遍遍从头播**：霰弹枪、链炮能在几十毫秒内打中多次，
   每次都重播，敌人看起来像在原地抽搐。
   所以 `_trigger_hurt_reaction()` 有两道闸：正在播就不播，播完还有 0.2 秒冷却。
2. **受击条播完必须把帧率还原**：待机和受击用的不是同一个帧率，
   不还原的话敌人回到待机后会比平时快一圈。
3. **缺文件不能崩**：11 个旧 MVP 敌人没有 `hurt.png`，
   `play_hurt_strip()` 返回 false 后表现与从前完全一致（不会换图、不会崩）。
4. **命中特效图里藏着半透明品红残渣**（`assets/effects/hit_effect_sheet.png`，
   上一轮遗留）：alpha 1~101 的纯品红像素在贴图里几乎看不见，
   但命中特效被缩放渲染时就会渗成一条紫色竖线，跟着每个被打中的敌人闪。
   这轮实机截图把它暴露出来，已清掉（198 像素透明化 + 36 像素就地修补）。
   **教训**：抠底残渣不能只查「不透明的品红」，半透明的也要查 ——
   它们在静帧里看不见，在缩放/滤波后就现形。

### 验证

- 自动化：`tools/iter_hurt_test.gd` —— 13 条受击条存在且是 6 帧横条、相邻帧差异、
  登记表一致、`enemy_base` 接线点在位、挨打会切条、播完回待机、连击不重播、
  致死一击走死亡条、缺文件不崩。
- 实机：`tools/iter_hurt_shot.gd` —— 13 个敌人走真实 `take_damage()` 路径，
  截图对比「挨打前」与「受击中」。

### 仍然没做的（边界）

- **旧 MVP 11 个敌人自己的 `hurt.png` 仍缺**（吸血鬼、狼人、蝙蝠、僵尸、骷髅弓手、
  爆裂者、石像鬼、吸血鬼法师、召唤师、亲王敌人、精英吸血鬼）。
  请求点已经接好，把图放进 `assets/sprites/enemies/<enemy>/hurt.png` 即可自动生效，
  不需要再改代码。
- **地面危险贴图仍然没有**。

### 授权边界

全部为 AI 生成素材，登记为「AI 生成、待核实」，见 docs/asset-licenses.md 第 15 条。

