"""死亡条的后处理：抠底 -> 切格 -> 缩到 56px 拼条。

单独成模块，方便不重新出图就反复调后处理。

三个关键决定：
1. 抠底用"全局品红色相"，但比 MVP 的 key_magenta 放宽：
   MVP 要求 G<75，模型画的半透明灰雾是"灰+品红"混色，G 在 75~110 之间，
   落在阈值外，抠完留一圈紫斑。这里放宽到 (R-G)>25 且 (B-G)>25，
   同时用 R 不小于 B 保护角色自带的紫罗兰（紫水晶、维洛特法袍都是 B 明显大于 R）。
2. 切格按三等分。模型输出的 3x2 网格是规整的，纯三等分比"找空白列"稳：
   找空白列会被角色内部的空隙切成碎片。
3. 帧序保留模型的阅读顺序（左上 -> 右上 -> 左下 -> 右下）。
   模型是照提示词里"第 1..6 阶段"画的，几何量重排反而会打乱它。
"""
from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / ".workbuddy" / "comfy"))
import reskin_pipeline as RP  # noqa: E402


def key_bg(im: Image.Image) -> Image.Image:
    """品红抠底：放宽阈值到偏品红色相，同时保护角色自带的紫罗兰。"""
    rgb = np.array(im.convert("RGB")).astype(np.int16)
    R, G, B = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    magenta_side = (
        ((R - G) > 25)
        & ((B - G) > 25)
        & (R > 55)
        & (B > 55)
        & (R >= B * 0.88)
        & (B >= R * 0.72)
    )
    arr = np.array(im.convert("RGB"))
    alpha = np.where(magenta_side, 0, 255).astype(np.uint8)
    out = Image.fromarray(np.dstack([arr, alpha]), "RGBA")
    return RP.purge_purple_edge(out)


def cut_grid(image: Image.Image, columns: int = 3, rows: int = 2) -> list:
    w, h = image.size
    frames = []
    for row in range(rows):
        y0 = round(row * h / rows)
        y1 = round((row + 1) * h / rows)
        for col in range(columns):
            x0 = round(col * w / columns)
            x1 = round((col + 1) * w / columns)
            frames.append(image.crop((x0, y0, x1, y1)))
    return frames


def pack(frames: list, cell: int = 56) -> Image.Image:
    """保留模型给的阅读顺序；只做统一缩放与底部对齐。

    空格子（模型画了一格纯背景）在这里被跳过，不会中断整批：
    调用方会看到帧数不足，据此重跑。
    """
    strip = Image.new("RGBA", (cell * len(frames), cell), (0, 0, 0, 0))
    slot = 0
    for frame in frames:
        keyed = key_bg(frame.convert("RGB"))
        box = keyed.getbbox()
        if box is None:
            continue
        body = keyed.crop(box)
        usable = cell - 4
        factor = max(1, round(max(body.size) / usable))
        small = body.resize((max(1, body.width // factor), max(1, body.height // factor)),
                            Image.Resampling.NEAREST)
        canvas = Image.new("RGBA", (cell, cell), (0, 0, 0, 0))
        canvas.alpha_composite(small, ((cell - small.width) // 2, cell - small.height))
        strip.alpha_composite(canvas, (slot * cell, 0))
        slot += 1
    return strip
