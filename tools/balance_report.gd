extends SceneTree
## 平衡验算工具（开发用）
## 用法: godot --headless --path . --script res://tools/balance_report.gd
## 作用: 直接读取敌人脚本里的 base_hp 和 GameConfig 的缩放公式，
##       模拟一条典型玩家成长曲线，打印各波次的 DPS / TTK 表。

const ENEMY_DIR := "res://scripts/enemies/"
const ENEMY_FILES := [
	["蝙蝠", "bat.gd"],
	["骷髅弓手", "skeleton_archer.gd"],
	["吸血鬼", "vampire.gd"],
	["自爆者", "exploder.gd"],
	["狼人", "werewolf.gd"],
	["精英吸血鬼", "elite_vampire.gd"],
	["召唤师", "summoner.gd"],
	["吸血鬼法师", "vampire_mage.gd"],
	["僵尸", "zombie.gd"],
	["石像鬼", "gargoyle.gd"],
	["血族亲王", "vampire_prince.gd"],
]

## 读取某个敌人脚本里的 base_hp
func _read_base_hp(file_name: String) -> float:
	var path := ENEMY_DIR + file_name
	if not FileAccess.file_exists(path):
		return -1.0
	var text := FileAccess.get_file_as_string(path)
	var re := RegEx.new()
	re.compile("base_hp\\s*=\\s*([0-9]+(?:\\.[0-9]+)?)")
	var m := re.search(text)
	if m:
		return float(m.get_string(1))
	return -1.0

## 模拟典型玩家的 DPS 成长曲线
## 假设: 每 4 波多一把武器(上限6把)，每 5 波武器平均 +1 级(上限5级)，
##       每 3 波一次伤害升级(+20%)，第 12 波起第一把武器进化
func _estimate_player_dps(wave: int) -> float:
	var weapon_count: int = mini(1 + wave / 4, 6)
	var avg_level: int = mini(1 + wave / 5, 5)
	var damage_picks: int = mini(wave / 3, 8)
	var dmg_mult: float = 1.0 + damage_picks * GameConfig.UPGRADE_DAMAGE_MULT

	# 以手枪为基准单体 DPS
	var base_damage: float = 4.0
	var base_interval: float = 0.25
	var per_weapon_dps: float = 0.0
	for i in range(weapon_count):
		var dmg: float = base_damage * (1.0 + (avg_level - 1) * GameConfig.WEAPON_DAMAGE_PER_LEVEL)
		var interval: float = maxf(base_interval * (1.0 - (avg_level - 1) * GameConfig.WEAPON_FIRE_RATE_PER_LEVEL), 0.08)
		var dps: float = dmg / interval
		# 进化：第一把武器在第 12 波后进化（取钳制后的保守倍率）
		if i == 0 and wave >= 12:
			dps = dps * (GameConfig.EVOLUTION_DAMAGE_MIN / GameConfig.EVOLUTION_FIRE_RATE_MAX)
		dps *= GameConfig.get_weapon_damage_multiplier(i)
		per_weapon_dps += dps
	return per_weapon_dps * dmg_mult

func _init() -> void:
	print("")
	print("================ 吸血鬼猎人 · 平衡验算 ================")
	print("（DPS 为典型成长曲线估算，TTK = 敌人HP / DPS）")
	print("")
	print("波次 | 玩家DPS | 等级缩放 | 吸血鬼HP | 蝙蝠HP | 僵尸HP | 吸血鬼TTK | 僵尸TTK")
	print("-----|---------|----------|----------|--------|--------|-----------|---------")

	for wave in [1, 3, 5, 10, 15, 20, 25]:
		# 用经验曲线反推该波次的大致等级
		var level: int = 1
		var total_xp: int = 0
		var need: int = GameConfig.get_xp_required(level)
		# 每波约 12 只怪，平均 6 点经验
		total_xp = wave * 12 * 6
		while total_xp >= need and level < 60:
			total_xp -= need
			level += 1
			need = GameConfig.get_xp_required(level)

		var dps: float = _estimate_player_dps(wave)
		var lv_scale: float = GameConfig.get_player_level_hp_scale(level)
		var wave_scale: float = GameConfig.get_enemy_hp_multiplier(wave)

		var hp_vampire: float = _read_base_hp("vampire.gd") * wave_scale * lv_scale
		var hp_bat: float = _read_base_hp("bat.gd") * wave_scale * lv_scale
		var hp_zombie: float = _read_base_hp("zombie.gd") * wave_scale * lv_scale

		print("%4d | %7.1f | %8.2f | %8.0f | %6.0f | %6.0f | %9.2f | %7.2f" % [
			wave, dps, lv_scale, hp_vampire, hp_bat, hp_zombie,
			hp_vampire / maxf(dps, 0.1), hp_zombie / maxf(dps, 0.1),
		])

	print("")
	print("目标区间: 杂兵 TTK 0.3~1.0s / 精英 1~2s")
	print("说明: 单局实际只到第 12 波（3 层 × 4 战斗房），15 波以后仅用于验证曲线外推不崩")
	print("      Boss 战与层倍率请用 tools/dungeon_test.gd（按真实三层流程模拟）")
	print("======================================================")
	quit()
