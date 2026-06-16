#!/usr/bin/env python3
"""
处理 assets-downloaded/ 中的原始素材：
- 裁切透明边、统一为方形、缩放
- 生成程序化占位特效/UI
- 输出到 assets/ 对应目录
"""
import os
import random
import shutil
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageEnhance

# 固定随机种子，保证每次生成结果一致（便于版本控制）
random.seed(42)

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "assets-downloaded"
DST = ROOT / "assets"


def trim_and_square(img: Image.Image, target: int = 256, pad: int = 8) -> Image.Image:
    """裁切透明边，居中 pad 到正方形，再缩放到 target。"""
    if img.mode != "RGBA":
        img = img.convert("RGBA")
    alpha = img.getchannel("A")
    bbox = alpha.getbbox()
    if bbox:
        img = img.crop(bbox)
    # 保持比例的方形画布
    w, h = img.size
    side = max(w, h) + pad * 2
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    x = (side - w) // 2
    y = (side - h) // 2
    canvas.paste(img, (x, y), img)
    if side != target:
        canvas = canvas.resize((target, target), Image.Resampling.LANCZOS)
    return canvas


def save(img: Image.Image, path: Path):
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, "PNG")
    print(f"Saved {path}")


def process_enemies():
    base = SRC / "sprites" / "freegamesprites"
    out = DST / "sprites" / "enemies"
    mapping = {
        "exploder_walk.png": "infernal-flame-skull.png",
        "gargoyle_idle.png": "brimstone-gargoyle.png",
        "mage_cast.png": "bone-mage-caster.png",
        "summoner_cast.png": "lich-crowned-necromancer.png",
        "prince_idle.png": "vampire-count.webp",
    }
    for out_name, src_name in mapping.items():
        src_path = base / src_name
        if not src_path.exists():
            print(f"MISSING {src_path}")
            continue
        img = Image.open(src_path)
        if src_path.suffix.lower() == ".webp":
            img = img.convert("RGBA")
        img = trim_and_square(img, target=256, pad=8)
        save(img, out / out_name)

    # 精英吸血鬼使用现有吸血鬼贴图（脚本会加发光），无需新建文件
    # 但创建一个精英变体：复制 vampire_idle 并加金色描边/调亮
    vamp_path = DST / "sprites" / "enemies" / "vampire_idle.png"
    if vamp_path.exists():
        img = Image.open(vamp_path).convert("RGBA")
        elite = trim_and_square(img, target=256, pad=0)
        # 轻微金色辉光外描边
        glow = elite.filter(ImageFilter.GaussianBlur(radius=4))
        enh = ImageEnhance.Brightness(glow)
        glow = enh.enhance(1.4)
        # 叠到底层
        comp = Image.new("RGBA", elite.size, (0, 0, 0, 0))
        comp.paste(glow, (0, 0), glow)
        comp.paste(elite, (0, 0), elite)
        save(comp, out / "elite_vampire_idle.png")


def tint(img: Image.Image, color) -> Image.Image:
    """为图像整体着色（保留 alpha）。"""
    color_img = Image.new("RGBA", img.size, color)
    return Image.alpha_composite(color_img, img)


def lerp_color(a, b, t):
    """线性插值两个 (r,g,b) 或 (r,g,b,a) 颜色。"""
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(len(a)))


def colorize_with_lut(img: Image.Image, color_map) -> Image.Image:
    """根据灰度值用 color_map(t) -> (r,g,b) 重着色，保留 alpha。"""
    if img.mode != "RGBA":
        img = img.convert("RGBA")
    gray = img.convert("L")
    lut = [color_map(i / 255.0) for i in range(256)]
    lut_r = [c[0] for c in lut]
    lut_g = [c[1] for c in lut]
    lut_b = [c[2] for c in lut]
    r = gray.point(lut_r, "L")
    g = gray.point(lut_g, "L")
    b = gray.point(lut_b, "L")
    a = img.getchannel("A")
    return Image.merge("RGBA", (r, g, b, a))


def load_or_none(path: Path) -> Image.Image | None:
    if path.exists():
        return Image.open(path).convert("RGBA")
    return None


def generate_effect(name: str, size: int = 128) -> Image.Image:
    """生成简单的程序化特效占位图。"""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    cx, cy = size // 2, size // 2

    if name == "poison_spread":
        for r in range(size // 2, 2, -4):
            alpha = int(180 * (r / (size // 2)))
            draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(50, 200, 50, alpha))
    elif name == "chain_lightning":
        # 几条折线闪电
        for _ in range(3):
            pts = [(0, cy)]
            x = 0
            while x < size:
                x += size // 8
                y = cy + (size // 4 if len(pts) % 2 else -size // 4)
                pts.append((min(x, size), y))
            pts.append((size, cy))
            draw.line(pts, fill=(150, 220, 255, 220), width=3)
    elif name == "holy_light":
        for r in range(size // 2, 4, -6):
            alpha = int(200 * (r / (size // 2)))
            draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(255, 255, 200, alpha))
        draw.polygon([(cx, 0), (cx + 8, cy), (cx, size), (cx - 8, cy)], fill=(255, 255, 240, 180))
    elif name == "knife_tornado":
        for i in range(8):
            angle = i * 45
            draw.regular_polygon((cx, cy, size // 3), n_sides=3, rotation=angle, fill=(200, 200, 220, 180))
    elif name == "thunder_wrath":
        draw.ellipse([0, 0, size, size], fill=(40, 20, 60, 200))
        for _ in range(5):
            pts = [(cx, 0)]
            x, y = cx, 0
            while y < size:
                x += (size // 8) * (1 if _ % 2 else -1)
                y += size // 6
                pts.append((x, y))
            draw.line(pts, fill=(255, 240, 100, 220), width=4)
    elif name == "wave_start":
        draw.rectangle([0, 0, size, size], fill=(20, 0, 0, 180))
        draw.text((cx - 30, cy - 8), "WAVE", fill=(255, 200, 100, 255))
    elif name == "crit_text":
        draw.text((cx - 20, cy - 8), "CRIT", fill=(255, 80, 80, 255))
    elif name == "boss_warning":
        draw.rectangle([0, 0, size, size], fill=(120, 0, 0, 120))
        draw.text((cx - 40, cy - 8), "WARNING", fill=(255, 0, 0, 255))
    elif name == "poison_cloud":
        for r in range(size // 2, 4, -8):
            alpha = int(160 * (r / (size // 2)))
            draw.ellipse([cx - r, cy - r // 2, cx + r, cy + r // 2], fill=(80, 180, 60, alpha))
    elif name == "shotgun_pellet":
        draw.ellipse([cx - 3, cy - 3, cx + 3, cy + 3], fill=(255, 220, 80, 255))
    else:
        draw.ellipse([cx - 10, cy - 10, cx + 10, cy + 10], fill=(255, 255, 255, 255))
    return img


def generate_effects():
    effects = [
        ("poison_spread", 128),
        ("chain_lightning", 256),
        ("holy_light", 128),
        ("knife_tornado", 96),
        ("thunder_wrath", 256),
        ("wave_start", 256),
        ("crit_text", 128),
        ("boss_warning", 256),
    ]
    for name, size in effects:
        img = generate_effect(name, size)
        save(img, DST / "effects" / f"{name}.png")

    # 武器特效
    save(generate_effect("poison_cloud", 128), DST / "weapons" / "poison_cloud.png")
    save(generate_effect("shotgun_pellet", 8), DST / "weapons" / "shotgun_pellet.png")


def generate_ui():
    out = DST / "ui"

    # 商人：使用 spice-merchant 素材
    merchant_src = SRC / "sprites" / "freegamesprites" / "spice-merchant-bearded-robed.png"
    if merchant_src.exists():
        img = Image.open(merchant_src).convert("RGBA")
        img = trim_and_square(img, target=128, pad=4)
        save(img, out / "merchant.png")

    # 暗黑哥特调色盘
    c_dark = (12, 4, 5)
    c_mid = (80, 18, 20)
    c_light = (160, 45, 45)
    c_hover_mid = (120, 35, 35)
    c_hover_light = (210, 70, 70)
    c_pressed_dark = (8, 2, 3)
    c_pressed_light = (70, 15, 15)
    c_gold = (201, 162, 39)
    c_gold_dark = (110, 82, 18)
    c_panel = (20, 14, 16)
    c_panel_dark = (10, 7, 8)
    c_panel_light = (45, 30, 35)

    # 基于 Kenney Red 按钮生成按钮三种状态
    k_base = SRC / "ui" / "kenney_ui-pack" / "PNG" / "Red" / "Default"
    btn_files = {
        "normal": "button_rectangle_depth_flat.png",
        "hover": "button_rectangle_depth_gloss.png",
        "pressed": "button_rectangle_depth_border.png",
    }
    btn_maps = {
        "normal": lambda t: lerp_color(c_dark, c_mid, t),
        "hover": lambda t: lerp_color(c_mid, c_hover_light, t),
        "pressed": lambda t: lerp_color(c_pressed_dark, c_pressed_light, t),
    }
    for state, src_name in btn_files.items():
        src = k_base / src_name
        if src.exists():
            img = load_or_none(src)
            if img:
                img = colorize_with_lut(img, btn_maps[state])
                save(img, out / f"btn_{state}.png")

    # 武器/被动槽位：基于 Kenney 方形按钮
    slot_src = k_base / "button_square_depth_flat.png"
    if slot_src.exists():
        base = load_or_none(slot_src)
        if base:
            slot = colorize_with_lut(
                base,
                lambda t: lerp_color((8, 3, 4), (60, 18, 20), t),
            )
            slot = slot.resize((48, 48), Image.Resampling.LANCZOS)
            save(slot, out / "weapon_slot.png")
            save(slot.copy(), out / "passive_slot.png")

    # 暂停按钮/选中标记：基于现有图标素材做金色调色
    for src_name, dst_name, low, high in [
        ("btn_pause.png", "btn_pause.png", (20, 15, 10), c_gold),
        ("selected_mark.png", "selected_mark.png", (30, 25, 15), c_gold),
    ]:
        src = out / src_name
        if src.exists():
            img = load_or_none(src)
            if img:
                img = colorize_with_lut(img, lambda t: lerp_color(low, high, t))
                save(img, out / dst_name)

    # 商店格子
    shop = Image.new("RGBA", (160, 48), (0, 0, 0, 0))
    d = ImageDraw.Draw(shop)
    d.rounded_rectangle([0, 0, 159, 47], radius=6, fill=c_panel, outline=c_mid, width=2)
    d.rounded_rectangle([2, 2, 157, 45], radius=5, outline=c_gold_dark, width=1)
    save(shop, out / "shop_slot.png")

    # 价格标签 / 售罄标签
    def make_tag(w, h, fill, stroke, text_color=None):
        tag = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        td = ImageDraw.Draw(tag)
        td.rounded_rectangle([0, 0, w - 1, h - 1], radius=4, fill=fill, outline=stroke, width=2)
        return tag

    save(make_tag(64, 24, (30, 22, 10), c_gold_dark), out / "price_tag.png")
    save(make_tag(64, 24, (25, 25, 25), (80, 80, 80)), out / "sold_out.png")

    # 波次数字背景
    wave_bg = Image.new("RGBA", (96, 32), (0, 0, 0, 0))
    wd = ImageDraw.Draw(wave_bg)
    wd.rounded_rectangle([0, 0, 95, 31], radius=6, fill=c_panel, outline=c_gold_dark, width=2)
    save(wave_bg, out / "wave_number_bg.png")

    # 升级卡片
    def make_card(w, h, hover=False):
        card = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        draw = ImageDraw.Draw(card)
        fill = c_panel
        outer = c_mid
        inner = c_gold_dark
        if hover:
            fill = (35, 20, 22)
            outer = c_light
            inner = c_gold
        draw.rounded_rectangle([0, 0, w - 1, h - 1], radius=10, fill=fill, outline=outer, width=3)
        draw.rounded_rectangle([4, 4, w - 5, h - 5], radius=8, outline=inner, width=2)
        # 顶部高光
        draw.line([(10, 5), (w - 10, 5)], fill=(255, 255, 255, 30), width=1)
        if hover:
            # 金色内发光边框
            glow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
            gd = ImageDraw.Draw(glow)
            gd.rounded_rectangle([2, 2, w - 3, h - 3], radius=9, outline=(*c_gold, 90), width=4)
            card = Image.alpha_composite(card, glow)
        return card

    save(make_card(200, 160, hover=False), out / "upgrade_card.png")
    save(make_card(200, 160, hover=True), out / "upgrade_card_hover.png")

    # 统计面板 / 设置面板
    panel = Image.new("RGBA", (400, 300), (0, 0, 0, 0))
    pd = ImageDraw.Draw(panel)
    pd.rounded_rectangle([0, 0, 399, 299], radius=12, fill=c_panel_dark, outline=c_mid, width=4)
    pd.rounded_rectangle([5, 5, 394, 294], radius=10, outline=c_gold_dark, width=2)
    # 标题栏
    pd.rounded_rectangle([5, 5, 394, 45], radius=10, fill=(30, 15, 18))
    pd.line([(5, 45), (394, 45)], fill=c_mid, width=2)
    save(panel, out / "stats_panel.png")

    # 菜单边框
    frame = Image.new("RGBA", (640, 480), (0, 0, 0, 0))
    fd = ImageDraw.Draw(frame)
    fd.rounded_rectangle([0, 0, 639, 479], radius=16, outline=c_mid, width=6)
    fd.rounded_rectangle([8, 8, 631, 471], radius=14, outline=c_gold, width=2)
    # 四角装饰块
    corner = 24
    for x, y in [(0, 0), (640 - corner, 0), (0, 480 - corner), (640 - corner, 480 - corner)]:
        fd.rectangle([x, y, x + corner, y + corner], outline=c_gold, width=2)
    save(frame, out / "menu_frame.png")

    # 血条 / 经验条 / Boss 血条
    def make_bar(w, h, bg_color, fill_gradient, border_color):
        bg = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        d = ImageDraw.Draw(bg)
        d.rounded_rectangle([0, 0, w - 1, h - 1], radius=h // 2, fill=bg_color, outline=border_color, width=2)
        fill = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        fd = ImageDraw.Draw(fill)
        for x in range(w):
            t = x / max(1, w - 1)
            color = lerp_color(fill_gradient[0], fill_gradient[1], t)
            fd.line([(x, 2), (x, h - 3)], fill=color)
        return bg, fill

    hp_bg, hp_fill = make_bar(128, 16, c_panel_dark, (c_mid, c_light), c_mid)
    save(hp_bg, out / "hp_bar_bg.png")
    save(hp_fill, out / "hp_bar_fill.png")

    xp_bg, xp_fill = make_bar(128, 16, c_panel_dark, ((50, 30, 70), c_gold), (80, 50, 90))
    save(xp_bg, out / "xp_bar_bg.png")
    save(xp_fill, out / "xp_bar_fill.png")

    boss_bg, boss_fill = make_bar(256, 20, c_panel_dark, ((80, 10, 12), (200, 30, 30)), c_mid)
    save(boss_bg, out / "boss_hp_bg.png")
    save(boss_fill, out / "boss_hp_fill.png")

    # 胜利/失败背景
    def make_background(name, base_top, base_bot, accent, rays=True):
        bg = Image.new("RGBA", (1280, 720))
        pixels = bg.load()
        for y in range(720):
            t = y / 719
            color = lerp_color(base_top, base_bot, t)
            for x in range(1280):
                pixels[x, y] = color
        draw = ImageDraw.Draw(bg)
        if rays:
            cx, cy = 640, 360
            for angle in range(0, 360, 10):
                import math
                rad = math.radians(angle)
                x2 = int(cx + math.cos(rad) * 900)
                y2 = int(cy + math.sin(rad) * 700)
                draw.line([(cx, cy), (x2, y2)], fill=(*accent, 18), width=8)
        # 装饰性边框
        draw.rectangle([30, 30, 1250, 690], outline=(*accent, 160), width=6)
        draw.rectangle([44, 44, 1236, 676], outline=(*accent, 80), width=2)
        # 底部暗角遮罩
        vignette = Image.new("RGBA", (1280, 720), (0, 0, 0, 0))
        vd = ImageDraw.Draw(vignette)
        for i in range(120):
            alpha = int(180 * (i / 120))
            vd.rectangle([i, i, 1280 - i, 720 - i], outline=(0, 0, 0, alpha), width=1)
        bg = Image.alpha_composite(bg, vignette)
        save(bg, out / f"{name}.png")

    make_background("victory_bg", (15, 12, 25), (40, 20, 20), c_gold, rays=True)
    make_background("defeat_bg", (30, 8, 8), (10, 5, 5), (200, 40, 40), rays=False)


def copy_bgm():
    audio_src = SRC / "audio" / "oga"
    bgm_dst = DST / "audio" / "bgm"
    bgm_dst.mkdir(parents=True, exist_ok=True)
    copies = [
        ("battle_theme_a.mp3", "bgm_battle.mp3"),
        ("basilisk_boss.ogg", "bgm_boss.ogg"),
        ("ForgottenVictory.ogg", "bgm_victory.ogg"),
        ("WhatIsLeft_0.mp3", "bgm_defeat.mp3"),
        ("Tavern_0.ogg", "bgm_shop.ogg"),
    ]
    for src_name, dst_name in copies:
        src = audio_src / src_name
        dst = bgm_dst / dst_name
        if src.exists():
            dst.write_bytes(src.read_bytes())
            print(f"Copied {src} -> {dst}")


def copy_sfx():
    """从 Kenney 音效包中挑选并复制战斗/受击/技能音效。"""
    sfx_dst = DST / "audio" / "sfx"
    sfx_dst.mkdir(parents=True, exist_ok=True)
    mapping = {
        # 武器射击
        "kenney_sci-fi-sounds/Audio/laserSmall_000.ogg": "sfx_shoot.ogg",
        "kenney_sci-fi-sounds/Audio/explosionCrunch_000.ogg": "sfx_shoot_shotgun.ogg",
        "kenney_sci-fi-sounds/Audio/forceField_000.ogg": "sfx_shoot_magic.ogg",
        "kenney_rpg-audio/Audio/knifeSlice.ogg": "sfx_knife_throw.ogg",
        "kenney_sci-fi-sounds/Audio/slime_000.ogg": "sfx_poison_cloud.ogg",
        "kenney_sci-fi-sounds/Audio/laserRetro_000.ogg": "sfx_lightning_chain.ogg",
        # Boss / 受击 / 死亡
        "kenney_sci-fi-sounds/Audio/lowFrequency_explosion_000.ogg": "sfx_boss_attack.ogg",
        "kenney_impact-sounds/Audio/impactGlass_medium_000.ogg": "sfx_player_hurt.ogg",
        "kenney_impact-sounds/Audio/impactMetal_medium_000.ogg": "sfx_hit_enemy.ogg",
        "kenney_impact-sounds/Audio/impactBell_heavy_000.ogg": "sfx_enemy_death.ogg",
        "kenney_sci-fi-sounds/Audio/explosionCrunch_002.ogg": "sfx_explosion.ogg",
    }
    for src_rel, dst_name in mapping.items():
        src = SRC / "audio" / src_rel
        dst = sfx_dst / dst_name
        if src.exists():
            shutil.copy2(src, dst)
            print(f"Copied {src} -> {dst}")


def desaturate(img: Image.Image, factor: float = 1.0) -> Image.Image:
    """去饱和图像，factor=1 完全灰度。"""
    gray = img.convert("L").convert("RGBA")
    return Image.blend(img, gray, factor)


def add_glow(img: Image.Image, color: tuple, radius: int = 8, intensity: float = 0.6) -> Image.Image:
    """为图像添加单色外发光/内发光。"""
    glow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    alpha = img.getchannel("A")
    colored = Image.new("RGBA", img.size, color)
    glow.paste(colored, (0, 0), alpha)
    glow = glow.filter(ImageFilter.GaussianBlur(radius=radius))
    enh = ImageEnhance.Brightness(glow)
    glow = enh.enhance(intensity)
    comp = Image.alpha_composite(glow, img)
    return comp


def motion_blur(img: Image.Image, direction: tuple = (1, 0), distance: int = 16) -> Image.Image:
    """简单的方向运动模糊。"""
    if "MotionBlur" in dir(ImageFilter):
        return img.filter(ImageFilter.MotionBlur(int(distance), direction))
    # fallback：偏移叠加
    dx, dy = direction
    base = Image.new("RGBA", img.size, (0, 0, 0, 0))
    steps = max(2, distance // 2)
    for i in range(steps):
        offset = (dx * i, dy * i)
        layer = img.copy()
        alpha = layer.getchannel("A").point(lambda a: int(a * 0.3))
        layer.putalpha(alpha)
        base = Image.alpha_composite(base, layer.transform(img.size, Image.Transform.AFFINE, (1, 0, -offset[0], 0, 1, -offset[1])))
    base = Image.alpha_composite(base, img)
    return base


def generate_enemy_states():
    """从现有敌人贴图派生缺失的状态贴图（爆炸、石化、瞬移、冲刺、狂暴等）。"""
    enemies = DST / "sprites" / "enemies"
    boss = DST / "sprites" / "boss"

    # 自爆者爆炸：walk + 红色发光/膨胀
    exploder = Image.open(enemies / "exploder_walk.png").convert("RGBA")
    explode = add_glow(exploder, (255, 60, 0), radius=12, intensity=1.2)
    explode = explode.resize((280, 280), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
    canvas.paste(explode, (-12, -12), explode)
    save(canvas, enemies / "exploder_explode.png")

    # 法师瞬移：cast + 紫色透明残影
    mage = Image.open(enemies / "mage_cast.png").convert("RGBA")
    alpha = mage.getchannel("A").point(lambda a: int(a * 0.55))
    mage.putalpha(alpha)
    mage_teleport = tint(mage, (80, 20, 120, 80))
    mage_teleport = add_glow(mage_teleport, (120, 40, 200), radius=10, intensity=0.7)
    save(mage_teleport, enemies / "mage_teleport.png")

    # 石像鬼石化：idle 去饱和 + 石质纹理
    gargoyle = Image.open(enemies / "gargoyle_idle.png").convert("RGBA")
    petrify = desaturate(gargoyle, 0.9)
    # 添加轻微石裂缝：随机深色线条
    draw = ImageDraw.Draw(petrify)
    for i in range(6):
        x1, y1 = 40 + i * 30, 50 + (i % 3) * 60
        x2, y2 = x1 + 20, y1 + 30
        draw.line([(x1, y1), (x2, y2)], fill=(40, 40, 40, 160), width=2)
    save(petrify, enemies / "gargoyle_petrify.png")

    # 石像鬼苏醒：石化版 + 金色裂纹
    wake = petrify.copy()
    draw = ImageDraw.Draw(wake)
    for i in range(8):
        x1, y1 = 30 + i * 28, 40 + (i % 4) * 50
        x2, y2 = x1 + 25, y1 + 35
        draw.line([(x1, y1), (x2, y2)], fill=(201, 162, 39, 200), width=2)
    save(wake, enemies / "gargoyle_wake.png")

    # 血族亲王冲刺：idle + 红色运动模糊
    prince = Image.open(enemies / "prince_idle.png").convert("RGBA")
    prince_dash = motion_blur(prince, (1, 0), 20)
    prince_dash = tint(prince_dash, (180, 40, 40, 60))
    prince_dash = add_glow(prince_dash, (200, 40, 40), radius=8, intensity=0.6)
    save(prince_dash, enemies / "prince_dash.png")

    # 血族亲王狂暴：idle + 红色发光
    prince_rage = add_glow(prince, (220, 30, 30), radius=14, intensity=1.0)
    prince_rage = tint(prince_rage, (255, 60, 60, 40))
    save(prince_rage, enemies / "prince_rage.png")

    # Boss 冲刺：idle + 红色残影
    boss_idle = Image.open(boss / "boss_idle.png").convert("RGBA")
    boss_dash = motion_blur(boss_idle, (1, 0), 40)
    boss_dash = tint(boss_dash, (220, 40, 40, 80))
    boss_dash = add_glow(boss_dash, (255, 50, 50), radius=16, intensity=0.7)
    save(boss_dash, boss / "boss_attack3.png")

    # Boss 死亡：idle 变暗 + 红色崩解
    boss_death = desaturate(boss_idle, 0.6)
    boss_death = tint(boss_death, (80, 0, 0, 100))
    boss_death = add_glow(boss_death, (200, 0, 0), radius=20, intensity=0.8)
    save(boss_death, boss / "boss_death.png")


# ===== 房间瓦片与装饰物 =====

ROOM_THEMES: dict = {
    "dungeon": {
        "base": (45, 42, 48),
        "highlight": (70, 66, 74),
        "shadow": (28, 26, 30),
        "accent": (90, 30, 30),
    },
    "castle": {
        "base": (55, 45, 45),
        "highlight": (85, 70, 68),
        "shadow": (35, 28, 28),
        "accent": (120, 50, 45),
    },
    "cave": {
        "base": (48, 40, 35),
        "highlight": (75, 62, 52),
        "shadow": (28, 22, 18),
        "accent": (65, 50, 40),
    },
    "boss": {
        "base": (35, 25, 30),
        "highlight": (65, 45, 50),
        "shadow": (20, 14, 16),
        "accent": (140, 25, 25),
    },
}


def _clamp_color(c: tuple) -> tuple:
    return tuple(max(0, min(255, v)) for v in c)


def _vary_color(base: tuple, delta: int = 12) -> tuple:
    return _clamp_color(tuple(v + random.randint(-delta, delta) for v in base))


def _generate_wall_tile(theme: str, colors: dict, out: Path) -> None:
    """生成水平墙壁条带纹理（128x32，可横向拉伸或平铺）。"""
    w, h = 128, 32
    img = Image.new("RGBA", (w, h))
    draw = ImageDraw.Draw(img)
    base = colors["base"]
    highlight = colors["highlight"]
    shadow = colors["shadow"]
    accent = colors["accent"]

    brick_h = 10
    cols = 4
    for row in range(h // brick_h):
        y = row * brick_h
        offset = (row % 2) * (w // (cols * 2))
        for col in range(-1, cols + 1):
            bx = col * (w // cols) + offset
            fill = _vary_color(base, 10)
            draw.rectangle(
                [bx, y, bx + w // cols - 1, y + brick_h - 1],
                fill=fill,
                outline=shadow,
                width=1,
            )
            draw.line([(bx, y), (bx + w // cols - 1, y)], fill=highlight, width=1)

    # 裂缝 / 血迹
    for _ in range(4):
        x1 = random.randint(0, w - 1)
        y1 = random.randint(0, h - 1)
        pts = [(x1, y1)]
        for _ in range(2):
            pts.append((pts[-1][0] + random.randint(-14, 14), pts[-1][1] + random.randint(-6, 6)))
        draw.line(pts, fill=(*accent, 130), width=1)

    save(img, out / f"wall_{theme}.png")
    vertical = img.rotate(90, expand=True)
    save(vertical, out / f"wall_{theme}_v.png")


def _generate_pillar_tile(theme: str, colors: dict, out: Path) -> None:
    """生成方形柱子纹理 48x48。"""
    size = 48
    img = Image.new("RGBA", (size, size))
    draw = ImageDraw.Draw(img)
    base = colors["base"]
    highlight = colors["highlight"]
    shadow = colors["shadow"]
    accent = colors["accent"]

    margin = 4
    body = _vary_color(base, 8)
    draw.rectangle(
        [margin, margin, size - margin, size - margin],
        fill=body,
        outline=shadow,
        width=2,
    )
    draw.line([(margin, margin), (size - margin, margin)], fill=highlight, width=2)
    draw.line([(margin, margin), (margin, size - margin)], fill=highlight, width=2)

    for _ in range(2):
        x1 = random.randint(margin + 6, size - margin - 6)
        y1 = random.randint(margin + 6, size - margin - 6)
        draw.line(
            [(x1, y1), (x1 + random.randint(-8, 8), y1 + random.randint(-8, 8))],
            fill=(*accent, 150),
            width=1,
        )

    save(img, out / f"pillar_{theme}.png")


def _generate_floor_tile(theme: str, colors: dict, out: Path) -> None:
    """生成可平铺地板细节纹理 128x128。"""
    size = 128
    img = Image.new("RGBA", (size, size))
    draw = ImageDraw.Draw(img)
    base = colors["base"]
    shadow = colors["shadow"]
    accent = colors["accent"]

    draw.rectangle([0, 0, size, size], fill=base)

    tile_size = 32
    for y in range(0, size, tile_size):
        for x in range(0, size, tile_size):
            fill = _vary_color(base, 15)
            draw.rectangle([x, y, x + tile_size - 1, y + tile_size - 1], fill=fill, outline=shadow, width=1)

    for _ in range(6):
        x1 = random.randint(0, size - 1)
        y1 = random.randint(0, size - 1)
        pts = [(x1, y1)]
        for _ in range(3):
            pts.append((pts[-1][0] + random.randint(-18, 18), pts[-1][1] + random.randint(-18, 18)))
        draw.line(pts, fill=(*accent, 70), width=1)

    save(img, out / f"floor_{theme}.png")


def _generate_props(out: Path) -> None:
    """生成环境装饰物精灵图。"""
    out.mkdir(parents=True, exist_ok=True)

    # 火把
    torch = Image.new("RGBA", (24, 48))
    d = ImageDraw.Draw(torch)
    d.rectangle([6, 20, 18, 26], fill=(55, 40, 30))
    d.rectangle([4, 14, 20, 20], fill=(75, 55, 40))
    d.ellipse([5, 0, 19, 16], fill=(230, 90, 15))
    d.ellipse([8, 2, 16, 11], fill=(255, 230, 80))
    save(torch, out / "torch.png")

    # 棺材
    coffin = Image.new("RGBA", (40, 64))
    d = ImageDraw.Draw(coffin)
    d.rounded_rectangle([2, 0, 38, 63], radius=7, fill=(48, 38, 33), outline=(28, 20, 16), width=2)
    d.line([(20, 4), (20, 58)], fill=(68, 52, 42), width=2)
    d.line([(7, 18), (33, 18)], fill=(68, 52, 42), width=2)
    d.line([(7, 48), (33, 48)], fill=(68, 52, 42), width=2)
    save(coffin, out / "coffin.png")

    # 书架
    shelf = Image.new("RGBA", (48, 56))
    d = ImageDraw.Draw(shelf)
    d.rectangle([0, 0, 47, 55], fill=(52, 32, 22), outline=(28, 16, 10), width=2)
    for y in [14, 28, 42]:
        d.line([(2, y), (45, y)], fill=(32, 18, 10), width=2)
    book_colors = [(120, 40, 40), (40, 60, 90), (80, 80, 40), (90, 40, 80)]
    for y in [4, 18, 32]:
        x = 4
        for c in book_colors:
            w = random.randint(5, 9)
            d.rectangle([x, y, x + w, y + 10], fill=c)
            x += w + 1
    save(shelf, out / "bookshelf.png")

    # 雕像
    statue = Image.new("RGBA", (40, 56))
    d = ImageDraw.Draw(statue)
    d.rectangle([10, 40, 30, 55], fill=(92, 92, 98), outline=(52, 52, 58), width=2)
    d.ellipse([10, 6, 30, 28], fill=(112, 112, 118), outline=(62, 62, 68), width=2)
    d.rectangle([14, 24, 26, 42], fill=(102, 102, 108), outline=(62, 62, 68), width=2)
    save(statue, out / "statue.png")

    # 祭坛
    altar = Image.new("RGBA", (64, 40))
    d = ImageDraw.Draw(altar)
    d.rectangle([0, 16, 63, 39], fill=(60, 55, 60), outline=(35, 30, 35), width=2)
    d.rectangle([12, 0, 52, 16], fill=(50, 45, 50), outline=(35, 30, 35), width=2)
    d.ellipse([26, 4, 38, 12], fill=(160, 25, 25))
    save(altar, out / "altar.png")

    # 断裂石柱
    broken = Image.new("RGBA", (40, 48))
    d = ImageDraw.Draw(broken)
    d.rectangle([8, 10, 32, 47], fill=(82, 80, 84), outline=(47, 45, 49), width=2)
    d.polygon(
        [(8, 10), (14, 2), (23, 7), (32, 3), (32, 10)],
        fill=(82, 80, 84),
        outline=(47, 45, 49),
        width=2,
    )
    save(broken, out / "broken_pillar.png")

    # 血迹
    splatter = Image.new("RGBA", (48, 48))
    d = ImageDraw.Draw(splatter)
    for r, a in [(20, 150), (14, 190), (8, 220)]:
        d.ellipse([24 - r, 24 - r, 24 + r, 24 + r], fill=(145, 10, 10, a))
    for _ in range(6):
        x, y = random.randint(0, 42), random.randint(0, 42)
        d.ellipse([x, y, x + 7, y + 7], fill=(125, 8, 8, 140))
    save(splatter, out / "blood_splatter.png")

    # 蛛网
    cobweb = Image.new("RGBA", (48, 48))
    d = ImageDraw.Draw(cobweb)
    for i in range(0, 48, 6):
        d.line([(0, i), (i, 0)], fill=(200, 200, 200, 55), width=1)
        d.line([(i, 47), (47, i)], fill=(200, 200, 200, 55), width=1)
    d.ellipse([8, 8, 40, 40], outline=(200, 200, 200, 35), width=1)
    d.ellipse([16, 16, 32, 32], outline=(200, 200, 200, 35), width=1)
    save(cobweb, out / "cobweb.png")


def generate_room_tiles() -> None:
    """生成房间主题瓦片与装饰物。"""
    out = DST / "tiles"
    for theme, colors in ROOM_THEMES.items():
        _generate_wall_tile(theme, colors, out)
        _generate_pillar_tile(theme, colors, out)
        _generate_floor_tile(theme, colors, out)
    _generate_props(out / "props")


def generate_portal() -> None:
    """生成传送门精灵图。"""
    size = 96
    img = Image.new("RGBA", (size, size))
    draw = ImageDraw.Draw(img)
    cx, cy = size // 2, size // 2

    for r in range(size // 2, 8, -4):
        alpha = int(110 * (r / (size // 2)))
        draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(120, 30, 180, alpha))

    for r in range(size // 3, 4, -3):
        alpha = int(190 * (r / (size // 3)))
        draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(80, 10, 160, alpha))

    draw.ellipse([cx - 10, cy - 10, cx + 10, cy + 10], fill=(210, 130, 255))
    save(img, DST / "effects" / "portal.png")


if __name__ == "__main__":
    process_enemies()
    generate_effects()
    generate_ui()
    copy_bgm()
    copy_sfx()
    generate_enemy_states()
    generate_room_tiles()
    generate_portal()
    print("Done")
