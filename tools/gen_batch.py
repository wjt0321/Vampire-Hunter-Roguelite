"""Batch driver: sequential generation from a manifest JSON.

Each manifest item: {"name","prompt","width","height","refs":[...],"seed","steps","cfg"}
Skips items whose output already exists (resume-safe).
"""
import argparse
import json
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import gen_vhr_assets as g

def run_item(item):
    dest = g.OUT / (item["name"] + ".png")
    if dest.exists():
        print("SKIP %s (exists)" % item["name"], flush=True)
        return True
    wf = g.build_workflow(item["name"], item["prompt"], item["width"], item["height"],
                          item.get("refs", []), item.get("seed", 0), item.get("steps", 8),
                          item.get("cfg", 1.0), item.get("backend", "qwen_t2i"),
                          item.get("negative", g.NEG_BASE))
    resp = g.post_json("/prompt", {"prompt": wf, "client_id": "vhr_gen"})
    pid = resp["prompt_id"]
    t0 = time.time()
    print("RUN %s pid=%s" % (item["name"], pid), flush=True)
    deadline = time.time() + item.get("timeout", 2400)
    while time.time() < deadline:
        time.sleep(5)
        try:
            h = g.get_json("/history/" + pid)
        except Exception as e:
            print("poll error %s: %s" % (item["name"], e), flush=True)
            continue
        if pid not in h:
            continue
        entry = h[pid]
        status = entry.get("status", {})
        if status.get("completed") is False:
            print("FAIL %s: %s" % (item["name"], json.dumps(status, ensure_ascii=False)[:800]), flush=True)
            return False
        outs = entry.get("outputs") or {}
        got = False
        for node_out in outs.values():
            for img in node_out.get("images", []):
                q = urllib.parse.urlencode({"filename": img["filename"], "subfolder": img.get("subfolder", ""), "type": img.get("type", "output")})
                with urllib.request.urlopen(g.HOST + "/view?" + q, timeout=60) as r:
                    dest.write_bytes(r.read())
                got = True
        if got:
            print("OK %s (%.0fs)" % (item["name"], time.time() - t0), flush=True)
            return True
    print("TIMEOUT %s" % item["name"], flush=True)
    return False

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--manifest", required=True)
    a = ap.parse_args()
    items = json.loads(Path(a.manifest).read_text(encoding="utf-8"))
    failed = []
    for item in items:
        try:
            if not run_item(item):
                failed.append(item["name"])
        except Exception as e:
            print("ERROR %s: %s" % (item["name"], e), flush=True)
            failed.append(item["name"])
    print("BATCH DONE ok=%d failed=%s" % (len(items) - len(failed), ",".join(failed) or "-"), flush=True)
    sys.exit(1 if failed else 0)

if __name__ == "__main__":
    main()