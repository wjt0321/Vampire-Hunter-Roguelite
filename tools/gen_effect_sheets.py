"""特效 / 道具的序列帧生成器（P1-B + P2）。

每个条目跑一次 Edit：
  现有单帧 PNG（透明底，已是新风格正式美术）-> 拼成 N 格品红底卡片
  -> Qwen-Image-Edit 把每一格重画成同一特效的不同阶段 -> 切格 -> 拼成横条

输出统一是「N 格横条」，单格尺寸取自条目里的 cell：
  * 方形特效 64x64 / 96x96 / 128x128
  * 矩形道具 火把 24x48 / 营火 40x48 / 宝箱 48x40 / 商人 128x128
矩形单格不能用「宽÷高=帧数」那条 SpriteSheet 规则，游戏侧要单独用
SpriteFrames 播放器（scripts/core/sprite_frames_lib.gd）。

写法上刻意保留相对大小：所有帧用同一个缩放系数、同一个落点，
爆炸会真的越来越大、盾牌会真的碎开，而不是每帧各自裁一次。

用法：
  python tools/gen_effect_sheets.py                 # 全跑
  python tools/gen_effect_sheets.py --only portal
  python tools/gen_effect_sheets.py --finalize-only # 只重切重拼，不出图
"""
from __future__ import annotations

import argparse
import json
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
sys.path.insert(0, str(ROOT / ".workbuddy" / "comfy"))
import gen_vhr_assets as g        # noqa: E402
import death_repack as REPACK     # noqa: E402
import effects_plan_data as PLAN  # noqa: E402

COMFY_INPUT = Path(r"E:/AI/ComfyUI/input")
RAW = ROOT / "artifacts" / "iteration_assets" / "effects_raw"
WF_DIR = ROOT / "artifacts" / "iteration_assets" / "workflows"
MANIFEST = ROOT / "artifacts" / "iteration_assets" / "effect_sheets_manifest.json"

NEG = ("blurry, low quality, watermark, text, signature, jpeg artifacts, 3d render, "
       "photorealistic, smooth gradients, chibi, cute, cartoon, anime, modern clothing, "
       "sci-fi, bright cheerful colors, neon glow, lens flare, multiple separate effects, "
       "cropped, frame, border")

BASE_H = 176          # 卡片单格高度基准
GAP = 8
MAX_TRIES = 3


def layout_for(entry: dict) -> tuple:
    if entry["layout"] == "row":
        return entry["frames"], 1
    return 3, 2


def _fit_into(art: Image.Image, box_w: int, box_h: int) -> Image.Image:
    """把原画放进格子：够小就整数倍 NEAREST 放大（保住像素颗粒），够大就 LANCZOS 缩。"""
    factor = min(box_w // max(1, art.width), box_h // max(1, art.height))
    if factor >= 1:
        return art.resize((art.width * factor, art.height * factor), Image.Resampling.NEAREST)
    ratio = min(box_w / art.width, box_h / art.height)
    return art.resize((max(1, round(art.width * ratio)), max(1, round(art.height * ratio))),
                      Image.Resampling.LANCZOS)


def compose_card(entry: dict, out_name: str) -> tuple:
    """把现有单帧画复制到 N 格品红底卡片里，每格同一个东西。"""
    cols, rows = layout_for(entry)
    cw, ch = entry["cell"]
    cell_w = max(32, round(BASE_H * cw / ch))
    cell_h = BASE_H
    art = Image.open(ROOT / entry["src"]).convert("RGBA")
    body = _fit_into(art, cell_w - 16, cell_h - 16)
    canvas = Image.new("RGBA", (cols * cell_w + (cols + 1) * GAP,
                                rows * cell_h + (rows + 1) * GAP), (255, 0, 255, 255))
    for i in range(cols * rows):
        x = GAP + (i % cols) * (cell_w + GAP) + (cell_w - body.width) // 2
        y = GAP + (i // cols) * (cell_h + GAP) + (cell_h - body.height) // 2
        canvas.alpha_composite(body, (x, y))
    dest = COMFY_INPUT / (out_name + ".png")
    canvas.convert("RGB").save(dest)
    return dest, (cell_w * cols + GAP * (cols + 1), cell_h * rows + GAP * (rows + 1))


def build_prompt(entry: dict) -> str:
    """照死亡条那套已验证的结构写。

    早期版本写成「Draw the SAME effect in six separate square cells arranged in
    3 columns and 2 rows」，模型理解成「画六个带暗底板和装饰边框的独立小画格」，
    每个格子里都多出一块黑色底板——这是提示词的问题，不是素材的问题。
    改成「repeated in N identical cells on a magenta card」之后，
    模型只重画内容、不再自己加板子。
    """
    steps = entry["steps"]
    cells = " ".join("cell %d shows %s" % (i + 1, s) for i, s in enumerate(steps))
    n = len(steps)
    return (
        "Image 1 is the same effect repeated in %d identical cells on a magenta card. "
        "Redraw all %d cells as one continuous animation of that exact effect, "
        "keeping its exact shape, colors, materials and style. "
        "The %d cells are: %s. "
        "Every cell must be a visibly different frame, never a copy of another cell. "
        "The background of every cell stays the same flat magenta as the card: "
        "no panel, no plate, no frame, no border, no decorative surround, no dark backdrop, "
        "no scenery, no ground; only the effect itself is drawn on the magenta. "
        "Keep every cell clean: one effect plus small particles, no thick smoke or dust "
        "covering the whole cell. "
        "%s %s" % (n, n, n, cells, PLAN.STYLE, PLAN.BG)
    )


def run_edit(card: Path, entry: dict, seed: int) -> Path:
    name = "fx_%s_s%d" % (entry["name"], seed)
    dest = RAW / (name + ".png")
    if dest.exists():
        dest.unlink()
    wf = g.build_workflow(name, build_prompt(entry), 1024, 1024, [card.name], seed, 16, 3.0, "qwen_edit", NEG)
    # 拆掉 FluxKontextImageScale：它会把图硬拉到 ~1MP（1248×832 那一档），
    # 而 19.5GB 的 Edit 模型在 8GB 显存上每一步都要搬权重，拉到 1MP 意味着
    # 单张 3 分钟。特效最终只有 64~128px 一格，不需要 1MP，
    # 直接把原图当 latent 输入，采样面积降到 1/5，一张几十秒。
    wf.pop("11", None)
    wf["12"]["inputs"]["pixels"] = ["10", 0]
    wf["13"]["inputs"]["image1"] = ["10", 0]
    wf["14"]["inputs"]["image1"] = ["10", 0]
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
            print("FAIL", entry["name"], json.dumps(status, ensure_ascii=False)[:300], flush=True)
            return dest
        for node_out in (h[pid].get("outputs") or {}).values():
            for img in node_out.get("images", []):
                q = urllib.parse.urlencode({"filename": img["filename"],
                                           "subfolder": img.get("subfolder", ""),
                                           "type": img.get("type", "output")})
                with urllib.request.urlopen(g.HOST + "/view?" + q, timeout=120) as r:
                    dest.write_bytes(r.read())
                return dest
    print("MISS", entry["name"], flush=True)
    return dest


def cut_cells(image: Image.Image, cols: int, rows: int) -> list:
    w, h = image.size
    out = []
    for r in range(rows):
        for c in range(cols):
            x0, x1 = round(c * w / cols), round((c + 1) * w / cols)
            y0, y1 = round(r * h / rows), round((r + 1) * h / rows)
            out.append(image.crop((x0, y0, x1, y1)))
    return out


def write_strip(cells: list, entry: dict, dest: Path) -> Path:
    """切好的格子 -> 统一缩放的 N 格横条。

    关键：所有帧共用一个缩放系数和同一个落点，所以帧与帧之间的大小关系
    （爆炸变大、盾牌碎开）不会被「每帧各自裁到刚好」抹掉。
    """
    cw, ch = entry["cell"]
    keyed = [REPACK.key_bg(c.convert("RGB")) for c in cells]
    boxes = [k.getbbox() for k in keyed]
    if any(b is None for b in boxes):
        raise RuntimeError("有空格是空的: " + entry["name"])
    x0 = min(b[0] for b in boxes)
    y0 = min(b[1] for b in boxes)
    x1 = max(b[2] for b in boxes)
    y1 = max(b[3] for b in boxes)
    # 往里收 2 像素：模型偶尔在格子边缘留一条品红边，收掉它
    x0 = min(x0 + 2, x1 - 1)
    y0 = min(y0 + 2, y1 - 1)
    x1 = max(x1 - 2, x0 + 1)
    y1 = max(y1 - 2, y0 + 1)
    uw, uh = max(1, x1 - x0), max(1, y1 - y0)
    ratio = min((cw - 2) / uw, (ch - 2) / uh)
    nw, nh = max(1, round(uw * ratio)), max(1, round(uh * ratio))
    strip = Image.new("RGBA", (cw * len(keyed), ch), (0, 0, 0, 0))
    for i, k in enumerate(keyed):
        piece = k.crop((x0, y0, x1, y1)).resize((nw, nh), Image.Resampling.LANCZOS)
        px = (cw - nw) // 2
        py = (ch - nh) // 2
        if entry.get("anchor") == "bottom":
            py = ch - nh
        strip.alpha_composite(piece, (i * cw + px, py))
    dest.parent.mkdir(parents=True, exist_ok=True)
    strip.save(dest)
    return dest


def out_path(entry: dict) -> Path:
    src = ROOT / entry["src"]
    if entry["name"] == "merchant":
        return ROOT / "assets/ui/merchant_sheet.png"
    return src.parent / (src.stem + "_sheet.png")


def _signature(frame: Image.Image) -> np.ndarray:
    """帧的粗签名：16x16 灰度，用来比较两帧差别。"""
    alpha = np.array(frame.getchannel("A"))
    rgb = np.array(frame.convert("RGB")).astype(np.float32).mean(axis=2)
    m = alpha > 96
    if not m.any():
        return np.zeros(256, dtype=np.float32)
    h, w = m.shape
    ys = (np.arange(h) * 16 // h).clip(0, 15)
    xs = (np.arange(w) * 16 // w).clip(0, 15)
    idx = (ys[:, None] * 16 + xs[None, :]).reshape(-1)
    acc = np.zeros(256, dtype=np.float32)
    cnt = np.zeros(256, dtype=np.float32)
    np.add.at(acc, idx[m.reshape(-1)], rgb[m].reshape(-1))
    np.add.at(cnt, idx[m.reshape(-1)], 1.0)
    return acc / np.maximum(cnt, 1.0)


def judge(cells: list, need: int) -> tuple:
    """每格有内容，且相邻两格确实不一样。"""
    if len(cells) != need:
        return False, []
    sigs = []
    for c in cells:
        k = REPACK.key_bg(c.convert("RGB"))
        if k.getbbox() is None:
            return False, []
        sigs.append(_signature(k))
    diffs = []
    for i in range(1, len(sigs)):
        a, b = sigs[i - 1], sigs[i]
        denom = max(1e-3, (np.abs(a).sum() + np.abs(b).sum()) / 2.0)
        diffs.append(float(np.abs(a - b).sum() / denom))
    if min(diffs) < 0.02:
        return False, diffs
    return True, diffs


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="")
    ap.add_argument("--finalize-only", action="store_true")
    args = ap.parse_args()

    RAW.mkdir(parents=True, exist_ok=True)
    manifest = {}
    for idx, entry in enumerate(PLAN.ALL, 1):
        if args.only and entry["name"] != args.only:
            continue
        cols, rows = layout_for(entry)
        dest = out_path(entry)
        if args.finalize_only:
            cands = sorted(RAW.glob("fx_%s_s*.png" % entry["name"]))
            if not cands:
                print("no raw", entry["name"], flush=True)
                continue
            cells = cut_cells(REPACK.key_bg(Image.open(cands[-1]).convert("RGB")), cols, rows)
        else:
            base_seed = 8300 + idx * 53
            cells = None
            # 先看有没有已经出过的原始图：过了质检就直接用，不重复烧 GPU
            for cached in sorted(RAW.glob("fx_%s_s*.png" % entry["name"]), reverse=True):
                got = cut_cells(REPACK.key_bg(Image.open(cached).convert("RGB")), cols, rows)
                ok, diffs = judge(got, entry["frames"])
                if ok:
                    cells = got
                    print("REUSE %s %s diffs=%s" % (entry["name"], cached.name,
                          ",".join("%.3f" % d for d in diffs)), flush=True)
                    break
            if cells is None:
                card, card_size = compose_card(entry, "fxcard_%s" % entry["name"])
            for attempt in range(MAX_TRIES):
                if cells is not None:
                    break
                seed = base_seed + attempt * 137
                raw = run_edit(card, entry, seed)
                if not raw.exists():
                    break
                got = cut_cells(REPACK.key_bg(Image.open(raw).convert("RGB")), cols, rows)
                ok, diffs = judge(got, entry["frames"])
                print("%s seed=%d %s diffs=%s" % (
                    entry["name"], seed, "OK" if ok else "RETRY",
                    ",".join("%.3f" % d for d in diffs)), flush=True)
                if ok:
                    cells = got
                    break
            if cells is None:
                print("SKIP", entry["name"], "帧质检没过", flush=True)
                continue
        out = write_strip(cells, entry, dest)
        print("SHEET", entry["name"], out, Image.open(out).size, flush=True)
        manifest[entry["name"]] = {
            "sheet": str(out.relative_to(ROOT)).replace("\\", "/"),
            "frames": entry["frames"],
            "cell": list(entry["cell"]),
            "mode": entry["mode"],
        }
    if manifest:
        old = json.loads(MANIFEST.read_text(encoding="utf-8")) if MANIFEST.is_file() else {}
        old.update(manifest)
        MANIFEST.write_text(json.dumps(old, ensure_ascii=False, indent=1), encoding="utf-8")
        print("MANIFEST", MANIFEST, flush=True)


if __name__ == "__main__":
    main()
