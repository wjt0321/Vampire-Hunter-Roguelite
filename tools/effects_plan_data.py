"""特效 / 道具的序列帧提示词与参数（P1-B + P2）。

提示词结构照抄「死亡条」那套已验证的写法：
  「Image 1 is the same effect repeated in N identical cells on a magenta card.
    Redraw all N cells as one continuous animation of that exact effect ...」
早期版本写成「Draw the SAME effect in six separate square cells arranged in 3 columns
and 2 rows」，模型理解成了「画六个带暗底板的独立小画格」，
每个格子里都多出一块黑色底板和装饰边框——这不是素材本身的问题，是提示词的问题。

每条：
  name    输出 basename
  src     现有单帧 PNG（造型/配色锚）
  frames  帧数
  cell    单格尺寸（w, h）
  layout  "row" = 横排，"grid" = 3 列 2 行
  mode    "once" / "loop"
  anchor  "bottom" = 底部对齐（火把/营火/宝箱这类站地的东西）
  steps   逐格要画什么，按列表写
"""

STYLE = (
    'Dark gothic fantasy pixel art, chunky visible pixels, limited 32-color palette, '
    'deep crimson and bone white highlights over near-black shadows, '
    'high contrast with dramatic rim light, crisp 2px black outline, dense micro-detail, '
    'muted desaturated shadows with a few saturated accents'
)

BG = (
    'Flat solid pure magenta #FF00FF background, uniform bright magenta color card, '
    'no gradient, no shadow on the background, no text, no grid lines, '
    'no smoke or haze in the background.'
)

EFFECTS = [
    dict(name='hit_effect', src='assets/effects/hit_effect.png',
         frames=4, cell=(64, 64), layout='row', mode='once',
         steps=[
             'a tight bright pinpoint flash of pale gold light',
             'the flash expanding into a radiating star of gold sparks',
             'the star breaking into short streaking sparks flying outward',
             'the sparks scattering and fading out, leaving only a faint glow',
         ]),

    dict(name='death_explosion', src='assets/effects/death_explosion.png',
         frames=6, cell=(128, 128), layout='grid', mode='once',
         steps=[
             'a small tight fire core with a few sparks',
             'the fireball swelling and growing brighter',
             'the fireball at full blast with cracks of light running through it',
             'the fire breaking into rolling dark smoke',
             'the smoke expanding and cooling to pale grey',
             'only dark smoke and a few dying embers, the fire almost gone',
         ]),

    dict(name='portal', src='assets/effects/portal.png',
         frames=6, cell=(96, 96), layout='grid', mode='loop',
         steps=[
             'the swirl of violet arcane energy turning slowly, dim',
             'the swirl turning faster with the crimson gems brightening',
             'the swirl at its brightest, the gems fully lit',
             'the swirl turning again, the gems dimming a little',
             'the swirl nearly back to its first phase, dimmer',
             'the swirl almost identical to the first phase, about to repeat',
         ]),

    dict(name='shield_break', src='assets/effects/shield_break.png',
         frames=6, cell=(64, 64), layout='grid', mode='once',
         steps=[
             'the intact round shield of dark steel with a crimson gem in the centre',
             'a crack opening across the shield face',
             'the crack spreading into a spiderweb of fractures',
             'the shield bursting apart into shards',
             'the shards flying apart and spinning',
             'only a few shards and dust falling',
         ]),

    dict(name='poison_spread', src='assets/effects/poison_spread.png',
         frames=6, cell=(128, 128), layout='grid', mode='loop',
         steps=[
             'a patch of thick green poison mist with a few bubbles',
             'the mist churning and rolling inward',
             'more bubbles rising and popping in the mist',
             'the mist swirling the other way',
             'the mist settling back toward its first shape',
             'the mist almost identical to the first phase, about to repeat',
         ]),

    dict(name='levelup_aura', src='assets/effects/levelup_aura.png',
         frames=6, cell=(128, 128), layout='grid', mode='once',
         steps=[
             'faint runic outlines appearing on the ground',
             'the runic circle completing and brightening',
             'the runes blazing to white gold',
             'the circle erupting upward into a column of light',
             'the light thinning and falling back down',
             'only faint dying runes left on the ground',
         ]),

    dict(name='freeze_effect', src='assets/effects/freeze_effect.png',
         frames=6, cell=(48, 48), layout='grid', mode='once',
         steps=[
             'a thin frost outline forming',
             'frost spreading over more of the shape',
             'the ice thickening into a solid shell',
             'the shell fully formed and opaque pale blue-white',
             'the ice cracking apart',
             'only shattered ice fragments and frost drifting',
         ]),

    dict(name='petrify_effect', src='assets/effects/petrify_effect.png',
         frames=6, cell=(48, 48), layout='grid', mode='once',
         steps=[
             'a thin grey stone crust appearing',
             'the crust spreading across the shape',
             'the stone shell thickening and turning fully grey',
             'the shell solid with cracks running through it',
             'the stone shell hardening and darkening',
             'the stone shell fully formed and still',
         ]),

    dict(name='holy_light', src='assets/effects/holy_light.png',
         frames=6, cell=(128, 128), layout='grid', mode='once',
         steps=[
             'a narrow faint beam of pale gold light',
             'the beam widening and brightening',
             'the beam at full strength with strong rays',
             'the beam bursting outward',
             'the light thinning into drifting motes',
             'only a few fading sparks left',
         ]),

    dict(name='chain_lightning', src='assets/effects/chain_lightning.png',
         frames=4, cell=(128, 128), layout='row', mode='once',
         steps=[
             'a thin faint violet arc of electricity striking one point',
             'the arc brightening and branching into smaller forks',
             'the bolt at full brightness with many branches and sparks',
             'the bolt fading into scattered sparks and smoke',
         ]),

    dict(name='thunder_wrath', src='assets/effects/thunder_wrath.png',
         frames=6, cell=(128, 128), layout='grid', mode='once',
         steps=[
             'a faint fork of lightning in the sky',
             'the bolt descending toward the ground',
             'the bolt hitting the ground in a burst',
             'the impact ringing outward as a bright shockwave',
             'the afterglow fading',
             'only smoke and dying sparks on the ground',
         ]),
]

PROPS = [
    dict(name='torch', src='assets/tiles/props/torch.png',
         frames=4, cell=(24, 48), layout='row', mode='loop', anchor='bottom',
         steps=[
             'the flame flickering up in a tall thin tongue',
             'the flame bending sideways and dimming',
             'the flame shrinking to a small bright tip',
             'the flame flaring back up, almost identical to the first phase',
         ]),

    dict(name='campfire', src='assets/tiles/props/campfire.png',
         frames=4, cell=(40, 48), layout='row', mode='loop', anchor='bottom',
         steps=[
             'the flames rising high above the logs',
             'the flames flickering lower and to one side',
             'the flames low, with embers glowing brighter',
             'the flames flaring up again, almost identical to the first phase',
         ]),

    dict(name='chest', src='assets/tiles/props/chest.png',
         frames=6, cell=(48, 40), layout='grid', mode='once', anchor='bottom',
         steps=[
             'the closed antique wooden chest bound with dark steel and an antique gold lock',
             'the lock clasp lifting and glowing pale gold',
             'the lid cracking open a little',
             'the lid opening wide with pale gold light spilling out',
             'the lid fully open with the light at its brightest',
             'the lid fully open with the light settled and the chest still open',
         ]),

    dict(name='cursed_chest', src='assets/items/cursed_chest.png',
         frames=6, cell=(48, 40), layout='grid', mode='once', anchor='bottom',
         steps=[
             'the sealed blackened iron-bound chest with dim violet runes on the seams',
             'the runes flaring bright violet',
             'the lid binding cracking open',
             'the lid lifting with violet light pouring out',
             'the chest open with the curse light swirling above it',
             'the chest open with the light settled and the crimson gem lit',
         ]),

    dict(name='merchant', src='assets/ui/merchant.png',
         frames=4, cell=(128, 128), layout='row', mode='loop', anchor='bottom',
         steps=[
             'the hooded merchant standing still with the shoulders level',
             'the shoulders shifting slightly and the head tilting a little',
             'the robe hem swaying to one side',
             'the merchant almost identical to the first pose, about to repeat',
         ]),
]

ALL = EFFECTS + PROPS
