extends SceneTree
## BGM 切换诊断：为什么玩家从头到尾只听到一首。
## 打印每一次 play_bgm 之后真正在播的流、对每首曲子算一个粗指纹（时长 + 分段能量），
## 用来区分"没切换"和"切换了但曲子听着一样"。

func _initialize() -> void:
	_run()

func _fingerprint(stream: AudioStream) -> String:
	if stream == null:
		return "<null>"
	var ogg := stream as AudioStreamOggVorbis
	if ogg == null:
		return "not ogg"
	var data: PackedByteArray = ogg.get_data()
	var samples: int = data.size() / 2
	if samples <= 0:
		return "empty"
	var seg: int = samples / 8
	var parts: Array[String] = []
	for i in 8:
		var start: int = i * seg
		var acc: float = 0.0
		var count: int = 0
		var j: int = start
		var limit: int = start + seg
		while j < limit and j < samples:
			var v: int = int(data[j * 2]) | (int(data[j * 2 + 1]) << 8)
			if v > 32767:
				v -= 65536
			acc += absf(float(v))
			count += 1
			j += 4
		parts.append("%3d" % int(acc / maxf(float(count), 1.0)))
	return "len=%.1fs seg=[%s]" % [ogg.get_length(), " ".join(parts)]

func _stream_name(audio: Node) -> String:
	var player = audio.get("_bgm_player")
	if player == null:
		return "<no player>"
	var st = player.get("stream")
	if st == null:
		return "<null>"
	return String(st.get("resource_path"))

func _run() -> void:
	await process_frame
	var lib = root.get_node("AudioLib")
	var audio = root.get_node("AudioManager")
	audio.set_music_volume(0.5, false)

	print("=== 各曲指纹 ===")
	for key in ["menu", "battle", "boss", "shop", "victory", "defeat"]:
		var s: AudioStream = lib.call("get_%s_bgm" % key)
		print("  %-8s %s" % [key, _fingerprint(s)])

	print("=== 切换过程 ===")
	var battle: AudioStream = lib.call("get_battle_bgm")
	var shop: AudioStream = lib.call("get_shop_bgm")
	var boss: AudioStream = lib.call("get_boss_bgm")

	audio.play_bgm(battle, false)
	await process_frame
	print("  battle -> ", _stream_name(audio), " playing=", audio.get("_bgm_player").playing)

	audio.play_bgm(shop, true)
	await create_timer(1.6).timeout
	print("  shop   -> ", _stream_name(audio), " playing=", audio.get("_bgm_player").playing,
		" fade=%.2f" % float(audio.get("_bgm_fade")))

	audio.play_bgm(boss, true)
	await create_timer(1.6).timeout
	print("  boss   -> ", _stream_name(audio), " playing=", audio.get("_bgm_player").playing,
		" fade=%.2f" % float(audio.get("_bgm_fade")))

	audio.stop_bgm(false)
	quit(0)
