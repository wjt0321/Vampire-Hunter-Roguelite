# 美术资产状态（单一事实来源）

> 最后更新：2026-11-09
> 这份文档回答三个问题：**现在做到哪了 / 依据是什么 / 下一步往哪走**。
> 与 `ROADMAP.md` Phase 12、`asset-licenses.md` 如有冲突，**以本文档为准**，并回头修正那两份。

---

## 一、一句话结论

**Phase 12 已完成闭环：出图、接线、文档三件都做完了。**

32 张角色精灵 + 26 张 UI/图标全部完成并与代码尺寸对齐；玩家四张动作图（攻击 / 受伤 / 死亡 / 护盾）已接进 `player.gd` 并通过单测；文档旧表已按「以代码为准」修正；8 张纯色或全透明的假资源已清理。

剩下的是三件需要你先定方向的事：12 张成品特效图是否接线、3 个历史缺项是否补、交互动效是否做。

---

## 二、资产清单与状态

### 2.1 角色精灵（32 张，全部完成）

| 尺寸 | 数量 | 文件 |
|---|---|---|
| `224×56`（4 帧） | 20 | 玩家 5 张、普通敌人 15 张 |
| `336×56`（6 帧） | 4 | `player_run`、`zombie_walk`、`vampire_run`、`werewolf_charge` |
| `112×56`（2 帧） | 2 | `player_hurt` 等 |
| `512×128`（4 帧） | 6 | `boss_idle` / `enraged` / `attack1` / `attack2` / `attack3` / `death` |

存放：`assets/sprites/{player,enemies,boss}/`
校验：`verify_all` **32/32 通过**（尺寸、帧数、RGBA、四角透明、每帧填充率、亮色高光、帧间差异）

### 2.2 UI 与图标（26 张，全部完成）

| 类别 | 数量 | 说明 |
|---|---|---|
| 武器/被动图标 | 8 | 1024×1024 → **48×48**，BOX 下采样 + MEDIANCUT 32 色 |
| 血条边框 | 1 | 1536×1024 → 裁内容 → **200×24** |
| 菜单背景 | 2 | `menu_bg` 1344×768（压暗+暗角，让位菜单文字）、`defeat_bg` 1280×720 |
| 按钮三态 | 3 | `btn_normal` / `hover` / `pressed`，192×64 |
| 面板与槽位 | 10 | 菜单框、升级卡片、统计面板、商店槽位、波次牌、武器槽、被动槽、选中标记、成就图标、价格牌 |
| 角色 | 1 | `merchant` 128×128 |
| 售罄印章 | 1 | `sold_out` 64×24 |

校验：`verify_ui.py` **9/9 通过**

---

## 三、规格依据：为什么是 56 / 128 / 48，不是清单上的 32

清单（`art-assets-requirements.md`）第一节写的是 **32×32 方帧**、图标 **32×32**。实际没有照它做，原因是 GDD 附录 C 的标题就是「实现校准值（**以代码为准**）」。

| 资产 | 代码实际显示尺寸 | 出处 |
|---|---|---|
| 玩家精灵 | **56** 世界像素 | `scripts/player/player.gd:176` `_present_sprite(...)` → `SpriteSheetLib.apply(sprite, texture, 56.0)` |
| 普通敌人 | **56** 世界像素 | `scripts/enemies/enemy_base.gd:319` `_present_sprite(56.0)` |
| Boss | **128** 世界像素 | `scripts/enemies/vampire_lord.gd:273` `_present_sprite(128.0 * size_mult)` |
| 武器/被动图标 | **48×48** | `scripts/ui/upgrade_ui.gd:528` `icon.custom_minimum_size = Vector2(48, 48)` |

**为什么要对齐到这个数字**：图素与屏幕像素 1:1 时没有重采样。之前是 48 格图拉伸到 56 显示（1.167 倍），而 `sprite_sheet.gd:43` 设的是 `TEXTURE_FILTER_NEAREST`，非整数放大让像素列宽度在 1px/2px 之间跳，角色移动时边缘会"爬行"。

**明确没有改的**：按钮、经验条、升级卡片。它们在 UI 里是 `StyleBoxTexture` 整图拉伸（未设 `texture_margin_*`），改图片尺寸**看不出任何差别**；升级卡片控件是 222×196 横版，按清单改 180×240 竖版反而会被拉变形。

**分辨率上限的物理事实**：角色在 1280×720 画布上只占 56 像素高（7.8% 屏高）。原图 1024 的细节在这里只能保留剪影和主色——这是屏幕像素数的硬上限，不是制作质量问题。若想让 1024 的质感真正显出来，唯一有效手段是把角色显示尺寸做大（如 96），但那会改变视野手感且碰撞体不同步，属于玩法决策，未做。

---

## 四、来源与工艺

**32 张精灵 + 17 张 UI 全部由 AI 生成**（不是采集包裁切）。上一版曾用 `assets-downloaded/sprites/` 的成套帧拼过 13 张，但在「统一哥特暗金红、非幼态」的审美要求下，采集包的亮色卡通风格不匹配，已全量替换。

工艺固定为**双参考图**，不是靠文字描述猜风格：

| 输入 | 内容 | 作用 |
|---|---|---|
| `image_1` | `backup/icons/icon_pistol.png`（1024，已验收的图标） | **风格锚**：暗钢/皮革/金边/深红/高对比 |
| `image_2` | `backup/sprites/<asset>.png`（MVP 旧精灵） | **造型锚**：角色身份与服装 |

提示词写死 `Mature heroic proportions, about 6 heads tall` + `NOT chibi, NOT super deformed, no oversized head`，负面词含 `chibi, cute, cartoon, childlike`。这是"幼态"被显式挡掉的原因，不是运气。

工作流：`图片_Qwen-Image2.1_图像编辑.json`（Qwen-Image2.1 int8），本机 ComfyUI。
**全程串行，一次只提交一张**，从未并发。

---

## 五、复盘：真正花时间的不是出图，是后处理

出图本身很稳定（56 秒/张，模型驻留后 29 秒/张）。返工几乎都集中在"把 1024 变成能进游戏的 56 格"这一步：

| 问题 | 症状 | 根因 | 修法 |
|---|---|---|---|
| 限色溢出 | 整张布满黄/青/品红噪点 | 用 `int16` 算颜色距离平方，245² 超出 32767 溢出 | 改 `float32` |
| 整体压黑 | 亮红金角色变墨绿剪影 | 从旧图按**出现频次**取 top-48 色，暗部像素占多数，亮色没进调色板 | 撤销限色，改为按亮部 p90 做 gamma 提亮 |
| 脚下紫红横线 | 深紫背景上不明显，石板/砖墙上很扎眼 | 黑角色与品红背景之间的**抗锯齿过渡带**被保留下采样 | `purge_purple_edge()`，判据见下 |
| 石化四帧全同 | 尺寸色数全合格，但没有动画 | `gargoyle.png` 本身是纯灰阶，项目现成的 `to_sat()` 去饱和对它无效 | 改为石壳自下而上蔓延 + 末帧裂纹，`gargoyle_petrify.py` |
| 淡出帧空 3 格 | 6 帧里 3 帧全透明 | 4 帧淡出复制补齐到 6 帧 | 按目标帧数均分透明度 |

**紫边判据的踩坑记录**（三次才对，留作教训）：

1. 第一版用连通块宽度 ≥25% 格宽 → **永远不命中**。因为紫带被角色的黑色脚交错切成 200 多个 1px 碎块（`boss_attack1` 最大块只有 `w=19`、`area=40`）。
2. 第二版用形态学开运算区分薄/厚 → 脚下紫带是"高 2~3px、宽很大"的横条，3×3 方核把它当厚块保下来。
3. **最终版按「行投影跨度」判断**：同一行里紫像素的左右跨度是连续的，虽被切碎但跨度仍在。判据 `y ≥ 85% 格高` 且 `跨度 ≥ 25% 格宽`。

同时要保住**设计性紫**：`boss_enraged` 的紫是披风内衬（`h=27~47` 的竖直块，颜色 `(79,31,59)`），与残留颜色几乎相同、靠颜色分不开，只能靠形状与位置区分。`gargoyle` 的石化效果给 B 通道乘 1.08 让石头偏冷，也是设计。

---

## 六、验收记录（真实数字，非估计）

| 项目 | 结果 |
|---|---|
| `verify_all.py` | **32/32 通过** |
| `verify_ui.py` | **9/9 通过** |
| 底部紫带残留 | **0 张**（行跨度判据复查） |
| 亮度过暗（p90 < 70） | **0 张** |
| 静止横条 | **0 张** |
| Godot `--headless --import` | **exit=0** |
| Godot `--quit-after 180` 运行 | **exit=0**（仅既有退出时 2 个对象泄漏警告） |
| 本轮后处理耗时 | 16:54 → 17:13，约 19 分钟（含 4 次判据调试重跑，**未重新出图**） |

第二批（四张动作图接线 + 文档 + 占位清理）：

| 项目 | 结果 |
|---|---|
| 玩家四张动作图单测 | `apply_recoil→attack`、`take_damage→hurt`、`grant_shield→shield`、`_die→death` 全部命中；0.8s 后回 idle；死亡 1.2s 后销毁（`tools/_test_player_actions.tscn`） |
| 六张玩家纹理 | 全部加载，帧数 4/6/4/2/6/4 与素材一致 |
| 资产数 | 163 → **155**（移走 8 张零引用假资源） |
| Godot `--import` | **exit=0**，无缺失引用 |
| 运行 `res://scenes/main.tscn` | **exit=0**，正常进第 1 层房间 1/6 |
| 顺手修掉的既有 bug | `vampire_lord.gd:328` 的 `if sprite:` 缺缩进块，导致整个 Boss 脚本编译失败、Boss 战会崩（上一会话遗留） |

---

## 七、回退方式

| 想回到 | 操作 |
|---|---|
| MVP 原版精灵 | `.workbuddy/backup/sprites/` 覆盖回 `assets/sprites/` |
| MVP 原版图标/UI | `.workbuddy/backup/icons/`、`.workbuddy/backup/ui/`、`.workbuddy/backup/ui_assets/` |
| 48 格版本 | 改 `reskin_plan.json` 的 `cell` 为 48/96，跑 `reskin_pipeline.py --finalize-only` |
| 1024 原始底图 | `.workbuddy/comfy/raw_reskin/`（32 张，去重后）；ComfyUI 输出目录 `E:\AI\ComfyUI\output\vhr_reskin\`（36 张含重跑） |
| 被清理的 8 张占位资源 | `.workbuddy/backup/dead-assets/`（保留原目录结构，直接移回 `assets/` 即可） |
| 「弱项精修」两次试改 | `.workbuddy/backup/refine2/`（已回滚，备份仅留档） |

---

## 八、明确没做的（边界，防止误以为漏了）

1. **`lightning_bolt` / `lightning_chain` / `shop_bg` 三个历史缺项没有补**。在所有 `.gd` / `.tscn` 里都搜不到引用（`lightning_chain` 只是武器 id 和场景名），补了也不会显示。
2. **12 张特效图有内容但零引用，没有接线**。VFX 目前走 `vfx_manager.gd` 程序生成，要不要换成贴图是另一个决定，不在资产范围内。
3. **12.4 背景没改图**。背景全是 `TextureRect` 全屏拉伸，现有 `room_standard` / `menu_bg` 是成品美术，改尺寸看不出差别。
4. **交互动效没有做**。按钮三态贴图已就位（`StyleBoxTexture` 自动切换），但缩放、光晕、淡入需要改 `.gd`。
5. **没有为「弱项」硬改图**。见第十节——评估后判定它们不是缺陷。

---

## 九、占位资源清理

`assets/` 下**没有任何 SVG**。真正的问题是 8 张「看起来像资源、其实是空的」PNG，经全局引用审计（`scripts/**/*.gd`、`scenes/**/*.tscn`、`*.tres`）确认**零引用**，已移到 `.workbuddy/backup/dead-assets/`（保留原目录结构，可原样移回）。

| 文件 | 尺寸 | 实际内容 | 为什么移除 |
|---|---|---|---|
| `backgrounds/room_square.png` | 960×960 | 纯黑，100% 不透明 | 房间背景实际用 `room_standard.png`（完整哥特房间） |
| `tiles/tile_floor.png` | 32×32 | 2 色灰块 | 地面实际用 `floor_dungeon.png`（18 色石砖） |
| `tiles/tile_floor_var1.png` | 32×32 | 同上 | 同上 |
| `tiles/tile_floor_var2.png` | 32×32 | 同上 | 同上 |
| `tiles/tile_pillar.png` | 64×64 | **全透明，0 像素** | 空文件 |
| `tiles/props/window.png` | 64×96 | **全透明，0 像素** | 空文件 |
| `effects/damage_numbers.png` | 160×32 | **全透明，0 像素** | 伤害数字由字体渲染 |
| `effects/bullet_trail.png` | 16×4 | 纯黄条 | 拖尾由 `vfx_manager.spawn_bullet_trail()` 程序生成 |

**另外 12 张特效图有内容但零引用**，属于「画好了没接线」，未移除：
`achievement_unlock`、`btn_click`、`dodge_afterimage`、`freeze_effect`、`knife_spin`、
`levelup_aura`、`lightning_retaliate`、`magic_trail`、`petrify_effect`、`xp_collect`，
以及 `tiles/tile_obstacle`、`tile_wall`、`tile_wall_corner`、`ui/star_icon`、`weapons/xp_gem_medium`、`xp_gem_small`。

这些是成品而不是占位，留着不碍事；要启用得先决定是否用贴图替换程序特效。

验证：移除后 `Godot --import` 与运行 `res://scenes/main.tscn` 均 **exit=0**，无缺失引用报错。资产数 163 → 155。

---

## 十、「弱项精修」的结论：不需要改

上一轮我列了四个「弱项」，这一轮按**真实显示尺寸**（图标 48px、精灵 56px）重新看，结论是它们都不成立，两次修改都更差，已全部回滚（`md5` 与备份一致，`git status` 无改动）。

| 资产 | 我上轮的说法 | 实测 | 结论 |
|---|---|---|---|
| `icon_lightning` | 填充率仅 13.4% | 48px 下法杖轮廓清楚，填充率低只是因为它细 | 不改 |
| `icon_magic_book` | 紫光吞掉书本 | 48px 下能看出「紫符文 + 金书框」，辨识度够 | 不改 |
| `mage_cast` | 整体偏紫偏暗 | **p90 = 95**，与 `vampire_idle` 的 95 完全一致 | 不改 |
| `mage_teleport` | 同上 | **p90 = 96** | 不改 |

试过并否掉的两个方案：
1. **按 p90 做 gamma 提亮** → mage 两张 p90 只从 95 涨到 100，肉眼无差别（因为本来就不暗）；同时把 `icon_magic_book` 压得发闷。
2. **只降紫色饱和度、不动亮度** → 亮度确实一点没变（96→96、95→96），但紫袍变成灰扑扑的，丢了法师的身份色，比原图差。

**教训**：上一轮的「弱项」是从单帧统计和填充率指标推出来的，不是看图得出的。对小尺寸像素图，指标低不等于不可读——必须按真实显示尺寸看。

---

## 十一、下一步（按优先级）

1. **决定 12 张特效图是否接线** —— 若要让 `vfx_manager.gd` 用贴图，需要逐个替换程序绘制
2. **`lightning_bolt` / `lightning_chain` / `shop_bg`** —— 补之前先决定是否接线
3. **交互动效**（按钮悬停缩放、面板淡入）—— 纯代码工作

> 如果你发现我在做上面三件之外的事，说明我偏了，直接叫停。

