extends CanvasLayer
## 游戏结束界面
## 显示本局统计信息和血晶奖励

signal restart_requested
signal menu_requested

@onready var stats_label: Label = $CenterContainer/PanelContainer/VBoxContainer/StatsLabel
@onready var panel: PanelContainer = $CenterContainer/PanelContainer

var save_mgr: Node

func _ready() -> void:
	visible = false
	save_mgr = get_node_or_null("/root/SaveManager")

func show_game_over(stats: Dictionary) -> void:
	visible = true
	get_tree().paused = true
	
	var crystals: int = 0
	if save_mgr:
		crystals = save_mgr.end_run(stats)
	
	var text := "☠ 游戏结束 ☠\n\n"
	text += "探索房间: %d\n" % stats.get("rooms", 0)
	text += "存活波次: %d\n" % stats.get("wave", 0)
	text += "击杀数: %d\n" % stats.get("kills", 0)
	text += "达到等级: %d\n" % stats.get("level", 1)
	if save_mgr:
		text += "\n💎 获得血晶: +%d\n" % crystals
		text += "💎 总血晶: %d" % save_mgr.get_blood_crystals()
	stats_label.text = text
	
	panel.modulate = Color(1, 1, 1, 0)
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(panel, "modulate:a", 1.0, 0.3)

func _on_restart_pressed() -> void:
	get_tree().paused = false
	restart_requested.emit()

func _on_menu_pressed() -> void:
	get_tree().paused = false
	menu_requested.emit()
