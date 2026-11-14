"""迭代新增 12 个敌人的专属动作条计划 + 血铠幼虫。

这批敌人上一轮只做了「待机 + 死亡」，本轮补它们各自的行为动作：
每个动作条 6 帧，落在 assets/sprites/enemies/<enemy>/<state>.png。

state 名与脚本请求的状态名一致（见 asset_slots.gd 的 ENEMIES 登记表），
文件放对即自动生效。

steps 里逐格点名要画什么，模型才不会把 6 格画成同一张。
"""

ACTIONS = [
    dict(enemy="shield_guard", state="guard", frames=6,
         action="raising a heavy shield and bracing to block an incoming strike",
         steps=(
             "1 standing braced with the tall dark steel shield held low in front of the body, "
             "2 the shield lifting to cover the chest with the shoulders squared behind it, "
             "3 the shield pushed forward in a full block with the arms braced and the body leaning back, "
             "4 the shield still forward with the whole body braced against the impact, "
             "5 the shield lowering slightly as the body starts to push forward, "
             "6 stepping forward with the shield held out in front and the head lowered behind it")),

    dict(enemy="blood_hound", state="pounce", frames=6,
         action="crouching then leaping forward in a pouncing attack",
         steps=(
             "1 crouching low on all fours with the clawed paws spread on the ground and the muzzled head lowered, "
             "2 the hind legs coiling with the shoulders bunched and the torn leather harness stretched, "
             "3 launching forward in a long leap with the jaws open and the yellow fangs bared, "
             "4 airborne at full stretch with the front paws extended and the dark fur streaming back, "
             "5 landing hard on the front paws with the head lunging forward, "
             "6 sliding to a stop with the head low and the fangs still showing")),

    dict(enemy="blood_priest", state="cast", frames=6,
         action="raising both arms and channeling a healing spell",
         steps=(
             "1 standing with the arms lowered and the hooded head bowed and the face clearly visible, "
             "2 both hands lifting to shoulder height with the fingers spread, "
             "3 the arms raised higher with the palms turned upward, "
             "4 the arms fully raised overhead with the face and hood clearly visible, "
             "5 the arms beginning to lower with the face still clearly visible, "
             "6 lowering the arms back down with the head bowed. "
             "The red priest stays in the same spot in every cell. "
             "The face and the head are always visible and never covered by any light or glow. "
             "There is NO glowing ball, NO light orb and NO bright flare anywhere in any cell. "
             "Only a few tiny dull red sparks near the hands, no large bright red shape")),

    dict(enemy="web_weaver", state="cast", frames=6,
         action="spitting out a sticky web from its abdomen",
         steps=(
             "1 crouching low with the abdomen lifted and the mandibles working, "
             "2 the abdomen swelling and the dark green silk starting to gather, "
             "3 the abdomen pulsing brighter with a strand of web stretching out, "
             "4 the strand shooting forward and widening into a sheet of green web, "
             "5 the web sheet fully extended with the abdomen still raised, "
             "6 the web released and the abdomen lowering back down")),

    dict(enemy="burrower", state="burrow", frames=6,
         action="sinking into the ground and burrowing under it",
         steps=(
             "1 standing upright with the shovel-like forelimbs raised, "
             "2 the body lowering with the forelimbs digging into the ground, "
             "3 sinking to half height with dirt and pebbles around the shoulders, "
             "4 sinking further so only the head and shoulders remain above the ground, "
             "5 almost fully underground with just the top of the head visible, "
             "6 gone completely with only disturbed dirt and a small hole left on the ground")),

    dict(enemy="gem_leech", state="steal", frames=6,
         action="scooping up a glowing crystal and gulping it down",
         steps=(
             "1 lowering the wide open maw toward a small glowing crystal on the ground, "
             "2 the maw clamped around the glowing crystal, "
             "3 pulling the crystal up with the throat bulging, "
             "4 the crystal swallowed and the body swelling up with the veins lighting up, "
             "5 the swollen body still glowing from inside, "
             "6 turning away and slinking off with the belly still full and glowing")),

    dict(enemy="coffin_guard", state="revive", frames=6,
         action="clawing its way back out of the coffin and rising to its feet",
         steps=(
             "1 a cracked wooden coffin lid breaking open with a hand pushing up from inside, "
             "2 the upper body rising out of the coffin with splinters falling, "
             "3 the figure hauling itself higher with one arm braced on the coffin edge, "
             "4 swinging one leg over the coffin rim, "
             "5 stepping down out of the coffin and standing hunched, "
             "6 straightening up to full height with the arms hanging at the sides")),

    dict(enemy="lantern_wraith", state="beam", frames=6,
         action="raising the lantern and releasing a straight beam of light",
         steps=(
             "1 hovering with the brass lantern hanging low and dim, "
             "2 the lantern lifting to chest height and the flame inside brightening, "
             "3 the lantern held forward with the light swelling to a bright core, "
             "4 the beam starting to pour forward out of the lantern opening, "
             "5 the beam fully extended and shining straight ahead, "
             "6 the beam holding steady with the wraith hovering in place")),

    dict(enemy="alchemist_pitcher", state="throw", frames=6,
         action="pulling back an arm and hurling a glass potion flask",
         steps=(
             "1 standing with a green glass flask held in front of the chest, "
             "2 the arm drawing the flask back to the shoulder, "
             "3 winding up further with the flask held high behind the head, "
             "4 the arm whipping forward and releasing the flask, "
             "5 the flask flying away in the air with a green trail, "
             "6 the throwing arm following through with the flask gone from the hand")),

    dict(enemy="furnace_golem", state="charge", frames=6,
         action="shattering its armor and charging forward in a rage",
         steps=(
             "1 standing with the heavy iron plates still intact and the furnace core glowing dim, "
             "2 the iron plates cracking apart with the core flaring bright orange, "
             "3 the broken plates falling away and the core burning white hot, "
             "4 leaning forward and driving off the ground in a charge, "
             "5 charging forward with the bare core blazing and the arms swinging, "
             "6 still charging with the core streaming heat and the head lowered")),

    dict(enemy="resonance_mage", state="cast", frames=6,
         action="reaching out with both hands and linking to nearby allies",
         steps=(
             "1 standing with the arms lowered and the head bowed, "
             "2 the hands lifting in front of the chest with a violet glow gathering, "
             "3 both hands spread wide with violet energy arcing between the fingers, "
             "4 one arm thrusting forward with a bright violet link shooting out, "
             "5 the other arm joining so two violet links cross the body, "
             "6 the arms lowering with the violet links still reaching out and fading")),

    dict(enemy="blood_larva", state="pounce", frames=6,
         action="coiling up and then lunging forward to bite",
         steps=(
             "1 the crimson larva coiled tight on the ground with the blunt head lowered, "
             "2 the segmented body bunching up and the pale ribs compressing together, "
             "3 the head pulling back with the wide fanged mouth opening, "
             "4 launching forward in a long lunge with the body uncoiling and the tail trailing, "
             "5 airborne and stretched out straight with the jaws still open, "
             "6 landing and biting down with the body settling back into a coil")),
    dict(enemy="moon_wing", state="dive", frames=6,
         action="folding the wings and diving downward at speed",
         steps=(
             "1 hovering with the wide pale wings spread open, "
             "2 the wings folding back tight against the body, "
             "3 the head tipping down and the body angling downward, "
             "4 plunging straight down with the wings fully folded and a wind streak behind, "
             "5 still diving fast with the wind streaming upward past the body, "
             "6 pulling out of the dive at the bottom with the wings starting to open again")),
]
