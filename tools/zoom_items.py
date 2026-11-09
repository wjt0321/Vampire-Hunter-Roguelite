"""把 assets/items 里的图放大 6 倍（NEAREST）拼成一张，便于逐像素核对。

用法: python tools/zoom_items.py
输出: tools/evidence/contact_items_zoom.png
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
ITEMS = ROOT / "assets" / "items"
OUT = ROOT / "tools" / "evidence" / "contact_items_zoom.png"

SCALE = 6
CELL = 48 * SCALE
PAD = 10


def on_checker(im: Image.Image) -> Image.Image:
    bg = Image.new("RGBA", im.size, (70, 55, 70, 255))
    for yy in range(0, im.height, 8):
        for xx in range(0, im.width, 8):
            if (xx // 8 + yy // 8) % 2 == 0:
                bg.paste((95, 75, 95, 255), (xx, yy, xx + 8, yy + 8))
    bg.alpha_composite(im)
    return bg.convert("RGB")


def main() -> None:
    files = sorted(ITEMS.glob("*.png"))
    cols = 5
    rows = max(1, (len(files) + cols - 1) // cols)
    sheet = Image.new("RGB", (cols * CELL, rows * (CELL + PAD)), (26, 18, 26))
    d = ImageDraw.Draw(sheet)
    for i, p in enumerate(files):
        im = Image.open(p).convert("RGBA")
        flat = on_checker(im).resize((im.width * SCALE, im.height * SCALE),
                                     Image.Resampling.NEAREST)
        x = (i % cols) * CELL + (CELL - flat.width) // 2
        y = (i // cols) * (CELL + PAD) + (CELL - flat.height) // 2
        sheet.paste(flat, (x, y))
        d.text(((i % cols) * CELL + 3, (i // cols) * (CELL + PAD) + CELL + 1),
               f"{p.name} {im.width}x{im.height}", fill=(215, 215, 215))
    OUT.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(OUT)
    print(f"-> {OUT}")


if __name__ == "__main__":
    main()
