"""一次性接线工具：把用户可见上下文里的中文字面量包上 tr()。

只处理显示上下文（.text= / text+= / show_toast / set_wave_status / set_event_status /
_make_slider_row 标签 / run_log lines.append），不碰 print/push_error 日志、
不碰 const 数据（catalog 的翻译在显示层做）。幂等：已包 tr 的跳过。
用法：python tools/wrap_i18n.py
"""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CJK = re.compile(r"[一-鿿]")
LIT = r'"(?:[^"\\]|\\.)*"'
PATTERNS = [
    re.compile(r"(\.text\s*=\s*)(" + LIT + r")"),
    re.compile(r"(text\s*\+=\s*)(" + LIT + r")"),
    re.compile(r"(show_toast\(\s*)(" + LIT + r")"),
    re.compile(r"(set_wave_status\(\s*)(" + LIT + r")"),
    re.compile(r"(set_event_status\(\s*)(" + LIT + r")"),
    re.compile(r"(_make_slider_row\(\s*\w+,\s*)(" + LIT + r")"),
    re.compile(r"(lines\.append\(\s*)(" + LIT + r")"),
    re.compile(r"(return\s+)(" + LIT + r")"),
    re.compile(r"(else\s+)(" + LIT + r")"),
    re.compile(r"(\[\"(?:badge|level_text|desc|name)\"\]\s*=\s*)(" + LIT + r")"),
    re.compile(r"(parts\.append\(\s*)(" + LIT + r")"),
    re.compile(r"(out\.append\(\s*)(" + LIT + r")"),
    re.compile(r"(\.(?:description|char_name|passive_name|passive_description)\s*=\s*)(" + LIT + r")"),
    re.compile(r"(\.text\s*=\s*)([A-Za-z_][A-Za-z0-9_]*(?:\[[^\]\n]*\])?(?:\.[A-Za-z_][A-Za-z0-9_]*)*)\s*$"),
    re.compile(r"(\.text\s*=\s*)(String\([^\n]*\))\s*$"),
    re.compile(r"(?<!tr\()(?<!translate\()(" + LIT + r")(?=\s*%)"),
    re.compile(r"(?<!tr\()(?<!translate\()(" + LIT + r")(?=\s*\+)"),
    re.compile(r"(\+\s*)(" + LIT + r")"),
    re.compile(r"(\b(?:_notify|_set_hud|_end|_tag_enemy|hint|note_build|update_blood_pact|_reward)\((?:[^)\n]*?,\s*)?)(" + LIT + r")"),
    re.compile(r"^(\s*)(" + LIT + r")(?=\s*[,%])"),
]
FILES = [
    "scripts/managers/main.gd",
    "scripts/managers/run_log.gd",
    "scripts/managers/room_event_manager.gd",
    "scripts/core/game_config.gd",
] + [str(p.relative_to(ROOT)).replace("\\", "/") for p in sorted((ROOT / "scripts" / "ui").glob("*.gd"))]


def wrap_line(line: str) -> str:
    for idx, pattern in enumerate(PATTERNS):
        def repl(match: re.Match) -> str:
            if match.lastindex == 1:
                lit = match.group(1)
                if not CJK.search(lit):
                    return match.group(0)
                return "tr(" + lit + ")"
            prefix, lit = match.group(1), match.group(2)
            # 13/14 是变量/表达式型右值：本身不含中文，靠显示上下文判定。
            if idx in (13, 14):
                if lit.startswith("tr(") or lit.startswith("TranslationServer.translate("):
                    return match.group(0)
                tail = match.group(0)[len(prefix) + len(lit):]
                return prefix + "tr(" + lit + ")" + tail
            if not CJK.search(lit):
                return match.group(0)
            return prefix + "tr(" + lit + ")"
        line = pattern.sub(repl, line)
    return line


def main() -> None:
    total = 0
    for rel in FILES:
        path = ROOT / rel
        text = path.read_text(encoding="utf-8")
        out = []
        changed = 0
        for line in text.splitlines(keepends=True):
            if "print(" in line or "push_error(" in line or "push_warning(" in line:
                out.append(line)
                continue
            new = wrap_line(line)
            if new != line:
                changed += 1
            out.append(new)
        if changed:
            path.write_text("".join(out), encoding="utf-8")
            total += changed
            print(f"{rel}: {changed} lines wrapped")
    print(f"total {total} lines")


if __name__ == "__main__":
    main()