"""把旧敌人的新风格精灵条拼成一张验收图。

每一行一个敌人：左边是待机横条（4 帧连着放），右边是死亡条的前/中/末三帧。
放大 3 倍用最近邻，保留像素颗粒。

用法：
  python tools/legacy_contact_sheet.py
输出：
  artifacts/iteration_assets/legacy_enemies_sheet.png
"""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

ENEMY_ROOT = ROOT / "assets" / "sprites" / "enemies"

ROWS = [
    ("vampire", "吸血鬼"),
    ("werewolf", "狼人"),
    ("zombie", "僵尸"),
    ("bat", "蝙蝠"),
    ("skeleton", "骨架弓手"),
    ("exploder", "爆裂者"),
    ("gargoyle", "石像鬼"),
    ("vampire_mage", "血族法师"),
    ("summoner", "召唤师"),
    ("vampire_prince", "血族王子"),
    ("elite_vampire", "精英吸血鬼"),
]

SCALE = 3
CELL = 56


def sheet_of(path: Path) -> Image.Image | None:
    if not path.is_file():
        return None
    im = Image.open(path).convert("RGBA")
    return im


def build() -> Path:
    rows = []
    for enemy_id, label in ROWS:
        idle = sheet_of(ENEMY_ROOT / enemy_id / "idle.png")
        death = sheet_of(ENEMY_ROOT / enemy_id / "death.png")
        if idle is None and death is None:
            continue
        rows.append((label, idle, death))

    if not rows:
        raise SystemExit("没有可拼的旧敌人资产")

    idle_w = max((r[1].width if r[1] else 0) for r in rows)
    death_w = max((r[2].width if r[2] else 0) for r in rows)
    pad = 12
    label_w = 96
    width = label_w + pad + idle_w + pad + death_w + pad
    row_h = CELL * SCALE + pad
    height = pad + row_h * len(rows)

    canvas = Image.new("RGBA", (width, height), (22, 16, 20, 255))
    for i, (label, idle, death) in enumerate(rows):
        y = pad + i * row_h
        # 待机条
        if idle is not None:
            big = idle.resize((idle.width * SCALE, idle.height * SCALE), Image.Resampling.NEAREST)
            canvas.alpha_composite(big, (label_w + pad, y))
        # 死亡条：取第 1 / 中间 / 末三帧
        if death is not None:
            n = max(1, death.width // CELL)
            picks = sorted({0, n // 2, n - 1})
            for k, idx in enumerate(picks):
                frame = death.crop((idx * CELL, 0, (idx + 1) * CELL, CELL))
                big = frame.resize((CELL * SCALE, CELL * SCALE), Image.Resampling.NEAREST)
                canvas.alpha_composite(big, (label_w + pad + idle_w + pad + k * CELL * SCALE, y))

    # 左边标签用默认位图字体画不了中文，这里退化成英文 id 首字母标记条
    for i, (label, _, _) in enumerate(rows):
        bar = Image.new("RGBA", (label_w - pad, 6), (150, 120, 60, 255))
        canvas.alpha_composite(bar, (pad, y + CELL * SCALE // 2 - 3))

    out = ROOT / "artifacts" / "iteration_assets" / "legacy_enemies_sheet.png"
    out.parent.mkdir(parents=True, exist_ok=True)
    canvas.convert("RGB").save(out)
    return out


if __name__ == "__main__":
    p = build()
    print("SHEET", p, p.stat().st_size)
