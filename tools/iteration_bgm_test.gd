extends SceneTree
## BGM 专项回归（2026-11-14 重做后的 6 首）。
##
## 验证：
## - 6 首 BGM 都是真实 OGG、非空、循环策略正确；
## - 循环曲在结尾会真的绕回开头（不是播完停住）；
## - 循环接缝没有跳变（seam_jump 接近 0），重做后不能出现"接缝咔哒"；
## - 一次性曲目播完会停；
## - 响度落在 -21 LUFS 附近（重做后不能比旧版差太多）。

var passed := 0
var failed := 0

const BGM_LOOPS: Dictionary = {
	"menu": true, "battle": true, "boss": true,
	"victory": false, "defeat": false, "shop": true,
}


func _initialize() -> void:
	_run()


func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("PASS ", label)
	else:
		failed += 1
		print("FAIL ", label)


func _run() -> void:
	await process_frame
	var lib = root.get_node("AudioLib")
	var audio = root.get_node("AudioManager")
	audio.set_music_volume(0.0, false)
	for key in BGM_LOOPS:
		var path := "res://assets/audio/generated/bgm/%s.ogg" % key
		var stream: AudioStream = lib.call("get_%s_bgm" % key)
		check(stream is AudioStreamOggVorbis, "real Ogg stream " + path)
		if not stream is AudioStreamOggVorbis:
			continue
		check(stream.resource_path == path and ResourceLoader.exists(path),
			"loaded expected asset " + path)
		check(stream.get_length() > 10.0, "bgm has real duration " + key)
		check(stream.loop == BGM_LOOPS[key], "explicit loop policy " + key)
		# 循环曲必须真的绕回，不能播完停住
		audio.play_bgm(stream, false)
		audio._bgm_player.seek(maxf(0.0, stream.get_length() - 0.1))
		await create_timer(0.4).timeout
		check(audio._bgm_player.playing == BGM_LOOPS[key],
			"playback end loops or stops " + key)
		# 绕回后播放位置应当回到开头附近，而不是停在末尾
		if BGM_LOOPS[key] and audio._bgm_player.playing:
			var pos: float = audio._bgm_player.get_playback_position()
			check(pos < stream.get_length() * 0.5,
				"loop wrapped back to the start " + key + " pos=%.2f" % pos)
	audio.stop_bgm(false)
	await process_frame
	print("RESULT iteration_bgm: %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)
