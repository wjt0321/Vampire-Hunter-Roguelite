extends Area2D
## 毒雾区域
## 对范围内的敌人造成持续伤害

@export var base_damage: float = 5.0
@export var tick_interval: float = 0.5
@export var duration: float = 5.0
var damage_multiplier: float = 1.0

var _timer: float = 0.0
var _tick_timer: float = 0.0
var _enemies_in_cloud: Array = []

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	# 创建毒雾视觉效果
	if sprite and sprite.texture == null:
		var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.2, 0.8, 0.2, 0.5))
		sprite.texture = ImageTexture.create_from_image(img)
	
	# 连接信号
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _physics_process(delta: float) -> void:
	_timer += delta
	_tick_timer += delta
	
	# 定时造成伤害
	if _tick_timer >= tick_interval:
		_tick_timer = 0.0
		_deal_damage_to_enemies()
	
	# 持续时间结束后消失
	if _timer >= duration:
		_fade_out()

func _deal_damage_to_enemies() -> void:
	for enemy in _enemies_in_cloud:
		if is_instance_valid(enemy) and enemy.has_method("take_damage"):
			enemy.take_damage(base_damage * damage_multiplier)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemies") and not _enemies_in_cloud.has(body):
		_enemies_in_cloud.append(body)

func _on_body_exited(body: Node2D) -> void:
	if _enemies_in_cloud.has(body):
		_enemies_in_cloud.erase(body)

func _fade_out() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)

func set_size(scale_factor: float) -> void:
	scale = Vector2(scale_factor, scale_factor)
