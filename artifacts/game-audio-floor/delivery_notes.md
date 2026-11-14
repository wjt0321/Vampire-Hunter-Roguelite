# 楼层专属 BGM 批次交付说明（2026-11-14）

## 这一批解决什么

实机反馈：**「背景音乐我有好几首的，怎么从头到尾只听到一首？」**

诊断（`tools/bgm_switch_diag.gd`）：`AudioManager.play_bgm()` 的切换机制**本身是好的**——
battle → shop → boss 实测都能换流，0.5s 淡出淡入也正常。
真正的原因是**所有战斗房都只有一首 `battle.ogg`**，换房换的还是同一首。

所以做法不是修切换，而是**补曲子**：每层一首主题曲，战斗房进入时按层取。

## 曲目

| 文件 | 楼层 | BPM | 调式 | 时长 |
|---|---|---|---|---|
| `floor_1.ogg` | 1 血月回廊 | 124 | D 小调 | 1:00 循环 |
| `floor_2.ogg` | 2 织血巢穴 | 132 | F# 小调 | 1:00 循环 |
| `floor_3.ogg` | 3 骸骨墓穴 | 108 | A 小调 | 1:00 循环 |
| `floor_4.ogg` | 4 炼金工坊 | 138 | C 小调 | 1:00 循环 |
| `floor_5.ogg` | 5 月蚀王座 | 146 | E 小调 | 1:00 循环 |

Boss 战沿用已有的 `boss.ogg`（已是专属曲），商店用 `shop.ogg`，菜单用 `menu.ogg`。

## 接入

- `scripts/managers/audio_library.gd`：`BGM_PATHS` 加 `floor_1..floor_5`，
  `LOOPING_BGMS` 追加同 5 个键，新增 `get_floor_bgm(floor_index)`。
  **文件缺失时回退 `battle.ogg`**，不允许因为一首歌没生成出来就整局静音。
- `scripts/managers/main.gd`：战斗房 / 雾房 / 镜像房进入时的
  `get_battle_bgm()` 换成 `get_floor_bgm(dungeon.current_floor)`；shop / boss 不动。

## 管线

复用第 12 条（`artifacts/game-audio-iteration/`）已跑通的那套：
本机 ComfyUI 0.45.2 + YuE2 int8 乐器 LoRA → FLAC →
`tools/prepare_iteration_audio.py` 裁剪 / 响度归一（-21 LUFS）/ 尾首交叠循环 → 48kHz 立体声 OGG。

- 清单：`tools/make_floor_audio_manifest.py` → `manifest.json`（提示词、种子 2026111601~605）
- 原始 FLAC：`raw/`（gitignore，不入库）
- 实际 API 图：`workflows/bgm_floor_1~5.api.json`
- 母带指标与哈希：`audio_report.json`

## 验证

- `tools/feedback7_shots.gd`：实机跑一遍，逐层断言 `get_floor_bgm(1..5)` 返回
  **5 个互不相同**的真实 OGG；进 Boss 房断言实际播放的是 `boss.ogg`。fail=0。
- `tools/iteration_bgm_test.gd`：34 / 34 通过（6 首旧 BGM 的真实时长与循环接缝未受影响）。
