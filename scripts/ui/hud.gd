extends CanvasLayer
## 游戏内 HUD
## 显示生命值、经验条、波次信息、击杀数、游戏时间、房间编号

@onready var hp_bar: ProgressBar = $MarginContainer/VBoxContainer/TopBar/HpBar
@onready var hp_label: Label = $MarginContainer/VBoxContainer/TopBar/HpBar/HpLabel
@onready var xp_bar: ProgressBar = $MarginContainer/VBoxContainer/BottomBar/XpBar
@onready var level_label: Label = $MarginContainer/VBoxContainer/BottomBar/LevelLabel
@onready var wave_label: Label = $MarginContainer/VBoxContainer/TopBar/WaveLabel
@onready var kills_label: Label = $MarginContainer/VBoxContainer/TopBar/KillsLabel
@onready var wave_banner: Label = $WaveBanner
@onready var time_label: Label = $MarginContainer/VBoxContainer/TopBar/TimeLabel
@onready var room_label: Label = $MarginContainer/VBoxContainer/TopBar/RoomLabel

var game_time: float = 0.0

func _ready() -> void:
	wave_banner.visible = false
	_setup_bar_textures()

func _process(delta: float) -> void:
	game_time += delta
	var minutes := int(game_time) / 60
	var seconds := int(game_time) % 60
	time_label.text = "⏱ %02d:%02d" % [minutes, seconds]

func update_hp(current: float, maximum: float) -> void:
	hp_bar.max_value = maximum
	hp_bar.value = current
	hp_label.text = "%d / %d" % [int(current), int(maximum)]

func update_xp(current_xp: int, xp_needed: int, level: int) -> void:
	xp_bar.max_value = xp_needed
	xp_bar.value = current_xp
	level_label.text = "Lv.%d" % level

func update_wave(wave_number: int) -> void:
	wave_label.text = "Wave %d" % wave_number
	_show_wave_banner(wave_number)

func update_kills(total_kills: int) -> void:
	kills_label.text = "击杀: %d" % total_kills

func update_room(room_number: int) -> void:
	room_label.text = "房间 %d" % room_number

func _show_wave_banner(wave_number: int) -> void:
	wave_banner.text = "=== WAVE %d ===" % wave_number
	wave_banner.visible = true
	wave_banner.modulate = Color(1, 1, 1, 1)
	var tween := create_tween()
	tween.tween_interval(1.5)
	tween.tween_property(wave_banner, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func(): wave_banner.visible = false)

func _setup_bar_textures() -> void:
	## 设置血条和经验条的纹理
	var hp_fill_texture := TextureManager.instance.get_ui_texture("hp_bar_fill")
	var hp_bg_texture := TextureManager.instance.get_ui_texture("hp_bar_bg")
	var xp_fill_texture := TextureManager.instance.get_ui_texture("xp_bar_fill")
	var xp_bg_texture := TextureManager.instance.get_ui_texture("xp_bar_bg")
	
	if hp_fill_texture:
		var hp_style := StyleBoxTexture.new()
		hp_style.texture = hp_fill_texture
		hp_bar.add_theme_stylebox_override("fill", hp_style)
	
	if hp_bg_texture:
		var hp_bg_style := StyleBoxTexture.new()
		hp_bg_style.texture = hp_bg_texture
		hp_bar.add_theme_stylebox_override("background", hp_bg_style)
	
	if xp_fill_texture:
		var xp_style := StyleBoxTexture.new()
		xp_style.texture = xp_fill_texture
		xp_bar.add_theme_stylebox_override("fill", xp_style)
	
	if xp_bg_texture:
		var xp_bg_style := StyleBoxTexture.new()
		xp_bg_style.texture = xp_bg_texture
		xp_bar.add_theme_stylebox_override("background", xp_bg_style)
