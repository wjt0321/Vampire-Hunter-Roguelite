# Vampire Hunter Roguelite 素材授权登记表

> 所有第三方素材、AI 生成素材、外包素材都应登记到这里。目标是保证后续发布、商用、开源或上架时不会被授权问题卡住。

---

## 一、登记规则

### 1. 必须登记的素材

以下来源都必须登记：

- 免费素材站下载的素材
- 付费素材包
- AI 生成素材
- 外包/约稿素材
- 从其他项目迁移或改造的素材
- 字体
- 音效和 BGM

### 2. 可以不登记的素材

以下内容可以不登记，但建议保留制作记录：

- 完全由项目作者原创绘制的素材
- Godot 默认图标或引擎自带资源
- 纯代码生成的临时占位图形

### 3. 风险标记

每条素材建议标注风险：

- `低`：明确 CC0 / Public Domain / 自制 / 已购买可商用
- `中`：允许商用但需要署名或有条件限制
- `高`：授权不明确、来源不明、AI 平台条款不清楚
- `禁止使用`：不允许商用、不允许修改、不允许打包发布、无法确认来源

---

## 二、授权检查清单

下载或使用素材前，确认：

- [ ] 是否允许商用
- [ ] 是否允许修改
- [ ] 是否允许打包进游戏发布
- [ ] 是否需要署名
- [ ] 是否需要保留原作者链接
- [ ] 是否禁止二次分发源文件
- [ ] 是否限制平台，例如 Steam、itch.io、移动端
- [ ] 是否限制 AI 训练或 AI 衍生使用
- [ ] 是否保留了来源页面 URL
- [ ] 是否保留了下载日期和素材版本

---

## 三、素材登记模板

复制以下模板新增条目：

```markdown
## 素材名称

- 状态：候选 / 已使用 / 已替换 / 已弃用
- 风险：低 / 中 / 高 / 禁止使用
- 类型：角色 / 敌人 / UI / 图标 / 地图 / 特效 / 音效 / BGM / 字体 / 宣传图 / 其他
- 来源 URL：
- 来源平台：Kenney / itch.io / OpenGameArt / CraftPix / GameDev Market / Pixabay / Freesound / AI / 外包 / 自制 / 其他
- 作者 / 版权方：
- 授权名称：CC0 / CC-BY / CC-BY-SA / MIT / Royalty Free / 商业授权 / 自制 / 待确认
- 是否允许商用：是 / 否 / 待确认
- 是否允许修改：是 / 否 / 待确认
- 是否需要署名：是 / 否 / 待确认
- 署名文本：
- 下载 / 生成日期：YYYY-MM-DD
- 原始文件保存位置：
- 项目内使用路径：
- 用途说明：
- 修改记录：
- 备注：
```

---

## 四、当前项目素材登记

> 初始仓库已有素材来源暂未逐项确认。后续若要正式发布，应回溯确认这些素材是自制、AI 生成、还是来自第三方素材包。

### 1. 初始仓库已有素材

- 状态：已使用
- 风险：待确认
- 类型：综合
- 来源 URL：项目初始仓库
- 来源平台：自有项目 / 待确认
- 作者 / 版权方：项目作者 / 待确认
- 授权名称：待确认
- 是否允许商用：待确认
- 是否允许修改：待确认
- 是否需要署名：待确认
- 下载 / 生成日期：2026-06-14 前已存在
- 项目内使用路径：
  - `assets/backgrounds/`
  - `assets/effects/`
  - `assets/sprites/`
  - `assets/ui/`
  - `assets/weapons/`
- 用途说明：当前游戏基础素材
- 修改记录：无
- 备注：后续若计划商用或公开发布，建议逐项确认来源。

---

### 2. 2026-06-15 批量整理新增素材

本次整理从 `assets-downloaded/` 中筛选授权友好的素材，统一命名后放入 `assets/`。主要来源为 Kenney（CC0）和 OpenGameArt（CC0/CC-BY）。

#### 2.1 Kenney UI Pack

- 状态：已使用
- 风险：低
- 类型：UI
- 来源 URL：https://kenney.nl/assets/ui-pack
- 来源平台：Kenney
- 作者 / 版权方：Kenney
- 授权名称：CC0
- 是否允许商用：是
- 是否允许修改：是
- 是否需要署名：否
- 下载 / 生成日期：2026-06-15
- 原始文件保存位置：`assets-downloaded/ui/kenney_ui-pack/`
- 项目内使用路径：
  - `assets/ui/weapon_slot.png`
  - `assets/ui/passive_slot.png`
  - `assets/ui/shop_slot.png`
  - `assets/ui/star_icon.png`
  - `assets/ui/star_gold.png`
  - `assets/ui/star_gray.png`
- 用途说明：HUD 槽位、商店格子、星标
- 修改记录：缩放、裁剪
- 备注：选用 Red / Yellow / Grey 主题以匹配暗黑哥特配色

#### 2.2 Kenney Game Icons

- 状态：已使用
- 风险：低
- 类型：图标
- 来源 URL：https://kenney.nl/assets/game-icons
- 来源平台：Kenney
- 作者 / 版权方：Kenney
- 授权名称：CC0
- 是否允许商用：是
- 是否允许修改：是
- 是否需要署名：否
- 下载 / 生成日期：2026-06-15
- 原始文件保存位置：`assets-downloaded/weapons/kenney_game-icons/`
- 项目内使用路径：
  - `assets/ui/btn_pause.png`
  - `assets/ui/selected_mark.png`
  - `assets/ui/achievement_icon.png`
  - `assets/weapons/icon_greed.png`
  - `assets/weapons/icon_lightning_shield.png`
  - `assets/weapons/icon_shadow.png`
- 用途说明：UI 按钮、选中标记、成就图标、被动道具图标占位
- 修改记录：缩放至目标尺寸
- 备注：部分图标为临时占位，后续可替换为主题更贴合的图标

#### 2.3 Kenney Particle Pack

- 状态：已使用
- 风险：低
- 类型：特效
- 来源 URL：https://kenney.nl/assets/particle-pack
- 来源平台：Kenney
- 作者 / 版权方：Kenney
- 授权名称：CC0
- 是否允许商用：是
- 是否允许修改：是
- 是否需要署名：否
- 下载 / 生成日期：2026-06-15
- 原始文件保存位置：`assets-downloaded/effects/kenney_particle-pack/`
- 项目内使用路径：
  - `assets/effects/levelup_aura.png`
  - `assets/effects/xp_collect.png`
  - `assets/effects/shield_break.png`
  - `assets/effects/magic_trail.png`
  - `assets/effects/knife_spin.png`
  - `assets/effects/btn_click.png`
  - `assets/effects/achievement_unlock.png`
  - `assets/weapons/bullet.png`
  - `assets/weapons/magic_orb.png`
  - `assets/weapons/knife.png`
  - `assets/weapons/icon_frozen.png`（占位）
- 用途说明：粒子特效、武器飞行体、UI 特效
- 修改记录：缩放、调色、组合
- 备注：使用 Transparent 目录下的 PNG

#### 2.4 Kenney Roguelike RPG Pack

- 状态：已使用
- 风险：低
- 类型：地图瓦片
- 来源 URL：https://kenney.nl/assets/roguelike-rpg-pack
- 来源平台：Kenney
- 作者 / 版权方：Kenney
- 授权名称：CC0
- 是否允许商用：是
- 是否允许修改：是
- 是否需要署名：否
- 下载 / 生成日期：2026-06-15
- 原始文件保存位置：`assets-downloaded/tiles/kenney_roguelike-rpg-pack/`
- 项目内使用路径：
  - `assets/tiles/tile_floor.png`
  - `assets/tiles/tile_floor_var1.png`
  - `assets/tiles/tile_floor_var2.png`
  - `assets/tiles/tile_wall.png`
  - `assets/tiles/tile_wall_corner.png`
  - `assets/tiles/tile_pillar.png`
  - `assets/tiles/tile_obstacle.png`
- 用途说明：地牢房间地板、墙壁、柱子、障碍物
- 修改记录：从 spritesheet 切片并放大至 32x32 / 64x64
- 备注：原始瓦片为 16x16，已使用最近邻插值放大

#### 2.5 Kenney Interface Sounds

- 状态：已使用
- 风险：低
- 类型：音效
- 来源 URL：https://kenney.nl/assets/interface-sounds
- 来源平台：Kenney
- 作者 / 版权方：Kenney
- 授权名称：CC0
- 是否允许商用：是
- 是否允许修改：是
- 是否需要署名：否
- 下载 / 生成日期：2026-06-15
- 原始文件保存位置：`assets-downloaded/audio/kenney_interface-sounds/`
- 项目内使用路径：
  - `assets/audio/sfx/sfx_click.ogg`
  - `assets/audio/sfx/sfx_hover.ogg`
  - `assets/audio/sfx/sfx_levelup.ogg`
  - `assets/audio/sfx/sfx_pickup_xp.ogg`
  - `assets/audio/sfx/sfx_coin.ogg`
- 用途说明：UI 点击、悬停、升级、拾取、金币
- 修改记录：重命名
- 备注：无

#### 2.6 Kenney Impact Sounds

- 状态：已使用
- 风险：低
- 类型：音效
- 来源 URL：https://kenney.nl/assets/impact-sounds
- 来源平台：Kenney
- 作者 / 版权方：Kenney
- 授权名称：CC0
- 是否允许商用：是
- 是否允许修改：是
- 是否需要署名：否
- 下载 / 生成日期：2026-06-15
- 原始文件保存位置：`assets-downloaded/audio/kenney_impact-sounds/`
- 项目内使用路径：
  - `assets/audio/sfx/sfx_shoot.ogg`
  - `assets/audio/sfx/sfx_hit_enemy.ogg`
  - `assets/audio/sfx/sfx_enemy_death.ogg`
  - `assets/audio/sfx/sfx_player_hurt.ogg`
  - `assets/audio/sfx/sfx_shield_break.ogg`
  - `assets/audio/sfx/sfx_explosion.ogg`
- 用途说明：射击、命中、死亡、受伤、护盾破碎、爆炸
- 修改记录：重命名
- 备注：无

#### 2.7 fins' Teleport

- 状态：已使用
- 风险：低
- 类型：音效
- 来源 URL：https://opengameart.org/content/teleport
- 来源平台：OpenGameArt
- 作者 / 版权方：fins
- 授权名称：CC0
- 是否允许商用：是
- 是否允许修改：是
- 是否需要署名：否
- 下载 / 生成日期：2026-06-15
- 原始文件保存位置：`assets-downloaded/audio/172206__fins__teleport.wav`
- 项目内使用路径：`assets/audio/sfx/sfx_teleport.wav`
- 用途说明：传送/瞬移音效
- 修改记录：重命名
- 备注：无

#### 2.8 RPG Inventory Icons

- 状态：已使用
- 风险：低
- 类型：图标
- 来源 URL：https://opengameart.org/content/rpg-inventory-icons
- 来源平台：OpenGameArt
- 作者 / 版权方：待确认（OpenGameArt 页面）
- 授权名称：CC0
- 是否允许商用：是
- 是否允许修改：是
- 是否需要署名：否
- 下载 / 生成日期：2026-06-15
- 原始文件保存位置：`assets-downloaded/weapons/rpg_inventory/`
- 项目内使用路径：
  - `assets/weapons/blood_crystal.png`
  - `assets/weapons/icon_regen.png`
  - `assets/weapons/icon_berserker.png`
- 用途说明：血晶、生命恢复、狂战士之血图标
- 修改记录：缩放至 24x24 / 32x32
- 备注：无

#### 2.9 "Beyond Redemption" BGM

- 状态：已使用
- 风险：中
- 类型：BGM
- 来源 URL：https://opengameart.org/content/beyond-redemption
- 来源平台：OpenGameArt
- 作者 / 版权方：matthew.pablo
- 授权名称：CC-BY 3.0
- 是否允许商用：是
- 是否允许修改：是
- 是否需要署名：是
- 下载 / 生成日期：2026-06-15
- 原始文件保存位置：`assets-downloaded/bgms/demo_Beyond Redemption_master_0.mp3`
- 项目内使用路径：`assets/audio/bgm/bgm_menu.mp3`
- 用途说明：主菜单背景音乐
- 修改记录：重命名
- 备注：需在 Credits 署名 matthew.pablo

#### 2.10 OpenGameArt 角色/敌人素材

- 状态：已使用
- 风险：中
- 类型：角色 / 敌人
- 来源平台：OpenGameArt
- 授权名称：CC0 / CC-BY（见各资源页面）
- 是否允许商用：是
- 是否允许修改：是
- 是否需要署名：CC-BY 需署名
- 下载 / 生成日期：2026-06-15
- 原始文件保存位置：`assets-downloaded/sprites/`
- 项目内使用路径：
  - `assets/sprites/enemies/summoner_cast.png`（来源：`NecroGuy_01.gif`，CC0）
  - `assets/sprites/enemies/mage_cast.png`（来源：`mage.png`，CC0）
  - `assets/sprites/enemies/gargoyle_idle.png`（来源：`gargoyle.png`，CC0）
  - `assets/sprites/enemies/prince_idle.png`（来源：`vampire-f-001.png`，免费商用/CraftPix）
- 用途说明：高级敌人占位素材
- 修改记录：缩放至目标尺寸、GIF 提取首帧
- 备注：部分素材为占位，后续需替换为统一风格的终版动画

#### 2.11 程序生成 / 派生素材

- 状态：已使用
- 风险：低
- 类型：UI / 特效 / 瓦片 / 道具
- 来源平台：自制 / 从已有素材派生
- 授权名称：自制
- 是否允许商用：是
- 是否允许修改：是
- 是否需要署名：否
- 下载 / 生成日期：2026-06-15
- 项目内使用路径：
  - `assets/ui/btn_pressed.png`（从 `btn_hover.png` 压暗生成）
  - `assets/ui/upgrade_card_hover.png`（从 `upgrade_card.png` 加金色边框）
  - `assets/ui/hp_bar_bg.png` / `assets/ui/xp_bar_bg.png`（黑色背景）
  - `assets/ui/boss_hp_bg.png` / `assets/ui/boss_hp_fill.png`
  - `assets/ui/price_tag.png` / `assets/ui/sold_out.png` / `assets/ui/wave_number_bg.png` / `assets/ui/stats_panel.png`
  - `assets/ui/evolution_glow.png`
  - `assets/weapons/xp_gem_medium.png` / `assets/weapons/xp_gem_small.png`（从 `xp_gem_large.png` 缩放）
  - `assets/effects/bullet_trail.png`
  - `assets/effects/damage_numbers.png`（占位）
  - `assets/tiles/props/torch.png` / `window.png` / `coffin.png` / `bookshelf.png` / `cobweb.png` / `blood_splatter.png`（占位）
  - `assets/backgrounds/room_square.png`（占位）
  - `assets/sprites/boss/boss_attack3.png` / `assets/sprites/boss/boss_death.png`（从 `boss_idle.png` 复制占位）
- 用途说明：补齐缺口、临时占位
- 修改记录：程序生成或从已有素材派生
- 备注：占位素材标注为 placeholder，后续需替换为正式美术资源

---

### 3. 2026-06-16 风格统一补素材

本轮重点：为之前没有贴图的高级敌人补充风格统一的像素精灵，替换程序化占位 BGM，补齐缺失的特效/UI 占位图。

#### 3.1 FreeGameSprites 敌人精灵

- 状态：已使用
- 风险：低
- 类型：敌人
- 来源 URL：https://freegamesprites.com
- 来源平台：FreeGameSprites
- 作者 / 版权方：FreeGameSprites（AI 生成，CC0）
- 授权名称：CC0
- 是否允许商用：是
- 是否允许修改：是
- 是否需要署名：否
- 下载 / 生成日期：2026-06-16
- 原始文件保存位置：`assets-downloaded/sprites/freegamesprites/`
- 项目内使用路径：
  - `assets/sprites/enemies/exploder_walk.png`（来源：`infernal-flame-skull.png`）
  - `assets/sprites/enemies/gargoyle_idle.png`（来源：`brimstone-gargoyle.png`）
  - `assets/sprites/enemies/mage_cast.png`（来源：`bone-mage-caster.png`）
  - `assets/sprites/enemies/summoner_cast.png`（来源：`lich-crowned-necromancer.png`）
  - `assets/sprites/enemies/prince_idle.png`（来源：`vampire-count.webp`）
- 用途说明：为波次中后期敌人提供可见精灵
- 修改记录：裁切透明边、统一为 256x256 方形、转 PNG
- 备注：CC0，可直接商用

#### 3.2 FreeGameSprites 商人 / UI 素材

- 状态：已使用
- 风险：低
- 类型：UI / 角色
- 来源 URL：https://freegamesprites.com
- 来源平台：FreeGameSprites
- 作者 / 版权方：FreeGameSprites（AI 生成，CC0）
- 授权名称：CC0
- 是否允许商用：是
- 是否允许修改：是
- 是否需要署名：否
- 下载 / 生成日期：2026-06-16
- 原始文件保存位置：`assets-downloaded/sprites/freegamesprites/`
- 项目内使用路径：
  - `assets/ui/merchant.png`（来源：`spice-merchant-bearded-robed.png`）
- 用途说明：商店界面商人立绘
- 修改记录：裁切透明边、缩放至 128x128
- 备注：CC0

#### 3.3 OpenGameArt BGM

- 状态：已使用
- 风险：低
- 类型：BGM
- 来源平台：OpenGameArt
- 授权名称：CC0
- 是否允许商用：是
- 是否允许修改：是
- 是否需要署名：否
- 下载 / 生成日期：2026-06-16
- 原始文件保存位置：`assets-downloaded/audio/oga/`
- 项目内使用路径：
  - `assets/audio/bgm/bgm_battle.mp3`（来源：`battleThemeA_0.mp3`，作者：Eric Matyas / Pixelsphere，CC0）
  - `assets/audio/bgm/bgm_boss.ogg`（来源：`basilisk_boss_battle_in_game_0.ogg`，CC0）
- 用途说明：替换原先程序生成的战斗/Boss BGM
- 修改记录：重命名
- 备注：原先程序生成的 `bgm_battle.wav` / `bgm_boss.wav` 已删除

#### 3.4 程序生成占位特效 / UI

- 状态：已使用
- 风险：低
- 类型：特效 / UI
- 来源平台：自制 / 代码生成
- 授权名称：自制
- 是否允许商用：是
- 是否允许修改：是
- 是否需要署名：否
- 下载 / 生成日期：2026-06-16
- 项目内使用路径：
  - `assets/effects/poison_spread.png`
  - `assets/effects/chain_lightning.png`
  - `assets/effects/holy_light.png`
  - `assets/effects/knife_tornado.png`
  - `assets/effects/thunder_wrath.png`
  - `assets/effects/wave_start.png`
  - `assets/effects/crit_text.png`
  - `assets/effects/boss_warning.png`
  - `assets/weapons/shotgun_pellet.png`
  - `assets/weapons/poison_cloud.png`
  - `assets/ui/victory_bg.png`
  - `assets/ui/defeat_bg.png`
  - `assets/ui/menu_frame.png`
- 用途说明：补齐资产缺口，方便后续替换
- 修改记录：使用 Python/Pillow 程序化绘制
- 备注：均为占位，后续可替换为正式美术

---

## 五、推荐优先登记批次

### P0：优先登记

这些素材一旦引入，最容易进入最终游戏包，必须第一时间登记：

- UI 包
- 图标包
- 音效包
- BGM
- 字体
- tileset
- Boss / 主角终版素材

### P1：随后登记

- 高级敌人素材
- 环境装饰物
- 特效序列帧
- 商店/结算界面素材

### P2：发布前登记

- 宣传图
- 封面图
- itch.io / Steam 页面素材
- 预告片音乐和音效

---

## 六、署名文本暂存区

> 如果素材授权要求署名，把最终需要放进 README、游戏 Credits 或发布页的文本集中放这里。

```text
暂无
```

---

## 七、弃用素材记录

> 曾经下载或尝试使用、但最终不进入游戏包的素材也可以记录，避免未来误用。

```markdown
## 弃用素材名称

- 弃用原因：风格不符 / 授权不清 / 不允许商用 / 质量不足 / 已被替换
- 原来源 URL：
- 原项目路径：
- 处理方式：已删除 / 已移出项目 / 保留在外部素材库
- 日期：YYYY-MM-DD
```

## Noto Sans CJK SC Regular

- 状态：已使用
- 风险：低
- 类型：字体
- 来源 URL：https://github.com/notofonts/noto-cjk
- 来源平台：Google Noto Fonts (GitHub)
- 作者 / 版权方：Google Inc.
- 授权名称：OFL (SIL Open Font License) 1.1
- 是否允许商用：是
- 是否允许修改：是
- 是否需要署名：否（OFL 不要求署名，但需保留授权文件）
- 下载 / 生成日期：2026-06-16
- 原始文件保存位置：assets/fonts/NotoSansCJKsc-Regular.otf
- 项目内使用路径：assets/fonts/NotoSansCJKsc-Regular.otf
- 用途说明：游戏主界面、HUD、伤害数字等所有中文显示
- 修改记录：无
- 备注：通过本地代理从 GitHub 下载

## 程序化 BGM（战斗 / Boss）

- 状态：已替换
- 风险：低
- 类型：BGM
- 来源 URL：N/A
- 来源平台：自制 / 代码生成
- 作者 / 版权方：项目作者
- 授权名称：自制
- 是否允许商用：是
- 是否允许修改：是
- 是否需要署名：否
- 下载 / 生成日期：2026-06-16
- 原始文件保存位置：scripts/managers/audio_library.gd
- 项目内使用路径：~~assets/audio/bgm/bgm_battle.wav、assets/audio/bgm/bgm_boss.wav~~（已删除）
- 用途说明：战斗房间与 Boss 战背景音乐临时占位，现已替换为 OpenGameArt CC0 音乐
- 修改记录：使用 AudioLibrary 中的正弦波/噪声生成算法导出为 WAV；2026-06-16 删除并替换
- 备注：AudioLibrary 中仍保留程序生成作为音频文件缺失时的 fallback
