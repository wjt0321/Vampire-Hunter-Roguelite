r"""为迭代新增的敌人生成专属精灵条。

复用 MVP 已验收的管线（.workbuddy/comfy/reskin_pipeline.py）：
  * ComfyUI 工作流：E:\AI\ComfyUI\user\default\workflows\图片_Qwen-Image2.1_*.json
  * 风格：用户认可的 vhr_reskin 源图那一套（暗哥特像素画、金边红宝石、正面全身、品红抠底）
  * 后处理：品红抠底 -> 紫边清理 -> NEAREST 缩到 56px 单格 -> 提亮 -> 32 色 -> 程序化错帧

产物：
  * 原图：E:\AI\ComfyUI\output\vhr_iter\<asset>_00001.png
  * 成品：assets/sprites/enemies/<asset>.png

用法：
  python tools/gen_iteration_sprites.py --only shield_guard_idle
  python tools/gen_iteration_sprites.py --plan <plan.json> [--finalize-only]
"""
from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / ".workbuddy" / "comfy"))
sys.path.insert(0, str(ROOT / "tools"))
import reskin_pipeline as RP          # noqa: E402  已验证的抠底 / 紫边清理 / 缩格 / 提亮
import build_pose_strips as strips    # noqa: E402  已验证的程序化错帧

WF_T2I = Path(r"E:\AI\ComfyUI\user\default\workflows\图片_Qwen-Image2.1_文生图.json")
WF_EDIT = Path(r"E:\AI\ComfyUI\user\default\workflows\图片_Qwen-Image2.1_图像编辑.json")
COMFY = r"E:\AI\comfy-mcp-env\Scripts\comfy.exe"
COMFY_INPUT = Path(r"E:\AI\ComfyUI\input")
COMFY_OUTPUT = Path(r"E:\AI\ComfyUI\output\vhr_iter")
RAW = ROOT / "artifacts" / "iteration_assets"
WF_DIR = ROOT / "artifacts" / "iteration_assets" / "workflows"
LOG = ROOT / "artifacts" / "iteration_assets" / "gen.log"
ASSETS = ROOT / "assets" / "sprites" / "enemies"

PROMPT_NODE, RESOLUTION_NODE, SAVE_NODE = 459, 13, 461
LOAD1, LOAD2 = 470, 475

STYLE_DESC = (
    "dark gothic fantasy pixel art, chunky visible pixels, limited 32-color palette, "
    "brushed dark steel and worn leather, antique gold filigree trim, deep crimson gems, "
    "high contrast with dramatic rim light, crisp 2px black outline, dense micro-detail, "
    "muted desaturated shadows with a few saturated accents"
)
PROPORTION = (
    "Mature heroic proportions, about 6 heads tall, narrow waist and broad shoulders. "
    "NOT chibi, NOT super-deformed, no oversized head, no big cute eyes, no toy-like look."
)
NEG_T2I = (
    "photo, realistic, 3d render, smooth gradients, gradient background, drop shadow, "
    "multiple characters, cropped, text, watermark, frame, border, motion blur, "
    "jpeg artifacts, extra limbs, blurry, soft focus, chibi, cute, super deformed, "
    "big head, oversized head, big eyes, cartoon, childlike, toy-like, flat pastel colors, "
    "bright cheerful colors, neon glow, lens flare"
)


def log(line: str) -> None:
    text = f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] {line}"
    print(text, flush=True)
    LOG.parent.mkdir(parents=True, exist_ok=True)
    with LOG.open("a", encoding="utf-8") as f:
        f.write(text + "\n")


def stable_seed(name: str) -> int:
    return int(hashlib.sha256(("vhr-iter:" + name).encode()).hexdigest()[:12], 16) % (2 ** 31)


def build_t2i(asset: str, prompt: str, steps: int = 25, megapixels: float = 1.0) -> Path:
    data = json.loads(WF_T2I.read_text(encoding="utf-8"))
    nodes = {n["id"]: n for n in data["nodes"]}
    p = nodes[PROMPT_NODE]["widgets_values"]
    p[0] = prompt
    p[1] = NEG_T2I
    p[3] = steps
    p[8] = stable_seed(asset)
    nodes[RESOLUTION_NODE]["widgets_values"] = ["1:1 (Square)", megapixels, 8]
    nodes[SAVE_NODE]["widgets_values"][0] = f"vhr_iter\\{asset}"
    WF_DIR.mkdir(parents=True, exist_ok=True)
    out = WF_DIR / f"iter_{asset}.json"
    out.write_text(json.dumps(data, ensure_ascii=False), encoding="utf-8")
    return out


def build_edit(asset: str, prompt: str, style_name: str, char_name: str, steps: int = 25) -> Path:
    data = json.loads(WF_EDIT.read_text(encoding="utf-8"))
    nodes = {n["id"]: n for n in data["nodes"]}
    p = nodes[PROMPT_NODE]["widgets_values"]
    p[1] = prompt
    p[2] = NEG_T2I
    p[4] = steps
    p[10] = stable_seed(asset)
    nodes[LOAD1]["widgets_values"][0] = style_name
    nodes[LOAD2]["widgets_values"][0] = char_name
    nodes[SAVE_NODE]["widgets_values"][0] = f"vhr_iter\\{asset}"
    WF_DIR.mkdir(parents=True, exist_ok=True)
    out = WF_DIR / f"iter_{asset}.json"
    out.write_text(json.dumps(data, ensure_ascii=False), encoding="utf-8")
    return out


def prepare_style_ref() -> str:
    """image_1：用户已认可的 1024 风格锚（与 MVP reskin 管线完全一致）。"""
    src = ROOT / ".workbuddy" / "backup" / "icons" / "icon_pistol.png"
    im = Image.open(src).convert("RGBA")
    bg = Image.new("RGBA", im.size, (26, 10, 26, 255))
    bg.alpha_composite(im)
    name = "vhr_iter_style_ref.png"
    bg.convert("RGB").save(COMFY_INPUT / name)
    return name


def prepare_char_ref(asset: str, source_sheet: str) -> str:
    """image_2：造型/剪影参考。

    "raw:<name>" = 直接用本批次刚出的 1024 原图当造型锚（死亡姿态靠它保持同一只怪）；
    其他 = 取仓库里已有精灵的最近邻放大版。
    """
    if source_sheet.startswith("raw:"):
        src = RAW / (source_sheet[4:] + ".png")
        name = f"vhr_iter_char_{asset}.png"
        shutil.copy2(src, COMFY_INPUT / name)
        return name
    src = ROOT / "assets" / "sprites" / "enemies" / source_sheet
    im = Image.open(src).convert("RGBA")
    cell = im.height
    frame = im.crop((0, 0, cell, cell))
    bg = Image.new("RGBA", frame.size, (26, 10, 26, 255))
    bg.alpha_composite(frame)
    scale = min(16, max(1, 1024 // cell))
    name = f"vhr_iter_char_{asset}.png"
    bg.resize((cell * scale, cell * scale), Image.Resampling.NEAREST).convert("RGB").save(COMFY_INPUT / name)
    return name


def run_comfy(wf: Path, asset: str) -> Path:
    COMFY_OUTPUT.mkdir(parents=True, exist_ok=True)
    before = {p.name for p in COMFY_OUTPUT.glob(f"{asset}_*.png")}
    t0 = time.time()
    log(f"{asset} SUBMIT {wf.name}")
    proc = subprocess.run(
        [COMFY, "run", "--workflow", str(wf), "--wait", "--no-notify",
         "--where", "local", "--timeout", "420"],
        capture_output=True, text=True, timeout=900,
    )
    log(f"{asset} COMFY rc={proc.returncode} secs={time.time() - t0:.1f} "
        f"err={proc.stderr.strip()[-200:]!r}")
    RAW.mkdir(parents=True, exist_ok=True)
    cached = RAW / f"{asset}.png"
    new = [p for p in COMFY_OUTPUT.glob(f"{asset}_*.png")
           if p.name not in before and p.stat().st_mtime >= t0 - 2]
    if new:
        src = max(new, key=lambda p: p.stat().st_mtime)
        shutil.copy2(src, cached)
        return cached
    if cached.exists():
        log(f"{asset} cache hit")
        return cached
    raise RuntimeError(f"{asset}: 没有新输出\n{proc.stdout[-800:]}\n{proc.stderr[-800:]}")


def make_frames(cell_im: Image.Image, frames: int, cell: int, motion: str) -> list:
    def fit(fs):
        if len(fs) >= frames:
            return fs[:frames]
        return (fs + [fs[-1]] * (frames - len(fs))) if fs else []

    if motion == "corpse":
        # 尸体：逐帧下沉 + 变暗，最后一帧彻底消失
        out = []
        for i in range(frames):
            t = i / max(1, frames - 1)
            alpha = int(round(255 * (1.0 - 0.15 * t)))
            frame = strips.blank(cell)
            ghost = cell_im.copy()
            band = ghost.getchannel("A").point(lambda a, k=alpha: a * k // 255)
            ghost.putalpha(band)
            dark = ghost.convert("RGB").point(lambda v: int(v * (1.0 - 0.35 * t)))
            ghost = Image.merge("RGBA", (*dark.split(), band))
            ox, oy = strips.centered_origin(ghost, cell)
            strips.blit(frame, ghost, ox, oy + int(round(2 * t)))
            out.append(frame)
        return out
    if motion in ("run", "walk"):
        return fit(strips.step_cycle(cell_im, frames, cell))
    if motion in ("lunge", "attack", "charge"):
        return fit(strips.lunge(cell_im, cell))
    return fit(strips.idle_cloak(cell_im, cell))


def finalize(src: Path, asset: str, cell: int, frames: int, motion: str, dst: Path | None = None) -> Path:
    keyed = RP.purge_purple_edge(RP.key_magenta(Image.open(src).convert("RGB")))
    base = RP.to_cell(keyed, cell)
    base = RP.lift_luma(base)
    base = RP.purge_purple_edge(base)
    out_frames = make_frames(base, frames, cell, motion)
    strip = Image.new("RGBA", (cell * frames, cell), (0, 0, 0, 0))
    for i, f in enumerate(out_frames):
        strip.alpha_composite(f.convert("RGBA"), (i * cell, 0))
    if dst is None:
        # 新敌人走专属目录：assets/sprites/enemies/<enemy_id>/<state>.png
        if "_" in asset:
            enemy_id, state = asset.rsplit("_", 1)
            if state in ("idle", "run", "walk", "attack", "death", "hurt"):
                dst = ASSETS / enemy_id / f"{state}.png"
            else:
                dst = ASSETS / f"{asset}.png"
        else:
            dst = ASSETS / f"{asset}.png"
    dst.parent.mkdir(parents=True, exist_ok=True)
    strip.save(dst)
    log(f"{asset} STRIP {dst} size={strip.size}")
    return dst


def finalize_icon(src: Path, dest: Path, cell: int = 48) -> Path:
    """图标：品红抠底 -> 缩到 cell -> 限色 -> 黑描边，输出单张。
    描边用 1px（32/48px 下再粗就会糊），量化用固定哥特调色板，保证整套不偏色。
    """
    import cv2
    import numpy as np
    from postprocess import PALETTE, OUTLINE_COLOR
    keyed = RP.purge_purple_edge(RP.key_magenta(Image.open(src).convert("RGB")))
    box = keyed.getbbox()
    if box is None:
        raise RuntimeError("抠底之后是空的: " + str(src))
    im = keyed.crop(box)
    usable = cell - 4
    ratio = min(usable / im.width, usable / im.height)
    nw, nh = max(1, round(im.width * ratio)), max(1, round(im.height * ratio))
    small = im.resize((nw, nh), Image.Resampling.LANCZOS)
    arr = np.array(small.convert("RGBA"))
    arr[:, :, 3] = np.where(arr[:, :, 3] > 127, 255, 0).astype(np.uint8)
    rgb = arr[:, :, :3].astype(np.float32)
    pal = PALETTE.astype(np.float32)
    idx = ((rgb[:, :, None, :] - pal[None, None, :, :]) ** 2).sum(axis=3).argmin(axis=2)
    arr[:, :, :3] = PALETTE[idx].astype(np.uint8)
    canvas = np.zeros((cell, cell, 4), dtype=np.uint8)
    ox, oy = (cell - nw) // 2, (cell - nh) // 2
    placed = np.zeros((cell, cell, 4), dtype=np.uint8)
    placed[oy:oy + nh, ox:ox + nw] = arr
    a = placed[:, :, 3]
    dil = cv2.dilate(a, np.ones((3, 3), np.uint8), iterations=1)
    ring = (dil > 0) & (a == 0)
    canvas[ring] = OUTLINE_COLOR
    canvas[a > 0] = placed[a > 0]
    out = Image.fromarray(canvas, "RGBA")
    dest.parent.mkdir(parents=True, exist_ok=True)
    out.save(dest)
    log(f"ICON {dest} size={out.size}")
    return dest


def process(item: dict) -> None:
    asset = item["asset"]
    if item.get("mode") == "edit":
        style = prepare_style_ref()
        char = prepare_char_ref(asset, item["char_ref"])
        # "swap" = image_1 放角色、image_2 放风格锚；否则沿用 MVP 的 image_1 风格 / image_2 角色
        if item.get("swap"):
            wf = build_edit(asset, item["prompt"], char, style, item.get("steps", 25))
        else:
            wf = build_edit(asset, item["prompt"], style, char, item.get("steps", 25))
    else:
        wf = build_t2i(asset, item["prompt"], item.get("steps", 25), item.get("megapixels", 1.0))
    src = run_comfy(wf, asset)
    if item.get("kind") == "icon":
        dest = Path(item["dest"]) if item.get("dest") else (ROOT / item["out"] / (asset + ".png"))
        finalize_icon(src, dest, item.get("cell", 48))
        return
    finalize(src, asset, item.get("cell", 56), item.get("frames", 4), item.get("motion", "idle"))


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--plan", required=True)
    ap.add_argument("--only", default="")
    ap.add_argument("--finalize-only", action="store_true")
    args = ap.parse_args()
    plan = json.loads(Path(args.plan).read_text(encoding="utf-8"))
    todo = [x for x in plan if not args.only or x["asset"] == args.only]
    log(f"ITER BATCH START total={len(todo)}")
    for i, item in enumerate(todo, 1):
        log(f"--- {i}/{len(todo)} ---")
        try:
            if args.finalize_only:
                src = RAW / f"{item['asset']}.png"
                if src.exists():
                    finalize(src, item["asset"], item.get("cell", 56), item.get("frames", 4), item.get("motion", "idle"))
                else:
                    log(f"{item['asset']} no raw, skipped")
            else:
                process(item)
        except Exception as exc:  # noqa: BLE001
            log(f"{item['asset']} FAILED {exc!r}")
    log("ITER BATCH COMPLETE")


if __name__ == "__main__":
    main()
