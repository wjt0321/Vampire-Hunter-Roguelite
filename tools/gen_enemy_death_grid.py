"""重做新敌人的死亡条：让 6 帧真的在演塌倒。

关键做法（pilot 已验证）：
  用同一张立绘拼成 3x2 品红底网格当编辑源图，Qwen-Image-Edit 会把网格里每一格
  画成不同的倒地阶段，而不是 6 格复制同一张尸体。

流程：
  立绘原图 -> 拼 3x2 网格 -> 图像编辑 -> 切 3x2 -> 缩到 56px -> 拼成 336x56

两道保险：
  1. 提示词逐格点名（第 1 格画什么、第 2 格画什么……），并明确后三格角色已经倒下。
  2. 自动质检：量每格主体的"站高比"（本体连通域的高/格高），
     必须大致单调下降，否则换种子重跑。
"""
from __future__ import annotations

import json
import sys
import zlib
import time
import urllib.parse
import urllib.request
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
sys.path.insert(0, str(ROOT / ".workbuddy" / "comfy"))
import gen_vhr_assets as g
import reskin_pipeline as RP
import death_repack as REPACK

OUT = ROOT / "artifacts" / "iteration_assets"
RAW = OUT
INPUT = Path(r"E:/AI/ComfyUI/input")
DEST = ROOT / "assets" / "sprites" / "enemies"

DEATH_STEPS = {
    "shield_guard": "1 staggering backward as the shield buckles, 2 dropping to one knee with the axe falling away, 3 pitching forward onto both hands, 4 lying prone on the ground while sparks and ash burst from the seams of the armor, 5 the plate armor cracking apart into rising ash, 6 only a heap of broken plates and cold embers left on the ground",
    "blood_priest": "1 the blood candle bursting into red flame, 2 thrown backward as the flames flare, 3 dropping to the knees, 4 lying collapsed on the ground with the robe catching dark red flame, 5 the body crumbling into rising ash, 6 a flat blackened robe and a snuffed-out candle lying on the ground",
    "web_weaver": "1 the whole body thrashing with the legs scrambling, 2 the eight legs folding and going limp, 3 the body curling into a tight ball as the silk sac swells, 4 the pale silk sac rupturing and spraying sticky silk across the floor, 5 the body drying out and shrinking low to the ground, 6 only a dry husk of the spider and a puddle of sticky silk left",
    "coffin_guard": "1 the coffin lid lurching sideways and the bone arm falling out, 2 the coffin tipping over at an angle, 3 the whole coffin crashing down onto its side, 4 the lid sliding off and the bones scattering out on the ground, 5 the planks splintering apart flat on the ground, 6 only scattered rotten boards and a heap of bones left",
    "blood_hound": "1 lunging forward and missing, 2 crashing onto its side, 3 rolling onto its back and kicking its legs, 4 lying still and panting with blood at the mouth, 5 the blood running out and the fur drying and shrinking, 6 only matted bloody fur and a bare ribcage left",
    "furnace_golem": "1 the furnace fire surging out of the open chest, 2 the iron plates splitting and spitting sparks, 3 the whole construct dropping to its knees as the pipes snap, 4 the fire dying out and only black smoke rising, 5 the body collapsing into a heap of iron rubble, 6 only a heap of cold iron blocks and dying embers left",
    "burrower": "1 the body rearing up as the forelimbs start digging into the dirt, 2 clawing into the ground and throwing soil backward while its head dips down, 3 the head and shoulders sinking down into the hole, 4 the body sinking further in so only the upper shell shows above the rim of the hole, 5 almost entirely swallowed by the earth leaving only the cracked shell edge showing, 6 only a small mound of disturbed earth and scattered pebbles left where it went down",
    "gem_leech": "1 the embedded gemstone flaring bright while the spider rears up on its legs, 2 the legs buckling and the body pitching forward and down, 3 the body collapsing onto its front with the crystal carapace cracking, 4 the crystal shell shattering into violet shards as the body slumps down, 5 the segmented body drying out and caving in, shrinking low and flat, 6 only a flat collapsed husk and a few violet crystal shards lying low",
    "lantern_wraith": "1 the lantern flame flaring up and lighting the shroud, 2 the ghostly body turning transparent, 3 the lantern slipping out of the hands, 4 the whole wraith collapsing into grey mist on the ground, 5 the mist drifting apart and thinning low, 6 only the rusted lantern lying on the ground with its flame dead",
    "alchemist_pitcher": "1 the vial slipping from the hand and shattering, 2 amber liquid spilling as the body staggers back, 3 falling to the knees, 4 the wicker basket falling and the vials rolling out, 5 the body crumbling into ash, 6 only broken vials and spilled amber liquid left on the floor",
    "resonance_mage": "1 the violet crystal orb shattering with shards flying, 2 the violet light blasting back into the caster, 3 the body arching backward, 4 the deep purple robe catching violet flame as the caster falls, 5 the body turning to violet-grey ash, 6 only broken crystal shards and a heap of ash left",
    "moon_wing": "1 the skeletal wings spasming as the body drops out of the air, 2 the body hitting the ground and toppling sideways, 3 the body lying on its side with the wings flapping weakly, 4 one wing bone snapping and the wing drooping flat to the ground, 5 the body curling up and shrinking low, 6 only a curled wing and a patch of moon-white fur lying on the ground",
}

NEG = ("blurry, low quality, watermark, text, signature, jpeg artifacts, 3d render, "
       "photorealistic, smooth gradients, chibi, cute, cartoon, anime, modern clothing, "
       "sci-fi, green color on the character, bright cheerful colors")

MAX_TRIES = 3

# 个别角色的专属补充约束。
# gem_leech 之前三次都被判不合格：模型给每一格都画了一片贴地的泥土，
# 泥土与角色连成一个连通域，"站高比"永远测不出塌陷。
# 判据本身没错，错在提示词让模型画了地面。改成"不许画地面"，几何量就重新有效。
EXTRA_RULES = {
    "gem_leech": (
        "Do not draw any ground, dirt, soil, mud or rubble under the character; "
        "the background of every cell must stay completely empty flat magenta "
        "except for the character itself and a few small shards."
    ),
}


def compose_grid(sheet_path: Path, out_name: str, cols: int = 3, rows: int = 2, cell_px: int = 384) -> Path:
    keyed = RP.key_magenta(Image.open(sheet_path).convert("RGB"))
    box = keyed.getbbox()
    body = keyed.crop(box) if box else keyed
    gap = 8
    canvas = Image.new("RGBA", (cols * cell_px + (cols + 1) * gap, rows * cell_px + (rows + 1) * gap), (255, 0, 255, 255))
    scale = min((cell_px - 12) / body.width, (cell_px - 12) / body.height)
    body = body.resize((max(1, round(body.width * scale)), max(1, round(body.height * scale))), Image.Resampling.LANCZOS)
    for i in range(cols * rows):
        x = gap + (i % cols) * (cell_px + gap) + (cell_px - body.width) // 2
        y = gap + (i // cols) * (cell_px + gap) + (cell_px - body.height) // 2
        canvas.alpha_composite(body, (x, y))
    dest = INPUT / (out_name + ".png")
    canvas.convert("RGB").save(dest)
    return dest


def body_metrics(frame: Image.Image) -> tuple:
    """返回 (站高比, 顶边位置)：本体连通域的高/格高、本体顶边/格高。"""
    import cv2

    alpha = np.array(frame.getchannel("A"))
    solid = (alpha > 96).astype(np.uint8)
    n, _, stats, _ = cv2.connectedComponentsWithStats(solid, 8)
    if n <= 1:
        return 0.0, 1.0
    idx = 1 + int(np.argmax(stats[1:, cv2.CC_STAT_AREA]))
    h = int(stats[idx, cv2.CC_STAT_HEIGHT])
    top = int(stats[idx, cv2.CC_STAT_TOP])
    return h / max(1, frame.height), top / max(1, frame.height)


def judge(frames: list) -> tuple:
    """帧序质检：主体必须大致单调降低，且最后一格明显低于第一格。"""
    ratios = []
    tops = []
    for f in frames:
        r, t = body_metrics(f)
        ratios.append(r)
        tops.append(t)
    if len(frames) != 6 or any(r == 0.0 for r in ratios):
        # 有空格（模型画了一格纯背景）或帧数不对，都判不合格
        return False, ratios, tops
    # 末帧必须明显比首帧低（角色真的倒下去了/沉下去了）
    dropped = len(ratios) >= 2 and ratios[-1] <= ratios[0] - 0.25
    # 竖立型角色（吞晶虫那种头朝上的虫）塌不下去，但顶端会明显下移，
    # 这也算"倒伏"，用顶边位置判定。
    top_dropped = len(tops) >= 2 and tops[-1] >= tops[0] + 0.15
    if not (dropped or top_dropped):
        return False, ratios, tops
    # 中途允许小幅回弹（蠕虫翻身、翅膀扑腾都会短暂"变高"），
    # 但不允许大幅回升：回升说明模型又画了一个站立帧。
    for i in range(1, len(ratios) - 1):
        if ratios[i] > ratios[i - 1] + 0.22:
            return False, ratios, tops
    return True, ratios, tops


def build_prompt(enemy_id: str) -> str:
    steps = DEATH_STEPS[enemy_id].split(", ")
    cells = []
    for i, s in enumerate(steps):
        cells.append("cell %d shows %s" % (i + 1, s[2:] if s[:2].isdigit() else s))
    return (
        "Image 1 is the same character repeated in six identical cells on a magenta card. "
        "Redraw all six cells as one continuous death animation of that exact character, "
        "keeping its exact design, colors and proportions. "
        "Draw exactly 3 columns and 2 rows, six equal square cells, reading order left to right then top to bottom. "
        "The six cells are: "
        + ". ".join(cells) + ". "
        "Every cell must be a visibly different pose, never a copy of another cell. "
        "The character must get progressively lower and more collapsed in every later cell; "
        "in cells 4, 5 and 6 the character is already down on the ground, never standing upright. "
        "Cell 6 shows only flat remains lying on the ground: broken pieces, ash, cloth or bones "
        "spread low, no upright body, no standing figure, nothing taller than the debris pile. "
        "Keep every cell clean: one character plus small sparks, no thick smoke or dust clouds "
        "covering the background, no overlapping artwork between cells. "
        "Dark gothic fantasy pixel art, chunky visible pixels, limited 32-color palette, "
        "brushed dark steel and worn leather, antique gold filigree trim, deep crimson gems, "
        "crisp 2px black outline, high contrast. "
        "Each cell holds exactly one full character, feet anchored at the same height in every cell, "
        "the character filling at most 80 percent of its cell and never crossing the cell border. "
        "Flat solid pure magenta #FF00FF background, uniform bright magenta color card, no gradient, "
        "no shadow on the background, no text, no grid lines, no smoke or haze in the background."
        + (" " + EXTRA_RULES[enemy_id] if enemy_id in EXTRA_RULES else "")
    )


def run_edit(grid: Path, enemy_id: str, seed: int) -> Path:
    name = "deathgrid_%s_s%d" % (enemy_id, seed)
    dest = RAW / (name + ".png")
    # 不复用旧缓存：同一颗种子出的图如果帧序不合格，重跑也还是不合格，
    # 必须换种子。先删掉再出图。
    if dest.exists():
        dest.unlink()
    prompt = build_prompt(enemy_id)
    wf = g.build_workflow(name, prompt, 1152, 768, [grid.name], seed, 16, 3.0, "qwen_edit", NEG)
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
            print("FAIL", enemy_id, json.dumps(status, ensure_ascii=False)[:400])
            return dest
        for node_out in (h[pid].get("outputs") or {}).values():
            for img in node_out.get("images", []):
                q = urllib.parse.urlencode({"filename": img["filename"], "subfolder": img.get("subfolder", ""), "type": img.get("type", "output")})
                with urllib.request.urlopen(g.HOST + "/view?" + q, timeout=120) as r:
                    dest.write_bytes(r.read())
                return dest
    print("MISS", enemy_id)
    return dest


def main() -> None:
    ids = sys.argv[1:] or list(DEATH_STEPS.keys())
    for enemy_id in ids:
        sheet = RAW / (enemy_id + "_idle.png")
        if not sheet.exists():
            print("no sheet", enemy_id)
            continue
        grid = compose_grid(sheet, "deathgrid_" + enemy_id)
        base_seed = 7000 + (zlib.crc32(enemy_id.encode("utf-8")) % 900)
        chosen = None
        # 先认领已经生成过且质检合格的网格，避免重复出图。
        candidates = sorted(RAW.glob("deathgrid_%s_s*.png" % enemy_id))
        for cand in candidates:
            keyed = REPACK.key_bg(Image.open(cand).convert("RGB"))
            frames = REPACK.cut_grid(keyed, 3, 2)
            ok, ratios, tops = judge(frames)
            if ok:
                print(enemy_id, "reuse", cand.name,
                      "h=" + ",".join("%.2f" % r for r in ratios))
                chosen = frames
                break
        for attempt in range(MAX_TRIES):
            if chosen is not None:
                break
            seed = base_seed + attempt * 137
            raw = run_edit(grid, enemy_id, seed)
            if not raw.exists():
                break
            keyed = REPACK.key_bg(Image.open(raw).convert("RGB"))
            frames = REPACK.cut_grid(keyed, 3, 2)
            ok, ratios, tops = judge(frames)
            print(enemy_id, "seed", seed, "ok" if ok else "RETRY",
                  "h=" + ",".join("%.2f" % r for r in ratios),
                  "top=" + ",".join("%.2f" % t for t in tops))
            if ok:
                chosen = frames
        if chosen is None:
            print("SKIP", enemy_id, "帧序质检没过")
            continue
        strip = REPACK.pack(chosen, 56)
        out = DEST / enemy_id / "death.png"
        out.parent.mkdir(parents=True, exist_ok=True)
        strip.save(out)
        print("OK", enemy_id, out, strip.size)


if __name__ == "__main__":
    main()
