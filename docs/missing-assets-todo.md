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
| DONE | `assets/audio/sfx/sfx_shoot.ogg` | Kenney Impact Sounds | 手枪射击 |
| DONE | `assets/audio/sfx/sfx_hit_enemy.ogg` | Kenney Impact Sounds | 命中反馈 |
| DONE | `assets/audio/sfx/sfx_enemy_death.ogg` | Kenney Impact Sounds | 死亡反馈 |
| DONE | `assets/audio/sfx/sfx_pickup_xp.ogg` | Kenney Interface Sounds | 拾取经验 |
| DONE | `assets/audio/sfx/sfx_levelup.ogg` | Kenney Interface Sounds | 升级提示 |
| DONE | `assets/audio/sfx/sfx_player_hurt.ogg` | Kenney Impact Sounds | 玩家受伤 |
| DONE | `assets/audio/sfx/sfx_click.ogg` | Kenney Interface Sounds | UI 点击 |
| DONE | `assets/audio/sfx/sfx_hover.ogg` | Kenney Interface Sounds | UI 悬停 |
| DONE | `assets/audio/sfx/sfx_shield_break.ogg` | Kenney Impact Sounds | 护盾破碎 |
| DONE | `assets/audio/sfx/sfx_explosion.ogg` | Kenney Impact Sounds | 爆炸 |
| DONE | `assets/audio/sfx/sfx_coin.ogg` | Kenney Interface Sounds | 金币 |
| DONE | `assets/audio/sfx/sfx_teleport.wav` | fins (OpenGameArt, CC0) | 传送 |

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
| TODO | `elite_vampire_idle.png` | `vampire_idle.png` 加金边/红眼 | `vampire_idle.png` |
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
| TODO | `assets/ui/merchant.png` | AI/角色包 | 商人形象 |

---

## 四、P2 TODO：版本包装与后期打磨

### 游戏结束与包装界面

| 状态 | 资源 | 建议方式 |
|---|---|---|
| TODO | `assets/ui/victory_bg.png` | AI 背景/概念图 |
| TODO | `assets/ui/defeat_bg.png` | AI 背景/概念图 |
| DONE | `assets/ui/stats_panel.png` | 程序生成占位 | 已生成 |
| DONE | `assets/ui/achievement_icon.png` | Kenney Game Icons | 已复制缩放 |
| DONE | `assets/ui/star_gold.png` | Kenney UI Pack | 已复制缩放 |
| DONE | `assets/ui/star_gray.png` | Kenney UI Pack | 已复制缩放 |
| TODO | `assets/ui/menu_frame.png` | 哥特 UI 包/AI |
| DONE | `assets/ui/btn_pause.png` | Kenney Game Icons | 已复制缩放 |
| DONE | `assets/ui/selected_mark.png` | Kenney Game Icons | 已复制缩放 |
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
| TODO | `poison_spread.png` | P2 | 毒雾反馈 |
| TODO | `chain_lightning.png` | P2 | 闪电链 |
| TODO | `holy_light.png` | P2 | 进化武器 |
| TODO | `knife_tornado.png` | P2 | 进化武器 |
| TODO | `thunder_wrath.png` | P2 | 进化武器 |
| DONE | `btn_click.png` | P2 | Kenney circle 缩放 |
| DONE | `achievement_unlock.png` | P2 | Kenney star 缩放 |
| TODO | `wave_start.png` | P2 | 波次提示 |
| DONE | `damage_numbers.png` | P1 | 占位，需美术字 |
| TODO | `crit_text.png` | P2 | 暴击反馈 |
| TODO | `boss_warning.png` | P1 | Boss 登场/危险提示 |

---

## 五、BGM TODO

建议新建：`assets/audio/bgm/`

| 状态 | 资源 | 优先级 | 建议来源 |
|---|---|---|---|
| DONE | `bgm_menu.mp3` | P1 | OpenGameArt (matthew.pablo, CC-BY) |
| DONE | `bgm_battle.wav` | P1 | 程序生成占位 |
| TODO | `bgm_battle1.ogg` | P2 | OpenGameArt / Pixabay |
| TODO | `bgm_battle2.ogg` | P2 | OpenGameArt / Pixabay |
| DONE | `bgm_boss.wav` | P1 | 程序生成占位 |
| TODO | `bgm_shop.ogg` | P2 | OpenGameArt / Pixabay |
| TODO | `bgm_victory.ogg` | P2 | OpenGameArt / Pixabay |
| TODO | `bgm_defeat.ogg` | P2 | OpenGameArt / Pixabay |

建议：

- `menu` 已补齐
- 先补 `battle1`、`boss`
- 其余等商店/结算流程稳定后再补

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

- [ ] `elite_vampire_idle.png`
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
