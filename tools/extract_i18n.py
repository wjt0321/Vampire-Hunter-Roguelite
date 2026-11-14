"""扫描 scripts/ 下所有 tr("...") 键，生成/合并 i18n CSV 骨架。

用法：python tools/extract_i18n.py
- 键 = 中文源串；zh_CN 列 = 键本身；en 列保留已有翻译，新键留空待填。
- 只扫 tr("字面量")，不扫变量拼接（拼接串在接线时已改成 tr 格式串）。
"""
from __future__ import annotations

import csv
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CSV_PATH = ROOT / "i18n" / "game.csv"
TR_RE = re.compile(r'\b(?:tr|TranslationServer\.translate)\(\s*"((?:[^"\\]|\\.)*)"')
LIT_RE = re.compile(r'"((?:[^"\\]|\\.)*[一-鿿](?:[^"\\]|\\.)*)"')
TITLE_RE = re.compile(r'(?:boss_title|enemy_name)\s*=\s*"((?:[^"\\]|\\.)*[一-鿿](?:[^"\\]|\\.)*)"')
# 数据表里的中文（目录/图鉴/成就/词缀/每日词缀/房间标签）经 tr(变量) 显示，
# 字面量不在 tr() 里，必须按文件白名单收进键表。
DATA_FILES = {
    "scripts/core/item_catalog.gd",
    "scripts/core/asset_slots.gd",
    "scripts/core/game_config.gd",
    "scripts/weapons/weapon_fusion.gd",
    "scripts/managers/achievement_manager.gd",
    "scripts/enemies/elite_affix.gd",
    "scripts/player/character_data.gd",
    "scripts/map/dungeon_manager.gd",
    "scripts/weapons/weapon_data.gd",
    "scripts/ui/upgrade_shop.gd",
}


def unescape(s: str) -> str:
    # 源码字面量里的 \n 是转义写法，运行时键是真 newline，CSV 必须存真字符。
    return re.sub(r"\\(.)", lambda m: {"n": "\n", "t": "\t", "r": "\r", '"': '"', "\\": "\\"}.get(m.group(1), m.group(0)), s)


def main() -> None:
    keys: list[str] = []
    seen: set[str] = set()

    def add(key: str) -> None:
        key = unescape(key)
        if key not in seen:
            seen.add(key)
            keys.append(key)

    for path in sorted((ROOT / "scripts").rglob("*.gd")):
        text = path.read_text(encoding="utf-8")
        for match in TR_RE.finditer(text):
            add(match.group(1))
        rel = path.relative_to(ROOT).as_posix()
        if rel in DATA_FILES:
            for line in text.splitlines():
                if "print(" in line or line.strip().startswith("#"):
                    continue
                for match in LIT_RE.finditer(line):
                    add(match.group(1))
        for match in TITLE_RE.finditer(text):
            add(match.group(1))
    for path in sorted((ROOT / "scenes").rglob("*.tscn")):
        for line in path.read_text(encoding="utf-8").splitlines():
            if line.startswith("text = ") or line.startswith("placeholder_text = "):
                for match in LIT_RE.finditer(line):
                    add(match.group(1))
    existing: dict[str, str] = {}
    if CSV_PATH.is_file():
        with CSV_PATH.open(encoding="utf-8", newline="") as handle:
            for row in csv.DictReader(handle):
                existing[row["keys"]] = row.get("en", "")
    CSV_PATH.parent.mkdir(parents=True, exist_ok=True)
    with CSV_PATH.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.writer(handle)
        writer.writerow(["keys", "zh_CN", "en"])
        for key in keys:
            writer.writerow([key, key, existing.get(key, "")])
    missing = [k for k in keys if not existing.get(k)]
    print(f"keys={len(keys)} missing_en={len(missing)}")
    for key in missing:
        print("TODO_EN:", key)


if __name__ == "__main__":
    main()