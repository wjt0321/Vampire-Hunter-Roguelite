"""收尾：把旧敌人这一轮的产物对齐到游戏真正会去找的位置，并汇总清单。

要做的一件额外事：
  精英吸血鬼的贴图键是 elite_vampire，但 _get_enemy_type() 返回 elite，
  而死亡动画是按 _get_enemy_type() 找表的 —— 所以 death.png 要有两份，
  少一份，精英吸血鬼死的时候就会退回淡出，不会播新死亡条。

用法：python tools/finalize_legacy_round.py
"""
from __future__ import annotations

import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ENEMY_ROOT = ROOT / "assets" / "sprites" / "enemies"

EXPECTED = {
    "vampire": ["idle", "run", "death"],
    "werewolf": ["idle", "charge", "death"],
    "bat": ["idle", "fly", "death"],
    "zombie": ["idle", "walk", "death"],
    "skeleton": ["idle", "shoot", "death"],
    "exploder": ["idle", "walk", "explode", "death"],
    "gargoyle": ["idle", "petrify", "wake", "death"],
    "vampire_mage": ["idle", "cast", "teleport", "death"],
    "summoner": ["idle", "cast", "death"],
    "vampire_prince": ["idle", "dash", "rage", "death"],
    "elite_vampire": ["idle", "death"],
}

EFFECT_SHEETS = {
    "hit_effect": "assets/effects/hit_effect_sheet.png",
    "death_explosion": "assets/effects/death_explosion_sheet.png",
    "portal": "assets/effects/portal_sheet.png",
    "shield_break": "assets/effects/shield_break_sheet.png",
    "poison_spread": "assets/effects/poison_spread_sheet.png",
    "levelup_aura": "assets/effects/levelup_aura_sheet.png",
    "freeze_effect": "assets/effects/freeze_effect_sheet.png",
    "petrify_effect": "assets/effects/petrify_effect_sheet.png",
    "holy_light": "assets/effects/holy_light_sheet.png",
    "chain_lightning": "assets/effects/chain_lightning_sheet.png",
    "thunder_wrath": "assets/effects/thunder_wrath_sheet.png",
    "torch": "assets/tiles/props/torch_sheet.png",
    "campfire": "assets/tiles/props/campfire_sheet.png",
    "chest": "assets/tiles/props/chest_sheet.png",
    "cursed_chest": "assets/items/cursed_chest_sheet.png",
    "merchant": "assets/ui/merchant_sheet.png",
}


def main() -> None:
    src = ENEMY_ROOT / "elite_vampire" / "death.png"
    dst_dir = ENEMY_ROOT / "elite"
    if src.is_file():
        dst_dir.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dst_dir / "death.png")
        print("COPY elite_vampire/death.png -> elite/death.png")
    else:
        print("!! elite_vampire/death.png 还没有")

    missing: list[str] = []
    total = 0
    for enemy_id, states in EXPECTED.items():
        for state in states:
            total += 1
            p = ENEMY_ROOT / enemy_id / (state + ".png")
            if not p.is_file():
                missing.append("%s/%s" % (enemy_id, state))
    fx_missing = [k for k, v in EFFECT_SHEETS.items() if not (ROOT / v).is_file()]

    print("敌人动作条 %d 项，缺 %d 项" % (total, len(missing)))
    for m in missing:
        print("  缺", m)
    print("特效/道具序列帧 %d 项，缺 %d 项" % (len(EFFECT_SHEETS), len(fx_missing)))
    for m in fx_missing:
        print("  缺", m)
    if missing or fx_missing:
        sys.exit(1)
    print("全部到位")


if __name__ == "__main__":
    main()
