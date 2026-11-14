"""旧 MVP 11 个敌人的受击条（hurt）补齐计划。

2026-11-14 第二十一节给迭代新增的 13 个敌人做了 hurt 条并接上请求点；
这 11 个旧敌人当时没图，挨打静默跳过。本条线与 iter_pose_data.py 的
hurt 段同规格：6 帧 56px 横条，弧线固定「挨打 → 后仰 → 踉跄 → 找回平衡 →
站稳 → 回到原姿势」，最后一格必须回到原姿势，接回待机条才不跳。

基准卡片用 RAW/<enemy>_idle.png（pose_grid 管线惯例），产物落
assets/sprites/enemies/<enemy>/hurt.png，enemy_base.play_hurt_strip 自动生效。

elite_vampire.gd 的 _get_enemy_type() 返回 "elite"，所以目录名是 elite/。
"""

ACTIONS = [
    dict(enemy="vampire", state="hurt", frames=6,
         action="recoiling from a hit and staggering back",
         steps=(
             "1 the cloaked vampire struck with the body jolting backward and the head snapping back, "
             "2 the torso arching back with the high collar thrown back and one arm flung wide, "
             "3 the vampire staggering with the shoulders twisted and the cloak flaring out, "
             "4 the stagger slowing with the head coming back level and the cloak settling, "
             "5 the vampire straightening with the arms gathering back in, "
             "6 back in the original upright stance with the cloak wrapped tight and the head forward")),
    dict(enemy="zombie", state="hurt", frames=6,
         action="shuddering back from a hit",
         steps=(
             "1 the hunched zombie jolted with the head snapping back and the arms thrown up, "
             "2 the body shuddering backward with the jaw hanging open and the shoulders hunched, "
             "3 the zombie stumbling with the arms dangling and the body tilted, "
             "4 the stumble slowing with the head lolling forward and the body still swaying, "
             "5 the zombie steadying with the arms lowering, "
             "6 back in the original shambling stance with the arms hanging loose")),
    dict(enemy="bat", state="hurt", frames=6,
         action="jolted in midair by a hit",
         steps=(
             "1 the bat struck in flight with the body jolting and the wings jerking upward, "
             "2 the body tumbling with the wings folded sharply and the fangs bared, "
             "3 the bat flapping unevenly with the body thrown off balance and the wings out of sync, "
             "4 the wings steadying with the body still tilted, "
             "5 the bat righting itself with the wings beating evenly again, "
             "6 back in the original flying pose with the wings spread wide")),
    dict(enemy="skeleton", state="hurt", frames=6,
         action="rattled by a hit with the bow dropping",
         steps=(
             "1 the skeleton archer struck with the skull snapping back and the bow arm thrown wide, "
             "2 the ribcage jolting with the spine arching and the jaw clacking open, "
             "3 the skeleton staggering with the bow dangling low and the knees wobbling, "
             "4 the stagger slowing with the skull coming back level and the ribs realigning, "
             "5 the skeleton gathering itself with the bow being raised again, "
             "6 back in the original archer stance with the bow held ready")),
    dict(enemy="werewolf", state="hurt", frames=6,
         action="thrown back by a heavy hit",
         steps=(
             "1 the werewolf struck with the massive body jolting back and the head snapping up, "
             "2 the body reeling with the claws flung wide and the back arching, "
             "3 the werewolf staggering on its hind legs with the arms windmilling, "
             "4 the stagger slowing with the head lowered and the shoulders hunched, "
             "5 the werewolf planting its feet and rising back up, "
             "6 back in the original hunched predatory stance with the claws forward")),
    dict(enemy="exploder", state="hurt", frames=6,
         action="jiggling back from a hit with the swollen body wobbling",
         steps=(
             "1 the bloated exploder struck with the swollen body jolting and the head snapping back, "
             "2 the body wobbling backward with the belly quivering and the stubby arms flailing, "
             "3 the exploder staggering with the body tilted and the belly still wobbling, "
             "4 the wobble slowing with the body settling and the head coming back level, "
             "5 the exploder steadying with the arms lowering, "
             "6 back in the original waddling stance with the swollen belly forward")),
    dict(enemy="gargoyle", state="hurt", frames=6,
         action="rocking back as stone chips fly",
         steps=(
             "1 the stone gargoyle struck with the body jolting and small stone chips flying off the shoulder, "
             "2 the heavy body leaning back with the wings snapping partly open and dust falling, "
             "3 the gargoyle rocking with the claws scraping and the wings half spread, "
             "4 the rocking slowing with the body still tilted and the wings lowering, "
             "5 the gargoyle settling back onto its feet with the wings folding, "
             "6 back in the original crouched stone stance with the wings folded tight")),
    dict(enemy="vampire_mage", state="hurt", frames=6,
         action="recoiling from a hit with the hood thrown back",
         steps=(
             "1 the robed mage struck with the body jolting backward and the hood snapping back, "
             "2 the torso arching with the casting arm flung high and the robe flaring, "
             "3 the mage staggering with the sleeves swinging and the body turned, "
             "4 the stagger slowing with the head coming back level and the robe settling, "
             "5 the mage straightening with the arms gathering back in, "
             "6 back in the original standing pose with the hood forward and the arms lowered")),
    dict(enemy="summoner", state="hurt", frames=6,
         action="recoiling from a hit as the summoning circle breaks",
         steps=(
             "1 the summoner struck with the body jolting and the raised arms thrown wide, "
             "2 the robed torso arching back with the sleeves flapping and the head snapping back, "
             "3 the summoner staggering with the arms dropped and the robe swirling, "
             "4 the stagger slowing with the head bowing forward and the body still tilted, "
             "5 the summoner steadying with the hands coming back up, "
             "6 back in the original casting stance with both arms raised")),
    dict(enemy="vampire_prince", state="hurt", frames=6,
         action="staggering back from a heavy hit with the cape swirling",
         steps=(
             "1 the armored prince struck with the body jolting back and the head snapping back, "
             "2 the torso arching with the ornate cape swirling and one gauntlet flung wide, "
             "3 the prince staggering with the shoulders turned and the cape wrapping around, "
             "4 the stagger slowing with the head coming back level and the cape falling, "
             "5 the prince straightening with the arms gathering back in, "
             "6 back in the original regal stance with the cape draped and the chin raised")),
    dict(enemy="elite", state="hurt", frames=6,
         action="rocking back from a heavy hit on the ornate armor",
         steps=(
             "1 the armored elite struck with the body jolting and the head snapping back, "
             "2 the heavy torso arching back with one arm thrown wide and the ornate armor gleaming, "
             "3 the elite staggering with the shoulders twisted and the body off balance, "
             "4 the stagger slowing with the head coming back level and the body still tilted, "
             "5 the elite planting its feet and straightening up, "
             "6 back in the original battle stance with the arms ready")),
]
