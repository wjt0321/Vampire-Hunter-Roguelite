#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""一次性清理：删掉"用字符当图标"的数据字段与赋值。

2026-11-09 第五轮试玩反馈"依旧有很多只有字没有图标的技能出现"。
排查到底：所有界面图标位都已改成贴图，但工程里还留着一整套
「单字图标」机制（icon_emoji / evolution_icon / catalog 的 "icon" 字段），
并且 HUD / 房间商店 / 升级卡 / 精英词缀四处都保留了
「拿不到贴图就显示单字」的回退分支。

这就是复发口子：以后新增一个物品忘了在 ItemCatalog 映射表登记，
界面就会静默退化成"枪""书""刃"这种单字——正是用户看到的现象。

所以这里连数据源一起拔掉：
  1. 删掉 icon_emoji / evolution_icon 字段与全部赋值
  2. 删掉 ItemCatalog 数据行里的 "icon": "枪" 单字字段
  3. 删掉升级三选一 basic 卡的 "icon": "" 空字段
界面层那四处回退分支由单独的 edit 处理（要留注释说明原因）。

幂等：重复运行不会二次删坏。
行尾：按原样保留（工作区 CRLF）。
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# 整行删除的规则：(文件, 正则)
LINE_RULES = [
    # 数据类字段声明
    ("scripts/weapons/weapon_data.gd", r'^\s*@export var icon_emoji: String = ".*"\s*$'),
    ("scripts/weapons/weapon_evolution.gd", r'^\s*@export var evolution_icon: String = ".*"\s*$'),
    ("scripts/player/passive_item_data.gd", r'^\s*@export var icon_emoji: String = ".*"\s*$'),
    ("scripts/player/character_data.gd", r'^\s*@export var icon_emoji: String = ".*"\s*$'),
    # 赋值
    ("scripts/weapons/weapon_manager.gd", r'^\s*w\.icon_emoji = ".*"\s*$'),
    ("scripts/weapons/weapon_manager.gd", r'^\s*weapon\.icon_emoji = evolution\.evolution_icon\s*$'),
    ("scripts/weapons/weapon_manager.gd", r'^\s*evolution\.evolution_icon = config\.get\("evolution_icon".*\)\s*$'),
    ("scripts/player/passive_item_data.gd", r'^\s*item\.icon_emoji = ".*"\s*$'),
    ("scripts/player/character_data.gd", r'^\s*data\.icon_emoji = ".*"\s*$'),
    # EVOLUTION_CONFIG 里的单字图标
    ("scripts/weapons/weapon_manager.gd", r'^\s*"evolution_icon": ".*",?\s*$'),
    # ItemCatalog 数据行里的单字图标字段
    ("scripts/core/item_catalog.gd", r'^(\s*\{.*?), "icon": "[^"]*"(\s*,.*)$'),
    # 升级三选一 basic 卡的空 icon 字段
    ("scripts/ui/upgrade_ui.gd", r'^(\s*\{.*?), "icon": ""(\s*,.*)$'),
]


def apply_file(rel: str, rules: list) -> int:
    path = ROOT / rel
    raw = path.read_text(encoding="utf-8")
    # 保留原行尾
    lines = raw.splitlines(keepends=True)
    out = []
    removed = 0
    for line in lines:
        body = line.rstrip("\r\n")
        hit = False
        for pattern in rules:
            m = re.match(pattern, body)
            if m:
                if m.groups():
                    # 带捕获组的规则：把字段抠掉，保留整行其余部分
                    new_body = m.group(1) + m.group(2)
                    ending = line[len(body):]
                    out.append(new_body + ending)
                # 无捕获组：整行删掉
                hit = True
                removed += 1
                break
        if not hit:
            out.append(line)
    if removed:
        path.write_text("".join(out), encoding="utf-8", newline="")
    return removed


def main() -> int:
    total = 0
    by_file: dict = {}
    for rel, pattern in LINE_RULES:
        n = apply_file(rel, [pattern])
        if n:
            by_file[rel] = by_file.get(rel, 0) + n
            total += n
    for rel, n in sorted(by_file.items()):
        print(f"  {rel}: 删掉 {n} 处")
    print(f"[strip_char_icons] 共删除 {total} 处字符图标字段/赋值")
    return 0


if __name__ == "__main__":
    sys.exit(main())
