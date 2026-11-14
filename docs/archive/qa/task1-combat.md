# Task 1 战斗与玩家属性修复

分支：repair/pre-audio-20261112。工作范围仅 scripts/enemies、scripts/player、scripts/weapons、战斗测试与本记录；未提交、未推送。

> 当前结论：20项已完成分批回归和独立复审，Spec/Quality PASS。下文保留早期实现及审查整改记录；全项目最终状态以 validation.md 为准。

## 接口

- 保留 take_damage(amount) 与 take_damage_with_knockback(amount, direction, force, stun_duration) 调用兼容性。击退动态调用子类 take_damage；领主免疫位移但共用伤害入口。
- 新增玩家信号 damage_received(amount: float)：护甲、护盾、闪避、无敌处理后仅报告实际损血，致死夹到剩余 HP；献血支出不视作战斗受伤。
- on_dealt_damage(amount) 接收实际有效伤害，敌人不乘汲取比例。玩家乘一次 drain_ratio，保留既有 2HP 累积阈值；致死命中、持续伤害均报告实际伤害，禁疗期间不积存回血。
- 敌人直接伤害入口统一暴击；受击后的存活敌人统一冰冻/流血/霜缚。dot_damage 不触发上述直接命中效果。
- set_base_move_speed(value) 修改阶段基础移速并重新应用急速/减速；_deal_contact_damage(body) 是首次接触与持续接触共用钩子。

## 逐项实现与回归

| ID | 修改文件与行为 | 新集成回归要点 |
|---|---|---|
| 02 | enemies/gargoyle.gd：石化倒计时由 _process 推进，保持 super 状态 tick；进入石化立即停止本帧移动 | 等待真实石化时长后解除 |
| 13 | player/silver_coin.gd：读取 pickup_range_bonus，保留银币原有 0.5 系数 | 真实玩家加成让150px外银币开始吸附 |
| 14 | enemies/enemy_base.gd、gargoyle.gd、exploder.gd、vampire_lord.gd：击退动态调用防御/受击入口 | 石像鬼护甲、石化免伤、自爆阈值钩子 |
| 15 | player/bullet.gd：移除弹丸私有暴击判定，统一使用敌人入口；复用时可重新取得玩家引用 | 对象池归还/获取同一场景弹丸后100%暴击 |
| 16 | enemies/enemy_base.gd 与覆写物理帧的敌人：统一 _process 冻结计时，物理帧仅拦移动/攻击；冻结不接触伤害 | 狼人、射手、自爆鬼、领主冻结不动并真实计时解冻 |
| 17 | enemies/enemy_base.gd 及伤害覆写、player/bullet.gd、poison_cloud.gd：直接命中共享暴击/冰冻；DoT不递归命中效果 | 飞刀、复用子弹、闪电、环刃100%被动；毒雾无暴击/冻结/流血 |
| 18 | 敌人 _subtract_hp/_report_dealt_damage 与玩家 on_dealt_damage：只回报有效损血，比例只乘一次 | 100伤害、2%恢复2HP；过量致死直接命中/DoT均只按剩余100HP |
| 19 | player/player.gd：汲取禁疗与死亡保护，禁疗清空零头池 | no_heal 下100有效伤害恢复0HP |
| 20 | enemies/enemy_base.gd：未到下一跳而状态已到期时也清空旧流血强度和计时 | 强流血到期后可重新施加较弱流血 |
| 21 | enemies/vampire_prince.gd、vampire_lord.gd：阶段基础速度通过统一重算入口更新 | 小亲王减速到期保持二阶段90移速 |
| 22 | enemies/vampire_prince.gd：独立蓄力状态，0.3秒前摇后才设 is_charging，计时服从暂停 | 前摇不位移，等待后开始冲锋 |
| 23 | enemies/vampire_lord.gd：_ready 缓存接触区域 | 真实登场结束后重叠玩家持续扣血 |
| 24 | weapons/orbit_blade.gd、weapon_manager.gd：环刃每次命中读取当前玩家总倍率和当前武器槽位衰减 | 伤害成长、狂战士、临时强化及到期、第二槽衰减 |
| 25 | weapons/weapon_manager.gd：散射数量/角度、毒雾与血爆范围、连锁数量/距离、弩箭穿透兑现配置 | 逐次升级+宝箱进化后检查实际生成节点参数 |
| 26 | player/lightning_chain.gd：线段追加而非覆盖，世界点转局部点，单次淡出 | 非零世界原点、两段共12顶点、末点抵达第二敌人、跳伤递减 |
| 27 | enemies/vampire_prince.gd、enemy_base.gd：首次与持续接触共用实际扣血差值吸血 | 无敌不回血，护甲后损血乘一次亲王比例 |
| 31 | player/player.gd：贪婪使用独立已应用贡献补差额 | 保留初始永久经验与后续外部增长，再升级贪婪 |
| 46 | weapons/weapon_manager.gd、player/bullet.gd、lightning_chain.gd、player.gd：跳过 is_dead；射击重新检查活目标 | 最近死亡目标不会被武器缓存或追踪弹选中 |
| 47 | player/poison_cloud.gd：到期幂等，立即停止监测/处理/伤害，仅保留淡出 | 到期后继续调用也不造成伤害；物理处理已停止 |
| 48 | player/player.gd：经验保留小数余量，整数UI接口不变 | 10次1经验与一次10经验在30%加成下相同 |

现有 tools/status_effect_test.gd 的假玩家回调断言从“已经乘过比例的5”修正为“有效伤害10”；真实玩家2%汲取由新套件单独验证。断言窗口放在等待之后，避免等待期间真实流血回调污染本次直接命中读数。

## 数值假设

进化配置没有独立额外弹丸/穿透/连锁倍数字段。按已有 size_multiplier 兑现声明的范围/数量效果：霰弹1.3倍数量（向上取整）与散射角；毒雾2.0倍、血爆1.8倍范围；十字弩1.3倍穿透（向上取整）；闪电1.5倍跳数（向上取整），跳距覆盖当前房间对角线，无房间时用现有800世界单位兜底。保留既有伤害/攻速倍率及 GameConfig 上下限。不改变随机宝箱或必进化机会。

## 验证记录

- 新测试：tools/pre_audio_combat_test.gd，真实 player/enemy/weapon 场景，无 Main 自动攻击；使用 SaveManager 现有 --script 工具存档隔离与退出清理。
- 修复前：先编写回归；便携引擎尚未解压可用，未能获得修复前失败执行结果。按任务明确授权继续代码实现，不将静态核查冒充失败测试。
- 引擎：父会话提供并校验的 Godot 4.7.2.stable.official.ed1daf0bf。工程 headless editor --import 退出0，无解析错误。
- 最终运行器退出0，8/8套通过，每套均 exit=0、errors=0；新战斗集成61项通过，经验宝石44项通过。日志与机器结果在 .tools/qa/task1-final/（results.json 及各套 .log）。
- git diff --check：最终执行退出0；各源码/既有测试沿用原有行尾。Git autocrlf提示不代表本批已转换行尾。

| 套件 | 结果 | 用时 |
|---|---|---|
| pre_audio_combat_test | PASS，61项 | 10.05s |
| status_effect_test | PASS，38项 | 9.75s |
| combat_rules_test | PASS，78项 | 16.25s |
| build_enemy_rules_test | PASS，83项 | 7.17s |
| phase17_test | PASS | 7.95s |
| combat_visual_test | PASS | 3.82s |
| elite_affix_test | PASS，63项 | 6.42s |
| xp_gem_test | PASS，44项 | 5.79s |

最终命令：

```bash
python tools/run_pre_audio_regression.py --label task1-final --suite pre_audio_combat_test --suite status_effect_test --suite combat_rules_test --suite build_enemy_rules_test --suite phase17_test --suite combat_visual_test --suite elite_affix_test --suite xp_gem_test
```

### 运行中发现与修正

1. 首轮 .tools/qa/task1-first/ 为6/7：build_enemy_rules_test断言通过但退出有6条资源错误。--verbose复现明确定位到无父节点的 bullet.gd / bullet.tscn资源。该测试两处手动挂载 Main 未设置 current_scene，自动开火创建弹丸却无挂载目标。只在测试补齐场景归属，两处各一行设置与注释；重跑 task1-build-recheck 与最终批次均退出0、errors=0。没有改对象池或 Main。
2. 父会话追加既有 xp_gem_test 基线39通过/1失败（自动吸附）。临时记录真实状态后连续3次复测均40通过：paused=false、in_pool=true、xp_value=0、玩家经验9。floor_banner.show_card源码未暂停树，不能将基线失败断言为登场暂停。旧断言只有0.5秒窗口，宝石随机掉落位移tween占0.3秒，存在时序敏感性；基线失败未稳定复现，具体触发尚未证实。
3. xp_gem_test现等待真实首波启动后停止刷怪，使用2秒有界终态等待，保留原自动拾取断言，新增实际9XP到账；池化复用后也验证自动回池和实际3XP到账。提高升级门槛避免测试被升级弹窗暂停。没有修改 xp_gem.gd、没有删除有效断言。加强后 task1-xp-recheck 与最终批次均44通过、errors=0。

独立审查由父会话执行；本批已自查首次接触钩子与十字弩倍率接线，修正两处遗漏。未做人工操控、视听验收或导出测试；headless combat_visual_test通过不等于人工视觉认可。

## 独立审查修复第1轮（2026-11-12）

独立审查发现两项P2，本轮仅修改 scripts/player/lightning_chain.gd、scripts/player/player.gd、scripts/enemies/vampire_prince.gd、tools/pre_audio_combat_test.gd，并追加本记录；未提交、未推送。

- ID46：_find_next_target同首跳入口一样排除is_dead。新增真实僵尸take_damage(10000)后同帧连锁回归，明确断言尸体仍在树中及enemies组；两活敌HP分别500→490、500→493，尸体不进入_hit_enemies，不占跳数或额外衰减。
- ID27：玩家take_damage参数不变，新增float返回值；在实际扣血后、任何信号或反击执行前保存effective_damage，信号及返回值共享此结果。死亡/非正伤害/无敌/护盾/闪避分支返回0。原有忽略返回值的调用兼容。亲王使用该返回值吸血，不再读取调用前后净HP差；反击已杀死亲王时不再回血。没有新增共享last_damage状态。
- 组合回归使用真实一级汲取与一级闪电护符：先80伤害积累1.6HP，接触实际扣10HP，反击20伤触发2HP汲取，玩家40→32、damage_received=10，亲王580→500→480→482。

修复前新增回归命令：

```bash
python tools/run_pre_audio_regression.py --label task1-review-r1-red --suite pre_audio_combat_test
```

实际输出：64 passed / 3 failed；连锁第二活敌、尸体占跳数、亲王回血三条断言失败，夹具构筑与玩家反击回血断言通过。套件exit=1、errors=0，运行器退出1。日志：.tools/qa/task1-review-r1-red/pre_audio_combat_test.log。

修复后命令：

```bash
python tools/run_pre_audio_regression.py --label task1-review-r1-green --suite pre_audio_combat_test --suite status_effect_test --suite combat_rules_test --suite phase17_test --suite build_enemy_rules_test
```

实际输出：RESULT: 5/5 suites passed，运行器退出0；所有套件exit=0、errors=0。pre_audio_combat_test为67 passed / 0 failed。用时分别10.15s、9.74s、16.26s、7.93s、7.27s。完整日志与results.json位于 .tools/qa/task1-review-r1-green/。git diff --check退出0。

假设与边界：生产玩家使用新的返回值契约；旧void测试替身仍能受击，但null返回不推测吸血量。不扩改进化数值。无执行阻塞，待父会话独立复审；本轮未做人工视听或导出验收。
