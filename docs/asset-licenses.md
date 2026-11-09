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
  - `assets/audio/sfx/sfx_hit_enemy.ogg`
  - `assets/audio/sfx/sfx_enemy_death.ogg`
  - `assets/audio/sfx/sfx_player_hurt.ogg`
  - `assets/audio/sfx/sfx_shield_break.ogg`
- 用途说明：命中、死亡、受伤、护盾破碎
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

#### 2.7a Kenney Sci-Fi Sounds

- 状态：已使用
- 风险：低
- 类型：音效
- 来源 URL：https://kenney.nl/assets/sci-fi-sounds
- 来源平台：Kenney
- 作者 / 版权方：Kenney
- 授权名称：CC0
- 是否允许商用：是
- 是否允许修改：是
- 是否需要署名：否
- 下载 / 生成日期：2026-06-16
- 原始文件保存位置：`assets-downloaded/audio/kenney_sci-fi-sounds/`
- 项目内使用路径：
  - `assets/audio/sfx/sfx_shoot.ogg`（来源：`laserSmall_000.ogg`）
  - `assets/audio/sfx/sfx_shoot_shotgun.ogg`（来源：`explosionCrunch_000.ogg`）
  - `assets/audio/sfx/sfx_shoot_magic.ogg`（来源：`forceField_000.ogg`）
  - `assets/audio/sfx/sfx_poison_cloud.ogg`（来源：`slime_000.ogg`）
  - `assets/audio/sfx/sfx_lightning_chain.ogg`（来源：`laserRetro_000.ogg`）
  - `assets/audio/sfx/sfx_boss_attack.ogg`（来源：`lowFrequency_explosion_000.ogg`）
  - `assets/audio/sfx/sfx_explosion.ogg`（来源：`explosionCrunch_002.ogg`）
- 用途说明：武器射击、技能、Boss 攻击、爆炸
- 修改记录：重命名
- 备注：无

#### 2.7b Kenney RPG Audio

- 状态：已使用
- 风险：低
- 类型：音效
- 来源 URL：https://kenney.nl/assets/rpg-audio
- 来源平台：Kenney
- 作者 / 版权方：Kenney
- 授权名称：CC0
- 是否允许商用：是
- 是否允许修改：是
- 是否需要署名：否
- 下载 / 生成日期：2026-06-16
- 原始文件保存位置：`assets-downloaded/audio/kenney_rpg-audio/`
- 项目内使用路径：
  - `assets/audio/sfx/sfx_knife_throw.ogg`（来源：`knifeSlice.ogg`）
- 用途说明：飞刀射击音效
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

#### 3.4 暗黑哥特 UI 主题生成

- 状态：已使用
- 风险：低
- 类型：UI
- 来源平台：Kenney UI Pack + PixelUIpack（CC0）经 Python/Pillow 调色生成
- 授权名称：CC0
- 是否允许商用：是
- 是否允许修改：是
- 是否需要署名：否
- 下载 / 生成日期：2026-06-16
- 原始文件保存位置：
  - `assets-downloaded/ui/kenney_ui-pack/PNG/Red/Default/`
  - `assets-downloaded/ui/PixelUIpack/9-Slice/Ancient/`
- 项目内使用路径：
  - `assets/ui/btn_normal.png` / `btn_hover.png` / `btn_pressed.png`
  - `assets/ui/upgrade_card.png` / `upgrade_card_hover.png`
  - `assets/ui/shop_slot.png` / `stats_panel.png` / `menu_frame.png`
  - `assets/ui/weapon_slot.png` / `passive_slot.png`
  - `assets/ui/hp_bar_fill.png` / `hp_bar_bg.png` / `xp_bar_fill.png` / `xp_bar_bg.png`
  - `assets/ui/boss_hp_fill.png` / `boss_hp_bg.png`
  - `assets/ui/wave_number_bg.png` / `price_tag.png` / `sold_out.png`
  - `assets/ui/selected_mark.png` / `btn_pause.png`
  - `assets/ui/victory_bg.png` / `defeat_bg.png`
- 用途说明：统一游戏整体 UI 风格
- 修改记录：去饱和、压暗、暗红/黑金调色、目标尺寸生成
- 备注：生成脚本见 `tools/process_assets.py`

#### 3.5 OpenGameArt 新增 BGM

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
  - `assets/audio/bgm/bgm_victory.ogg`（来源：`ForgottenVictory.ogg`，作者：yd，CC0）
  - `assets/audio/bgm/bgm_defeat.mp3`（来源：`WhatIsLeft_0.mp3`，作者：SeKa，CC0）
  - `assets/audio/bgm/bgm_shop.ogg`（来源：`Tavern_0.ogg`，作者：yd，CC0）
- 用途说明：胜利结算、失败结算、商店房间背景音乐
- 修改记录：重命名
- 备注：无

#### 3.6 程序生成占位特效 / UI

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
  - `assets/sprites/enemies/exploder_explode.png`
  - `assets/sprites/enemies/mage_teleport.png`
  - `assets/sprites/enemies/gargoyle_petrify.png`
  - `assets/sprites/enemies/gargoyle_wake.png`
  - `assets/sprites/enemies/prince_dash.png`
  - `assets/sprites/enemies/prince_rage.png`
  - `assets/sprites/boss/boss_attack3.png`
  - `assets/sprites/boss/boss_death.png`
- 用途说明：补齐资产缺口，方便后续替换
- 修改记录：使用 Python/Pillow 从已有贴图派生生成
- 备注：均为占位，后续可替换为正式逐帧动画

#### 3.7 房间主题瓦片与装饰物

- 状态：已使用
- 风险：低
- 类型：地图 / 装饰物 / 特效
- 来源平台：自制 / 代码生成
- 授权名称：自制
- 是否允许商用：是
- 是否允许修改：是
- 是否需要署名：否
- 下载 / 生成日期：2026-06-16
- 项目内使用路径：
  - `assets/tiles/wall_dungeon.png` / `wall_dungeon_v.png`
  - `assets/tiles/wall_castle.png` / `wall_castle_v.png`
  - `assets/tiles/wall_cave.png` / `wall_cave_v.png`
  - `assets/tiles/wall_boss.png` / `wall_boss_v.png`
  - `assets/tiles/pillar_dungeon.png` / `pillar_castle.png` / `pillar_cave.png` / `pillar_boss.png`
  - `assets/tiles/floor_dungeon.png` / `floor_castle.png` / `floor_cave.png` / `floor_boss.png`
  - `assets/tiles/props/torch.png`
  - `assets/tiles/props/coffin.png`
  - `assets/tiles/props/bookshelf.png`
  - `assets/tiles/props/statue.png`
  - `assets/tiles/props/altar.png`
  - `assets/tiles/props/broken_pillar.png`
  - `assets/tiles/props/blood_splatter.png`
  - `assets/tiles/props/cobweb.png`
  - `assets/effects/portal.png`
- 用途说明：为房间生成提供主题化墙壁、柱子、地板与装饰物，提升单局视觉多样性
- 修改记录：使用 Python/Pillow 程序化生成
- 备注：均为占位，后续可替换为正式 tileset 与手绘装饰物

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

## AI 生成角色精灵（ComfyUI / Qwen-Image2.1）

- 状态：已替换（Phase 12）
- 风险：低（本机生成，未引入第三方素材）
- 类型：角色 / 敌人 / Boss 精灵横条
- 来源 URL：N/A
- 来源平台：本机 ComfyUI，现役工作流 `E:\AI\ComfyUI\user\default\workflows\图片_Qwen-Image2.1_文生图.json`
- 作者 / 版权方：项目作者（AI 辅助生成）
- 授权名称：自制
- 是否允许商用：是
- 是否允许修改：是
- 是否需要署名：否
- 下载 / 生成日期：2026-11-09
- 原始文件保存位置：`.workbuddy/comfy/raw/`（1024×1024 底图）
- 项目内使用路径：`assets/sprites/player/`、`assets/sprites/enemies/`、`assets/sprites/boss/` 共 32 张
- 用途说明：按 `docs/GDD.md` 12.3 与 `docs/art-assets-requirements.md` 第一节重绘全套精灵；48×48 格（Boss 96×96）、RGBA 透明底、8 帧/秒
- 修改记录：1024 底图 → Python PIL 抠品红底 / 限 32 色 / 黑描边 / 拼横条；替换前的旧图备份于 `.workbuddy/backup/sprites/`
- 备注：模型权重为本机 Qwen-Image2.1 int8；同一角色固定 seed，未做参考图锁定

### 2026-11-09 重做（取代上一版 AI 文生图）

上一版用 Qwen 文生图从零生成，未参考项目既有美术，风格偏暗写实、与游戏不符，已全部替换。

- 状态：已替换（Phase 12 第二轮）
- 风险：低；素材来自项目自身 `assets-downloaded/` 采集包与本机参考图生成
- 来源 A（18 张）：`assets-downloaded/sprites/` 的成套像素帧——Gothicvania patreon collection（hero idle/run/attack/hurt、demon、ghost、hell-hound、wolf、fire-skull）、`pixel-skeleton`、`vampire-1.1`、`zombie-1.1`、`bat-1.3`、`gargoyle.png`、`mage`/`NecroGuy` 等；对应第三方授权见本文件各采集包条目与 `docs/reports/collection-report-characters.md`
- 来源 B（14 张）：`图片_Qwen-Image2.1_图像编辑.json` 参考图生成；参考图取自本仓库已完成 MVP 的原有精灵（`.workbuddy/backup/sprites/`），只改动作、不改造型配色
- 线上补缺：Scrapling 0.4.10（代理 127.0.0.1:10808）抓取 OGA / CraftPix 共 3 页，所得 `vampire1.zip`、`vampire-1.1.zip` 项目内已存在，CraftPix 免费包需登录，未引入新素材
- 修改记录：取帧 → 裁透明边 → 整数倍 NEAREST 缩放 → 复用 `tools/build_pose_strips.py` 错帧/淡出/石化手法 → 拼 48×48（Boss 96×96）RGBA 横条
- 原始底图：`.workbuddy/comfy/raw_edit/`、参考帧 `.workbuddy/comfy/refs/`；替换前旧图备份 `.workbuddy/backup/sprites/`
- 备注：全流程串行出图，逐张耗时见 `.workbuddy/comfy/edit_batch.log`；`verify_all` 32/32 通过

### 2026-11-09 造型精修（5 张由 A 转 B）

`player_idle`、`zombie_walk`、`exploder_walk`、`werewolf_charge`、`skeleton_idle` 原用采集包成套帧，风格虽对但**角色身份与已完成 MVP 的原设定不符**（金发跑者替代宽檐帽猎人、白衣人替代绿皮僵尸/燃烧骷髅、白狼替代棕狼人、白蓝大骷髅替代持斧骷髅）。本地采集包再搜一遍确认无更贴合成套帧后，改用参考图生成。

- 来源：`图片_Qwen-Image2.1_图像编辑.json`，参考图仍取自 `.workbuddy/backup/sprites/` 的 MVP 旧精灵，只改动作、不改造型配色
- 修正后路线统计：采集包帧 **13 张** / 参考图生成 **19 张**，合计 32 张
  - ⚠️ 此为**第二版**统计。随后「按图标审美全量重制」一轮已把 32 张全部换成参考图生成（采集包帧归零），当前有效状态见本文件最后两条与 [asset-status.md](asset-status.md)
- 任务清单 `out/refine_plan.json`，逐张耗时见 `.workbuddy/comfy/edit_batch.log`（15:01:23 → 15:03:51，全程串行）
- 对照图 `out/refine_before.png` / `out/refine_after.png`；`verify_all` 32/32 通过
- 备注：清单二节以后的尺寸差异属于文档旧表与实际 MVP 演进的差别，现有 UI/背景/特效风格一致，**未批量重做**，以免破坏已跑通的界面

### 2026-11-09 Phase 12.3 UI（图标与血条边框）

- 状态：已替换 9 张（8 图标 + 1 血条边框），其余 UI 尺寸未动
- 来源：**无新增第三方素材**。均为本项目既有 PNG 的规格转换：
  - 8 张武器/被动图标 `assets/weapons/icon_{pistol,shotgun,magic_book,knife,poison,lightning,magnet,shield}.png`：原 1024×1024 → 48×48 像素图标（BOX 下采样 + MEDIANCUT 32 色），原图备份 `.workbuddy/backup/icons/`
  - `assets/ui/hp_bar_border.png`：1536×1024 画布中裁出 1419×287 实际内容 → 200×24，原图备份 `.workbuddy/backup/ui/`
- 尺寸依据：`scripts/ui/upgrade_ui.gd:528` 实际为 `custom_minimum_size = Vector2(48,48)`，按 GDD 附录 C「以代码为准」取 48，而非清单旧表的 32×32
- 校验：`verify_ui.py` 9/9 通过；Godot 4.7.2 无头导入与运行均 exit=0
- 脚本：`.workbuddy/comfy/pixelate_icons.py`、`verify_ui.py`；试点对比 `out/icon_pilot.png`、`out/icon_ab.png`

### 2026-11-09 精灵全量重制（第三轮，审美基准 = 现有 1024 图标）

前两版审美均被否（第一版暗色写实、第二版采集包幼态）。本版以项目现有 1024 图标（暗钢/皮革/金边/深红/高对比）为风格锚重做。

- 状态：已替换全部 32 张（Phase 12 第三轮）
- 模型/工作流：`图片_Qwen-Image2.1_图像编辑.json`（Qwen-Image2.1 int8，1024×1024，25 步）
- 双参考图：`image_1` = 本仓库既有 1024 图标（风格锚，属本项目资产）；`image_2` = 本仓库 MVP 旧精灵（造型锚）
- 提示词约束：mature 6-head proportions、禁止 chibi/cute/cartoon、Boss 动作禁止发光气场与紫色能量
- 后处理：品红键控 → 48/96 格 → gamma 亮度校正（p90→95，只抬暗部）→ 复用 `tools/build_pose_strips.py` 错帧/淡出 → 拼横条
- 产物与底图：`assets/sprites/**`；1024 原图 `.workbuddy/comfy/raw_reskin/`；总览 `out/reskin_final_sheet.png`
- 脚本：`.workbuddy/comfy/reskin_pipeline.py`（可续跑），任务表 `out/reskin_plan.json`
- 备注：全程串行，共 35 次出图（32 张 + 3 张 Boss 重跑），15:29:50 → 16:09:42；`verify_all` 32/32 通过；Godot 导入与运行 exit=0
- 可回退：MVP 原版 `.workbuddy/backup/sprites/`；上一版可由 `rebuild.py` 从 `assets-downloaded` 重建

### 2026-11-09 菜单/UI 重制（17 张）

- 状态：已替换 17 张（2 背景 / 3 按钮 / 5 面板 / 6 小件 / 1 角色）
- 模型/工作流：`图片_Qwen-Image2.1_图像编辑.json`，直接按目标比例设置节点 width/height
- 双参考图：`image_1` = 本项目 1024 图标（风格锚）；`image_2` = 本项目原 UI 图（构图锚）
- 后处理：玫红/品红键控 → 裁切缩放 → gamma 提亮（p90→112）；背景类改为压暗 + 暗角 + 轻虚化，保证菜单文字可读
- 产物：`assets/ui/**`（16 张）、`assets/backgrounds/menu_bg.png`；原图备份 `.workbuddy/backup/ui_assets/`
- 总览 `out/ui_set_v3.png`；脚本 `.workbuddy/comfy/ui_reskin.py`，任务表 `out/ui_reskin_plan.json`
- 备注：16:15:52 → 16:34:11 共 19 次出图，全程串行；Godot 导入与运行 exit=0
- 未做：`victory_bg`（现有可用）、`star_icon` 系列（16px 不适合生成）、`evolution_glow`（适合程序绘制）、`game_logo`（现有已达标）

### 2026-11-09 精灵规格对齐与品红残边清理（32 张）

- 状态：已替换全部 32 张；**无新增素材、无新增出图**，全部为既有 1024 底图的规格转换
- 格子尺寸：`48×48 → 56×56`、`96×96 → 128×128`
- 尺寸依据（GDD 附录 C「以代码为准」）：
  - `scripts/player/player.gd:176` → `SpriteSheetLib.apply(sprite, texture, 56.0)`
  - `scripts/enemies/enemy_base.gd:319` → `_present_sprite(56.0)`
  - `scripts/enemies/vampire_lord.gd:273` → `_present_sprite(128.0 * size_mult)`
  - 目的：图素与屏幕像素 **1:1**，消除 48→56 的 1.167 倍非整数 NEAREST 拉伸（`sprite_sheet.gd:43` 设的是 `TEXTURE_FILTER_NEAREST`，非整数放大时像素列宽会在 1px/2px 间跳）
- 缺陷修复：新增 `purge_purple_edge()`，清除「黑角色 ↔ 品红背景」抗锯齿过渡带在脚下形成的紫红横线（修复前 21/32 张有，砖墙/石板背景上明显）。三轮判据演进见 [asset-status.md](asset-status.md) 第五节
- 保留的设计性紫色：`boss_enraged` 披风内衬（`h=27~47` 竖直块）、`gargoyle` 石化冷色（B 通道 ×1.08）——均按形状与位置区分，未被误清
- 产物：`assets/sprites/**`（尺寸分布 `224×56`×20、`336×56`×4、`112×56`×2、`512×128`×6）
- 脚本：`.workbuddy/comfy/reskin_pipeline.py`（`--finalize-only`），任务表 `out/reskin_plan.json`
- 备注：16:54 → 17:13 完成，纯本地后处理；`verify_all` 32/32；底部紫带残留 0 张；Godot 导入与运行 exit=0
- 可回退：改 `reskin_plan.json` 的 `cell` 为 48/96 重跑即可回到上一版

### 2026-11-09 占位资产全量替换（87 张）

- 状态：已替换 87 张脚本画的占位图（纯色块 / 径向渐变圆 / 带英文调试文字的方块）
- 判据：正式资产 = AI 生成 1024 源图下采样（体积几十 KB ~ 1.4 MB）；占位 = PIL 脚本绘制（体积几百字节 ~ 6 KB，无描边、无明暗层次）
- 模型 / 工作流：本机 ComfyUI + `图片_Qwen-Image2.1_图像编辑.json`（Qwen-Image 2.1 int8，**本地离线推理**，未调用任何在线服务）；节点 `width/height` 按目标比例设置（场景图 1024×576，其余 1024×1024）
- 参考图策略：
  - 单体 / 图标 / 道具：`image_1` = `assets/weapons/heal_potion.png`（1024，已验收的厚像素风格锚）；`image_2` = 被替换的原占位图（只提供构图与朝向）
  - 特效：`image_1` = `assets/effects/hit_effect.png`（特效语言）；`image_2` = **构图草图**（品红底 + 白色竖条 / 折线 / 圆环，由 `make_sketch()` 生成）
  - 材质：`image_1` = `assets/backgrounds/room_standard.png`（房间既有石墙配色）
- 后处理：品红键控 → BOX 下采样 → MEDIANCUT 量化（40 / 56 / 96 色）；材质额外做分位数提亮（原始生成图均值仅 24/255）+ 1.1px 预模糊压掉缩小噪点；四方连续用 `np.roll` + 接缝带混合
- 产物分布：`weapons/` 22、`tiles/` 19、`tiles/props/` 13、`effects/` 21、`ui/` 12
- 脚本：`.workbuddy/comfy/newarts.py`（AI 60 张，`--group` 分批）、`ui_proc.py`（27 张程序化 / 派生）、`verify_placeholders.py`（87 项校验）
- 备注：18:04 → 19:01 全程串行出图；`verify_placeholders` 87/87、`verify_all` 32/32、`verify_ui` 9/9；Godot 导入 0 error
- 授权：登记为「AI 生成素材，风险 中」（生成物在部分地区版权归属不明确；Qwen-Image 系列模型许可为 Apache-2.0，可商用，无署名要求）
- 可回退：`.workbuddy/backup/placeholders/`（保留 `assets/` 原目录结构）

**本节生效后，下列旧登记条目不再对应实际文件（保留作历史记录）：**

| 旧登记 | 已不再使用的路径 |
|---|---|
| 2.1 Kenney UI Pack | `ui/star_icon.png`、`ui/star_gray.png` |
| 2.2 Kenney Game Icons | `ui/btn_pause.png`、`weapons/icon_greed.png`、`weapons/icon_lightning_shield.png`、`weapons/icon_shadow.png` |
| 2.3 Kenney Particle Pack | `effects/levelup_aura.png`、`effects/xp_collect.png`、`effects/shield_break.png`、`effects/magic_trail.png`、`effects/knife_spin.png`、`effects/btn_click.png`、`effects/achievement_unlock.png`、`weapons/bullet.png`、`weapons/magic_orb.png`、`weapons/knife.png`、`weapons/icon_frozen.png` |

仍来自 Kenney UI Pack 且**未被替换**的：`ui/weapon_slot.png`、`ui/passive_slot.png`、`ui/shop_slot.png`、`ui/star_gold.png`。
