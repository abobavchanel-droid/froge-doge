extends CharacterBody2D
## Враг: HP и преследование игрока.
## Анимации: вместо Visual/Sprite2D можно поставить AnimatedSprite2D и AnimationPlayer
## с клипами idle / hit (и при желании death до queue_free в take_damage).

@export var move_speed := 30
@export var max_hp := 4
@export var xp_reward := 4
@export var knockback_decay := 900.0
@export var contact_damage := 1
@export var separation_distance := 10.0
@export var separation_strength := 620.0

var _hp: int
var _knockback_velocity := Vector2.ZERO

@onready var _visual_root: Node2D = $Visual


func _ready() -> void:
	add_to_group("enemy")
	_hp = max_hp


func _physics_process(delta: float) -> void:
	var p: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	var chase_velocity := Vector2.ZERO
	if p:
		chase_velocity = global_position.direction_to(p.global_position) * move_speed
	var separation_velocity := _calc_separation_velocity()
	_knockback_velocity = _knockback_velocity.move_toward(Vector2.ZERO, knockback_decay * delta)
	velocity = chase_velocity + separation_velocity + _knockback_velocity
	move_and_slide()


func take_damage(amount: int, hit_dir: Vector2 = Vector2.ZERO, knockback_force: float = 0.0) -> void:
	if amount <= 0:
		return
	if hit_dir.length_squared() > 0.00001 and knockback_force > 0.0:
		_knockback_velocity += hit_dir.normalized() * knockback_force
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


func get_contact_damage() -> int:
	return maxi(1, contact_damage)


func _calc_separation_velocity() -> Vector2:
	var push := Vector2.ZERO
	for n in get_tree().get_nodes_in_group("enemy"):
		if n == self or not (n is Node2D):
			continue
		var other := n as Node2D
		var to_self := other.global_position.direction_to(global_position)
		var dist := global_position.distance_to(other.global_position)
		if dist <= 0.0001 or dist >= separation_distance:
			continue
		var overlap_ratio := (separation_distance - dist) / separation_distance
		push += to_self * overlap_ratio
	if push.length_squared() <= 0.0001:
		return Vector2.ZERO
	return push.normalized() * separation_strength
