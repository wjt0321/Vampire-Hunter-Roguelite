# 竞品与开源项目拆解（GDD 迭代依据）

> 调研日期：2026-11-08
> 用途：给 GDD 的机制迭代提供"别人已经验证过的答案"，避免我们凭感觉拍数值。
> 结论优先级：**已在我们代码里验证可落地的** > **需要新增系统的** > **纯参考不建议抄的**。

---

## 0. 一句话结论

我们的 MVP 已经站在正确的赛道上（房间推进 + 波次 + 三选一 + 层进 Boss），
目前缺的不是"更多内容"，而是三类**结构性缺口**：

1. **局内经济缺失**：商店房现在只是回血 30%，玩家整局没有任何"花钱做取舍"的机会。这是 Brotato 最核心的乐趣来源，也是我们最好补的一块。
2. **Build 决策深度不足**：升级三选一没有"重抽 / 跳过 / 锁定"，武器进化靠击杀数自动触发，玩家感觉不到"我在攒一个东西"。
3. **战斗可读性**：弹道、Boss 登场、敌人密度这些"看得清"的问题，本质是 juice / 可读性工程，不是美术问题。

---

## 1. 四个可直接读代码的开源项目

| 项目 | 技术栈 | 值得我们看的地方 | 明显短板 |
|---|---|---|---|
| [SurvivorsStarterKit](https://github.com/DarkRewar/SurvivorsStarterKit) | Godot 4.6 C# | 全局 `GameManager` 时间驱动难度：`DifficultyScale = 1.0 + 分钟数 * 0.05`；只做 4 个技能（射击 / 吸血领域 / 环绕球 / 随机水潭）就撑起完整循环 | 内容量极小；README 自述首次打开会崩（Jolt 重导入） |
| [vampire-survivor-style-game](https://github.com/alvaro347/vampire-survivor-style-game) | Godot 4.3 GDScript | 与我们同引擎同语言，是最直接的架构对照样本；随机关卡掉落 + 渐进难度的最小实现 | 仍是 demo 级，无 Meta |
| [GDLastOfTheSurvivors](https://github.com/imitatehappiness/GDLastOfTheSurvivors) | Godot 4 GDScript | 角色状态机（state machine）写法；武器/被动/升级三层数据分离；[itch 有可玩 demo](https://imitatehappiness.itch.io/last-of-the-survivors) | 2023 年后基本停更 |
| [FactorySurvivorsGame](https://github.com/coderKillo/FactorySurvivorsGame) | Godot 4 GDScript | 把"幸存者 + 塔防 + 工厂"拼起来的完整商业级原型：传送带、钻机、可切换控制器 | 系统过重，不适合我们当前体量 |

### 1.1 从开源项目里拿到的三条硬结论

1. **难度用"时间"驱动，而不是只用"波次"**。
   SurvivorsStarterKit 的写法是 `1 + 分钟 * 5%`，好处是玩家体感线性、可预期；
   我们目前是 `波次指数 + 玩家等级橡皮筋`，涨得更猛。建议保留指数底子，但把
   "同屏数量"改成随时间封顶（见 §3.6），避免后期变成一坨。
2. **技能/武器数量不是重点，组合才重要**。那个 kit 只有 4 个技能，但每个都有独立
   的伤害节奏（即时/持续/环绕/区域）。我们现在 11 把武器，同质化偏严重（8 把都是
   "朝目标飞一发"）。下一批内容应该优先做**行为差异**，不是第 12 把直线枪。
3. **对象池是标配，不是优化项**。四个项目全都做了池化；我们已经有了 `ObjectPool`，
   这次改弹道贴图也是共享材质 + 共享贴图（`ProjectileVisuals` 静态缓存），继续这个方向。

> ⚠️ 注意：SurvivorsStarterKit 那份 README 里"用 Jolt 把同屏敌人从 50 提到 200"的说法
> **不能直接套到我们身上** —— Godot 的 Jolt 是 **3D** 物理后端，2D 游戏跑的是
> GodotPhysics2D，换 Jolt 对 2D 毫无影响。我们要提密度只能走"少用物理体"的路线。

---

## 2. Vampire Survivors：进化系统是"仪式"，不是数值

VS 的进化条件（[官方 Wiki](https://vampire.survivors.wiki/w/Evolution)）：

```
武器满级 + 持有对应被动 + 打开 10 分钟后的宝箱 → 进化
```

关键不在于配方，而在于**它把"变强"做成了一个可预期、可等待、有仪式感的事件**：

- 被动只需要 **Lv1** 就够（`Hollow Heart` 1 级也能把满级鞭子变成 `Bloody Tear`），
  这让玩家在升级三选一里"为了未来的进化"拿一个当下很弱的被动，形成**跨波次的投资决策**。
- 宝箱由 Boss 掉，于是"打 Boss"和"变强"被绑成同一条因果链，而不是我们现在的
  "打满 50 只怪自动进化"。
- 进化后的武器**不再升级**，是完成态，视觉与手感都要明显不同（VS 的 `Death Spiral`
  直接把镰刀甩成螺旋，属于"换了一种玩法"而不是"+30% 伤害"）。

**对照我们当前实现**：`EVOLUTION_CONFIG` 里所有武器都是 `required_kill_count: 50`、
`required_passive_items: []`，`_check_weapon_evolutions()` 在每次击杀时静默检查。
结果就是 —— 玩家根本不知道自己在攒进化，进化发生时也没有任何"事件感"。

| 差距 | 建议改动 | 成本 |
|---|---|---|
| 进化无感知 | 进化条件改成"满级 + 指定被动（Lv1 即可）"，并在 HUD 常驻一个"进化进度"槽 | 中 |
| 进化无仪式 | 触发时机改成"打开宝箱房 / Boss 房结束"的宝箱事件，播 1.2s 动画 + 音效 | 低 |
| 进化后不够"换玩法" | 至少给 3 把武器做行为级变化（如手枪进化=双管齐射、飞刀进化=环绕刀阵） | 中高 |

---

## 3. Brotato：把"商店"做成第二套战斗

Brotato 的单局结构是 **20 波 + 波间商店**，一局 20~30 分钟。它被认为比 VS 更有深度的
原因几乎全部集中在商店（[评测](https://blog.hmpublishing.se/2026/08/brotato-review-how-much-game-can-you.html)、
[Higher Plain Games](https://higherplaingames.com/switch/brotato-review/)）：

1. **6 个武器槽是身份**。装 2 把还是 6 把，直接决定这局是什么流派。
2. **同名武器可合成升级**（两把 Lv1 霰弹枪 → 一把 Lv2），但合成期间占槽位，形成"先亏后赚"的取舍。
3. **属性带惩罚**：加攻速常常减射程，堆护甲常常变慢。玩家不是在"选更强的"，而是在"选一种失衡"。
4. **重抽（reroll）要花钱**，锁定（lock）不花钱但占未来的钱 → 随机性可以被"用钱谈判"。
5. **角色是规则改写器**，不是数值皮肤：`One-Armed` 只能带 1 把武器、`Bull` 完全不能带武器、`Loud` 敌人更密但材料更多。

**对照我们当前实现**：商店房 `_enter_shop_room()` 只有 `player.heal(max_hp * 0.3)` 和
2 秒后开传送门。`upgrade_shop.gd` 是**局外**的血晶商店，两者不是一个东西。

> 这是我认为**投入产出比最高的一块**：把商店房做成真正的局内商店，
> 需要新增的只有"局内金币掉落 + 一个可购买的 4 格货架 + 价格曲线"，
> 但它一次性解决了玩家反馈里的"前期太强/后期无双"和"没有决策"两个问题。

---

## 4. 20 Minutes Till Dawn：手动瞄准 + 弹匣，把"走位游戏"变回"射击游戏"

20MTD 的全部差异化就两条：**每一枪都要瞄，每个弹匣都会空**（[设计拆解](https://lemonarcade.com/games/20-minutes-till-dawn)、
[评测](https://lumenplays.com/games/com-flanne-minutestilldawn-roguelike-shooting-fr-gp.html)）。

- 弹匣机制制造了"节奏性承诺"：压力最大的时刻恰好是你弹匣空的时候，于是每次交火都是"什么时候可以承受停火"的赌博。
- 升级池全部围绕这个节奏写（打空触发、换弹触发、弹匣缩小），所以"杂务"变成了 Build 轴。
- 它的升级强度曲线**故意陡**：好 Build 能滚雪球，烂 Build 十分钟就死，靠快速失败降低重复成本。

**对我们的意义**：我们已经有鼠标瞄准（`auto_aim = false` 的武器），但 GDD 2.3 还写着
"无手动射击"，文档落后于代码。同时"手动瞄准"意味着**弹道必须极度可读**——
这正是这轮弹道改造的正当性来源：20MTD 之所以敢让玩家瞄，是因为它的弹幕对比度足够高。

---

## 5. Halls of Torment：可读性是"颜色 + 地面标记"两件事

HoT 被反复提到的两个设计（[Ars Technica](https://arstechnica.com/gaming/2024/10/halls-of-torment-is-diablo-cranked-up-to-50000-kills-hour/)、
[RPS](https://www.rockpapershotgun.com/vampire-survivors-meets-diablo-in-halls-of-torment)）：

1. **Boss/精英的重击前摇，用地面上的紫色线条和圆环画出来**，而不是只让 Boss 闪一下。
   （我们的 `_telegraph_attack()` 目前只有红色闪烁 + 一圈警告环，缺地面滞留标记。）
2. **色彩分工明确**：自己的召唤物和敌人的威胁必须一眼可分。Ars Technica 的原话是
   "自己的召唤攻击有时难以和敌人的威胁区分"，这是它被批评的点 —— 说明这条一旦做错就是显性缺陷。

另外 HoT 的"井 + 水桶"Meta（把一件本局装备送回地表，花金币永久解锁为开局装备）是个很妙的
**风险/长期收益**抉择，但评论也指出它"系统太多余"。我们不做这个，只借鉴它的核心：
**Meta 解锁应该是"你在局内主动选择送到局外的东西"，而不是自动结算。**

---

## 6. 手感清单（Vlambeer《The Art of Screenshake》，30 条）

这是"武器没特效、静态帧呆板"的直接解药。原 talk（GDC 2013）没有官方文稿，
可读的整理版：[30 条逐条说明](https://artificials.ch/?p=1605)、[Juice 综述](https://jamzo.com/blog/game-feel-and-juice)。

按我们现状标注（✅ 已有 / 🟡 部分 / ❌ 没有）：

| # | 技巧 | 我们 | 备注 |
|---|---|---|---|
| 5 | 更大的子弹 | ✅ | 本轮已做（16×6 亮芯+光晕） |
| 6 | 枪口闪光 | ❌ | 廉价高收益，一次 tween 就够 |
| 9 | 命中特效 | ✅ | `spawn_hit_particles` |
| 10 | 命中闪白 | ✅ | `_flash_hit()` |
| 11 | 击退 | ✅ | `take_damage_with_knockback` |
| 15 | 屏幕震动 | ✅ | `vfx.screen_shake` |
| 17 | **命中冻帧（hitstop）** | ❌ | 0.04~0.06s，最省的"重量感"来源 |
| 23 | 超级连射 | 🟡 | 火焰喷射器勉强算 |
| 26 | 更快的射速 | 🟡 | 后期依赖升级才起来 |

> 结论：我们不缺粒子，缺的是**时间维度**的反馈（冻帧、后坐、镜头推进）与**声音层次**。
> 这也是为什么"叠满技能后变成无双割草"不只是数值问题，也是反馈问题——打什么都没阻力。

---

## 7. 六条用户反馈 ↔ 调研结论对应表

| 反馈 | 根因（调研视角） | 处理 |
|---|---|---|
| 弹道太细看不清 | 子弹 6px、无对比度；HoT/20MTD 都靠"大 + 亮 + 加色" | ✅ 本轮：程序化亮芯+光晕，玩家/敌人/Boss 全部接入 |
| 敌人增多，先玩着 | 密度要靠"时间封顶"而非波次无上限（StarterKit） | 🟡 保留现状，观察后再加同屏上限 |
| Boss 开场就该亮血条 | HoT 的"前摇可读"原则同样适用于登场 | ✅ 本轮：2.6s 无敌 + 血条 0→满 + 碰撞关闭 |
| 武器没特效、静态帧 | 30 条清单里我们缺 hitstop / 枪口闪光 / 后坐 | ⏭ 下一批 P1 |
| 精灵图缺失 | 与玩法无关，等 ComfyUI 阶段 | ⏭ 搁置 |

---

## 8. 建议的下一批内容（按投入产出比排序）

| 优先级 | 内容 | 参考来源 | 预估改动面 |
|---|---|---|---|
| **P0** | 局内金币 + 真·商店房（4 格货架、重抽、锁定） | Brotato | 新增 `gold` 掉落 + 商店 UI + 价格曲线 |
| **P0** | 升级三选一加"重抽 1 次 / 跳过换血晶" | Brotato / VS | `upgrade_ui.gd` 小改 |
| **P1** | 进化改成"满级+指定被动+宝箱事件"，HUD 显示进化进度 | VS | 改 `weapon_evolution` + 宝箱房 |
| **P1** | 打击感三件套：枪口闪光、命中冻帧、玩家后坐 | Vlambeer | 局部，不动数值 |
| **P2** | Boss/精英重击加地面滞留标记 | HoT | VFX + Boss 脚本 |
| **P2** | 第三角色 + 角色规则改写（不是数值皮肤） | Brotato | character_data + 被动钩子 |
| **P3** | 难度层（血月等级 1~5，逐层加词缀） | Brotato Danger 1-5 | Meta + 倍率 |

---

## 9. 来源清单

- SurvivorsStarterKit — https://github.com/DarkRewar/SurvivorsStarterKit
- vampire-survivor-style-game — https://github.com/alvaro347/vampire-survivor-style-game
- GDLastOfTheSurvivors — https://github.com/imitatehappiness/GDLastOfTheSurvivors
- FactorySurvivorsGame — https://github.com/coderKillo/FactorySurvivorsGame
- Vampire Survivors Wiki · Evolution — https://vampire.survivors.wiki/w/Evolution
- Vampire Survivors 社区进化/组合指南 — http://vampire-survivors.net/
- Brotato 结构评测 — https://blog.hmpublishing.se/2026/08/brotato-review-how-much-game-can-you.html
- Brotato 系统评测 — https://higherplaingames.com/switch/brotato-review/
- 20 Minutes Till Dawn 设计拆解 — https://lemonarcade.com/games/20-minutes-till-dawn
- 20 Minutes Till Dawn 上手评测 — https://lumenplays.com/games/com-flanne-minutestilldawn-roguelike-shooting-fr-gp.html
- Halls of Torment（Ars Technica）— https://arstechnica.com/gaming/2024/10/halls-of-torment-is-diablo-cranked-up-to-50000-kills-hour/
- Halls of Torment（RPS）— https://www.rockpapershotgun.com/vampire-survivors-meets-diablo-in-halls-of-torment
- Vlambeer 30 条手感技巧整理 — https://artificials.ch/?p=1605
- Game Feel / Juice 综述 — https://jamzo.com/blog/game-feel-and-juice

---

## 10. 进阶玩法调研（第二轮，2026-11-08）

第一轮解决的是"骨架对不对"（房间/商店/进化/打击感）。这一轮的问题是：
**同样是 Survivors-like，为什么有人能玩 200 小时，我们 5 局就腻？**
答案是深度不在"更多武器"，而在**三层结构性设计**：敌人怎么变、风险怎么选、池子怎么优化。

### 10.1 精英敌人：不是"更肉的小怪"，是"带规则的威胁"

Brotato 的石像鬼（Gargoyle）是一个可抄的样板：

| 设计点 | 具体做法 |
|---|---|
| 分阶段变异 | 100% 血：随机游走 + 每 0.3s 环形弹幕；60% 血或 30s：开始追击 + 每 0.4s 12 发随机弹；30% 血或 45s：每 0.01~0.15s 三连发 |
| 早波次衰减 | 精英血量在第 1-8 波只有 50%，9-12 波 75%，13 波后才是 100%（乘算），保证前期也打得动 |
| 明确回报 | 精英必掉一个红箱，箱内必出一件传说物品 |
| 提前通知 | 商店里就会提示"这一波有精英" |

启示：精英的价值是**迫使玩家改变操作**（拆盾 / 侧移 / 优先集火），而不是把血量乘 3。
我们把"第 12 种换皮怪"改成了"现有 8 种怪随机长词缀"，理由就是这条。

来源：Brotato Wiki（Gargoyle / Gangster 条目）、brotatodex 的 Danger 5 攻略。

### 10.2 风险杠杆：让玩家自己调难度

Vampire Survivors 的 **Curse** 是全品类最聪明的设计之一：

- 每 10% 诅咒 → 敌人血量 +10%、移速 +10%、**生成数量 +10%、生成频率 +10%**（乘算）
- 收益侧：怪更多 = 经验宝石更多 = 升级更快 = 金币更多
- 获取途径：PowerUp（5 级，每级 +10%）、Skull O'Maniac（5 级，每级 +10%）、Torrona's Box 满级 +100%
- 关键：它不是难度选项，**是可购买的资源**。构筑成型后主动买诅咒换效率，是高手与新手的分水岭

Brotato 的 Danger 等级是同一件事的"局外版本"：难度修饰词叠加，回报同步提高。

我们的缺口：目前难度只有"往下推层"，玩家没有任何**主动加难换收益**的开关。
计划：休息房放"深渊契约"——献祭本层 20% 最大生命，换取本层敌人 +20% 数量与 +30% 掉落。

### 10.3 升级池的三件套：Reroll / Skip / **Banish**

VS 的升级界面有三个动作：Reroll（重抽本次）、Skip（跳过）、**Banish（把某个选项从本局池子里永久移除）**。

Halls of Torment 的"药剂"把这件事说得更直白：三种药剂里**移除**是最有价值的，
因为重抽只改善"这一屏"，移除改善"剩下的每一次升级"——**只有它会复利**。

我们已有 Reroll / Skip（17.2）。缺的是 Banish：
3 次机会，把一个武器或被动从本局三选一池里删掉，从此不再出现。
对"这局我不玩毒雾"的玩家来说，这比 10 次重抽都值。

### 10.4 "进化"必须改机制，不能只改数字

Halls of Torment：每个技能 6 条强化路线、最高 10 级，**第 3 次和第 6 次强化会通过卷轴选择最多 2 个"技能进化"，直接改变技能特性**。
VS 同理：进化后的武器换的是行为（鞭子变范围、书变环绕）。

我们 17.3 已经做了三把行为级进化（双管 / 环形 / 刀阵），这条继续沿用：
**新武器进化必须先回答"它和原版打法有什么不同"，答不出来就退回数值强化。**

### 10.5 音画的复利：小反馈叠起来就是"爽"

ChamberLoop（开源 Unity 项目）里有一个细节值得抄：
**经验拾取音效做 Pitch Ramping**——连续拾取时音高逐级升高，形成 combo 感。
成本几乎为零，但把"捡经验"从杂务变成了正反馈。

配合我们已经做的：弹道亮芯、命中冻帧、金币吸附合并、经验宝石分档。

### 10.6 反雪球：难度要挂钩"武器强度"，不只是"玩家等级"

Project-Bloodwave 的难度缩放公式里同时挂了 **player level + weapon strength**。
原因：等级高不等于强度高（可能全点了移速），只看等级会出现"玩家 DPS 落后但怪已经起飞"。

我们现在的橡皮筋只挂玩家等级（`ENEMY_HP_PER_PLAYER_LEVEL = 0.06`，上限 3 倍）。
待办：加入武器总 DPS 的软挂钩，让"胡点也能过关、但纯堆一件武器会被反制"。

### 10.7 开源仓库里其它可抄的技术点

| 项目 | 可抄的东西 | 我们的状态 |
|---|---|---|
| ChamberLoop | 宝箱 gacha：按 Tier 1/3/5 概率开箱，Luck 影响权重；武器分 Projectile / Orbital / Zone 三类行为 | 宝箱已有，Tier 与 Luck 缺；Orbital 已用于刀阵进化 |
| ChamberLoop | 无限地图分块（chunk）流式加载 | 不需要（我们是房间制） |
| Project-Bloodwave | 状态效果做成**可复用的投射物修饰器**（流血/减速/吸血） | 缺。比"再出一把毒武器"更省事 |
| Last Wave | 地面临时增益（回血球 / 回血区 / 伤害爆发） | 缺。战斗中的微决策，成本低 |
| ECS-RPG | 附魔（毒/爆）叠加在武器上 | 与上面的修饰器同一件事 |

### 10.8 结论：这一轮做什么

按"每单位工作量带来的玩法变化"排序：

1. **精英词缀**（已做）—— 让 8 种敌人变出 4 类威胁，改动集中在一个控制器里
2. **放逐 Banish**（下一步）—— 唯一有复利效果的池子操作，接口现成
3. **深渊契约（风险杠杆）** —— 把"难度"变成可交易资源
4. **武器强度软挂钩** —— 反雪球
5. **经验拾取 combo 音高** —— 近乎零成本的手感

### 10.9 来源

- Brotato Wiki：Gargoyle（Elite / Mutation）、Gangster（steal → elite 风险机制）、Elite HP by wave
- brotatodex：Jack / Danger 5 构筑（-75% 敌人、+175% 敌人血量等难度修饰词思路）
- Vampire Survivors Fandom：Curse 词条（数值与乘算规则）；NTGame 永久强化页（Skip / Reroll / Banish）
- Halls of Torment：Traits Primer（药剂三种效果）、技能 6 分支与 3/6 次进化、职业印记
- 开源仓库：`Fuheshka/ChamberLoop`（gacha 宝箱、Pitch Ramping、武器三类行为）、
  `zsoltikv/Project-Bloodwave`（状态修饰器、难度挂钩武器强度、elite variants）、
  `qArtemq/Last-Wave`（每波敌人修饰词、地面临时增益）、`DANDY0/ECS-RPG`（附魔与状态）
