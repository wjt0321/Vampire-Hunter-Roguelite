"""细查几个"疑似全透明"图标的真实 alpha 分布。

上一次统计用 `convert("RGBA").getchannel("A")` 的 alpha==255 计数，
对带调色板/transparency 的 PNG 可能会误判。这里直接看每个通道的直方图，
并分别输出：alpha 直方图、前景像素数、合成到暗底后的对比度。
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
TARGETS = [
    "weapons/icon_magnet.png",
    "weapons/icon_knife.png",
    "weapons/icon_lightning.png",
    "weapons/blood_crystal.png",
    "weapons/icon_pistol.png",
    "weapons/heal_potion.png",
    "weapons/xp_gem_large.png",
]


def report(rel: str) -> None:
    path = ROOT / "assets" / rel
    im = Image.open(path)
    print(f"\n--- {rel} ---")
    print(f"  mode={im.mode} size={im.size} info={ {k: v for k, v in im.info.items() if k in ('transparency',)} }")
    rgba = im.convert("RGBA")
    a = rgba.getchannel("A")
    hist = a.histogram()
    total = sum(hist)
    nonzero = total - hist[0]
    full = hist[255]
    print(f"  alpha: 全0={hist[0]} 全255={full} 非0={nonzero} 占比={nonzero / total:.4f}")
    # 前景 = alpha>16
    fg = sum(1 for p in a.getdata() if p > 16)
    print(f"  前景像素(alpha>16) = {fg} ({fg / total:.4f})")
    # 合成到深色底看实际观感
    bg = Image.new("RGBA", rgba.size, (26, 10, 26, 255))
    bg.alpha_composite(rgba)
    flat = bg.convert("L")
    px = list(flat.getdata())
    mean = sum(px) / len(px)
    var = sum((p - mean) ** 2 for p in px) / len(px)
    print(f"  合成后灰度 mean={mean:.1f} std={var ** 0.5:.1f}")
    # 前景区域的颜色数
    fg_colors = set()
    r, g, b, al = rgba.split()
    rl, gl, bl, all_ = list(r.getdata()), list(g.getdata()), list(b.getdata()), list(al.getdata())
    for i in range(total):
        if all_[i] > 16:
            fg_colors.add((rl[i], gl[i], bl[i]))
    print(f"  前景颜色数 = {len(fg_colors)}")


for t in TARGETS:
    report(t)
