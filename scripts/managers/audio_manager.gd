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
const BGM_FADE_DURATION: float = 1.0

# ========== 信号 ==========
signal music_volume_changed(volume: float)
signal sfx_volume_changed(volume: float)

func _ready() -> void:
	_setup_bgm_player()
	_setup_sfx_players()
	print("🎵 AudioManager 已初始化")

func _setup_bgm_player() -> void:
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.name = "BGMPlayer"
	_bgm_player.bus = "Music"
	add_child(_bgm_player)

func _setup_sfx_players() -> void:
	for i in range(_max_sfx_players):
		var player := AudioStreamPlayer.new()
		player.name = "SFXPlayer_%d" % i
		player.bus = "SFX"
		add_child(player)
		_sfx_players.append(player)

# ========== BGM 控制 ==========

func play_bgm(stream: AudioStream, fade: bool = true) -> void:
	if stream == null:
		return
	
	if _bgm_player.playing and fade:
		_fade_bgm_transition(stream)
	else:
		_bgm_player.stream = stream
		_bgm_player.volume_db = linear_to_db(music_volume)
		_bgm_player.play()

func stop_bgm(fade: bool = true) -> void:
	if not _bgm_player.playing:
		return
	
	if fade:
		_fade_bgm_out()
	else:
		_bgm_player.stop()

func _fade_bgm_transition(new_stream: AudioStream) -> void:
	if _bgm_tween and _bgm_tween.is_valid():
		_bgm_tween.kill()
	
	_bgm_tween = create_tween()
	_bgm_tween.tween_property(_bgm_player, "volume_db", -40.0, BGM_FADE_DURATION / 2.0)
	_bgm_tween.tween_callback(func():
		_bgm_player.stream = new_stream
		_bgm_player.play()
	)
	_bgm_tween.tween_property(_bgm_player, "volume_db", linear_to_db(music_volume), BGM_FADE_DURATION / 2.0)

func _fade_bgm_out() -> void:
	if _bgm_tween and _bgm_tween.is_valid():
		_bgm_tween.kill()
	
	_bgm_tween = create_tween()
	_bgm_tween.tween_property(_bgm_player, "volume_db", -40.0, BGM_FADE_DURATION)
	_bgm_tween.tween_callback(func():
		_bgm_player.stop()
	)

# ========== SFX 控制 ==========

func play_sfx(stream: AudioStream, pitch_random: float = 0.0) -> void:
	if stream == null:
		return
	
	# 找到一个空闲的 SFX 播放器
	var player := _get_available_sfx_player()
	if player == null:
		return
	
	player.stream = stream
	player.volume_db = linear_to_db(sfx_volume)
	
	if pitch_random > 0.0:
		player.pitch_scale = 1.0 + randf_range(-pitch_random, pitch_random)
	else:
		player.pitch_scale = 1.0
	
	player.play()

func _get_available_sfx_player() -> AudioStreamPlayer:
	# 优先找未播放的
	for player in _sfx_players:
		if not player.playing:
			return player
	
	# 如果都在播放，找播放进度最长的
	var oldest_player: AudioStreamPlayer = _sfx_players[0]
	var max_position: float = 0.0
	
	for player in _sfx_players:
		if player.get_playback_position() > max_position:
			max_position = player.get_playback_position()
			oldest_player = player
	
	return oldest_player

# ========== 音量控制 ==========

func set_music_volume(volume: float) -> void:
	music_volume = clampf(volume, 0.0, 1.0)
	if _bgm_player.playing:
		_bgm_player.volume_db = linear_to_db(music_volume)
	music_volume_changed.emit(music_volume)

func set_sfx_volume(volume: float) -> void:
	sfx_volume = clampf(volume, 0.0, 1.0)
	sfx_volume_changed.emit(sfx_volume)

func get_music_volume() -> float:
	return music_volume

func get_sfx_volume() -> float:
	return sfx_volume

# ========== 工具函数 ==========

func linear_to_db(linear: float) -> float:
	if linear <= 0.0:
		return -80.0
	return 20.0 * log(linear) / log(10.0)
