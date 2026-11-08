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

# 敌人 HP 随波次复合增长（与玩家 DPS 曲线对齐，保证 TTK 稳定）
const ENEMY_HP_GROWTH_PER_WAVE: float = 1.115

# 敌人伤害随波次增长
const ENEMY_DAMAGE_PER_WAVE: float = 0.05 # 每波+5%

# 敌人 HP 随玩家等级软性走高（橡皮筋机制，防止玩家过度成型后无伤）
const ENEMY_HP_PER_PLAYER_LEVEL: float = 0.03   # 玩家 3 级后每级 +3%
const ENEMY_HP_LEVEL_START: int = 3             # 从该等级开始计入
const ENEMY_HP_LEVEL_SCALE_CAP: float = 2.0     # 等级缩放上限

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

# ==================== 地下城结构 ====================

const DUNGEON_FLOOR_COUNT: int = 3        # 总层数
const DUNGEON_ROOMS_PER_FLOOR: int = 6    # 每层默认房间数（含 Boss 房），具体层可在配置里覆盖
const DUNGEON_MAX_ROOMS_PER_FLOOR: int = 8

# 每层额外的敌人强度倍率（叠加在波次缩放之上，制造"下潜"的压迫感）
# 下标 = floor - 1
const FLOOR_HP_MULTIPLIERS: Array = [1.0, 1.22, 1.50]
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
	return pow(ENEMY_HP_GROWTH_PER_WAVE, maxi(wave - 1, 0))

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

# ==================== 打击感（Vlambeer 清单） ====================

## 枪口闪光持续时间
const MUZZLE_FLASH_DURATION: float = 0.06
## 命中冻帧：只冻受击的敌人，绝不用 Engine.time_scale（会冻住整个游戏）
const HIT_FREEZE_DURATION: float = 0.05
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
const ELITE_AFFIX_CHANCE_BY_FLOOR: Array = [0.10, 0.15, 0.20]
## 词缀统一加成
const ELITE_AFFIX_HP_MULT: float = 1.55
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
const AFFIX_HASTE_MULT: float = 1.30
const AFFIX_HASTE_TICK: float = 0.4
const AFFIX_HASTE_DURATION: float = 0.75

static func get_elite_affix_chance(floor_index: int) -> float:
	var idx: int = clampi(floor_index - 1, 0, ELITE_AFFIX_CHANCE_BY_FLOOR.size() - 1)
	return float(ELITE_AFFIX_CHANCE_BY_FLOOR[idx])
