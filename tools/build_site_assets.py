#!/usr/bin/env python
"""为宣传站点 site/ 收集素材。

只做「复制」：从 assets/ 与 docs/screenshots/ 把公开素材拷到 site/assets/img/，
不修改任何源文件。跑法：

    python tools/build_site_assets.py
"""
from __future__ import annotations

import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SITE = ROOT / "site"
IMG = SITE / "assets" / "img"

FILES: list[tuple[str, str]] = []

for name in ("menu", "characters", "gameplay", "upgrade", "shop", "boss"):
    FILES.append((f"docs/screenshots/{name}.png", f"shots/{name}.png"))

FILES.append(("assets/backgrounds/menu_bg.png", "bg/menu_bg.png"))
FILES.append(("assets/backgrounds/room_standard.png", "bg/room_standard.png"))

for key in (
    "pistol", "shotgun", "magic_book", "knife", "kunai", "poison",
    "lightning", "crossbow", "holy_wand", "flame_thrower", "blood_burst",
):
    FILES.append((f"assets/weapons/icon_{key}.png", f"weapons/{key}.png"))

for key in (
    "magnet", "shield", "regen", "greed", "berserker", "frozen",
    "lightning_shield", "shadow", "vampiric", "swift_boots", "clover",
    "blood_edge", "frost_bind", "blood_drain",
):
    FILES.append((f"assets/weapons/icon_{key}.png", f"passives/{key}.png"))

for key in ("shielded", "charger", "splitter", "haster"):
    FILES.append((f"assets/ui/affix_{key}.png", f"affix/{key}.png"))

for key in ("mightstone", "swift_boots", "kunai"):
    FILES.append((f"assets/weapons/icon_{key}.png", f"stats/{key}.png"))
for key in ("blood_crystal_icon", "heal_potion_icon"):
    FILES.append((f"assets/items/{key}.png", f"stats/{key}.png"))

FILES.append(("assets/sprites/player/player_idle.png", "chars/player_idle.png"))
FILES.append(("assets/sprites/player/priestess_idle.png", "chars/priestess_idle.png"))
for key in (
    "vampire_idle", "zombie_walk", "bat_fly", "skeleton_idle", "werewolf_idle",
    "gargoyle_idle", "exploder_walk", "elite_vampire_idle", "mage_cast",
    "summoner_cast", "prince_idle",
):
    FILES.append((f"assets/sprites/enemies/{key}.png", f"enemies/{key}.png"))
FILES.append(("assets/sprites/boss/boss_idle.png", "boss/boss_idle.png"))

for key in ("blood_crystal_icon", "xp_gem_icon", "silver_coin", "heal_potion_icon", "cursed_chest"):
    FILES.append((f"assets/items/{key}.png", f"items/{key}.png"))

for p in sorted((ROOT / "assets" / "ui").glob("ach_*.png")):
    FILES.append((f"assets/ui/{p.name}", f"achievements/{p.name}"))
FILES.append(("assets/ui/achievement_icon.png", "achievements/_frame.png"))


def main() -> None:
    copied, missing = 0, []
    for src, dst in FILES:
        s = ROOT / src
        d = IMG / dst
        if not s.exists():
            missing.append(src)
            continue
        d.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(s, d)
        copied += 1
    print(f"copied={copied} missing={len(missing)}")
    for m in missing:
        print("  MISSING:", m)


if __name__ == "__main__":
    main()
