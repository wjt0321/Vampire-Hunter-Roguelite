# 素材整理执行计划

> 目标：将 `assets-downloaded/` 中的原始素材按项目需求整理到 `assets/` 各目录，统一命名，补齐 P0/P1 缺口，并更新文档。

## 当前状态

- `assets/` 已有部分终版素材（玩家、基础敌人、Boss 部分、UI 部分、武器部分、背景、特效）。
- `assets-downloaded/` 已下载 192 个文件，约 70MB，涵盖 Kenney(CC0)、OpenGameArt(CC0/CC-BY)、Google Fonts(OFL) 等来源。
- 缺口主要集中在：UI 状态图、武器/道具图标、音效、字体、瓦片/装饰、Boss 动作、高级敌人。

## 执行策略

1. **优先补齐 P0 可玩性素材**：UI 基础交互、基础音效、字体、核心道具图标、瓦片基础。
2. **风格统一原则**：以 Kenney CC0 资源为统一基础；OpenGameArt CC0/CC-BY 资源作为补充；避免混入风格差异过大的素材。
3. **复用与占位**：对暂时无法精确匹配的资源，使用颜色变体、缩放变体或相近资源占位，并在文档中标注。
4. **命名规范**：`[类型]_[名称]_[状态].[格式]`，例如 `btn_pressed.png`、`icon_magnet.png`、`sfx_click.wav`。

## 分类执行

按以下类别并行处理：

| 类别 | 负责人 | 关键来源 | 产出目录 |
|------|--------|----------|----------|
| UI 元素 | 子代理 | `ui/kenney_ui-pack`, `ui/PixelUIpack`, `ui/ui_big_pieces.png` | `assets/ui/` |
| 武器与道具图标 | 子代理 | `weapons/kenney_game-icons`, `weapons/rpg_inventory` | `assets/weapons/` |
| 特效 | 子代理 | `effects/kenney_particle-pack`, `effects/explosion_sprites`, `effects/blood_hit_*.png` | `assets/effects/` |
| 地图瓦片与装饰 | 子代理 | `tiles/kenney_roguelike-*`, `tiles/Dungeon Crawl Stone Soup Full`, `tiles/castle_*.png` | `assets/tiles/`, `assets/tiles/props/` |
| 音频与字体 | 子代理 | `audio/kenney_*`, `bgms/`, `fonts/*` | `assets/audio/sfx/`, `assets/audio/bgm/`, `assets/fonts/` |
| 角色、敌人与 Boss | 子代理 | `sprites/kenney_roguelike-characters`, `sprites/vampire*`, `sprites/bat*`, `sprites/zombie*`, `sprites/pixel-skeleton`, `sprites/mage*`, `sprites/gargoyle*` 等 | `assets/sprites/player/`, `assets/sprites/enemies/`, `assets/sprites/boss/` |

## 文档更新

- 更新 `docs/asset-licenses.md`，登记所有新增素材的来源与授权。
- 更新 `docs/missing-assets-todo.md`，将已补齐项标记为 DONE，并补充剩余缺口。
- 更新 `docs/asset_mapping_guide.md` 中的映射关系（如新增条目）。

## 验证

- 检查 `assets/` 目录结构与 `docs/art-assets-requirements.md` 的对应关系。
- 确认新增文件均已纳入 Git 跟踪（通过 `git status`）。
- 检查授权文档无遗漏。
