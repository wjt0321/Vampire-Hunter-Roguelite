extends Node
class_name WaveManager
## 波次管理器
## 控制敌人按波次生成，逐渐增加难度

# === 敌人场景 ===
var enemy_scenes: Dictionary = {
	"vampire": preload("res://scenes/enemies/vampire.tscn"),
	"werewolf": preload("res://scenes/enemies/werewolf.tscn"),
	"bat": preload("res://scenes/enemies/bat.tscn"),
	"zombie": preload("res://scenes/enemies/zombie.tscn"),
	"skeleton_archer": preload("res://scenes/enemies/skeleton_archer.tscn"),
	"exploder": preload("res://scenes/enemies/exploder.tscn"),
	"elite_vampire": preload("res://scenes/enemies/elite_vampire.tscn"),
}

# === 波次配置 ===
@export var wave_duration: float = 30.0         # 每波持续时间（秒）
@export var base_spawn_interval: float = 2.0    # 基础生成间隔
@export var min_spawn_interval: float = 0.3     # 最小生成间隔
@export var spawn_distance: float = 500.0       # 生成距离（屏幕外）

# === 状态 ===
var current_wave: int = 0
var wave_timer: float = 0.0
var spawn_timer: float = 0.0
var is_active: bool = false
var enemies_alive: int = 0
var total_kills: int = 0
var player: Node2D = null

# === 信号 ===
signal wave_started(wave_number: int)
signal wave_completed(wave_number: int)
signal enemy_killed(total_kills: int)

func _ready() -> void:
	pass

func start(player_node: Node2D) -> void:
	player = player_node
	is_active = true
	_start_next_wave()

func _process(delta: float) -> void:
	if not is_active or player == null:
		return
	
	wave_timer += delta
	spawn_timer += delta
	
	# 生成敌人
	var current_interval := _get_spawn_interval()
	if spawn_timer >= current_interval:
		spawn_timer = 0.0
		_spawn_enemy()
	
	# 检查波次结束
	if wave_timer >= wave_duration:
		_end_current_wave()

func _start_next_wave() -> void:
	current_wave += 1
	wave_timer = 0.0
	spawn_timer = 0.0
	wave_started.emit(current_wave)
	print("=== Wave %d 开始! ===" % current_wave)

func _end_current_wave() -> void:
	wave_completed.emit(current_wave)
	is_active = false
	print("=== Wave %d 完成! ===" % current_wave)

func _get_spawn_interval() -> float:
	# 每波生成速度加快
	var interval := base_spawn_interval - (current_wave - 1) * 0.15
	return maxf(interval, min_spawn_interval)

func _get_enemies_per_spawn() -> int:
	# 每波同时生成更多敌人
	return mini(1 + current_wave / 3, 5)

func _spawn_enemy() -> void:
	if player == null or not is_instance_valid(player):
		is_active = false
		return
	
	var count := _get_enemies_per_spawn()
	for i in range(count):
		var enemy_type := _pick_enemy_type()
		var enemy_scene: PackedScene = enemy_scenes[enemy_type]
		var enemy := enemy_scene.instantiate()
		
		# 在屏幕外随机位置生成
		enemy.global_position = _get_spawn_position()
		
		# 连接死亡信号
		enemy.enemy_died.connect(_on_enemy_died)
		
		enemies_alive += 1
		get_tree().current_scene.add_child(enemy)

func _pick_enemy_type() -> String:
	## 根据当前波次选择敌人类型（高波次解锁更强敌人）
	var available_types: Array[String] = ["vampire"]
	
	if current_wave >= 2:
		available_types.append("bat")
	if current_wave >= 3:
		available_types.append("zombie")
	if current_wave >= 4:
		available_types.append("skeleton_archer")
	if current_wave >= 5:
		available_types.append("werewolf")
	if current_wave >= 6:
		available_types.append("exploder")
	if current_wave >= 8:
		available_types.append("elite_vampire")
	
	# 每种类型权重不同
	var weights: Array[float] = []
	for type in available_types:
		match type:
			"vampire":
				weights.append(10.0)
			"bat":
				weights.append(8.0)
			"zombie":
				weights.append(5.0)
			"skeleton_archer":
				weights.append(4.0)
			"werewolf":
				weights.append(3.0)
			"exploder":
				weights.append(2.0)
			"elite_vampire":
				weights.append(1.0)
	
	# 加权随机选择
	var total_weight: float = 0.0
	for w in weights:
		total_weight += w
	
	var roll := randf() * total_weight
	var cumulative: float = 0.0
	for j in range(available_types.size()):
		cumulative += weights[j]
		if roll <= cumulative:
			return available_types[j]
	
	return available_types[0]

func _get_spawn_position() -> Vector2:
	## 在玩家周围的圆圈外随机位置生成
	var angle := randf() * TAU
	var offset := Vector2(cos(angle), sin(angle)) * spawn_distance
	return player.global_position + offset

func _on_enemy_died(enemy: Node2D) -> void:
	enemies_alive -= 1
	total_kills += 1
	enemy_killed.emit(total_kills)

func stop() -> void:
	is_active = false
