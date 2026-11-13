extends SceneTree
## Real audio players and UI callbacks; silent in-memory streams, no listening claim.
var passed := 0
var failed := 0
var audio: Node
var lib: Node
var host: Node2D
var track_a: AudioStreamWAV
var track_b: AudioStreamWAV
var track_c: AudioStreamWAV

func _initialize() -> void:
	_run()

func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("PASS ", label)
	else:
		failed += 1
		print("FAIL ", label)

func silent_stream(seconds: float = 10.0) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var bytes := PackedByteArray()
	bytes.resize(int(seconds * 22050) * 2)
	stream.data = bytes
	return stream

func reset_audio(volume: float = 0.5) -> void:
	# Test isolation only: don't use stop_bgm to hide the cancellation bug under test.
	if audio._bgm_tween != null and audio._bgm_tween.is_valid():
		audio._bgm_tween.kill()
	audio._bgm_player.stop()
	for player in audio._sfx_players:
		player.stop()
	paused = false
	audio.set_music_volume(volume, false)
	audio.play_bgm(track_a, false)

func check_gain_window(seconds: float, ceiling: float, label: String) -> void:
	var end := Time.get_ticks_msec() + int(seconds * 1000)
	var max_db := -1000.0
	var frames := 0
	while Time.get_ticks_msec() < end:
		await process_frame
		var db: float = audio._bgm_player.volume_db
		if is_nan(db):
			max_db = INF
		else:
			max_db = maxf(max_db, db)
		frames += 1
	check(frames > 2 and max_db <= ceiling + 0.01, "%s (%d frames, max %.3f dB)" % [label, frames, max_db])

func playing_sfx(stream: AudioStream) -> AudioStreamPlayer:
	for player in audio._sfx_players:
		if player.stream == stream and (player.playing or player.stream_paused):
			return player
	return null

func _run() -> void:
	await process_frame
	var save = root.get_node("SaveManager")
	check(save.is_tool_run and save.save_path == "user://test_pre_audio_audio_test.json", "isolated save active before UI")
	if not save.is_tool_run or not save.save_path.begins_with("user://test_"):
		quit(1)
		return
	audio = root.get_node("AudioManager")
	lib = root.get_node("AudioLib")
	host = Node2D.new()
	root.add_child(host)
	current_scene = host
	track_a = silent_stream()
	track_b = silent_stream()
	track_c = silent_stream()
	for key in lib.SFX_PATHS:
		lib._cached_sounds[key] = silent_stream(0.18)
	for key in ["shoot_crossbow", "flame_thrower", "blood_burst", "holy_wand", "purchase", "chest_open", "room_clear", "door_open"]:
		lib._cached_sounds[key] = silent_stream(0.18)
	var ui_sound := silent_stream(0.18)
	lib._cached_bgms["victory"] = track_b
	lib._cached_bgms["defeat"] = track_c
	for key in ["hover", "button_click", "pickup_xp"]:
		lib._cached_sounds[key] = ui_sound

	# Re-requesting the current track must keep its position and cancel stale callbacks.
	for pending in ["none", "stop", "switch"]:
		for fade in [false, true]:
			reset_audio()
			await create_timer(0.35).timeout
			if pending == "stop":
				audio.stop_bgm(true)
			elif pending == "switch":
				audio.play_bgm(track_b)
			await create_timer(0.15).timeout
			var position: float = audio._bgm_player.get_playback_position()
			audio.play_bgm(track_a, fade)
			check(audio._bgm_player.get_playback_position() >= position - 0.05, "same track preserves position pending=%s fade=%s" % [pending, fade])
			await create_timer(1.1).timeout
			check(audio._bgm_player.playing and audio._bgm_player.stream == track_a and audio._bgm_player.get_playback_position() > position + 0.8, "same track cancels stale callback pending=%s fade=%s" % [pending, fade])
			check(is_equal_approx(audio._bgm_player.volume_db, -6.0206), "same track restores user gain")

	# 43: settlement itself pauses the world and requests the new music.
	for victory in [true, false]:
		reset_audio()
		var combat := silent_stream()
		audio.play_sfx(combat)
		await create_timer(0.15).timeout
		var combat_player := playing_sfx(combat)
		check(combat_player != null, "43 combat starts before settlement")
		var over = load("res://scenes/ui/game_over_ui.tscn").instantiate()
		host.add_child(over)
		over.show_game_over({}, victory)
		check(paused, "43 real settlement pauses world")
		await create_timer(0.1).timeout
		check(audio._bgm_player.stream == track_a and not audio._bgm_player.stream_paused, "43 paused transition fades old track before switching")
		var combat_position: float = combat_player.get_playback_position()
		check(combat_player.stream_paused, "43 already-playing combat pauses")
		over.panel.find_children("", "Button", true)[0].mouse_entered.emit()
		check(paused and PauseController.is_held_by(over), "43 settlement pause remains held during hover")
		var ui_player := playing_sfx(ui_sound)
		check(ui_player != null and not ui_player.stream_paused, "43 settlement hover runs while paused")
		await create_timer(0.4).timeout
		check(ui_player != null and not ui_player.playing, "43 settlement hover finishes while paused")
		over._on_button_click_sfx()
		ui_player = playing_sfx(ui_sound)
		check(ui_player != null and not ui_player.stream_paused, "43 settlement click runs while paused")
		await create_timer(0.75).timeout
		check(audio._bgm_player.stream == (track_b if victory else track_c) and audio._bgm_player.playing and not audio._bgm_player.stream_paused, "43 settlement BGM switches and plays while paused")
		check(is_equal_approx(audio._bgm_player.volume_db, -6.0206), "43 paused transition reaches user gain")
		check(audio._bgm_player.get_playback_position() > 0.1, "43 new settlement music playback advances")
		check(combat_player.stream == combat and combat_player.has_stream_playback() and combat_player.stream_paused and absf(combat_player.get_playback_position() - combat_position) < 0.05, "43 combat remains frozen throughout UI playback")
		PauseController.release(over)
		await create_timer(0.2).timeout
		check(not combat_player.stream_paused and combat_player.get_playback_position() > combat_position + 0.05, "43 combat resumes after settlement pause released")
		over.queue_free()
		await process_frame

	# 43: shop purchase feedback, then reuse the very same player for combat.
	reset_audio()
	var player = load("res://scenes/player/player.tscn").instantiate()
	host.add_child(player)
	player.set_physics_process(false)
	player.add_silver(1000)
	var shop = load("res://scripts/ui/room_shop.gd").new()
	host.add_child(shop)
	shop.open(player)
	var offer: Dictionary = load("res://scripts/core/item_catalog.gd").find_consumable("damage")
	shop._offers = [offer, {}, {}, {}]
	shop._sold = [false, false, false, false]
	shop._locked = [false, false, false, false]
	shop._refresh()
	var before: int = player.silver
	shop._on_buy(0)
	check(paused and shop._sold[0] and player.silver == before - int(offer.price), "43 real shop purchase succeeds under pause")
	var shop_sfx := playing_sfx(lib._cached_sounds["purchase"])
	check(shop_sfx != null and not shop_sfx.stream_paused, "43 shop feedback plays under pause")
	await create_timer(0.4).timeout
	check(shop_sfx != null and not shop_sfx.playing, "43 shop feedback finishes under pause")
	# Stop allows reuse even on the broken baseline, keeping this case independent.
	if shop_sfx != null:
		shop_sfx.stop()
	var reused_sound := silent_stream()
	audio.play_sfx(reused_sound)
	var reused := playing_sfx(reused_sound)
	check(reused == shop_sfx and reused.stream_paused, "43 pooled UI player resets to pausable combat mode")
	shop.close()
	await create_timer(0.2).timeout
	check(reused.playing and not reused.stream_paused and reused.get_playback_position() > 0.05, "43 reused combat resumes")
	shop.queue_free()
	player.queue_free()
	await process_frame

	# 43: a busy combat pool must neither silence UI nor steal frozen combat.
	reset_audio()
	var frozen_players: Array[AudioStreamPlayer] = []
	var frozen_streams: Array[AudioStream] = []
	for i in 8:
		var sound := silent_stream()
		audio.play_sfx(sound)
		frozen_streams.append(sound)
		frozen_players.append(playing_sfx(sound))
	await create_timer(0.1).timeout
	paused = true
	var busy_over = load("res://scenes/ui/game_over_ui.tscn").instantiate()
	host.add_child(busy_over)
	busy_over._on_button_hover_sfx()
	var busy_ui := playing_sfx(ui_sound)
	check(busy_ui != null and not busy_ui.stream_paused, "43 full frozen combat pool still allows UI feedback")
	await create_timer(0.4).timeout
	var preserved := true
	for i in 8:
		preserved = preserved and frozen_players[i].stream == frozen_streams[i] and frozen_players[i].stream_paused
	check(preserved, "43 full pool preserves all eight frozen combat streams")
	paused = false
	await create_timer(0.2).timeout
	var resumed := true
	for frozen in frozen_players:
		resumed = resumed and frozen.playing and not frozen.stream_paused
	check(resumed, "43 full pool resumes all eight combat streams")
	busy_over.queue_free()
	await process_frame

	# 44: user gain changes during both halves, with immediate multiplicative effect.
	for delay in [0.2, 0.7]:
		reset_audio(0.8)
		audio.play_bgm(track_b)
		await create_timer(delay).timeout
		var old_gain: float = db_to_linear(audio._bgm_player.volume_db)
		audio.set_music_volume(0.2, false)
		check(absf(db_to_linear(audio._bgm_player.volume_db) - old_gain * 0.25) < 0.001, "44 settings multiply existing fade at %.1fs" % delay)
		await check_gain_window(1.2 - delay, -13.9794, "44 old tween never overrides new setting at %.1fs" % delay)
		check(is_equal_approx(audio._bgm_player.volume_db, -13.9794), "44 transition finishes at new user volume")

	# 45: zero volume must remain at silence during every frame, paused too.
	for pause_world in [false, true]:
		reset_audio(0.0)
		paused = pause_world
		audio.play_bgm(track_b)
		await check_gain_window(1.2, -80.0, "45 muted entire switch paused=%s" % pause_world)
		check(audio._bgm_player.stream == track_b and audio._bgm_player.playing, "45 muted switch still completes")
		audio.stop_bgm(true)
		await check_gain_window(1.2, -80.0, "45 muted stop never raises volume paused=%s" % pause_world)
		check(not audio._bgm_player.playing, "45 muted fade-out actually stops")
	reset_audio()
	audio.play_bgm(track_b)
	await create_timer(0.2).timeout
	audio.set_music_volume(0.0, false)
	await check_gain_window(1.1, -80.0, "45 muting mid-transition remains silent")

	# Pending transition callback and pending stop must not override immediate requests.
	for pending_stop in [false, true]:
		for immediate_stop in [false, true]:
			reset_audio()
			if pending_stop:
				audio.stop_bgm(true)
			else:
				audio.play_bgm(track_b)
			await create_timer(0.15).timeout
			if immediate_stop:
				audio.stop_bgm(false)
			else:
				audio.play_bgm(track_c, false)
			await create_timer(1.2).timeout
			if immediate_stop:
				check(not audio._bgm_player.playing, "cancel pending stop=%s with immediate stop" % pending_stop)
			else:
				check(audio._bgm_player.playing and audio._bgm_player.stream == track_c and is_equal_approx(audio._bgm_player.volume_db, -6.0206), "cancel pending stop=%s with immediate track" % pending_stop)
	paused = false
	audio.stop_bgm(false)
	for sfx in audio._sfx_players:
		sfx.stop()
	await check_event_audio()
	host.queue_free()
	await process_frame
	await process_frame
	print("RESULT audio: %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)

func stop_sfx() -> void:
	for player in audio._sfx_players:
		player.stop()

func sound_count(stream: AudioStream) -> int:
	var count := 0
	for player in audio._sfx_players:
		if player.stream == stream and (player.playing or player.stream_paused):
			count += 1
	return count

func check_event_audio() -> void:
	var player = load("res://scenes/player/player.tscn").instantiate()
	host.add_child(player)
	player.set_physics_process(false)
	var weapons = load("res://scripts/weapons/weapon_manager.gd").new()
	host.add_child(weapons)
	weapons.setup(player)
	weapons.set_process(false)
	var expected := {"pistol": "shoot_pistol", "shotgun": "shoot_shotgun", "magic_book": "shoot_magic", "throwing_knife": "knife_throw", "kunai": "knife_throw", "crossbow": "shoot_crossbow", "holy_wand": "holy_wand", "flame_thrower": "flame_thrower", "blood_burst": "blood_burst", "poison_cloud": "poison_cloud"}
	for key in expected:
		stop_sfx()
		weapons._play_shoot_sound(key)
		check(playing_sfx(lib._cached_sounds[expected[key]]) != null, "weapon cue " + key)
	var target := Node2D.new()
	target.position = Vector2(200, 200)
	host.add_child(target)
	target.add_to_group("enemies")
	stop_sfx()
	var shotgun = weapons.create_shotgun()
	shotgun.auto_aim = true
	weapons._fire_weapon(shotgun)
	check(sound_count(lib._cached_sounds["shoot_shotgun"]) == 1, "shotgun volley uses one cue for all pellets")
	stop_sfx()
	weapons._fire_weapon(weapons.create_lightning_chain())
	check(sound_count(lib._cached_sounds["lightning_chain"]) == 1 and sound_count(lib._cached_sounds["shoot_magic"]) == 0, "lightning cast uses one dedicated cue")
	target.remove_from_group("enemies")
	stop_sfx()
	weapons._fire_weapon(weapons.create_lightning_chain())
	check(sound_count(lib._cached_sounds["lightning_chain"]) == 0, "lightning without target is silent")
	stop_sfx()
	player.current_hp = player.max_hp
	player.heal(10.0)
	check(playing_sfx(lib._cached_sounds["heal"]) == null, "full health does not emit heal cue")
	stop_sfx()
	player.current_hp = player.max_hp - 20.0
	paused = true
	player.heal(10.0)
	var healing := playing_sfx(lib._cached_sounds["heal"])
	check(healing != null and not healing.stream_paused, "actual healing during shop pause is audible")
	paused = false
	check_pickup_audio(player)
	stop_sfx()
	var chest = load("res://scripts/managers/cursed_chest.gd").new()
	host.add_child(chest)
	chest.open()
	check(sound_count(lib._cached_sounds["chest_open"]) == 1, "chest opening emits cue")
	stop_sfx()
	chest.open()
	check(sound_count(lib._cached_sounds["chest_open"]) == 0, "opened chest cannot replay cue")
	# Real wave callback and exit creation: repeat notifications must not replay cues.
	stop_sfx()
	var room = load("res://scripts/map/game_room.gd").new()
	host.add_child(room)
	var main = load("res://scripts/managers/main.gd").new()
	main._audio_lib = lib
	main.current_room = room
	main._on_wave_completed(1)
	check(sound_count(lib._cached_sounds["room_clear"]) == 1 and sound_count(lib._cached_sounds["door_open"]) == 1, "cleared combat opens exit with both event cues")
	stop_sfx()
	main._on_wave_completed(1)
	check(sound_count(lib._cached_sounds["room_clear"]) == 0 and sound_count(lib._cached_sounds["door_open"]) == 0, "duplicate wave notification is silent")
	main.free()
	var boss = load("res://scenes/enemies/vampire_lord.tscn").instantiate()
	host.add_child(boss)
	boss.set_physics_process(false)
	stop_sfx()
	boss._telegraph_attack()
	check(sound_count(lib._cached_sounds["boss_attack"]) == 1, "boss attack windup has audio warning")
	stop_sfx()
	boss._die()
	check(sound_count(lib._cached_sounds["enemy_death"]) == 1, "boss death emits death cue")
	stop_sfx()
	var burst := silent_stream(1.0)
	for i in 12:
		audio.play_sfx(burst)
	check(sound_count(burst) == 1, "same-frame repeated combat cue coalesces")
	audio.play_ui_sfx(burst)
	check(sound_count(burst) == 2, "combat coalescing never suppresses UI")
	# Scene construction above can consume a long frame; measure real elapsed time.
	var repeat_at := Time.get_ticks_msec() + 80
	while Time.get_ticks_msec() < repeat_at:
		await process_frame
	var burst_position: float = playing_sfx(burst).get_playback_position() if playing_sfx(burst) != null else -1.0
	audio.play_sfx(burst)
	check(sound_count(burst) == 3, "subsequent combat cue is allowed after short window (position=%.3f, voices=%d)" % [burst_position, sound_count(burst)])
	await create_timer(1.4).timeout
	stop_sfx()
	weapons.queue_free()
	player.queue_free()
	target.queue_free()

func check_pickup_audio(player) -> void:
	stop_sfx()
	var coin = load("res://scripts/player/silver_coin.gd").new()
	coin._player = player
	coin.value = 3
	host.add_child(coin)
	coin.set_process(false)
	check(sound_count(lib._cached_sounds["pickup_coin"]) == 0, "coin spawn is silent")
	var silver_before: int = player.silver
	coin._collect()
	check(player.silver == silver_before + 3 and sound_count(lib._cached_sounds["pickup_coin"]) == 1, "coin collection grants silver and plays its cue")
	stop_sfx()
	coin._collect()
	check(player.silver == silver_before + 3 and sound_count(lib._cached_sounds["pickup_coin"]) == 0, "queued coin cannot grant or sound twice")
	for kind in ["magnet", "frenzy"]:
		stop_sfx()
		var cue: AudioStream = lib._cached_sounds["pickup_" + kind]
		var pickup = load("res://scripts/player/powerup.gd").new()
		pickup.kind = kind
		pickup._player = player
		host.add_child(pickup)
		pickup.set_process(false)
		var gem := Node2D.new()
		host.add_child(gem)
		gem.global_position = player.global_position + Vector2(200, 0)
		gem.add_to_group("xp_gems")
		check(sound_count(cue) == 0, kind + " spawn is silent")
		pickup._collect()
		var applied: bool = gem.global_position.distance_to(player.global_position) <= 24.1 if kind == "magnet" else player.is_powerup_active()
		check(applied and sound_count(cue) == 1, kind + " pickup applies effect and plays its cue")
		stop_sfx()
		pickup._collect()
		check(sound_count(cue) == 0, kind + " queued pickup cannot sound twice")
		gem.remove_from_group("xp_gems")
		gem.queue_free()
		var expired = load("res://scripts/player/powerup.gd").new()
		expired.kind = kind
		expired._player = player
		expired.lifetime = 0.0
		host.add_child(expired)
		expired.set_process(false)
		expired._process(0.01)
		check(expired.is_queued_for_deletion() and sound_count(cue) == 0, kind + " expiration is silent")
