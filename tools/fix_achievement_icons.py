"""把 achievement_manager.gd 里 25 处共用的 "icon": "★" 改成各自的徽章资产名。

25 个成就共用同一个 "★" 字符是"只有字没有图"的根源之一：
结算界面把 info["icon"] 直接拼进文字里，于是整列都是同一个星号。
改成 "ach_<成就id>" 之后，icon 字段指向真实贴图资产。

用法: python tools/fix_achievement_icons.py
"""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TARGET = ROOT / "scripts" / "managers" / "achievement_manager.gd"

PAT = re.compile(
    r'("(?P<aid>[a-z_]+)": \{\s*\n'
    r'\s*"name": "[^"]*",\s*\n'
    r'\s*"description": "[^"]*",\s*\n'
    r'\s*"icon": )"★"'
)


def main() -> None:
    src = TARGET.read_text(encoding="utf-8")
    hits: list[str] = []

    def repl(m: re.Match) -> str:
        hits.append(m.group("aid"))
        return f'{m.group(1)}"ach_{m.group("aid")}"'

    out = PAT.sub(repl, src)
    if not hits:
        print("没有匹配到任何 \"icon\": \"★\"（可能已经改过了）")
        return
    TARGET.write_text(out, encoding="utf-8")
    print(f"改写 {len(hits)} 条:")
    for h in hits:
        print(f"  {h} -> ach_{h}")


if __name__ == "__main__":
    main()
