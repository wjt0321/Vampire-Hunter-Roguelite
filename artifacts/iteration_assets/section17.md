

## 十七、2026-11-14 迭代新增敌人与新武器图标专属资产

### 为什么做这一轮

新玩法切片（2026-11-13 玩法迭代）加了 12 种敌人、7 把新武器、5 张融合卡、3 个新被动，
但当时是「先做行为、图后面补」：这 12 种敌人在游戏里全部**借用 MVP 旧图再染色**
（texture_manager.gd 里注释写明「新敌人的专属序列帧还没到」），新武器图标也是借用
散弹/圣光/魔法书/弩的图。本轮把这些占位全部换成专属资产。

### 风格锚：MVP 已验收的那一套

风格基准不是新发明的，而是用户在 MVP 阶段明确认可过的那批源图：
E:\AI\ComfyUI\output\vhr_reskin\（36 张 1024×1024）。它的特征是
**正面前视、粗颗粒像素画、暗钢+旧金描边+深红宝石、品红抠底**。
本轮沿用同一套 ComfyUI 工作流、同一套抠底/量化/错帧脚本，只换画什么。

### 制作管线（复用 MVP 认可的管线，没有另起炉灶）

| 环节 | 做法 | 出处 |
|---|---|---|
| 出图 | 本机 ComfyUI + 图片_Qwen-Image2.1_文生图.json（立绘）/ 图片_Qwen-Image2.1_图像编辑.json（死亡姿态） | .workbuddy/comfy/reskin_pipeline.py |
| 死亡姿态 | 用立绘原图拼成 3×2 绿底网格当编辑源图，Edit 会把 6 格画成 6 个不同的倒地阶段 | tools/gen_enemy_death_grid.py |
| 抠底 | 品红键控 + 抗锯齿过渡带清理（紫边） | reskin_pipeline.key_magenta / purge_purple_edge |
| 缩格 | NEAREST 整数倍缩到 56×56 单格，脚底锚点固定 | reskin_pipeline.to_cell |
| 错帧 | 待机：下摆 1px 摆动；死亡：下沉 + 变暗 + 渐隐 | tools/build_pose_strips.py |
| 调色板 | 固定 32 色哥特色板（不按频次取色，避免一张偏暖一张偏冷） | .workbuddy/comfy/postprocess.py |

出图落盘统一在 E:\AI\ComfyUI\output\vhr_iter\，与 vhr_reskin / vhr_new / vhr_edit 同级。

### 交付物

**敌人精灵（12 种 × 2 张 = 24 张横条）**

- 立绘 idle：224×56（4 帧），单格 56×56。
- 死亡 death：336×56（6 帧），单格 56×56，六帧是真的倒地过程，不是同一张尸体复制。
- 路径：assets/sprites/enemies/<enemy_id>/idle.png 与 .../death.png
  （走 asset_slots.gd 早就预留好的专属目录机制，文件一放进去就会被读到）。

| 敌人 | 中文名 | 状态 |
|---|---|---|
| shield_guard | 盾卫 | idle + death 已完成 |
| blood_priest | 血祭司 | idle + death 已完成 |
| web_weaver | 织网者 | idle + death 已完成 |
| coffin_guard | 棺卫 | idle + death 已完成 |
| blood_hound | 血猎犬 | idle + death 已完成 |
| furnace_golem | 炉心巨像 | idle + death 已完成 |
| burrower | 潜伏者 | idle + death 已完成 |
| gem_leech | 吞晶虫 | idle + death 已完成 |
| lantern_wraith | 灯鬼 | idle + death 已完成 |
| alchemist_pitcher | 炼金投手 | idle + death 已完成 |
| resonance_mage | 共鸣术士 | idle + death 已完成 |
| moon_wing | 月翼兽 | idle + death 已完成 |

**图标（15 张 48×48）**

- 新武器 7 张：assets/weapons/icons/{scythe,thorn_whip,frost_bell,repeater,soul_lantern,spike_tome,chain_gun}.png
- 融合卡 5 张：assets/weapons/icons/{thunder_bolt,miasma_shot,returning_blade,twin_chant,burning_blood}.png
- 新被动 3 张：assets/ui/passives/{execution_mark,time_gear,cold_blood}.png

图标走 ItemCatalog.get_icon_texture() 的专属目录优先分支，升级三选一 / 房间商店 /
元进度商店 / HUD 全部自动换成新图，不再借用别的武器的图标。

### 接线改动

| 文件 | 改动 |
|---|---|
| scripts/enemies/enemy_base.gd | 新增 use_dedicated_sprite()：专属目录有图就用它且不染色，没有才退回借用旧图并保留染色标记 |
| scripts/enemies/enemy_base.gd | _die() 优先播放专属死亡条（6 帧逐帧播完再淡出回收），没有死亡条才沿用原来的直接淡出 |
| scripts/enemies/<12 个敌人>.gd | use_placeholder_sprite(...) 改成 use_dedicated_sprite(...) |
| scripts/core/asset_slots.gd | 12 个敌人的状态表补上 death |

### 仍然没做的（边界）

1. **行走/攻击动作没有做**：这批只出了 idle 与 death。新敌人移动时播的是待机条
   （下摆 1px 摆动），近战扑击、施法、吐网、钻地这些专属动作仍是借用或程序表现。
2. **地面危险贴图没有做**：减速网、棺材、卵巢、药液、月蚀安全圈仍是半透明多边形和圆环。
3. **旧敌人的动作缺口没有动**：吸血鬼/狼人/僵尸等的 death、run、hurt 仍在第四节清单里待补。
4. 特效序列帧（P1-B）没有动。
5. 授权边界：全部为 AI 生成素材，登记为「AI 生成、待核实」，见 docs/asset-licenses.md。

### 复现

- 出图计划：artifacts/iteration_assets/plan_enemies.json、plan_icons.json
- 生成入口：python tools/gen_iteration_sprites.py --plan <plan>（立绘 + 图标）
- 死亡网格：python tools/gen_enemy_death_grid.py
- 审阅拼版：python tools/iteration_contact_sheet.py
