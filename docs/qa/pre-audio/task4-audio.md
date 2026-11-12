# 第四批：音频框架（ID43 / ID44 / ID45）

状态：实现、范围回归与独立审查完成；Spec compliance、Implementation quality、VERDICT均PASS，ID43–45关闭。审查核对实际红绿日志及源码，未重复执行Godot；全量回归另由父会话执行。未提交、未推送。

执行环境：分支 `repair/pre-audio-20261112`，基线 727e3ad；Godot 4.7.2.stable.official.ed1daf0bf，使用项目内 .tools/godot/Godot_v4.7.2-stable_win64_console.exe。

## 合同与改动范围

完整读取 .tools/qa/task4-brief.md 和 docs/superpowers/plans/2026-11-12-pre-audio-repair.md。仅修改以下文件；未修改父计划、validation、运行器、AudioLib、总线配置、素材或 nul。前三批既有修改保留。

| 文件 | 本批改动 |
|---|---|
| scripts/managers/audio_manager.gd:17 | 新增独立线性 fade 系数，实际 BGM 增益由用户 music_volume × fade 计算；Tween 不再保存用户音量目标 |
| scripts/managers/audio_manager.gd:70 | BGM 播放器 ALWAYS；两类 BGM Tween 均 TWEEN_PAUSE_PROCESS |
| scripts/managers/audio_manager.gd:89 | 每次有效切曲与停止先取消旧 Tween；包括 fade=false 和停止时已无播放的路径 |
| scripts/managers/audio_manager.gd:138 | 显式 play_ui_sfx；原 play_sfx 两参数调用兼容，默认仍为战斗；池化借出时重置 process_mode，暂停中新发战斗声音也等待恢复 |
| scripts/managers/audio_manager.gd:164 | 暂停的战斗声音仍占槽位，不能被误当空闲或被 UI 抢占；保留原 8 个战斗槽位，另加 1 个仅 UI 能借用的槽位，保障满池暂停反馈 |
| scripts/managers/audio_manager.gd:207 | 使用不与全局转换函数同名的 _volume_to_db，零增益固定 -80 dB，避免无限分贝参与插值 |
| scripts/ui/main_menu.gd:222 | hover / click 改接 UI 音效入口（仅两个调用） |
| scripts/ui/character_select.gd:284 | 按钮 hover / click 改接 UI 音效入口（仅两个调用） |
| scripts/ui/game_over_ui.gd:95 | 结算 hover / click 改接 UI 音效入口（仅两个调用，保留第三批结算修复） |
| scripts/ui/room_shop.gd:410 | 成功购买反馈改接 UI 音效入口（仅一个调用，保留第二批交易修复） |
| tools/pre_audio_audio_test.gd:1 | 新增真实播放器 / 真实结算和商店回调测试，最终 54 项 |
| tools/settings_menu_test.gd:15 | 增加隔离档守卫及主菜单 / 暂停设置真实滑块回归；保留原窗口模式与截图验证 |

已用文件读取结果核对换行：五个生产文件全部 CRLF，两个测试为 LF，未混入其他换行。

## 行为验证

- ID43：真实胜利和失败结算 show_game_over 触发暂停与 BGM 切换；0.1 秒时仍在旧曲淡出，超过完整过渡后新曲播放位置前进。结算真实按钮 hover 信号和 click 音效回调能在暂停中播放、结束。
- 已播放战斗声音在结算期间保持原流身份、暂停标志和冻结进度；解除暂停后继续播放。商店通过真实 open / _on_buy 完成合法购买、扣款和反馈；同一播放器再用于战斗时重置为可暂停，恢复后继续。
- 满池专项：8 个真实战斗播放器全部暂停，结算 hover 仍有反馈；8 个原流全部保留，恢复后全部继续。为此添加 1 个 UI 保留槽位，未扩大可同时分配的战斗声音上限。
- ID44：在过渡 0.2 秒和 0.7 秒（淡出 / 淡入两个阶段）把用户音量从 0.8 调到 0.2；立即增益应为调整前的 1/4，余下逐帧增益不超过新用户音量，结束为 -13.9794 dB。实际暂停设置滑块也验证完成后的音量和隔离档保存值。
- ID45：用户音量 0 时，在运行和暂停两种状态下分别跨帧检查整段切曲、淡出停止；全程不超过 -80 dB，切曲和停止仍实际完成。另检查中途静音及主菜单实际滑块静音后不被旧 Tween 拉高。
- 过期回调：待完成切曲 / 待完成停止，分别被即时切曲 / 即时停止覆盖，四个组合均等待 1.2 秒（超过旧过渡期限）检查新状态不被覆盖。
- 流为内存静音 WAV，仅替换本测试进程的 AudioLib 缓存；不新增或修改音频素材。settings 测试走真实渲染与现有资源。

## 红绿证据与实际命令

所有命令在仓库根目录运行；运行器默认引擎即上述项目内引擎。

### 修复前有效红测

~~~bash
python tools/run_pre_audio_regression.py --suite pre_audio_audio_test --suite settings_menu_test --label task4-red-final
~~~

运行器 exit 1；两套子进程均 exit 1。音频 32 PASS / 19 FAIL；settings 的主菜单滑块静音检查失败。日志保留 216 条原实现引擎错误（Volume can't be set to NaN），未过滤或吞掉。

具体证据：旧 Tween 将用户已调至 0.2 的音量恢复到 -1.938 dB（0.8）；零音量停止淡出最高升到 -40 dB；中途静音被恢复到 -6.021 dB；暂停切曲绕过淡出，UI 复用覆盖战斗播放器；即时请求被旧回调覆盖。

结果：.tools/qa/task4-red-final/results.json；完整音频 / 设置日志同目录。

### 首轮绿测与满池专项红测

~~~bash
python tools/run_pre_audio_regression.py --suite pre_audio_audio_test --suite settings_menu_test --suite pre_audio_economy_test --suite ui_interaction_test --suite lifecycle_cleanup_test --label task4-green-r1
python tools/run_pre_audio_regression.py --suite pre_audio_audio_test --label task4-pool-red
~~~

第一条 exit 0，5/5 套通过，音频 51/0。随后针对检查发现的满池边界补行为用例：第二条 exit 1，音频 53 PASS / 1 FAIL，失败仅为“full frozen combat pool still allows UI feedback”，无引擎错误。补 UI 保留槽位后进入最终回归。

### 最终绿测

~~~bash
python tools/run_pre_audio_regression.py --suite pre_audio_audio_test --suite settings_menu_test --suite pre_audio_economy_test --suite ui_interaction_test --suite lifecycle_cleanup_test --suite combat_rules_test --label task4-final-green
~~~

运行器 exit 0，6/6 通过；每套 exit 0、errors=[]、无超时。

| 套件 | 观察结果 | 显示模式 |
|---|---|---|
| pre_audio_audio_test | 54 PASS / 0 FAIL | headless |
| settings_menu_test | 失败 0；窗口全屏同步和截图检查实际执行 | rendered |
| pre_audio_economy_test | 52 PASS / 0 FAIL | headless |
| ui_interaction_test | 全部通过 | headless |
| lifecycle_cleanup_test | 13 PASS / 0 FAIL | headless |
| combat_rules_test | 78 PASS / 0 FAIL | headless |

结果：.tools/qa/task4-final-green/results.json；6 份完整日志同目录。

另运行 git diff --check，exit 0。Git 输出工作区既有 LF→CRLF 配置提示（含原为 LF 的 settings 测试），没有差异空白错误；未为消除提示修改换行。

### 夹具调试记录（不算成功或有效缺陷红测）

- task4-red：首次误把静态 PauseController 当成 autoload，出现 Node not found / 空实例调用；主动取消，未产生完成退出码。
- task4-red-r1：修正静态引用后完整执行，两套 exit 1；随后加强旧曲淡出阶段断言形成 task4-red-final。
- task4-green：生产修复后，测试查找器仅按 playing 查找，因暂停的播放器 playing 为 false 而取得 null，触发脚本错误；主动取消。查找器改成 playing 或 stream_paused，再完整运行 task4-green-r1。未掩盖引擎错误或改运行器。

## 隔离、假设和未测边界

- SaveManager 的 --script 自动隔离在 autoload 初始化时生效；新增音频和修改后的 settings 测试先断言精确 user://test_<suite>.json 路径，之后才实例化 UI。继承现有 SaveManager 测试档及 .tmp / .bak 清理逻辑，不读取真实进度。
- 未做真实主档摘要对比；本批依靠已审查的工具存档隔离入口及测试显式守卫。未调用真实档加载或写入。
- 本批证明参数、流身份、播放进度、暂停 / 恢复、音量保存和 UI 接线；不声称做过人工听音、混音听感、声卡设备切换、导出包验证。
- settings 真实渲染生成现有截图输出 tools/evidence/iteration/settings_menu.png 和 pause_settings_menu.png；未改截图路径或以 headless 跳过。
- 无实现阻塞。独立复审已PASS（见顶部状态）；总项目回归由父会话按合同统一执行。
