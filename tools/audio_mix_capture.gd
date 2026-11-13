extends SceneTree
## Captures the real first combat room through Godot's audio bus using an isolated tool save.
var recorder: AudioEffectRecord
var capture: AudioEffectCapture
var peak := 0.0
var clipped_frames := 0
var recorded_frames := 0

func _initialize() -> void:
	_run()

func _run() -> void:
	await process_frame
	var save = root.get_node("SaveManager")
	if not save.is_tool_run or not save.save_path.begins_with("user://test_"):
		push_error("Mix capture requires isolated tool save")
		quit(1)
		return
	var audio = root.get_node("AudioManager")
	audio.set_music_volume(1.0, false)
	audio.set_sfx_volume(1.0, false)
	recorder = AudioEffectRecord.new()
	recorder.format = AudioStreamWAV.FORMAT_16_BITS
	capture = AudioEffectCapture.new()
	capture.buffer_length = 1.0
	AudioServer.add_bus_effect(0, recorder)
	AudioServer.add_bus_effect(0, capture)
	recorder.set_recording_active(true)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	game.player.max_hp = 1000000.0
	game.player.current_hp = game.player.max_hp
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < 35000:
		if game.upgrade_ui != null and game.upgrade_ui.visible:
			game.upgrade_ui._on_skip()
		var frames := capture.get_frames_available()
		if frames > 0:
			var samples := capture.get_buffer(frames)
			for sample in samples:
				var amplitude: float = maxf(absf(sample.x), absf(sample.y))
				peak = maxf(peak, amplitude)
				if amplitude >= 1.0:
					clipped_frames += 1
				recorded_frames += 1
		await process_frame
	recorder.set_recording_active(false)
	var recording := recorder.get_recording()
	var target := "res://artifacts/game-audio-20261113/gameplay_mix.wav"
	var result := recording.save_to_wav(target)
	var report := {"save_result": result, "peak_linear": peak, "clipped_frames": clipped_frames, "captured_frames": recorded_frames, "music_gain": 1.0, "sfx_gain": 1.0, "audio_driver": AudioServer.get_driver_name(), "context": "Real first combat room, 35 seconds, stationary invulnerable test player, automatic fire; no listening claim"}
	var file := FileAccess.open("res://artifacts/game-audio-20261113/gameplay_mix_report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("MIX_CAPTURE ", JSON.stringify(report))
	AudioServer.remove_bus_effect(0, AudioServer.get_bus_effect_count(0) - 1)
	AudioServer.remove_bus_effect(0, AudioServer.get_bus_effect_count(0) - 1)
	paused = false
	game.queue_free()
	await process_frame
	quit(0 if result == OK and recorded_frames > 0 and peak > 0.001 and clipped_frames == 0 else 1)
