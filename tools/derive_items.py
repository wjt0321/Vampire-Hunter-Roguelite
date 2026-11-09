"""派生战场掉落物与 UI 图标资产（不跑 ComfyUI，纯像素处理）。

为什么"能派生就不重新生成"：
  - 经验宝石三档本来就有 AI 原图（weapons/xp_gem_large.png 1024×1024），
    只是从来没接进世界层，场上画的是程序化菱形。派生三档颜色即可。
  - 受诅宝箱可以由已有宝箱（tiles/props/chest.png）改配色得到。
  - heal_potion / blood_crystal 当 48px 图标用会糊（1024 原图 / 24 原图），
    下采样出真正的 48×48 版本。

产出（assets/items/）：
  xp_gem_gold.png   32×32  金（大经验）
  xp_gem_blue.png   24×24  蓝（中经验）
  xp_gem_green.png  16×16  绿（小经验）
  xp_gem_icon.png   48×48  金（UI 图标）
  cursed_chest.png  48×40  受诅宝箱
  heal_potion_icon.png   48×48
  blood_crystal_icon.png 48×48

用法: python tools/derive_items.py
"""
from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / ".workbuddy" / "comfy"))

from ui_proc import recolor_luma  # noqa: E402

ASSETS = ROOT / "assets"
ITEMS = ASSETS / "items"

# 三档宝石的色阶（和 xp_gem.gd 的 _tier_for 保持一致）
GEM_RAMPS = {
    "gold": [np.array([26, 18, 10]), np.array([96, 66, 22]),
             np.array([196, 146, 44]), np.array([252, 226, 158])],
    "blue": [np.array([10, 16, 28]), np.array([36, 72, 122]),
             np.array([88, 150, 216]), np.array([206, 234, 255])],
    "green": [np.array([10, 24, 14]), np.array([38, 100, 52]),
              np.array([92, 186, 104]), np.array([206, 248, 200])],
}

# 受诅宝箱：冷紫灰配色，和普通宝箱（暖木色）区分开
CURSED_RAMP = [np.array([16, 12, 22]), np.array([50, 38, 64]),
               np.array([104, 88, 122]), np.array([186, 172, 200])]

# 血晶（沿用 derive_extra 里的同一套血红色阶）
CRIMSON_RAMP = [np.array([28, 8, 10]), np.array([96, 16, 24]),
                np.array([186, 40, 52]), np.array([248, 148, 140])]


def crop_box(im: Image.Image) -> Image.Image:
    box = im.getbbox()
    return im.crop(box) if box else im


def fit(im: Image.Image, w: int, h: int, pad: int = 1) -> Image.Image:
    """等比缩放到 w×h 画布（BOX = 像素化），四周留 pad 透明边。"""
    im = crop_box(im.convert("RGBA"))
    iw, ih = max(1, w - pad * 2), max(1, h - pad * 2)
    s = min(iw / im.width, ih / im.height)
    tw, th = max(1, round(im.width * s)), max(1, round(im.height * s))
    im = im.resize((tw, th), Image.Resampling.BOX)
    canvas = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    canvas.alpha_composite(im, ((w - tw) // 2, (h - th) // 2))
    return canvas


def quantize(im: Image.Image, colors: int = 40) -> Image.Image:
    a = im.getchannel("A")
    q = im.convert("RGB").quantize(colors=colors, method=Image.Quantize.MEDIANCUT,
                                   dither=Image.Dither.NONE)
    return Image.fromarray(np.dstack([np.array(q.convert("RGB")), np.array(a)]), "RGBA")


def build_gems() -> None:
    src = Image.open(ASSETS / "weapons" / "xp_gem_large.png").convert("RGBA")
    master = fit(src, 32, 32, pad=0)
    for tier, size in (("gold", 32), ("blue", 24), ("green", 16)):
        # 先从 32 主图缩到目标尺寸，再上色阶：色阶要在小尺寸上量化才不会有杂色边
        small = master if size == 32 else master.resize((size, size), Image.Resampling.BOX)
        out = quantize(recolor_luma(small, GEM_RAMPS[tier]), colors=24)
        out.save(ITEMS / f"xp_gem_{tier}.png")
        print(f"  items/xp_gem_{tier}.png  {size}x{size}  bbox={out.getbbox()}")


def build_gem_icon() -> None:
    src = Image.open(ASSETS / "weapons" / "xp_gem_large.png").convert("RGBA")
    out = quantize(recolor_luma(fit(src, 48, 48, pad=1), GEM_RAMPS["gold"]), colors=32)
    out.save(ITEMS / "xp_gem_icon.png")
    print(f"  items/xp_gem_icon.png  48x48")


def build_cursed_chest() -> None:
    src = Image.open(ASSETS / "tiles" / "props" / "chest.png").convert("RGBA")
    body = recolor_luma(src, CURSED_RAMP)
    # 背后加一圈紫色雾光：一眼能和普通宝箱区分开
    halo = body.getchannel("A").filter(ImageFilter.GaussianBlur(radius=5))
    halo_img = Image.new("RGBA", body.size, (0, 0, 0, 0))
    halo_img.putalpha(halo.point(lambda v: int(v * 0.75)))
    tint = Image.new("RGBA", body.size, (128, 64, 176, 255))
    tint.putalpha(halo_img.getchannel("A"))
    out = Image.new("RGBA", body.size, (0, 0, 0, 0))
    out.alpha_composite(tint)
    out.alpha_composite(body)
    out = quantize(out, colors=32)
    out.save(ITEMS / "cursed_chest.png")
    print(f"  items/cursed_chest.png  {out.width}x{out.height}")


def build_icons() -> None:
    heal = Image.open(ASSETS / "weapons" / "heal_potion.png").convert("RGBA")
    quantize(fit(heal, 48, 48, pad=1), colors=32).save(ITEMS / "heal_potion_icon.png")
    print("  items/heal_potion_icon.png  48x48")

    gem = Image.open(ASSETS / "weapons" / "xp_gem_large.png").convert("RGBA")
    quantize(recolor_luma(fit(gem, 48, 48, pad=1), CRIMSON_RAMP),
             colors=32).save(ITEMS / "blood_crystal_icon.png")
    print("  items/blood_crystal_icon.png  48x48")


def main() -> None:
    ITEMS.mkdir(parents=True, exist_ok=True)
    print("派生 assets/items/:")
    build_gems()
    build_gem_icon()
    build_cursed_chest()
    build_icons()
    print("完成")


if __name__ == "__main__":
    main()
