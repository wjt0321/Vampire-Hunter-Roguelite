#!/usr/bin/env python
"""校验站点引用的每个本地资源都真实存在。

跑法：python tools/check_site_links.py
"""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SITE = ROOT / "site"

HTML_REFS = re.compile(r'(?:src|href)="([^"#]+)"')
CSS_URL_RE = re.compile(r"url\(([^)]+)\)")


def main() -> None:
    problems: list[str] = []
    checked = 0

    html = (SITE / "index.html").read_text(encoding="utf-8")
    for ref in HTML_REFS.findall(html):
        if ref.startswith(("http://", "https://", "mailto:", "#")):
            continue
        checked += 1
        if not (SITE / ref).exists():
            problems.append(f"index.html -> {ref}")

    for css in sorted((SITE / "assets" / "css").glob("*.css")):
        for ref in CSS_URL_RE.findall(css.read_text(encoding="utf-8")):
            ref = ref.strip("'\"")
            if ref.startswith(("http", "data:")):
                continue
            checked += 1
            if not (css.parent / ref).resolve().exists():
                problems.append(f"{css.name} -> {ref}")

    js_path = SITE / "assets" / "js" / "main.js"
    js = js_path.read_text(encoding="utf-8")
    for ref in re.findall(r"'assets/[^']+'", js):
        # 以 _ 结尾的是拼接前缀（'...ach_' + name + '.png'），由下面的成就名校验覆盖
        if ref.rstrip("'").endswith("_"):
            continue
        checked += 1
        if not (SITE / ref.strip("'")).exists():
            problems.append(f"main.js -> {ref}")

    if "var names = [" in js:
        block = js.split("var names = [")[1].split("]")[0]
        for name in re.findall(r"'([a-z_]+)'", block):
            checked += 1
            p = SITE / "assets" / "img" / "achievements" / f"ach_{name}.png"
            if not p.exists():
                problems.append(f"main.js 成就徽章 -> ach_{name}.png")

    tmp = SITE / "_spritecheck.html"
    if tmp.exists():
        tmp.unlink()
        print("removed temporary file:", tmp.name)

    print(f"checked={checked} problems={len(problems)}")
    for p in problems:
        print("  MISSING:", p)
    raise SystemExit(1 if problems else 0)


if __name__ == "__main__":
    main()
