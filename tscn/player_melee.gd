extends Node
## Ближняя атака: сектор удара на MeleePivot/MeleeHitbox.
## Полноценная анимация удара: GameVisual/AnimationPlayer (клип «attack») И/ИЛИ нож MeleePivot/.../Visual.
## Подставь свои текстуры в MeleePivot/MeleeHitbox/Visual.

@export var swing_duration := 0.11

var _cooldown_left := 0.0
var _hits_this_swing: Dictionary = {}

@onready var _player: CharacterBody2D = get_parent() as CharacterBody2D
## MeleeAttack — сосед MeleePivot, путь от родителя-player.
@onready var _pivot: Node2D = $"../MeleePivot"
@onready var _hitbox: Area2D = $"../MeleePivot/MeleeHitbox"


func _ready() -> void:
	if _hitbox:
		_hitbox.body_entered.connect(_on_hitbox_body_entered)
		_hitbox.monitoring = false


func _physics_process(delta: float) -> void:
	if _player == null or _pivot == null or _hitbox == null:
		return
	_cooldown_left -= delta
	if _cooldown_left > 0.0:
		return
	var target := _nearest_enemy()
	if target == null:
		return
	_cooldown_left = _player.get_attack_cooldown()
	_swing_at(target)


func _nearest_enemy() -> Node2D:
	var from := _player.global_position
	var best: Node2D = null
	var best_d := INF
	for n in get_tree().get_nodes_in_group("enemy"):
		if n is Node2D:
			var d := from.distance_squared_to((n as Node2D).global_position)
			if d < best_d:
				best_d = d
				best = n as Node2D
	return best


func _swing_at(target: Node2D) -> void:
	var dir := _player.global_position.direction_to(target.global_position)
	if dir.length_squared() < 0.00001:
		dir = Vector2.RIGHT
	_pivot.rotation = dir.angle()
	_hits_this_swing.clear()
	_hitbox.monitoring = true
	_play_attack_vfx()
	get_tree().create_timer(swing_duration).timeout.connect(_end_swing)


func _end_swing() -> void:
	if _hitbox:
		_hitbox.monitoring = false
	_hits_this_swing.clear()


func _on_hitbox_body_entered(body: Node2D) -> void:
	if _hitbox == null or not _hitbox.monitoring:
		return
	if not body.is_in_group("enemy"):
		return
	if _hits_this_swing.has(body):
		return
	_hits_this_swing[body] = true
	if body.has_method(&"take_damage"):
		body.take_damage(_player.get_attack_damage())


func _play_attack_vfx() -> void:
	var gv := _player.get_node_or_null("GameVisual")
	if gv:
		var ap := gv.get_node_or_null("AnimationPlayer") as AnimationPlayer
		if ap and ap.has_animation(&"attack"):
			ap.play(&"attack")
	var kv := _hitbox.get_node_or_null("Visual") as Node2D
	if kv:
		var ap2 := kv.get_node_or_null("AnimationPlayer") as AnimationPlayer
		if ap2 and ap2.has_animation(&"slash"):
			ap2.play(&"slash")
