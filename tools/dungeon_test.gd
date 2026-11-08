extends SceneTree
## 地下城结构验算工具（开发用）
## 用法: godot --headless --path . --script res://tools/dungeon_test.gd
## 作用: 校验层/房间序列生成是否合法，并估算三层 Boss 的实际 TTK

const DUNGEON_SCRIPT := "res://scripts/map/dungeon_manager.gd"
const ENEMY_DIR := "res://scripts/enemies/"

## 读取敌人脚本里的 base_hp
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

## 用累计经验反推该波次的大致等级（每波约 12 只怪，平均 6 点经验）
func _estimate_level(wave: int) -> int:
	var level: int = 1
	var total_xp: int = wave * 12 * 6
	var need: int = GameConfig.get_xp_required(level)
	while total_xp >= need and level < 60:
		total_xp -= need
		level += 1
		need = GameConfig.get_xp_required(level)
	return level

## 与 balance_report.gd 保持一致的玩家 DPS 估算模型
func _estimate_player_dps(wave: int) -> float:
	var weapon_count: int = mini(1 + wave / 4, 6)
	var avg_level: int = mini(1 + wave / 5, 5)
	var damage_picks: int = mini(wave / 3, 8)
	var dmg_mult: float = 1.0 + damage_picks * GameConfig.UPGRADE_DAMAGE_MULT

	var base_damage: float = 4.0
	var base_interval: float = 0.25
	var per_weapon_dps: float = 0.0
	for i in range(weapon_count):
		var dmg: float = base_damage * (1.0 + (avg_level - 1) * GameConfig.WEAPON_DAMAGE_PER_LEVEL)
		var interval: float = maxf(base_interval * (1.0 - (avg_level - 1) * GameConfig.WEAPON_FIRE_RATE_PER_LEVEL), 0.08)
		var dps: float = dmg / interval
		if i == 0 and wave >= 12:
			dps = dps * (GameConfig.EVOLUTION_DAMAGE_MIN / GameConfig.EVOLUTION_FIRE_RATE_MAX)
		dps *= GameConfig.get_weapon_damage_multiplier(i)
		per_weapon_dps += dps
	return per_weapon_dps * dmg_mult

func _init() -> void:
	print("")
	print("============== 吸血鬼猎人 · 地下城结构验算 ==============")
	print("总层数: %d  (每层房间数见下表)  Boss 固定为该层最后一间" % GameConfig.DUNGEON_FLOOR_COUNT)
	print("")

	var dm_script = load(DUNGEON_SCRIPT)
	var errors: int = 0
	var trials: int = 200

	# 每层 Boss 出现时的累计波次（只统计战斗房）
	var boss_wave_sum: Array = []
	for i in range(GameConfig.DUNGEON_FLOOR_COUNT):
		boss_wave_sum.append(0)

	for t in range(trials):
		var dm = dm_script.new()
		dm.start_dungeon()
		var wave_cursor: int = 0
		var floor_guard: int = 0

		while floor_guard < 10:
			floor_guard += 1
			var plan: Array = dm.get_room_plan()
			var expected_rooms: int = dm.get_room_count()
			var expected_specials: int = dm.get_special_count()
			# --- 结构校验 ---
			if plan.size() != expected_rooms:
				print("❌ 房间数量错误: %d (期望 %d)" % [plan.size(), expected_rooms])
				errors += 1
			if plan[plan.size() - 1] != "boss":
				print("❌ 最后一间不是 Boss 房")
				errors += 1
			var special_count: int = 0
			for r in plan:
				if r in ["shop", "treasure", "rest"]:
					special_count += 1
				elif r != "combat" and r != "boss":
					print("❌ 未知房间类型: %s" % r)
					errors += 1
			if special_count != expected_specials:
				print("❌ 特殊房数量异常: %d (期望 %d)" % [special_count, expected_specials])
				errors += 1
			if plan[0] != "combat":
				print("❌ 第一间应为战斗房")
				errors += 1

			# --- 消耗房间，累计波次 ---
			for i in range(plan.size()):
				var rt: String = dm.consume_room()
				if rt == "combat":
					wave_cursor += 1

			boss_wave_sum[dm.current_floor - 1] += wave_cursor

			var has_next: bool = dm.advance_floor()
			if not has_next:
				break
			if dm.room_in_floor != 0:
				print("❌ 进入新层后房间计数未重置")
				errors += 1

		dm.free()

	print("结构校验: 跑了 %d 次完整流程，问题 %d 处" % [trials, errors])
	print("")

	# --- Boss TTK 估算 ---
	print("层 | 楼层名        | Boss                | BossHP | 到达波次 | 玩家DPS | BossTTK | 敌人HP倍率 | 敌人伤害倍率")
	print("---|---------------|---------------------|--------|----------|---------|---------|------------|-------------")
	var probe = dm_script.new()
	for i in range(GameConfig.DUNGEON_FLOOR_COUNT):
		var floor_index: int = i + 1
		var data: Dictionary = probe.floors_data[i]
		var avg_wave: int = int(round(float(boss_wave_sum[i]) / float(trials)))
		var boss_tier: int = i + 1
		var boss_hp: float = GameConfig.get_boss_hp(boss_tier)
		var dps: float = _estimate_player_dps(avg_wave)
		var ttk: float = boss_hp / maxf(dps, 0.1)
		print("%2d | %-13s | %-19s | %6.0f | %8d | %7.1f | %6.1fs | %10.2f | %8.2f" % [
			floor_index,
			String(data.get("name", "")),
			String(data.get("boss_name", "")),
			boss_hp, avg_wave, dps, ttk,
			GameConfig.get_floor_hp_multiplier(floor_index),
			GameConfig.get_floor_damage_multiplier(floor_index),
		])

	print("")
	print("目标: Boss TTK 15~25s。若偏离，调整 GameConfig.BOSS_HP_TIERS")
	print("")

	# --- 各层普通杂兵 TTK ---
	print("杂兵 TTK 校验（含层倍率与等级橡皮筋，目标 0.3~1.0s，坦克型可放宽到 2.5s）")
	print("层 | 波次 | 等级 | 蝙蝠HP | 蝙蝠TTK | 吸血鬼HP | 吸血鬼TTK | 僵尸HP | 僵尸TTK")
	print("---|------|------|--------|---------|----------|-----------|--------|--------")
	for i in range(GameConfig.DUNGEON_FLOOR_COUNT):
		var floor_index: int = i + 1
		var wave: int = int(round(float(boss_wave_sum[i]) / float(trials)))
		var lvl: int = _estimate_level(wave)
		var lv_scale: float = GameConfig.get_player_level_hp_scale(lvl)
		var wave_scale: float = GameConfig.get_enemy_hp_multiplier(wave)
		var floor_scale: float = GameConfig.get_floor_hp_multiplier(floor_index)
		var dps: float = _estimate_player_dps(wave)

		var hp_bat: float = _read_base_hp("bat.gd") * wave_scale * lv_scale * floor_scale
		var hp_vamp: float = _read_base_hp("vampire.gd") * wave_scale * lv_scale * floor_scale
		var hp_zombie: float = _read_base_hp("zombie.gd") * wave_scale * lv_scale * floor_scale

		print("%2d | %4d | %4d | %6.0f | %6.2fs | %8.0f | %7.2fs | %6.0f | %6.2fs" % [
			floor_index, wave, lvl,
			hp_bat, hp_bat / maxf(dps, 0.1),
			hp_vamp, hp_vamp / maxf(dps, 0.1),
			hp_zombie, hp_zombie / maxf(dps, 0.1),
		])

	print("")
	print("========================================================")
	probe.free()
	quit()
