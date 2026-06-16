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
    size = 256
    # 商人：使用 spice-merchant 素材
    merchant_src = SRC / "sprites" / "freegamesprites" / "spice-merchant-bearded-robed.png"
    if merchant_src.exists():
        img = Image.open(merchant_src).convert("RGBA")
        img = trim_and_square(img, target=128, pad=4)
        save(img, DST / "ui" / "merchant.png")

    # 胜利/失败背景：程序化暗色渐变 + 简单图案
    for name, base_color, accent in [
        ("victory_bg", (10, 10, 30), (255, 215, 0)),
        ("defeat_bg", (30, 5, 5), (180, 0, 0)),
    ]:
        bg = Image.new("RGBA", (1280, 720), base_color)
        draw = ImageDraw.Draw(bg)
        # 放射线
        for i in range(0, 1280, 40):
            draw.line([(i, 0), (i + 200, 720)], fill=(*accent, 30), width=2)
        # 边框
        draw.rectangle([20, 20, 1260, 700], outline=(*accent, 120), width=4)
        save(bg, DST / "ui" / f"{name}.png")

    # 菜单边框装饰
    frame = Image.new("RGBA", (400, 500), (0, 0, 0, 0))
    fdraw = ImageDraw.Draw(frame)
    fdraw.rectangle([0, 0, 399, 499], outline=(139, 0, 0, 255), width=6)
    fdraw.rectangle([10, 10, 389, 489], outline=(255, 215, 0, 200), width=2)
    save(frame, DST / "ui" / "menu_frame.png")


def copy_bgm():
    audio_src = SRC / "audio" / "oga"
    bgm_dst = DST / "audio" / "bgm"
    bgm_dst.mkdir(parents=True, exist_ok=True)
    copies = [
        ("battle_theme_a.mp3", "bgm_battle.mp3"),
        ("basilisk_boss.ogg", "bgm_boss.ogg"),
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
