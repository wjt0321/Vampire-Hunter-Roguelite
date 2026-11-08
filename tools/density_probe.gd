extends SceneTree
## 同屏敌人密度探针
## 加载真实主场景，每 0.25 秒采样一次场上敌人数量，输出每波的峰值/均值。
## 玩家被设为持续满血，避免中途死亡打断采样。
## 用法: godot --headless --path . --script res://tools/density_probe.gd

const RUN_SECONDS := 70.0
const SAMPLE_INTERVAL := 0.25
const FIXED_STEP := 1.0 / 60.0

func _initialize() -> void:
	await process_frame

	var packed: PackedScene = load("res://scenes/main.tscn")
	var main_scene := packed.instantiate()
	get_root().add_child(main_scene)
	current_scene = main_scene
	await process_frame

	var player = main_scene.get_node_or_null("Player")
	var wave_mgr = main_scene.get_node_or_null("WaveManager")
	if player == null or wave_mgr == null:
		print("❌ 找不到 Player 或 WaveManager")
		quit(1)
		return

	print("")
	print("============ 同屏敌人密度探针 ============")
	print("时长 %.0fs  采样间隔 %.2fs" % [RUN_SECONDS, SAMPLE_INTERVAL])
	print("波次 | 样本数 | 平均同屏 | 峰值同屏 | 生成数")
	print("-----|--------|----------|----------|--------")

	var elapsed := 0.0
	var sample_timer := 0.0
	var real_start_ms := Time.get_ticks_msec()
	var samples: Array[int] = []
	var cur_wave := 0
	var wave_samples: Array[int] = []
	var wave_max := 0
	var peaks: Array[int] = []
	var wave_rows: Array = []

	while (Time.get_ticks_msec() - real_start_ms) < int(RUN_SECONDS * 1000.0):
		await physics_frame
		# 用真实时钟判断总时长，避免 headless 下 delta 不稳定导致跑不完/跑过头
		var delta := FIXED_STEP
		elapsed = (Time.get_ticks_msec() - real_start_ms) / 1000.0
		sample_timer += delta

		# 保命：让采样不被玩家死亡打断
		if is_instance_valid(player):
			player.current_hp = player.max_hp

		var w: int = wave_mgr.current_wave
		if w != cur_wave:
			if cur_wave > 0 and not wave_samples.is_empty():
				var sum := 0
				for s in wave_samples:
					sum += s
				wave_rows.append([cur_wave, wave_samples.size(), float(sum) / wave_samples.size(), wave_max])
				peaks.append(wave_max)
			cur_wave = w
			wave_samples = []
			wave_max = 0

		if sample_timer >= SAMPLE_INTERVAL:
			sample_timer = 0.0
			var n: int = get_nodes_in_group("enemies").size()
			wave_samples.append(n)
			if n > wave_max:
				wave_max = n
			samples.append(n)

	if cur_wave > 0 and not wave_samples.is_empty():
		var sum2 := 0
		for s in wave_samples:
			sum2 += s
		wave_rows.append([cur_wave, wave_samples.size(), float(sum2) / wave_samples.size(), wave_max])

	for row in wave_rows:
		print("%4d | %6d | %8.1f | %8d |      -" % [row[0], row[1], row[2], row[3]])

	print("------------------------------------------")
	if not samples.is_empty():
		var total := 0
		var peak := 0
		for s in samples:
			total += s
			if s > peak:
				peak = s
		print("全局: 平均 %.1f 只 / 峰值 %d 只 / 样本 %d" % [float(total) / samples.size(), peak, samples.size()])
	print("参考目标: 第1波峰值 8~15, 第3波以后峰值 20 以上")
	print("==========================================")
	print("")

	quit()
