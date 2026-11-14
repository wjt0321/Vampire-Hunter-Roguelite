"""Generate game animation asset strips via local ComfyUI.

Backends:
  qwen_t2i : Qwen-Image-2.1 turbo (text-to-image, light) -- official template wiring
  qwen_edit: Qwen-Image-Edit 2511 (identity-preserving edits of a source sheet)
  h3       : MiniMax H3-Image local w4a8 (heavy, kept for reference)

Workflow notes (2026-11-14, rebuilt from the official ComfyUI templates):
  * qwen_t2i MUST use EmptyLatentImage. EmptyQwenImageLayeredLatentImage returns a
    5D latent and the 2.1 UNET then dies with "too many values to unpack (expected 4)".
  * qwen_t2i uses the official turbo sigma schedule through ManualSigmas +
    SamplerCustomAdvanced + CFGGuider(cfg=1); a plain KSampler with 8 steps is not
    equivalent for the distilled turbo UNET.
  * qwen_t2i CLIP is qwen3vl_8b_int8_convrot (type qwen_image).
  * qwen_edit uses ModelSamplingAuraFlow(shift=3.1) + CFGNorm + VAEEncode of the
    reference image as the latent, CLIP is qwen_2.5_vl_7b_fp8_scaled.

Usage:
  python tools/gen_vhr_assets.py --name X --backend qwen_t2i --prompt "..." --width 768 --height 512
  python tools/gen_vhr_assets.py --name X --backend qwen_edit --prompt "..." --width 768 --height 512 --ref sheet.png
"""
import argparse
import json
import random
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "artifacts" / "comfy_gen"
HOST = "http://127.0.0.1:8188"

NEG_BASE = "blurry, low quality, watermark, text, signature, jpeg artifacts"

# Official Qwen-Image 2.1 turbo schedule (8 steps).
TURBO_SIGMAS = "1.0, 0.978453, 0.95418, 0.926626, 0.89508, 0.845148, 0.704534, 0.414568, 0"


def build_workflow(name, prompt, width, height, refs, seed, steps, cfg, backend="qwen_t2i", negative=NEG_BASE):
    wf = {}
    if backend == "h3":
        wf["1"] = {"class_type": "UNETLoader", "inputs": {"unet_name": "minimax_h3_image_pruned_w4a8.safetensors", "weight_dtype": "default"}}
        wf["2"] = {"class_type": "CLIPLoader", "inputs": {"clip_name": "qwen3vl_32b_minimax_h3_int8_convrot.safetensors", "type": "minimax", "device": "default"}}
        wf["3"] = {"class_type": "VAELoader", "inputs": {"vae_name": "minimax_h3_image_vae_fp16.safetensors"}}
        cond_inputs = {"clip": ["2", 0], "vae": ["3", 0], "prompt": prompt, "width": width, "height": height}
        for i, ref in enumerate(refs, start=1):
            wf["9%d" % i] = {"class_type": "LoadImage", "inputs": {"image": ref}}
            cond_inputs["image_%d" % i] = ["9%d" % i, 0]
        wf["4"] = {"class_type": "MiniMaxH3ImageConditioning", "inputs": cond_inputs}
        wf["4b"] = {"class_type": "CLIPTextEncode", "inputs": {"clip": ["2", 0], "text": negative}}
        wf["5"] = {"class_type": "KSampler", "inputs": {
            "model": ["1", 0], "seed": seed, "steps": steps, "cfg": cfg,
            "sampler_name": "euler", "scheduler": "simple",
            "positive": ["4", 0], "negative": ["4b", 0], "latent_image": ["4", 1], "denoise": 1.0}}
        wf["6"] = {"class_type": "VAEDecode", "inputs": {"samples": ["5", 0], "vae": ["3", 0]}}
        wf["7"] = {"class_type": "SaveImage", "inputs": {"images": ["6", 0], "filename_prefix": "vhr_%s" % name}}
        return wf

    if backend == "qwen_t2i":
        wf["1"] = {"class_type": "UNETLoader", "inputs": {"unet_name": "qwen_image_2.1_turbo_int8_convrot.safetensors", "weight_dtype": "default"}}
        wf["2"] = {"class_type": "CLIPLoader", "inputs": {"clip_name": "qwen3vl_8b_int8_convrot.safetensors", "type": "qwen_image", "device": "default"}}
        wf["3"] = {"class_type": "VAELoader", "inputs": {"vae_name": "qwen_image_2.1_vae_bf16.safetensors"}}
        wf["4"] = {"class_type": "TextEncodeQwenImage21", "inputs": {
            "clip": ["2", 0], "prompt": prompt, "negative_prompt": negative,
            "resolution": max(512, min(width, height)), "vae": ["3", 0]}}
        wf["5"] = {"class_type": "EmptyLatentImage", "inputs": {"width": width, "height": height, "batch_size": 1}}
        wf["6"] = {"class_type": "ManualSigmas", "inputs": {"sigmas": TURBO_SIGMAS}}
        wf["7"] = {"class_type": "KSamplerSelect", "inputs": {"sampler_name": "euler"}}
        wf["8"] = {"class_type": "RandomNoise", "inputs": {"noise_seed": seed}}
        wf["9"] = {"class_type": "CFGGuider", "inputs": {
            "model": ["1", 0], "positive": ["4", 0], "negative": ["4", 1], "cfg": 1.0}}
        wf["10"] = {"class_type": "SamplerCustomAdvanced", "inputs": {
            "noise": ["8", 0], "guider": ["9", 0], "sampler": ["7", 0],
            "sigmas": ["6", 0], "latent_image": ["5", 0]}}
        wf["11"] = {"class_type": "VAEDecode", "inputs": {"samples": ["10", 0], "vae": ["3", 0]}}
        wf["7b"] = {"class_type": "SaveImage", "inputs": {"images": ["11", 0], "filename_prefix": "vhr_%s" % name}}
        return wf

    # qwen_edit
    wf["1"] = {"class_type": "UNETLoader", "inputs": {"unet_name": "qwen_image_edit_2511_int8_convrot.safetensors", "weight_dtype": "default"}}
    wf["2"] = {"class_type": "CLIPLoader", "inputs": {"clip_name": "qwen_2.5_vl_7b_fp8_scaled.safetensors", "type": "qwen_image", "device": "default"}}
    wf["3"] = {"class_type": "VAELoader", "inputs": {"vae_name": "qwen_image_vae.safetensors"}}
    wf["4"] = {"class_type": "ModelSamplingAuraFlow", "inputs": {"model": ["1", 0], "shift": 3.1}}
    wf["5"] = {"class_type": "CFGNorm", "inputs": {"model": ["4", 0], "strength": 1.0, "pre_cfg": False}}
    wf["10"] = {"class_type": "LoadImage", "inputs": {"image": refs[0]}}
    wf["11"] = {"class_type": "FluxKontextImageScale", "inputs": {"image": ["10", 0]}}
    wf["12"] = {"class_type": "VAEEncode", "inputs": {"pixels": ["11", 0], "vae": ["3", 0]}}
    wf["13"] = {"class_type": "TextEncodeQwenImageEditPlus", "inputs": {
        "clip": ["2", 0], "prompt": prompt, "vae": ["3", 0], "image1": ["11", 0]}}
    wf["14"] = {"class_type": "TextEncodeQwenImageEditPlus", "inputs": {
        "clip": ["2", 0], "prompt": "", "vae": ["3", 0], "image1": ["11", 0]}}
    wf["5b"] = {"class_type": "KSampler", "inputs": {
        "model": ["5", 0], "seed": seed, "steps": steps, "cfg": cfg,
        "sampler_name": "euler", "scheduler": "simple",
        "positive": ["13", 0], "negative": ["14", 0], "latent_image": ["12", 0], "denoise": 1.0}}
    wf["6"] = {"class_type": "VAEDecode", "inputs": {"samples": ["5b", 0], "vae": ["3", 0]}}
    wf["7"] = {"class_type": "SaveImage", "inputs": {"images": ["6", 0], "filename_prefix": "vhr_%s" % name}}
    return wf


def post_json(path, payload):
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(HOST + path, data=data, headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            return json.loads(r.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", "replace")
        raise RuntimeError("HTTP %s: %s" % (e.code, body[:2000]))


def get_json(path):
    with urllib.request.urlopen(HOST + path, timeout=60) as r:
        return json.loads(r.read().decode("utf-8"))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--name", required=True)
    ap.add_argument("--prompt", required=True)
    ap.add_argument("--backend", default="qwen_t2i", choices=["qwen_t2i", "qwen_edit", "h3"])
    ap.add_argument("--width", type=int, default=768)
    ap.add_argument("--height", type=int, default=512)
    ap.add_argument("--ref", action="append", default=[])
    ap.add_argument("--seed", type=int, default=-1)
    ap.add_argument("--steps", type=int, default=8)
    ap.add_argument("--cfg", type=float, default=1.0)
    ap.add_argument("--negative", default=NEG_BASE)
    ap.add_argument("--timeout", type=int, default=2400)
    a = ap.parse_args()
    if a.seed < 0:
        a.seed = random.randint(0, 2**31)
    if a.backend == "qwen_edit" and not a.ref:
        raise SystemExit("qwen_edit needs --ref")
    wf = build_workflow(a.name, a.prompt, a.width, a.height, a.ref, a.seed, a.steps, a.cfg, a.backend, a.negative)
    OUT.mkdir(parents=True, exist_ok=True)
    resp = post_json("/prompt", {"prompt": wf, "client_id": "vhr_gen"})
    pid = resp["prompt_id"]
    print("prompt_id=%s seed=%d" % (pid, a.seed), flush=True)
    deadline = time.time() + a.timeout
    while time.time() < deadline:
        time.sleep(4)
        try:
            h = get_json("/history/" + pid)
        except Exception as e:
            print("poll error: %s" % e, flush=True)
            continue
        if pid not in h:
            continue
        entry = h[pid]
        status = entry.get("status", {})
        if status.get("completed") is False:
            print("ERROR: " + json.dumps(status, ensure_ascii=False), flush=True)
            sys.exit(2)
        outs = entry.get("outputs") or {}
        saved = []
        for node_out in outs.values():
            for img in node_out.get("images", []):
                q = urllib.parse.urlencode({"filename": img["filename"], "subfolder": img.get("subfolder", ""), "type": img.get("type", "output")})
                dest = OUT / (a.name + ".png")
                with urllib.request.urlopen(HOST + "/view?" + q, timeout=120) as r:
                    dest.write_bytes(r.read())
                saved.append(str(dest))
        if saved:
            print("SAVED " + ";".join(saved), flush=True)
            return
    print("TIMEOUT", flush=True)
    sys.exit(3)


if __name__ == "__main__":
    main()
