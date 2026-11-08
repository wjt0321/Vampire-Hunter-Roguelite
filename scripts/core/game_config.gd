extends Node
class_name GameConfig
## 游戏配置中心
## 集中管理所有平衡性数值，避免硬编码

# ==================== 玩家基础配置 ====================

const PLAYER_BASE_HP: float = 100.0
const PLAYER_BASE_SPEED: float = 200.0
const PLAYER_BASE_DAMAGE_MULT: float = 1.0
const PLAYER_INVINCIBLE_DURATION: float = 0.5
const PLAYER_PICKUP_RANGE: float = 100.0
const PLAYER_CRIT_DAMAGE: float = 2.0

# ==================== 经验与升级 ====================

# 升级经验公式: XP_BASE + (level-1)*XP_LINEAR + (level-1)^XP_EXPONENT
# 初版 20/12/1.5 时，第 1 波就能升 3-4 级，玩家开局即多武器，前期毫无压力。
# 上调后 1→2 级约需 6 只怪，前 3 波大约升 2-3 级。
const XP_BASE: int = 26
const XP_LINEAR: int = 16
const XP_EXPONENT: float = 1.5

# 玩家升级效果
const UPGRADE_DAMAGE_MULT: float = 0.20      # +20% 伤害
const UPGRADE_SPEED_MULT: float = 0.15       # +15% 移速
const UPGRADE_SHOOT_SPEED_MULT: float = 0.20 # +20% 射速
const UPGRADE_MAX_HP: float = 20.0           # +20 HP
const UPGRADE_ARMOR: float = 5.0             # +5 护甲
const UPGRADE_PICKUP_RANGE: float = 30.0     # +30 拾取范围

# ==================== 护甲与减伤 ====================

# 百分比减伤公式: armor / (armor + ARMOR_CONSTANT)，上限 MAX_DAMAGE_REDUCTION
const ARMOR_CONSTANT: float = 100.0
const MAX_DAMAGE_REDUCTION: float = 0.75     # 75% 减伤上限

# ==================== 武器配置 ====================

# 武器升级系数
const WEAPON_DAMAGE_PER_LEVEL: float = 0.15   # 每级 +15% 伤害
const WEAPON_FIRE_RATE_PER_LEVEL: float = 0.06 # 每级 -6% 间隔
const WEAPON_MAX_LEVEL: int = 5

# 武器槽上限（含初始手枪）。
# 没有上限时玩家能同时持有全部 10 把武器，每把独立开火、DPS 线性叠加，
# 10 级以后必然变成无双割草。上限设定后，多余的选择会转为"升级已有武器"。
const MAX_WEAPON_SLOTS: int = 4

# 武器进化系数 (降低以避免数值崩塌)
const EVOLUTION_DAMAGE_MIN: float = 1.6
const EVOLUTION_DAMAGE_MAX: float = 2.2
const EVOLUTION_FIRE_RATE_MIN: float = 0.5
const EVOLUTION_FIRE_RATE_MAX: float = 0.8
const EVOLUTION_SIZE_MIN: float = 1.2
const EVOLUTION_SIZE_MAX: float = 2.0

# 多武器收益递减: 第N个武器伤害 × MULTI_WEAPON_DECAY^(N-1)
const MULTI_WEAPON_DECAY: float = 0.9

# 武器进化击杀条件
const EVOLUTION_KILL_COUNT: int = 50
const EVOLUTION_KILL_COUNT_ADVANCED: int = 60

# ==================== 敌人配置 ====================

# 敌人 HP 随波次**线性**增长（每波 +12%，不是复利）
#
# 旧版是 1.115 的复合增长，第 12 波已经 ×3.3；再叠楼层台阶就是 ×5。
# 玩家第一次试玩的原话是「怪一开始血量太厚了不线性」——问题不在最终数值，
# 而在曲线形状：复利让前 3 波几乎不动、后面陡增，和玩家能力（每级固定增量）不匹配。
# 现在改成 `1 + (wave-1) × 0.12`，第 12 波 ×2.32，绝对增量逐波恒定，
# 玩家每过一间房感受到的"变厚"是等量的。后期总量靠楼层台阶补回来（见 FLOOR_HP_MULTIPLIERS）。
const ENEMY_HP_LINEAR_PER_WAVE: float = 0.12

# 敌人伤害随波次增长
const ENEMY_DAMAGE_PER_WAVE: float = 0.05 # 每波+5%

# 敌人 HP 随玩家等级软性走高（橡皮筋机制，防止玩家过度成型后无伤）
const ENEMY_HP_PER_PLAYER_LEVEL: float = 0.03   # 玩家 3 级后每级 +3%
const ENEMY_HP_LEVEL_START: int = 3             # 从该等级开始计入
const ENEMY_HP_LEVEL_SCALE_CAP: float = 2.0     # 等级缩放上限

# ==================== 敌人远程火力 ====================
#
# 试玩反馈「小怪投射物太多了，需要到后期慢慢增多才合理」。
# 原来只要敌人在池子里就可能被选中：第 1 层 5 种敌人里有骷髅射手，
# 6 个房间从第一间就可能是弓箭手，配合 2 秒冷却 + 20% 三连发，
# 一间房同时有 4-6 个射手 → 每秒 2-3 发弹幕，开局就被迫站桩躲弹。
#
# 三层控制，从"有没有"到"多不多"逐级放开：
#   1) 逐层解禁：第 1 层前几间房根本不刷远程怪（RANGED_UNLOCK_ROOM_BY_FLOOR）
#   2) 开火节奏：层数越深冷却越短（ENEMY_FIRE_COOLDOWN_MULT_BY_FLOOR）
#   3) 同屏上限：场上敌人投射物超过上限就不再开火（ENEMY_PROJECTILE_CAP_BY_FLOOR）
# 用"同屏上限"而不是"减伤害"：玩家抱怨的是屏幕被弹幕糊住，那是视觉与闪避空间问题，
# 不是数值问题——改伤害只会让弹幕依旧糊屏但没那么痛。

## 远程敌人类型（用于逐层解禁判断）
const RANGED_ENEMY_TYPES: Array = ["skeleton_archer", "vampire_mage"]

## 该层的第几间房开始允许刷远程怪（下标 = floor - 1；按本层已清房间数算）
## 第 1 层前 3 间房纯近战，第 4 间房开始出现射手，最后 2 间与 Boss 房才真正有压力
const RANGED_UNLOCK_ROOM_BY_FLOOR: Array = [4, 2, 1]

## 敌人开火冷却倍率（下标 = floor - 1）。第 1 层射手 2.0s → 3.4s，几乎是原来的两倍
const ENEMY_FIRE_COOLDOWN_MULT_BY_FLOOR: Array = [1.7, 1.25, 1.0]

## 同屏敌人投射物数量上限（下标 = floor - 1）
const ENEMY_PROJECTILE_CAP_BY_FLOOR: Array = [3, 7, 12]

## 三连发概率（下标 = floor - 1）。第 1 层永远单发
const RANGED_TRIPLE_SHOT_CHANCE_BY_FLOOR: Array = [0.0, 0.18, 0.30]

static func get_ranged_unlock_room(floor_index: int) -> int:
	var idx: int = clampi(floor_index - 1, 0, RANGED_UNLOCK_ROOM_BY_FLOOR.size() - 1)
	return int(RANGED_UNLOCK_ROOM_BY_FLOOR[idx])

static func is_ranged_allowed(floor_index: int, rooms_cleared: int) -> bool:
	## rooms_cleared 传"本层已清房间数"，从 0 开始
	return rooms_cleared >= get_ranged_unlock_room(floor_index)

static func get_enemy_fire_cooldown_mult(floor_index: int) -> float:
	var idx: int = clampi(floor_index - 1, 0, ENEMY_FIRE_COOLDOWN_MULT_BY_FLOOR.size() - 1)
	return float(ENEMY_FIRE_COOLDOWN_MULT_BY_FLOOR[idx])

static func get_enemy_projectile_cap(floor_index: int) -> int:
	var idx: int = clampi(floor_index - 1, 0, ENEMY_PROJECTILE_CAP_BY_FLOOR.size() - 1)
	return int(ENEMY_PROJECTILE_CAP_BY_FLOOR[idx])

static func get_ranged_triple_chance(floor_index: int) -> float:
	var idx: int = clampi(floor_index - 1, 0, RANGED_TRIPLE_SHOT_CHANCE_BY_FLOOR.size() - 1)
	return float(RANGED_TRIPLE_SHOT_CHANCE_BY_FLOOR[idx])

# ==================== 波次配置 ====================

const WAVE_DURATION: float = 30.0
# 生成节奏：初版是「每 2 秒生成 1 只」，而玩家一秒能杀 2-3 只，
# 结果场上永远是空的，只能体验到"割草"而看不到"草"。
# 现在开局就是 1.1 秒一批、每批 2 只（约 1.8 只/秒），同屏能堆到 8-12 只。
const WAVE_BASE_SPAWN_INTERVAL: float = 1.3
const WAVE_MIN_SPAWN_INTERVAL: float = 0.4
const WAVE_SPAWN_INTERVAL_DECREASE: float = 0.04
const WAVE_MAX_SPAWN_COUNT: int = 5
# 注：Boss 不再按固定波次触发，改由地下城结构决定（每层最后一间房）

## 同屏存活上限（按层）。
##
## 为什么必须要有：试玩反馈「从 wave5 开始怪扎堆，甚至没有地方跑了」。
## 之前完全没有任何上限——每 1.1~1.3 秒刷一批、每批 3~4 只，一波 30 秒就是
## 70~90 只；玩家 DPS 又清不完，于是场上越堆越多，1280×720 的房间里
## 最后连一条缝都没有。这是"数量曲线"和"击杀速度"脱钩导致的。
##
## 有上限之后，压力由"同时在场的敌人"决定而不是"累计刷了多少"：
## 杀得快→补得快（压力持续），杀得慢→不再加码（不会雪崩到动不了）。
## 数值参考：屏幕 1280×720、玩家速度 200，同屏 16 只时还能绕着走；
## 22 只开始吃走位；28 只是"满屏但仍有缝"的上限。
const ENEMY_ALIVE_CAP_BY_FLOOR: Array = [16, 22, 28]
## 距离上限还剩几只时开始放慢补怪节奏（避免"刚杀一只立刻顶上"的窒息感）
const ENEMY_ALIVE_CAP_SOFT_RANGE: int = 4

## 满级后「伤害提升」补给卡的攻击倍率增幅。
## ⚠ 预览文案和真正生效必须用同一个常量：之前预览读 UPGRADE_DAMAGE_MULT（0.20）、
## 实际只加 0.10，卡片承诺的和玩家拿到的对不上，属于最伤信任的一类 bug。
const BASIC_REWARD_DAMAGE: float = 0.10

static func get_enemy_alive_cap(floor_index: int) -> int:
	var idx: int = clampi(floor_index - 1, 0, ENEMY_ALIVE_CAP_BY_FLOOR.size() - 1)
	return int(ENEMY_ALIVE_CAP_BY_FLOOR[idx])

# ==================== 地下城结构 ====================

const DUNGEON_FLOOR_COUNT: int = 3        # 总层数
const DUNGEON_ROOMS_PER_FLOOR: int = 6    # 每层默认房间数（含 Boss 房），具体层可在配置里覆盖
const DUNGEON_MAX_ROOMS_PER_FLOOR: int = 8

# 每层额外的敌人强度倍率（叠加在波次缩放之上，制造"下潜"的压迫感）
# 下标 = floor - 1
# 波次曲线从复利改成线性后，第 12 波只有 ×2.32（旧版 ×3.3），
# 差额必须由楼层台阶补回来，否则三层 Boss 前的杂兵会软得没有威胁。
# 1.0 / 1.40 / 1.85 与线性曲线相乘后，第 3 层第 12 波的等效倍率 ≈ ×4.3（旧版 ×4.98）。
const FLOOR_HP_MULTIPLIERS: Array = [1.0, 1.40, 1.85]
const FLOOR_DAMAGE_MULTIPLIERS: Array = [1.0, 1.18, 1.40]

# 层通关奖励：恢复生命百分比 + 血晶
const FLOOR_CLEAR_HEAL_RATIO: float = 0.5
const FLOOR_CLEAR_CRYSTALS: Array = [30, 60, 120]

# ==================== Boss 配置 ====================

const BOSS_BASE_HP: float = 800.0
# 各 tier 的 Boss 基础血量：与"层内 Boss 出现时的玩家 DPS"实测对齐
# 设计目标 Boss 战 15-25 秒（tools/dungeon_test.gd 可验算）
const BOSS_HP_TIERS: Array = [650.0, 1600.0, 3200.0, 4600.0, 7000.0]
const BOSS_ENRAGE_THRESHOLD: float = 0.5    # 50% HP 狂暴
const BOSS_DESPERATE_THRESHOLD: float = 0.25 # 25% HP 绝望

# ==================== 被动道具配置 ====================

# 收益递减系数
const PASSIVE_DECAY_DEFAULT: float = 0.8
const PASSIVE_DECAY_LINEAR: float = 1.0   # 线性（无递减）

# 被动上限
const PASSIVE_MAX_DODGE: float = 0.25      # 闪避上限25%
const PASSIVE_MAX_CRIT: float = 0.40       # 暴击上限40%
const PASSIVE_MAX_LIFESTEAL: float = 0.28  # 吸血上限28%
const PASSIVE_MAX_FREEZE: float = 0.25     # 冻结上限25%

# ==================== 血晶经济 ====================

const CRYSTAL_PER_KILL: int = 8            # 每8杀1血晶
const CRYSTAL_PER_ROOM: int = 2            # 每房间2血晶
const CRYSTAL_PER_WAVE: int = 3            # 每波次3血晶
const CRYSTAL_PER_LEVEL: int = 3           # 每等级3血晶
const CRYSTAL_PER_BOSS: int = 50           # 每Boss50血晶

# ==================== 永久升级 ====================

const PERMANENT_UPGRADE_MAX_LEVEL: int = 5
const PERMANENT_DAMAGE_PER_LEVEL: float = 0.05   # +5%/级
const PERMANENT_HP_PER_LEVEL: float = 10.0       # +10/级
const PERMANENT_SPEED_PER_LEVEL: float = 0.05    # +5%/级
const PERMANENT_ARMOR_PER_LEVEL: float = 10.0    # +10 护甲/级（百分比体系下更有意义）
const PERMANENT_XP_PER_LEVEL: float = 0.10       # +10%/级
const PERMANENT_CRYSTAL_PER_LEVEL: float = 0.10  # +10%/级

# 升级价格表
const UPGRADE_COSTS: Dictionary = {
	"base_damage": [50, 100, 200, 400, 800],
	"base_hp": [30, 60, 120, 240, 500],
	"base_speed": [40, 80, 160, 320, 640],
	"base_armor": [40, 80, 160, 320, 640],
	"xp_bonus": [60, 120, 240, 480, 960],
	"blood_crystal_bonus": [80, 160, 320, 640, 1280],
}

# 角色解锁价格
const CHARACTER_UNLOCK_COSTS: Dictionary = {
	"priestess": 500,
	"assassin": 1500,
	"mage": 1500,
	"knight": 2000,
}

# ==================== 工具函数 ====================

## 计算敌人 HP 缩放系数（复合增长，与玩家 DPS 成长曲线对齐）
static func get_enemy_hp_multiplier(wave: int) -> float:
	## 线性而非复利：绝对增量恒定，玩家每过一间房感受到的"变厚"是等量的
	return 1.0 + float(maxi(wave - 1, 0)) * ENEMY_HP_LINEAR_PER_WAVE

## 计算玩家等级带来的敌人 HP 软缩放（橡皮筋）
static func get_player_level_hp_scale(player_level: int) -> float:
	var extra := maxi(player_level - ENEMY_HP_LEVEL_START, 0)
	return minf(1.0 + extra * ENEMY_HP_PER_PLAYER_LEVEL, ENEMY_HP_LEVEL_SCALE_CAP)

## 计算敌人伤害缩放系数
static func get_enemy_damage_multiplier(wave: int) -> float:
	return 1.0 + (wave - 1) * ENEMY_DAMAGE_PER_WAVE

## 计算升级所需经验
static func get_xp_required(level: int) -> int:
	return XP_BASE + (level - 1) * XP_LINEAR + int(pow(level - 1, XP_EXPONENT))

## 计算护甲减伤比例
static func calculate_damage_reduction(armor: float) -> float:
	return minf(armor / (armor + ARMOR_CONSTANT), MAX_DAMAGE_REDUCTION)

## 计算多武器伤害递减
static func get_weapon_damage_multiplier(weapon_index: int) -> float:
	return pow(MULTI_WEAPON_DECAY, weapon_index)

## 计算被动递减后的数值
static func get_passive_scaled_value(base_value: float, value_per_level: float, current_level: int, decay: float = PASSIVE_DECAY_DEFAULT) -> float:
	var total = base_value
	for i in range(1, current_level):
		total += value_per_level * pow(decay, i - 1)
	return total

## 计算 Boss HP
static func get_boss_hp(boss_tier: int) -> float:
	var idx: int = clampi(boss_tier - 1, 0, BOSS_HP_TIERS.size() - 1)
	return float(BOSS_HP_TIERS[idx])

## 计算某层的敌人 HP 额外倍率
static func get_floor_hp_multiplier(floor_index: int) -> float:
	var idx: int = clampi(floor_index - 1, 0, FLOOR_HP_MULTIPLIERS.size() - 1)
	return float(FLOOR_HP_MULTIPLIERS[idx])

## 计算某层的敌人伤害额外倍率
static func get_floor_damage_multiplier(floor_index: int) -> float:
	var idx: int = clampi(floor_index - 1, 0, FLOOR_DAMAGE_MULTIPLIERS.size() - 1)
	return float(FLOOR_DAMAGE_MULTIPLIERS[idx])

## 计算某层通关奖励血晶
static func get_floor_clear_crystals(floor_index: int) -> int:
	var idx: int = clampi(floor_index - 1, 0, FLOOR_CLEAR_CRYSTALS.size() - 1)
	return int(FLOOR_CLEAR_CRYSTALS[idx])

# ==================== 升级三选一：重抽 / 跳过 ====================

## 每局免费重抽次数。用完后再重抽要花银币。
const REROLL_FREE_COUNT: int = 3
## 免费用完后的单次重抽价格（银币）
const REROLL_SILVER_COST: int = 10
## 跳过一次升级奖励的银币补偿
const SKIP_SILVER_REWARD: int = 15

# ==================== 放逐 Banish ====================
#
# 设计取舍：这是唯一一个"对池子做永久操作、且收益会复利"的动作。
# 重抽只解决"这一手烂"，放逐解决"这个池子里永远别再来垃圾"。
# 每局给 3 次，够玩家剔除最讨厌的 2-3 张卡，又不至于把池子洗成三张神卡。
# 放逐不消耗重抽次数——否则两个功能互相抢资源，玩家会陷入"该不该 ban"的算账，
# 而 ban 的乐趣正在于无脑执行。

## 每局放逐次数
const BANISH_COUNT: int = 3

# ==================== 深渊契约（休息房） ====================
#
# 设计取舍：惩罚只挂"本层"，不挂整局。
# 整局 -20% 上限能被 3 间休息房叠到 -48%，纯数值惩罚会把局玩死；
# 本层扣、层末还，玩家每层重做一次决策，赌"这层能不能用 +30% 掉落赚回来"。

## 缔约时扣掉的最大生命比例（本层有效，层末归还）
const BLOOD_PACT_HP_RATIO: float = 0.20
## 缔约后本层敌人数量倍率
const BLOOD_PACT_COUNT_MULT: float = 1.20
## 缔约后本层银币与经验倍率
const BLOOD_PACT_LOOT_MULT: float = 1.30
## 选择"安息"时的治疗比例
const BLOOD_PACT_REST_HEAL_RATIO: float = 0.50
## 缔约后当前生命至少保留到新上限的这个比例，否则禁止缔约（防自杀）
const BLOOD_PACT_MIN_HP_RATIO: float = 0.30


# ==================== 打击感（Vlambeer 清单） ====================

## 枪口闪光持续时间
const MUZZLE_FLASH_DURATION: float = 0.06
## 命中冻帧：只冻受击的敌人，绝不用 Engine.time_scale（会冻住整个游戏）
const HIT_FREEZE_DURATION: float = 0.05

# ==================== 状态修饰器（17.13） ====================
# 三个修饰器都挂在"任意武器"上：玩家的六处伤害来源都会经过
# EnemyBase._after_damage_taken，不需要每把武器单独接线。

## 流血：每秒伤害 = 触发那次命中伤害 × 该比例（不叠层，取更强的那次）
## 0.30 × 2.5 秒 = 一次命中的 0.75 倍总伤，够形成"要不要补流血"的取舍，
## 又不至于让流血盖过武器本身（叠层会，所以刻意没做叠层）。
const BLEED_DPS_RATIO: float = 0.30
const BLEED_DURATION: float = 2.5
## 流血结算间隔。0.5 秒既省性能，也让"每跳掉一截"看得清
const BLEED_TICK: float = 0.5

## 霜缚：移速乘数 / 持续时间
## 0.70 而不是 0.5：减速的目的是"让它晚半个身位到位"，不是控到死
const SLOW_MULT: float = 0.70
const SLOW_DURATION: float = 2.0
## Boss 对减速的抗性（0 = 和普通怪一样，1 = 完全免疫）
const SLOW_BOSS_RESIST: float = 0.6

## 同一敌人两次状态判定之间的最小间隔。
## 高攻速武器每发都命中，不设冷却的话流血/减速会永久满覆盖。
const STATUS_VFX_COOLDOWN: float = 0.30

## 汲取：每攒够这么多血才真回一次。
## 直接按每点伤害调 heal() 会每帧播一次治疗音效，听起来像漏水。
const DRAIN_HEAL_THRESHOLD: float = 2.0

## 三个新被动的硬上限（get_scaled_value 已按等级递减，这里再兜一层）
const PASSIVE_MAX_BLEED_CHANCE: float = 0.60
const PASSIVE_MAX_SLOW_CHANCE: float = 0.55
const PASSIVE_MAX_DRAIN: float = 0.06
## 玩家开火反馈：**纯视觉**挤压，绝不产生位移。
## 早期版本给的是向后的速度（60px/s，0.1s 衰减），实际观感是"人物每枪往回缩一下"，
## 用户明确反馈这是缺点。现在改成精灵沿竖直方向挤压 6% 再弹回，位置一律不动。
const PLAYER_FIRE_PUNCH_SCALE: float = 0.94
const PLAYER_FIRE_PUNCH_TIME: float = 0.08

# ==================== 护盾（能量护盾被动） ====================

## 护盾光环颜色（青蓝，和"受击红"区分开）
const SHIELD_AURA_COLOR: Color = Color(0.48, 0.84, 1.0, 1.0)
## 光环直径（像素）。略大于玩家精灵（56px），保证四周露出一圈
const SHIELD_AURA_RADIUS: float = 46.0
## 拿到护盾道具时立刻给一层，而不是让玩家干等 30 秒冷却
const SHIELD_FIRST_GRANT_IMMEDIATE: bool = true

# ==================== 地面预警标记 ====================

## 默认预警时长（秒）。Boss 冲刺/新星都在这段时间里把圆环画满。
const GROUND_MARKER_DURATION: float = 0.6

# ==================== 精英词缀 ====================
#
# 设计取舍：不做"第 12 种敌人"，而是让现有敌人随机长出词缀。
# 玩家面对的变化是"威胁类型"（该先拆盾 / 该侧移躲冲锋 / 该先杀掉加速者），
# 而不是又一次换皮。词缀定义见 scripts/enemies/elite_affix.gd。

const ELITE_AFFIX_ENABLED: bool = true
## 每层精英词缀的出现概率（逐层递增）
const ELITE_AFFIX_CHANCE_BY_FLOOR: Array = [0.05, 0.13, 0.18]
## 每层允许出现的词缀池。
##
## 试玩反馈第一句就是「怎么第一关小怪就有护盾啊」——第 1 层原本 10% 概率随机四选一，
## 一间房 30 只怪里就有 3 只带盾（血盾 = 血量 ×1.55 × 护盾 1.45 ≈ 2.25 倍），
## 开局第一间房就撞上肉墙。现在第 1 层**只放「急速」**：它不加血量，
## 只是把周围小怪催快，是"词缀"这个概念的教学关卡；血盾/裂变这类会改变血量预期的
## 词缀从第 2 层才开始出现。
const ELITE_AFFIX_POOL_BY_FLOOR: Array = [
	["haster"],
	["haster", "charger", "splitter", "shielded"],
	["haster", "charger", "splitter", "shielded"],
]
## 词缀统一加成
## 血盾是"×1.55 血 ×1.45 盾"叠乘，原本 2.25 倍；调到 1.35 后是 1.96 倍，
## 依然是"需要优先拆掉的硬目标"，但不会拖成 4 秒。
const ELITE_AFFIX_HP_MULT: float = 1.35
const ELITE_AFFIX_DAMAGE_MULT: float = 1.20
const ELITE_AFFIX_SILVER_MULT: float = 4.0
const ELITE_AFFIX_XP_MULT: float = 2.0
const ELITE_AFFIX_SCALE_MULT: float = 1.22

## 血盾：护盾量 = 加成后 max_hp × 该比例（护盾直接计入 max_hp，见 enemy_base）
const AFFIX_SHIELD_RATIO: float = 0.45

## 裂变：分裂体数量 / 继承血量比例 / 继承体型比例
const AFFIX_SPLIT_COUNT: int = 2
const AFFIX_SPLIT_HP_RATIO: float = 0.35
const AFFIX_SPLIT_SCALE: float = 0.62

## 冲锋：触发距离、前摇、突进时长、收招硬直、速度倍率、冷却、首次延迟
const AFFIX_CHARGE_RANGE: float = 300.0
const AFFIX_CHARGE_WINDUP: float = 0.6
const AFFIX_CHARGE_DURATION: float = 0.32
const AFFIX_CHARGE_RECOVER: float = 0.55
const AFFIX_CHARGE_SPEED_MULT: float = 3.2
const AFFIX_CHARGE_COOLDOWN: float = 3.2
const AFFIX_CHARGE_FIRST_DELAY: float = 1.6

## 急速光环：半径、加速倍率、刷新间隔、单次持续时间
const AFFIX_HASTE_RADIUS: float = 150.0
## 1.30 时蝙蝠 140 → 182，几乎贴上玩家 200 的跑速，被迫一直后撤、腾不出手捡宝石
## （试玩反馈「怪初始移动速度有些过快，来不及捡经验」）。1.18 后是 165，
## 追得上但追不死，玩家还有"回头捡一下"的余量。
const AFFIX_HASTE_MULT: float = 1.18
const AFFIX_HASTE_TICK: float = 0.4
const AFFIX_HASTE_DURATION: float = 0.75

static func get_elite_affix_chance(floor_index: int) -> float:
	var idx: int = clampi(floor_index - 1, 0, ELITE_AFFIX_CHANCE_BY_FLOOR.size() - 1)
	return float(ELITE_AFFIX_CHANCE_BY_FLOOR[idx])

static func get_elite_affix_pool(floor_index: int) -> Array:
	## 该层允许的词缀池（第 1 层只有急速，见 ELITE_AFFIX_POOL_BY_FLOOR）
	var idx: int = clampi(floor_index - 1, 0, ELITE_AFFIX_POOL_BY_FLOOR.size() - 1)
	return (ELITE_AFFIX_POOL_BY_FLOOR[idx] as Array).duplicate()

# ==================== 武器强度软挂钩（DPS 自适应难度） ====================
#
# 解决什么：原来的橡皮筋只看玩家等级（每级 +3% 血，上限 2 倍）。
# 但等级不等于强度——同样 15 级，"进化武器 + 满级被动"和"五张属性卡"的
# 实际 DPS 能差 3 倍。于是运气好的一局后期变成无双，运气差的一局变成硬墙。
#
# 做法：把"玩家实际能打出的 DPS"和"该等级应有 DPS"相比，比值开方后当倍率。
# 关键取舍：**只做软修正，不做硬对齐**。倍率夹在 0.85~1.55，指数 0.35。
# 玩家 DPS 超模 2 倍，敌人只硬 27%，仍然是"变强了"，而不是"永远打一样久"。
# 硬对齐会抹掉构筑成长的快感，那是 Roguelite 最不能碰的东西。

const DPS_SOFT_ENABLED: bool = true
## 1 级时的参考 DPS（手枪 4 伤害 / 0.25 秒间隔 = 16，与实际数值对齐）
const DPS_SOFT_EXPECTED_BASE: float = 16.0
## 每级参考 DPS 的成长率（与经验曲线、武器升级节奏实测对齐）
const DPS_SOFT_LEVEL_GROWTH: float = 1.20
## 比值指数：0.35 → 实际/期望 = 2.0 时倍率 1.27
const DPS_SOFT_EXPONENT: float = 0.35
## 倍率下限（构筑太差也别让玩家打不动）
const DPS_SOFT_MIN: float = 0.85
## 倍率上限（构筑超模也别变成血牛地狱）
const DPS_SOFT_MAX: float = 1.55
## 每波向目标值靠拢的比例，避免数值突变
const DPS_SOFT_LERP: float = 0.5

static func get_expected_dps(player_level: int) -> float:
	return DPS_SOFT_EXPECTED_BASE * pow(DPS_SOFT_LEVEL_GROWTH, maxi(player_level - 1, 0))

static func get_dps_soft_scale(actual_dps: float, player_level: int) -> float:
	## 返回敌人血量的软修正倍率。actual_dps <= 0 视为数据缺失，不做修正。
	if not DPS_SOFT_ENABLED or actual_dps <= 0.0:
		return 1.0
	var expected: float = get_expected_dps(player_level)
	var ratio: float = clampf(actual_dps / maxf(expected, 1.0), 0.2, 6.0)
	var soft: float = pow(ratio, DPS_SOFT_EXPONENT)
	return clampf(soft, DPS_SOFT_MIN, DPS_SOFT_MAX)

# ==================== 战斗内临时增益 ====================
#
# 设计取舍：不做"击杀掉落"，改成"房间内定时刷新"。
# 击杀掉落会奖励已经很强的玩家（杀得快→掉得多→更强），是正反馈雪球；
# 定时刷新是中立供给，谁都能拿到，弱构筑反而更需要它。
# 16 秒存活上限 + 需要走位去捡 = 一个"值不值得过去"的小决策。

const POWERUP_ENABLED: bool = true
## 战斗房里每隔多久刷一个（秒）
const POWERUP_INTERVAL: float = 24.0
## 进房后第一个的延迟，避开开局那波
const POWERUP_FIRST_DELAY: float = 14.0
## 掉落物存活上限（超时消失，不自动拾取）
const POWERUP_LIFETIME: float = 16.0
## 血露回复比例
const POWERUP_HEAL_RATIO: float = 0.25
## 狂暴倍率与时长
const POWERUP_FRENZY_MULT: float = 1.5
const POWERUP_FRENZY_DURATION: float = 8.0

# ==================== 局内目标事件（17.14） ====================
# 设计取舍：战斗房里只有"杀与被杀"，30 秒里没有第二个目标。
# 事件是"房间的钩子"而不是新房间类型——保持 6~7 间房的节奏不变，
# 只让其中一间（每层最多一间）多一个"这间我要干点什么"的小目标。
# 两种事件二选一，不叠加：猎杀偏输出检验，守卫偏清场检验。

const ROOM_EVENT_ENABLED: bool = true
## 本层第几间战斗房起开始判定（第 1 间当教学，别刚进门就加事）
const ROOM_EVENT_MIN_COMBAT_ROOM: int = 2
## 触发概率按层（每层最多触发一次）
const ROOM_EVENT_CHANCE_BY_FLOOR: Array = [0.35, 0.40, 0.45]
## 猎杀权重 vs 守卫权重（守卫事件更重流程，所以低一些）
const ROOM_EVENT_HUNT_WEIGHT: float = 0.65

## 猎杀：双词缀精英的额外血量倍率（叠在词缀 1.35 之上）
const ROOM_EVENT_HUNT_HP_MULT: float = 2.0
## 猎杀限时（秒）。放太长等于白给，太短则是纯挫败——
# 20 秒 ≈ 波次时长的 2/3，期间要边躲小怪边集火
const ROOM_EVENT_HUNT_TIME: float = 20.0
const ROOM_EVENT_HUNT_SILVER: int = 30
const ROOM_EVENT_HUNT_XP: int = 80

## 守卫：数量 / 血量倍率 / 奖励。守卫围成一圈守住房间中央的上锁宝箱
const ROOM_EVENT_GUARD_COUNT: int = 5
const ROOM_EVENT_GUARD_HP_MULT: float = 1.3
const ROOM_EVENT_GUARD_SILVER: int = 25
const ROOM_EVENT_GUARD_XP: int = 60
## 守卫的视觉标记色（和普通敌人区分开）
const ROOM_EVENT_GUARD_COLOR: Color = Color(1.0, 0.78, 0.25)
## 类型权重表：回血最常见（最容易形成决策），狂暴次之
const POWERUP_KINDS: Array = ["heal", "heal", "frenzy", "magnet"]



# ==================== 深渊阶梯（17.14） ====================
# 通关后可选"继续深入"：+1 深渊等级重开三层，敌人更强、掉落更多。
# GameConfig 不是 autoload（纯静态类），运行时状态必须用 static var：
# 静态变量挂在脚本资源本身上，reload_current_scene() 重建 main 后依然在。
# 离开深渊（普通重开 / 回主菜单 / 游戏失败）时归零。

## 本局当前深渊等级（0 = 首轮正常难度）
static var abyss_level: int = 0
## 历史最深到达的深渊等级（真值在 SaveManager 存档里，这里只是运行时镜像）。
## 只在"继续深入"真正进入该级时记录，不是"通关过多少层"。
static var best_abyss: int = 0

const ABYSS_STEP_HP: float = 0.15
const ABYSS_STEP_DAMAGE: float = 0.10
const ABYSS_STEP_LOOT: float = 0.10

## 放弃深渊：回主菜单 / 普通重开 / 失败结算都走这一个入口。
## 只归零当前等级，不动 best_abyss（历史最深到达是存档成就，不该被清掉）。
static func abandon_abyss() -> void:
	abyss_level = 0

## 每级敌人血量 +15%
static func get_abyss_hp_mult() -> float:
	return 1.0 + ABYSS_STEP_HP * float(abyss_level)

## 每级敌人伤害 +10%
static func get_abyss_damage_mult() -> float:
	return 1.0 + ABYSS_STEP_DAMAGE * float(abyss_level)

## 每级掉落（银币/经验/血晶）+10%
static func get_abyss_loot_mult() -> float:
	return 1.0 + ABYSS_STEP_LOOT * float(abyss_level)
