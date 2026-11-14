"""旧敌人「动作姿态」表（P1-A 第二半）。

一条目 = 一张动作精灵条。做法是把该敌人的新风格立绘原图拼成 N 格品红底卡片，
让 Qwen-Image-Edit 把每一格重画成同一角色的不同姿态，再切格拼成横条。

steps 里逐格点名要画什么，模型才不会把 6 格画成同一张。

enemy  = 敌人 id（决定专属目录）
state  = 游戏里请求的状态名（决定文件落在 <enemy>/<state>.png）
frames = 帧数
steps  = 逐格描述，逗号分隔，"1 ..., 2 ..., ..."
action = 动作总述，写进提示词
"""

ACTIONS = [
    dict(enemy="vampire", state="run", frames=6,
         action="sprinting forward with the rapier drawn low",
         steps=(
             "1 striding forward with the right leg extended and the rapier held low at the side, "
             "2 the body pitched forward with the dark crimson cape streaming back and the left boot pushing off the ground, "
             "3 mid-stride with the cape swept fully behind and both boots off the ground, "
             "4 the left boot landing ahead with the shoulders turned and the rapier angled back, "
             "5 pushing hard off the right boot with the cape flaring wide, "
             "6 slowing down with the cape settling and the rapier coming back up to guard")),
    dict(enemy="werewolf", state="charge", frames=6,
         action="winding up and leaping forward in a pouncing charge",
         steps=(
             "1 crouching low with the clawed paws on the ground and the muzzled head lowered, "
             "2 the hind legs coiling and the shoulders bunching as the torn leather harness stretches, "
             "3 launching forward in a long leap with the jaws open and the yellow fangs bared, "
             "4 airborne at full stretch with the claws extended and the brown fur streaming back, "
             "5 landing hard on the front paws with the head lunging forward, "
             "6 sliding to a stop with the head low and the fangs still showing")),
    dict(enemy="bat", state="fly", frames=6,
         action="beating its wings while hanging upside down",
         steps=(
             "1 hanging with both ragged wings spread wide and fully raised, "
             "2 the wings beating down with the membrane stretched taut, "
             "3 the wings at the bottom of the stroke and the body swinging forward, "
             "4 the wings sweeping up again with the tips curled, "
             "5 the wings at the top of the stroke with the body swinging back, "
             "6 the wings passing through the middle of the stroke again. "
             "The body stays hanging upside down and the crimson eyes stay lit in every cell")),
    dict(enemy="zombie", state="walk", frames=6,
         action="shambling forward with a lurching gait",
         steps=(
             "1 lurching forward with the left leg swinging ahead and the swollen belly swaying, "
             "2 the right leg dragging and the torn burial clothes trailing, "
             "3 the left foot planted and the shoulders slumped forward, "
             "4 the right leg swinging ahead and the head lolling to one side, "
             "5 both feet close together and the belly swaying the other way, "
             "6 the zombie mid-stride again with one arm hanging low")),
    dict(enemy="skeleton", state="shoot", frames=6,
         action="nocking an arrow and firing the longbow",
         steps=(
             "1 raising the dark steel longbow with an arrow nocked and the bow arm straight, "
             "2 drawing the bowstring back with the arrow tip near the cheek, "
             "3 holding the draw at full tension with the violet eye lights bright, "
             "4 releasing the string with the arrow leaving the bow, "
             "5 the bow snapping forward with the loose string vibrating, "
             "6 lowering the bow with the spent arm dropping. "
             "The skeleton stays in the same spot in every cell")),
    dict(enemy="exploder", state="walk", frames=6,
         action="waddling forward with the chemical core pulsing",
         steps=(
             "1 waddling forward with the swollen steel-strapped body leaning to one side, "
             "2 the red chemical core in the split chest cavity glowing brighter, "
             "3 the other foot planting with the body leaning the other way, "
             "4 the core pulsing brighter and the thin arms swinging out, "
             "5 the body leaning back as the core flares, "
             "6 a heavy step with the core dimming slightly. "
             "The corpse-puppet keeps the same metal straps and rivets in every cell")),
    dict(enemy="exploder", state="explode", frames=6,
         action="swelling up and bursting apart",
         steps=(
             "1 the swollen chest cavity splitting wider with the red core glowing hot, "
             "2 the core swelling and the steel straps starting to bow outward, "
             "3 the whole body inflating with the core blindingly bright, "
             "4 the steel straps snapping and the body rupturing with the core flaring white, "
             "5 the burst body collapsing inward with dark crimson fluid spraying out, "
             "6 only a blackened empty shell lying flat on the ground with the burnt-out core as a black crust")),
    dict(enemy="gargoyle", state="petrify", frames=6,
         action="being turned into stone",
         steps=(
             "1 the gargoyle standing as it always is, rough grey granite with mossy cracks and green lichen, "
             "2 the lower half of the gargoyle turned to smooth pale stone, the legs and the tail already stone, "
             "3 the pale stone climbing up to the chest, the folded stone wings half covered, "
             "4 the pale stone climbing past the shoulders, the blunt head half turned to stone, "
             "5 the whole gargoyle now smooth pale stone, the moss and lichen gone and the cracks sealed, "
             "6 the gargoyle a completely solid pale stone statue, every part stone, standing rigid and motionless")),
    dict(enemy="gargoyle", state="wake", frames=6,
         action="shedding the stone shell and rising back to life",
         steps=(
             "1 the gargoyle as a completely smooth pale stone statue, totally rigid, "
             "2 a crack splitting the pale stone torso and stone chips falling away, "
             "3 half the stone shell gone, rough grey granite with moss and lichen showing through, "
             "4 most of the shell gone, the gargoyle's real granite body almost fully revealed, "
             "5 the last stone pieces sliding off the shoulders and the gargoyle straightening up, "
             "6 fully awake, standing tall with the heavy rough granite wings spreading wide")),
    dict(enemy="vampire_mage", state="cast", frames=6,
         action="raising the wand and releasing a violet spell",
         steps=(
             "1 the mage raising the slender dark steel wand with the violet crystal at its tip, "
             "2 the wand held high with a violet glow gathering around the crystal, "
             "3 the violet light swelling into a bright orb above the raised hand, "
             "4 the mage sweeping the wand forward and the orb flaring, "
             "5 the spell releasing with a violet bolt leaving the crystal, "
             "6 the wand lowering as the last violet sparks fade. "
             "The deep purple robe and its gold embroidery stay the same in every cell")),
    dict(enemy="vampire_mage", state="teleport", frames=6,
         action="dissolving into violet motes and re-forming",
         steps=(
             "1 the mage standing solid with the deep purple robe fully opaque, "
             "2 the lower body turning transparent and violet motes lifting off the hem, "
             "3 the mage half dissolved into swirling violet dust with only the hood outline left, "
             "4 almost nothing left but a cloud of violet motes and the faint outline of the wand, "
             "5 the motes gathering back together and the robe re-forming, "
             "6 the mage fully solid again in the same spot with the robe whole")),
    dict(enemy="summoner", state="cast", frames=6,
         action="raising both hands and calling up creatures",
         steps=(
             "1 the summoner raising both clawed hands to shoulder height, "
             "2 the bone charms and small bronze bells lifting and swinging, "
             "3 the orange lights in the iron half-mask flaring brighter, "
             "4 a dark crimson ring of energy forming between the raised hands, "
             "5 the ring breaking apart as dark shapes tear out of it, "
             "6 the summoner lowering the arms as the last crimson sparks fade")),
    dict(enemy="vampire_prince", state="dash", frames=6,
         action="dashing forward with the gold-lined cape streaming",
         steps=(
             "1 the prince dropping into a low forward dash with the gold-lined cape swept back, "
             "2 driving forward with the right leg extended and the slender sword carried low, "
             "3 mid-dash with the cape streaming straight back and the black hair blown across the face, "
             "4 the left boot landing ahead with the dark steel breastplate catching the light, "
             "5 pushing off the ground with the cape flaring to one side, "
             "6 sliding to a stop with the sword coming back up")),
    dict(enemy="vampire_prince", state="rage", frames=6,
         action="surging into a rage and raising the sword overhead",
         steps=(
             "1 the prince standing rigid with the shoulders squared and the sword lowered, "
             "2 the head lifting and the pale narrow face snarling, "
             "3 the mouth open in a rage howl with the thin scar standing out, "
             "4 the sword raised high above the head with the cape flaring wide, "
             "5 the sword still held overhead with the body shaking and the cape thrown back, "
             "6 the prince dropping the sword back down with the chest heaving. "
             "The gold-lined cape flares wide in every cell")),
]

# 需要同时写到两个目录的敌人：
# 精英吸血鬼的贴图键是 "elite_vampire"，但 _get_enemy_type() 返回 "elite"，
# 而死亡动画是按 _get_enemy_type() 找表的，两边都得有。
EXTRA_DEATH_DIRS = {
    "elite_vampire": ["elite"],
}
