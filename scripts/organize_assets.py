#!/usr/bin/env python3
"""
素材整理脚本：将 assets-downloaded/ 中的原始素材整理到 assets/ 目录。
遵循项目命名规范，优先使用 Kenney CC0 资源保证风格统一。
"""
import os
import shutil
import zipfile
from pathlib import Path
from PIL import Image, ImageEnhance, ImageFilter

ROOT = Path(__file__).parent.parent
SRC = ROOT / "assets-downloaded"
DST = ROOT / "assets"


def ensure_dirs():
    for d in [
        DST / "ui",
        DST / "weapons",
        DST / "effects",
        DST / "tiles" / "props",
        DST / "audio" / "sfx",
        DST / "audio" / "bgm",
        DST / "fonts",
        DST / "sprites" / "enemies",
        DST / "sprites" / "boss",
    ]:
        d.mkdir(parents=True, exist_ok=True)


def copy(src, dst, resize=None, scale=None):
    """复制图片，可选 resize 到 (w,h) 或按 scale 缩放。"""
    if not src.exists():
        print(f"[SKIP] source not found: {src}")
        return False
    im = Image.open(src).convert("RGBA")
    if resize:
        im = im.resize(resize, Image.NEAREST)
    elif scale and scale != 1.0:
        w, h = im.size
        im = im.resize((int(w * scale), int(h * scale)), Image.NEAREST)
    dst.parent.mkdir(parents=True, exist_ok=True)
    im.save(dst)
    print(f"[COPY] {src} -> {dst} ({im.size})")
    return True


def darken(src, dst, factor=0.7):
    """降低亮度生成按下态等。"""
    if not src.exists():
        return False
    im = Image.open(src).convert("RGBA")
    enhancer = ImageEnhance.Brightness(im)
    im = enhancer.enhance(factor)
    im.save(dst)
    print(f"[DARKEN] {src} -> {dst}")
    return True


def add_border_glow(src, dst, color=(255, 215, 0, 255), thickness=4):
    """给图片加金色边框高亮。"""
    if not src.exists():
        return False
    im = Image.open(src).convert("RGBA")
    w, h = im.size
    new = Image.new("RGBA", (w + thickness * 2, h + thickness * 2), (0, 0, 0, 0))
    new.paste(im, (thickness, thickness), im)
    # 绘制边框
    for i in range(thickness):
        alpha = int(255 * (i + 1) / thickness)
        c = (*color[:3], alpha)
        for x in range(new.size[0]):
            new.putpixel((x, i), c)
            new.putpixel((x, new.size[1] - 1 - i), c)
        for y in range(new.size[1]):
            new.putpixel((i, y), c)
            new.putpixel((new.size[0] - 1 - i, y), c)
    new.save(dst)
    print(f"[GLOW] {src} -> {dst}")
    return True


def solid_image(dst, size, color):
    im = Image.new("RGBA", size, color)
    im.save(dst)
    print(f"[SOLID] {dst}")


def process_ui():
    print("\n=== UI ===")
    # 1. 从现有素材派生
    darken(DST / "ui/btn_hover.png", DST / "ui/btn_pressed.png", factor=0.6)
    add_border_glow(DST / "ui/upgrade_card.png", DST / "ui/upgrade_card_hover.png", thickness=6)

    # 血条/经验条背景：用黑色填充，尺寸与现有边框一致
    for bar_bg, bar_border in [
        ("hp_bar_bg.png", "hp_bar_border.png"),
        ("xp_bar_bg.png", "hp_bar_border.png"),
    ]:
        src = DST / "ui" / bar_border
        if src.exists():
            im = Image.open(src).convert("RGBA")
            bg = Image.new("RGBA", im.size, (0, 0, 0, 200))
            bg.save(DST / "ui" / bar_bg)
            print(f"[BAR_BG] {DST / 'ui' / bar_bg}")

    # 2. 从 Kenney UI Pack 复制（Grey/Red 主题更适配暗黑哥特）
    k_ui = SRC / "ui/kenney_ui-pack/PNG"
    theme = "Red"  # 与项目深红主题一致

    # 武器槽 / 被动槽
    copy(k_ui / theme / "Default/button_square_flat.png", DST / "ui/weapon_slot.png", resize=(48, 48))
    copy(k_ui / theme / "Default/button_square_flat.png", DST / "ui/passive_slot.png", resize=(40, 40))

    # Boss 血条背景与填充
    boss_bar_bg = Image.new("RGBA", (600, 32), (20, 0, 0, 255))
    boss_bar_bg.save(DST / "ui/boss_hp_bg.png")
    boss_bar_fill = Image.new("RGBA", (596, 28), (139, 0, 0, 255))
    boss_bar_fill.save(DST / "ui/boss_hp_fill.png")
    print("[BOSS_BAR] generated")

    # 商店格子 / 价格标签
    copy(k_ui / theme / "Default/button_rectangle_flat.png", DST / "ui/shop_slot.png", resize=(120, 120))
    price = Image.new("RGBA", (80, 30), (60, 50, 30, 230))
    price.save(DST / "ui/price_tag.png")
    print("[PRICE_TAG] generated")

    sold = Image.new("RGBA", (120, 120), (0, 0, 0, 160))
    sold.save(DST / "ui/sold_out.png")
    print("[SOLD_OUT] generated")

    # 波次数字背景
    wave_bg = Image.new("RGBA", (80, 40), (40, 0, 0, 200))
    wave_bg.save(DST / "ui/wave_number_bg.png")
    print("[WAVE_BG] generated")

    # 暂停按钮 / 选中标记 / 星标
    k_icons = SRC / "weapons/kenney_game-icons/PNG/Black/1x"
    copy(k_icons / "pause.png", DST / "ui/btn_pause.png", resize=(48, 48))
    copy(k_icons / "checkmark.png", DST / "ui/selected_mark.png", resize=(40, 40))
    copy(SRC / "ui/kenney_ui-pack/PNG/Yellow/Default/star.png", DST / "ui/star_icon.png", resize=(16, 16))
    copy(SRC / "ui/kenney_ui-pack/PNG/Yellow/Default/star.png", DST / "ui/star_gold.png", resize=(48, 48))
    copy(SRC / "ui/kenney_ui-pack/PNG/Grey/Default/star_outline.png", DST / "ui/star_gray.png", resize=(48, 48))

    # 统计面板
    stats = Image.new("RGBA", (600, 400), (20, 10, 20, 230))
    stats.save(DST / "ui/stats_panel.png")
    print("[STATS_PANEL] generated")

    # 成就图标
    copy(k_icons / "medal1.png", DST / "ui/achievement_icon.png", resize=(64, 64))

    # 进化光效占位
    glow = Image.new("RGBA", (200, 200), (0, 0, 0, 0))
    # 金色径向渐变模拟
    for r in range(100, 0, -5):
        alpha = int(30 * (r / 100))
        for x in range(200):
            for y in range(200):
                if (x - 100) ** 2 + (y - 100) ** 2 <= r ** 2:
                    glow.putpixel((x, y), (255, 215, 0, alpha))
    glow.save(DST / "ui/evolution_glow.png")
    print("[EVOLUTION_GLOW] generated")


def process_weapons():
    print("\n=== Weapons / Items ===")
    rpg = SRC / "weapons/rpg_inventory/RPG Inventory"
    gems = sorted((rpg / "Crafting").glob("Gem_*.png"))

    # 经验宝石：从已有大宝石缩放，或从 RPG gem 生成
    existing_gem = DST / "weapons/xp_gem_large.png"
    if existing_gem.exists():
        copy(existing_gem, DST / "weapons/xp_gem_medium.png", resize=(12, 12))
        copy(existing_gem, DST / "weapons/xp_gem_small.png", resize=(8, 8))
    elif gems:
        copy(gems[0], DST / "weapons/xp_gem_large.png", resize=(16, 16))
        copy(gems[1], DST / "weapons/xp_gem_medium.png", resize=(12, 12))
        copy(gems[2], DST / "weapons/xp_gem_small.png", resize=(8, 8))

    # 血晶：红色 gem
    if gems:
        copy(gems[0], DST / "weapons/blood_crystal.png", resize=(24, 24))

    # 传送门：从 teleporter 特效
    portal_src = SRC / "effects/teleporter_01.png"
    if portal_src.exists():
        copy(portal_src, DST / "weapons/portal.png", resize=(48, 48))

    # 被动道具图标：从 Kenney game-icons / RPG 装备中选取含义接近的
    k_icons = SRC / "weapons/kenney_game-icons/PNG/Black/1x"
    mappings = {
        "icon_regen.png": rpg / "Potions/PotionHp_Small.png",  # 生命恢复
        "icon_greed.png": k_icons / "medal2.png",               # 贪婪戒指
        "icon_berserker.png": rpg / "Potions/PotionHp_Big.png", # 狂战士之血（红色大药水）
        "icon_lightning_shield.png": k_icons / "power.png",      # 闪电护符
        "icon_shadow.png": k_icons / "exitRight.png",            # 影子披风
    }
    for name, src in mappings.items():
        copy(src, DST / "weapons" / name, resize=(32, 32))

    # 冰冻之心：火焰改蓝
    frozen = Image.open(SRC / "effects/kenney_particle-pack/PNG (Transparent)/flame_01.png").convert("RGBA").resize((32, 32), Image.NEAREST)
    r, g, b, a = frozen.split()
    frozen = Image.merge("RGBA", (b, g, r, a))
    frozen.save(DST / "weapons/icon_frozen.png")
    print("[FROZEN] flame tinted blue")

    # 武器飞行体
    copy(SRC / "effects/kenney_particle-pack/PNG (Transparent)/muzzle_01.png", DST / "weapons/bullet.png", resize=(8, 8))
    copy(SRC / "effects/kenney_particle-pack/PNG (Transparent)/magic_01.png", DST / "weapons/magic_orb.png", resize=(16, 16))

    # 飞刀：从 Kenney slash 旋转
    knife = Image.open(SRC / "effects/kenney_particle-pack/PNG (Transparent)/slash_01.png").convert("RGBA")
    knife = knife.resize((12, 6), Image.NEAREST)
    knife.save(DST / "weapons/knife.png")
    print(f"[KNIFE] {DST / 'weapons/knife.png'}")


def process_effects():
    print("\n=== Effects ===")
    kp = SRC / "effects/kenney_particle-pack/PNG (Transparent)"

    # 升级光环：金色 star + circle 组合，简单占位
    aura = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    star = Image.open(kp / "star_01.png").convert("RGBA").resize((128, 128), Image.NEAREST)
    aura.paste(star, (0, 0), star)
    aura.save(DST / "effects/levelup_aura.png")
    print("[LEVELUP_AURA]")

    # 拾取经验
    xp = Image.open(kp / "light_01.png").convert("RGBA").resize((48, 48), Image.NEAREST)
    xp.save(DST / "effects/xp_collect.png")
    print("[XP_COLLECT]")

    # 护盾破裂
    copy(kp / "slash_01.png", DST / "effects/shield_break.png", resize=(64, 64))

    # 子弹轨迹
    trail = Image.new("RGBA", (16, 4), (255, 255, 0, 200))
    trail.save(DST / "effects/bullet_trail.png")
    print("[BULLET_TRAIL]")

    # 魔法轨迹
    copy(kp / "magic_01.png", DST / "effects/magic_trail.png", resize=(24, 8))

    # 飞刀旋转
    copy(kp / "slash_01.png", DST / "effects/knife_spin.png", resize=(24, 24))

    # 冻结 / 闪电 / 吸血 / 石化 占位
    freeze = Image.open(kp / "flame_01.png").convert("RGBA").resize((48, 48), Image.NEAREST)
    # 将火焰改为冰蓝色
    r, g, b, a = freeze.split()
    freeze = Image.merge("RGBA", (b, g, r, a))
    freeze.save(DST / "effects/freeze_effect.png")
    print("[FREEZE_EFFECT] flame tinted blue")

    copy(kp / "spark_01.png", DST / "effects/lightning_retaliate.png", resize=(64, 64))

    # 吸血：使用红色烟雾/血迹风格
    lifesteal_src = SRC / "effects/blood_hit_01.png"
    if not lifesteal_src.exists():
        lifesteal_src = kp / "smoke_01.png"
    copy(lifesteal_src, DST / "effects/lifesteal.png", resize=(32, 32))

    copy(kp / "scorch_01.png", DST / "effects/petrify_effect.png", resize=(48, 48))

    # 闪避残影：灰色 slash
    dodge = Image.open(kp / "slash_01.png").convert("RGBA").resize((32, 32), Image.NEAREST)
    r, g, b, a = dodge.split()
    gray = Image.merge("RGBA", (g, g, g, a))
    gray.save(DST / "effects/dodge_afterimage.png")
    print("[DODGE] gray slash")

    # UI 特效
    copy(kp / "circle_01.png", DST / "effects/btn_click.png", resize=(64, 64))
    copy(kp / "star_01.png", DST / "effects/achievement_unlock.png", resize=(128, 128))

    # 伤害数字精灵表：简单生成 0-9
    # 这里仅作占位，实际需美术字
    dmg = Image.new("RGBA", (160, 32), (0, 0, 0, 0))
    dmg.save(DST / "effects/damage_numbers.png")
    print("[DAMAGE_NUMBERS] placeholder")


def process_tiles():
    print("\n=== Tiles ===")
    # 从 Kenney roguelike RPG pack spritesheet 切片
    sheet_path = SRC / "tiles/kenney_roguelike-rpg-pack/Spritesheet/roguelikeSheet_transparent.png"
    if sheet_path.exists():
        sheet = Image.open(sheet_path).convert("RGBA")
        tile_size = 16
        margin = 1

        def get_tile(row, col):
            x = col * (tile_size + margin)
            y = row * (tile_size + margin)
            return sheet.crop((x, y, x + tile_size, y + tile_size))

        # 选取常见地牢瓦片（第 0 行附近），统一放大到 32x32
        def save_tile(tile, path, size):
            tile = tile.resize((size, size), Image.NEAREST)
            tile.save(path)
            print(f"[TILE] {path} ({size}x{size})")

        save_tile(get_tile(0, 7), DST / "tiles/tile_floor.png", 32)
        save_tile(get_tile(1, 7), DST / "tiles/tile_floor_var1.png", 32)
        save_tile(get_tile(2, 7), DST / "tiles/tile_floor_var2.png", 32)
        save_tile(get_tile(6, 3), DST / "tiles/tile_wall.png", 32)
        save_tile(get_tile(6, 2), DST / "tiles/tile_wall_corner.png", 32)
        save_tile(get_tile(8, 1), DST / "tiles/tile_pillar.png", 64)
        save_tile(get_tile(8, 4), DST / "tiles/tile_obstacle.png", 64)
        print("[TILES] sliced from Kenney roguelike RPG pack")

    # 装饰物：火炬、血迹等占位
    torch = Image.new("RGBA", (32, 48), (0, 0, 0, 0))
    torch.save(DST / "tiles/props/torch.png")
    window = Image.new("RGBA", (64, 96), (0, 0, 0, 0))
    window.save(DST / "tiles/props/window.png")
    coffin = Image.new("RGBA", (64, 32), (40, 30, 30, 255))
    coffin.save(DST / "tiles/props/coffin.png")
    bookshelf = Image.new("RGBA", (64, 64), (80, 50, 30, 255))
    bookshelf.save(DST / "tiles/props/bookshelf.png")
    cobweb = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    cobweb.save(DST / "tiles/props/cobweb.png")
    blood = Image.new("RGBA", (64, 64), (139, 0, 0, 120))
    blood.save(DST / "tiles/props/blood_splatter.png")
    print("[PROPS] placeholders generated")

    # room_square 背景占位
    room = Image.new("RGBA", (960, 960), (26, 15, 30, 255))
    room.save(DST / "backgrounds/room_square.png")
    print("[ROOM_SQUARE] placeholder generated")


def process_audio():
    print("\n=== Audio ===")
    k_if = SRC / "audio/kenney_interface-sounds/Audio"
    k_im = SRC / "audio/kenney_impact-sounds/Audio"

    mappings = {
        "sfx_click.wav": k_if / "click_001.ogg",
        "sfx_hover.wav": k_if / "select_001.ogg",
        "sfx_levelup.wav": k_if / "confirmation_004.ogg",
        "sfx_pickup_xp.wav": k_if / "drop_001.ogg",
        "sfx_shoot.wav": k_im / "impactMining_001.ogg",
        "sfx_hit_enemy.wav": k_im / "impactGeneric_light_001.ogg",
        "sfx_enemy_death.wav": k_im / "impactPlate_heavy_001.ogg",
        "sfx_player_hurt.wav": k_im / "impactGlass_medium_001.ogg",
        "sfx_shield_break.wav": k_im / "impactGlass_heavy_001.ogg",
        "sfx_explosion.wav": k_im / "impactMetal_heavy_001.ogg",
        "sfx_coin.wav": k_if / "maximize_001.ogg",
    }
    for name, src in mappings.items():
        if src.exists():
            dst = DST / "audio/sfx" / name.replace(".wav", ".ogg")
            shutil.copy2(src, dst)
            print(f"[AUDIO] {src} -> {dst}")

    # 传送音效
    teleport = SRC / "audio/172206__fins__teleport.wav"
    if teleport.exists():
        shutil.copy2(teleport, DST / "audio/sfx/sfx_teleport.wav")
        print("[AUDIO] teleport")

    # BGM（文件名可能被 URL 编码）
    bgm_candidates = [
        SRC / "bgms/demo_Beyond Redemption_master_0.mp3",
        SRC / "bgms/demo_Beyond%20Redemption_master_0.mp3",
    ]
    for bgm in bgm_candidates:
        if bgm.exists():
            shutil.copy2(bgm, DST / "audio/bgm/bgm_menu.ogg")
            print(f"[BGM] menu from {bgm.name}")
            break


def process_fonts():
    print("\n=== Fonts ===")
    font_map = {
        "main_font.ttf": "Noto_Sans_SC.zip",
        "damage_font.ttf": "Bangers.zip",
        "title_font.ttf": "Cinzel.zip",
        "number_font.ttf": "Space_Mono.zip",
    }
    for dst_name, zip_name in font_map.items():
        zip_path = SRC / "fonts" / zip_name
        if not zip_path.exists():
            print(f"[SKIP] font zip not found: {zip_path}")
            continue
        try:
            with zipfile.ZipFile(zip_path, "r") as z:
                ttf_files = [n for n in z.namelist() if n.lower().endswith((".ttf", ".otf"))]
                if not ttf_files:
                    print(f"[SKIP] no font files in {zip_name}")
                    continue
                chosen = ttf_files[0]
                # 优先选 Regular 变体
                for f in ttf_files:
                    if "Regular" in f or "-Regular" in f:
                        chosen = f
                        break
                data = z.read(chosen)
                dst = DST / "fonts" / dst_name
                dst.write_bytes(data)
                print(f"[FONT] {zip_name}/{chosen} -> {dst}")
        except zipfile.BadZipFile:
            print(f"[SKIP] {zip_name} is not a valid zip (download likely failed)")


def process_enemies():
    print("\n=== Enemies / Boss ===")
    # 召唤师：NecroGuy GIF 提取第一帧
    necro_gif = SRC / "sprites/NecroGuy_01.gif"
    if necro_gif.exists():
        im = Image.open(necro_gif)
        im.seek(0)
        im.convert("RGBA").resize((32, 32), Image.NEAREST).save(DST / "sprites/enemies/summoner_cast.png")
        print("[SUMMONER] extracted from gif")

    # 法师
    for mage_name in ["mage.png", "mage_0.png", "mage_2.png", "mage_strip4.png"]:
        src = SRC / "sprites" / mage_name
        if src.exists():
            copy(src, DST / "sprites/enemies/mage_cast.png", resize=(32, 32))
            break

    # 石像鬼
    for g_name in ["gargoyle.png", "gargoyle_0.png"]:
        src = SRC / "sprites" / g_name
        if src.exists():
            copy(src, DST / "sprites/enemies/gargoyle_idle.png", resize=(48, 48))
            break

    # 血族亲王：vampire-f-001
    for v_name in ["vampire-f-001.png", "vampire-m-001.png"]:
        src = SRC / "sprites" / v_name
        if src.exists():
            copy(src, DST / "sprites/enemies/prince_idle.png", resize=(40, 40))
            break

    # 自爆者：从 gothicvania 或 DCSS 风格的怪物中选一个肿胀的
    # 先占位：用 zombie 改色逻辑，这里复制一个普通敌人改名
    zombie = DST / "sprites/enemies/zombie_walk.png"
    if zombie.exists():
        copy(zombie, DST / "sprites/enemies/exploder_walk.png", resize=(28, 28))
        print("[EXPLODER] placeholder from zombie")

    # Boss 冲刺/死亡占位
    boss_idle = DST / "sprites/boss/boss_idle.png"
    if boss_idle.exists():
        copy(boss_idle, DST / "sprites/boss/boss_attack3.png", resize=(64, 64))
        copy(boss_idle, DST / "sprites/boss/boss_death.png", resize=(64, 64))
        print("[BOSS] placeholders generated")


def main():
    ensure_dirs()
    process_ui()
    process_weapons()
    process_effects()
    process_tiles()
    process_audio()
    process_fonts()
    process_enemies()
    print("\nDone. Check assets/ for new files.")


if __name__ == "__main__":
    main()
