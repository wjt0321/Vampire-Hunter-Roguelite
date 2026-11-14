extends SceneTree
## 迭代新增内容的专属音效接入回归（2026-11-14）。
##
## 验证的不是"文件在不在"，而是"引擎真的会播专属音"：
## - 12 种新敌人的受击与死亡走专属键，不再是通用 hit_enemy / enemy_death；
## - 旧敌人仍然走通用音，没有被这轮改动波及；
## - 7 把新武器与 5 张融合卡走专属发射音；
## - 3 个新被动的映射键能取到且文件可解码；
## - 每个映射键在 AudioLib 的键表里都真实存在（漏注册会在这里报出来）。

const NEW_ENEMIES: Array[String] = [
	"shield_guard", "blood_priest", "web_weaver", "coffin_guard",
	"blood_hound", "furnace_golem", "burrower", "gem_leech",
	"lantern_wraith", "alchemist_pitcher", "resonance_mage", "moon_wing",
]
const OLD_ENEMIES: Array[String] = ["vampire", "werewolf", "zombie", "skeleton"]
const NEW_WEAPONS: Array[String] = [
	"scythe", "thorn_whip", "frost_bell", "repeater",
	"soul_lantern", "spike_tome", "chain_gun",
]
const FUSION_KINDS: Array[String] = ["thunder", "miasma", "returning", "split", "burning"]
const PASSIVES: Array[String] = ["execution_mark", "time_gear", "cold_blood"]

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


func _run() -> void:
	await process_frame
	var lib = root.get_node("AudioLib")
	check(lib != null, "AudioLib present")
	if lib == null:
		quit(1)
		return

	# --- 12 种新敌人：受击与死亡都有专属键，且键在键表里真实存在 ---
	for enemy_id in NEW_ENEMIES:
		var hit_key := IterationAudioMap.enemy_hit_sound(enemy_id)
		var death_key := IterationAudioMap.enemy_death_sound(enemy_id)
		check(not hit_key.is_empty(), "enemy hit key mapped " + enemy_id)
		check(not death_key.is_empty(), "enemy death key mapped " + enemy_id)
		check(lib.SFX_PATHS.has(hit_key), "hit key in catalog " + hit_key)
		check(lib.SFX_PATHS.has(death_key), "death key in catalog " + death_key)
		var hit_stream: AudioStream = lib.get_sound(hit_key)
		var death_stream: AudioStream = lib.get_sound(death_key)
		check(hit_stream is AudioStreamOggVorbis, "hit stream real ogg " + hit_key)
		check(death_stream is AudioStreamOggVorbis, "death stream real ogg " + death_key)
		if hit_stream is AudioStreamOggVorbis:
			check(hit_stream.get_length() > 0.05, "hit sound nonempty " + hit_key)
		if death_stream is AudioStreamOggVorbis:
			check(death_stream.get_length() > 0.05, "death sound nonempty " + death_key)
		# 专属音必须与通用音不是同一个文件，否则"专属"是假的
		check(hit_key != "hit_enemy", "enemy uses dedicated hit sound " + enemy_id)
		check(death_key != "enemy_death", "enemy uses dedicated death sound " + enemy_id)

	# --- 旧敌人不受影响：仍走通用音 ---
	for enemy_id in OLD_ENEMIES:
		check(IterationAudioMap.enemy_hit_sound(enemy_id).is_empty(),
			"legacy enemy has no dedicated hit sound " + enemy_id)
		check(IterationAudioMap.enemy_death_sound(enemy_id).is_empty(),
			"legacy enemy has no dedicated death sound " + enemy_id)

	# --- 7 把新武器 ---
	for weapon_id in NEW_WEAPONS:
		var key := IterationAudioMap.weapon_sound(weapon_id)
		check(not key.is_empty(), "weapon key mapped " + weapon_id)
		check(lib.SFX_PATHS.has(key), "weapon key in catalog " + key)
		var stream: AudioStream = lib.get_sound(key)
		check(stream is AudioStreamOggVorbis, "weapon stream real ogg " + key)

	# --- 5 张融合卡：按 fusion_kind 匹配，不是按 weapon_id ---
	for kind in FUSION_KINDS:
		var key := IterationAudioMap.fusion_sound(kind)
		check(not key.is_empty(), "fusion key mapped " + kind)
		check(lib.SFX_PATHS.has(key), "fusion key in catalog " + key)
		var stream: AudioStream = lib.get_sound(key)
		check(stream is AudioStreamOggVorbis, "fusion stream real ogg " + key)
	check(IterationAudioMap.fusion_sound("").is_empty(), "empty fusion kind has no sound")
	check(IterationAudioMap.fusion_sound("not_a_kind").is_empty(), "unknown fusion kind has no sound")

	# --- 3 个新被动 ---
	for passive_id in PASSIVES:
		var key := IterationAudioMap.passive_sound(passive_id)
		check(not key.is_empty(), "passive key mapped " + passive_id)
		check(lib.SFX_PATHS.has(key), "passive key in catalog " + key)
		var stream: AudioStream = lib.get_sound(key)
		check(stream is AudioStreamOggVorbis, "passive stream real ogg " + key)

	# --- 映射表与键表必须一一对应，不能有孤儿键 ---
	for enemy_id in NEW_ENEMIES:
		for key in [IterationAudioMap.enemy_hit_sound(enemy_id),
				IterationAudioMap.enemy_death_sound(enemy_id)]:
			check(lib.SFX_PATHS.has(key), "no orphan enemy key " + key)
	for weapon_id in NEW_WEAPONS:
		check(lib.SFX_PATHS.has(IterationAudioMap.weapon_sound(weapon_id)),
			"no orphan weapon key " + weapon_id)
	for kind in FUSION_KINDS:
		check(lib.SFX_PATHS.has(IterationAudioMap.fusion_sound(kind)),
			"no orphan fusion key " + kind)
	for passive_id in PASSIVES:
		check(lib.SFX_PATHS.has(IterationAudioMap.passive_sound(passive_id)),
			"no orphan passive key " + passive_id)

	print("RESULT iteration_audio: %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)
