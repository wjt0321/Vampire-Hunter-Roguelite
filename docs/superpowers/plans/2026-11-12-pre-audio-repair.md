# 音频适配前全项目修复实施计划

> 完成状态：50/50关闭，修后全量35/35通过，整分支独立审查PASS；详情见 docs/archive/qa/validation.md。

> 执行方式：按批次实现、独立审查、回归；本文件同时是进度账本。用户已授权自主完成，不在批次间等待确认。

**Goal:** 关闭 2026-11-12 审查提出的 50 项缺陷，补上真实玩法路径测试，形成音频适配前的可靠基线。

**Architecture:** 保留现有 Godot 场景与 Manager/Player/Enemy/UI 分层，在权威入口统一伤害、交易、终局、统计和保存规则。不重制素材、不新增玩法框架。已有行为与文案冲突时优先兑现明确机制；计时生存、即时血晶等已有明确实现只修正误导提示。

**Tech Stack:** Godot 4.7.2、GDScript、Python（测试运行器）；无新增运行时依赖。

**Spec:** 本文“问题台账”对应本会话上一轮完整源码审查，编号保持不变。

## Global Constraints

- 基线 commit：727e3ad；修复分支：repair/pre-audio-20261112。所有更改保留在当前工作区，不提交、不推送。原有未跟踪 nul 不处理。
- 保持既有 CRLF/LF；修改前读取当前文件，不覆盖别人的更改。每批仅一个实现者，跨批依赖由主会话审查整合。
- 测试只使用工具运行隔离存档；禁止将真实存档加载为测试进度或修改真实存档。仅允许对真实主档及其临时/备份伴随文件计算只读摘要以确认未被改写。存档测试包含临时文件、备份的隔离及清理。
- 新增测试应复现实际故障；不得直接设满级后宣称正常升级可达，不得直接调用 Boss defeated 后宣称真实通关。
- 每批记录：实现文件、针对性用例、实际命令、退出码、失败与未验证范围。源码修复、引擎测试、人工视听分别记账。
- 便携 Godot 只放项目 .tools/godot/，从官方发布下载并验证 SHA256，不安装系统软件。
- 不把通过数量当作玩法体验证明；最终仍说明未做人工操作/听音的边界。

## 规则决策

1. 计时房仍为存活到出口开启，不强制杀光；提示使用“出口已开启”。
2. 血晶补给保留即时永久入账，文案统一为“立即入账”，同时计入本局收入。
3. 玩家直接命中武器共享暴击与冰冻；持续伤害不额外重复触发直接命中效果，流血不递归触发自身。汲取按实际有效伤害乘一次比例，包含致死伤害，遵守禁疗。
4. 玩家实际受伤、Boss 本战伤害、有效游戏时间各有唯一统计口径。累计击杀跨局持久，旧档无法恢复的分类历史不虚构。
5. 每局只允许死亡或胜利一个终态；死亡优先于尚未完成的 Boss 胜利协程，终局后不再开升级、换层或重复发奖。
6. 进化机会和每日随机公平性单列为设计风险：先核实当前产品承诺，在交付文档说明实际边界；不悄然把随机玩法改成强制必进化。

## 问题台账

状态定义：待修复 / 实现待验 / 回归通过 / 经核查撤回（需证据）。所有编号均须有结论。

| ID | 等级 | 缺陷 | 批次 | 状态 |
|---|---|---|---|---|
| 01 | P1 | 死亡与胜利竞态、重复结算 | 3 | 回归通过 |
| 02 | P1 | 石像鬼石化关闭自身倒计时 | 1 | 回归通过 |
| 03 | P1 | 初始手枪无正常升级入口 | 2 | 回归通过 |
| 04 | P1 | 放逐模式切换免费重抽 | 2 | 回归通过 |
| 05 | P1 | 唯一存档截断、无恢复 | 3 | 回归通过 |
| 06 | P2 | 普通传送门/换房可重入 | 3 | 回归通过 |
| 07 | P2 | 拾取/过场计时越过暂停 | 3 | 回归通过 |
| 08 | P2 | 临时拾取加成还原覆盖新成长 | 3 | 回归通过 |
| 09 | P2 | 换房遗留敌方弹丸 | 3 | 回归通过 |
| 10 | P2 | 特殊房中心出生与道具碰撞 | 3 | 回归通过 |
| 11 | P2 | 批量刷怪突破同屏容量 | 3 | 回归通过 |
| 12 | P2 | 出口已开误报房间已清 | 3 | 回归通过 |
| 13 | P2 | 银币拾取属性名错误 | 1 | 回归通过 |
| 14 | P2 | 击退伤害绕过防御/受伤钩子 | 1 | 回归通过 |
| 15 | P2 | 池化子弹丢失暴击引用 | 1 | 回归通过 |
| 16 | P2 | 覆写敌人不处理冻结 | 1 | 回归通过 |
| 17 | P2 | 多武器未接全局命中被动 | 1 | 回归通过 |
| 18 | P2 | 汲取双乘并遗漏致死命中 | 1 | 回归通过 |
| 19 | P2 | 汲取绕过禁疗 | 1 | 回归通过 |
| 20 | P2 | 流血到期残留强度 | 1 | 回归通过 |
| 21 | P2 | 转阶段移速被旧基值覆盖 | 1 | 回归通过 |
| 22 | P2 | 小亲王预警期已开始冲锋 | 1 | 回归通过 |
| 23 | P2 | 领主漏持续接触初始化 | 1 | 回归通过 |
| 24 | P2 | 环刃倍率快照和衰减遗漏 | 1 | 回归通过 |
| 25 | P2 | 进化攻击参数未兑现说明 | 1 | 回归通过 |
| 26 | P2 | 闪电坐标与连锁线覆盖 | 1 | 回归通过 |
| 27 | P2 | 小亲王无有效伤害仍回血 | 1 | 回归通过 |
| 28 | P2 | 升级退出动画重复领奖 | 2 | 回归通过 |
| 29 | P2 | 连续购买突破武器槽位 | 2 | 回归通过 |
| 30 | P2 | 购买满级物品扣钱无收益 | 2 | 回归通过 |
| 31 | P2 | 贪婪覆盖永久经验 | 1 | 回归通过 |
| 32 | P2 | Boss 奖励倍率不一致 | 3 | 回归通过 |
| 33 | P2 | 模态窗口后方打开暂停菜单 | 2 | 回归通过 |
| 34 | P2 | 缺血量重复累计为受伤量 | 3 | 回归通过 |
| 35 | P2 | 无伤 Boss 使用整局伤害 | 3 | 回归通过 |
| 36 | P2 | 累计击杀实际单局 | 3 | 回归通过 |
| 37 | P2 | 存活成就更新时间与检查断链 | 3 | 回归通过 |
| 38 | P2 | 暂停时间混入结算与榜单 | 3 | 回归通过 |
| 39 | P2 | 开局统计重置晚于事件 | 3 | 回归通过 |
| 40 | P2 | 满级成就错误挂在进化 | 3 | 回归通过 |
| 41 | P2 | 血晶收入成就漏记 | 3 | 回归通过 |
| 42 | P2 | 落榜成绩显示第一 | 3 | 回归通过 |
| 43 | P2 | 暂停冻结结算音乐/UI音效 | 4 | 回归通过 |
| 44 | P2 | 过渡动画覆盖新音量 | 4 | 回归通过 |
| 45 | P2 | 静音切曲反而抬高音量 | 4 | 回归通过 |
| 46 | P3 | 索敌选中死亡动画目标 | 1 | 回归通过 |
| 47 | P3 | 毒雾到期重复淡出且伤害不停 | 1 | 回归通过 |
| 48 | P3 | 经验逐颗截断 | 1 | 回归通过 |
| 49 | P3 | 祭坛楼层标签不刷新 | 2 | 回归通过 |
| 50 | P3 | 补给血晶入账文案不符 | 2 | 回归通过 |

## Task 1：战斗与玩家属性（20 项）

**Files:** scripts/enemies/*.gd、scripts/player/*.gd、scripts/weapons/*.gd；tools/pre_audio_combat_test.gd 与相关既有战斗测试。不能修改 main/UI/save/achievement。

**Interfaces:** 保留 take_damage(amount)、take_damage_with_knockback(amount, direction, force) 的现有调用兼容性；普通击退通过动态分派调用敌人自己的 take_damage。玩家新增实际受伤信号 `damage_received(amount: float)`，只在扣除护甲/护盾后真实损血时发出，供批次3接线。`on_dealt_damage(amount)` 参数统一为实际有效伤害，比例只在玩家乘一次。

- [x] 读取实现并添加回归；初版因引擎尚未就绪未取得修复前红灯，明确保留验证边界。第1轮审查整改已取得64通过/3失败→67通过/0失败的红绿证据。
- [x] 用统一生命周期处理石化/冻结/流血，转阶段修改基础移速后统一重算。冲锋蓄力结束再开启移动。
- [x] 统一直接命中暴击/冰冻且不重复触发；真实敌人与真实玩家验证 100 有效伤害、2%汲取恢复2HP，致死按剩余HP计，禁疗0HP。
- [x] 修复池化引用、领主接触区、小亲王实际伤害吸血、死亡目标过滤与毒雾一次性到期。
- [x] 环刃随玩家当前倍率/槽位变化更新；进化散射/范围/连锁/穿透使用现有配置的具体数值。
- [x] 贪婪采用增量或独立贡献；经验保留余数；银币读取 pickup_range_bonus。
- [x] 运行 pre_audio_combat_test、status_effect_test、combat_rules_test、build_enemy_rules_test、phase17_test、combat_visual_test、elite_affix_test；修复因正确契约变化而过时的断言，不能删除有效覆盖。
- [x] 独立审查本批差异，记录发现与修复。

关键断言：
```gdscript
# 真实玩家/敌人连接后的验收值（测试夹具负责清空自动攻击与无敌状态）
assert(is_equal_approx(player.current_hp - hp_before, 2.0))
assert(not gargoyle.is_petrified) # 超过现有石化时长后
assert(is_equal_approx(xp_separate, xp_merged))
```

## Task 2：成长入口与 UI 交易（8 项）

**Files:** scripts/core/item_catalog.gd、scripts/ui/upgrade_ui.gd、room_shop.gd、pause_menu.gd、blood_pact_ui.gd；必要的 weapon_manager.gd 容量与操作结果接口；tools/pre_audio_economy_test.gd。

**Interfaces:** 新增武器容量在 WeaponManager 权威检查；购买先验证可应用，再扣款/发奖；失败不扣款。升级每次展示只接受一个完成操作，首次提交同步禁用输入。

- [x] 添加手枪正常抽卡/商店可达、模式切换保牌、快速确认+Tab、3槽连续两次购买、满级不扣款的失败用例。
- [x] 补齐 pistol 目录/工厂并保持已持有才升级的池规则，禁止引入不可用图标资源。
- [x] 分离抽牌与卡片渲染；模式切换不消耗 RNG、不换手牌。
- [x] 交易前重验槽位/等级；成功后才扣款，其他货架条目根据最新状态禁用。底层新增武器也拦截超过4槽。
- [x] 模态打开时不额外弹出背后的暂停菜单；祭坛每次刷新楼层；补给文案改为立即入账。
- [x] 运行 pre_audio_economy_test、roguelite_ops_test、shop_test、ui_interaction_test、feedback_v2_test、phase17_test；独立审查。

关键断言：切换模式前后的武器/卡片 ID 序列相同；一次展示奖励回调计数为1；买第4槽后第5槽失败且银币不变；从初始手枪逐次合法升级到满级后可进化。

## Task 3：主流程、存档与统计（19 项）

**Files:** scripts/managers/main.gd、save_manager.gd、achievement_manager.gd、wave_manager.gd；scripts/map/game_room.gd；scripts/ui/game_over_ui.gd、floor_banner.gd、hud.gd；必要的 vampire_lord.gd 掉落接线与 upgrade_ui.gd 血晶记账；tools/pre_audio_lifecycle_test.gd、pre_audio_save_stats_test.gd、run_dungeon_smoke.gd。

**Interfaces:** 消费批次1 damage_received；按房间/运行生命周期令牌验证所有 await 后仍有效。GameOverUI 的每局结算只能提交一次。有效游戏时钟由 AchievementManager 单一维护，HUD 与结算共同读取。保留 `save_game() -> void` 及既有覆写签名；需要状态时新增 `try_save_game() -> bool`，由 save_game 包装调用。

- [x] 添加死亡→Boss击杀及Boss击杀→死亡两种竞态，必须等待挂起协程恢复后再确认唯一终态、奖励次数及无后续换层；补重复触门、暂停拾取倒计时、成长期间临时拾取恢复、批量刷怪剩余容量、特殊房出生无重叠用例。
- [x] 同步锁定终态和换房状态；await 后复核令牌/玩家有效性；所有清理包含敌方弹丸，Boss动态弹幕也加入统一组。
- [x] 拾取计时和横幅暂停语义一致；临时加成按独立贡献减回；宝箱/祭坛与出生点分离；按实时剩余容量生成；计时房提示改为出口开启。
- [x] 统一 Boss 掉落倍率及额外经验；初始化先重置统计；受伤信号按实际损血计；Boss 使用本战差值；满级事件在首次满级记账。
- [x] 累计击杀及分类持久化兼容旧档；第一局真实击杀记账并保存后，丢弃实例，用全新 SaveManager/AchievementManager 从同一隔离档读回，再运行第二局，断言总数、分类与成就。重载时不得调用会清档的 use_test_save_path。时间同步先于成就检查，结算前收入全部进入本局统计。HUD/榜单/成就使用相同暂停感知时间。
- [x] 保存先写临时文件并检查 flush/error，保留有效备份，替换失败保留可恢复文件；加载损坏主档时恢复备份，没有可用档时阻止静默覆盖。隔离测试清理三类文件。
- [x] 每日排名在裁剪前计算，或显示明确未上榜；不改变已有奖励防重规则。
- [x] 三层冒烟等待实际出口开启，经玩家触门入口推进，处理商店/祭坛等特殊房；允许缩短测试计时，但禁止直接调用 _enter_next_room 替代通行。通过真实伤害入口击杀 Boss，等待真实胜利结算信号及唯一奖励结果，不再以固定6秒和层号判断通关。
- [x] 运行新增2套测试、save_merge_test、save_isolation_test、dungeon_test、room_event_test、lifecycle_cleanup_test、abyss_ladder_test、run_dungeon_smoke；独立审查。

关键算例：HP100→90→80→85只计20；两局60击杀累计120；普通房挨打后Boss无伤可解锁；暂停2秒不增加有效时间；第9个差成绩不显示第一；重复show_game_over不增加局数；坏主档+有效备份能恢复。

## Task 4：音频框架（3 项）

**Files:** scripts/managers/audio_manager.gd；必要的 default_bus_layout.tres；tools/pre_audio_audio_test.gd、settings_menu_test.gd；按既定brief允许main_menu、character_select、game_over_ui、room_shop仅修改UI音效调用。最终未修改总线、AudioLib或素材。

- [x] 添加暂停中BGM过渡完成/UI音效运行、过渡中改音量、零音量切曲不抬高的回归。
- [x] BGM与UI需要的节点及Tween使用暂停中处理；用户音量与曲目fade独立相乘，避免旧Tween覆盖设置或解除静音。保留战斗暂停语义。
- [x] 运行新增音频测试、settings_menu_test；独立审查。自动断言验证参数/播放状态，不冒充人工听音。

## Task 5：总回归与交付

**Files:** tools/run_pre_audio_regression.py（可重复执行、超时与日志错误检查）、本文、docs/archive/qa/validation.md；启动脚本仅在确证需要时修复。

- [x] 校验官方便携引擎 SHA256，运行版本检查、导入/解析基线，记录失败。
  - 实际版本：4.7.2.stable.official.ed1daf0bf；ZIP SHA256 与官方一致。首次导入缺少字体缓存，导入结束后第二次执行同一 --headless --editor --path .tools/baseline --import 命令，退出0且无 ERROR/Parse Error。
- [x] 运行所有现有 *_test.gd 与新增回归及真实三层冒烟；最终35/35通过（pre-audio-full-post-review），每个子进程有超时，非零、SCRIPT ERROR、Parse Error 均判失败。
- [x] 独立审查全部更改，修复重要发现并补回归。整分支初审两项P2经33/11→44/0、8套通过及独立限定复审均ADDRESSED，最终Spec/Quality/VERDICT PASS。
- [x] 核对50项台账、两项玩法风险及新增回归项，每项记录处理证据。50个唯一ID，四批20/8/19/3完整覆盖；ID36追加总审查整改证据，全部关闭。
- [x] 检查 git diff --check、改动范围及新增静态资源引用，提供可重跑命令、计划与验证记录；没有做的人工视听/导出测试如实列明。

## 执行记录

- 2026-11-12：计划落盘。基线仅有原有未跟踪 nul。创建 repair/pre-audio-20261112 分支。尚无修复或引擎测试结果。
- 官方便携引擎：Godot 4.7.2-stable Windows x64，发布 URL https://github.com/godotengine/godot-builds/releases/tag/4.7.2-stable 。ZIP SHA256：731980f9608d61333e5baf54a2ef17210acc7a538446c0cb9969f002aca1e953。

- 第一批：20项修复及8套回归完成。独立审查发现两项P2遗漏，经第1轮修复与5套回归（集成67项）后限定复审Spec/Quality PASS，第一批关闭。证据 docs/archive/qa/task1-combat.md 与 .tools/qa/task1-review-r1-green/。第二批已启动。

- 第二批：8项修复完成，经济52项、要求六套及readability共7/7通过；生产独立审查Spec/Quality PASS。交叉回归定位两处旧测试抽牌入口，修正后build_enemy_rules 96/96及相关4/4套通过，限定复审ADDRESSED、Spec/Quality PASS。第二批关闭（累计28/50），第三批已启动。证据 docs/archive/qa/task2-economy.md 与 .tools/qa/task2-cross-fix/。

- 第三批阶段进展：.tools/qa/task3-final-guard-regression/ 九套exit0、errors=[]；生命周期69项、隔离42项、三层真实计时/物理触门/伤害击杀smoke通过。仍未关闭：父会话发现分类累计成就、结算血晶记账、主档缺失时备份恢复缺口及若干明确要求的行为测试不足，已以 .tools/qa/task3-closeout-brief.md 交新实现者集中收尾。独立审查尚未开始，完成数仍28/50。

- 第三批收尾实现完成：10/10套回归通过，先前分类累计/结算收入/缺主档恢复及专项测试缺口均已补齐，报告见 docs/archive/qa/task3-lifecycle-save.md 第119行起。整批独立审查复现两项P2遗漏：最终Boss真实经验仍触发升级暂停胜利、未开局主菜单累计有效时间并解锁生存成就。已交唯一实现者整改，仍标实现待验，未关闭19项。七套交叉回归中六套直接通过，ui_interaction旧文案改为精确检查“出口已开启 · 走传送门”后单套通过（task3-cross-ui-copy-fix），独立限定复审PASS；两项生产P2现已整改：完整红测74通过/29失败，修后终态时钟103/0及相关5/5套通过（task3-review-r1-green）；独立限定复审进行中，未提前关闭。

- 第三批关闭：限定复审VERDICT/Spec/Quality均PASS，两项P2均ADDRESSED；此前整批认可结论与UI测试复审复用。完整红测74/29→103/0，相关5/5套通过（task3-review-r1-green）。19项全部回归通过，累计47/50；第四批ID43–45音频已启动。直接restart/深渊continue本次仅静态核对，人工视听未验收。

- 第四批关闭：ID43–45独立Spec/Quality/VERDICT PASS；音频54/0、范围6/6套通过，settings真实渲染。累计50/50项分批验收关闭；最终34套全量回归与整分支总审查进行中，尚未宣称整任务完成。

- 首次最终全量：pre-audio-full-final 34/34通过，exit0、errors=[]、无超时且清理成功，settings/VFX真实渲染。整分支总审查仍FAIL：死亡演出期间分类引用可变导致总数/分类快照不一致；Boss召唤蝙蝠成就事件重复，新增分类永久化消费了旧重复源。ID36重开，当前49/50关闭。两项先以真实入口复现，再由唯一writer最小整改、独立复审和重跑最终全量；不得以旧34/34替代新增路径验收。

- 最终结案：ID36两项总审查遗漏完成33/11→44/0真实红绿测试，指定8套通过，独立复审两项均ADDRESSED、Spec/Quality/VERDICT PASS。源码冻结后最终35/35套通过，全部exit0、errors=[]、无超时、清理成功；运行器单测8/8通过，git diff --check通过。50/50台账完整关闭。人工试玩/听音/视觉/导出包未验证，两项玩法设计风险已记录；未提交、未推送。
