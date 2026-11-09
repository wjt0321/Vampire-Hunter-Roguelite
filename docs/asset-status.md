# 美术资产状态（单一事实来源）

> 最后更新：2026-11-09
> 这份文档回答三个问题：**现在做到哪了 / 依据是什么 / 下一步往哪走**。
> 与 `ROADMAP.md` Phase 12、`asset-licenses.md` 如有冲突，**以本文档为准**，并回头修正那两份。

---

## 一、一句话结论

**Phase 12 已完成闭环：出图、接线、文档三件都做完了；占位资产也清干净了。**

32 张角色精灵 + 37 张 UI/图标全部完成并与代码尺寸对齐；玩家四张动作图（攻击 / 受伤 / 死亡 / 护盾）已接进 `player.gd` 并通过单测；文档旧表已按「以代码为准」修正；**87 张脚本画的占位图（纯色块 / 渐变圆 / 带文字的调试方块）已全部重做成正式资产**（明细见 2.3）。

剩下的是三件需要你先定方向的事：特效图是否接线到 `vfx_manager`、3 个历史缺项是否补、交互动效是否做。

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

### 2.2 UI 与图标（37 张，全部完成）

| 类别 | 数量 | 说明 |
|---|---|---|
| 武器/被动图标 | 19 | 1024×1024 → **48×48**，BOX 下采样 + MEDIANCUT 32 色（11 张于第二轮补齐，见 2.3） |
| 血条边框 | 1 | 1536×1024 → 裁内容 → **200×24** |
| 菜单背景 | 2 | `menu_bg` 1344×768（压暗+暗角，让位菜单文字）、`defeat_bg` 1280×720 |
| 按钮三态 | 3 | `btn_normal` / `hover` / `pressed`，192×64 |
| 面板与槽位 | 10 | 菜单框、升级卡片、统计面板、商店槽位、波次牌、武器槽、被动槽、选中标记、成就图标、价格牌 |
| 角色 | 1 | `merchant` 128×128 |
| 主菜单图标 | 8 | 手画像素（`menu_play`/`character`/`shop`/`settings`/`quit`/`daily`/`crystal` 24×24、`menu_bat` 48×48），替换原来的 emoji 字形 |
| 售罄印章 | 1 | `sold_out` 64×24 |

校验：`verify_ui.py` **9/9 通过**

### 2.4 角色专属精灵：牧师塞西莉亚（6 张，2026-11-09 第三轮）

之前只有猎人一套玩家精灵，角色选择界面选牧师，**游戏里画面上还是猎人**——
卡片上那个「术」字就是这件事暴露出来的症状：没有立绘可放，只能塞一个字。

| 文件 | 尺寸 | 帧数 | 动作 |
|---|---|---|---|
| `priestess_idle` | 224×56 | 4 | 待机 |
| `priestess_run` | 336×56 | 6 | 移动 |
| `priestess_attack` | 224×56 | 4 | 攻击（一次性） |
| `priestess_hurt` | 112×56 | 2 | 受击 |
| `priestess_death` | 336×56 | 6 | 死亡（逐帧渐隐，末帧全透明） |
| `priestess_shield` | 224×56 | 4 | 护盾 |

- 存放：`assets/sprites/player/`，命名 `<角色id>_<动作>.png`
- 接线：`texture_manager.gd` 启动时扫这个目录自动登记成 `player_character_textures`；
  `player.gd` 的取图统一走 `_player_tex(state)`，按 `character_id` 取专属图，取不到回退通用图。
  **以后加角色只要丢 6 个文件，不用改代码。**
- 造型：以敌人的 `mage_cast`（连帽长袍剪影）作第一张的布局参考，
  其余五张以 `priestess_idle` 作参考保证是同一人；象牙白长袍 + 淡金刺绣 + 暗色内裙
- 校验：`verify_priestess.py` **6/6 通过**（尺寸/帧数/RGBA/每帧非空/四角透明/帧间有差异）

### 2.5 特效接线 / 界面动效 / 地板贴图处置（2026-11-09 第四轮）

这一轮解决的是「图做完了但没人用」：16 张特效图此前全部零引用，VFX 全靠
`vfx_manager.gd` 画圆环和粒子。

**16 张特效的落点**（全部接线，`grep` 可查）：

| 贴图 | 触发点 |
|---|---|
| `xp_collect` | 经验拾取（`spawn_xp_particles`） |
| `levelup_aura` | 升级（`spawn_levelup_particles`） |
| `boss_warning` | Boss 登场（`spawn_boss_warning`） |
| `freeze_effect` | 冰冻之心触发（`spawn_freeze_effect`） |
| `shield_break` | 护盾破碎（`player._break_shield`） |
| `dodge_afterimage` | 闪避（`spawn_dodge_effect`） |
| `poison_spread` | 毒云落点（`weapon_manager._spawn_poison_cloud`） |
| `chain_lightning` | 闪电链每跳一次的落点（`lightning_chain.gd`） |
| `thunder_wrath` | 闪电链进化「雷神之怒」开火 35% 概率 + 进化瞬间 |
| `holy_light` | 圣光弩 / 大天使之杖进化瞬间的圣光柱 |
| `knife_tornado` | 刀阵旋风成型（`_spawn_orbit_blades`） |
| `petrify_effect` | 石像鬼石化（`gargoyle._petrify`） |
| `lightning_retaliate` | 闪电护符反击（`player._lightning_retaliate`） |
| `achievement_unlock` | 成就解锁（HUD 在角色身上炸一圈金环） |
| `wave_start` | 波次横幅底光（`hud._show_wave_banner`） |
| `btn_click` | 所有按钮点击涟漪（`UiFx.click_ripple`） |

**动效怎么做**：贴图是单帧，统一走 `vfx_manager.spawn_texture_fx()` ——
Sprite2D + 「放大 + 淡出」tween + 加色混合，播完自毁。
不另做序列帧的理由：这些效果只有 0.2~0.9 秒，单帧扩散已经够读；
序列帧要多 8~10 倍文件，收益不成比例；tween 的时长和缩放还能按等级调。

**按贴图实际尺寸校准过的缩放**（踩过的坑）：`boss_warning` / `wave_start` /
`chain_lightning` 的源图都是 256，按默认 1.x 倍会铺满半个屏幕。
现在 boss 警告收到 1.3、波次底光固定 230px、连锁闪电收到 0.45。

**界面动效**（`scripts/ui/ui_fx.gd`，静态工具类 `UiFx`）：
- 悬停放大 1.05 + 按下回弹 0.96（大卡片 1.03，避免三张卡互相压边）
- 点击涟漪（`btn_click` 贴图，收在 90~230px，否则 64px 图放大会糊成一片金光）
- 面板淡入 0.18s（暂停/商店/选角的 Panel）
- 已接：主菜单、升级商店、选角、暂停、升级三选一、房间商店、结算页
- **注意**：`Control.scale` 只是绘制变换，不参与容器排版，所以能直接套在
  HBox/VBox 里；但 pivot 必须手动设到中心，否则按左上角放大整块往右下跑。
  暂停菜单是在 `get_tree().paused` 下弹的，补间要设 `TWEEN_PAUSE_PROCESS`。

**4 张地板贴图已删除**：`tiles/floor_{dungeon,castle,cave,boss}.png`。
房间地板用的是 `backgrounds/room_*.png` 整图（已实测四张背景全不透明，
地板、墙面、火把都画在里面），把 128×128 的平铺地板盖上去只会打架，
换掉整图又是美术方向的事。既然没有任何绘制路径会取它，就不留着占位。
`texture_manager` 的 `floor` 键与 `verify_placeholders` 的 4 行同步删除，
校验数从 87 → 83。需要恢复时从 git 历史（`57e7a12` 之前）取回即可。

### 2.6 试玩反馈回补：仍然"只有字没有图"的位置（2026-11-09 第五轮）

玩家试玩后的直接反馈：**「依旧有很多只有字没有图标的技能出现」** + **「阶段地图掉落道具没有图标」**。

上一轮（2.3）把武器/被动/商店/HUD/元进度四处的图标补齐了，但**还有三处从来没接过图标**。
这次不是靠猜，是三路交叉取证定位的：

| 取证方式 | 看到什么 |
|---|---|
| `grep` 全工程 `"icon"` / `icon_emoji` / 单字赋值 | 25 个成就共用一个 `"★"`；`powerup.gd` 用中文字「血/狂/磁」当图标；`cursed_chest.gd` 用 ColorRect + 「锁」字 |
| 无头枚举 `ItemCatalog.get_icon_texture()` | 武器 10 / 被动 14 / 属性 6 / 消耗品 4 **全部命中** → 映射层是好的，缺图在别处 |
| 截图核对（`tools/icon_evidence_shots.gd`） | 升级三选一、房间商店、元进度商店、HUD build 面板**都已有图标**（上一轮的成果） |

**结论：不是"图标映射漏了"，是这些位置压根没接图标。**

#### 2.6.1 新增资产（38 张）

| 类别 | 数量 | 文件 | 做法 |
|---|---|---|---|
| 成就徽章 | 25 | `assets/ui/ach_<成就id>.png` 48×48 | AI 双参考图 → 品红抠底 → BOX 下采样 → 32 色 |
| 角色被动图标 | 2 | `assets/ui/passive_hunter_instinct.png`、`passive_holy_ward.png` 48×48 | 同上 |
| 战场掉落物 | 4 | `assets/items/silver_coin.png`、`powerup_heal/frenzy/magnet.png` 48×48 | 同上 |
| 经验宝石三档 | 3 | `assets/items/xp_gem_{green,blue,gold}.png` 16/24/32 | **派生**：从已有 AI 原图 `weapons/xp_gem_large.png` 下采样 + 换色阶 |
| 受诅宝箱 | 1 | `assets/items/cursed_chest.png` 48×40 | **派生**：从 `tiles/props/chest.png` 改冷紫配色 + 背后紫雾 |
| UI 尺寸修正 | 2 | `assets/items/heal_potion_icon.png`、`blood_crystal_icon.png` 48×48 | **派生**：原图是 1024 / 24，当 48px 图标用会糊 |
| 宝石 UI 图标 | 1 | `assets/items/xp_gem_icon.png` 48×48 | **派生** |

**新出的 31 张全部走"构图草图"路线**（`.workbuddy/comfy/sketches.py`，31 个手写轮廓 → 品红底白形状）。
理由：管线是**图像编辑**（image_1 = 风格锚，image_2 = 形状参考），新资产没有占位图可参考时
`prep_shape_ref` 会退化成"拿风格锚当形状参考"——那瓶血瓶会让 31 个图标全部变成药瓶。
草图库先渲染成一张联络表人工核对形状，确认无误才喂给 ComfyUI。

**派生 7 张遵循既有原则「能派生就不重新生成」**（见 2.3）：派生版和原图像素级对齐、画风一致，
重新生成反而对不上。

#### 2.6.2 接线：哪些位置从"字"换成了"图"

| 位置 | 旧表现 | 现在 |
|---|---|---|
| 结算界面成就列表 | `game_over_ui.gd` 把 `info["icon"]` 拼成 `"★ 第一滴血"` 纯文字行 | 每行一张 48×48 专属徽章 + 名称；列表套 `ScrollContainer`（一局解锁 20+ 个时不会把面板撑出屏幕） |
| 成就解锁通知 | `IconRect` 绑通用 `achievement_icon.png`，25 个成就长一个样 | 换成该成就自己的徽章 |
| 角色选择界面被动技能 | 一个纯文字 Label（`"猎人直觉\n拾取范围 +20%"`） | 48×48 图标 + 名称/说明 |
| 战场经验宝石 | `ProjectileVisuals.style_gem()` 程序化发光菱形 | `assets/items/xp_gem_*.png`，尺寸同时上调（14/19/26 → 16/24/32） |
| 战场银币 | `style_sprite()` 画的 13px 发光圆点 | `assets/items/silver_coin.png` |
| 战场增益（血露/狂暴/磁力） | 程序化菱形 + 中文字「血/狂/磁」 | `assets/items/powerup_*.png`；中文字从数据里删掉，只留名字标签做冗余 |
| 受诅宝箱 | ColorRect 纯色块 + 中文字「锁」 | `assets/items/cursed_chest.png` |

**顺手清掉的"字符当图标"残留**（贴图永远能命中，留着就是口子）：
`achievement_manager.gd` 25 处 `"icon": "★"` → `"icon": "ach_<成就id>"`；
`upgrade_shop.gd` 6 处 `"icon": "攻"/"命"/"疾"/"甲"/"验"/"晶"` → 删除；
`powerup.gd` 3 处 `"icon": "血"/"狂"/"磁"` → 删除。

**尺寸修正**：`heal_potion` 原图 1024×1024、`blood_crystal` 原图 24×24，
当 48px 图标用分别是"糊成马赛克"和"非整数拉伸"。现在各有一个真正的 48×48 版本。

#### 2.6.3 收尾：把"字符当图标"这套机制整个拆掉

表层修完后再全工程 grep，还能搜出一整套**单字图标机制**。它不是这次的直接病因，
但正是"以后还会再犯"的根源——**新增一个物品忘了在 `ItemCatalog` 登记，
界面就会静默退化成"枪""书""刃"这种单字**，而单字长得像图标，玩家分不清是图标还是文字。

| 残留 | 位置 | 它为什么是口子 |
|---|---|---|
| `icon_emoji` 字段 | `weapon_data` / `passive_item_data` / `character_data` + 30 处赋值 | 武器/被动/角色都带一个单字（枪/书/刃/猎…） |
| `evolution_icon` | `weapon_evolution` + `EVOLUTION_CONFIG` 11 项 | 进化武器的单字 |
| catalog 的 `"icon": "枪"` | `item_catalog` 34 处 | 数据行里的单字 |
| **四处"拿不到贴图就显示单字"回退** | `hud` / `room_shop` / `upgrade_ui` / `elite_affix_controller` | 贴图缺失时静默退化成单字，**回归测试也测不出来** |

处理（一次性脚本 `tools/strip_char_icons.py`，共删 81 处字段/赋值）：

- 删掉 `icon_emoji` / `evolution_icon` 字段与全部赋值
- 删掉 `ItemCatalog` 34 处 `"icon": "枪"`、升级三选一 3 处 `"icon": ""`、
  `EliteAffix.icon()` 函数与词缀表 4 处 `"icon": "盾"`
- 四处回退分支改成**拿不到贴图就留白**：图标位空着一眼能看出缺图，
  `tools/verify_round4.gd` 会把缺图当成回归直接报出来（原来显示单字，回归测不出来）

另外把角色名前的"★"换成已有的 `assets/ui/star_gold.png`——这张资产早就注册进
`TextureManager`，但一直被字符 `"★ "` 顶替。

#### 2.6.4 顺带修的结算面板排版

截图核对时发现结算界面的标题和统计行**压在金框花纹上**。根因：
`game_over_ui.gd` 是全工程唯一没给 `stats_panel` 设 `texture_margin` 的面板
（主菜单 26/26/24/24、选角 48/48/62/60、商店、升级弹窗都设了）。

- `texture_margin` 上下改 56/28、`content_margin` 60/32
  （面板顶部中间有个向上凸的尖刺装饰，选角界面就是按 62/66 让的）
- 标题从 `StatsLabel` 里拆出来，单独一个 `TitleLabel`（字号 24），不再靠 `\n\n` 空行分隔
- 成就列表行高 140 → **152**（= 48×3 + 行距 4×2），第三行不再被裁掉半截

---

### 2.3 非正式资产替换（87 张，2026-11-09 第二轮）

**怎么区分正式与非正式**（这是这一轮的判据，写下来避免下次又混）：

| | 正式资产 | 非正式资产（占位） |
|---|---|---|
| 来源 | AI 生成 1024 源图 → BOX 下采样 | 早期脚本用 PIL 画的 |
| 文件体积 | 几十 KB ~ 1.4 MB | **几百字节 ~ 6 KB** |
| 外观 | 有描边、明暗层次、限定调色板 | 纯色块、径向渐变圆、带英文调试文字的方块 |
| 例子 | `death_explosion` / `hit_effect` / `heal_potion` | `poison_spread`（绿色渐变圆）/ `boss_warning`（红方块 + 文字） |

按这个判据全量盘点后，`assets/` 里 87 张是占位，已全部重做：

| 类别 | 数量 | 做法 | 为什么这么做 |
|---|---|---|---|
| 武器/被动图标 | 11 | AI 双参考图 → 48×48 | UI 固定按 48 画，原来的 32/64 会被非整数拉伸糊掉 |
| 场景道具 | 13 | 同上，保持原尺寸 | 房间装饰，按 1:1 贴地 |
| 柱子 | 4 | 同上，48×48 | 撞击体装饰 |
| 地板/墙体 | 12 | 每主题生成 1 张无缝材质 → roll+带内混合做四方连续 → 裁 128²/128×32/32×128 | 墙是按贴图尺寸平铺的，接缝必须对齐；一次生成供 3 个成品 |
| 特效 | 16 | 风格锚 `hit_effect` + **构图草图** → 品红抠底 | 只给文字描述会全出成"爆炸星芒"，加一张白色竖条/折线/圆环草图才能定形状 |
| UI 条形与派生 | 12 | 程序化 + 从成品派生 | 血条是 `StyleBoxTexture` 横向整图拉伸，AI 花纹会被拉成条纹 |
| 极小弹道 | 13 | 手排像素（8~16px） | 8px 交给 AI 只能得到糊块 |
| 二次派生 | 6 | 从本轮成品派生 | 毒云雾/传送门/血晶/墙砖必须和源头同一画风 |

**关键决定：能派生就不重新生成。** `star_gray` 从 `star_gold` 转灰度、`upgrade_card_hover` 从 `upgrade_card` 提亮+加金边、`xp_gem_small/medium` 从 `xp_gem_large` 缩、`knife_spin` 从 `icon_knife` 缩、`dodge_afterimage` 取 `player_idle` 首帧做剪影——派生版和原图**像素级对齐**，重新生成反而对不上。

**已知取舍**：特效都是单帧。清单里写的"8 帧/10 帧"没有做——代码目前是 `modulate`/`scale` tween 让单帧动起来，做序列帧需要另一轮（帧间一致性比单张难得多）。

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
| `verify_placeholders.py` | **83/83 通过**（87 张里 4 张地板贴图已删，见 2.5） |
| `verify_priestess.py` | **6/6 通过**（牧师六个动作） |
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

第三批（87 张占位资产替换，2026-11-09 18:04 → 19:01）：

| 项目 | 结果 |
|---|---|
| `verify_placeholders.py`（新增） | **87/87 通过**：尺寸、RGBA、四角透明、填充率、**品红残留 0 px**、条形图不透明 |
| `verify_all.py` / `verify_ui.py` | 仍是 **32/32** / **9/9**（精灵与已验收 UI 未被碰到） |
| 出图 | 主模型串行 60 张（11 图标 + 13 道具 + 4 柱子 + 4 材质 + 16 特效 + 1 场景 + 11 张重试），平均 **64 秒/张** |
| 程序化/派生 | 27 张（6 条形 + 3 星标/悬停卡/暂停/光环 + 13 极小弹道 + 6 二次派生） |
| Godot `--headless --import` | 0 个 ERROR |
| 运行 `res://scenes/main.tscn` | 0 个 SCRIPT ERROR / Parse Error |
| 顺手修的既有 bug | `main_menu.gd` 只写了 `anchors_preset`，`Control` 不在容器里时 rect 仍是 0×0 → **主菜单背景一直没显示，透出引擎清屏灰**；改成 `set_anchors_and_offsets_preset` 后正常（已用删改前后两张截图对照确认，不是本轮引入的） |
| 顺手修掉的既有 bug | `vampire_lord.gd:328` 的 `if sprite:` 缺缩进块，导致整个 Boss 脚本编译失败、Boss 战会崩（上一会话遗留） |

第四批（试玩反馈回补，2026-11-09 22:02 → 22:36）：

| 项目 | 结果 |
|---|---|
| 刷怪越界复测 | **0/200**（修前 15/200），增益落点 **0/40** |
| `tools/verify_round4.gd`（新增） | 成就徽章 25/25、角色被动 2/2、战场掉落物 10/10、元进度 6/6、词缀 4/4 全部有贴图；物品图标尺寸全部 ≤64px |
| `tools/audit_icons.py`（扩展） | 覆盖 4 组共 100+ 张图标，判据按"全透明 / 近乎单色 / 缩小后糊 / 体积异常"逐项查 |
| 出图 | ComfyUI 串行 31 张（25 成就 + 2 被动 + 4 掉落物），平均 **66 秒/张** |
| 程序化/派生 | 7 张（宝石三档 / 受诅宝箱 / 药瓶 48px / 血晶 48px / 宝石 UI 图标） |
| 顺手修的既有 bug | `wave_manager.gd` 用 `player.get_parent()` 当房间（那是 Main 不是房间）→ 边界钳制整段被静默跳过，**怪刷在地图外**；同源问题还有 `vampire_mage.gd` 瞬移、`weapon_manager.gd` 子弹射程。抽出 `scripts/core/room_lookup.gd` 作唯一房间解析入口 |

第五批（字符图标机制拆除 + 结算面板排版，2026-11-09 23:10 → 23:40）：

| 项目 | 结果 |
|---|---|
| 字符图标字段/赋值 | **81 处删除**（`icon_emoji` / `evolution_icon` / catalog 34 处 `"icon": "枪"` / `EliteAffix.icon()`），脚本 `tools/strip_char_icons.py` |
| 字符回退分支 | **4 处全部移除**（`hud` / `room_shop` / `upgrade_ui` / `elite_affix_controller`）→ 拿不到贴图就留白，缺图由 `verify_round4.gd` 当回归报出 |
| 全工程残留扫描 | `icon_emoji` / `evolution_icon` / `get("icon"` **0 命中**（仅剩一行说明性注释） |
| 角色名星号 | 字符 `"★ "` → `assets/ui/star_gold.png` 贴图（这张资产早已注册，一直被字符顶替） |
| 结算面板排版 | `texture_margin` 缺失导致标题/统计压金框 → 补 56/28 + content 60/32；标题拆成独立 `TitleLabel`；成就行高 140 → 152 |
| `tools/verify_round4.gd` 复跑 | **✅ 全部通过（0 项警告）**；刷怪 200 次 0 越界、增益 40 次 0 越界 |
| `tools/audit_icons.py` 复跑 | 4 组全部 OK（weapon 26 / ui 36 / item 11 / source 3） |
| 取证截图 | 9 张全部产出；逐张核对：掉落物 6 类图标、成就徽章 3 行、HUD 构筑 21 条目、选角被动 2 个，均为真实贴图 |
| README 截图 | 6 张重录（`menu` / `characters` / `shop` / `gameplay` / `upgrade` / `boss`），fail=0 |

---

## 七、回退方式

| 想回到 | 操作 |
|---|---|
| MVP 原版精灵 | `.workbuddy/backup/sprites/` 覆盖回 `assets/sprites/` |
| MVP 原版图标/UI | `.workbuddy/backup/icons/`、`.workbuddy/backup/ui/`、`.workbuddy/backup/ui_assets/` |
| 第二轮被替换的 87 张占位图 | `.workbuddy/backup/placeholders/`（保留 `assets/` 原目录结构，直接覆盖回去即可） |
| 48 格版本 | 改 `reskin_plan.json` 的 `cell` 为 48/96，跑 `reskin_pipeline.py --finalize-only` |
| 1024 原始底图 | `.workbuddy/comfy/raw_reskin/`（32 张）、`.workbuddy/comfy/raw_new/`（第二轮 60 张原始生成图 + `tex_*_tone.png` 提亮后材质） |
| 被清理的 8 张占位资源 | `.workbuddy/backup/dead-assets/`（保留原目录结构，直接移回 `assets/` 即可） |
| 「弱项精修」两次试改 | `.workbuddy/backup/refine2/`（已回滚，备份仅留档） |
| 牧师精灵（整套新增） | 删掉 `assets/sprites/player/priestess_*.png` 即回到「所有人共用猎人精灵」的状态，代码会走回退分支，不用改 |

---

## 八、明确没做的（边界，防止误以为漏了）

1. **`lightning_bolt` / `lightning_chain` / `shop_bg` 三个历史缺项决定不补**（2026-11-09 定）。
   闪电的落点电光已经有 `chain_lightning.png` 承担，再补一张 `lightning_bolt` 是重复；
   `lightning_chain` 只是武器 id 与场景名，没有独立的画面需求；
   `shop_bg` 对应的商店是挂在主菜单上的模态面板（`upgrade_shop.tscn` + `stats_panel` 金框），
   没有独立场景，铺一张全屏背景反而会把后面的主菜单盖掉。结论：从缺项清单里划掉。
2. ~~12 张特效图零引用~~ —— **已全部接线**，见 2.5。
3. **12.4 背景没改图**。背景全是 `TextureRect` 全屏拉伸，现有 `room_standard` / `menu_bg` 是成品美术，改尺寸看不出差别。
4. ~~交互动效没有做~~ —— **已完成**：悬停放大、按下回弹、点击涟漪、面板淡入，见 2.5。
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

**上一版这里写错了，更正**：初版把「另外 12 张特效图」当成「画好了没接线」，实际上它们全是脚本画的渐变圆/星芒/文字方块，属于占位。2026-11-09 第二轮已连同其余占位一起重做（见 2.3），现在这批零引用特效是**真成品**，接线时可以直接用：

`achievement_unlock`、`btn_click`、`dodge_afterimage`、`freeze_effect`、`knife_spin`、
`levelup_aura`、`lightning_retaliate`、`magic_trail`、`petrify_effect`、`xp_collect`，
以及 `tiles/tile_obstacle`、`tile_wall`、`tile_wall_corner`、`ui/star_icon`、`weapons/xp_gem_medium`、`xp_gem_small`。

它们目前零引用（`vfx_manager.gd` 走程序绘制），要启用得先决定是否用贴图替换程序特效。

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

1. **决定 16 张特效图是否接线** —— 若要让 `vfx_manager.gd` 用贴图，需要逐个替换程序绘制；贴图现在是单帧，动效要么靠 tween，要么另做序列帧
2. **`lightning_bolt` / `lightning_chain` / `shop_bg`** —— 补之前先决定是否接线
3. **交互动效**（按钮悬停缩放、面板淡入）—— 纯代码工作
4. **墙体只出现在房间四边 32px 的窄带上** —— 房间地板用的是 `backgrounds/room_*.png` 整图（`game_room.gd:_create_floor` 优先用背景图，背景缺失才回退纯色）。`floor_*` 材质没有任何绘制路径取用：`texture_manager` 会加载 `tile_textures[theme]["floor"]`，但全工程只取过 `wall` / `wall_v` / `pillar`。要么把它接成平铺地板，要么下次别再花时间出这 4 张

> 如果你发现我在做上面三件之外的事，说明我偏了，直接叫停。

