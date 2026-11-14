# Task 2：成长入口与 UI 交易

## 结果

ID03/04/28/29/30/33/49/50 已实现，要求的六套回归及完整 readability 均通过（Godot 4.7.2.stable.official.ed1daf0bf，7/7，运行器退出 0）。新增经济回归最终 52 个断言通过、0 失败。父会话独立审查 Spec compliance / Implementation quality 均 PASS，交叉测试整改限定复审亦通过，本批关闭；未提交、未推送、未处理 nul。

## 逐项修改与证据

| ID | 修改 | 回归证据 |
|---|---|---|
|03|scripts/core/item_catalog.gd:9 增加 pistol，标记 upgrade_only；工厂复用 WeaponManager 静态手枪创建；upgrade_ui 和 room_shop 仅向已持有者提供手枪升级|真实初始 Lv1 手枪→正常抽到手枪卡并选择至 Lv2→实际商店重抽/购买至 Lv5→取得四叶草后宝箱接口进化；不直接设置等级。非手枪角色池不出现新手枪；现有 pistol 图标非空|
|04|scripts/ui/upgrade_ui.gd:81 分离 _draw_and_render_options 和 _render_options；切换模式仅渲染|连续四次切换保留 type:id 顺序及 RNG.state；真正重抽和放逐仍更新手牌|
|28|scripts/ui/upgrade_ui.gd:516 增加同步提交闸门，禁用卡片与页脚；R/B/Tab 和重复回调被拒绝；新展示复位，死亡关闭取消待执行关闭 tween|真实卡片按钮确认后同帧 Tab、再次确认、R/B；奖励回调仅一次，不额外领银币；连续跳过仅 +15，下一展示仍可用|
|29|scripts/weapons/weapon_manager.gd:210 增加 can_add_weapon，add_weapon 返回 bool 并权威检查四槽；room_shop 购买前重验、成功应用后扣款|真实三槽→购买第四槽→另一货架按钮立即禁用→强调旧回调购买第五槽失败且余额不变；直接 add_weapon 同样无法超过四槽|
|30|scripts/ui/room_shop.gd:347 / _can_apply_offer / _apply_offer 统一校验目录、槽位、进化/满级状态和工厂结果；货架刷新先移除旧节点|满级武器退出可售池；旧货架满级武器、满级被动、未知工厂均不扣费且不售出；满槽仍可升级现有武器|
|33|scripts/ui/pause_menu.gd:227 打开前检查其他 PauseController 持有者|升级、商店、血祭坛打开时 ESC 不在背后新增菜单；无模态时 ESC 正常打开/关闭暂停|
|49|scripts/ui/blood_pact_ui.gd:213 将楼层标签保存为成员，每次刷新更新|同一祭坛实例先开第1层，关闭后再开第4层，显示第4层且不残留第1层|
|50|scripts/ui/upgrade_ui.gd 补给描述、预览和 toast 统一立即入账；保留 add_blood_crystals 并调用既有 record_crystals_earned|隔离持久余额立即 +100，本局 crystals_earned 恰好 +100|

第三批协调提示：本批已在补给 gold 路径记账 record_crystals_earned(100)。若第三批统一所有血晶收入入口，需要迁移而非叠加这个调用，避免重复统计。

其他修改：tools/pre_audio_economy_test.gd（新增）；tools/roguelite_ops_test.gd:77 在比较池规模前绑定相同 player/wm；tools/ui_interaction_test.gd:148 将旧“暂停叠在升级后方”的断言改成明确的新禁止行为，保留其他多持有者释放断言。

## 附加：目录静态资源残留

父会话红测证据：.tools/qa/pre-task2-readability/results.json，readability 自身退出 0，但退出出现 ERROR: 5 resources still in use，运行器退出 1。

第一项生产修改严格只把 ItemCatalog.create_weapon 内 WeaponManager 的 preload 改为 load。实验记录 .tools/qa/task2-load-candidate/：完整 readability 退出 0、errors=[]；经济套件所有原有 10 个目录工厂实际创建断言通过，其他尚未修复的 28 个行为失败保持不变。由此采用该单变量候选，不扩改类注册/缓存。最终完整 readability 与包含 pistol 的全部 11 个目录工厂均通过。未修改原诊断快照、未强制 unreference、未删除退出检查或忽略错误。

## 红绿命令与退出码

所有命令均在仓库根目录执行，使用运行器默认便携引擎 .tools/godot/Godot_v4.7.2-stable_win64_console.exe；全部串行，无同名套件并发。每个目录包含逐套 .log 和 results.json（含实际 Godot 命令）。

1. 测试脚本编译修正前（不计作行为红测）：
   python tools/run_pre_audio_regression.py --label task2-red --suite pre_audio_economy_test
   运行器 1 / 套件 1；测试局部 buttons 动态类型推断错误，随后明确 Array 修正。
2. 真实红测：
   python tools/run_pre_audio_regression.py --label task2-red-behavior --suite pre_audio_economy_test
   运行器 1 / 套件 1；19 通过、28 行为失败，无脚本错误。覆盖全部八项。
3. 单变量 load 实验：
   python tools/run_pre_audio_regression.py --label task2-load-candidate --suite readability_test --suite pre_audio_economy_test
   运行器 1；readability 0，无错误；经济 1（19/28，尚未修其他问题），所有既有工厂通过。
4. 初次整体绿测：
   python tools/run_pre_audio_regression.py --label task2-green-first --suite pre_audio_economy_test --suite roguelite_ops_test --suite shop_test --suite ui_interaction_test --suite feedback_v2_test --suite phase17_test --suite readability_test
   运行器 1，4/7 通过。三个失败来源：经济确认用例随机拿新武器污染三槽前提；roguelite 初始池未绑定 wm 而后续池已绑定，新增手枪导致前后池不能比较；ui_interaction 仍要求旧的背后暂停菜单行为。分别修正为实际抽到属性卡后确认、比较前绑定相同对象、新模态契约断言。未以删掉业务断言换绿。
5. 最终：
   python tools/run_pre_audio_regression.py --label task2-green-second --suite pre_audio_economy_test --suite roguelite_ops_test --suite shop_test --suite ui_interaction_test --suite feedback_v2_test --suite phase17_test --suite readability_test
   运行器 0；七套分别 exit=0、errors=[]、timeout=false、cleanup_ok=true。经济 52/0。
6. git diff --check：退出 0。Git 提示既有配置将来可能把部分 LF 转 CRLF，实际文本检查：本批六个生产文件和 ui_interaction_test 保持纯 CRLF；roguelite_ops_test 保持纯 LF；新测试/本报告 LF。未触碰第一批其他代码；weapon_manager 仅改容量/结果接口与手枪工厂 static，保留第一批进化参数和实时倍率修复。

## 假设、边界与风险

- 沿用现有同步 Godot 交易调用和 player.spend_silver 语义，先检查余额和可应用条件、应用成功后扣款；没有引入异步交易服务。手枪定价 28，沿用现有轻型武器价位，未重平衡其他道具。
- 工具启动由现有 SaveManager.detect_tool_run 在 load_game 前选择 test_<suite>.json，经济套件显式断言隔离路径；日志确认测试档，不加载真实玩家进度。清理由 SaveManager 退出钩子负责；本批未改保存实现、未读取真实存档内容或声称做过真实存档哈希对照。原保存器临时/备份保护的整体修复属于第三批。
- 正常抽卡/商店可达得到验证，不承诺有限局数或每局随机必出手枪/必进化；测试给足隔离银币并有界重抽以验证入口，不代表实际经济平衡。
- 进化测试调用真实宝箱进化接口，不冒称已人工打完整局或通过实体宝箱完整交互。
- 全部为 headless 自动回归。未做人工鼠标体验、画面观感或听音验收，未证明音频适配质量。
- 无实现阻塞；独立审查由父会话安排，本子会话没有委派其他代理。

## 交叉回归整改（父会话 task2-cross-combat）

父会话交叉回归中 pre_audio_combat_test / status_effect_test 通过，build_enemy_rules_test 退出 1，断言“预算用满后界面仍然发得出卡（当前0张）”失败。证据：.tools/qa/task2-cross-combat/results.json。核对发现该套两处仍把 _render_options 当作抽牌入口；另一处“无放逐补给”检查还可能被空手牌或旧手牌掩盖。

本次仅修改 tools/build_enemy_rules_test.gd 的 _test_supply_branch 和 _test_banish_not_bypassed：创建并绑定真实玩家/WeaponManager，通过 show_upgrade 进入真实展示流程；保留原属性卡预算与放逐断言，新增非空手牌、对应卡片按钮数、每张卡属于当前合法池且未放逐、无 stat、打开暂停及关闭后释放暂停的断言。三张补给全放逐时仍明确断言本轮无 basic。测试结束显式 dismiss_for_game_over 后再清场。保留第一批 _make_scene_root / _clear_roots 的 current_scene 修复与原 LF；没有修改生产接口。

验证命令：

```text
python tools/run_pre_audio_regression.py --label task2-cross-fix --suite build_enemy_rules_test --suite pre_audio_economy_test --suite roguelite_ops_test --suite ui_interaction_test
```

运行器退出 0，4/4 通过；各套 exit=0、errors=[]，日志及完整命令位于 .tools/qa/task2-cross-fix/。沿用隔离测试存档，未做真实存档或人工视听操作。独立审查由父会话继续执行。


## 独立审查结论

生产实现审查 Spec compliance / Implementation quality 均 PASS。交叉测试整改限定复审 ADDRESSED，Spec compliance / Implementation quality 均 PASS，确认两处真实show_upgrade、非空合法手牌、无stat/已放逐basic、暂停释放和既有current_scene修正均保留。审查未重复运行已记录套件；证据来自当前源码、差异与对应运行器日志。
