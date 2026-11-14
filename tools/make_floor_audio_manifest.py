"""Build the per-floor BGM manifest (5 floors, one loop each).

Why: the game shipped 6 BGM files but every combat room played the same
battle loop, so a whole run sounded like one song. Now each dungeon floor
has its own loop and the music changes as you descend.

The generation pipeline is the proven 2026-11-14 one:
    make_floor_audio_manifest.py -> render_iteration_audio.py -> prepare_iteration_audio.py
The ComfyUI workflow template (YuE2 + instrumental LoRAs) is copied verbatim
from the iteration manifest so the new tracks sit in the same sonic family.
"""
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / 'artifacts/game-audio-iteration/manifest.json'
DST = ROOT / 'artifacts/game-audio-floor/manifest.json'

BGM_STYLE = (
    "Chunky-pixel gothic dark fantasy, instrumental only, no vocals, no choir, "
    "no speech, no lyrics. Dark steel, antique gold filigree and deep crimson "
    "colour. "
)

JOBS = [
    {
        'kind': 'bgm', 'key': 'floor_1', 'label': '血月回廊', 'duration': 60, 'loop': True,
        'seed': 2026111601,
        'prompt': BGM_STYLE + (
            "Floor 1 corridor battle loop, 124 BPM, 4/4, D minor. "
            "Harpsichord staccato melody, pizzicato string ostinato, restrained "
            "pipe organ bass and a dry frame drum pulse, like chunky 16-bit "
            "gothic game music. "
            "Steady forward hunting rhythm, repeating eight-bar phrases, "
            "clear instrument separation and room for game sound effects. "
            "The beat starts immediately, no long intro, no breakdown, no fade out."
        ),
    },
    {
        'kind': 'bgm', 'key': 'floor_2', 'label': '织血巢穴', 'duration': 60, 'loop': True,
        'seed': 2026111602,
        'prompt': BGM_STYLE + (
            "Floor 2 blood nest battle loop, 132 BPM, 4/4, F sharp minor. "
            "Muted low strings, a detuned harpsichord answering a plucked lute, "
            "pipe organ pedal notes and irregular wet dripping percussion over a "
            "slow heartbeat kick, like chunky 16-bit gothic game music. "
            "Claustrophobic but steady, repeating eight-bar phrases, "
            "clear instrument separation and room for game sound effects. "
            "The beat starts immediately, no long intro, no breakdown, no fade out."
        ),
    },
    {
        'kind': 'bgm', 'key': 'floor_3', 'label': '骸骨墓穴', 'duration': 60, 'loop': True,
        'seed': 2026111603,
        'prompt': BGM_STYLE + (
            "Floor 3 bone crypt battle loop, 108 BPM, 4/4, A minor. "
            "Hollow low bells, sparse pizzicato cello, a lonely harpsichord pulse "
            "and dry bone-shaker percussion, like chunky 16-bit gothic game music. "
            "Slow ominous funeral march that keeps moving, repeating eight-bar "
            "phrases, lots of space and room for game sound effects. "
            "The beat starts immediately, no long intro, no breakdown, no fade out."
        ),
    },
    {
        'kind': 'bgm', 'key': 'floor_4', 'label': '炼金工坊', 'duration': 60, 'loop': True,
        'seed': 2026111604,
        'prompt': BGM_STYLE + (
            "Floor 4 alchemy workshop battle loop, 138 BPM, 4/4, C minor. "
            "Mechanical gear-and-pipe percussion, clanging muted metal hits, a "
            "quirky pizzicato bass ostinato and a bright harpsichord hook over a "
            "pipe organ drone, like chunky 16-bit gothic game music. "
            "Brisk and industrious with an uneasy edge, repeating eight-bar "
            "phrases, clear instrument separation and room for game sound effects. "
            "The beat starts immediately, no long intro, no breakdown, no fade out."
        ),
    },
    {
        'kind': 'bgm', 'key': 'floor_5', 'label': '月蚀王座', 'duration': 60, 'loop': True,
        'seed': 2026111605,
        'prompt': BGM_STYLE + (
            "Floor 5 eclipse throne battle loop, 146 BPM, 4/4, E minor. "
            "Wide tremolo strings, a deep pipe organ drone, sharp harpsichord "
            "stabs and relentless tight electronic drums, like chunky 16-bit "
            "gothic game music. "
            "The heaviest and most driving floor, oppressive without a break, "
            "repeating eight-bar phrases, leave space for game sound effects. "
            "The beat starts immediately, no long intro, no breakdown, no fade out."
        ),
    },
]


def main():
    src = json.loads(SRC.read_text(encoding='utf-8'))
    out = {
        'version': 'floor-20261116',
        'bgm_template': src['bgm_template'],
        'jobs': JOBS,
    }
    DST.parent.mkdir(parents=True, exist_ok=True)
    DST.write_text(json.dumps(out, ensure_ascii=False, indent=2), encoding='utf-8')
    print('jobs', len(JOBS), '->', DST)


if __name__ == '__main__':
    main()
