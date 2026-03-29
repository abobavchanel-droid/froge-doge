extends CharacterBody2D
## Враг: HP и преследование игрока.
## Анимации: вместо Visual/Sprite2D можно поставить AnimatedSprite2D и AnimationPlayer
## с клипами idle / hit (и при желании death до queue_free в take_damage).

@export var move_speed := 155.0
@export var max_hp := 4
@export var xp_reward := 4

var _hp: int

@onready var _visual_root: Node2D = $Visual


func _ready() -> void:
	add_to_group("enemy")
	_hp = max_hp


func _physics_process(_delta: float) -> void:
	var p: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if p:
		velocity = global_position.direction_to(p.global_position) * move_speed
	else:
		velocity = Vector2.ZERO
	move_and_slide()


func take_damage(amount: int) -> void:
	if amount <= 0:
		return
	_hp -= amount
	_hit_feedback()
	if _hp <= 0:
		_drop_xp()
		queue_free()


func _drop_xp() -> void:
	var gf := get_tree().get_first_node_in_group("game_flow")
	if gf and gf.has_method("spawn_xp_pickup"):
		gf.spawn_xp_pickup(global_position, xp_reward)


func _primary_canvas_item() -> CanvasItem:
	if _visual_root == null:
		return null
	for c in _visual_root.get_children():
		if c is CanvasItem:
			return c as CanvasItem
	return null


func _hit_feedback() -> void:
	_play_hit_animation()
	var vis := _primary_canvas_item()
	if vis == null:
		return
	var tw := create_tween()
	tw.tween_property(vis, "modulate", Color(1.0, 0.45, 0.45), 0.055)
	tw.tween_property(vis, "modulate", Color.WHITE, 0.09)


func _play_hit_animation() -> void:
	var ap := get_node_or_null("Visual/AnimationPlayer") as AnimationPlayer
	if ap and ap.has_animation(&"hit"):
		ap.play(&"hit")
