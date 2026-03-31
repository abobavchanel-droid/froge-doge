extends Area2D

@export var sprite: AnimatedSprite2D

## Кристалл опыта: свои спрайт/AnimatedSprite2D под Visual — замени в сцене.

@export var magnet_range := 320.0
@export var magnet_accel := 1400.0
@export var magnet_speed_max := 920.0

var _amount: int = 1
var _magnet_speed: float = 0.0


func configure(amount: int) -> void:
	_amount = maxi(1, amount)


func _ready() -> void:
	sprite.play("overflowing")
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	var pl := get_tree().get_first_node_in_group("player") as Node2D
	if pl == null:
		return
	var d := global_position.distance_to(pl.global_position)
	if d < magnet_range:
		_magnet_speed = minf(_magnet_speed + magnet_accel * delta, magnet_speed_max)
		global_position += global_position.direction_to(pl.global_position) * _magnet_speed * delta


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	var gf := get_tree().get_first_node_in_group("game_flow")
	if gf and gf.has_method("add_xp"):
		gf.add_xp(_amount)
	queue_free()
