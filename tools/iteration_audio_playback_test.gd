extends SceneTree
## 端到端播放验证（2026-11-14 迭代音效）。
##
## 前面的 iteration_audio_test 只证明"映射表和文件对得上"，
## 这一组证明"引擎在真实调用路径上确实播的是专属音"：
## - 真的建一个敌人、真的打死它，检查 AudioManager 实际播放的流；
## - 真的开一枪，检查实际播放的流；
## - 确认播出来的资源路径与该敌人的专属键一致，而不是通用音。
##
## 做法：不断轮询 AudioManager 的播放器池，记录所有处于播放状态的流。
## 不替换任何方法，避免动到生产代码。

var passed := 0
var failed := 0

var audio: Node


func _initialize() -> void:
	_run()


func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("PASS ", label)
	else:
		failed += 1
		print("FAIL ", label)


## 触发动作后立刻抓取此刻正在播放的流。
## 音效池里只有刚触发的那一个是新起的，其余是历史残留。
func _capture_new() -> Array[String]:
	var out: Array[String] = []
	if audio == null:
		return out
	for player in audio.get("_sfx_players"):
		if player.playing and player.stream != null:
			out.append(player.stream.resource_path)
	return out


func _run() -> void:
	await process_frame
	audio = root.get_node_or_null("AudioManager")
	check(audio != null, "AudioManager present")
	if audio == null:
		quit(1)
		return

	# --- 敌人路径：建敌人、受击、死亡 ---
	var enemy_scene = load("res://scenes/enemies/gem_leech.tscn")
	check(enemy_scene != null, "gem_leech scene loads")
	if enemy_scene != null:
		var enemy = enemy_scene.instantiate()
		root.add_child(enemy)
		await process_frame
		# 受击
		if enemy.has_method("take_damage"):
			enemy.call("take_damage", 1.0)
			var hit_seen := _capture_new()
			check(hit_seen.size() > 0, "gem_leech hit produced a sound")
			var hit_hit := false
			var hit_generic := false
			for p in hit_seen:
				if p.ends_with("hit_gem_leech.ogg"):
					hit_hit = true
				if p.ends_with("hit_enemy.ogg"):
					hit_generic = true
			check(hit_hit, "gem_leech hit plays dedicated sound")
			check(not hit_generic, "gem_leech hit does not use generic sound")
		# 死亡
		if enemy.has_method("_die"):
			enemy.call("_die")
			var death_seen := _capture_new()
			var death_hit := false
			var death_generic := false
			for p in death_seen:
				if p.ends_with("death_gem_leech.ogg"):
					death_hit = true
				if p.ends_with("enemy_death.ogg"):
					death_generic = true
			check(death_hit, "gem_leech death plays dedicated sound")
			check(not death_generic, "gem_leech death does not use generic sound")
		enemy.queue_free()

	# --- 旧敌人路径：必须仍然走通用音 ---
	await process_frame
	var old_scene = load("res://scenes/enemies/vampire.tscn")
	if old_scene != null:
		var old_enemy = old_scene.instantiate()
		root.add_child(old_enemy)
		await process_frame
		if old_enemy.has_method("take_damage"):
			old_enemy.call("take_damage", 1.0)
			var seen := _capture_new()
			var generic := false
			for p in seen:
				if p.ends_with("hit_enemy.ogg"):
					generic = true
			check(generic, "legacy enemy still uses generic hit sound")
		old_enemy.queue_free()

	# --- 武器路径：专属发射音 ---
	# WeaponManager 不是 autoload，这里自己实例化一个。
	var wm = root.get_node_or_null("WeaponManager")
	if wm == null:
		var wm_script = load("res://scripts/weapons/weapon_manager.gd")
		wm = wm_script.new()
		root.add_child(wm)
		await process_frame
		# setup() 里才会把 _audio_lib 注入为 AudioLib；不调用它就拿不到音效库。
		wm.call("setup", null, "pistol")
		await process_frame
	if wm != null:
		wm.call("_play_shoot_sound", "scythe", "")
		await process_frame
		var scythe_seen := _capture_new()
		var scythe_ok := false
		for p in scythe_seen:
			if p.ends_with("shot_scythe.ogg"):
				scythe_ok = true
		check(scythe_ok, "scythe plays dedicated shot sound")
		# 融合卡：按 fusion_kind 走自己的音
		wm.call("_play_shoot_sound", "crossbow", "thunder")
		await process_frame
		var thunder_seen := _capture_new()
		var thunder_ok := false
		for p in thunder_seen:
			if p.ends_with("shot_thunder_bolt.ogg"):
				thunder_ok = true
		check(thunder_ok, "thunder fusion plays dedicated shot sound")
		# 旧武器：必须仍然走原来的通用映射
		wm.call("_play_shoot_sound", "pistol", "")
		await process_frame
		var pistol_seen := _capture_new()
		var pistol_ok := false
		for p in pistol_seen:
			if p.ends_with("shoot_pistol.ogg"):
				pistol_ok = true
		check(pistol_ok, "legacy weapon still uses its original sound")
	else:
		print("SKIP WeaponManager not in this scene tree")

	print("RESULT iteration_audio_playback: %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)
