"""图标资产体检：查"只有字没有图"到底是映射漏了，还是贴图本身是废图。

判据（每条都是"看上去像没有图标"的物理原因）：
  1. 文件缺失 / 尺寸不是目标尺寸（UI 按 48 画，尺寸不对会被拉糊）
  2. 全透明（alpha 全 0）——画出来什么都没有
  3. 近乎单色（distinct colors 极少）——画出来是一坨色块
  4. 缩小到 48 后细节全糊（对比度骤降）
  5. 文件体积异常大（1024 原图没下采样，直接当图标用会糊成马赛克）

用法：python "D:\\mydev\\games\\Vampire-Hunter-Roguelite\\tools\\audit_icons.py"
"""
from __future__ import annotations

import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets"

# TextureManager 里的 weapon_icons 键 → 文件
WEAPON_ICONS = {
    "pistol": "weapons/icon_pistol.png",
    "shotgun": "weapons/icon_shotgun.png",
    "magic_book": "weapons/icon_magic_book.png",
    "knife": "weapons/icon_knife.png",
    "poison": "weapons/icon_poison.png",
    "lightning": "weapons/icon_lightning.png",
    "magnet": "weapons/icon_magnet.png",
    "shield": "weapons/icon_shield.png",
    "regen": "weapons/icon_regen.png",
    "greed": "weapons/icon_greed.png",
    "berserker": "weapons/icon_berserker.png",
    "frozen": "weapons/icon_frozen.png",
    "lightning_shield": "weapons/icon_lightning_shield.png",
    "shadow": "weapons/icon_shadow.png",
    "crossbow": "weapons/icon_crossbow.png",
    "holy_wand": "weapons/icon_holy_wand.png",
    "vampiric": "weapons/icon_vampiric.png",
    "swift_boots": "weapons/icon_swift_boots.png",
    "clover": "weapons/icon_clover.png",
    "kunai": "weapons/icon_kunai.png",
    "flame_thrower": "weapons/icon_flame_thrower.png",
    "blood_burst": "weapons/icon_blood_burst.png",
    "blood_edge": "weapons/icon_blood_edge.png",
    "frost_bind": "weapons/icon_frost_bind.png",
    "blood_drain": "weapons/icon_blood_drain.png",
    "mightstone": "weapons/icon_mightstone.png",
}
# heal_potion / blood_crystal / xp_gem_large 的原图（1024 / 24 / 1024）
# 不再直接当图标用，UI 走 items/ 下的 48×48 派生版，见 ITEM_ICONS。
# 这里单列一组，只查"文件在不在、是不是废图"，不查 48×48。
SOURCE_ICONS = {
    "heal_potion_src": "weapons/heal_potion.png",
    "blood_crystal_src": "weapons/blood_crystal.png",
    "xp_gem_large_src": "weapons/xp_gem_large.png",
}

UI_ICONS = {
    "affix_shielded": "ui/affix_shielded.png",
    "affix_charger": "ui/affix_charger.png",
    "affix_splitter": "ui/affix_splitter.png",
    "affix_haster": "ui/affix_haster.png",
    "achievement_icon": "ui/achievement_icon.png",
    "star_gold": "ui/star_gold.png",
    "star_gray": "ui/star_gray.png",
    "passive_hunter_instinct": "ui/passive_hunter_instinct.png",
    "passive_holy_ward": "ui/passive_holy_ward.png",
}

# 25 个成就徽章（2026-11-09 第五轮新增：原来 25 个成就共用一个 "★" 字符）
ACHIEVEMENT_IDS = [
    "first_blood", "novice_hunter", "expert_hunter", "vampire_slayer",
    "werewolf_hunter", "zombie_hunter", "exterminator", "elite_hunter",
    "prince_slayer", "boss_killer", "crypt_breaker", "throne_breaker",
    "flawless_victory", "speed_runner", "survivor", "wave_master",
    "room_explorer", "weapon_master", "jack_of_all_trades", "evolutionist",
    "rich_hunter", "maxed_out", "shopaholic", "treasure_hunter", "rest_stop",
]
for _aid in ACHIEVEMENT_IDS:
    UI_ICONS[f"ach_{_aid}"] = f"ui/ach_{_aid}.png"

# 战场地面掉落物 + UI 尺寸修正版（2026-11-09 第五轮新增）
ITEM_ICONS = {
    "silver_coin": "items/silver_coin.png",
    "xp_gem_green": "items/xp_gem_green.png",
    "xp_gem_blue": "items/xp_gem_blue.png",
    "xp_gem_gold": "items/xp_gem_gold.png",
    "xp_gem_icon": "items/xp_gem_icon.png",
    "powerup_heal": "items/powerup_heal.png",
    "powerup_frenzy": "items/powerup_frenzy.png",
    "powerup_magnet": "items/powerup_magnet.png",
    "cursed_chest": "items/cursed_chest.png",
    "heal_potion_icon": "items/heal_potion_icon.png",
    "blood_crystal_icon": "items/blood_crystal_icon.png",
}


def analyse(path: Path) -> dict:
    info: dict = {"exists": path.exists()}
    if not path.exists():
        return info
    info["bytes"] = path.stat().st_size
    try:
        im = Image.open(path)
        im.load()
    except Exception as exc:  # 坏文件
        info["error"] = str(exc)
        return info
    info["size"] = list(im.size)
    info["mode"] = im.mode
    rgba = im.convert("RGBA")
    alpha = rgba.getchannel("A")
    hist = alpha.histogram()
    opaque = hist[255]
    total = alpha.size[0] * alpha.size[1]
    info["opaque_ratio"] = round(opaque / total, 4) if total else 0.0
    info["transparent_ratio"] = round(hist[0] / total, 4) if total else 0.0
    info["has_visible"] = any(hist[1:])
    info["bbox"] = list(rgba.getbbox()) if rgba.getbbox() else None
    colors = rgba.getcolors(maxcolors=100000)
    info["distinct_colors"] = len(colors) if colors else ">100000"
    # 缩到 48 再看对比度：糊成一片 = 灰度标准差很小
    small = rgba.convert("RGB").resize((48, 48), Image.Resampling.NEAREST)
    grey = small.convert("L")
    pixels = list(grey.getdata())
    mean = sum(pixels) / len(pixels)
    var = sum((p - mean) ** 2 for p in pixels) / len(pixels)
    info["stddev_48"] = round(var ** 0.5, 1)
    return info


def main() -> None:
    # 每组的期望尺寸。图标一律 48×48（UI 固定按 48 画）；
    # 战场掉落物按真实显示尺寸（宝石三档 16/24/32、宝箱 48×40）。
    expected = {
        "weapon_icons": {k: (48, 48) for k in WEAPON_ICONS},
        "ui_icons": {k: (48, 48) for k in UI_ICONS},
        "item_icons": {
            "silver_coin": (48, 48),
            "xp_gem_green": (16, 16),
            "xp_gem_blue": (24, 24),
            "xp_gem_gold": (32, 32),
            "xp_gem_icon": (48, 48),
            "powerup_heal": (48, 48),
            "powerup_frenzy": (48, 48),
            "powerup_magnet": (48, 48),
            "cursed_chest": (48, 40),
            "heal_potion_icon": (48, 48),
            "blood_crystal_icon": (48, 48),
        },
    }
    expected["ui_icons"]["achievement_icon"] = (64, 64)
    # 词缀图标是 affix_icons.py 手绘的 24×24（头顶小图标，设计如此）
    for _k in ("affix_shielded", "affix_charger", "affix_splitter", "affix_haster"):
        expected["ui_icons"][_k] = (24, 24)
    groups = {"weapon_icons": WEAPON_ICONS, "ui_icons": UI_ICONS,
              "item_icons": ITEM_ICONS, "source_icons": SOURCE_ICONS}
    problems: list[str] = []
    for gname, table in groups.items():
        print(f"\n=== {gname} ===")
        for key, rel in sorted(table.items()):
            path = ASSETS / rel
            info = analyse(path)
            flags: list[str] = []
            if not info.get("exists"):
                flags.append("缺失")
            else:
                if "error" in info:
                    flags.append(f"坏文件({info['error'][:40]})")
                else:
                    w, h = info["size"]
                    exp = expected.get(gname, {}).get(key)
                    if exp is not None and (w, h) != exp:
                        flags.append(f"尺寸{w}x{h}≠{exp[0]}x{exp[1]}")
                    if not info.get("has_visible"):
                        flags.append("全透明（画出来什么都没有）")
                    if (1.0 - info["transparent_ratio"]) < 0.005:
                        flags.append(f"几乎没有可见像素({info['transparent_ratio']})")
                    if isinstance(info["distinct_colors"], int) and info["distinct_colors"] <= 2:
                        flags.append(f"近乎单色({info['distinct_colors']}色)")
                    if info["stddev_48"] < 12:
                        flags.append(f"缩小后糊(std={info['stddev_48']})")
                    if info["bytes"] > 200000 and gname != "source_icons":
                        flags.append(f"体积异常({info['bytes'] // 1024}KB)")
            if flags:
                problems.append(f"{gname}/{key} ({rel}): " + "、".join(flags))
            detail = ""
            if info.get("exists") and "error" not in info:
                detail = (f"{info['size'][0]}x{info['size'][1]} "
                          f"opaque={info['opaque_ratio']:.3f} "
                          f"colors={info['distinct_colors']} "
                          f"std48={info['stddev_48']} "
                          f"{info['bytes'] // 1024}KB")
            print(f"  {'OK ' if not flags else 'BAD'} {key:22s} {rel:38s} {detail}")

    print("\n=== 结论 ===")
    if problems:
        for p in problems:
            print("  · " + p)
    else:
        print("  全部图标文件本身可用")
    out = ROOT / "tools" / "audit_icons_report.json"
    out.write_text(json.dumps(problems, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"\n报告: {out}")


if __name__ == "__main__":
    main()
