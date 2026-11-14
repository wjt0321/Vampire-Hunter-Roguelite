r"""把本批次生成的精灵条拼成一张审阅图（放大到能看清像素）。

用法：
    python tools/iteration_contact_sheet.py [--scale 3]
输出：
    artifacts/iteration_assets/contact_sheet.png
"""
import argparse
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "artifacts" / "iteration_assets"
OUT = ROOT / "artifacts" / "iteration_assets" / "contact_sheet.png"


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--scale", type=int, default=3)
    ap.add_argument("--pattern", default="*_idle.png,*_death.png")
    args = ap.parse_args()
    names = []
    for part in args.pattern.split(","):
        part = part.strip()
        if "*" in part and "/" in part:
            names += sorted((ROOT / "assets" / "sprites" / "enemies").glob(part))
        else:
            names += sorted(p for p in SRC.glob(part))
    if not names:
        print("no raw sheets")
        return
    scale = args.scale
    rows = []
    for path in names:
        im = Image.open(path).convert("RGBA")
        rows.append((path.stem, im))
    label_w = 190
    cell_h = max(im.height for _, im in rows) * scale + 16
    sheet = Image.new("RGB", (label_w + max(im.width for _, im in rows) * scale + 24, cell_h * len(rows) + 20), "#151821")
    draw = ImageDraw.Draw(sheet)
    y = 10
    for name, im in rows:
        draw.text((10, y + 8), name, fill="#d8cfb8")
        big = im.resize((im.width * scale, im.height * scale), Image.Resampling.NEAREST)
        bg = Image.new("RGBA", big.size, (40, 44, 58, 255))
        bg.alpha_composite(big)
        sheet.paste(bg.convert("RGB"), (label_w, y))
        y += cell_h
    sheet.save(OUT)
    print(OUT, sheet.size, len(rows))


if __name__ == "__main__":
    main()
