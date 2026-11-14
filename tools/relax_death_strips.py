"""死亡条的宽松兜底：把已经生成过、但没过严格判据的网格救回来。

严格判据（gen_enemy_death_grid.judge）要求「站高比逐格单调下降」，
这对人形怪成立，对四足/矮趴的怪不成立——狼人趴下时本来就矮，
高度比不会掉 25%，于是被误判成不合格。

这个脚本不再出图，只把已经躺在 artifacts/iteration_assets/deathgrid_*.png
里的原始网格，用放宽后的判据重新挑一遍，重新打包成死亡条。

放宽后的判据（任一成立即算演到位）：
  1. 末帧的「主体顶边」明显比首帧低（角色整体往下沉）
  2. 末两帧的平均站高比，明显低于首两帧的平均站高比
  3. 主体连通域的面积在末尾两帧明显缩小（塌成一堆）
另外允许中途有小幅回弹（虫翻身、翅膀扑腾都会短暂"变高"）。

用法：
  python tools/relax_death_strips.py vampire werewolf ...
"""
from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import death_repack as REPACK  # noqa: E402

RAW = ROOT / "artifacts" / "iteration_assets"
DEST = ROOT / "assets" / "sprites" / "enemies"


def metrics(frame: Image.Image) -> tuple:
    import cv2

    alpha = np.array(frame.getchannel("A"))
    solid = (alpha > 96).astype(np.uint8)
    n, _, stats, _ = cv2.connectedComponentsWithStats(solid, 8)
    if n <= 1:
        return 0.0, 1.0, 0.0
    idx = 1 + int(np.argmax(stats[1:, cv2.CC_STAT_AREA]))
    h = int(stats[idx, cv2.CC_STAT_HEIGHT])
    top = int(stats[idx, cv2.CC_STAT_TOP])
    area = int(stats[idx, cv2.CC_STAT_AREA])
    return h / max(1, frame.height), top / max(1, frame.height), area / float(frame.width * frame.height)


def relaxed_ok(frames: list) -> tuple:
    if len(frames) != 6:
        return False, "帧数不是 6"
    ms = [metrics(f) for f in frames]
    ratios = [m[0] for m in ms]
    tops = [m[1] for m in ms]
    areas = [m[2] for m in ms]

    if min(ratios) == 0.0:
        return False, "有空格是空的"

    head = (ratios[0] + ratios[1]) / 2.0
    tail = (ratios[-1] + ratios[-2]) / 2.0
    if tops[-1] >= tops[0] + 0.10:
        return True, "顶边下沉 %.2f" % (tops[-1] - tops[0])
    if tail <= head - 0.08:
        return True, "末段比首段矮 %.2f" % (head - tail)
    if areas[-1] <= areas[0] * 0.65:
        return True, "面积缩小到 %.0f%%" % (areas[-1] / max(1e-6, areas[0]) * 100.0)
    return False, "高度 %.2f→%.2f 顶边 %.2f→%.2f 面积 %.3f→%.3f" % (
        ratios[0], ratios[-1], tops[0], tops[-1], areas[0], areas[-1])


def main() -> None:
    ids = sys.argv[1:]
    if not ids:
        ids = ["vampire", "werewolf", "zombie", "bat", "skeleton", "exploder",
               "gargoyle", "vampire_mage", "summoner", "vampire_prince", "elite_vampire"]
    for enemy_id in ids:
        out = DEST / enemy_id / "death.png"
        cands = sorted(RAW.glob("deathgrid_%s_s*.png" % enemy_id))
        if not cands:
            print("NO RAW", enemy_id, flush=True)
            continue
        best = None
        for cand in reversed(cands):
            keyed = REPACK.key_bg(Image.open(cand).convert("RGB"))
            frames = REPACK.cut_grid(keyed, 3, 2)
            ok, why = relaxed_ok(frames)
            print("%s %s %s" % (enemy_id, cand.name, "PASS " + why if ok else "FAIL " + why), flush=True)
            if ok:
                best = frames
                break
        if best is None:
            print("RELAX-SKIP", enemy_id, flush=True)
            continue
        strip = REPACK.pack(best, 56)
        out.parent.mkdir(parents=True, exist_ok=True)
        strip.save(out)
        print("OK", enemy_id, out, strip.size, flush=True)


if __name__ == "__main__":
    main()
