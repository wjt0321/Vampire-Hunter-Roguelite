# Vampire Hunter Roguelite 素材来源清单

> 目标：给当前项目提供可直接搜索、下载、购买或生成素材的渠道与关键词。优先考虑 Godot 友好、像素风、暗黑哥特、Roguelite、俯视角/近俯视角资源。

---

## 一、使用原则

### 1. 优先找成套资源

尽量按以下组合找素材：

- 1 套暗黑/地牢 tileset
- 1 套怪物/角色像素包
- 1 套哥特 UI 包
- 1 套通用 SFX 包
- AI 生成 Logo、封面、背景、补缺图标

这样比从十几个包里东拼西凑更容易保持统一。

### 2. 下载前必须检查授权

每个素材下载前都要确认：

- 是否允许商用
- 是否需要署名
- 是否允许修改
- 是否允许打包进游戏发布
- 是否禁止二次分发源文件

建议在项目里新增：

- `docs/asset-licenses.md`
- 记录来源 URL、作者、授权、用途、下载日期

### 3. 风格筛选标准

优先选择：

- 像素风
- 暗黑/哥特/地牢/吸血鬼/亡灵主题
- 俯视角、近俯视角或可裁切为俯视角
- 32x32 / 48x48 / 64x64 尺寸体系
- 深色描边、低饱和度、暗紫/暗红/金色点缀

谨慎使用：

- 明显横版侧视素材
- 过于 Q 版或过于现代枪械风素材
- 过度写实、非像素风素材
- UI 与角色风格完全不一致的包

---

## 二、综合素材站

### Kenney

- 网站：https://kenney.nl/assets
- 适合：UI、图标、音效、占位资源、粒子素材
- 优点：授权友好、质量稳定、结构规范
- 推荐用途：按钮、面板、武器槽、通用 SFX、基础图标占位

推荐搜索：

- `kenney ui pack`
- `kenney interface sounds`
- `kenney impact sounds`
- `kenney particle pack`
- `kenney roguelike`
- `kenney dungeon`

适合补：

- `btn_pressed.png`
- `weapon_slot.png`
- `passive_slot.png`
- `sfx_click.wav`
- `sfx_hover.wav`
- `sfx_pickup_xp.wav`

---

### itch.io Game Assets

- 网站：https://itch.io/game-assets
- 适合：像素角色、怪物、UI、地牢 tileset、完整主题包
- 优点：成套素材多，暗黑/像素/地牢资源丰富
- 风险：授权各不相同，必须逐项确认

推荐搜索：

- `pixel gothic ui`
- `dark fantasy pixel art`
- `vampire pixel art`
- `vampire enemy pixel`
- `top down dungeon pixel`
- `pixel dungeon tileset`
- `roguelite asset pack`
- `pixel monster pack`
- `dark fantasy monster pack`
- `gothic castle tileset`
- `pixel boss monster`
- `top down roguelike assets`

适合补：

- 高级敌人
- Boss 动画
- tileset
- UI 皮肤
- 商店/结算界面
- 地牢装饰物

---

### OpenGameArt

- 网站：https://opengameart.org
- 适合：免费像素资源、BGM、SFX、地牢 tileset、亡灵怪物
- 优点：免费资源多，适合原型和补缺
- 风险：风格杂，授权类型多，需要筛选

推荐搜索：

- `vampire pixel`
- `undead pixel`
- `gothic tileset`
- `dungeon tileset 32x32`
- `top down dungeon`
- `skeleton archer pixel`
- `bat pixel animation`
- `dark magic effect`
- `pixel explosion`
- `gothic music loop`
- `dark fantasy music`

适合补：

- `exploder_walk.png`
- `summoner_cast.png`
- `gargoyle_idle.png`
- `tile_floor.png`
- `torch.png`
- BGM 与 SFX

---

### GameDev Market

- 网站：https://www.gamedevmarket.net
- 适合：付费商用品质角色、UI、图标、场景资源
- 优点：商业项目可用资源多，质量比免费站更稳定
- 风险：需要花钱，注意授权范围

推荐搜索：

- `dark fantasy pixel`
- `gothic ui`
- `dungeon tileset pixel`
- `top down monster`
- `vampire game assets`
- `pixel roguelike pack`

适合补：

- 统一 UI 包
- 统一敌人包
- 图标包
- 商业化版本替换资源

---

### CraftPix

- 网站：https://craftpix.net
- 适合：完整 UI、角色、怪物、背景、图标包
- 优点：成套程度高，适合快速补项目观感
- 风险：不少资源偏横版/手游风，需要筛选是否适合俯视角

推荐搜索：

- `dark fantasy ui`
- `gothic game ui`
- `monster pixel art`
- `vampire game assets`
- `dungeon game tileset`
- `roguelike icons`

适合补：

- 主菜单 UI
- 升级卡 UI
- 商店 UI
- 胜利/失败界面
- 道具图标

---

## 三、分类素材来源

### 1. 玩家与敌人精灵

优先渠道：

- itch.io
- OpenGameArt
- GameDev Market
- CraftPix

推荐关键词：

- `top down vampire hunter pixel`
- `pixel vampire hunter character`
- `dark fantasy pixel character`
- `pixel undead enemy pack`
- `pixel skeleton archer animation`
- `pixel bat flying animation`
- `pixel werewolf animation`
- `pixel vampire boss`
- `gothic monster pixel art`
- `top down monster sprites`

项目对应资源：

- `player_idle.png`
- `player_run.png`
- `player_attack.png`
- `exploder_walk.png`
- `summoner_cast.png`
- `mage_cast.png`
- `gargoyle_idle.png`
- `prince_idle.png`
- `boss_attack3.png`
- `boss_death.png`

建议：

- 玩家主角最终最好定制或重绘，保证辨识度
- 敌人可以先用成套包，后续逐步替换关键敌人
- 高级敌人可先用已有敌人改色/缩放/加光效暂代

---

### 2. 地图与场景

优先渠道：

- itch.io
- OpenGameArt
- Kenney
- GameDev Market

推荐关键词：

- `top down dungeon tileset 32x32`
- `gothic castle tileset pixel`
- `dark dungeon pixel tileset`
- `vampire castle tileset`
- `roguelike dungeon tiles`
- `pixel dungeon props`
- `castle interior pixel art`
- `top down gothic room`
- `pixel crypt tileset`
- `dungeon decoration pixel`

项目对应资源：

- `room_square.png`
- `tile_floor.png`
- `tile_floor_var1.png`
- `tile_floor_var2.png`
- `tile_wall.png`
- `tile_wall_corner.png`
- `tile_pillar.png`
- `tile_obstacle.png`
- `torch.png`
- `window.png`
- `coffin.png`
- `bookshelf.png`
- `cobweb.png`
- `blood_splatter.png`

建议：

- 地图类资源最适合买/找“一整套”
- 如果只找单张背景，后续房间扩展会很痛苦
- tileset 的优先级高于静态大背景，因为程序化房间更需要拼接能力

---

### 3. UI 与图标

优先渠道：

- Kenney
- itch.io
- CraftPix
- GameDev Market
- AI 生成后手工统一

推荐关键词：

- `gothic pixel ui`
- `dark fantasy ui pack`
- `vampire game ui`
- `pixel rpg ui`
- `roguelike ui icons`
- `fantasy inventory icons pixel`
- `dark rpg skill icons`
- `pixel weapon icons`
- `pixel potion icon`
- `pixel magic item icons`

项目对应资源：

- `btn_pressed.png`
- `menu_frame.png`
- `hp_bar_bg.png`
- `xp_bar_bg.png`
- `boss_hp_bg.png`
- `boss_hp_fill.png`
- `weapon_slot.png`
- `passive_slot.png`
- `upgrade_card_hover.png`
- `selected_mark.png`
- `star_icon.png`
- `shop_slot.png`
- `price_tag.png`
- `stats_panel.png`
- 被动道具图标一组

建议：

- UI 包可以独立于角色包，但内部必须统一
- 优先补交互状态：normal / hover / pressed / disabled
- 被动道具图标可以用 AI 或图标包快速补齐

---

### 4. 武器与战斗特效

优先渠道：

- OpenGameArt
- itch.io
- Kenney particle packs
- AI 生成概念后手工像素化

推荐关键词：

- `pixel bullet effect`
- `pixel magic projectile`
- `pixel lightning effect`
- `pixel poison cloud`
- `pixel slash effect`
- `pixel explosion spritesheet`
- `pixel hit effect`
- `pixel death explosion`
- `magic orb pixel animation`
- `chain lightning pixel`
- `pixel impact effect`

项目对应资源：

- `bullet.png`
- `shotgun_pellet.png`
- `magic_orb.png`
- `knife.png`
- `poison_cloud.png`
- `lightning_bolt.png`
- `lightning_chain.png`
- `levelup_aura.png`
- `shield_break.png`
- `freeze_effect.png`
- `lifesteal.png`
- `petrify_effect.png`

建议：

- 基础战斗反馈比高级特效更重要
- 命中、死亡、拾取、升级优先于进化大招
- 闪电/毒雾等可以先用 Godot 粒子或 Line2D 程序化实现

---

### 5. 音效与 BGM

优先渠道：

- Kenney
- OpenGameArt
- Pixabay
- Freesound
- Sonniss GDC Free Audio Bundle
- OpenGameArt music loops

推荐关键词：

- `gothic game music loop`
- `dark fantasy battle music loop`
- `vampire castle music`
- `horror organ loop`
- `boss battle orchestral loop`
- `pixel game shoot sound`
- `magic projectile sound`
- `monster death sound`
- `xp pickup sound`
- `level up sound effect`
- `shield break sound`
- `teleport sound effect`
- `ui click sound pack`

项目对应资源：

- `bgm_menu.mp3`
- `bgm_battle1.ogg`
- `bgm_battle2.ogg`
- `bgm_boss.ogg`
- `bgm_shop.ogg`
- `bgm_victory.ogg`
- `bgm_defeat.ogg`
- `sfx_shoot.wav`
- `sfx_shoot_magic.wav`
- `sfx_hit_enemy.wav`
- `sfx_enemy_death.wav`
- `sfx_pickup_xp.wav`
- `sfx_levelup.wav`
- `sfx_player_hurt.wav`
- `sfx_shield_break.wav`
- `sfx_explosion.wav`
- `sfx_teleport.wav`
- `sfx_boss_roar.wav`
- `sfx_click.wav`
- `sfx_hover.wav`
- `sfx_coin.wav`

建议：

- 音效先补全，BGM 后细化
- BGM 必须可循环，优先 `.ogg`
- SFX 可以用 `.wav`，再由 Godot 导入压缩

---

### 6. 字体

优先渠道：

- Google Fonts
- Fontesk
- 1001 Fonts
- DaFont
- itch.io font packs

推荐关键词：

- `free gothic font commercial use`
- `pixel font commercial use`
- `fantasy serif font commercial use`
- `game ui font free commercial`
- `monospace number font free`

项目对应资源：

- `title_font.ttf`
- `main_font.ttf`
- `number_font.ttf`
- `damage_font.ttf`

建议：

- 中文显示优先保证可读性，不要全用哥特字体
- 标题字体可以哥特化，正文必须清晰
- 如果游戏有中文，必须确认字体支持中文字形

---

## 四、AI 生成提示词模板

### 1. 游戏 Logo

```text
Dark gothic pixel art game logo, title "Vampire Hunter", crimson and gold letters, vampire castle silhouette, moonlight, ornate gothic frame, transparent background, high contrast, game UI asset, 2D pixel art style
```

中文说明：

- 用于 `game_logo.png` 的升级版
- 生成后建议手工描边和降色

---

### 2. 主菜单背景

```text
Dark gothic vampire castle interior, top down 2D game background, moonlight through stained glass windows, purple black atmosphere, red carpet, candles, stone floor, pixel art, 16:9 composition, no characters, game menu background
```

适合：

- `menu_bg.png`
- `victory_bg.png`
- `defeat_bg.png`

---

### 3. 地牢房间背景

```text
Top down pixel art gothic dungeon room, stone floor tiles, dark purple shadows, blood stains, candles, coffins, gothic pillars, seamless game room background, 2D roguelite arena, no characters
```

适合：

- `room_square.png`
- 房间背景变体

---

### 4. 被动道具图标

```text
32x32 pixel art icon, dark fantasy roguelite item, black outline, limited palette, transparent background, gothic style, readable silhouette, crimson and gold accent
```

可替换 item 关键词：

- `magnet`
- `energy shield`
- `green regeneration heart`
- `gold greed ring`
- `red berserker blood drop`
- `blue frozen heart`
- `lightning amulet`
- `shadow cloak`

---

### 5. Boss 动作概念

```text
64x64 pixel art vampire lord boss sprite, top down view, dark crimson cape, glowing red eyes, gothic armor, black outline, limited palette, transparent background, action pose for dash attack
```

适合：

- `boss_attack3.png`
- `boss_death.png` 概念参考

---

## 五、推荐执行顺序

### 第 1 批：今天就能找

- Kenney UI / SFX
- itch.io gothic UI
- OpenGameArt dungeon tileset
- OpenGameArt dark fantasy BGM

### 第 2 批：筛选成套包

- 暗黑像素怪物包
- 俯视角地牢 tileset
- 哥特 UI 包

### 第 3 批：AI 补缺

- Logo
- 主菜单背景
- 商店背景
- 结算背景
- 被动图标

### 第 4 批：后期定制

- 主角终版动画
- Boss 终版动画
- 高级敌人终版动画
- 宣传封面

---

## 六、素材登记模板

后续每下载一个素材包，建议登记：

```markdown
## 素材名称

- 来源 URL：
- 作者：
- 授权：
- 是否商用：是/否/待确认
- 是否需要署名：是/否
- 下载日期：
- 用途：
- 放置路径：
- 备注：
```

这样后续发布游戏时不会被授权问题卡住。
