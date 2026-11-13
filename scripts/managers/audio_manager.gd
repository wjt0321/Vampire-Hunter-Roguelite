extends Node
## 音频管理器（AutoLoad 单例）
## 管理 BGM 和 SFX 的播放、音量控制

# ========== 音量设置 ==========
var music_volume: float = 0.1  # 0.0 - 1.0 (默认10%)
var sfx_volume: float = 0.1    # 0.0 - 1.0 (默认10%)

# ========== 音频播放器 ==========
var _bgm_player: AudioStreamPlayer = null
var _sfx_players: Array[AudioStreamPlayer] = []
var _max_sfx_players: int = 8

# ========== BGM 过渡 ==========
var _bgm_tween: Tween = null
# 用户音量与曲目过渡独立；Tween 只能改淡入淡出系数。
var _bgm_fade: float = 1.0:
	set(value):
		_bgm_fade = value
		_apply_bgm_volume()
const BGM_FADE_DURATION: float = 1.0

# ========== 信号 ==========
signal music_volume_changed(volume: float)
signal sfx_volume_changed(volume: float)

# ========== 存档引用 ==========
var save_mgr: Node = null

func _ready() -> void:
	save_mgr = get_node_or_null("/root/SaveManager")
	_load_volume_settings()
	_setup_bgm_player()
	_setup_sfx_players()
	print("🎵 AudioManager 已初始化")

func _exit_tree() -> void:
	if _bgm_tween != null and _bgm_tween.is_valid():
		_bgm_tween.kill()
	_bgm_tween = null
	if _bgm_player != null and is_instance_valid(_bgm_player):
		_bgm_player.stop()
		_bgm_player.stream = null
	for player in _sfx_players:
		if player != null and is_instance_valid(player):
			player.stop()
			player.stream = null
	# 音频在独立混音线程释放 playback；停播后立即退出会让 MP3 流仍被该线程引用。
	# 给最后一次混音留出两个常见缓冲周期，避免正常关闭游戏时误报资源泄漏。
	OS.delay_msec(100)

func _load_volume_settings() -> void:
	## 从存档加载音量设置
	if save_mgr and save_mgr.save_data.has("audio_settings"):
		var audio_settings: Dictionary = save_mgr.save_data["audio_settings"]
		music_volume = audio_settings.get("music_volume", 0.1)
		sfx_volume = audio_settings.get("sfx_volume", 0.1)
		print("🎵 音量设置已加载: 音乐 %.0f%%, 音效 %.0f%%" % [music_volume * 100, sfx_volume * 100])

func _save_volume_settings() -> void:
	## 保存音量设置到存档
	if save_mgr:
		if not save_mgr.save_data.has("audio_settings"):
			save_mgr.save_data["audio_settings"] = {}
		save_mgr.save_data["audio_settings"]["music_volume"] = music_volume
		save_mgr.save_data["audio_settings"]["sfx_volume"] = sfx_volume
		save_mgr.save_game()
		print("🎵 音量设置已保存")

func _setup_bgm_player() -> void:
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.name = "BGMPlayer"
	_bgm_player.bus = "Music"
	_bgm_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_bgm_player)

func _setup_sfx_players() -> void:
	# 最后一格只供 UI 使用，八个战斗声全暂停时仍能反馈且不抢占它们。
	for i in range(_max_sfx_players + 1):
		var player := AudioStreamPlayer.new()
		player.name = "SFXPlayer_%d" % i
		player.bus = "SFX"
		player.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(player)
		_sfx_players.append(player)

# ========== BGM 控制 ==========

func play_bgm(stream: AudioStream, fade: bool = true) -> void:
	if stream == null:
		return
	
	_cancel_bgm_tween()
	# 同曲请求也要先取消待切换/待停止回调，但不能重新从头播放。
	if _bgm_player.playing and _bgm_player.stream == stream:
		_bgm_fade = 1.0
		return
	if _bgm_player.playing and fade:
		_fade_bgm_transition(stream)
	else:
		_bgm_player.stream = stream
		_bgm_fade = 1.0
		_bgm_player.play()

func stop_bgm(fade: bool = true) -> void:
	_cancel_bgm_tween()
	if not _bgm_player.playing:
		return
	
	if fade:
		_fade_bgm_out()
	else:
		_bgm_player.stop()

func _cancel_bgm_tween() -> void:
	if _bgm_tween and _bgm_tween.is_valid():
		_bgm_tween.kill()
	_bgm_tween = null

func _apply_bgm_volume() -> void:
	if _bgm_player != null:
		_bgm_player.volume_db = _volume_to_db(music_volume * _bgm_fade)

func _fade_bgm_transition(new_stream: AudioStream) -> void:
	_bgm_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_bgm_tween.tween_property(self, "_bgm_fade", 0.0, BGM_FADE_DURATION / 2.0)
	_bgm_tween.tween_callback(func():
		_bgm_player.stream = new_stream
		_bgm_player.play()
	)
	_bgm_tween.tween_property(self, "_bgm_fade", 1.0, BGM_FADE_DURATION / 2.0)

func _fade_bgm_out() -> void:
	_bgm_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_bgm_tween.tween_property(self, "_bgm_fade", 0.0, BGM_FADE_DURATION)
	_bgm_tween.tween_callback(func():
		_bgm_player.stop()
	)

# ========== SFX 控制 ==========

func play_ui_sfx(stream: AudioStream, pitch_random: float = 0.0) -> void:
	play_sfx(stream, pitch_random, true)

func play_sfx(stream: AudioStream, pitch_random: float = 0.0, during_pause: bool = false) -> void:
	if stream == null:
		return
	
	# 合并同流 50ms 内的战斗连发，避免范围命中瞬间占满整个池；UI 不限流。
	# 使用请求时间，混音线程的播放进度可能滞后一个缓冲区。
	var requested_at := Time.get_ticks_msec()
	if not during_pause:
		for active in _sfx_players:
			if active.stream == stream and active.playing and not active.stream_paused \
					and active.process_mode == Node.PROCESS_MODE_PAUSABLE \
					and requested_at - int(active.get_meta("audio_started_msec", 0)) < 50:
				return

	# 找到一个空闲的 SFX 播放器
	var player := _get_available_sfx_player(during_pause)
	if player == null:
		return
	
	# 池化节点每次借出都重置暂停语义，不能继承上次 UI/战斗用途。
	player.process_mode = Node.PROCESS_MODE_ALWAYS if during_pause else Node.PROCESS_MODE_PAUSABLE
	player.stream = stream
	player.volume_db = _volume_to_db(sfx_volume)
	
	if pitch_random > 0.0:
		player.pitch_scale = 1.0 + randf_range(-pitch_random, pitch_random)
	else:
		player.pitch_scale = 1.0
	
	player.set_meta("audio_started_msec", requested_at)
	player.play()
	# play() 可解除 stream_paused；在已暂停的世界里新发出的战斗音效也必须等待。
	player.stream_paused = not player.can_process()

func _get_available_sfx_player(during_pause: bool = false) -> AudioStreamPlayer:
	var count := _sfx_players.size() if during_pause else _max_sfx_players
	# 优先找未播放的
	for i in range(count):
		var player := _sfx_players[i]
		if not player.playing and not player.stream_paused:
			return player
	
	# 暂停中的战斗仍占用槽位，不能被 UI 覆盖；只抢占正在运行的音效。
	var oldest_player: AudioStreamPlayer = null
	var max_position: float = -1.0
	
	for i in range(count):
		var player := _sfx_players[i]
		if not player.stream_paused and player.get_playback_position() > max_position:
			max_position = player.get_playback_position()
			oldest_player = player
	
	return oldest_player

# ========== 音量控制 ==========

func set_music_volume(volume: float, save: bool = true) -> void:
	music_volume = clampf(volume, 0.0, 1.0)
	_apply_bgm_volume()
	music_volume_changed.emit(music_volume)
	if save:
		_save_volume_settings()

func set_sfx_volume(volume: float, save: bool = true) -> void:
	sfx_volume = clampf(volume, 0.0, 1.0)
	sfx_volume_changed.emit(sfx_volume)
	if save:
		_save_volume_settings()

func get_music_volume() -> float:
	return music_volume

func get_sfx_volume() -> float:
	return sfx_volume

# ========== 工具函数 ==========

func _volume_to_db(linear: float) -> float:
	if linear <= 0.0:
		return -80.0
	return 20.0 * log(linear) / log(10.0)
