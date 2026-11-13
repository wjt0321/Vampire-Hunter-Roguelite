extends SceneTree
## Integration gate for the real generated files; never injects fallback streams.
const SFX_KEYS: Array[String] = [
	"shoot_pistol", "shoot_shotgun", "shoot_magic", "knife_throw", "poison_cloud",
	"lightning_chain", "boss_attack", "hit_enemy", "enemy_death", "pickup_xp",
	"level_up", "button_click", "explosion", "shield_break", "heal", "player_hurt",
	"hover", "teleport", "shoot_crossbow", "flame_thrower", "blood_burst",
	"holy_wand", "purchase", "chest_open", "room_clear", "door_open",
	"pickup_coin", "pickup_magnet", "pickup_frenzy",
]
const BGM_LOOPS: Dictionary = {
	"menu": true, "battle": true, "boss": true,
	"victory": false, "defeat": false, "shop": true,
}
var passed := 0
var failed := 0

func _initialize() -> void:
	_run()

func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("PASS ", label)
	else:
		failed += 1
		print("FAIL ", label)

func check_asset(stream: AudioStream, path: String, looping: bool) -> void:
	check(stream is AudioStreamOggVorbis, "real Ogg stream " + path)
	if not stream is AudioStreamOggVorbis:
		return
	check(stream.resource_path == path and ResourceLoader.exists(path), "loaded expected asset " + path)
	check(stream.get_length() > 0.05, "nonempty decoded duration " + path)
	check(stream.loop == looping, "explicit loop policy " + path)

func _run() -> void:
	await process_frame
	var save = root.get_node("SaveManager")
	check(save.is_tool_run and save.save_path == "user://test_audio_assets_test.json", "isolated save active")
	if not save.is_tool_run or not save.save_path.begins_with("user://test_"):
		quit(1)
		return
	var lib = root.get_node("AudioLib")
	var audio = root.get_node("AudioManager")
	check(lib.SFX_PATHS.size() == 29 and lib.BGM_PATHS.size() == 6, "complete 29 SFX and 6 BGM catalog")
	for key in SFX_KEYS:
		var stream: AudioStream = lib.get_sound(key)
		check_asset(stream, "res://assets/audio/generated/sfx/%s.ogg" % key, false)
		check(stream != null and lib.get_sound(key) == stream, "SFX cached " + key)
	audio.set_music_volume(0.0, false)
	for key in BGM_LOOPS:
		var stream: AudioStream = lib.call("get_%s_bgm" % key)
		check_asset(stream, "res://assets/audio/generated/bgm/%s.ogg" % key, BGM_LOOPS[key])
		check(stream != null and lib.call("get_%s_bgm" % key) == stream, "BGM cached " + key)
		if stream == null:
			continue
		audio.play_bgm(stream, false)
		audio._bgm_player.seek(maxf(0.0, stream.get_length() - 0.1))
		await create_timer(0.4).timeout
		check(audio._bgm_player.playing == BGM_LOOPS[key], "playback end loops or stops " + key)
	audio.stop_bgm(false)
	await process_frame
	print("RESULT audio_assets: %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)
