# 整分支总审查整改：终态击杀截止与召唤记账

## 结果

两项 P2 已完成实现、指定回归及独立限定复审；**两项均ADDRESSED，Spec/Quality及整分支代码审查VERDICT均PASS**。复审读取实际红绿日志与三个生产快照，没有重复启动Godot；修后全量35套由父会话另行执行。新套件修复前 33 通过 / 11 失败，修复后 44 通过 / 0 失败；指定八套全部 exit_code=0、errors=[]、timeout=false、cleanup_ok=true。未提交、未推送、未暂存。

- 分支 repair/pre-audio-20261112；基线 727e3ad。
- 引擎为已有 .tools/godot/Godot_v4.7.2-stable_win64_console.exe，实际版本 4.7.2.stable.official.ed1daf0bf。没有安装或下载引擎。
- 修复前当前工作区三个生产文件快照：.tools/qa/final-review-kills-before/。这不是基线版本，而是本轮接手时的已修复分支内容。

## 根因、最小变更与事件契约

### 1. 死亡后的真实流血污染结算

main 在死亡入口同步保存 wave_manager.total_kills 标量，但 kill_categories 原来引用 AchievementManager 的可变字典；等待 0.8 秒期间，真实敌人仍运行流血 process。finish_run 原来仅停时钟，所以迟到击杀既增加类别又检查成就，造成结算总数和类别不一致。

- scripts/managers/achievement_manager.gd:213：增加 _run_finished 标志。
- scripts/managers/achievement_manager.gd:223：finish_run 同步关闭击杀与时钟；is_run_finished 供波次总数入口使用同一个截止状态。
- scripts/managers/achievement_manager.gd:238：start_new_run 重开击杀入口；不把普通房间停止刷怪误当整局结束。
- scripts/managers/achievement_manager.gd:281：record_kill 在终态后直接返回，不增加计数、不检查或保存迟到击杀成就。
- scripts/managers/main.gd:1000、scripts/managers/main.gd:1184：胜利、死亡结算类别分别 deep duplicate，避免结算载荷共享运行态字典。

截止定义：沿用 main 在真实玩家死亡或最终 Boss 胜利同步调用 finish_run 的时点；普通房/非最终 Boss 的 stop 仅停止刷怪，不关闭击杀。main 场景退出已有 finish_run 同样关闭离局后的记账。仅击杀被闸门拦截，不禁止 record_boss_kill、record_floor_cleared、record_dungeon_clear、record_crystals_earned 等合法结算事件。

### 2. Boss 召唤蝙蝠重复分类

vampire_lord 的 bat.enemy_died 回调原来调用 record_external_kill，后者既增加波次总数又调用 ach.record_kill；随后 EnemyBase._die 再调用 _record_kill_for_achievement，形成一只蝙蝠总数 +1、类别 +2。

- scripts/managers/wave_manager.gd:591：普通敌人死亡仍减少 enemies_alive，统计转入共用总数入口。
- scripts/managers/wave_manager.gd:595：record_external_kill 只负责总数和 enemy_killed，按 AchievementManager 同一个终态标志拦截迟到击杀；不再重复记成就。保留原可选 String 类型参数以兼容调用。
- 生产调用方已检索：原外部调用仅 scripts/enemies/vampire_lord.gd:532–533 的召唤蝙蝠接线；新增内部调用是 wave_manager._on_enemy_died。tools 中没有旧 record_external_kill 测试契约需要修改。
- 生产 ach.record_kill 调用现在唯一位于 scripts/enemies/enemy_base.gd:628；exploder 特殊死亡也复用该 helper。未修改 EnemyBase、vampire_lord 或其他敌人生产文件。

### 最终 Boss 顺序兼容

scripts/enemies/vampire_lord.gd:612–617 的真实死亡顺序为 is_dead → enemy_died → boss_defeated。main.gd:875–876 明确 Boss 不计入普通波次总数，Boss 独立统计由 main.gd:938–945 的 record_boss_kill / floor / income 完成。保留此既有口径，不新增普通 Boss 分类。

测试观察真实两个死亡信号的顺序，验证最终致死命中仍进入 victory、Boss 成就仍解锁、+120 血晶只发一次、延迟通关成就及结算收入继续入账。没有简单禁止 finish_run 后所有 record 方法。

## 永久测试与证据

新增 tools/pre_audio_kill_accounting_test.gd（LF）：

- :28 真实 main 夹具：等待开场，停止自动刷怪/攻击/物理移动，仅在待验窗口前清场；敌人 process 保留。
- :55 新 SaveManager 离树设置同一隔离路径后 load_game，不调用会清档的 use_test_save_path，不复用内存字典冒充重载。
- :73 死亡截止：隔离历史夹具总数/吸血鬼类别98；真实击杀一只达99，重复伤害不重计；另一只真实受伤至1HP并 apply_bleed，真实玩家 take_damage 死亡后保留流血自然 process，在结算前发出 enemy_died。断言波次、成就计数及类别都冻结在1，百杀成就不解锁，真实结算与新管理器重载均为99。下一局真实击杀达到100并合法解锁，两次真实结算最终磁盘总数/类别均100。
- :121 真实最终 Boss 召唤两只蝙蝠：第一只正常致死与重复伤害恰计1；真实 Boss 致死验证事件次序、独立成就与120奖励；Boss 清场 queue_free 尚未执行前对第二只施加真实致死伤害，断言胜利截止后不计入两套账。等待真实胜利结算，再新管理器重载，磁盘只含1只蝙蝠。
- :169 隔离初始化失败即退出；结束核验本套主档及 .tmp/.bak 已清理。

红测 .tools/qa/final-review-kills-red/pre_audio_kill_accounting_test.log：

- :19–28 前置路径成立：真实伤害、99阈值、活跃流血、玩家先死、流血在结算前自然致死。
- :24、:26 错误解锁两项百杀成就；:29–38 截止与持久化断言失败。
- :68–70 召唤蝙蝠波次计1而成就/类别重复；:87 胜利后迟到蝙蝠也污染记账。
- :105 汇总 33/11。exit=1；11条错误均为行为断言，没有 SCRIPT ERROR / Parse Error。

绿测同名日志位于 .tools/qa/final-review-kills-green/，相应断言全部通过，:105 汇总44/0。没有修改或覆盖红测日志，没有为了转绿降低断言。

## 实际执行命令

工作目录 D:/mydev/games/Vampire-Hunter-Roguelite；运行器逐套独立进程串行，无同名测试并发，每套 timeout 180。

红测实际命令：

    python tools/run_pre_audio_regression.py --suite pre_audio_kill_accounting_test --label final-review-kills-red --timeout 180

绿测实际命令：

    python tools/run_pre_audio_regression.py --suite pre_audio_kill_accounting_test --suite pre_audio_stats_integration_test --suite pre_audio_terminal_clock_test --suite pre_audio_lifecycle_test --suite pre_audio_save_stats_test --suite save_isolation_test --suite combat_rules_test --suite run_dungeon_smoke --label final-review-kills-green --timeout 180

| 套件 | 秒数 | 结果 |
|---|---:|---|
| pre_audio_kill_accounting_test | 20.17 | 44/0 |
| pre_audio_stats_integration_test | 30.01 | exit0, errors=[] |
| pre_audio_terminal_clock_test | 52.86 | exit0, errors=[] |
| pre_audio_lifecycle_test | 40.12 | exit0, errors=[] |
| pre_audio_save_stats_test | 2.83 | exit0, errors=[] |
| save_isolation_test | 3.55 | exit0, errors=[] |
| combat_rules_test | 16.26 | exit0, errors=[] |
| run_dungeon_smoke | 53.92 | 三层真实通关，fail=0 |

完整机器结果及每套完整日志保存在 .tools/qa/final-review-kills-green/results.json 和同目录 *.log；运行器最终 exit0、8/8。smoke 日志:253 为最终 Boss +120，:259–261 为真实胜利、唯一结算与 fail=0。

另执行 git diff --check：exit0，仅既有文件的 LF→CRLF 提示，无 whitespace error。使用 git diff --no-index 对三个修改前快照比较，只出现本文所列增量；其 exit1 表示存在预期差异，不是测试失败。三个修改生产文件读取核验 bare LF 均0，保持 CRLF。

## 隔离、假设和未验边界

- 新套件仅使用 user://test_pre_audio_kill_accounting_test.json、user://test_pre_audio_kill_accounting_test_summon.json 及其 .tmp/.bak；不加载真实存档、不输出真实存档内容。
- 指定 save_isolation_test 既有只读摘要检查通过（绿测日志:45–58），没有把真实存档载入测试进度。此检查只证明该套件前后摘要不变，不冒称八套运行统一外部包围采样。
- 保持现有 Boss 独立统计、终态后合法通关/收入入账契约。既有未 start_new_run 的离树 AchievementManager 兼容测试仍通过，未扩大为“所有菜单事件都禁用”的新需求。
- 全部为 headless；未做人工游玩、视听或导出验证。没有重新运行此前全部34套，也不宣称穷举全部同帧重入或所有敌人 DoT 类型。
- 本轮只改三个 Manager、新增一个永久套件和本专项报告；未改计划、validation、既有批报告、音频、nul，未操作 git stage/commit/push。
- 无实现阻塞；本轮独立复审由父会话安排。仅声称实现与指定回归完成，不声称整分支最终审查通过。
