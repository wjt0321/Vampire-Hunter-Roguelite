"""把截图里的图标列裁出来放大 4 倍，肉眼确认哪些位置"只有字没有图"。

用法：python tools/zoom_regions.py
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
EV = ROOT / "tools" / "evidence"
OUT = ROOT / "tools" / "evidence" / "zoom"

# (截图名, 左, 上, 右, 下, 放大倍数)
REGIONS = [
    ("02_meta_shop.png", 330, 205, 470, 480, 4),
    ("03_hud_build_panel.png", 14, 100, 190, 570, 3),
    ("01_character_select.png", 330, 430, 700, 500, 3),
]


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for name, l, t, r, b, k in REGIONS:
        src = EV / name
        if not src.exists():
            print(f"缺 {src}")
            continue
        im = Image.open(src).convert("RGB")
        crop = im.crop((l, t, r, b)).resize(((r - l) * k, (b - t) * k), Image.Resampling.NEAREST)
        out = OUT / f"zoom_{Path(name).stem}.png"
        crop.save(out)
        print(f"OK {out.name} {crop.size}")


if __name__ == "__main__":
    main()
