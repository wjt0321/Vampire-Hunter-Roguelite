extends SceneTree
## DPS 软挂钩诊断：确认"玩家 DPS → 波次软因子 → 敌人血量"这条链有没有真的通
## 用法: godot --headless --path . --script res://tools/dps_hook_diag.gd
##
## 为什么写这个：roguelite_ops_test 只断言了 GameConfig.get_dps_soft_scale() 这个纯函数，
## 但"谁来喂 actual_dps"这一环从来没被断言过 —— 纯函数绿，接线断，功能照样是死的。

func _initialize() -> void:
	_run()

func _run() -> void:
	await process_frame
	print("\n====== DPS 软挂钩诊断 ======")

	var main_scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	current_scene = main_scene
	await create_timer(3.4).timeout

	var wm = main_scene.get_node_or_null("WaveManager")
	if wm == null:
		print("  ❌ 找不到 WaveManager 节点")
		quit(1)
		return
	var cfg = root.get_node_or_null("/root/GameConfig")
	if cfg == null:
		cfg = load("res://scripts/core/game_config.gd")

	print("  DPS_SOFT_ENABLED = %s" % str(cfg.DPS_SOFT_ENABLED))
	print("  dps_provider.is_null() = %s" % str(wm.dps_provider.is_null()))
	print("  _soft_hp_scale = %.3f" % float(wm.get("_soft_hp_scale")))

	var lv: int = int(main_scene.player.current_level)
	var est: float = main_scene._estimate_player_dps()
	print("  _estimate_player_dps() = %.2f" % est)
	print("  get_expected_dps(Lv.%d) = %.2f" % [lv, cfg.get_expected_dps(lv)])
	print("  期望软因子 = %.3f" % cfg.get_dps_soft_scale(est, lv))

	# 手工喂一个远超期望的 DPS，看重算后软因子会不会动
	wm.dps_provider = func() -> float: return 64.0
	wm._update_soft_hp_scale()
	print("  喂 64 DPS 后 _soft_hp_scale = %.3f（应 > 1.0）" % float(wm.get("_soft_hp_scale")))

	# 再喂一个极低 DPS
	wm.set("_soft_hp_scale", 1.0)
	wm.dps_provider = func() -> float: return 4.0
	wm._update_soft_hp_scale()
	print("  喂 4 DPS 后 _soft_hp_scale = %.3f（应 < 1.0）" % float(wm.get("_soft_hp_scale")))

	# 最后看敌人身上有没有真的乘上去
	var before := root.get_tree().get_nodes_in_group("enemies").size()
	wm.set("_soft_hp_scale", 1.5)
	if wm.has_method("_spawn_enemy"):
		wm._spawn_enemy()
	await create_timer(0.4).timeout
	var enemies := root.get_tree().get_nodes_in_group("enemies")
	print("  场上敌人 %d → %d 个" % [before, enemies.size()])
	for e in enemies:
		if "hp_scale" in e:
			print("    %s hp_scale=%.2f max_hp=%.1f（软因子 1.5 应乘进去）" % [
				e.name, float(e.get("hp_scale")), float(e.get("max_hp"))])
			break
	print("====== 诊断结束 ======\n")
	quit(0)
