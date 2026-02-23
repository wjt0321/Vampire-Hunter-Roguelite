extends CanvasLayer
## 暂停菜单
## ESC 键暂停游戏

@onready var panel: PanelContainer = $CenterContainer/PanelContainer

signal resume_requested
signal menu_requested

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if visible:
			_resume()
		else:
			_pause()

func _pause() -> void:
	visible = true
	get_tree().paused = true
	panel.modulate = Color(1, 1, 1, 0)
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(panel, "modulate:a", 1.0, 0.2)

func _resume() -> void:
	get_tree().paused = false
	visible = false
	resume_requested.emit()

func _on_resume_pressed() -> void:
	_resume()

func _on_menu_pressed() -> void:
	get_tree().paused = false
	visible = false
	menu_requested.emit()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
