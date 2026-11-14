extends Node
## 手柄焦点开关。全项目按钮默认 FOCUS_NONE（Space 是开火键，聚焦会被 ui_accept 误触）。
## 检测到手柄活动才临时给可见按钮开焦点并抓第一个；键鼠活动立即恢复 FOCUS_NONE。
## 面板在手柄模式下新打开时，按方向键发现没有焦点主人就补抓第一个可见按钮。

var _pad_mode := false
var _first: Button = null

func _ready() -> void:
	# 升级/暂停面板会暂停整棵树；焦点开关必须在暂停时也收得到手柄事件。
	process_mode = Node.PROCESS_MODE_ALWAYS

func _input(event: InputEvent) -> void:
	var pad := event is InputEventJoypadButton or event is InputEventJoypadMotion
	if pad:
		if not _pad_mode:
			_pad_mode = true
			_apply(true)
		if get_viewport().gui_get_focus_owner() == null:
			_grab_first()
	elif _pad_mode and (event is InputEventKey or event is InputEventMouse):
		_pad_mode = false
		_apply(false)

func _apply(enable: bool) -> void:
	_first = null
	_walk(get_tree().root, enable)
	if enable:
		_grab_first()
	else:
		get_viewport().gui_release_focus()

func _walk(node: Node, enable: bool) -> void:
	for child in node.get_children():
		if child is Button and child.is_visible_in_tree():
			child.focus_mode = Control.FOCUS_ALL if enable else Control.FOCUS_NONE
			if enable and _first == null:
				_first = child
		_walk(child, enable)

func _grab_first() -> void:
	if _first != null and is_instance_valid(_first) and _first.is_visible_in_tree():
		_first.grab_focus()
		return
	_first = null
	_walk(get_tree().root, true)
	if _first != null:
		_first.grab_focus()