# Vampire Hunter Roguelite 素材缺口清单与获取方案

> 面向当前仓库的可执行补素材文档。目标不是一次性做完全部美术，而是先用最小成本把游戏补到“可完整游玩 + 观感统一 + 后续可迭代”。

---

## 一、当前判断

这个项目的核心代码、场景结构和玩法框架已经具备，问题不在“从零开始没东西”，而在：

1. **已有基础素材，但覆盖不完整**
2. **需求文档很全，但实装资产没有完全跟上**
3. **部分资源已经有第一版，占位足够，但还不够统一**
4. **最缺的是成套补齐方案，而不是继续零散找图**

建议采取：

- **先补可玩性核心素材（P0）**
- **再补视觉识别度核心素材（P1）**
- **最后补打磨型素材（P2）**

---

## 二、补素材总体策略

### 推荐组合

- **现成免费/低价素材包**：补角色、敌人、UI、音效
- **AI 生成**：补 Logo、宣传图、背景图、图标、小量特效
- **代码内占位/复用**：暂时复用动画、颜色变体、缩放变体

### 不建议的做法

- 一开始就手搓全部逐帧角色动画
- 东拼西凑十几套风格差异很大的像素包
- 先做宣传图而不先补可玩核心资源
- 为了“完整美术”拖住玩法迭代

---

## 三、优先级总表

### P0：必须先补，影响实际游玩

这些资源优先级最高，因为会直接影响武器识别、反馈完整性、界面可用性。

#### 1. 武器与道具图标补齐

优先检查并补齐：

- `assets/weapons/icon_pistol.png`
- `assets/weapons/icon_shotgun.png`
- `assets/weapons/icon_poison.png`
- `assets/weapons/icon_shield.png`
- `assets/weapons/xp_gem_large.png`

说明：

- 这些图标是 HUD、升级选择、拾取反馈里的基础识别资产
- 如果缺失，玩家对系统理解会明显变差

#### 2. UI 缺失状态图

建议优先补：

- `btn_pressed.png`
- `hp_bar_bg.png`
- `xp_bar_bg.png`
- `upgrade_card_hover.png`
- `weapon_slot.png`
- `passive_slot.png`

说明：

- 这类素材并不复杂，完全可以先用简单边框 + 渐变 + 描边做占位版
- 对体验提升很大，制作成本反而低

#### 3. 基础音效

优先需要：

- 玩家射击
- 命中反馈
- 敌人死亡
- 玩家受伤
- 升级弹窗
- 拾取经验/道具
- Boss 攻击

说明：

- 音频是低成本高收益项
- 你的 README 已经把音频系统写进卖点了，所以最好尽快补齐基础包

---

### P1：强烈建议补，影响项目质感

#### 1. 高级敌人与专属动作

需求文档里已经列出，但当前应仍未完整覆盖：

- `exploder_walk.png`
- `exploder_explode.png`
- `elite_vampire_idle.png`
- `summoner_cast.png`
- `mage_teleport.png`
- `mage_cast.png`
- `gargoyle_idle.png`
- `gargoyle_petrify.png`
- `gargoyle_wake.png`
- `prince_idle.png`
- `prince_dash.png`
- `prince_rage.png`
- `boss_attack3.png`
- `boss_death.png`

建议：

- 第一阶段可先用颜色变体、缩放变体、已有动作替代
- 第二阶段再补成真正独立立绘/动画

#### 2. 房间与地图资源

优先顺序：

- `room_square.png`
- 基础 tileset（地板、墙、墙角）
- 柱子/障碍物
- 火炬/窗户/棺材/书架/蜘蛛网/血迹

说明：

- 如果场景变化不够，房间随机性会显得“逻辑随机，视觉不随机”
- 这部分很适合用现成像素 dungeon/castle 包

#### 3. 进阶 HUD / 面板资源

建议补：

- `boss_hp_bg.png`
- `boss_hp_fill.png`
- `wave_number_bg.png`
- `shop_slot.png`
- `price_tag.png`
- `stats_panel.png`

---

### P2：打磨项，适合后续版本

- 主菜单高级边框与装饰
- 商人 NPC 立绘
- 胜利/失败背景
- 成就图标
- 进化发光与高级粒子特效
- 宣传海报、商店页封面、截图包装

---

## 四、素材获取方案

### 方案 A：免费素材站先补齐

这是最适合当前阶段的主路线。

#### 1. Kenney

适合：

- UI 元素
- 图标
- 通用音效
- 占位道具资源

优点：

- 质量稳定
- 授权友好
- 上手快
- 很适合先做占位版与系统验证

建议用途：

- 按钮
- 面板
- 图标槽位
- 经验与拾取类图标占位
- 基础 SFX

#### 2. OpenGameArt

适合：

- 像素角色
- 敌人
- 地牢贴图
- BGM 与 SFX

优点：

- 免费资源很多
- 可找到哥特、地牢、亡灵题材

风险：

- 风格非常杂
- 一定要筛选成套资源，别乱拼

建议用途：

- 僵尸、骷髅、蝙蝠、地牢 tileset
- 血迹、火炬、魔法特效

#### 3. itch.io

适合：

- 成套像素包
- 暗黑/哥特 UI
- 地牢场景包
- Boss/怪物包

优点：

- 成套感通常比 OpenGameArt 更好
- 很适合找到统一风格包

建议检索关键词：

- `pixel gothic ui`
- `pixel dungeon tileset`
- `vampire pixel enemy`
- `roguelite asset pack`
- `dark fantasy pixel art`

#### 4. CraftPix / GameDev Market

适合：

- 相对完整的商用品质包
- UI、角色、敌人整套补货

优点：

- 节省时间
- 统一度通常更高

风险：

- 有些资源偏手游风或横版风，和你的俯视角不一定完全匹配

---

### 方案 B：AI 生成补缺口

AI 更适合做这些：

#### 1. 很适合 AI 生成的内容

- 游戏 Logo
- 主菜单背景
- 房间背景图
- 商店背景图
- 结算界面背景
- 被动道具图标
- 武器图标
- 宣传图

#### 2. 不适合一开始全靠 AI 的内容

- 全套逐帧角色动画
- 高精度统一透视 tileset
- 要严格碰撞和帧数对齐的战斗精灵

#### 3. 推荐 AI 使用方式

- 先生成大图或概念图
- 再裁切/像素化/手工修边
- 或只把 AI 图用在 UI、封面、背景层

---

### 方案 C：代码复用与占位顶上

在你正式补齐资源前，可以允许这些替代策略：

- `vampire_idle` 改色后暂代 `elite_vampire_idle`
- `boss_attack2` 暂代 `boss_attack3`
- `upgrade_card` 改色高亮后暂代 `upgrade_card_hover`
- `btn_hover` 压暗后暂代 `btn_pressed`
- `xp_gem_medium` 放大后暂代 `xp_gem_large`
- `werewolf_idle` 与 `werewolf_charge` 先共用部分帧

这样做的目的是：

- 优先让玩法完整
- 避免卡死在缺一两张图就没法继续开发

---

## 五、最小可执行补货清单


---

# Vampire Hunter Roguelite 缺失素材 TODO

> 本文档基于当前仓库 `assets/` 实际文件与 `docs/art-assets-requirements.md` 对照整理。用途是把“需要哪些素材”拆成可执行 TODO，方便后续下载、AI 生成、外包或手工制作。

---

## 一、当前已有素材概览

### 1. 玩家

当前已有：

- `assets/sprites/player/player_idle.png`
- `assets/sprites/player/player_run.png`
- `assets/sprites/player/player_attack.png`
- `assets/sprites/player/player_hurt.png`
- `assets/sprites/player/player_death.png`
- `assets/sprites/player/player_shield.png`

状态：

- 玩家基础动画已覆盖
- 后续重点不是“补数量”，而是检查帧数、风格统一、动作手感和终版质量

---

### 2. 基础敌人

当前已有：

- `assets/sprites/enemies/vampire_idle.png`
- `assets/sprites/enemies/vampire_run.png`
- `assets/sprites/enemies/werewolf_idle.png`
- `assets/sprites/enemies/werewolf_charge.png`
- `assets/sprites/enemies/bat_fly.png`
- `assets/sprites/enemies/zombie_walk.png`
- `assets/sprites/enemies/skeleton_idle.png`
- `assets/sprites/enemies/skeleton_shoot.png`

状态：

- 基础敌人主循环素材已覆盖
- 自爆者和高级敌人缺失较多

---

### 3. Boss

当前已有：

- `assets/sprites/boss/boss_idle.png`
- `assets/sprites/boss/boss_attack1.png`
- `assets/sprites/boss/boss_attack2.png`
- `assets/sprites/boss/boss_attack3.png`（占位：复制自 `boss_idle.png`）
- `assets/sprites/boss/boss_enraged.png`
- `assets/sprites/boss/boss_death.png`（占位：复制自 `boss_idle.png`）

状态：

- Boss 基础动作已补齐
- `boss_attack3.png` 和 `boss_death.png` 为临时占位，建议后续替换为正式冲刺/死亡动画

---

### 4. 背景

当前已有：

- `assets/backgrounds/menu_bg.png`
- `assets/backgrounds/room_standard.png`
- `assets/backgrounds/room_hall.png`
- `assets/backgrounds/room_boss.png`
- `assets/backgrounds/room_portal.png`
- `assets/backgrounds/room_square.png`（占位：纯色填充）

状态：

- 5 张主要房间背景 + 1 张占位
- 程序化房间更需要 tileset 和装饰物，而不仅是更多静态背景

---

### 5. UI

当前已有：

- `assets/ui/btn_normal.png`
- `assets/ui/btn_hover.png`
- `assets/ui/btn_pressed.png`（由 `btn_hover.png` 压暗生成）
- `assets/ui/game_logo.png`
- `assets/ui/hp_bar_border.png`
- `assets/ui/hp_bar_fill.png`
- `assets/ui/hp_bar_bg.png`
- `assets/ui/xp_bar_fill.png`
- `assets/ui/xp_bar_bg.png`
- `assets/ui/upgrade_card.png`
- `assets/ui/upgrade_card_hover.png`（由 `upgrade_card.png` 加金边生成）
- `assets/ui/weapon_slot.png`
- `assets/ui/passive_slot.png`
- `assets/ui/boss_hp_bg.png` / `assets/ui/boss_hp_fill.png`
- `assets/ui/shop_slot.png` / `assets/ui/price_tag.png` / `assets/ui/sold_out.png`
- `assets/ui/wave_number_bg.png`
- `assets/ui/btn_pause.png` / `assets/ui/selected_mark.png`
- `assets/ui/star_icon.png` / `assets/ui/star_gold.png` / `assets/ui/star_gray.png`
- `assets/ui/achievement_icon.png` / `assets/ui/stats_panel.png`
- `assets/ui/evolution_glow.png`（占位）

仍缺失：

- 商店商人形象 `merchant.png`
- 结算界面背景 `victory_bg.png` / `defeat_bg.png`
- 主菜单装饰边框 `menu_frame.png`
- 部分 UI 特效素材（已在 `assets/effects/` 中补充占位）

---

### 6. 武器与道具

当前已有：

- `assets/weapons/icon_pistol.png`
- `assets/weapons/icon_shotgun.png`
- `assets/weapons/icon_magic_book.png`
- `assets/weapons/icon_knife.png`
- `assets/weapons/icon_poison.png`
- `assets/weapons/icon_lightning.png`
- `assets/weapons/icon_magnet.png`
- `assets/weapons/icon_shield.png`
- `assets/weapons/heal_potion.png`
- `assets/weapons/xp_gem_large.png`
- `assets/weapons/xp_gem_medium.png`
- `assets/weapons/xp_gem_small.png`
- `assets/weapons/blood_crystal.png`
- `assets/weapons/portal.png`
- `assets/weapons/icon_regen.png` / `icon_greed.png` / `icon_berserker.png`
- `assets/weapons/icon_frozen.png`（占位） / `icon_lightning_shield.png` / `icon_shadow.png`（占位）
- `assets/weapons/bullet.png` / `magic_orb.png` / `knife.png`

仍缺失：

- `shotgun_pellet.png`
- 部分被动道具图标的主题化精修版本
- 毒雾 `poison_cloud.png`

---

### 7. 特效

当前已有：

- `assets/effects/hit_effect.png`
- `assets/effects/death_explosion.png`
- `assets/effects/levelup_aura.png`
- `assets/effects/xp_collect.png`
- `assets/effects/shield_break.png`
- `assets/effects/bullet_trail.png` / `magic_trail.png` / `knife_spin.png`
 - `assets/effects/freeze_effect.png`（冰蓝火焰占位） / `lightning_retaliate.png`（占位） / `petrify_effect.png`（占位）
- `assets/effects/dodge_afterimage.png`（占位） / `lifesteal.png`（占位）
- `assets/effects/btn_click.png` / `achievement_unlock.png`
- `assets/effects/damage_numbers.png`（占位）

仍缺失：

- `dodge_afterimage.png` / `lifesteal.png`
- `poison_spread.png` / `chain_lightning.png`
- `holy_light.png` / `knife_tornado.png` / `thunder_wrath.png`
- `wave_start.png` / `crit_text.png` / `boss_warning.png`

状态：

- 命中、死亡、升级、拾取、护盾破裂等核心反馈已补齐占位
- 高级特效和 UI 特效可以延后

---

### 8. 地图瓦片、音频、字体

当前已有：

- `assets/tiles/tile_floor.png` 等基础瓦片（从 Kenney Roguelike RPG Pack 切片放大）
- `assets/tiles/props/` 下装饰物占位（torch/window/coffin/bookshelf/cobweb/blood_splatter）
- `assets/audio/sfx/` 下 12 个基础音效（Kenney + fins）
- `assets/audio/bgm/bgm_menu.mp3`（Beyond Redemption，CC-BY）

仍缺失：

- `assets/fonts/` 目录（下载的字体 zip 文件损坏，需重新下载）
- BGM：`bgm_battle1.ogg`、`bgm_boss.ogg`、`bgm_battle2.ogg`、`bgm_shop.ogg`、`bgm_victory.ogg`、`bgm_defeat.ogg`
- 瓦片/装饰物多为占位或程序生成，需美术精修

状态：

- 音频基础包已补齐，体验提升明显
- 字体需重新下载；Google Fonts 下载脚本可能未正确保存为 zip

---

## 二、P0 TODO：优先补齐，影响可玩完整度

### UI 基础交互

| 状态 | 资源 | 建议方式 | 备注 |
|---|---|---|---|
| DONE | `assets/ui/btn_pressed.png` | 由 `btn_hover.png` 压暗/加内阴影 | 程序生成 |
| DONE | `assets/ui/hp_bar_bg.png` | 手工制作/从 UI 包裁切 | 黑底占位 |
| DONE | `assets/ui/xp_bar_bg.png` | 手工制作/从 UI 包裁切 | 黑底占位 |
| DONE | `assets/ui/upgrade_card_hover.png` | `upgrade_card.png` 加金边高亮 | 程序生成 |
| DONE | `assets/ui/weapon_slot.png` | Kenney/UI 包 | 已复制缩放 |
| DONE | `assets/ui/passive_slot.png` | Kenney/UI 包 | 已复制缩放 |

### Boss 核心动作

| 状态 | 资源 | 建议方式 | 备注 |
|---|---|---|---|
| DONE | `assets/sprites/boss/boss_attack3.png` | 复用 `boss_idle.png` 占位 | 冲刺攻击用，后续替换 |
| DONE | `assets/sprites/boss/boss_death.png` | 复用 `boss_idle.png` 占位 | Boss 结算反馈，后续替换 |

### 基础音效

建议先新建：`assets/audio/sfx/`

| 状态 | 资源 | 建议来源 | 备注 |
|---|---|---|---|
| DONE | `assets/audio/sfx/sfx_shoot.ogg` | Kenney Sci-Fi Sounds | 手枪射击 |
| DONE | `assets/audio/sfx/sfx_shoot_shotgun.ogg` | Kenney Sci-Fi Sounds | 霰弹枪射击 |
| DONE | `assets/audio/sfx/sfx_shoot_magic.ogg` | Kenney Sci-Fi Sounds | 魔法书射击 |
| DONE | `assets/audio/sfx/sfx_knife_throw.ogg` | Kenney RPG Audio | 飞刀射击 |
| DONE | `assets/audio/sfx/sfx_poison_cloud.ogg` | Kenney Sci-Fi Sounds | 毒雾瓶 |
| DONE | `assets/audio/sfx/sfx_lightning_chain.ogg` | Kenney Sci-Fi Sounds | 闪电链 |
| DONE | `assets/audio/sfx/sfx_boss_attack.ogg` | Kenney Sci-Fi Sounds | Boss/精英攻击 |
| DONE | `assets/audio/sfx/sfx_hit_enemy.ogg` | Kenney Impact Sounds | 命中反馈 |
| DONE | `assets/audio/sfx/sfx_enemy_death.ogg` | Kenney Impact Sounds | 死亡反馈 |
| DONE | `assets/audio/sfx/sfx_pickup_xp.ogg` | Kenney Interface Sounds | 拾取经验 |
| DONE | `assets/audio/sfx/sfx_levelup.ogg` | Kenney Interface Sounds | 升级提示 |
| DONE | `assets/audio/sfx/sfx_player_hurt.ogg` | Kenney Impact Sounds | 玩家受伤（已接入） |
| DONE | `assets/audio/sfx/sfx_click.ogg` | Kenney Interface Sounds | UI 点击 |
| DONE | `assets/audio/sfx/sfx_hover.ogg` | Kenney Interface Sounds | UI 悬停（已接入） |
| DONE | `assets/audio/sfx/sfx_shield_break.ogg` | Kenney Impact Sounds | 护盾破碎 |
| DONE | `assets/audio/sfx/sfx_explosion.ogg` | Kenney Sci-Fi Sounds | 爆炸 |
| DONE | `assets/audio/sfx/sfx_coin.ogg` | Kenney Interface Sounds | 金币/治疗 |
| DONE | `assets/audio/sfx/sfx_teleport.wav` | fins (OpenGameArt, CC0) | 传送（已接入法师/传送门） |

### 拾取与货币

| 状态 | 资源 | 建议方式 | 备注 |
|---|---|---|---|
| DONE | `assets/weapons/xp_gem_small.png` | 从 `xp_gem_large.png` 缩放 | 已生成 |
| DONE | `assets/weapons/xp_gem_medium.png` | 从 `xp_gem_large.png` 缩放 | 已生成 |
| DONE | `assets/weapons/blood_crystal.png` | RPG Inventory Icons | 已复制缩放 |
| DONE | `assets/weapons/portal.png` | teleporter 特效 | 已复制缩放 |

---

## 三、P1 TODO：建议尽快补，提升质感

### 高级敌人

建议新建或继续使用：`assets/sprites/enemies/`

| 状态 | 资源 | 建议方式 | 可临时替代 |
|---|---|---|---|
| DONE | `exploder_walk.png` | 从 `zombie_walk.png` 缩放占位 | 已生成 |
| TODO | `exploder_explode.png` | 爆炸特效包/手工帧 | `death_explosion.png` 放大 |
| DONE | `elite_vampire_idle.png` | `vampire_idle.png` 加金边/红眼 | 已生成辉光变体 |
| DONE | `summoner_cast.png` | NecroGuy GIF 提取 | 已生成 |
| TODO | `mage_teleport.png` | 紫色消散特效 + 法师帧 | `vampire_run.png` 加透明残影 |
| DONE | `mage_cast.png` | 法师怪物包 | 已复制缩放 |
| DONE | `gargoyle_idle.png` | 石像鬼像素包 | 已复制缩放 |
| TODO | `gargoyle_petrify.png` | `gargoyle_idle` 灰度变化 | 无 |
| TODO | `gargoyle_wake.png` | 反向石化动画 | 无 |
| DONE | `prince_idle.png` | 吸血鬼贵族素材 | 已复制缩放 |
| TODO | `prince_dash.png` | `prince_idle` 残影帧 | `vampire_run.png` 放大改色 |
| TODO | `prince_rage.png` | 红色 aura 叠加 | `boss_enraged.png` 缩小参考 |

### 地图瓦片

建议新建：`assets/tiles/`

| 状态 | 资源 | 建议来源 | 备注 |
|---|---|---|---|
| DONE | `assets/tiles/tile_floor.png` | Kenney Roguelike RPG Pack | 已切片放大至 32x32 |
| DONE | `assets/tiles/tile_floor_var1.png` | Kenney Roguelike RPG Pack | 已切片放大至 32x32 |
| DONE | `assets/tiles/tile_floor_var2.png` | Kenney Roguelike RPG Pack | 已切片放大至 32x32 |
| DONE | `assets/tiles/tile_wall.png` | Kenney Roguelike RPG Pack | 已切片放大至 32x32 |
| DONE | `assets/tiles/tile_wall_corner.png` | Kenney Roguelike RPG Pack | 已切片放大至 32x32 |
| DONE | `assets/tiles/tile_pillar.png` | Kenney Roguelike RPG Pack | 已切片放大至 64x64 |
| DONE | `assets/tiles/tile_obstacle.png` | Kenney Roguelike RPG Pack | 已切片放大至 64x64 |

### 环境装饰

建议新建：`assets/props/` 或放入 `assets/tiles/props/`

| 状态 | 资源 | 建议来源 | 备注 |
|---|---|---|---|
| DONE | `torch.png` | 程序生成占位 | 已生成 |
| DONE | `window.png` | 程序生成占位 | 已生成 |
| DONE | `coffin.png` | 程序生成占位 | 已生成 |
| DONE | `bookshelf.png` | 程序生成占位 | 已生成 |
| DONE | `cobweb.png` | 程序生成占位 | 已生成 |
| DONE | `blood_splatter.png` | 程序生成占位 | 已生成 |

### HUD 与商店 UI

| 状态 | 资源 | 建议方式 | 备注 |
|---|---|---|---|
| DONE | `assets/ui/boss_hp_bg.png` | 程序生成 | 已生成 |
| DONE | `assets/ui/boss_hp_fill.png` | 程序生成 | 已生成 |
| DONE | `assets/ui/wave_number_bg.png` | 程序生成 | 已生成 |
| DONE | `assets/ui/shop_slot.png` | Kenney UI Pack | 已复制缩放 |
| DONE | `assets/ui/price_tag.png` | 程序生成 | 已生成 |
| DONE | `assets/ui/sold_out.png` | 程序生成 | 已生成 |
| DONE | `assets/ui/merchant.png` | FreeGameSprites spice-merchant | 已裁切缩放 |

---

## 四、P2 TODO：版本包装与后期打磨

### 游戏结束与包装界面

| 状态 | 资源 | 建议方式 |
|---|---|---|
| DONE | `assets/ui/victory_bg.png` | 程序生成暗金背景，已接入胜利结算 |
| DONE | `assets/ui/defeat_bg.png` | 程序生成暗红背景，已接入失败结算 |
| DONE | `assets/ui/stats_panel.png` | 程序生成面板，已用于设置/商店/升级弹窗 |
| DONE | `assets/ui/achievement_icon.png` | Kenney Game Icons | 已复制缩放 |
| DONE | `assets/ui/star_gold.png` | Kenney UI Pack | 已复制缩放 |
| DONE | `assets/ui/star_gray.png` | Kenney UI Pack | 已复制缩放 |
| DONE | `assets/ui/menu_frame.png` | 程序生成哥特边框 |
| DONE | `assets/ui/btn_pause.png` | Kenney Game Icons 调色 | 已复制缩放 |
| DONE | `assets/ui/selected_mark.png` | Kenney Game Icons 调色 | 已复制缩放 |
| DONE | `assets/ui/star_icon.png` | Kenney UI Pack | 已复制缩放 |
| DONE | `assets/ui/evolution_glow.png` | 程序生成占位 | 已生成 |

### 被动道具图标

建议继续放入：`assets/weapons/`

| 状态 | 资源 | 建议方式 | 备注 |
|---|---|---|---|
| DONE | `icon_regen.png` | RPG Inventory Icons | 已复制缩放 |
| DONE | `icon_greed.png` | Kenney Game Icons | 已复制缩放 |
| DONE | `icon_berserker.png` | RPG Inventory Icons | 已复制缩放 |
| DONE | `icon_frozen.png` | Kenney Particle Pack（占位） | 火焰图标临时占位 |
| DONE | `icon_lightning_shield.png` | Kenney Game Icons | 已复制缩放 |
| DONE | `icon_shadow.png` | Kenney Game Icons（占位） | exitRight 图标临时占位 |

### 战斗与粒子特效

建议继续放入：`assets/effects/`

| 状态 | 资源 | 优先级 | 备注 |
|---|---|---|---|
| DONE | `levelup_aura.png` | P1 | Kenney star 组合 |
| DONE | `xp_collect.png` | P1 | Kenney light 缩放 |
| DONE | `shield_break.png` | P1 | Kenney slash 缩放 |
| DONE | `freeze_effect.png` | P2 | 火焰图标临时占位 |
| DONE | `lightning_retaliate.png` | P2 | Kenney spark 临时占位 |
| DONE | `dodge_afterimage.png` | P2 | 灰色 slash 占位 |
| DONE | `lifesteal.png` | P2 | 血迹 smoke 占位 |
| DONE | `petrify_effect.png` | P2 | Kenney scorch 临时占位 |
| DONE | `bullet_trail.png` | P1 | 程序生成 |
| DONE | `magic_trail.png` | P2 | Kenney magic 缩放 |
| DONE | `knife_spin.png` | P2 | Kenney slash 缩放 |
| DONE | `poison_spread.png` | P2 | 程序生成占位 |
| DONE | `chain_lightning.png` | P2 | 程序生成占位 |
| DONE | `holy_light.png` | P2 | 程序生成占位 |
| DONE | `knife_tornado.png` | P2 | 程序生成占位 |
| DONE | `thunder_wrath.png` | P2 | 程序生成占位 |
| DONE | `btn_click.png` | P2 | Kenney circle 缩放 |
| DONE | `achievement_unlock.png` | P2 | Kenney star 缩放 |
| DONE | `wave_start.png` | P2 | 程序生成占位 |
| DONE | `damage_numbers.png` | P1 | 占位，需美术字 |
| DONE | `crit_text.png` | P2 | 程序生成占位 |
| DONE | `boss_warning.png` | P1 | 程序生成占位 |

---

## 五、BGM TODO

建议新建：`assets/audio/bgm/`

| 状态 | 资源 | 优先级 | 建议来源 |
|---|---|---|---|
| DONE | `bgm_menu.mp3` | P1 | OpenGameArt (matthew.pablo, CC-BY) |
| DONE | `bgm_battle.wav` | P1 | 程序生成占位 |
| DONE | `bgm_battle.mp3` | P1 | OpenGameArt (CC0) |
| TODO | `bgm_battle2.ogg` | P2 | OpenGameArt / Pixabay |
| DONE | `bgm_boss.ogg` | P1 | OpenGameArt (CC0) |
| DONE | `bgm_shop.ogg` | P2 | OpenGameArt (yd, CC0) |
| DONE | `bgm_victory.ogg` | P2 | OpenGameArt (yd, CC0) |
| DONE | `bgm_defeat.ogg` | P2 | OpenGameArt (SeKa, CC0) |

建议：

- `menu`、`battle`、`boss` 已补齐
- `shop`、`victory`、`defeat` 已补齐并接入对应流程
- `battle2` 可留作后续房间变体

---

## 六、字体 TODO

建议新建：`assets/fonts/`

| 状态 | 资源 | 优先级 | 备注 |
|---|---|---|---|
| DONE | `NotoSansCJKsc-Regular.otf` | P1 | 主界面/HUD/伤害数字（思源黑体，OFL） |
| TODO | `title_font.ttf` | P2 | 哥特标题，可不支持中文 |
| TODO | `number_font.ttf` | P2 | 专用数字字体 |

状态：

- 下载的字体 zip 文件损坏（均为 HTML 页面），需重新下载
- 建议从 Google Fonts 手动下载 TTF 文件，或检查 `assets-downloaded/download_script.py`

建议：

- 若游戏界面含中文，`main_font.ttf` 优先使用支持中文的开源字体
- 标题字体可以独立使用英文字体或艺术字图片

---

## 七、已新建目录

本次整理已新增以下目录：

```text
assets/audio/
assets/audio/bgm/
assets/audio/sfx/
assets/fonts/        # 待放入字体文件
assets/tiles/
assets/tiles/props/
```

说明：

- `audio/bgm` 与 `audio/sfx` 分开，方便 AudioManager 管理
- `tiles/props` 用于地图装饰物
- 如果后续 Godot 导入，记得提交对应 `.import` 文件

---

## 八、本次整理完成情况（2026-06-15）

本次从 `assets-downloaded/` 批量整理后，以下素材已补齐或生成占位：

- UI 基础交互：btn_pressed、bar backgrounds、upgrade_card_hover、weapon_slot、passive_slot 等
- 音效：12 个基础 SFX + 1 个主菜单 BGM
- 武器/道具：xp_gem 全尺寸、blood_crystal、portal、6 个被动道具图标占位
- 特效：levelup_aura、xp_collect、shield_break、bullet_trail 等核心反馈
- 瓦片：7 个基础 tile + 6 个装饰物占位
- 敌人/Boss：summoner、mage、gargoyle、prince、exploder、boss_attack3/death 占位

未完成的缺口：

- 字体（下载失败，需重新获取）
- BGM：battle1/boss/shop/victory/defeat
- 高级敌人完整动作：exploder_explode、mage_teleport、gargoyle_petrify/wake、prince_dash/rage 等
- 商店商人形象、胜利/失败背景、菜单边框
- 伤害数字精灵表、毒雾/闪电链/进化武器特效
- 大量装饰物和 UI 特效的精修版本

---

## 九、短期冲刺清单

如果只做一轮短期补齐，建议按以下顺序：

### 第 1 天：UI 基础

- [x] `btn_pressed.png`
- [x] `hp_bar_bg.png`
- [x] `xp_bar_bg.png`
- [x] `upgrade_card_hover.png`
- [x] `weapon_slot.png`
- [x] `passive_slot.png`

### 第 2 天：音效基础

- [x] `sfx_shoot.ogg`
- [x] `sfx_hit_enemy.ogg`
- [x] `sfx_enemy_death.ogg`
- [x] `sfx_pickup_xp.ogg`
- [x] `sfx_levelup.ogg`
- [x] `sfx_click.ogg`

### 第 3 天：Boss 与拾取

- [x] `boss_attack3.png`（占位）
- [x] `boss_death.png`（占位）
- [x] `xp_gem_small.png`
- [x] `xp_gem_medium.png`
- [x] `blood_crystal.png`
- [x] `portal.png`

### 第 4-5 天：地图基础

- [x] `tile_floor.png`
- [x] `tile_wall.png`
- [x] `tile_wall_corner.png`
- [x] `tile_floor_var1.png`
- [x] `tile_floor_var2.png`
- [x] `torch.png`（占位）
- [x] `coffin.png`（占位）
- [x] `blood_splatter.png`（占位）

### 第 6-7 天：高级敌人占位

- [x] `elite_vampire_idle.png`
- [x] `exploder_walk.png`（占位）
- [ ] `exploder_explode.png`
- [x] `summoner_cast.png`
- [x] `mage_cast.png`
- [x] `prince_idle.png`（占位）

---

## 十、执行备注

1. 下载素材后先放入对应目录，不要直接覆盖已有终版素材。
2. 新来源必须登记到 `docs/asset-licenses.md`。
3. 若尺寸不同，优先用导入设置或统一脚本适配，不要随意拉伸变形。
4. Godot 导入后记得确认 `.import` 文件已生成并纳入版本管理。
5. 所有临时占位素材建议在文件名或授权文档里标注 `placeholder`，方便后续替换。
