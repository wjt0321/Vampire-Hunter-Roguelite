extends CanvasLayer
## Boss 血条 UI
## 多段血条显示在屏幕顶部

@onready var container: PanelContainer = $PanelContainer
@onready var hp_bar: ProgressBar = $PanelContainer/VBoxContainer/HPBar
@onready var name_label: Label = $PanelContainer/VBoxContainer/NameLabel
@onready var phase_label: Label = $PanelContainer/VBoxContainer/PhaseLabel

func _ready() -> void:
	visible = false

func show_boss_bar(boss_name: String) -> void:
	visible = true
	name_label.text = "👑 " + boss_name
	phase_label.text = "Phase 1"
	hp_bar.value = 100.0
	# 入场动画
	container.modulate = Color(1, 1, 1, 0)
	var tween := create_tween()
	tween.tween_property(container, "modulate:a", 1.0, 0.5)

func update_hp(current: float, max_val: float) -> void:
	hp_bar.value = (current / max_val) * 100.0

func update_phase(phase: int) -> void:
	if phase == 1:
		phase_label.text = "💀 狂暴模式!"
		phase_label.modulate = Color(1.0, 0.3, 0.3, 1.0)
		# 血条颜色变红
		hp_bar.modulate = Color(1.5, 0.5, 0.5, 1.0)

func hide_boss_bar() -> void:
	var tween := create_tween()
	tween.tween_property(container, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func(): visible = false)
