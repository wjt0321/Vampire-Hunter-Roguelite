"""旧敌人的死亡条：严格判据优先，放宽判据兜底，并且复用已生成的原始网格。

为什么不用 gen_enemy_death_grid.py 那套：
  它的判据要求「站高比逐格单调下降 25%」，这对人形怪成立，
  对四足/矮趴的怪不成立——狼人趴下时本来就矮，高度比掉不到 25%，
  于是三次种子全被判不合格，白跑三张图。

这里的做法：
  1. 先看已经躺在 artifacts/iteration_assets/deathgrid_<id>_s*.png 的原始网格，
     逐个用严格判据、再用放宽判据过一遍，能过就直接打包，不重复出图；
  2. 全都不过，才出新图（最多 3 次）；
  3. 出图后同样先严格后放宽——严格过就一定收下。

放宽判据见 relax_death_strips.py 的说明。

用法：
  python tools/gen_legacy_death.py vampire werewolf ...
"""
from __future__ import annotations

import json
import sys
import time
import urllib.parse
import urllib.request
import zlib
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
sys.path.insert(0, str(ROOT / ".workbuddy" / "comfy"))
import gen_vhr_assets as g      # noqa: E402
import death_repack as REPACK   # noqa: E402

RAW = ROOT / "artifacts" / "iteration_assets"
INPUT = Path(r"E:/AI/ComfyUI/input")
DEST = ROOT / "assets" / "sprites" / "enemies"
STEPS_FILE = RAW / "death_steps_legacy.json"

MAX_TRIES = 3

NEG = ("blurry, low quality, watermark, text, signature, jpeg artifacts, 3d render, "
       "photorealistic, smooth gradients, chibi, cute, cartoon, anime, modern clothing, "
       "sci-fi, green color on the character, bright cheerful colors")

STYLE = ("Dark gothic fantasy pixel art, chunky visible pixels, limited 32-color palette, "
         "brushed dark steel and worn leather, antique gold filigree trim, deep crimson gems, "
         "high contrast with dramatic rim light, crisp 2px black outline")

BG = ("Flat solid pure magenta #FF00FF background, uniform bright magenta color card, "
      "no gradient, no shadow on the background, no text, no grid lines, "
      "no smoke or haze in the background.")


def death_steps(enemy_id: str) -> str:
    table = json.loads(STEPS_FILE.read_text(encoding="utf-8"))
    return str(table[enemy_id])


def compose_grid(src: Path, out_name: str, cols: int = 3, rows: int = 2, cell_px: int = 384) -> Path:
    keyed = REPACK.key_bg(Image.open(src).convert("RGB"))
    box = keyed.getbbox()
    body = keyed.crop(box) if box else keyed
    gap = 8
    canvas = Image.new("RGBA", (cols * cell_px + (cols + 1) * gap,
                                rows * cell_px + (rows + 1) * gap), (255, 0, 255, 255))
    scale = min((cell_px - 16) / body.width, (cell_px - 16) / body.height)
    body = body.resize((max(1, round(body.width * scale)), max(1, round(body.height * scale))),
                       Image.Resampling.LANCZOS)
    for i in range(cols * rows):
        x = gap + (i % cols) * (cell_px + gap) + (cell_px - body.width) // 2
        y = gap + (i // cols) * (cell_px + gap) + (cell_px - body.height) // 2
        canvas.alpha_composite(body, (x, y))
    dest = INPUT / (out_name + ".png")
    canvas.convert("RGB").save(dest)
    return dest


def metrics(frame: Image.Image) -> tuple:
    import cv2

    alpha = np.array(frame.getchannel("A"))
    solid = (alpha > 96).astype(np.uint8)
    n, _, stats, _ = cv2.connectedComponentsWithStats(solid, 8)
    if n <= 1:
        return 0.0, 1.0, 0.0
    idx = 1 + int(np.argmax(stats[1:, cv2.CC_STAT_AREA]))
    return (int(stats[idx, cv2.CC_STAT_HEIGHT]) / max(1, frame.height),
            int(stats[idx, cv2.CC_STAT_TOP]) / max(1, frame.height),
            int(stats[idx, cv2.CC_STAT_AREA]) / float(frame.width * frame.height))


def strict_ok(frames: list) -> tuple:
    if len(frames) != 6:
        return False, "帧数不是 6"
    ms = [metrics(f) for f in frames]
    ratios = [m[0] for m in ms]
    tops = [m[1] for m in ms]
    if min(ratios) == 0.0:
        return False, "有空格是空的"
    dropped = ratios[-1] <= ratios[0] - 0.25
    top_dropped = tops[-1] >= tops[0] + 0.15
    if not (dropped or top_dropped):
        return False, "高度没塌 %.2f→%.2f" % (ratios[0], ratios[-1])
    for i in range(1, len(ratios) - 1):
        if ratios[i] > ratios[i - 1] + 0.22:
            return False, "中途回弹 %.2f" % ratios[i]
    return True, "严格：高度 %.2f→%.2f" % (ratios[0], ratios[-1])


def relaxed_ok(frames: list) -> tuple:
    if len(frames) != 6:
        return False, "帧数不是 6"
    ms = [metrics(f) for f in frames]
    ratios = [m[0] for m in ms]
    tops = [m[1] for m in ms]
    areas = [m[2] for m in ms]
    if min(ratios) == 0.0:
        return False, "有空格是空的"
    if tops[-1] >= tops[0] + 0.10:
        return True, "放宽：顶边下沉 %.2f" % (tops[-1] - tops[0])
    head = (ratios[0] + ratios[1]) / 2.0
    tail = (ratios[-1] + ratios[-2]) / 2.0
    if tail <= head - 0.08:
        return True, "放宽：末段比首段矮 %.2f" % (head - tail)
    if areas[-1] <= areas[0] * 0.65:
        return True, "放宽：面积缩到 %.0f%%" % (areas[-1] / max(1e-6, areas[0]) * 100.0)
    return False, "高度 %.2f→%.2f 顶边 %.2f→%.2f 面积 %.3f→%.3f" % (
        ratios[0], ratios[-1], tops[0], tops[-1], areas[0], areas[-1])


# 个别角色的补充约束。
# 僵尸这关连着三次都没塌下去：模型让它一直半站着。
# 几何判据没错，错在提示词没说清"最后三帧必须趴在地上"。
EXTRA_RULES = {
    "zombie": ("In cells 4, 5 and 6 the zombie is lying flat on the ground and spread out "
               "horizontally, so it takes up clearly less vertical space than in cell 1; "
               "the head rests on the ground and is not held up, the arms lie out to the sides."),
}

GENERIC_RULE = ("The character must end up lying flat on the ground: in cells 4, 5 and 6 its "
                 "vertical height on the page is clearly less than half of its height in cell 1, "
                 "and nothing in those cells stands upright.")


def build_prompt(enemy_id: str) -> str:
    steps = death_steps(enemy_id).split(", ")
    cells = " ".join("cell %d shows %s" % (i + 1, s) for i, s in enumerate(steps))
    return (
        "Image 1 is the same character repeated in six identical cells on a magenta card. "
        "Redraw all six cells as one continuous death animation of that exact character, "
        "keeping its exact design, colors and proportions. "
        "Draw exactly 3 columns and 2 rows, six equal square cells, reading order left to right then top to bottom. "
        "The six cells are: " + cells + ". "
        "Every cell must be a visibly different pose, never a copy of another cell. "
        "The character must get progressively lower and more collapsed in every later cell; "
        "in cells 4, 5 and 6 the character is already down on the ground, never standing upright. "
        "Cell 6 shows only flat remains lying on the ground: broken pieces, ash, cloth or bones "
        "spread low, no upright body, no standing figure, nothing taller than the debris pile. "
        "Keep every cell clean: one character plus small sparks, no thick smoke or dust clouds "
        "covering the background, no overlapping artwork between cells. "
        + GENERIC_RULE + " "
        + (EXTRA_RULES.get(enemy_id, "") + " " if enemy_id in EXTRA_RULES else "")
        + STYLE + " "
        "Each cell holds exactly one full character, feet anchored at the same height in every cell, "
        "the character filling at most 80 percent of its cell and never crossing the cell border. "
        + BG
    )


def run_edit(grid: Path, enemy_id: str, seed: int) -> Path:
    name = "deathgrid_%s_s%d" % (enemy_id, seed)
    dest = RAW / (name + ".png")
    if dest.exists():
        dest.unlink()
    wf = g.build_workflow(name, build_prompt(enemy_id), 1152, 768, [grid.name], seed, 16, 3.0,
                          "qwen_edit", NEG)
    resp = g.post_json("/prompt", {"prompt": wf, "client_id": "vhr_gen"})
    pid = resp["prompt_id"]
    deadline = time.time() + 1200
    while time.time() < deadline:
        time.sleep(5)
        h = g.get_json("/history/" + pid)
        if pid not in h:
            continue
        status = h[pid].get("status", {})
        if status.get("completed") is False:
            print("FAIL", enemy_id, json.dumps(status, ensure_ascii=False)[:300], flush=True)
            return dest
        for node_out in (h[pid].get("outputs") or {}).values():
            for img in node_out.get("images", []):
                q = urllib.parse.urlencode({"filename": img["filename"],
                                           "subfolder": img.get("subfolder", ""),
                                           "type": img.get("type", "output")})
                with urllib.request.urlopen(g.HOST + "/view?" + q, timeout=120) as r:
                    dest.write_bytes(r.read())
                return dest
    print("MISS", enemy_id, flush=True)
    return dest


def try_pack(raw: Path) -> tuple:
    keyed = REPACK.key_bg(Image.open(raw).convert("RGB"))
    frames = REPACK.cut_grid(keyed, 3, 2)
    ok, why = strict_ok(frames)
    if ok:
        return frames, "严格 " + why
    ok, why2 = relaxed_ok(frames)
    if ok:
        return frames, "放宽 " + why2
    return None, why + " / " + why2


def main() -> None:
    ids = sys.argv[1:] or ["vampire", "werewolf", "zombie", "bat", "skeleton", "exploder",
                           "gargoyle", "vampire_mage", "summoner", "vampire_prince", "elite_vampire"]
    for enemy_id in ids:
        base = RAW / ("%s_idle.png" % enemy_id)
        if not base.exists():
            print("NO BASE", enemy_id, flush=True)
            continue
        out_path = DEST / enemy_id / "death.png"
        if out_path.is_file():
            print("SKIP-EXISTS", enemy_id, flush=True)
            continue
        chosen = None
        note = ""
        cached = sorted(RAW.glob("deathgrid_%s_s*.png" % enemy_id))
        for cand in reversed(cached):
            frames, why = try_pack(cand)
            if frames is not None:
                chosen = frames
                note = "%s %s" % (cand.name, why)
                break
        if chosen is None:
            grid = compose_grid(base, "deathgrid_" + enemy_id)
            base_seed = 7000 + (zlib.crc32(enemy_id.encode("utf-8")) % 900)
            for attempt in range(MAX_TRIES):
                seed = base_seed + attempt * 137
                raw = run_edit(grid, enemy_id, seed)
                if not raw.exists():
                    break
                frames, why = try_pack(raw)
                print("%s seed=%d %s" % (enemy_id, seed, why), flush=True)
                if frames is not None:
                    chosen = frames
                    break
        if chosen is None:
            print("SKIP", enemy_id, "两张判据都没过", flush=True)
            continue
        strip = REPACK.pack(chosen, 56)
        out = DEST / enemy_id / "death.png"
        out.parent.mkdir(parents=True, exist_ok=True)
        strip.save(out)
        print("OK", enemy_id, out, strip.size, note, flush=True)


if __name__ == "__main__":
    main()
