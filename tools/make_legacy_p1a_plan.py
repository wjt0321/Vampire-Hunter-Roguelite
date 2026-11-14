"""Build the P1-A plan: re-draw the 11 legacy MVP enemies in the current style.

Each legacy enemy gets:
- a new-style idle sheet (t2i, 4 frames) that replaces the old flat-named file,
- a new-style death sheet (edit from its own idle, 6 frames),
- and, where the legacy set had no movement loop, a run/walk sheet.

The old flat naming (vampire_idle.png) is kept for now: TextureManager still
registers those paths. New assets land in the same files so the engine picks
them up with no code change.

Character identity is written out in full for each enemy, because the model
has no memory of the old sprite and a vague "a werewolf" gives a different
creature every time.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'artifacts/iteration_assets/plan_legacy_p1a.json'

STYLE = (
    'dark gothic fantasy pixel art, chunky visible pixels, limited 32-color palette, '
    'brushed dark steel and worn leather, antique gold filigree trim, deep crimson gems, '
    'high contrast with dramatic rim light, crisp 2px black outline, dense micro-detail, '
    'muted desaturated shadows with a few saturated accents'
)

PROP = (
    'Mature heroic proportions, about 6 heads tall, narrow waist and broad shoulders. '
    'NOT chibi, NOT super-deformed, no oversized head, no big cute eyes, no toy-like look.'
)

BG = ('Flat solid pure magenta #FF00FF background, no gradient, no shadow, no ground, '
      'no text, no frame, no border.')


def enemy(asset, identity, extra='', frames=4, motion='idle'):
    return {
        'asset': asset,
        'mode': 't2i',
        'cell': 56,
        'frames': frames,
        'motion': motion,
        'steps': 25,
        'prompt': (identity + ' ' + extra + ' Full body, head to toe, front view, centered, '
                   'symmetrical stance, standing still. ' + STYLE + ' ' + PROP + ' ' + BG),
    }


def death(asset, source, description):
    return {
        'asset': asset,
        'mode': 'edit',
        'char_ref': 'raw:' + source,
        'cell': 56,
        'frames': 6,
        'motion': 'corpse',
        'steps': 25,
        'prompt': ('Redraw the single character from image 2 in ' + STYLE + ' ' + PROP + ' '
                   'Keep the character identity, outfit, colors and equipment from image 2 exactly, '
                   'but show it now dead: ' + description + ' '
                   'Full body, head to toe, front view, centered. ' + BG),
    }


def move(asset, source, description, motion='run', frames=6):
    return {
        'asset': asset,
        'mode': 'edit',
        'char_ref': 'raw:' + source,
        'cell': 56,
        'frames': frames,
        'motion': motion,
        'steps': 25,
        'prompt': ('Redraw the single character from image 2 in ' + STYLE + ' ' + PROP + ' '
                   'Keep the character identity, outfit, colors and equipment from image 2 exactly, '
                   'but show it in motion: ' + description + ' '
                   'Full body, head to toe, front view, centered, feet on the ground. ' + BG),
    }


ENEMIES = [
    {
        'id': 'vampire',
        'identity': ('A vampire lord: a tall aristocratic humanoid in a black leather doublet under a heavy '
                     'dark crimson high-collared cape fastened at the throat with an antique gold clasp set '
                     'with a large oval ruby, sharp pale face with high cheekbones and slicked black hair, '
                     'crimson-lined high boots, dark gauntlets with gold filigree, a straight dark steel rapier '
                     'held point down in the right hand'),
        'death': ('collapsed flat on the ground on its back, the dark crimson cape spread out and soaked '
                  'through with black blood, the pale face turned to the side with the mouth open and the '
                  'fangs showing, the antique gold throat clasp torn loose with the big ruby fallen out and '
                  'lying beside the head, the rapier slipped from the slack hand and lying flat in front '
                  'of the body, motionless'),
    },
    {
        'id': 'werewolf',
        'identity': ('A werewolf: a tall hulking humanoid wolf-man covered in coarse dark brown fur, a long '
                     'muzzled grey wolf head with bared yellow fangs and burning amber eyes, hunched '
                     'broad shoulders with a torn leather harness and antique gold studs across the chest, '
                     'bare clawed grey paws, digitigrade legs ending in dark hooves'),
        'death': ('collapsed on its side on the ground, the fur matted and bloodied, one hind leg folded '
                  'awkwardly under the body, the wolf head slack with the jaws still open and the yellow '
                  'fangs bared, the torn leather harness hanging open and the gold studs scattered loose '
                  'on the ground, one clawed paw stretched out, motionless'),
    },
    {
        'id': 'zombie',
        'identity': ('A shambling zombie: a bloated rotting humanoid with sickly desaturated green-grey '
                     'skin stretched over a swollen belly, sunken black eye sockets, a slack jaw with '
                     'rotting teeth, torn blackened burial clothes hanging in strips, one shoulder exposed '
                     'showing a dark crimson wound, bare cracked feet'),
        'death': ('collapsed forward onto the ground, the bloated body deflated and slumped, the torn '
                  'burial clothes spread out in the dirt, the slack jaw turned to the side with the rotting '
                  'teeth showing, the exposed shoulder wound dried to a dark scab, one arm stretched out '
                  'in front, motionless'),
    },
    {
        'id': 'bat',
        'identity': ('A giant vampire bat: a dark leathery winged creature with ragged scalloped wings of '
                     'deep charcoal membrane stretched over thin black finger bones, a furry dark brown body, '
                     'a short snout with small pale fangs and glowing crimson eyes, hooked black claws, '
                     'hanging upside down'),
        'death': ('fallen flat on the ground with the ragged wings crumpled and folded under the body, '
                  'one leathery wing stretched out and torn, the furry body limp, the small fangs bared in '
                  'a slack snout with the crimson eyes dimmed to dull points, motionless'),
    },
    {
        'id': 'skeleton',
        'identity': ('A skeleton archer: a bare bone humanoid skeleton in a tattered dark hood and a '
                     'short leather shoulder guard with antique gold rivets, a cracked bone-white skull '
                     'with two points of cold violet light in the eye sockets, holding a dark steel longbow '
                     'with an arrow nocked, thin bone fingers'),
        'death': ('collapsed into a heap of bones on the ground, the cracked skull rolled to one side with '
                  'the violet eye light gone out, the tattered hood fallen away, the longbow snapped in '
                  'two with the broken limbs and the nocked arrow lying separately, loose ribs and bone '
                  'fragments scattered around, motionless'),
    },
    {
        'id': 'exploder',
        'identity': ('An exploder: a bloated round humanoid corpse-puppet strapped with dark steel bands '
                     'and brass rivets, its swollen chest cavity split open to reveal a glowing red '
                     'chemical core packed with dark crimson alchemical fluid, thin arms with metal clamps, '
                     'short legs'),
        'death': ('burst apart on the ground, the steel straps and brass rivets sprung and scattered, the '
                  'swollen chest cavity torn fully open with the red chemical core spattered out and '
                  'burned out to black crust, the thin arms flung to either side, motionless'),
    },
    {
        'id': 'gargoyle',
        'identity': ('A stone gargoyle: a squat winged guardian carved from rough grey granite blocks with '
                     'mossy cracks, heavy folded bat wings of stone, a blunt snarling face with no eyes, '
                     'claws of grey stone, patches of dull green lichen'),
        'death': ('collapsed into a heap of broken stone on the ground, one heavy stone wing snapped off '
                  'and lying apart, large chunks of grey granite scattered around with lichen on the '
                  'broken faces, the blunt snarling face cracked in half, motionless'),
    },
    {
        'id': 'vampire_mage',
        'identity': ('A vampire mage: a gaunt humanoid in a long deep purple robe embroidered with faded '
                     'gold thread and trimmed in dark crimson, a pointed hood shadowing a skull-like pale '
                     'face with two violet lights in the sockets, holding a slender dark steel wand tipped '
                     'with a violet crystal, bone-thin hands'),
        'death': ('collapsed on the ground with the deep purple robe spread out and its gold thread '
                  'embroidery dulled, the pointed hood fallen back, the skull-like pale face turned upward '
                  'with the violet lights gone out, the slender wand broken and lying beside the body, '
                  'dark purple dust spilling out of the robe folds, motionless'),
    },
    {
        'id': 'summoner',
        'identity': ('A summoner: a tall gaunt humanoid in a dark charcoal robe with a deep crimson sash, '
                     'an iron half-mask covering the upper face with two burning orange lights in the '
                     'eye slits, bone charms and small bronze bells strung across the chest, both hands '
                     'raised with clawed fingers'),
        'death': ('collapsed on the ground with the dark charcoal robe pooled around the body and the '
                  'deep crimson sash askew, the iron half-mask fallen off to one side with the orange '
                  'lights snuffed out, the bone charms and bronze bells spilled loose and scattered, '
                  'both clawed hands slack, motionless'),
    },
    {
        'id': 'vampire_prince',
        'identity': ('A vampire prince: a tall lean humanoid in a dark steel breastplate over a deep '
                     'crimson doublet, a heavy dark cape lined in antique gold, a pale narrow face with '
                     'slicked back black hair and a thin scar, red gloves, holding a slender dark steel '
                     'sword'),
        'death': ('collapsed on the ground, the heavy gold-lined cape spread out and bloodied, the dark '
                  'steel breastplate dented and split, the slender sword slipped from one slack red-gloved '
                  'hand and lying flat, the pale narrow face turned to the side with the hair across the '
                  'face, motionless'),
    },
    {
        'id': 'elite_vampire',
        'identity': ('An elite vampire: a hulking armored vampire in heavy dark steel plate with gold '
                     'filigree edging, a deep crimson cape, a horned closed helm with two glowing '
                     'crimson eye slits, a huge two-handed dark steel greatsword resting on the shoulder'),
        'death': ('collapsed face down on the ground, the heavy dark steel plate dented all over, the '
                  'horned closed helm cracked and lying apart from the head, the gold filigree edging '
                  'torn, the huge greatsword dropped flat in front with the crimson eye lights out, '
                  'the deep crimson cape spread out and soaked, motionless'),
    },
]


def build():
    plan = []
    for e in ENEMIES:
        eid = e['id']
        plan.append(enemy(eid + '_idle', e['identity']))
        plan.append(death(eid + '_death', eid + '_idle', e['death']))
    # 移动缺口：只有旧版没有独立移动表的几个需要补
    plan.append(move('werewolf_run', 'werewolf_idle',
                      'the werewolf loping forward at a run, body pitched forward, one clawed paw lifted '
                      'and the other planted, the torn leather harness and fur streaming back'))
    plan.append(move('summoner_walk', 'summoner_idle',
                      'the summoner walking forward slowly, both clawed hands lowered to the sides, the '
                      'bone charms and bronze bells swinging, the dark charcoal robe swaying'))
    plan.append(move('vampire_mage_walk', 'vampire_mage_idle',
                      'the mage walking forward slowly with the deep purple robe swaying, the slender '
                      'wand held low in one bone-thin hand'))
    plan.append(move('elite_vampire_run', 'elite_vampire_idle',
                      'the elite vampire charging forward at a run, the heavy dark steel plate shifting, '
                      'the huge greatsword still resting on the shoulder, the deep crimson cape '
                      'streaming back'))
    plan.append(move('vampire_prince_run', 'vampire_prince_idle',
                      'the vampire prince running forward, the heavy gold-lined cape streaming back and '
                      'the slender sword carried low'))
    plan.append(move('zombie_walk', 'zombie_idle',
                      'the shambling zombie lurching forward, the swollen belly swaying, the torn '
                      'burial clothes dragging, one arm hanging low'))
    OUT.write_text(json.dumps(plan, ensure_ascii=False, indent=2), encoding='utf-8')
    print('plan', len(plan), '->', OUT)


if __name__ == '__main__':
    build()