"""把截图的一块区域裁出来放大，逐像素核对。

用法: python tools/crop_zoom.py <png> <x> <y> <w> <h> [倍率] [输出名]
"""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "tools" / "evidence" / "zoom"


def main() -> None:
    src = ROOT / "tools" / "evidence" / sys.argv[1]
    x, y, w, h = (int(v) for v in sys.argv[2:6])
    scale = int(sys.argv[6]) if len(sys.argv) > 6 else 3
    name = sys.argv[7] if len(sys.argv) > 7 else f"crop_{sys.argv[1]}"
    im = Image.open(src).convert("RGBA").crop((x, y, x + w, y + h))
    im = im.resize((im.width * scale, im.height * scale), Image.Resampling.NEAREST)
    OUT.mkdir(parents=True, exist_ok=True)
    dst = OUT / f"{name}.png"
    im.save(dst)
    print(f"-> {dst}  ({im.width}x{im.height})")


if __name__ == "__main__":
    main()
