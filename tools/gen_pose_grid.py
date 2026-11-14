"""旧敌人的「动作姿态」条生成器（P1-A 第二半）。

把某个敌人的新风格立绘原图拼成 N 格品红底卡片，交给 Qwen-Image-Edit 把每一格
重画成同一角色的不同姿态，再切格拼成 56px 横条，落到
assets/sprites/enemies/<enemy>/<state>.png。

与死亡条同一套思路，区别：
  * 死亡条要求逐格越来越低（几何量可判），动作条要求逐格姿态不同（两两差异可判）。
  * 动作条不靠"程序化错帧"糊弄，6 帧是真的 6 个姿势。

用法：
  python tools/gen_pose_grid.py                 # 全跑
  python tools/gen_pose_grid.py --only vampire_run
  python tools/gen_pose_grid.py --finalize-only # 只重切重拼，不出图
"""
from __future__ import annotations

import argparse
import json
import sys
import time
import urllib.parse
import zlib
import urllib.request
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
sys.path.insert(0, str(ROOT / ".workbuddy" / "comfy"))
import gen_vhr_assets as g        # noqa: E402
import death_repack as REPACK     # noqa: E402
import pose_grid_data as PLAN     # noqa: E402

RAW = ROOT / "artifacts" / "iteration_assets"
INPUT = Path(r"E:/AI/ComfyUI/input")
WF_DIR = ROOT / "artifacts" / "iteration_assets" / "workflows"
DEST = ROOT / "assets" / "sprites" / "enemies"

NEG = ("blurry, low quality, watermark, text, signature, jpeg artifacts, 3d render, "
       "photorealistic, smooth gradients, chibi, cute, cartoon, anime, modern clothing, "
       "sci-fi, green color on the character, bright cheerful colors, neon glow, lens flare, "
       "multiple characters, cropped, frame, border, motion blur")

STYLE = ("Dark gothic fantasy pixel art, chunky visible pixels, limited 32-color palette, "
         "brushed dark steel and worn leather, antique gold filigree trim, deep crimson gems, "
         "high contrast with dramatic rim light, crisp 2px black outline, dense micro-detail, "
         "muted desaturated shadows with a few saturated accents")

BG = ("Flat solid pure magenta #FF00FF background, uniform bright magenta color card, "
      "no gradient, no shadow on the background, no ground, no text, no grid lines, "
      "no smoke or haze in the background.")

MAX_TRIES = 3


def layout_for(frames: int) -> tuple:
    return (3, 2) if frames == 6 else (2, 2)


def compose_card(src: Path, out_name: str, cols: int, rows: int, cell_px: int = 384) -> Path:
    """把角色立绘复制到 cols x rows 的品红底卡片里，每格同一个角色。"""
    keyed = REPACK.key_bg(Image.open(src).convert("RGB"))
    box = keyed.getbbox()
    body = keyed.crop(box) if box else keyed
    gap = 8
    canvas = Image.new("RGBA", (cols * cell_px + (cols + 1) * gap,
                                rows * cell_px + (rows + 1) * gap), (255, 0, 255, 255))
    scale = min((cell_px - 16) / body.width, (cell_px - 16) / body.height)
    body = body.resize((max(1, round(body.width * scale)),
                        max(1, round(body.height * scale))), Image.Resampling.LANCZOS)
    for i in range(cols * rows):
        x = gap + (i % cols) * (cell_px + gap) + (cell_px - body.width) // 2
        y = gap + (i // cols) * (cell_px + gap) + (cell_px - body.height) // 2
        canvas.alpha_composite(body, (x, y))
    dest = INPUT / (out_name + ".png")
    canvas.convert("RGB").save(dest)
    return dest


def build_prompt(entry: dict, cols: int, rows: int) -> str:
    steps = entry["steps"].split(", ")
    cells = " ".join("cell %d shows %s" % (i + 1, s) for i, s in enumerate(steps))
    return (
        "Image 1 is the same character repeated in %d identical cells on a magenta card. "
        "Redraw all %d cells as %d consecutive frames of the same animation of that exact character, "
        "keeping its exact design, colors, equipment and proportions. "
        "The animation is: %s. "
        "Draw exactly %d columns and %d rows, %d equal cells, reading order left to right then top to bottom. "
        "The cells are: %s. "
        "Every cell must be a visibly different pose, never a copy of another cell. "
        "Keep the character at the same scale in every cell and fully inside its own cell, "
        "never overlapping the cell border. "
        "Keep every cell clean: one character plus small particles, no thick smoke or dust "
        "covering the background. "
        "%s %s" % (cols * rows, cols * rows, cols * rows, entry["action"], cols, rows, cols * rows, cells, STYLE, BG)
    )


def run_edit(card: Path, entry: dict, seed: int) -> Path:
    name = "posegrid_%s_%s_s%d" % (entry["enemy"], entry["state"], seed)
    dest = RAW / (name + ".png")
    if dest.exists():
        dest.unlink()
    cols, rows = layout_for(entry["frames"])
    prompt = build_prompt(entry, cols, rows)
    wf = g.build_workflow(name, prompt, 1152, 768, [card.name], seed, 16, 3.0, "qwen_edit", NEG)
    WF_DIR.mkdir(parents=True, exist_ok=True)
    (WF_DIR / (name + ".api.json")).write_text(json.dumps(wf, ensure_ascii=False, indent=1), encoding="utf-8")
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
            print("FAIL", entry["enemy"], entry["state"], json.dumps(status, ensure_ascii=False)[:300], flush=True)
            return dest
        for node_out in (h[pid].get("outputs") or {}).values():
            for img in node_out.get("images", []):
                q = urllib.parse.urlencode({"filename": img["filename"],
                                           "subfolder": img.get("subfolder", ""),
                                           "type": img.get("type", "output")})
                with urllib.request.urlopen(g.HOST + "/view?" + q, timeout=120) as r:
                    dest.write_bytes(r.read())
                return dest
    print("MISS", entry["enemy"], entry["state"], flush=True)
    return dest


def _signature(frame: Image.Image) -> np.ndarray:
    """帧的粗签名：16x16 灰度，用来比较两帧差别。"""
    alpha = np.array(frame.getchannel("A"))
    rgb = np.array(frame.convert("RGB")).astype(np.float32).mean(axis=2)
    m = alpha > 96
    if not m.any():
        return np.zeros((16, 16), dtype=np.float32)
    out = np.zeros((16, 16), dtype=np.float32)
    h, w = m.shape
    ys = (np.arange(h) * 16 // h).clip(0, 15)
    xs = (np.arange(w) * 16 // w).clip(0, 15)
    idx = ys[:, None] * 16 + xs[None, :]
    np.add.at(out.reshape(-1), idx[m].reshape(-1), rgb[m].reshape(-1))
    np.add.at(out.reshape(-1), idx[m].reshape(-1), 1.0)
    cnt = out.reshape(-1)
    sig = np.zeros(256, dtype=np.float32)
    nz = cnt > 0
    sig[nz] = out.reshape(-1)[nz] / cnt[nz]
    return sig.reshape(16, 16)


def judge(frames: list, need: int) -> tuple:
    """动作条质检：每格都得有内容，而且相邻两格必须真的不一样。"""
    if len(frames) != need:
        return False, []
    sigs = []
    for f in frames:
        keyed = REPACK.key_bg(f.convert("RGB"))
        if keyed.getbbox() is None:
            return False, []
        sigs.append(_signature(keyed))
    diffs = []
    for i in range(1, len(sigs)):
        a, b = sigs[i - 1], sigs[i]
        denom = max(1e-3, (np.abs(a).sum() + np.abs(b).sum()) / 2.0)
        diffs.append(float(np.abs(a - b).sum() / denom))
    # 相邻两格差异低于 0.02 基本就是同一张复制出来的
    if min(diffs) < 0.02:
        return False, diffs
    return True, diffs


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="")
    ap.add_argument("--enemy", default="")
    ap.add_argument("--finalize-only", action="store_true")
    ap.add_argument("--plan", default="",
                    help="额外的数据源模块名（tools/ 下），用于迭代新增敌人的动作条")
    args = ap.parse_args()

    entries = list(PLAN.ACTIONS)
    if args.plan:
        import importlib
        entries = list(importlib.import_module(args.plan).ACTIONS)
    entries = [e for e in entries
               if (not args.only or e["enemy"] + "_" + e["state"] == args.only)
               and (not args.enemy or e["enemy"] == args.enemy)]
    print("POSE GRID START total=%d" % len(entries), flush=True)
    for entry in entries:
        enemy, state = entry["enemy"], entry["state"]
        base = RAW / ("%s_idle.png" % enemy)
        if not base.exists():
            print("NO BASE", enemy, flush=True)
            continue
        cols, rows = layout_for(entry["frames"])
        out_path = DEST / enemy / ("%s.png" % state)
        if out_path.is_file():
            print("SKIP-EXISTS", enemy, state, flush=True)
            continue
        card = compose_card(base, "posecard_%s_%s" % (enemy, state), cols, rows)
        chosen = None
        if args.finalize_only:
            cands = sorted(RAW.glob("posegrid_%s_%s_s*.png" % (enemy, state)))
            if not cands:
                print("no raw", enemy, state, flush=True)
                continue
            cands = [cands[-1]]
        else:
            base_seed = 4100 + (zlib.crc32((enemy + state).encode("utf-8")) % 700)
            cands = []
            for attempt in range(MAX_TRIES):
                seed = base_seed + attempt * 137
                raw = run_edit(card, entry, seed)
                if not raw.exists():
                    break
                keyed = REPACK.key_bg(Image.open(raw).convert("RGB"))
                frames = REPACK.cut_grid(keyed, cols, rows)
                ok, diffs = judge(frames, entry["frames"])
                print("%s/%s seed=%d %s diffs=%s" % (
                    enemy, state, seed, "OK" if ok else "RETRY",
                    ",".join("%.3f" % d for d in diffs)), flush=True)
                if ok:
                    chosen = frames
                    break
            if chosen is None:
                print("SKIP", enemy, state, "帧质检没过", flush=True)
                continue
        if chosen is None:
            keyed = REPACK.key_bg(Image.open(cands[-1]).convert("RGB"))
            chosen = REPACK.cut_grid(keyed, cols, rows)
        strip = REPACK.pack(chosen, 56)
        out = DEST / enemy / ("%s.png" % state)
        out.parent.mkdir(parents=True, exist_ok=True)
        strip.save(out)
        print("OK", enemy, state, out, strip.size, flush=True)
    print("POSE GRID COMPLETE", flush=True)


if __name__ == "__main__":
    main()
