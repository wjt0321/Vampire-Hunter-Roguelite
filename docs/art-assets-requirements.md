# 吸血鬼猎人游戏 - 美术资源需求清单

> 本文档详细列出游戏所需的所有美术资源，包括角色、敌人、UI、特效等

---

## 📁 目录结构

```
assets/
├── sprites/          # 精灵图（角色、敌人、道具）
├── backgrounds/      # 背景图
├── ui/              # UI元素
├── effects/         # 特效
├── tiles/           # 地图瓦片
├── audio/           # 音效和音乐
└── fonts/           # 字体
```

---

## 🎮 一、角色精灵图 (Sprites)

### 1.1 玩家角色 (Player)

| 资源名称 | 尺寸建议 | 动画帧数 | 描述 |
|---------|---------|---------|------|
| `player_idle.png` | 32x32 | 4帧 | 待机动画（呼吸/浮动） |
| `player_run.png` | 32x32 | 6帧 | 跑步动画 |
| `player_attack.png` | 32x32 | 4帧 | 攻击动画 |
| `player_hurt.png` | 32x32 | 2帧 | 受伤动画 |
| `player_death.png` | 32x32 | 6帧 | 死亡动画 |
| `player_shield.png` | 32x32 | 4帧 | 护盾效果（环绕） |

**风格要求**：像素风，吸血鬼猎人主题，披风、帽子、十字架元素

---

### 1.2 敌人精灵图 (Enemies)

#### 基础敌人

| 敌人 | 资源名称 | 尺寸 | 动画 | 描述 |
|-----|---------|------|------|------|
| 吸血鬼 | `vampire_idle.png` | 32x32 | 4帧待机 | 经典吸血鬼，披风，尖牙 |
| 吸血鬼 | `vampire_run.png` | 32x32 | 6帧跑步 | 快速移动姿态 |
| 狼人 | `werewolf_idle.png` | 40x40 | 4帧待机 | 半人半狼，毛发蓬松 |
| 狼人 | `werewolf_charge.png` | 40x40 | 6帧冲锋 | 四足奔跑姿态 |
| 蝙蝠 | `bat_fly.png` | 24x24 | 4帧飞行 | 翅膀扇动动画 |
| 僵尸 | `zombie_walk.png` | 36x36 | 6帧行走 | 缓慢拖行姿态 |
| 骷髅射手 | `skeleton_idle.png` | 32x32 | 4帧待机 | 持弓骷髅 |
| 骷髅射手 | `skeleton_shoot.png` | 32x32 | 4帧射击 | 拉弓射箭动作 |
| 自爆者 | `exploder_walk.png` | 28x28 | 4帧行走 | 肿胀怪物，闪烁红光 |
| 自爆者 | `exploder_explode.png` | 28x28 | 6帧爆炸 | 膨胀到爆炸的过渡 |

#### 高级敌人

| 敌人 | 资源名称 | 尺寸 | 动画 | 描述 |
|-----|---------|------|------|------|
| 精英吸血鬼 | `elite_vampire_idle.png` | 36x36 | 4帧 | 发光效果，金色边框 |
| 召唤师 | `summoner_cast.png` | 32x32 | 6帧施法 | 法杖，召唤手势 |
| 吸血鬼法师 | `mage_teleport.png` | 32x32 | 8帧瞬移 | 消失→出现动画 |
| 吸血鬼法师 | `mage_cast.png` | 32x32 | 4帧施法 | 发射魔法弹 |
| 石像鬼 | `gargoyle_idle.png` | 48x48 | 2帧待机 | 石质纹理，翅膀 |
| 石像鬼 | `gargoyle_petrify.png` | 48x48 | 6帧石化 | 变灰石化过程 |
| 石像鬼 | `gargoyle_wake.png` | 48x48 | 6帧苏醒 | 恢复颜色动画 |
| 血族亲王 | `prince_idle.png` | 40x40 | 4帧待机 | 华丽披风，皇冠 |
| 血族亲王 | `prince_dash.png` | 40x40 | 4帧冲锋 | 高速移动残影 |
| 血族亲王 | `prince_rage.png` | 40x40 | 4帧狂暴 | 红色眼睛，气场 |

#### Boss

| Boss | 资源名称 | 尺寸 | 动画 | 描述 |
|-----|---------|------|------|------|
| 吸血鬼领主 | `boss_idle.png` | 64x64 | 6帧待机 | 巨大体型，王座姿态 |
| 吸血鬼领主 | `boss_attack1.png` | 64x64 | 8帧弹幕攻击 | 发射多个魔法弹 |
| 吸血鬼领主 | `boss_attack2.png` | 64x64 | 6帧召唤 | 召唤小怪手势 |
| 吸血鬼领主 | `boss_attack3.png` | 64x64 | 8帧冲刺 | 快速冲撞 |
| 吸血鬼领主 | `boss_enraged.png` | 64x64 | 6帧狂暴 | 红色 aura，眼睛发光 |
| 吸血鬼领主 | `boss_death.png` | 64x64 | 10帧死亡 | 化为灰烬动画 |

---

## 🗡️ 二、武器与道具 (Weapons & Items)

### 2.1 武器图标

| 武器 | 资源名称 | 尺寸 | 描述 |
|-----|---------|------|------|
| 手枪 | `icon_pistol.png` | 32x32 | 基础武器 |
| 散弹枪 | `icon_shotgun.png` | 32x32 | 扇形射击 |
| 魔法书 | `icon_magic_book.png` | 32x32 | 追踪法术 |
| 飞刀 | `icon_knife.png` | 32x32 | 穿透武器 |
| 毒雾瓶 | `icon_poison.png` | 32x32 | 绿色毒气瓶 |
| 闪电法杖 | `icon_lightning.png` | 32x32 | 闪电链武器 |

### 2.2 武器特效

| 特效 | 资源名称 | 尺寸 | 帧数 | 描述 |
|-----|---------|------|------|------|
| 子弹 | `bullet.png` | 8x8 | 1帧 | 黄色光点 |
| 散弹 | `shotgun_pellet.png` | 6x6 | 1帧 | 多个小弹丸 |
| 魔法弹 | `magic_orb.png` | 16x16 | 4帧 | 旋转魔法球 |
| 飞刀 | `knife.png` | 12x6 | 1帧 | 银色小刀 |
| 毒雾 | `poison_cloud.png` | 64x64 | 8帧 | 绿色毒雾扩散 |
| 闪电 | `lightning_bolt.png` | 32x64 | 4帧 | 闪电链效果 |
| 闪电链 | `lightning_chain.png` | 64x64 | 6帧 | 连接敌人的闪电 |

### 2.3 被动道具图标

| 道具 | 资源名称 | 尺寸 | 描述 |
|-----|---------|------|------|
| 经验磁铁 | `icon_magnet.png` | 32x32 | 磁铁形状 |
| 能量护盾 | `icon_shield.png` | 32x32 | 蓝色护盾 |
| 生命恢复 | `icon_regen.png` | 32x32 | 绿色心形 |
| 贪婪戒指 | `icon_greed.png` | 32x32 | 金色戒指 |
| 狂战士之血 | `icon_berserker.png` | 32x32 | 红色血滴 |
| 冰冻之心 | `icon_frozen.png` | 32x32 | 蓝色冰晶 |
| 闪电护符 | `icon_lightning_shield.png` | 32x32 | 闪电徽章 |
| 影子披风 | `icon_shadow.png` | 32x32 | 黑色斗篷 |

### 2.4 其他道具

| 道具 | 资源名称 | 尺寸 | 描述 |
|-----|---------|------|------|
| 经验宝石 | `xp_gem_small.png` | 8x8 | 小经验 |
| 经验宝石 | `xp_gem_medium.png` | 12x12 | 中经验 |
| 经验宝石 | `xp_gem_large.png` | 16x16 | 大经验 |
| 血晶 | `blood_crystal.png` | 24x24 | 红色水晶 |
| 传送门 | `portal.png` | 48x48 | 紫色漩涡 |
| 治疗药水 | `heal_potion.png` | 24x24 | 红色药水 |

---

## 🎨 三、UI元素 (User Interface)

### 3.1 主菜单

| 元素 | 资源名称 | 尺寸 | 描述 |
|-----|---------|------|------|
| 背景 | `menu_bg.png` | 1920x1080 | 哥特式城堡背景 |
| Logo | `game_logo.png` | 800x200 | 游戏标题艺术字 |
| 按钮背景 | `btn_normal.png` | 200x60 | 正常状态 |
| 按钮背景 | `btn_hover.png` | 200x60 | 悬停状态 |
| 按钮背景 | `btn_pressed.png` | 200x60 | 按下状态 |
| 装饰边框 | `menu_frame.png` | 400x500 | 哥特式花纹边框 |

### 3.2 游戏内HUD

| 元素 | 资源名称 | 尺寸 | 描述 |
|-----|---------|------|------|
| 血条背景 | `hp_bar_bg.png` | 200x24 | 黑色背景 |
| 血条填充 | `hp_bar_fill.png` | 196x20 | 红色渐变 |
| 血条边框 | `hp_bar_border.png` | 200x24 | 金色边框 |
| 经验条背景 | `xp_bar_bg.png` | 300x12 | 黑色背景 |
| 经验条填充 | `xp_bar_fill.png` | 296x8 | 紫色渐变 |
| Boss血条背景 | `boss_hp_bg.png` | 600x32 | 大型血条背景 |
| Boss血条填充 | `boss_hp_fill.png` | 596x28 | 深红色渐变 |
| 武器槽背景 | `weapon_slot.png` | 48x48 | 方形边框 |
| 被动道具槽 | `passive_slot.png` | 40x40 | 小方形边框 |
| 波次数字 | `wave_number_bg.png` | 80x40 | 圆形背景 |
| 暂停按钮 | `btn_pause.png` | 48x48 | 暂停图标 |

### 3.3 升级界面

| 元素 | 资源名称 | 尺寸 | 描述 |
|-----|---------|------|------|
| 卡片背景 | `upgrade_card.png` | 180x240 | 升级选项卡片 |
| 卡片悬停 | `upgrade_card_hover.png` | 180x240 | 高亮效果 |
| 选中标记 | `selected_mark.png` | 40x40 | 勾选标记 |
| 等级星标 | `star_icon.png` | 16x16 | 表示等级 |
| 进化特效 | `evolution_glow.png` | 200x200 | 武器进化光效 |

### 3.4 商店界面

| 元素 | 资源名称 | 尺寸 | 描述 |
|-----|---------|------|------|
| 商店背景 | `shop_bg.png` | 1280x720 | 商人房间背景 |
| 商品格子 | `shop_slot.png` | 120x120 | 商品展示框 |
| 价格标签 | `price_tag.png` | 80x30 | 价格背景 |
| 已购买标记 | `sold_out.png` | 120x120 | 售罄遮罩 |
| 商人形象 | `merchant.png` | 128x128 | NPC立绘 |

### 3.5 游戏结束界面

| 元素 | 资源名称 | 尺寸 | 描述 |
|-----|---------|------|------|
| 胜利背景 | `victory_bg.png` | 1280x720 | 胜利场景 |
| 失败背景 | `defeat_bg.png` | 1280x720 | 失败场景 |
| 统计面板 | `stats_panel.png` | 600x400 | 数据显示面板 |
| 成就图标 | `achievement_icon.png` | 64x64 | 成就解锁图标 |
| 星星评分 | `star_gold.png` | 48x48 | 金星 |
| 星星评分 | `star_gray.png` | 48x48 | 灰星 |

---

## 🏰 四、背景与地图 (Backgrounds & Maps)

### 4.1 房间背景

| 场景 | 资源名称 | 尺寸 | 描述 |
|-----|---------|------|------|
| 标准房间 | `room_standard.png` | 1280x768 | 石砖地面，墙壁 |
| 宽阔大厅 | `room_hall.png` | 1600x960 | 大理石地面，柱子 |
| 方形密室 | `room_square.png` | 960x960 | 神秘符文地板 |
| Boss房间 | `room_boss.png` | 2080x1248 | 王座厅，红色地毯 |
| 传送房间 | `room_portal.png` | 1280x768 | 魔法阵中央 |

### 4.2 地图瓦片 (Tileset)

| 瓦片 | 资源名称 | 尺寸 | 描述 |
|-----|---------|------|------|
| 地板 | `tile_floor.png` | 32x32 | 基础地板 |
| 地板变化1 | `tile_floor_var1.png` | 32x32 | 破损地板 |
| 地板变化2 | `tile_floor_var2.png` | 32x32 | 有血迹地板 |
| 墙壁 | `tile_wall.png` | 32x32 | 石墙 |
| 墙壁转角 | `tile_wall_corner.png` | 32x32 | 墙角 |
| 柱子 | `tile_pillar.png` | 64x64 | 装饰柱子 |
| 障碍物 | `tile_obstacle.png` | 64x64 | 可破坏障碍物 |

### 4.3 环境装饰

| 装饰 | 资源名称 | 尺寸 | 描述 |
|-----|---------|------|------|
| 火炬 | `torch.png` | 32x48 | 墙壁火炬动画 |
| 窗户 | `window.png` | 64x96 | 哥特式窗户 |
| 棺材 | `coffin.png` | 64x32 | 吸血鬼棺材 |
| 书架 | `bookshelf.png` | 64x64 | 魔法书书架 |
| 蜘蛛网 | `cobweb.png` | 64x64 | 角落蜘蛛网 |
| 血迹 | `blood_splatter.png` | 64x64 | 地面血迹 |

---

## ✨ 五、特效 (Effects)

### 5.1 粒子特效

| 特效 | 资源名称 | 尺寸 | 帧数 | 描述 |
|-----|---------|------|------|------|
| 受击 | `hit_effect.png` | 32x32 | 4帧 | 白色闪光 |
| 死亡爆炸 | `death_explosion.png` | 64x64 | 8帧 | 红色爆炸 |
| 升级光环 | `levelup_aura.png` | 128x128 | 12帧 | 金色光环扩散 |
| 拾取经验 | `xp_collect.png` | 48x48 | 6帧 | 宝石飞向玩家 |
| 护盾破裂 | `shield_break.png` | 64x64 | 6帧 | 蓝色碎片 |
| 冻结效果 | `freeze_effect.png` | 48x48 | 8帧 | 冰晶覆盖 |
| 闪电反击 | `lightning_retaliate.png` | 64x64 | 4帧 | 受击闪电 |
| 闪避残影 | `dodge_afterimage.png` | 32x32 | 4帧 | 灰色残影 |
| 吸血效果 | `lifesteal.png` | 32x32 | 6帧 | 红色粒子飞向敌人 |
| 石化效果 | `petrify_effect.png` | 48x48 | 8帧 | 变灰石化 |

### 5.2 武器特效

| 特效 | 资源名称 | 尺寸 | 帧数 | 描述 |
|-----|---------|------|------|------|
| 子弹轨迹 | `bullet_trail.png` | 16x4 | 1帧 | 黄色拖尾 |
| 魔法弹轨迹 | `magic_trail.png` | 24x8 | 4帧 | 紫色拖尾 |
| 飞刀旋转 | `knife_spin.png` | 24x24 | 4帧 | 旋转飞刀 |
| 毒雾扩散 | `poison_spread.png` | 128x128 | 8帧 | 绿色雾气扩散 |
| 闪电链 | `chain_lightning.png` | 256x64 | 6帧 | 连接闪电 |
| 神圣光芒 | `holy_light.png` | 128x128 | 8帧 | 进化后手枪特效 |
| 刀阵旋风 | `knife_tornado.png` | 96x96 | 8帧 | 进化后飞刀特效 |
| 雷神之怒 | `thunder_wrath.png` | 256x256 | 10帧 | 进化后闪电特效 |

### 5.3 UI特效

| 特效 | 资源名称 | 尺寸 | 帧数 | 描述 |
|-----|---------|------|------|------|
| 按钮点击 | `btn_click.png` | 64x64 | 4帧 | 点击波纹 |
| 成就解锁 | `achievement_unlock.png` | 128x128 | 12帧 | 金色爆发 |
| 波次开始 | `wave_start.png` | 640x128 | 8帧 | 文字入场 |
| 伤害数字 | `damage_numbers.png` | 160x32 | - | 0-9数字精灵表 |
| 暴击文字 | `crit_text.png` | 128x64 | 6帧 | "暴击"弹出 |
| Boss警告 | `boss_warning.png` | 1280x720 | 10帧 | 红色警告效果 |

---

## 🎵 六、音频资源 (Audio)

### 6.1 背景音乐 (BGM)

| 音乐 | 资源名称 | 时长 | 描述 |
|-----|---------|------|------|
| 主菜单 | `bgm_menu.mp3` | 2:00 | 神秘哥特风琴 |
| 战斗1 | `bgm_battle1.ogg` | 3:00 | 紧张快节奏 |
| 战斗2 | `bgm_battle2.ogg` | 3:00 | 变奏版本 |
| Boss战 | `bgm_boss.ogg` | 4:00 | 史诗管弦乐 |
| 商店 | `bgm_shop.ogg` | 2:00 | 轻松诡异 |
| 胜利 | `bgm_victory.ogg` | 1:00 |  triumphant |
| 失败 | `bgm_defeat.ogg` | 1:00 | 悲伤钢琴 |

### 6.2 音效 (SFX)

| 音效 | 资源名称 | 描述 |
|-----|---------|------|
| 射击 | `sfx_shoot.wav` | 手枪射击 |
| 射击魔法 | `sfx_shoot_magic.wav` | 魔法发射 |
| 命中敌人 | `sfx_hit_enemy.wav` | 击中反馈 |
| 敌人死亡 | `sfx_enemy_death.wav` | 死亡惨叫 |
| 拾取经验 | `sfx_pickup_xp.wav` | 清脆音效 |
| 升级 | `sfx_levelup.wav` | 升级提示音 |
| 受伤 | `sfx_player_hurt.wav` | 玩家受伤 |
| 护盾破裂 | `sfx_shield_break.wav` | 护盾破碎 |
| 爆炸 | `sfx_explosion.wav` | 爆炸声 |
| 传送 | `sfx_teleport.wav` | 瞬移音效 |
| Boss咆哮 | `sfx_boss_roar.wav` | Boss登场 |
| 按钮点击 | `sfx_click.wav` | UI点击 |
| 悬停 | `sfx_hover.wav` | 按钮悬停 |
| 金币 | `sfx_coin.wav` | 获得货币 |

---

## 🔤 七、字体 (Fonts)

| 用途 | 字体名称 | 格式 | 描述 |
|-----|---------|------|------|
| 标题 | `title_font.ttf` | TTF | 哥特式衬线字体 |
| 正文 | `main_font.ttf` | TTF | 易读的无衬线 |
| 数字 | `number_font.ttf` | TTF | 等宽数字字体 |
| 伤害数字 | `damage_font.ttf` | TTF | 粗体冲击力字体 |

---

## 🎨 八、风格指南 (Style Guide)

### 8.1 色彩方案

| 用途 | 主色 | 辅助色 |
|-----|------|-------|
| 玩家 | #E8D5B7 (肤色) | #8B0000 (披风) |
| 敌人 | #4A0000 (暗红) | #2D0047 (紫色) |
| UI主色 | #FFD700 (金色) | #8B0000 (深红) |
| 特效 | #FF4500 (橙红) | #9400D3 (紫罗兰) |
| 背景 | #1A0A1A (深紫黑) | #2D1B2E (暗紫) |

### 8.2 像素风格规范

- **分辨率**: 游戏画面 640x360（16:9），像素放大 2x 或 3x
- **色深**: 限制调色板（32-64色）
- **描边**: 2-3像素黑色描边
- **阴影**: 使用投影而非渐变
- **动画**: 8-12帧/秒

---

## 📝 九、输出规格

### 9.1 图片格式

| 类型 | 格式 | 备注 |
|-----|------|------|
| 精灵图 | PNG-32 | 保留透明通道 |
| 背景 | PNG-24 或 WebP | 大尺寸优化 |
| 特效 | PNG-32 | 序列帧动画 |
| UI | PNG-32 | 9切片支持 |

### 9.2 命名规范

```
[类型]_[名称]_[状态].[格式]
示例：
- player_idle.png
- enemy_vampire_run.png
- effect_explosion_01.png
- ui_btn_hover.png
```

---

## 📊 十、资源统计

| 类别 | 数量估算 | 优先级 |
|-----|---------|-------|
| 玩家角色 | 6组动画 | 🔴 高 |
| 敌人 | 15种 x 4组 | 🔴 高 |
| Boss | 1种 x 6组 | 🔴 高 |
| 武器 | 6种 | 🟡 中 |
| 道具 | 20种 | 🟡 中 |
| UI元素 | 50+ | 🔴 高 |
| 背景 | 5张 | 🟡 中 |
| 瓦片 | 20种 | 🟡 中 |
| 特效 | 30种 | 🟢 低 |
| 音频 | 20+ | 🟡 中 |

**总计**: 约 200+ 个美术资源

---

## 🚀 十一、AI美工工具推荐

### 11.1 像素艺术生成

| 工具 | 优势 | 适用场景 | 价格 |
|-----|------|---------|------|
| **Midjourney** | 高质量概念图 | 角色设计、背景 | $10/月 |
| **DALL-E 3** | 理解力强 | 快速原型、草图 | $20/月 |
| **Stable Diffusion** | 免费开源 | 批量生成、定制 | 免费 |
| **PixelLab** | 专为像素设计 | 精灵图、动画 | $15/月 |
| **Aseprite** | 专业像素软件 | 手动精修、动画 | $20一次性 |

### 11.2 推荐工作流

```
1. 概念设计: Midjourney/DALL-E → 生成角色概念图
2. 像素转换: PixelLab/Stable Diffusion → 转为像素风格
3. 精修动画: Aseprite → 手动调整、制作动画
4. UI设计: Figma + AI插件 → 界面设计
5. 特效生成: Stable Diffusion → 粒子特效
```

### 11.3 针对本游戏的推荐

**首选方案：Midjourney + Aseprite**
- 用 Midjourney 生成哥特风格角色概念图
- 在 Aseprite 中手动重绘为像素风格
- 保证风格统一和质量

**性价比方案：Stable Diffusion + Aseprite**
- 本地部署 SD，使用像素风格 LoRA
- 批量生成基础素材
- Aseprite 精修

**快速原型：PixelLab**
- 专为游戏像素艺术优化
- 内置角色模板和动画工具
- 适合快速出图

---

*文档版本: 1.0*
*创建日期: 2024年*
*游戏: 吸血鬼猎人 (Vampire Hunter)*
