# 音频适配前修复验证记录

> 状态：本轮50项修复完成。四批及总审查整改均已独立审查通过；修后最终全量35/35通过。以下历史失败记录保留用于追溯，最终结论以本段和末尾“最终验收”章节为准。人工试玩、视听和导出包验证未执行。

## 环境与基线

- 修复分支：`repair/pre-audio-20261112`；修复前 commit：`727e3ad`。未提交、未推送。
- 修复前源码快照：`.tools/baseline`，由 `git archive` 导出；便携引擎及日志位于 `.tools/`，已被 Git 忽略。
- 引擎实际版本：`4.7.2.stable.official.ed1daf0bf`。官方下载ZIP的 SHA256：`731980f9608d61333e5baf54a2ef17210acc7a538446c0cb9969f002aca1e953`，已核验一致。
- 基线首次 `--headless --editor --path .tools/baseline --import` 在导入字体前报告缓存缺失，退出0；完成资产导入后再次运行同一命令，退出0且无引擎错误。

## 测试运行器

- `python tools/test_pre_audio_runner.py`：修复前出现说明文本误报、缺少有界清理接口以及输出方式不匹配；修复后6项通过，退出0。
- `tools/run_pre_audio_regression.py`：每套件独立进程、直接写完整日志；非零退出、行首引擎错误协议及失败标记、超时均失败。进程树终止及回收均有超时；清理无法确认时停止后续套件并返回失败。
- 独立复审：现有6项测试重跑通过，额外5项内存模拟通过，覆盖启动失败、超时、父进程退出但树终止失败、正常终止、提前停止与不完整报告。结论仅适用于运行器及计划修订，不代替游戏测试。
- 同名套件不可在基线与当前工程同时执行，避免共享 `user://test_<suite>.json`。

## 已执行的引擎测试

| 工程 | 测试 | 结果 | 证据 |
|---|---|---|---|
| 修复前快照 | save_isolation_test | PASS，退出0，无错误标记，3.73秒 | `.tools/qa/baseline-isolation/results.json` 与对应日志 |

非战斗基线20套已完成，初次17/20通过（`.tools/qa/baseline-other/results.json`）。失败分项：

- `vfx_regression_test`：headless dummy renderer 无法截图；改用实际 Vulkan/Forward+ 渲染后通过。
- `xp_gem_test`：固定0.5秒吸附等待曾失败，3次诊断未稳定复现；第一批保留原断言，改有界终态等待并新增普通拾取9XP与池化复用3XP实际到账断言，最终44项通过。未改宝石生产逻辑，不宣称已证实根因。
- `readability_test`：初次断言均通过，但退出有12个ObjectDB实例和5个脚本资源残留；第二批已用目录工厂延迟加载修复，最终完整套件无退出错误，见下文。

运行器现对 VFX 和 settings 使用真实渲染，其余仍 headless，并在JSON记录display。新增模式测试后Python单测8/8，独立增量复审 Spec/Quality PASS。实际运行器基线复测 `baseline-rendered`：VFX与settings两套均exit0、errors0（10.41s/4.61s）；未用跳过截图制造通过。

第一批20项源码修复已经落盘，初版 `task1-final` 8/8套通过（新增战斗集成61项、经验宝石44项）。独立审查实测发现两项P2遗漏：闪电后续跳尸体；亲王净血差吸血被同步反击汲取回血干扰。第1轮新增回归修复前64通过/3失败，修复后67通过/0失败，`task1-review-r1-green` 五套exit0、errors0，范围限定的独立复审Spec/Quality PASS，两项均ADDRESSED，第一批关闭。详情见 `task1-combat.md`。

可读性退出残留进一步诊断：九个分组独立运行均无残留；`player_layers,passive` 最小组合稳定复现12实例/5脚本。排除地面层后仍复现，仅把passive替换为加载ItemCatalog也复现。ItemCatalog预加载WeaponManager、后者引用ItemCatalog，存在依赖闭环；但移除全局类声明的独立目录副本无论preload/load均不复现，因此尚不能把单个preload判为充分根因。日志及临时入口在 `.tools/qa/readability-diagnosis/`，原基线与生产源码未为此修改。

## 两项玩法设计风险（源码核查）

- **进化机会无保底**：DungeonManager当前三层特殊房数量为1/2/2，每个特殊房以35%概率选宝箱，未见保底。按现有独立抽取规则，全局5个特殊房都不是宝箱的理论概率为 `0.65^5 ≈ 11.6%`；即使出现宝箱，也可能在武器满级/所需被动齐备之前。WeaponManager要求满级武器+对应被动+开宝箱，不能把接口测试通过表述为普通随机局必定能进化。保留随机机制，不擅自改保底。
- **每日挑战不是完整确定性回放**：main为房间序列、常规敌人种类/词缀、升级抽卡注入独立种子；room_manager的房型模板、room_shop货架、room_event_manager事件及目标、wave_manager补给种类/位置和刷怪坐标仍用全局随机。ROADMAP的已完成描述明确走位/暴击不锁，但GDD“相同地图/敌人序列”的宽泛措辞不能代表全部场景和事件都固定。当前仅本地榜；不能当作严格同条件跨玩家竞技。此处记录边界，不在缺陷修复中悄然重做随机系统。

## 可重跑命令

```bash
python tools/test_pre_audio_runner.py
python tools/run_pre_audio_regression.py --label full-regression
# 指定一套：
python tools/run_pre_audio_regression.py --label combat --suite pre_audio_combat_test
# 同一运行器对修复前源码进行对照（不要与当前工程同名套件同时跑）：
python tools/run_pre_audio_regression.py --project .tools/baseline --label baseline
```

## 当前完成状态与验证边界

- 50个唯一编号全部关闭；四批20/8/19/3完整覆盖。累计统计ID36重开后，真实红测33/11→44/0，相关8套通过，两项独立复审均ADDRESSED，整分支Spec/Quality/VERDICT PASS。
- 最终全量 `pre-audio-full-post-review` 已完成35/35，所有套件exit0、errors=[]、无超时、cleanup_ok=true。settings与VFX为真实渲染，其余headless。旧34套结果仍保留，不代替本次最终证据。
- `python tools/test_pre_audio_runner.py` 最后重跑8/8、退出0；`git diff --check` 退出0。生产新增静态资源字面量路径已核实存在，动态加载路径由实际回归覆盖，未声称穷举全部资产。
- 人工试玩、画面观感、人工听音/混音、声卡设备切换及导出包验证未执行；自动渲染与参数断言不能替代这些验收。未穷举所有await时点、随机特殊房和磁盘耗尽/flush故障，具体边界见分批报告。
- 进化无保底与每日随机未完全固定两项设计风险保持原状，结论见上文。

## 第二批实现与回归

8项成长/交易/UI修复已关闭，生产实现独立审查 Spec compliance / Implementation quality 均 PASS；额外交叉回归发现 build_enemy_rules 两处测试仍调用旧抽牌接口，修正为真实show_upgrade入口后96/96断言及相关4/4套通过，限定复审ADDRESSED、Spec/Quality PASS。证据 .tools/qa/task2-cross-fix/。真实行为红测28项失败，最终经济52/0；`.tools/qa/task2-green-second/results.json` 七套回归全部exit0、errors=[]。报告见 `task2-economy.md`。

目录资源残留：在当前工程仅把ItemCatalog武器工厂内preload改为load，完整readability立即无退出错误，原有工厂行为通过；最终含新增手枪的11个工厂与完整readability均通过。证据 `.tools/qa/task2-load-candidate/` 及第二批最终日志。该实测补齐了早先无全局类副本不能复现的证据缺口。

## 第三批阶段回归与收尾

最终阶段结果 .tools/qa/task3-final-guard-regression/results.json 记录9/9套exit0、errors=[]、无超时。生命周期69项、存档隔离42项；真实三层smoke正常波次计时开放出口，物理触门，真实伤害击杀三层Boss并确认+30/+60/+120各一次及唯一胜利结算。该路径三个不同随机房序通过；未覆盖全部特殊房分支或人工体验。

独立审查前父会话发现：分类击杀成就仍按单局字段判断，现有累计测试直接提交60次计数不足以证明真实击杀链路；结算/每日血晶没有记入本局收入；保存替换失败若主档已删除，加载不会尝试有效伴随文件。连同HP实际损血、Boss本战无伤、正常满级、时钟/收入全链路、弹幕清理和倍率专项测试，已交新实现者按 .tools/qa/task3-closeout-brief.md 收尾。因此第三批仍是实现待验，累计关闭28/50项。

详见 task3-lifecycle-save.md；该报告早期通过结果不代表全部要求满足，后续以收尾追加及独立审查结论为准。

第三批收尾更新：六组明确缺口已完成，.tools/qa/task3-closeout-final/results.json 10/10套全部exit0、errors=[]、无超时且cleanup_ok=true。存档统计142项、统计集成69项、生命周期69项、隔离42项、三层smoke通过；涵盖真实120次击杀跨新实例累计、分类成就阈值、正常满级、结算收入、终态时钟、弹丸清理、Boss倍率及缺主档恢复。独立审查Spec/Quality均FAIL，实证发现最终Boss真实经验仍打开升级并暂停胜利，以及未开局主菜单累计时钟、解锁保存生存成就。探针在 .tools/qa/task3-review-probes/，已交实现者补红绿回归并整改；尚未验收关闭。七套跨批回归task3-cross-batches中六套通过，ui_interaction旧文案断言精确修正后 task3-cross-ui-copy-fix 单套exit0、errors=[]，独立限定复审PASS：保留真实_on_wave_completed(4)、完整字符串精确匹配与第二批模态契约。此PASS仅覆盖测试增量，不解除两项生产P2。原整改会话两次BYOK上游错误后，新writer已完成两项修复。main统一终态取消升级队列及关闭动画，入口和延迟回调拒绝终态；AchievementManager初始停钟，main退出本局时finish_run。完整红测74通过/29失败，修后task3-review-r1-green五套全部exit0、errors=[]、无超时且清理成功：terminal_clock103/0、lifecycle69/0、stats_integration69/0、ui_interaction与三层smoke通过。新独立审查完成：VERDICT、Spec compliance、Implementation quality均PASS，两项均ADDRESSED，无剩余应修问题；结合此前整批与UI增量结论，第三批19项关闭，累计47/50。复审核对实际红绿日志与生产快照，没有重复运行五套；直接restart/深渊continue仅静态核对，未冒称全部帧序或人工体验已测。父会话再次执行python tools/test_pre_audio_runner.py，8项通过，exit0。


## 首次全量运行记录（总审查统计整改前）

命令：`python tools/run_pre_audio_regression.py --label pre-audio-full-final --timeout 180`。运行器进程退出0；机器报告 `.tools/qa/pre-audio-full-final/results.json`，完成34/34套。下表只证明当时源码与既有覆盖通过；后续统计整改须用新的label重跑，不覆盖本次日志。

| 套件 | 显示模式 | 秒 | 退出码 | 结果 |
|---|---|---:|---:|---|
| abyss_ladder_test | headless | 3.48 | 0 | PASS |
| balance_curve_test | headless | 0.96 | 0 | PASS |
| build_enemy_rules_test | headless | 7.27 | 0 | PASS |
| combat_rules_test | headless | 16.26 | 0 | PASS |
| combat_visual_test | headless | 3.92 | 0 | PASS |
| dungeon_test | headless | 1.07 | 0 | PASS |
| elite_affix_test | headless | 6.52 | 0 | PASS |
| feedback_v2_test | headless | 8.2 | 0 | PASS |
| feel_fix_test | headless | 5.59 | 0 | PASS |
| lifecycle_cleanup_test | headless | 1.05 | 0 | PASS |
| movement_regression_test | headless | 1.7 | 0 | PASS |
| phase1715_test | headless | 1.51 | 0 | PASS |
| phase17_test | headless | 7.94 | 0 | PASS |
| pre_audio_audio_test | headless | 19.3 | 0 | PASS |
| pre_audio_combat_test | headless | 10.14 | 0 | PASS |
| pre_audio_economy_test | headless | 2.53 | 0 | PASS |
| pre_audio_lifecycle_test | headless | 40.04 | 0 | PASS |
| pre_audio_save_stats_test | headless | 2.92 | 0 | PASS |
| pre_audio_stats_integration_test | headless | 30.02 | 0 | PASS |
| pre_audio_terminal_clock_test | headless | 52.85 | 0 | PASS |
| ranged_pressure_test | headless | 8.01 | 0 | PASS |
| readability_test | headless | 3.54 | 0 | PASS |
| roguelite_ops_test | headless | 8.1 | 0 | PASS |
| room_event_test | headless | 14.47 | 0 | PASS |
| save_isolation_test | headless | 3.64 | 0 | PASS |
| save_merge_test | headless | 0.96 | 0 | PASS |
| settings_menu_test | rendered | 7.28 | 0 | PASS |
| shop_test | headless | 5.42 | 0 | PASS |
| sprite_sheet_test | headless | 0.95 | 0 | PASS |
| status_effect_test | headless | 9.66 | 0 | PASS |
| ui_interaction_test | headless | 6.9 | 0 | PASS |
| vfx_regression_test | rendered | 10.35 | 0 | PASS |
| xp_gem_test | headless | 5.59 | 0 | PASS |
| run_dungeon_smoke | headless | 57.13 | 0 | PASS |

全部34套无超时、cleanup_ok=true、errors=[]。settings/VFX实际渲染仅证明相应自动断言与截图路径运行，不代表人工视觉验收；音频自动参数及播放状态断言不代表人工听感验收。

## 最终验收（2026-11-12）

命令：`python tools/run_pre_audio_regression.py --label pre-audio-full-post-review --timeout 180`。运行器退出0；源码在完整执行期间冻结。机器结果与35份日志：`.tools/qa/pre-audio-full-post-review/`。

| 套件 | 模式 | 秒 | 结果 |
|---|---|---:|---|
| abyss_ladder_test | headless | 3.1 | PASS |
| balance_curve_test | headless | 0.96 | PASS |
| build_enemy_rules_test | headless | 7.27 | PASS |
| combat_rules_test | headless | 16.16 | PASS |
| combat_visual_test | headless | 3.83 | PASS |
| dungeon_test | headless | 0.95 | PASS |
| elite_affix_test | headless | 6.42 | PASS |
| feedback_v2_test | headless | 8.2 | PASS |
| feel_fix_test | headless | 5.6 | PASS |
| lifecycle_cleanup_test | headless | 1.05 | PASS |
| movement_regression_test | headless | 1.7 | PASS |
| phase1715_test | headless | 1.6 | PASS |
| phase17_test | headless | 7.93 | PASS |
| pre_audio_audio_test | headless | 19.3 | PASS |
| pre_audio_combat_test | headless | 10.14 | PASS |
| pre_audio_economy_test | headless | 2.53 | PASS |
| pre_audio_kill_accounting_test | headless | 20.18 | PASS |
| pre_audio_lifecycle_test | headless | 40.13 | PASS |
| pre_audio_save_stats_test | headless | 2.92 | PASS |
| pre_audio_stats_integration_test | headless | 30.02 | PASS |
| pre_audio_terminal_clock_test | headless | 52.84 | PASS |
| ranged_pressure_test | headless | 8.01 | PASS |
| readability_test | headless | 3.64 | PASS |
| roguelite_ops_test | headless | 8.1 | PASS |
| room_event_test | headless | 14.39 | PASS |
| save_isolation_test | headless | 3.54 | PASS |
| save_merge_test | headless | 0.95 | PASS |
| settings_menu_test | rendered | 7.11 | PASS |
| shop_test | headless | 5.31 | PASS |
| sprite_sheet_test | headless | 1.05 | PASS |
| status_effect_test | headless | 9.65 | PASS |
| ui_interaction_test | headless | 6.8 | PASS |
| vfx_regression_test | rendered | 10.33 | PASS |
| xp_gem_test | headless | 5.78 | PASS |
| run_dungeon_smoke | headless | 52.33 | PASS |

独立总审查任务 `bg_0e9edac6-9124-4d3b-ba45-b52417dacdfd` 初审两项P2；限定复审 `bg_fafba914-07c8-4e52-be64-77e3c583f860` 确认两项ADDRESSED、Spec/Quality及整分支代码审查VERDICT PASS。复审基于三个生产快照、真实红绿日志和调用链，未并发启动Godot；完整35套结果由主会话另行执行和核对。

修复保留在 `repair/pre-audio-20261112` 当前工作区，基线727e3ad；未暂存、提交或推送。使用现有项目 `project.godot` 打开即可运行，入口仍为主菜单。命令行启动：`.tools/godot/Godot_v4.7.2-stable_win64_console.exe --path .`。该普通启动使用游戏正常存档；自动回归使用隔离测试档。
