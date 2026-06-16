extends SceneTree
## 生成程序化 BGM 文件到 assets/audio/bgm/

func _init():
	var battle_bgm := AudioLib.get_battle_bgm()
	var boss_bgm := AudioLib.get_boss_bgm()
	
	_save_wav(battle_bgm, "res://assets/audio/bgm/bgm_battle.wav")
	_save_wav(boss_bgm, "res://assets/audio/bgm/bgm_boss.wav")
	
	print("✅ BGM 文件生成完成")
	quit()

func _save_wav(stream: AudioStreamWAV, path: String) -> void:
	if stream == null:
		push_error("无法生成: " + path)
		return
	
	# AudioStreamWAV 自带 save_to_wav 方法
	var err := stream.save_to_wav(path)
	if err != OK:
		push_error("保存失败 %s: %d" % [path, err])
	else:
		print("🎵 已保存: %s" % path)
