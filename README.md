# 🧛 吸血鬼猎人 (Vampire Hunter Roguelite)

**Godot 4.6 · GDScript · 2D 俯视角肉鸽动作游戏**

---

## 📖 简介

一款暗黑哥特风格的 2D Roguelite 动作游戏。玩家扮演猎人在不断涌来的吸血鬼和怪物潮中求生，通过击杀获取经验升级武器，探索随机生成的房间，最终挑战 Boss。

### 核心特性

| 特性 | 描述 |
|---|---|
| 🎮 动作战斗 | WASD 移动 + 鼠标瞄准射击，多武器自动开火 |
| 🗡️ 武器系统 | 手枪/散弹/激光/环绕球/魔法书，可堆叠升级和进化 |
| 🗺️ 房间探索 | 程序化生成房间（战斗/商店/宝箱/休息/Boss） |
| 👑 Boss 战 | 吸血鬼领主：弹幕 + 召唤 + 冲刺，50% 血量狂暴 |
| 💎 永久进度 | 血晶货币 + 6 种永久升级 + 可解锁角色 |
| 🧛 多角色 | 猎人阿尔忒弥斯（平衡）/ 牧师塞西莉亚（防御） |

---

## 🎯 操作方式

| 按键 | 功能 |
|---|---|
| `W/A/S/D` | 移动 |
| `鼠标左键` | 射击 |
| `ESC` | 暂停菜单 |

---

## 🏗️ 项目结构

```
VampireHunter/
├── scenes/
│   ├── main.tscn              # 游戏主场景
│   ├── player/                # 玩家、子弹、经验宝石
│   ├── enemies/               # 蝙蝠/僵尸/狼人/吸血鬼/Boss
│   └── ui/                    # 主菜单/HUD/暂停/结算/商店/角色选择
├── scripts/
│   ├── managers/              # main/wave_manager/save_manager/vfx_manager
│   ├── player/                # player/bullet/xp_gem/character_data
│   ├── enemies/               # enemy_base + 5种敌人
│   ├── weapons/               # weapon_manager/weapon_data
│   ├── map/                   # game_room/room_manager
│   └── ui/                    # 所有 UI 脚本
└── project.godot
```

### AutoLoad 单例

| 单例 | 职责 |
|---|---|
| `SaveManager` | JSON 存档、血晶、升级、角色解锁 |
| `VFXManager` | 粒子特效、屏幕震动 |

---

## 🚀 运行方式

1. 安装 [Godot 4.6+](https://godotengine.org/download)
2. 打开项目：`项目 → 导入 → 选择 project.godot`
3. 按 `F5` 运行游戏

---

## 📈 开发进度

- [x] Phase 1-5: 核心循环（玩家/敌人/波次/经验/武器）
- [x] Phase 6: 地图与房间系统
- [x] Phase 7: Boss 战
- [x] Phase 8: UI 系统（主菜单/HUD/暂停/结算）
- [x] Phase 9: 永久进度（存档/血晶/升级/多角色）
- [x] Phase 10: VFX 特效系统
- [x] Phase 11: 最终测试

---

## 🔮 后续开发建议

### 🎨 优先级 1：视觉升级

- **像素美术替换** — 用 16×16 / 32×32 Sprite Sheet 替换彩色方块
  - 推荐工具：[Aseprite](https://www.aseprite.org/)、[Pixelorama](https://orama-interactive.itch.io/pixelorama)
  - 免费素材：[itch.io 像素包](https://itch.io/game-assets/tag-pixel-art)
- **角色动画** — 待机/跑动/射击/受伤/死亡帧动画（AnimatedSprite2D）
- **地图 Tilemap** — 用 TileMapLayer 替换程序化 ColorRect 壁，添加地砖纹理

### 🔊 优先级 2：音频系统

- **BGM** — 主菜单/战斗/Boss 战各一首循环音乐
- **SFX** — 射击/受击/死亡/拾取/升级/按钮点击
- **AudioManager 单例** — 管理音效播放，带音量控制
- 免费音效：[Freesound](https://freesound.org/)、[OpenGameArt](https://opengameart.org/)

### ⚔️ 优先级 3：玩法扩展

- **更多敌人类型** — 远程射手、自爆者、精英怪（带词缀：速度/护甲/分裂）
- **更多武器** — 投掷飞刀、毒雾、闪电链、火焰区域
- **更多角色** — 刺客（高速低血）、法师（远程 AOE）、骑士（近战坦克）
- **被动道具系统** — 像《吸血鬼幸存者》的被动组件（磁铁/护盾/回血光环）
- **成就系统** — 击杀里程碑、通关挑战、隐藏解锁

### 🏰 优先级 4：关卡深度

- **多层地下城** — 每 10 个房间进入下一层，敌人变强
- **地图事件** — 随机事件（陷阱/NPC/隐藏房间）
- **多 Boss** — 每层一个 Boss，最终 Boss 为吸血鬼女王
- **每日挑战** — 固定种子 + 特殊规则

### 🌐 优先级 5：发布准备

- **本地化** — 中英文切换（Godot 内置 `TranslationServer`）
- **手柄支持** — 添加游戏手柄输入映射
- **Steam 集成** — Steamworks SDK，成就，排行榜
- **性能分析** — Godot Profiler 优化大量敌人场景

---

## 📄 License

MIT License — 自由使用和修改
