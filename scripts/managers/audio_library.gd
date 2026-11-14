class_name AudioLibrary
extends Node
## 音频资源库
## 正式音频必须来自 generated 资源；缺失时明确报错，不回退合成占位音。

# ========== 音效生成参数 ==========
const SAMPLE_RATE: int = 44100

# ========== 真实音频文件映射 ==========
const SFX_PATHS: Dictionary = {
	"shoot_pistol": "res://assets/audio/generated/sfx/shoot_pistol.ogg",
	"shoot_shotgun": "res://assets/audio/generated/sfx/shoot_shotgun.ogg",
	"shoot_magic": "res://assets/audio/generated/sfx/shoot_magic.ogg",
	"knife_throw": "res://assets/audio/generated/sfx/knife_throw.ogg",
	"poison_cloud": "res://assets/audio/generated/sfx/poison_cloud.ogg",
	"lightning_chain": "res://assets/audio/generated/sfx/lightning_chain.ogg",
	"boss_attack": "res://assets/audio/generated/sfx/boss_attack.ogg",
	"hit_enemy": "res://assets/audio/generated/sfx/hit_enemy.ogg",
	"enemy_death": "res://assets/audio/generated/sfx/enemy_death.ogg",
	"pickup_xp": "res://assets/audio/generated/sfx/pickup_xp.ogg",
	"pickup_coin": "res://assets/audio/generated/sfx/pickup_coin.ogg",
	"pickup_magnet": "res://assets/audio/generated/sfx/pickup_magnet.ogg",
	"pickup_frenzy": "res://assets/audio/generated/sfx/pickup_frenzy.ogg",
	"level_up": "res://assets/audio/generated/sfx/level_up.ogg",
	"button_click": "res://assets/audio/generated/sfx/button_click.ogg",
	"explosion": "res://assets/audio/generated/sfx/explosion.ogg",
	"shield_break": "res://assets/audio/generated/sfx/shield_break.ogg",
	"heal": "res://assets/audio/generated/sfx/heal.ogg",
	"player_hurt": "res://assets/audio/generated/sfx/player_hurt.ogg",
	"hover": "res://assets/audio/generated/sfx/hover.ogg",
	"teleport": "res://assets/audio/generated/sfx/teleport.ogg",
	"shoot_crossbow": "res://assets/audio/generated/sfx/shoot_crossbow.ogg",
	"flame_thrower": "res://assets/audio/generated/sfx/flame_thrower.ogg",
	"blood_burst": "res://assets/audio/generated/sfx/blood_burst.ogg",
	"holy_wand": "res://assets/audio/generated/sfx/holy_wand.ogg",
	"purchase": "res://assets/audio/generated/sfx/purchase.ogg",
	"chest_open": "res://assets/audio/generated/sfx/chest_open.ogg",
	"room_clear": "res://assets/audio/generated/sfx/room_clear.ogg",
	"door_open": "res://assets/audio/generated/sfx/door_open.ogg",
	# ---- 迭代新增内容的专属音效（2026-11-14）----
	# 12 把新武器与融合卡的发射音
	"shot_scythe": "res://assets/audio/generated/sfx/shot_scythe.ogg",
	"shot_thorn_whip": "res://assets/audio/generated/sfx/shot_thorn_whip.ogg",
	"shot_frost_bell": "res://assets/audio/generated/sfx/shot_frost_bell.ogg",
	"shot_repeater": "res://assets/audio/generated/sfx/shot_repeater.ogg",
	"shot_soul_lantern": "res://assets/audio/generated/sfx/shot_soul_lantern.ogg",
	"shot_spike_tome": "res://assets/audio/generated/sfx/shot_spike_tome.ogg",
	"shot_chain_gun": "res://assets/audio/generated/sfx/shot_chain_gun.ogg",
	"shot_thunder_bolt": "res://assets/audio/generated/sfx/shot_thunder_bolt.ogg",
	"shot_miasma": "res://assets/audio/generated/sfx/shot_miasma.ogg",
	"shot_returning_blade": "res://assets/audio/generated/sfx/shot_returning_blade.ogg",
	"shot_twin_chant": "res://assets/audio/generated/sfx/shot_twin_chant.ogg",
	"shot_burning_blood": "res://assets/audio/generated/sfx/shot_burning_blood.ogg",
	# 12 种新敌人的受击音
	"hit_shield_guard": "res://assets/audio/generated/sfx/hit_shield_guard.ogg",
	"hit_blood_priest": "res://assets/audio/generated/sfx/hit_blood_priest.ogg",
	"hit_web_weaver": "res://assets/audio/generated/sfx/hit_web_weaver.ogg",
	"hit_coffin_guard": "res://assets/audio/generated/sfx/hit_coffin_guard.ogg",
	"hit_blood_hound": "res://assets/audio/generated/sfx/hit_blood_hound.ogg",
	"hit_furnace_golem": "res://assets/audio/generated/sfx/hit_furnace_golem.ogg",
	"hit_burrower": "res://assets/audio/generated/sfx/hit_burrower.ogg",
	"hit_gem_leech": "res://assets/audio/generated/sfx/hit_gem_leech.ogg",
	"hit_lantern_wraith": "res://assets/audio/generated/sfx/hit_lantern_wraith.ogg",
	"hit_alchemist_pitcher": "res://assets/audio/generated/sfx/hit_alchemist_pitcher.ogg",
	"hit_resonance_mage": "res://assets/audio/generated/sfx/hit_resonance_mage.ogg",
	"hit_moon_wing": "res://assets/audio/generated/sfx/hit_moon_wing.ogg",
	# 12 种新敌人的死亡音
	"death_shield_guard": "res://assets/audio/generated/sfx/death_shield_guard.ogg",
	"death_blood_priest": "res://assets/audio/generated/sfx/death_blood_priest.ogg",
	"death_web_weaver": "res://assets/audio/generated/sfx/death_web_weaver.ogg",
	"death_coffin_guard": "res://assets/audio/generated/sfx/death_coffin_guard.ogg",
	"death_blood_hound": "res://assets/audio/generated/sfx/death_blood_hound.ogg",
	"death_furnace_golem": "res://assets/audio/generated/sfx/death_furnace_golem.ogg",
	"death_burrower": "res://assets/audio/generated/sfx/death_burrower.ogg",
	"death_gem_leech": "res://assets/audio/generated/sfx/death_gem_leech.ogg",
	"death_lantern_wraith": "res://assets/audio/generated/sfx/death_lantern_wraith.ogg",
	"death_alchemist_pitcher": "res://assets/audio/generated/sfx/death_alchemist_pitcher.ogg",
	"death_resonance_mage": "res://assets/audio/generated/sfx/death_resonance_mage.ogg",
	"death_moon_wing": "res://assets/audio/generated/sfx/death_moon_wing.ogg",
	# 3 个新被动的触发音
	"passive_execution_mark": "res://assets/audio/generated/sfx/passive_execution_mark.ogg",
	"passive_time_gear": "res://assets/audio/generated/sfx/passive_time_gear.ogg",
	"passive_cold_blood": "res://assets/audio/generated/sfx/passive_cold_blood.ogg",
}

const BGM_PATHS: Dictionary = {
	"menu": "res://assets/audio/generated/bgm/menu.ogg",
	"battle": "res://assets/audio/generated/bgm/battle.ogg",
	"boss": "res://assets/audio/generated/bgm/boss.ogg",
	"victory": "res://assets/audio/generated/bgm/victory.ogg",
	"defeat": "res://assets/audio/generated/bgm/defeat.ogg",
	"shop": "res://assets/audio/generated/bgm/shop.ogg",
	# 每层一首：以前一整局只有一首战斗曲，玩家从头到尾听不出变化
	# （试玩反馈："背景音乐我有好几首的怎么我从头到尾只听到一首？"）。
	"floor_1": "res://assets/audio/generated/bgm/floor_1.ogg",
	"floor_2": "res://assets/audio/generated/bgm/floor_2.ogg",
	"floor_3": "res://assets/audio/generated/bgm/floor_3.ogg",
	"floor_4": "res://assets/audio/generated/bgm/floor_4.ogg",
	"floor_5": "res://assets/audio/generated/bgm/floor_5.ogg",
}

const LOOPING_BGMS: Array[String] = ["menu", "battle", "boss", "shop",
	"floor_1", "floor_2", "floor_3", "floor_4", "floor_5"]

## 地下城一共几层。楼层 BGM 的键名按这个数循环。
const FLOOR_COUNT: int = 5

# ========== 缓存 ==========
var _cached_sounds: Dictionary = {}
var _cached_bgms: Dictionary = {}

# ========== 公共接口 ==========

func get_sound(sound_name: String) -> AudioStream:
	if _cached_sounds.has(sound_name):
		return _cached_sounds[sound_name]
	if not SFX_PATHS.has(sound_name):
		push_error("Unknown SFX key: %s" % sound_name)
		return null
	var stream := _load_audio_file(SFX_PATHS[sound_name])
	# Cache missing files too: report once instead of flooding on every combat hit.
	_cached_sounds[sound_name] = stream
	return stream

func _load_audio_file(path: String, looping: bool = false) -> AudioStream:
	if not ResourceLoader.exists(path):
		push_error("Required audio asset missing: %s" % path)
		return null
	var stream := load(path) as AudioStreamOggVorbis
	if stream == null:
		push_error("Required audio asset is not valid Ogg Vorbis: %s" % path)
		return null
	stream.loop = looping
	return stream

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

func _get_cached_bgm(key: String) -> AudioStream:
	if _cached_bgms.has(key):
		return _cached_bgms[key]
	if not BGM_PATHS.has(key):
		push_error("Unknown BGM key: %s" % key)
		return null
	var stream := _load_audio_file(BGM_PATHS[key], key in LOOPING_BGMS)
	_cached_bgms[key] = stream
	return stream

func get_menu_bgm() -> AudioStream:
	return _get_cached_bgm("menu")

func get_battle_bgm() -> AudioStream:
	return _get_cached_bgm("battle")

func get_boss_bgm() -> AudioStream:
	return _get_cached_bgm("boss")

func get_victory_bgm() -> AudioStream:
	return _get_cached_bgm("victory")

func get_defeat_bgm() -> AudioStream:
	return _get_cached_bgm("defeat")

func get_shop_bgm() -> AudioStream:
	return _get_cached_bgm("shop")

## 某一层的战斗曲。楼层文件缺失时退回通用战斗曲，
## 不能因为一首歌没生成出来就让整局静音。
func get_floor_bgm(floor_index: int) -> AudioStream:
	var idx: int = clampi(floor_index, 1, FLOOR_COUNT)
	var key := "floor_%d" % idx
	if not BGM_PATHS.has(key):
		return get_battle_bgm()
	if not ResourceLoader.exists(BGM_PATHS[key]):
		return get_battle_bgm()
	var stream := _get_cached_bgm(key)
	if stream == null:
		return get_battle_bgm()
	return stream

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
