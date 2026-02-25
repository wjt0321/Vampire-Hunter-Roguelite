# 🧛 吸血鬼猎人 (Vampire Hunter Roguelite)

[![Godot Version](https://img.shields.io/badge/Godot-4.6+-478061?style=flat&logo=godot-engine)](https://godotengine.org)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Mac%20%7C%20Linux-blue.svg)](https://godotengine.org)

一款暗黑哥特风格的 2D Roguelite 动作游戏。玩家扮演猎人在不断涌来的吸血鬼和怪物潮中求生，通过击杀获取经验升级武器，探索随机生成的房间，最终挑战 Boss。

---

## 📖 游戏简介

### 核心特性

| 特性 | 描述 |
|------|------|
| 🎮 动作战斗 | WASD 移动 + 鼠标瞄准射击，多武器自动开火 |
| 🗡️ 武器系统 | 手枪/散弹/激光/魔法书/飞刀/毒雾/闪电链，可堆叠升级和进化 |
| 🗺️ 房间探索 | 程序化生成房间（战斗/商店/宝箱/休息/Boss） |
| 👑 Boss 战 | 吸血鬼领主：弹幕 + 召唤 + 冲刺，50% 血量狂暴 |
| 💎 永久进度 | 血晶货币 + 6 种永久升级 + 2 个可解锁角色 |
| 🧛 多角色 | 猎人阿尔忒弥斯（平衡）/ 牧师塞西莉亚（防御） |
| 🎵 音频系统 | 音效管理、音量控制 |
| ✨ 视觉特效 | 粒子系统、屏幕震动、子弹拖尾、冰冻/闪避效果 |

---

## 🎮 游戏截图

> 在此添加游戏截图

![游戏截图](docs/images/screenshot.png)

---

## 🎯 操作方式

| 按键 | 功能 |
|------|------|
| `W/A/S/D` | 移动 |
| `鼠标左键` | 射击 |
| `ESC` | 暂停菜单 |

---

## 🚀 开始游戏

### 环境要求

- **Godot Engine 4.6+**
- **操作系统**: Windows / macOS / Linux

### 运行步骤

1. 克隆或下载本项目
2. 安装 [Godot 4.6+](https://godotengine.org/download)
3. 打开 Godot，点击 "导入" 并选择 `project.godot`
4. 按 `F5` 运行游戏

---

## 🗂️ 项目结构

```
VampireHunter/
├── scenes/                    # 游戏场景
│   ├── main.tscn              # 主场景
│   ├── player/                # 玩家相关
│   ├── enemies/               # 敌人
│   └── ui/                    # UI界面
├── scripts/                   # 源代码
│   ├── managers/              # 游戏管理器
│   ├── player/                # 玩家逻辑
│   ├── enemies/               # 敌人逻辑
│   ├── weapons/               # 武器系统
│   └── ui/                    # UI脚本
├── assets/                    # 资源文件
│   ├── sprites/               # 精灵图
│   ├── backgrounds/           # 背景图
│   ├── ui/                    # UI资源
│   ├── effects/               # 特效
│   └── weapons/               # 武器图标
├── docs/                      # 开发文档
└── project.godot              # 项目配置
```

---

## 🎮 已实现内容

### 武器系统 (7种)

| 武器 | 描述 |
|------|------|
| 🔫 手枪 | 基础单发 |
| 💥 散弹枪 | 扇形射击 |
| 🔦 激光 | 穿透射线 |
| 📖 魔法书 | 追踪法术 |
| 🗡️ 飞刀 | 穿透攻击 |
| ☠️ 毒雾 | 范围毒伤 |
| ⚡ 闪电链 | 连锁攻击 |

### 敌人类型 (6种)

| 敌人 | 描述 |
|------|------|
| 🦇 蝙蝠 | 快速小怪 |
| 🧟 僵尸 | 近战小怪 |
| 🐺 狼人 | 冲锋精英 |
| 🧛 吸血鬼 | 中等敌人 |
| 💀 骷髅射手 | 远程攻击 |
| 👹 吸血鬼领主 | Boss |

### 被动道具 (8种)

- 🧲 经验磁铁
- 🛡️ 能量护盾
- 💚 生命恢复
- 💍 贪婪戒指
- 🩸 狂战士之血
- ❄️ 冰冻之心
- ⚡ 闪电护符
- 🌑 影子披风

### 永久升级 (6种)

- ⚔️ 基础伤害 +5%/级
- ❤️ 基础血量 +10/级
- 👟 基础速度 +5%/级
- 🛡️ 基础护甲 +3/级
- ✨ 经验加成 +10%/级
- 💎 血晶加成 +10%/级

---

## 🗺️ 开发路线图

详见 [docs/ROADMAP.md](docs/ROADMAP.md)

---

## 🤝 贡献指南

欢迎提交 Issue 和 Pull Request！

### 开发环境设置

```bash
# 克隆项目
git clone https://github.com/yourusername/VampireHunter.git

# 安装 Godot 4.6+
# 导入项目并运行
```

---

## 📄 许可证

本项目基于 MIT 许可证开源 - 查看 [LICENSE](LICENSE) 了解详情。

---

## 🙏 致谢

- [Godot Engine](https://godotengine.org) - 游戏引擎
- [itch.io](https://itch.io/game-assets/tag-pixel-art) - 免费像素美术资源
