# 夜幕猎人：完整音频交付

共 6 段 BGM + 29 种 SFX，已接入当前 Godot 工程。普通战斗复用已选定的 YuE2 第二版；其余配乐使用本地 YuE2，音效使用本地 Stable Audio 3 Small SFX。

## 直接试听与使用

- `gameplay_mix.mp3`：最终资源版本的约35秒真实首房战斗总线录音，站立高生命测试角色自动开火。
- `preview/sfx_reel_1.mp3`、`sfx_reel_2.mp3`、`sfx_reel_3.mp3`：29种音效，每3秒播放一项；顺序见下方清单（前10、中10、后9）。
- `preview/bgm_*.mp3`：六段配乐；`preview/loop_*.mp3`：四段循环接缝试听，第4秒为尾头交接。
- `assets/audio/generated/`：游戏正式 OGG，48kHz；SFX单声道，BGM立体声。菜单、战斗、Boss、商店循环，胜败单次播放并淡出。
- 当前工作区直接用 Godot 打开 `project.godot` 运行即可，音量沿用已有设置。
- ZIP 保留项目相对目录，包含音频、原始FLAC、API工作流、修改的接入源码、制作工具与测试证据；它不是独立游戏安装包。代码文件供本项目对应版本集成使用。

## 完整清单

| 用途 | 资源键 | 时长 | 播放方式 |
|---|---|---:|---|
| 手枪 | `shoot_pistol` | 0.24 秒 | 单次音效 |
| 霰弹枪 | `shoot_shotgun` | 0.55 秒 | 单次音效 |
| 魔法弹 | `shoot_magic` | 0.42 秒 | 单次音效 |
| 飞刀 | `knife_throw` | 0.25 秒 | 单次音效 |
| 毒雾 | `poison_cloud` | 0.85 秒 | 单次音效 |
| 闪电 | `lightning_chain` | 0.55 秒 | 单次音效 |
| Boss攻击 | `boss_attack` | 0.90 秒 | 单次音效 |
| 敌人受击 | `hit_enemy` | 0.18 秒 | 单次音效 |
| 敌人死亡 | `enemy_death` | 0.56 秒 | 单次音效 |
| 经验拾取 | `pickup_xp` | 0.16 秒 | 单次音效 |
| 升级 | `level_up` | 1.30 秒 | 单次音效 |
| 点击 | `button_click` | 0.12 秒 | 单次音效 |
| 爆炸 | `explosion` | 0.85 秒 | 单次音效 |
| 护盾破裂 | `shield_break` | 0.65 秒 | 单次音效 |
| 治疗 | `heal` | 0.85 秒 | 单次音效 |
| 玩家受伤 | `player_hurt` | 0.37 秒 | 单次音效 |
| 悬停 | `hover` | 0.07 秒 | 单次音效 |
| 传送 | `teleport` | 0.80 秒 | 单次音效 |
| 弩箭 | `shoot_crossbow` | 0.30 秒 | 单次音效 |
| 喷火 | `flame_thrower` | 0.55 秒 | 单次音效 |
| 血爆 | `blood_burst` | 0.65 秒 | 单次音效 |
| 圣杖 | `holy_wand` | 0.47 秒 | 单次音效 |
| 购买 | `purchase` | 0.55 秒 | 单次音效 |
| 宝箱 | `chest_open` | 1.50 秒 | 单次音效 |
| 清房 | `room_clear` | 1.10 秒 | 单次音效 |
| 开门 | `door_open` | 0.82 秒 | 单次音效 |
| 银币拾取 | `pickup_coin` | 0.20 秒 | 单次音效 |
| 磁力拾取 | `pickup_magnet` | 0.65 秒 | 单次音效 |
| 狂热拾取 | `pickup_frenzy` | 0.80 秒 | 单次音效 |
| 夜幕猎人 | `menu` | 56.75 秒 | 循环 |
| 猎杀脉冲 | `battle` | 57.35 秒 | 循环 |
| 猩红王座 | `boss` | 57.35 秒 | 循环 |
| 烛火与银币 | `shop` | 56.75 秒 | 循环 |
| 黎明归来 | `victory` | 20.00 秒 | 一次播放 |
| 最后的烛火 | `defeat` | 20.00 秒 | 一次播放 |

## 接入修正

同曲请求保持进度并取消旧的切换回调；霰弹单次齐射只发声一次；闪电有目标才发声；有效治疗、购买、宝箱、清房、开门及银币/磁力/狂热使用专用反馈。相同战斗音效在50ms内合并，暂停界面仍可播放反馈。缺少正式音频会明确报错。

## 最终检查记录

- Godot 4.7.2：播放行为回归107/107，真实资源回归183/183，三层地牢走到胜利结算，三套均退出0且无脚本/资源错误。完整日志位于包内 `.tools/qa/audio-final-validation/`。
- 35项OGG完成解码与非空、有限值、峰值检查；打包时逐项SHA-256与 `audio_report.json` 核对。
- 最终WASAPI总线录音：音乐和音效设置均1.0，捕获1,731,584帧，峰值0.5259727（约−5.58dBFS），削波帧0。仅代表这一段首房战斗，不是所有关卡的峰值保证。见 `gameplay_mix_report.json` 与日志。
- 独立源码审查发现的包外试听依赖已修复；屏蔽旧试听目录后35项续跑均跳过已有raw，无网络调用。见 `review_resolution.json`。
- `listening_final.json` 归并最终版本的辅助音频理解，已用新版菜单与第三组音效复查覆盖旧结论；`listening_gameplay.json` 是最终混音辅助检查。均不替代人工听感验收，其中模型描述的BPM/调性/“实测”等词不作为客观测量。
- 循环曲单独播完会停在乐句中；游戏内会回到开头，接缝另有8秒试听。胜败曲有独立淡出。

## 制作与恢复

`manifest.json` 保存提示词、种子、版本和制作参数；`raw/` 保存选用原始FLAC；`workflows/` 保存实际API图；`audio_report.json` 保存剪辑参数、波形指标与哈希。旧弃用版本及带临时签名URL的调用参数未放入ZIP。

工具默认本机 ComfyUI `http://127.0.0.1:8188` 和 FFmpeg `E:/AI/ffmpeg/current/bin/ffmpeg.exe`，重新制作需相应模型与依赖；换机器需调整FFmpeg路径。完整包执行 `python tools/render_game_audio.py` 会跳过35个现有raw。复用的battle raw若误删，请从ZIP恢复；其复制分支仍需要历史源FLAC，不应当成自动再生成命令。后处理使用 `python tools/prepare_game_audio.py`。

本次未提交、推送或发布，测试全部使用隔离存档。
