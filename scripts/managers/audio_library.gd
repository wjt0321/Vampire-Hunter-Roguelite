class_name AudioLibrary
extends Node
## 音频资源库
## 提供程序生成的默认音效

# ========== 音效生成参数 ==========
const SAMPLE_RATE: int = 44100

# ========== 缓存 ==========
var _cached_sounds: Dictionary = {}

# ========== 公共接口 ==========

func get_sound(sound_name: String) -> AudioStreamWAV:
	if _cached_sounds.has(sound_name):
		return _cached_sounds[sound_name]
	
	var sound := _generate_sound(sound_name)
	_cached_sounds[sound_name] = sound
	return sound

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
		var envelope := lerp(start_volume, end_volume, progress)
		var noise := (randf() * 2.0 - 1.0) * envelope * 127.0 + 128.0
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

func get_menu_bgm() -> AudioStreamWAV:
	return _generate_ambient_loop(60.0, [220, 261, 329], 0.3)

func get_battle_bgm() -> AudioStreamWAV:
	return _generate_ambient_loop(30.0, [146, 174, 220], 0.4)

func get_boss_bgm() -> AudioStreamWAV:
	return _generate_ambient_loop(20.0, [110, 130, 164], 0.5)

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
