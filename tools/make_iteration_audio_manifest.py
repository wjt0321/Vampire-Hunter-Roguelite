"""Build the iteration audio manifest: 39 new SFX + 6 reworked BGM.

Each SFX prompt is written per subject, not per category:
- 12 weapon/fusion shot sounds follow what each weapon actually does
  (arc-and-return scythe, cone whip crack, frost ring bell, 3-round burst, etc).
- 12 enemy death sounds follow each enemy's own death animation
  (armour shattering, candle guttering out, silk sac rupturing, coffin boards
  splintering, earth mound collapsing, crystal shattering, lantern glass
  breaking, glass vials shattering, violet orb detonating, wing bones snapping).
- 12 enemy hit sounds follow each enemy's material
  (steel plate, wet flesh, chitin, dry bone, hot iron, dirt, crystal glass,
  hollow cloth, glass, arcane hum, fur, feather).
- 3 passive sounds follow what each passive actually does.

BGM prompts are reworked to match this round's visual identity:
chunky pixel gothic, dark steel + antique gold + deep crimson.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / 'artifacts/game-audio-20261113/manifest.json'
DST = ROOT / 'artifacts/game-audio-iteration/manifest.json'

BASE = 2026111400
TAIL = " Isolated single game sound effect on a silent background, no speech, no music."


def sfx(key, label, duration, peak, prompt, seed):
    return {
        'kind': 'sfx', 'key': key, 'label': label,
        'duration': duration, 'peak': peak, 'seed': seed,
        'prompt': prompt + TAIL,
    }


JOBS = []

# ---------------------------------------------------------------- 12 weapon shots
JOBS += [
    sfx('shot_scythe', '回旋镰', 0.42, -11,
        "One heavy curved scythe blade slicing through air in a fast arc, "
        "a sharp metallic whoosh that builds and cuts off, faint ring of "
        "polished steel at the end", BASE + 100),
    sfx('shot_thorn_whip', '荆棘长鞭', 0.34, -12,
        "One thorny whip cracking through air with a dry leathery snap "
        "and a short hiss of barbs tearing past", BASE + 101),
    sfx('shot_frost_bell', '寒霜圣铃', 0.75, -12,
        "One frost bell struck once, a bright bell tone ringing out "
        "immediately followed by a spread of thin crystalline ice shimmer "
        "and a cold airy tail", BASE + 102),
    sfx('shot_repeater', '连珠火铳', 0.30, -13,
        "One short three-round pistol burst, three tight dry gunshots "
        "in rapid succession with small mechanical clacks between them", BASE + 103),
    sfx('shot_soul_lantern', '魂引灯', 0.55, -13,
        "One ghostly blue spirit flame launching and streaking through "
        "air, a soft ethereal whoosh with a faint choir-like shimmer and "
        "a dying ember trail", BASE + 104),
    sfx('shot_spike_tome', '地刺法典', 0.48, -12,
        "One stone spike erupting violently out of the ground with a "
        "sharp crack of breaking rock and a short gritty rubble scrape", BASE + 105),
    sfx('shot_chain_gun', '锁链枪', 0.40, -11,
        "One iron chain fired out with a fast metallic clatter of links "
        "rapping together and a heavy hook impact at the end", BASE + 106),
    sfx('shot_thunder_bolt', '雷鸣融合', 0.52, -10,
        "One crackling lightning bolt discharge, sharp electric snap "
        "with a bright sizzling arc tail and a low thunder thump", BASE + 107),
    sfx('shot_miasma', '瘴气融合', 0.80, -13,
        "One blast of thick toxic mist, a wet bubbling exhale with a "
        "low hollow drone and a soft corrosive hiss", BASE + 108),
    sfx('shot_returning_blade', '回返刃融合', 0.36, -12,
        "One thrown blade spinning through air with a thin metallic "
        "swish and a light ringing edge tone", BASE + 109),
    sfx('shot_twin_chant', '双声咏唱融合', 0.60, -12,
        "One layered double voice chant striking in unison, two "
        "overlapping breathy vocal tones with a hollow bell overtone", BASE + 110),
    sfx('shot_burning_blood', '燃血融合', 0.50, -11,
        "One burst of burning blood, a wet gurgling whoosh igniting into "
        "a fierce hiss of flame and a low sizzling scorch", BASE + 111),
]

# ---------------------------------------------------------------- 12 enemy deaths
JOBS += [
    sfx('death_shield_guard', '盾卫死亡', 0.70, -10,
        "One armoured soldier falling in a full suit of plate armour, "
        "heavy clanking of steel plates, a body hitting the ground with "
        "a solid metal clang and a final short metallic settle", BASE + 120),
    sfx('death_blood_priest', '血祭司死亡', 0.80, -11,
        "One robed priest dying as a blood candle gutters out, a soft "
        "puff of flame, heavy cloth collapsing to the floor and a "
        "hollow wooden candle roll", BASE + 121),
    sfx('death_web_weaver', '织网者死亡', 0.65, -12,
        "One large spider dying, a wet crack of an abdomen bursting and "
        "a splattering of sticky silk strands hitting the ground", BASE + 122),
    sfx('death_coffin_guard', '棺卫死亡', 0.85, -10,
        "One rotten wooden coffin breaking apart, splintering planks, "
        "dry bones rattling loose and wooden boards collapsing heavily", BASE + 123),
    sfx('death_blood_hound', '血猎犬死亡', 0.60, -11,
        "One hunting hound dying, a wet choke and a heavy body drop on "
        "dirt with a dull thud and a short whimper", BASE + 124),
    sfx('death_furnace_golem', '炉心巨像死亡', 0.95, -9,
        "One iron construct collapsing, a furnace door bursting open with "
        "a roar of fire, heavy iron slabs slamming down and clanging, "
        "ending in a dying ember hiss", BASE + 125),
    sfx('death_burrower', '潜伏者死亡', 0.75, -12,
        "One burrowing creature going down into the earth, a scrape of "
        "claws on soil, a muffled underground thud and loose dirt "
        "pattering down", BASE + 126),
    sfx('death_gem_leech', '吞晶虫死亡', 0.70, -11,
        "One crystal carapace shattering, a bright glassy break with "
        "scattering shard tinkle and a wet body collapse underneath", BASE + 127),
    sfx('death_lantern_wraith', '灯鬼死亡', 0.72, -12,
        "One ghost wraith dissolving, a rusted lantern's glass breaking "
        "with a delicate tinkle, a puff of hollow smoky air and a "
        "fading low breath", BASE + 128),
    sfx('death_alchemist_pitcher', '炼金投手死亡', 0.72, -11,
        "One alchemist dying with glass vials, several small bottles "
        "shattering on stone floor with bright glass breaks and a wet "
        "spill sloshing out", BASE + 129),
    sfx('death_resonance_mage', '共鸣术士死亡', 0.88, -10,
        "One sorcerer dying as a violet crystal orb detonates, a sharp "
        "magical glass burst with a ringing shattering resonance that "
        "descends into a low magical hum", BASE + 130),
    sfx('death_moon_wing', '月翼兽死亡', 0.85, -11,
        "One winged beast hitting the ground and dying, thin wing bones "
        "snapping with sharp cracks, a heavy furry body landing with a "
        "dull thump and a fading breath", BASE + 131),
]

# ---------------------------------------------------------------- 12 enemy hits
JOBS += [
    sfx('hit_shield_guard', '盾卫受击', 0.20, -13,
        "One strike on a steel shield, a tight metallic clang with a "
        "short ringing edge tone", BASE + 140),
    sfx('hit_blood_priest', '血祭司受击', 0.20, -14,
        "One strike on a robed figure, a soft dull thud of a body under "
        "thick fabric with a faint wet slap", BASE + 141),
    sfx('hit_web_weaver', '织网者受击', 0.22, -14,
        "One strike on a large spider, a brittle chitinous crunch with a "
        "dry scraping of legs on stone", BASE + 142),
    sfx('hit_coffin_guard', '棺卫受击', 0.24, -13,
        "One strike on a wooden coffin, a hollow dry knock of old boards "
        "with a faint rattle of bone inside", BASE + 143),
    sfx('hit_blood_hound', '血猎犬受击', 0.20, -14,
        "One strike on a hound, a wet muffled thud on fur and flesh with "
        "a short yelping whine", BASE + 144),
    sfx('hit_furnace_golem', '炉心巨像受击', 0.24, -12,
        "One strike on an iron construct, a heavy dead metallic thud "
        "with a faint internal furnace roar", BASE + 145),
    sfx('hit_burrower', '潜伏者受击', 0.22, -14,
        "One strike on a burrowing creature, a gritty thud on packed "
        "dirt with loose soil scraping away", BASE + 146),
    sfx('hit_gem_leech', '吞晶虫受击', 0.20, -13,
        "One strike on a crystal shelled creature, a bright glassy ping "
        "with a wet squish of soft body underneath", BASE + 147),
    sfx('hit_lantern_wraith', '灯鬼受击', 0.22, -14,
        "One strike on a ghost, a hollow breathy whoosh of disturbed "
        "air with a faint ethereal chime", BASE + 148),
    sfx('hit_alchemist_pitcher', '炼金投手受击', 0.22, -14,
        "One strike on a hurler, a dull thud on a body with a jingling "
        "rattle of glass bottles on a belt", BASE + 149),
    sfx('hit_resonance_mage', '共鸣术士受击', 0.24, -13,
        "One strike on a sorcerer, a deep resonant arcane hum that "
        "briefly pitches upward with a short magical ring", BASE + 150),
    sfx('hit_moon_wing', '月翼兽受击', 0.22, -14,
        "One strike on a winged beast, a soft impact on fur with a light "
        "rustle of feathers and a short birdlike cry", BASE + 151),
]

# ---------------------------------------------------------------- 3 passive sounds
JOBS += [
    sfx('passive_execution_mark', '处刑印记', 0.55, -12,
        "One cursed execution brand burning into a target, a sharp "
        "sizzling brand press with a low ominous toll and a short "
        "satisfied snap as the mark settles", BASE + 160),
    sfx('passive_time_gear', '时滞齿轮', 0.70, -13,
        "One heavy clockwork gear engaging, slow metallic cog ratcheting "
        "with a deep winding spring groan and a soft tick", BASE + 161),
    sfx('passive_cold_blood', '寒血反应', 0.60, -12,
        "One frozen blood vessel rupturing in extreme cold, a brittle "
        "icy crack with a wet deep snap and a faint freezing shimmer", BASE + 162),
]


# ---------------------------------------------------------------- 6 reworked BGM
BGM_STYLE = (
    "Chunky-pixel gothic dark fantasy, instrumental only, no vocals, no choir, "
    "no speech, no lyrics. Dark steel, antique gold filigree and deep crimson "
    "colour. "
)

JOBS += [
    {
        'kind': 'bgm', 'key': 'menu', 'label': '夜幕猎人', 'duration': 60, 'loop': True,
        'seed': 2026111500,
        'prompt': BGM_STYLE + (
            "Title screen chamber loop, 96 BPM, D minor, steady 4/4. "
            "ONLY harpsichord, pizzicato cello, plucked lute and a soft ticking "
            "wooden percussion pulse, like chunky 16-bit game music. "
            "A short repeating baroque melody over a sparse ostinato. "
            "Small dry intimate ensemble, identical instrumentation throughout, "
            "consistent moderate energy from beginning to end. "
            "No orchestra build, no strings pad, no synthesizer pad, no voices, "
            "no vocal textures, no humming, no singing, no dramatic ending, no fade out."
        ),
    },
    {
        'kind': 'bgm', 'key': 'battle', 'label': '猎杀脉冲', 'duration': 60, 'loop': True,
        'seed': 2026111501,
        'prompt': BGM_STYLE + (
            "Action roguelite battle loop, 128 BPM, 4/4, D minor. "
            "A memorable short harpsichord hook, tight staccato string ostinato, "
            "restrained pipe organ bass and punchy compact electronic drums, "
            "sounding like a chiptune gothic boss arena. "
            "Dark determined vampire hunter energy with a steady driving groove. "
            "The beat starts immediately, no long intro. "
            "Clear instrument separation, restrained cymbals and sub-bass, "
            "leave space for game sound effects. "
            "Consistent energy, repeating eight-bar phrases with subtle variation, "
            "no dramatic breakdown, no fade-out."
        ),
    },
    {
        'kind': 'bgm', 'key': 'boss', 'label': '猩红王座', 'duration': 60, 'loop': True,
        'seed': 2026111502,
        'prompt': BGM_STYLE + (
            "Action boss battle loop, 144 BPM, D minor. "
            "Relentless sharp string ostinato, sinister pipe organ low chords, "
            "driving tight industrial electronic drums and threatening brass stabs, "
            "heavy and crimson like a gothic thrones room. "
            "Sustained oppressive tension without a break, a hammering eight-bar "
            "figure that repeats with subtle variation. "
            "The beat starts immediately, no long intro. "
            "Leave space for game sound effects, no dramatic ending, no fade-out."
        ),
    },
    {
        'kind': 'bgm', 'key': 'shop', 'label': '烛火与银币', 'duration': 60, 'loop': True,
        'seed': 2026111503,
        'prompt': BGM_STYLE + (
            "Safe room and merchant loop, 78 BPM, D minor with gentle warm major turns. "
            "Delicate plucked strings, intimate harpsichord, soft cello pizzicato "
            "and sparse brushed percussion, warm candlelit antique shop, "
            "cozy but haunted. "
            "A short repeating waltz-like phrase with a light ticking pulse, "
            "identical instrumentation throughout, consistent calm energy from "
            "beginning to end. "
            "No orchestra build, no voices, no vocal textures, no singing, "
            "no dramatic ending, no fade out."
        ),
    },
    {
        'kind': 'bgm', 'key': 'victory', 'label': '黎明归来', 'duration': 20, 'loop': False,
        'seed': 2026111504,
        'prompt': BGM_STYLE + (
            "A short triumphant gothic game victory cue, 110 BPM, D major. "
            "Bright noble strings, restrained brass, harpsichord and warm bells, "
            "like a pixel-art sunrise after a long night. "
            "Immediate uplifting rising motif, decisive closing hit, "
            "compact and celebratory without a long build."
        ),
    },
    {
        'kind': 'bgm', 'key': 'defeat', 'label': '最后的烛火', 'duration': 20, 'loop': False,
        'seed': 2026111505,
        'prompt': BGM_STYLE + (
            "A short sorrowful gothic game defeat cue, 68 BPM, D minor. "
            "Descending solo cello phrase, sparse felt piano and quiet low organ, "
            "the last candle going out in a dark steel hall. "
            "Dignified melancholy, immediate recognizable fatal motif, "
            "slowly sinking and fading to silence."
        ),
    },
]


def main():
    src = json.loads(SRC.read_text(encoding='utf-8'))
    out = {
        'version': 'iteration-20261114',
        'bgm_template': src['bgm_template'],
        'jobs': JOBS,
    }
    DST.parent.mkdir(parents=True, exist_ok=True)
    DST.write_text(json.dumps(out, ensure_ascii=False, indent=2), encoding='utf-8')
    print('jobs', len(JOBS), '->', DST)


if __name__ == '__main__':
    main()
