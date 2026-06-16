#!/usr/bin/env python3
"""
处理 assets-downloaded/ 中的原始素材：
- 裁切透明边、统一为方形、缩放
- 生成程序化占位特效/UI
- 输出到 assets/ 对应目录
"""
import os
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageEnhance

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


if __name__ == "__main__":
    process_enemies()
    generate_effects()
    generate_ui()
    copy_bgm()
    print("Done")
