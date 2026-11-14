r"""生成迭代新敌人的出图计划（12 个敌人 × 立绘 + 死亡姿态 = 24 张）。"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

STYLE = ("dark gothic fantasy pixel art, chunky visible pixels, limited 32-color palette, "
         "brushed dark steel and worn leather, antique gold filigree trim, deep crimson gems, "
         "high contrast with dramatic rim light, crisp 2px black outline, dense micro-detail, "
         "muted desaturated shadows with a few saturated accents")
PROP = ("Mature heroic proportions, about 6 heads tall, narrow waist and broad shoulders. "
        "NOT chibi, NOT super-deformed, no oversized head, no big cute eyes, no toy-like look.")
BG = ("Flat solid pure magenta #FF00FF background, no gradient, no shadow, no ground, "
      "no text, no frame, no border.")
POSE = "Full body, head to toe, front view, centered, symmetrical stance, standing still."

ENEMIES = {
    "shield_guard": (
        "A heavily armored shield guard: a tall humanoid knight encased in thick dark steel plate armor "
        "with riveted pauldrons and a crested closed helm, carrying an enormous kite shield emblazoned "
        "with a crimson blood sigil in the left hand and a short-handled battle axe in the right hand, "
        "dark red rune glow seeping from the armor joints, heavy iron boots planted on the ground.",
        "collapsed on the ground in a heap of broken steel plates, the kite shield fallen beside him and "
        "the axe dropped, helm dented and cracked open, one gauntlet arm slack, blood pooling under the "
        "torso, the armor scorched black and cracked, motionless"),
    "blood_priest": (
        "A blood priest: a tall gaunt humanoid in a heavy dark crimson hooded robe embroidered with faded "
        "silver sigils, hollow eyes glowing with two points of scarlet light inside the hood, holding a tall "
        "black iron candle stand crowned with a single blood-red flame, a string of bone beads at the belt.",
        "collapsed on the ground, the robe spread out and soaked through with dark blood, the hood fallen "
        "back revealing a bone-white skull face, the candle stand broken beside him, the red flame snuffed "
        "out and drifting grey ash rising from the robe"),
    "web_weaver": (
        "A web weaver: a dark green armored spider creature standing on eight spindly legs, the abdomen "
        "bulging with a pale grey silk sac, thick chitinous legs with hooked claws, venom dripping from "
        "short hooked fangs, grey mottling across the carapace.",
        "collapsed on the ground with its eight legs curled stiffly inward, the pale silk sac split open "
        "and spilling sticky grey silk across the floor, the chitin shell dried and cracked, the fangs "
        "still dripping dark venom"),
    "coffin_guard": (
        "A coffin guard: an upright walking coffin of rotting dark oak bound with frayed hemp rope, iron "
        "rivets along the edges, the lid pushed half open to reveal a white bone arm and a hollow skull "
        "face inside, dried dark blood stains on the planks.",
        "the coffin lying on its side, broken open into splintered planks and scattered bones, the lid "
        "fallen away, the bone arm lying loose on the floor, the rope snapped and trailing in the dirt"),
    "blood_hound": (
        "A blood hound: a lean wolf-like hound with blood-red matted fur, ribs showing through the "
        "emaciated flanks, a black and crimson bristling mane, long white fangs bared from a snarling "
        "muzzle, and glowing dull yellow eyes.",
        "collapsed on its side on the ground, the red fur matted and bloodied, ribs still showing through "
        "the flank, the jaw slack with the fangs visible, the black mane spread out in the dirt, "
        "motionless and bleeding out"),
    "furnace_golem": (
        "A furnace golem: a massive squat construct of riveted black iron plates, the chest cavity wide "
        "open and glowing with a roaring orange furnace fire, thick blocky arms like girders, a short "
        "chimney pipe on one shoulder venting smoke.",
        "collapsed in a heap of cracked iron plates, the furnace fire dead and the chest cavity blackened "
        "and open, the chimney pipe snapped off, thin grey smoke still drifting from the broken vents, "
        "scattered rivets and broken gears around it"),
    "burrower": (
        "A burrower: a mud-brown burrowing beast with a segmented worm-like body, powerful shovel-shaped "
        "forelimbs, a pair of huge curved mandibles, and a crust of dried cracked earth and pebbles "
        "crusted over its back.",
        "collapsed on its side in the dirt, the segmented body curled stiffly, the big mandibles slack and "
        "half buried, the mud crust on its back cracked into flakes and shed all over the ground"),
    "gem_leech": (
        "A gem leech: a flat six-legged insect with a faceted violet-blue crystal carapace, a large "
        "glowing violet gemstone embedded in the middle of its abdomen, dark teal chitin rings between the "
        "segments and thin clawed legs.",
        "collapsed on the ground with the crystal carapace shattered into many violet shards, the embedded "
        "gem rolled out and lying beside it still glowing faintly, the segmented body dried and shriveled"),
    "lantern_wraith": (
        "A lantern wraith: a tall translucent grey-blue ghost in a tattered hooded shroud, hollow under "
        "the hood, clutching a rusted iron lantern with a cold blue flame burning inside it, the lower "
        "hem of the shroud dissolving into mist.",
        "the shroud dissolving into drifting grey mist, the rusted iron lantern dropped on the ground with "
        "the blue flame snuffed out and the lid hanging open, only a faint cold residue glowing inside"),
    "alchemist_pitcher": (
        "An alchemical pitcher: a lean servant in a grey-brown work robe with a stained leather apron, "
        "a wicker basket of glass vials strapped to the back, empty pockets for bottles at the belt, a "
        "plain hood showing only a pale lower jaw, holding a stoppered vial of glowing amber liquid.",
        "collapsed on the ground, the wicker basket overturned with glass vials shattered and amber liquid "
        "spilled across the floor, the stained apron torn, the dropped vial cracked open and empty"),
    "resonance_mage": (
        "A resonance mage: a tall caster in a deep purple robe crossed with silver triangle sigils, a "
        "pale chin and lower jaw visible under a deep hood, both hands raised holding a floating faceted "
        "violet crystal orb that glows with inner light.",
        "collapsed on the ground with the violet crystal orb shattered into glittering shards, the deep "
        "purple robe scorched and burning with small violet flames, silver sigils glowing faintly then "
        "going dark, grey ash rising"),
    "moon_wing": (
        "A moon wing: a large bat-like beast with pale moon-white fur, thin skeletal wings with stretched "
        "grey membrane, pointed ears, cold glowing blue eyes, and long hooked claws on the front paws.",
        "collapsed on the ground with the skeletal wings folded and one wing bone broken and bent, the pale "
        "moon-white fur ruffled and dirty, the cold blue eyes dimmed, the hooked claws curled inwards"),
}


def main() -> None:
    plan = []
    for enemy_id, (creature, death) in ENEMIES.items():
        plan.append({
            "asset": enemy_id + "_idle",
            "mode": "t2i",
            "cell": 56,
            "frames": 4,
            "motion": "idle",
            "steps": 25,
            "prompt": (creature + " " + POSE + " " + STYLE + ". " + PROP + " " + BG),
        })
        plan.append({
            "asset": enemy_id + "_death",
            "mode": "edit",
            "char_ref": "raw:" + enemy_id + "_idle",
            "cell": 56,
            "frames": 6,
            "motion": "corpse",
            "steps": 25,
            "prompt": ("Redraw the single character from image 2 in " + STYLE + ". " + PROP +
                       " Keep the character identity, outfit and colors from image 2, but show it now "
                       "dead: " + death + ". Full body, head to toe, front view, centered. " + BG),
        })
    out = ROOT / "artifacts" / "iteration_assets" / "plan_enemies.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(plan, ensure_ascii=False, indent=2), encoding="utf-8")
    print(out, len(plan))


if __name__ == "__main__":
    main()
