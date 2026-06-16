class_name AudioLibrary
extends Node
## 音频资源库
## 提供程序生成的默认音效

# ========== 音效生成参数 ==========
const SAMPLE_RATE: int = 44100

# ========== 真实音频文件映射 ==========
const SFX_PATHS: Dictionary = {
	"shoot_pistol": "res://assets/audio/sfx/sfx_shoot.ogg",
	"shoot_shotgun": "res://assets/audio/sfx/sfx_shoot_shotgun.ogg",
	"shoot_magic": "res://assets/audio/sfx/sfx_shoot_magic.ogg",
	"knife_throw": "res://assets/audio/sfx/sfx_knife_throw.ogg",
	"poison_cloud": "res://assets/audio/sfx/sfx_poison_cloud.ogg",
	"lightning_chain": "res://assets/audio/sfx/sfx_lightning_chain.ogg",
	"boss_attack": "res://assets/audio/sfx/sfx_boss_attack.ogg",
	"hit_enemy": "res://assets/audio/sfx/sfx_hit_enemy.ogg",
	"enemy_death": "res://assets/audio/sfx/sfx_enemy_death.ogg",
	"pickup_xp": "res://assets/audio/sfx/sfx_pickup_xp.ogg",
	"level_up": "res://assets/audio/sfx/sfx_levelup.ogg",
	"button_click": "res://assets/audio/sfx/sfx_click.ogg",
	"explosion": "res://assets/audio/sfx/sfx_explosion.ogg",
	"shield_break": "res://assets/audio/sfx/sfx_shield_break.ogg",
	"heal": "res://assets/audio/sfx/sfx_coin.ogg",
	"player_hurt": "res://assets/audio/sfx/sfx_player_hurt.ogg",
	"hover": "res://assets/audio/sfx/sfx_hover.ogg",
	"teleport": "res://assets/audio/sfx/sfx_teleport.wav",
}

const BGM_PATHS: Dictionary = {
	"menu": "res://assets/audio/bgm/bgm_menu.mp3",
	"battle": "res://assets/audio/bgm/bgm_battle.mp3",
	"boss": "res://assets/audio/bgm/bgm_boss.ogg",
	"victory": "res://assets/audio/bgm/bgm_victory.ogg",
	"defeat": "res://assets/audio/bgm/bgm_defeat.mp3",
	"shop": "res://assets/audio/bgm/bgm_shop.ogg",
}

# ========== 缓存 ==========
var _cached_sounds: Dictionary = {}
var _cached_bgms: Dictionary = {}

# ========== 公共接口 ==========

func get_sound(sound_name: String) -> AudioStream:
	if _cached_sounds.has(sound_name):
		return _cached_sounds[sound_name]
	
	# 优先加载真实音频文件
	if SFX_PATHS.has(sound_name):
		var stream := _load_audio_file(SFX_PATHS[sound_name])
		if stream:
			_cached_sounds[sound_name] = stream
			return stream
	
	var sound := _generate_sound(sound_name)
	_cached_sounds[sound_name] = sound
	return sound

func _load_audio_file(path: String) -> AudioStream:
	if ResourceLoader.exists(path):
		return load(path) as AudioStream
	return null

# ========== 音效生成 ==========

func _generate_sound(sound_name: String) -> AudioStreamWAV:
	match sound_name:
		"shoot_pistol":
			return _generate_noise_burst(0.1, 0.8, 0.3)
		"shoot_shotgun":
			return _generate_noise_burst(0.15, 0.6, 0.5)
		"shoot_magic":
			return _generate_tone(880, 0.2, 0.4)
		"hit_enemy":
			return _generate_noise_burst(0.05, 0.9, 0.2)
		"enemy_death":
			return _generate_noise_burst(0.2, 0.5, 0.4)
		"pickup_xp":
			return _generate_tone(1760, 0.1, 0.3)
		"level_up":
			return _generate_arpeggio([523, 659, 784, 1047], 0.4)
		"button_click":
			return _generate_tone(2000, 0.05, 0.2)
		"explosion":
			return _generate_noise_burst(0.3, 0.3, 0.8)
		"shield_break":
			return _generate_tone(440, 0.15, 0.5)
		"heal":
			return _generate_tone(880, 0.2, 0.3)
		_:
			return _generate_tone(440, 0.1, 0.3)

func _generate_tone(frequency: float, duration: float, volume: float) -> AudioStreamWAV:
	var samples := int(SAMPLE_RATE * duration)
	var data := PackedByteArray()
	data.resize(samples)
	
	for i in range(samples):
		var t := float(i) / SAMPLE_RATE
		var envelope := 1.0 - (float(i) / samples)  # 简单衰减包络
		var value := sin(t * frequency * TAU) * volume * envelope * 127.0 + 128.0
		data[i] = clampi(int(value), 0, 255)
	
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	return stream

func _generate_noise_burst(duration: float, start_volume: float, end_volume: float) -> AudioStreamWAV:
	var samples := int(SAMPLE_RATE * duration)
	var data := PackedByteArray()
	data.resize(samples)
	
	for i in range(samples):
		var progress := float(i) / samples
		var envelope: float = lerp(start_volume, end_volume, progress)
		var noise: float = (randf() * 2.0 - 1.0) * envelope * 127.0 + 128.0
		data[i] = clampi(int(noise), 0, 255)
	
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	return stream

func _generate_arpeggio(frequencies: Array, duration: float) -> AudioStreamWAV:
	var samples_per_note := int(SAMPLE_RATE * duration / frequencies.size())
	var total_samples := samples_per_note * frequencies.size()
	var data := PackedByteArray()
	data.resize(total_samples)
	
	for note_idx in range(frequencies.size()):
		var freq := frequencies[note_idx] as float
		for i in range(samples_per_note):
			var sample_idx := note_idx * samples_per_note + i
			var t := float(i) / SAMPLE_RATE
			var envelope := 1.0 - (float(i) / samples_per_note)
			var value := sin(t * freq * TAU) * 0.5 * envelope * 127.0 + 128.0
			data[sample_idx] = clampi(int(value), 0, 255)
	
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	return stream

# ========== BGM 生成 ==========

func get_menu_bgm() -> AudioStream:
	var menu_path: String = BGM_PATHS.get("menu", "")
	if not menu_path.is_empty():
		var stream := _load_audio_file(menu_path)
		if stream:
			return stream
	# 回退到程序生成
	return _generate_simple_ambient(60.0, 174, 0.15)

func get_battle_bgm() -> AudioStream:
	var battle_path: String = BGM_PATHS.get("battle", "")
	if not battle_path.is_empty():
		var stream := _load_audio_file(battle_path)
		if stream:
			return stream
	return _generate_ambient_loop(30.0, [146, 174, 220], 0.4)

func get_boss_bgm() -> AudioStream:
	var boss_path: String = BGM_PATHS.get("boss", "")
	if not boss_path.is_empty():
		var stream := _load_audio_file(boss_path)
		if stream:
			return stream
	return _generate_ambient_loop(20.0, [110, 130, 164], 0.5)

func get_victory_bgm() -> AudioStream:
	var path: String = BGM_PATHS.get("victory", "")
	if not path.is_empty():
		var stream := _load_audio_file(path)
		if stream:
			return stream
	return _generate_simple_ambient(30.0, 523, 0.3)

func get_defeat_bgm() -> AudioStream:
	var path: String = BGM_PATHS.get("defeat", "")
	if not path.is_empty():
		var stream := _load_audio_file(path)
		if stream:
			return stream
	return _generate_ambient_loop(30.0, [110, 130], 0.3)

func get_shop_bgm() -> AudioStream:
	var path: String = BGM_PATHS.get("shop", "")
	if not path.is_empty():
		var stream := _load_audio_file(path)
		if stream:
			return stream
	return _generate_simple_ambient(30.0, 220, 0.2)

func _generate_ambient_loop(duration: float, base_freqs: Array, volume: float) -> AudioStreamWAV:
	var samples := int(SAMPLE_RATE * duration)
	var data := PackedByteArray()
	data.resize(samples)
	
	for i in range(samples):
		var t := float(i) / SAMPLE_RATE
		var value := 0.0
		
		# 叠加多个低频正弦波创造氛围感
		for freq in base_freqs:
			value += sin(t * freq * TAU) * volume
		
		# 添加一些噪声增加质感
		value += (randf() * 2.0 - 1.0) * volume * 0.1
		
		# 应用缓慢的包络
		var envelope := 0.8 + 0.2 * sin(t * 0.5 * TAU)
		value *= envelope
		
		data[i] = clampi(int(value * 127.0 + 128.0), 0, 255)
	
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = samples
	stream.data = data
	return stream

func _generate_simple_ambient(duration: float, frequency: float, volume: float) -> AudioStreamWAV:
	## 生成简单的单音环境音乐，更柔和
	var samples := int(SAMPLE_RATE * duration)
	var data := PackedByteArray()
	data.resize(samples)
	
	for i in range(samples):
		var t := float(i) / SAMPLE_RATE
		
		# 单一正弦波，非常柔和
		var value := sin(t * frequency * TAU) * volume
		
		# 添加缓慢变化的包络，避免刺耳
		var envelope := 0.5 + 0.5 * sin(t * 0.2 * TAU)
		value *= envelope
		
		data[i] = clampi(int(value * 127.0 + 128.0), 0, 255)
	
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = samples
	stream.data = data
	return stream
