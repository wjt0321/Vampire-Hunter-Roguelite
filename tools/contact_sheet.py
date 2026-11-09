"""把某个资产目录拼成一张联络表，方便人工核对。

用法: python tools/contact_sheet.py [目录 ...]
默认 assets/ 下挑几个关键源文件；给了目录就渲染该目录全部 png。
输出: tools/evidence/contact_<dirname>.png
"""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets"
OUTDIR = ROOT / "tools" / "evidence"

DEFAULT_FILES = [
    "weapons/heal_potion.png",
    "weapons/xp_gem_large.png",
    "weapons/xp_gem_medium.png",
    "weapons/xp_gem_small.png",
    "weapons/blood_crystal.png",
    "tiles/props/chest.png",
    "tiles/props/gold_pile.png",
    "ui/achievement_icon.png",
    "ui/star_gold.png",
    "ui/affix_shielded.png",
    "weapons/icon_shield.png",
    "weapons/icon_magnet.png",
]

CELL = 180
PAD = 10
BG = (60, 45, 60, 255)
BG2 = (85, 65, 85, 255)


def on_checker(im: Image.Image) -> Image.Image:
    flat = Image.new("RGBA", im.size, BG)
    for yy in range(0, im.height, 16):
        for xx in range(0, im.width, 16):
            if (xx // 16 + yy // 16) % 2 == 0:
                flat.paste(BG2, (xx, yy, xx + 16, yy + 16))
    flat.alpha_composite(im)
    return flat.convert("RGB")


def render(files: list[str], out: Path) -> None:
    cols = 6
    rows = max(1, (len(files) + cols - 1) // cols)
    sheet = Image.new("RGB", (cols * CELL, rows * (CELL + PAD)), (26, 18, 26))
    d = ImageDraw.Draw(sheet)
    for i, rel in enumerate(files):
        p = ASSETS / rel
        if not p.exists():
            continue
        im = Image.open(p).convert("RGBA")
        orig = f"{im.width}x{im.height}"
        flat = on_checker(im)
        flat.thumbnail((CELL - 8, CELL - 8), Image.Resampling.NEAREST)
        x = (i % cols) * CELL
        y = (i // cols) * (CELL + PAD)
        sheet.paste(flat, (x + (CELL - flat.width) // 2, y + (CELL - flat.height) // 2))
        d.text((x + 3, y + CELL + 1), f"{rel.split('/')[-1]} {orig}", fill=(210, 210, 210))
    out.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(out)
    print(f"-> {out}")


def main() -> None:
    args = sys.argv[1:]
    if not args:
        render(DEFAULT_FILES, OUTDIR / "contact_sources.png")
        return
    for d in args:
        folder = ASSETS / d if not Path(d).is_absolute() else Path(d)
        files = [f"{d}/{p.name}" for p in sorted(folder.glob("*.png"))]
        if not files:
            print(f"!! {folder} 里没有 png")
            continue
        name = folder.name
        render(files, OUTDIR / f"contact_{name}.png")


if __name__ == "__main__":
    main()
