extends CanvasLayer
## 成就解锁通知UI
## 在屏幕角落显示成就解锁提示

@onready var panel: PanelContainer = $PanelContainer
@onready var icon_label: Label = $PanelContainer/MarginContainer/HBoxContainer/IconLabel
@onready var name_label: Label = $PanelContainer/MarginContainer/HBoxContainer/VBoxContainer/NameLabel
@onready var desc_label: Label = $PanelContainer/MarginContainer/HBoxContainer/VBoxContainer/DescLabel

var notification_queue: Array[Dictionary] = []
var is_showing: bool = false

func _ready() -> void:
	panel.visible = false
	panel.position = Vector2(-400, 20)  # 初始位置在屏幕外
	
	# 连接成就管理器信号
	var ach_mgr = get_node_or_null("/root/AchievementManager")
	if ach_mgr:
		ach_mgr.achievement_unlocked.connect(_on_achievement_unlocked)

func _on_achievement_unlocked(achievement_id: String, achievement_name: String) -> void:
	var ach_mgr = get_node_or_null("/root/AchievementManager")
	if not ach_mgr:
		return
	
	var info: Dictionary = ach_mgr.get_achievement_info(achievement_id)
	notification_queue.append({
		"id": achievement_id,
		"name": achievement_name,
		"icon": info.get("icon", "🏆"),
		"description": info.get("description", ""),
	})
	
	if not is_showing:
		_show_next_notification()

func _show_next_notification() -> void:
	if notification_queue.is_empty():
		is_showing = false
		return
	
	is_showing = true
	var notification: Dictionary = notification_queue.pop_front()
	
	# 设置内容
	icon_label.text = notification["icon"]
	name_label.text = "成就解锁: %s" % notification["name"]
	desc_label.text = notification["description"]
	
	panel.visible = true
	
	# 滑入动画
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(panel, "position:x", 20.0, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	
	# 等待显示时间
	tween.tween_interval(3.0)
	
	# 滑出动画
	tween.tween_property(panel, "position:x", -400.0, 0.3).set_ease(Tween.EASE_IN)
	
	await tween.finished
	
	# 显示下一个
	_show_next_notification()
