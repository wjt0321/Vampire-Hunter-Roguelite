# Task 3：生命周期、存档与统计 QA

> 当前结论：第三批19项分批审查与后续终态整改均已通过；总审查再次发现的ID36两处统计遗漏，也已补修并独立复审PASS，详见 final-review-kills.md。下文保留当时的实现/失败/收尾记录，全项目最终状态以 validation.md 为准。

## 结论

**本 worker 的第三批六组收尾交付 DONE，待父会话独立审查。** 最终命令 task3-closeout-final 退出 0，原 9 套加新增 integration 共 10/10 套件通过，全部 errors=[]、timeout=false、cleanup_ok=true。生命周期 69 项、存档统计 142 项、统计集成 69 项通过，三层真实计时/物理触门/Boss 伤害通关仍通过。此前明确遗漏的统计、恢复、掉落和暂停专项均已补齐，详见末尾收尾记录。人工体验验收及非必需穷举边界仍保留，不等同于整个项目最终验收。未提交、未推送；原有未跟踪 nul 未处理。

## 环境与隔离

- 分支：repair/pre-audio-20261112；基线 727e3ad；Godot 4.7.2.stable.official.ed1daf0bf。
- 运行器：python tools/run_pre_audio_regression.py，套件串行、独立进程。存档行为测试使用 user://test_* 隔离档；未读写真实存档内容。save_isolation_test 只计算真实主档及 .tmp/.bak 的只读摘要，不解析或输出内容；摘要结果见下文。
- 保留既有 dirty worktree 变更及快照 .tools/qa/task3-before/；报告不把前批改动归到本批。

## 逐项证据

| ID | 验收项 | 当前证据与状态 |
|---|---|---|
| 01 | 死亡/Boss 胜利竞态、唯一终态、挂起协程恢复后不重复奖励/换层 | 首层与最终层分别执行死亡→Boss、Boss→死亡，均经真实 take_damage；释放结算自身暂停后再等待协程恢复，验证死亡唯一终态、楼层/room token 不变、奖励及 total_runs 防重。69 项生命周期套件通过。其他 await 时点及第二层组合未穷举。 |
| 05 | 原子存档、有效备份、失败保留恢复文件、坏档保护 | 主档缺失时分别从有效 .bak/.tmp 恢复并再次保存不丢进度；坏主档有效备份恢复；无效主档/孤立伴随文件拒绝覆盖；目录占用触发 rename 失败后 tmp 保留并可新实例恢复；切换测试路径清除 _load_blocked，void 包装兼容。专项通过。未模拟磁盘耗尽/flush 故障。 |
| 06 | 门/换房重入与重复触门 | 独立房间重复调用触门 handler 只发一次信号；smoke 物理重叠进入真实普通门/岔路门并完成三层。多门同帧竞争与主场景重复物理穿门专项未覆盖。 |
| 07 | 拾取/横幅计时与暂停 | 原拾取暂停/成长断言保留；新增横幅淡入后暂停 1.3 秒，保持显示和透明度，恢复后完成剩余 hold/fade。通过。 |
| 08 | 临时拾取范围独立贡献恢复 | 拾取临时贡献 +260 期间调用 player.apply_upgrade("pickup_range")，恢复只移除 260，保留正常成长。通过。 |
| 09 | 换房/终局清理敌方弹丸（含 Boss 动态弹幕） | 真实普通敌方弹丸与 Boss 动态弹幕，经已连接的正式触门入口、真实 Boss 死亡、真实玩家死亡三种路径清理，均断言无残留。补齐死亡入口清理。通过。 |
| 10 | 宝箱/祭坛与出生点分离、摆位不重叠 | 分别真实创建祭坛/宝箱房，断言非空占位、全部占位矩形避开出生安全区及彼此间距。通过；未穷举随机布局和全部房型。 |
| 11 | 批量刷怪按实时剩余容量限制 | 填满实时 enemies 组后拒绝生成；只留一格时真实 _spawn_enemy 仅补一只，再次立即调用仍不超限。通过；填充节点为容量夹具。 |
| 12 | 计时房存活到出口开放，提示准确 | smoke 把 wave_duration 缩短至 0.25 秒，等待 _process 正常完成波次并开放出口；不再直接 emit wave_completed。三层流程通过。 |
| 32 | Boss 掉落倍率及额外经验倍率统一 | 修复 Boss._ready 覆盖主流程倍率：生成后应用 effective_loot_mult。倍率 1/1.5/2 经真实 Boss take_damage 死亡，实际经验资产总值为 200/300/400（含五份额外经验与自动合并），银币为 12/18/24。通过。 |
| 34 | 玩家实际损血唯一统计口径 | 实际 player.take_damage 两次并 heal：HP100→90→80→85，主流程 damage_received 接线只计20。护甲/闪避/护盾/无敌影响已清除。通过。 |
| 35 | Boss 无伤成就只看本战伤害差值 | 普通房实际损血20后进入真实第二层 Boss，待登场结束用 take_damage 击杀；总损血仍20，本战无伤并解锁 flawless_victory。通过。 |
| 36 | 累计击杀、分类跨局持久，旧档兼容 | 替换旧伪累计夹具：两局各60只真实吸血鬼 take_damage 死亡，生产接线记账，提交真实 run_stats；局间销毁并新建两类管理器从同一隔离档读取，第二局第39/40杀验证累计99/100阈值；最终磁盘总数及分类均120。修复跨局分类与旧 run_stats 分类回写；旧档321总数保留且分类不虚构。通过。 |
| 37 | 存活时间先更新再检查成就 | 有效时钟置于899.99秒边界，由真实 process 跨越900；解锁通知中同步观察 survival_time==900。通过。 |
| 38 | 暂停时间不进入 HUD/结算/榜单/成就 | 暂停2秒时 HUD 与成就有效时钟不变；实际死亡入口向结算和每日榜单交付同一125秒，HUD显示02:05，结算显示2:05。修复死亡等待期间时钟继续增长，终态停止有效时钟，新局恢复。通过。 |
| 39 | 开局统计在事件发生前重置 | 旧局脏统计预置后，在主场景首个真实 weapon_added 信号内观察击杀/收入已清零，武器列表只有本局开局手枪。通过。 |
| 40 | 首次正常升级满级即时检查成就 | 复用现有 weapon_leveled_up 信号，在普通 add_weapon 升级首次满级即时记账；三种武器正常升级达成原有三满级阈值且进化数0，重复满级升级被拒绝。通过。 |
| 41 | 血晶收入完整进入本局成就统计 | GameOverUI 按 end_run 与 record_daily_run 返回的实际收入统一记账，先于成就列表生成。四次真实补给提交各100（重复点击不增加）+第二层真实Boss60+结算+每日50，与余额增量一致；普通495+5和每日结算跨500均即时展示 rich_hunter；重复 show 不增加余额/局数/成就/收入/榜单。通过。 |
| 42 | 排名裁剪后差成绩不伪装第一且奖励防重不变 | 新测试加入截断榜断言未上榜/不是第一；通过。 |

### 代码决策与兼容

- save_game() -> void、原有虚方法签名保持；新增 try_save_game() -> bool。
- 玩家损血消费 damage_received(amount)；血晶补给已由第二批实时入账并记本局收入，本批没有重复接线。
- 计时房仍按存活开放出口，不改为强制清怪。宝箱进化机会、每日随机不是本批强制改造目标，仍有随机机会不均的设计边界。
- 分层 Boss 击败不是整局胜利；整局胜利终态只在最终层锁定。真实三层 smoke 已完成最终结算。新增首层死亡竞态红测发现：旧入口只在最终层拒绝死亡后的 Boss 奖励；现将 _terminal_state == "death" 检查提前到所有楼层共用入口。

## 红测与绿测

有效红测（实现前）：

    python tools/run_pre_audio_regression.py --suite pre_audio_lifecycle_test --suite pre_audio_save_stats_test --label task3-red2

运行器退出1：4项生命周期行为断言失败，存档状态 API 缺失；无解析错误。这是有效行为红测。此前 task3-red 是夹具无主场景 autoload 上下文的无效测试，不作为红测证据。

解析修复尝试 task3-green-attempt1 退出1，属于脚本解析失败，不算行为回归。夹具修正、坏档子进程隔离后，两项新增测试通过：

    python tools/run_pre_audio_regression.py --suite pre_audio_lifecycle_test --suite pre_audio_save_stats_test --label task3-save-stats4

运行器退出0，2/2套件通过，errors=0。后续最终稳定回归：

    python tools/run_pre_audio_regression.py --suite pre_audio_lifecycle_test --suite pre_audio_save_stats_test --suite save_merge_test --suite save_isolation_test --suite dungeon_test --suite room_event_test --suite lifecycle_cleanup_test --suite abyss_ladder_test --label task3-final-regression

运行器退出0，8/8套件通过，所有 suite exit=0、errors=0。room_event_test 与 abyss_ladder_test 曾因 run_stats.kill_categories 缺省报错，添加兼容初始化后均通过。

指定回归含 smoke 的首次运行 task3-regression1：4/7通过；room_event_test、abyss_ladder_test 的兼容错误随后修复，smoke 当时还直接跳房并调用 _on_boss_defeated，结果层间终态锁死。修正终态后 task3-regression2 两个兼容套件通过，旧 smoke 仍因等待预算/跳房行为失败。改写 smoke 后多轮结果见 .tools/qa/task3-smoke-real1 至 .tools/qa/task3-smoke-real9；所有尝试均未达到三层完成条件，最终以失败作为未验证边界保留。 修正 smoke 等待阶段后最后命令 task3-smoke-final2 仍失败：运行器退出1、164.52秒，portal handler 8项等待失败。这是历史失败，不是当前最终状态。下文列出随后修复与最终验证证据。

## 收尾前闭环与历史九套证据

- 旧 smoke 的“8 个 portal handler 失败”来自同一个休息房失败后循环重复等待。直接发 pact_chosen 信号绕过 _choose()，modal 未关闭且暂停持有者未释放，物理重叠不触发。测试现在走 blood_pact._choose("rest") / mutation_ui._choose("leave") 并检查关闭；将玩家移至门后等待物理帧，失败即停止该流程。
- 战斗房出口改由 WaveManager 正常计时触发；没有直接调用 _enter_next_room()、_on_boss_defeated() 或 emit wave_completed 来证明通关。加速仅针对测试波次/拾取窗口；Boss 等待真实登场结束后走 take_damage()。
- task3-smoke-timed-wave（55.52 秒）、task3-final-timed-regression（54.22 秒）与 task3-final-guard-regression（57.43 秒）三次不同随机房序均通过。合计实测 combat/rest/shop/treasure/boss；本轮这三次未抽到 mutation/fog/mirror，不能当作这些完整分支已验收。祭坛/宝箱摆位另有专项覆盖。
- task3-terminal-clean-red：40.12 秒、exit=1，仅首层 death-before-Boss 奖励断言失败，无脚本解析/运行时错误。修改 main.gd 统一入口保护后，最终 lifecycle 69/69 通过（40.12 秒），包含首层/最终层两种竞态、真实死亡结算、等待恢复后无换层/房间替换、重复终态回调不再奖励或增加局数。
- 早期 task3-timed-wave-and-lifecycle 因测试把 void 协程当值保存而报错并触发工具 120 秒墙钟；task3-terminal-real-red 因测试访问死亡后释放的 player 而有脚本错误。这两轮不作为有效行为红测。后续已修正测试并独立重跑。

最终命令：

	python tools/run_pre_audio_regression.py --suite pre_audio_lifecycle_test --suite pre_audio_save_stats_test --suite save_merge_test --suite save_isolation_test --suite dungeon_test --suite room_event_test --suite lifecycle_cleanup_test --suite abyss_ladder_test --suite run_dungeon_smoke --label task3-final-guard-regression

运行器 exit=0，9/9；各套件 errors=[]、timeout=false、cleanup_ok=true。机器结果在 .tools/qa/task3-final-guard-regression/results.json。

| 套件 | 秒数 | 结果 |
|---|---:|---|
| pre_audio_lifecycle_test | 40.12 | 69 项通过 |
| pre_audio_save_stats_test | 1.88 | exit=0 |
| save_merge_test | 0.95 | exit=0 |
| save_isolation_test | 3.55 | 42 项通过 |
| dungeon_test | 0.96 | exit=0 |
| room_event_test | 14.39 | exit=0 |
| lifecycle_cleanup_test | 1.05 | exit=0 |
| abyss_ladder_test | 3.09 | exit=0 |
| run_dungeon_smoke | 57.43 | fail=0；逐层奖励及唯一结算通过 |

日志定位：run_dungeon_smoke.log:82、169、257 为 +30/+60/+120；263、264 为胜利 UI 与单次结算。pre_audio_lifecycle_test.log:57 起是四种竞态，140 为 69/0 汇总。以上均位于最终日志目录。

git diff --check 退出 0；仅提示已有工作区若干文件下次 Git 操作可能 LF→CRLF，不是 whitespace error。

## 真实存档隔离摘要契约

save_isolation_test.log:11 起记录：

| 路径 | 运行前 / 运行后 |
|---|---|
| user://save_data.json | SHA256 f7ced8b0e0e5cef81d39e366cf97ec4406c85e6d1c0ec88e6d2c9d4fb9ecf2e5（相同） |
| user://save_data.json.tmp | <missing> / <missing> |
| user://save_data.json.bak | <missing> / <missing> |

隔离档保存、成就触发保存、场景工具端到端运行及整个隔离测试完成后均比对摘要；测试主档、.tmp、.bak 清理断言通过（日志52–58）。此证据覆盖该隔离套件前后，不声称是整次回归运行外部包围的摘要采样。最终 task3-closeout-final/save_isolation_test.log:11–58 再次确认相同摘要与 sidecar 缺失状态，42项通过。真实存档未加载为测试进度，未输出其内容。真实 sidecar 缺失，不能推论已实测“真实 sidecar 预先存在”场景。

## 未完成 / 风险

- 未做独立代码审查：本 worker 不派生任务，交父会话安排。
- 未做人工游玩、画面视听或声音试听；全部上述套件为 headless，不能替代体验验收。
- 未穷举所有 await 恢复时点、第二层竞态、多门同帧竞争及全部随机特殊房路线。竞态夹具通过 _enter_boss_room 建立真实 Boss 接线，不把该夹具称为完整通关；完整通关依据独立 smoke。
- 上述指定统计/恢复/掉落专项已由本次 closeout 两套测试完成；详细证据见末尾收尾记录。
- rename 失败已用隔离目标目录占用实测，120次真实敌人死亡已实测。未模拟磁盘耗尽/flush 失败；真实 sidecar 预先存在场景未构造（禁止改动真实档），隔离 sidecar 恢复和清理已测试。
- 随机宝箱进化机会与每日随机公平性保持原设计边界；未改为必进化。

## 文件范围

第三批累计生产修改：scripts/managers/main.gd、save_manager.gd、achievement_manager.gd、wave_manager.gd、scripts/map/game_room.gd、scripts/ui/game_over_ui.gd、floor_banner.gd、hud.gd、scripts/enemies/vampire_lord.gd。测试新增/修改：tools/pre_audio_lifecycle_test.gd、pre_audio_save_stats_test.gd、pre_audio_stats_integration_test.gd、run_dungeon_smoke.gd、save_isolation_test.gd。报告 docs/qa/pre-audio/task3-lifecycle-save.md 已更新。未提交。本次 closeout 增量只涉及下节列出的四个生产文件、两套测试与本报告。

## 第三批 closeout 六组收尾记录

### 实现与测试范围

- scripts/managers/achievement_manager.gd:212：开局保存持久分类快照，分类成就检查使用快照加本局分类，避免结算持久化后重复累加；record_kill 无条件回写分类字典；finish_run 停止有效游戏时钟，start_new_run 恢复。
- scripts/managers/save_manager.gd:142：主档缺失时也按 .bak、.tmp 顺序恢复；有无效文件但无有效恢复来源时阻止覆盖；use_test_save_path 复位 _load_blocked。保持 save_game() -> void 和 try_save_game() -> bool，未改变保存 API。
- scripts/managers/main.gd:246：连接既有 weapon_leveled_up，在正常升级首次满级时统计，移除进化入口的满级统计，三种满级阈值不变；Boss 添加到场景、完成 _ready 后应用 effective_loot_mult；死亡清敌弹，死亡/最终胜利停止统计时钟。
- scripts/ui/game_over_ui.gd:117：按普通和每日结算实际返回收入记录血晶，在生成成就列表之前完成，沿用单次结算保护。
- tools/pre_audio_save_stats_test.gd:35：替换伪累计测试，两局各60次真实吸血鬼死亡并重建管理器读档；覆盖累计阈值、旧档、主档缺失恢复、无效档保护、替换失败与路径复位。
- tools/pre_audio_stats_integration_test.gd:50：新增主流程集成，覆盖实际损血与本战无伤、开局事件顺序、普通满级、存活阈值、暂停/HUD/榜单/终态时间、收入与重复 UI、真实弹丸清理、掉落倍率、横幅暂停。
- 保留既有生命周期及三层 smoke，不修改回归运行器、计划、validation、nul、baseline/task3-before 快照。四个生产文件保持 CRLF；两套测试与本报告保持 LF。

### 本轮红绿命令与结果

以下命令均已执行，日志目录与 --label 同名，位于 .tools/qa/ 下。红测中的夹具问题单独列出，不作为生产缺陷证据。

	a) python tools/run_pre_audio_regression.py --suite pre_audio_save_stats_test --suite pre_audio_stats_integration_test --label task3-closeout-red --timeout 90
	b) python tools/run_pre_audio_regression.py --suite pre_audio_save_stats_test --suite pre_audio_stats_integration_test --label task3-closeout-red-clean --timeout 90
	c) python tools/run_pre_audio_regression.py --suite pre_audio_save_stats_test --suite pre_audio_stats_integration_test --label task3-closeout-green1 --timeout 90
	d) python tools/run_pre_audio_regression.py --suite pre_audio_save_stats_test --label task3-closeout-probe-diagnostic --timeout 20
	e) '.tools/godot/Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tools/pre_audio_save_stats_test.gd -- --failure-probe
	f) python tools/run_pre_audio_regression.py --suite pre_audio_save_stats_test --suite pre_audio_stats_integration_test --label task3-closeout-green2 --timeout 90

- a 退出1。存档统计7项断言失败，暴露分类跨局、旧字典回写及主档缺失恢复问题；其中故障探针汇总还受日志编码影响，不能把7项全部算生产缺陷。集成夹具在 add_child 前设置 current_scene，引擎报场景父节点错误及空 current_scene 的 call_deferred 错误，此集成轮不作为干净红测。
- b 退出1。修复场景夹具后，集成52通过/17失败，无脚本或解析错误，暴露普通满级、结算收入、死亡等待时钟、死亡弹丸及 Boss 倍率缺口。17项中也包含两处夹具错误：经验宝石会自动合并，不能强制六个独立节点；第一层 Boss30 加补给400和每日50达不到500。后续改为实际经验总资产断言、真实第二层 Boss60，未降低生产验收阈值。此轮分类/恢复实现已修，存档只剩故障探针汇总1项失败。
- c 退出1。两套各剩1项失败：存档子进程中文 stdout 编码导致精确错误匹配失败；每日阈值夹具金额不足500。d 退出1，明确诊断为 Windows 子进程中文乱码；e 子进程退出0，故障行为断言通过并输出 FAILURE_PROBE_OK。
- 故障探针改为子进程 --log-file 写入 user://test_* UTF-8 日志，读取后清理；严格校验 exit=0、成功标记和三类预期错误计数 [3,3,1]（坏主档保护、坏档不可恢复、替换失败），任何额外 ERROR、SCRIPT ERROR、Parse Error 或失败断言均拒绝，不吞掉任意脚本错误。
- f 退出0，2/2；存档142/0（2.82秒），集成69/0（29.90秒），全部 errors=[]、timeout=false、cleanup_ok=true。

### 最终完整回归

	python tools/run_pre_audio_regression.py --suite pre_audio_lifecycle_test --suite pre_audio_save_stats_test --suite save_merge_test --suite save_isolation_test --suite dungeon_test --suite room_event_test --suite lifecycle_cleanup_test --suite abyss_ladder_test --suite run_dungeon_smoke --suite pre_audio_stats_integration_test --label task3-closeout-final --timeout 180

运行器退出0，原9套+新增1套，共10/10。所有 suite exit_code=0、errors=[]、timeout=false、cleanup_ok=true。机器结果：.tools/qa/task3-closeout-final/results.json。

| 套件 | 秒数 | 实际结果 |
|---|---:|---|
| pre_audio_lifecycle_test | 40.12 | 69通过 / 0失败 |
| pre_audio_save_stats_test | 2.93 | 142通过 / 0失败 |
| save_merge_test | 0.96 | PASS |
| save_isolation_test | 3.54 | 42通过 / 0失败 |
| dungeon_test | 0.96 | PASS |
| room_event_test | 14.39 | PASS |
| lifecycle_cleanup_test | 1.05 | PASS |
| abyss_ladder_test | 3.09 | PASS |
| run_dungeon_smoke | 54.39 | 三层真实通关，fail=0 |
| pre_audio_stats_integration_test | 30.64 | 69通过 / 0失败 |

最终日志定位（以下文件均在 .tools/qa/task3-closeout-final/）：

- pre_audio_save_stats_test.log:122–130：第二局39/40杀对应累计99/100，两种成就恰在100解锁；155：磁盘120总数与120吸血鬼分类；175：故障探针 exit=0、expected_diagnostics=[3,3,1]、marker=true；188：142/0。
- pre_audio_stats_integration_test.log:26、39、56：三种正常满级即时记录；73：实际损血20；98–100：普通房受伤后本战无伤、Boss收入一次、弹丸清理；108–112：共同125秒、每日收入/成就/防重；118：普通结算5血晶；136：死亡清敌弹；152–167：三个倍率实际掉落；168–170：横幅暂停与69/0汇总。
- pre_audio_lifecycle_test.log:140：69/0；run_dungeon_smoke.log:84、171、257：三层奖励+30/+60/+120；263–265：真实胜利 UI、唯一结算、fail=0。
- save_isolation_test.log:11–58：真实主档 SHA256 与上文相同，.tmp/.bak 均缺失，隔离存档与成就保存、工具场景运行后摘要不变；61：42/0。只覆盖隔离套件的前后采样，不声称整次十套运行被统一摘要采样包围。

六组 closeout 清单完成，无实现阻塞。仍由父会话安排独立审查；headless 不替代人工体验验收。磁盘耗尽/flush 故障、所有 await 与随机房序穷举、真实 sidecar 预存在情况属于上文列明的非必需边界。

### 交叉回归整改：出口开启文案断言

父会话交叉7套 task3-cross-batches 为6/7，唯一 ui_interaction_test 失败。已读取 .tools/qa/task3-cross-batches/ui_interaction_test.log:85、163：真实主流程输出“出口已开启 · 走传送门”，旧测试却期待“第 4 波已清 · 走传送门”，共1项失败。main.gd:359–365 的实际提示符合计划 ID12，计时结束只表示出口开启，不能宣称怪物已清光。

本次仅修改 tools/ui_interaction_test.gd:365 起的出口提示断言及相邻注释/标签：仍调用真实 main_scene._on_wave_completed(4)，仍读取 hud.wave_label.text，并精确匹配完整“出口已开启 · 走传送门”；没有改成宽泛中文匹配，也没有直接向 HUD 写入期望值。保留传送门状态备份/恢复和第二批已有模态契约（已有升级模态时拒绝背后打开暂停菜单）。保持测试 CRLF、报告 LF；没有修改生产代码。

执行命令：

	python tools/run_pre_audio_regression.py --suite ui_interaction_test --label task3-cross-ui-copy-fix --timeout 180

结果：运行器退出0，1/1通过，耗时6.89秒；exit_code=0、errors=[]、timeout=false、cleanup_ok=true。机器证据：.tools/qa/task3-cross-ui-copy-fix/results.json。git diff --check 退出0，仅既有文件 LF→CRLF 提示，无空白错误。未重跑已通过的另外6套；本次不声称重新执行了全部交叉7套。无阻塞，测试增量待独立审查者复核。

## 第三批独立审查整改 R1：终态升级与主菜单计时

本轮两项 P2 已经独立限定复审：VERDICT、Spec compliance、Implementation quality均PASS，两项ADDRESSED，无剩余应修发现。结合整批认可结论及UI增量PASS，第三批19项关闭；不代表全部50项或人工视听已验收。

### 修改与行为

- scripts/managers/main.gd:59：将原死亡专用的升级队列清空、界面取消移至统一终态入口，最终胜利也取消关闭动画与排队升级；死亡仍可抢占未完成胜利并递增 run token。复用 dismiss_for_game_over，仅释放升级自身的暂停，不重置其他模态持有者。
- scripts/managers/main.gd:1088：等级统计保留；终态后的 level_up 不再入升级队列，_try_open_upgrade 同时检查终态，阻断已挂起的下一张升级回调。
- scripts/managers/achievement_manager.gd:226：autoload 初始 _ready 关闭 process，仍由 start_new_run 重置时钟并开启；既有死亡/最终胜利 finish_run 不变。
- scripts/managers/main.gd:170：新增 _exit_tree 调用 finish_run。已核对 PauseMenu 默认 go_to_main_menu 直接 change_scene_to_file，统一场景退出停钟同时覆盖暂停菜单放弃和 main 返回菜单，不必修改 UI 接线。
- tools/pre_audio_terminal_clock_test.gd:28：接续前 worker 新建文件，补齐隔离磁盘 JSON 检查、隔离失败即停止保护、正常连续升级及关闭回调已发出但队列仍待开的时点。覆盖初始菜单、真实开始、暂停、正常升级、放弃、重新开始、真实死亡、主动返回、最终 Boss 三种升级状态（无既有队列 / 关闭动画进行中 / 延迟队列回调待恢复）。每次 Boss 均等待登场结束并真实 take_damage，玩家差1XP，拾取真实掉落；终态后不调用 skip、不强行解暂停，等待唯一胜利结算。

本轮仅修改以上两生产文件、接续测试及本报告。生产文件保持 CRLF，测试及报告保持 LF。修改前生产快照在 .tools/qa/task3-review-r1-before/。原 review_probe.gd/log、父计划、validation、音频、素材与 nul 未动；未提交、未推送。

### 红绿证据与命令

引擎均为 .tools/godot/Godot_v4.7.2-stable_win64_console.exe（运行器默认参数），各套串行独立进程，没有与基线同名套件并发。

    python tools/run_pre_audio_regression.py --suite pre_audio_terminal_clock_test --label task3-review-r1-red --timeout 100
    python tools/run_pre_audio_regression.py --suite pre_audio_terminal_clock_test --label task3-review-r1-red-complete --timeout 110
    python tools/run_pre_audio_regression.py --suite pre_audio_terminal_clock_test --suite pre_audio_lifecycle_test --suite pre_audio_stats_integration_test --suite ui_interaction_test --suite run_dungeon_smoke --label task3-review-r1-green --timeout 180

- 初始接续红测：exit=1，54通过 / 20失败，45.65秒。
- 补齐后的完整红测：exit=1，74通过 / 29失败，61.48秒；全部失败为行为断言，没有 SCRIPT ERROR / Parse Error。确认菜单跨阈值把 survivor 写入隔离磁盘，Boss真实经验及两种既有队列阻塞胜利。正常连续升级及延迟回调夹具均通过。
- 生产修复后绿测：运行器 exit=0，5/5；全部 exit_code=0、errors=[]、timeout=false、cleanup_ok=true。

| 套件 | 秒数 | 结果 |
|---|---:|---|
| pre_audio_terminal_clock_test | 52.91 | 103通过 / 0失败 |
| pre_audio_lifecycle_test | 40.11 | 69通过 / 0失败；首层/最终层两种真实死亡竞态保留 |
| pre_audio_stats_integration_test | 30.00 | 69通过 / 0失败；有效生存阈值、暂停/HUD/结算口径保留 |
| ui_interaction_test | 6.89 | 全部通过 |
| run_dungeon_smoke | 56.81 | 三层真实通关，fail=0 |

每轮完整日志和机器结果位于 .tools/qa/<label>/results.json 及同目录 *.log。绿测汇总定位：pre_audio_terminal_clock_test.log:222、pre_audio_lifecycle_test.log:140、pre_audio_stats_integration_test.log:170、ui_interaction_test.log:163、run_dungeon_smoke.log:265。

### 隔离、假设与边界

- 仅使用 user://test_*；本轮没有读取真实进度。新增测试读取的是其隔离 save_path 的磁盘 JSON；use_test_save_path 仅作测试初始化，不冒充持久重载验证。本轮未新增管理器持久重载测试，沿用此前证据，不声称重跑了该套件。
- 行为假设沿用既有设计：开场演出从 main._ready 开始算本局时间；非最终层 Boss 后仍可正常升级；最终胜利后经验仍增加玩家等级与统计，但不再发升级选择。
- 未重跑整套10套或无关音频套件；全部为 headless，未做人工游玩/试听。三种升级时点和既有两种死亡竞态已测，不声称穷举所有帧序或所有随机房序。
- 首次 git diff --check exit=2：新增函数邻近原空行的 Tab 被计入变更；已仅删除该空白，未改行为。绿测后仅该空白修正及报告追加，最终 git diff --check exit=0，仅既有 LF→CRLF 提示，无空白错误。无实现阻塞，独立复审由父会话执行。
