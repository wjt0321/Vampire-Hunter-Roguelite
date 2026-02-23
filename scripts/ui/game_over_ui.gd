extends CanvasLayer
## 游戏结束界面
## 显示本局统计信息和血晶奖励

signal restart_requested
signal menu_requested

@onready var stats_label: Label = $CenterContainer/PanelContainer/VBoxContainer/StatsLabel
@onready var achievement_label: Label = $CenterContainer/PanelContainer/VBoxContainer/AchievementLabel
@onready var panel: PanelContainer = $CenterContainer/PanelContainer

var save_mgr: Node
var achievement_mgr: Node

func _ready() -> void:
	visible = false
	save_mgr = get_node_or_null("/root/SaveManager")
	achievement_mgr = get_node_or_null("/root/AchievementManager")

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
	
	# 显示本局解锁的成就
	_update_achievement_display()
	
	panel.modulate = Color(1, 1, 1, 0)
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(panel, "modulate:a", 1.0, 0.3)

func _update_achievement_display() -> void:
	if not achievement_mgr:
		achievement_label.text = ""
		return
	
	var unlocked: Array[String] = achievement_mgr.get_unlocked_this_run()
	if unlocked.is_empty():
		achievement_label.text = ""
		return
	
	var text := "\n🏆 本局解锁成就:\n"
	for ach_id in unlocked:
		var info: Dictionary = achievement_mgr.get_achievement_info(ach_id)
		text += "  %s %s\n" % [info.get("icon", "🏆"), info.get("name", ach_id)]
	
	achievement_label.text = text

func _on_restart_pressed() -> void:
	get_tree().paused = false
	restart_requested.emit()

func _on_menu_pressed() -> void:
	get_tree().paused = false
	menu_requested.emit()
