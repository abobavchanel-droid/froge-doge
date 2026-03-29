extends CharacterBody2D

@export var sprite: AnimatedSprite2D

## Тело: GameVisual (Sprite2D или AnimatedSprite2D) + опционально GameVisual/AnimationPlayer.
## Ближний бой: узел MeleeAttack (player_melee.gd) и MeleePivot/MeleeHitbox/Visual — нож и анимация «slash».

const BASE_SPEED := 350.0

var speed_mult := 1.0
var invuln_after_hit := 1.15
var max_lives := 2
var lives := 2
var invuln_time := 0.0

var attack_damage := 1
var attack_damage_mult := 1.0
var attack_cooldown_base := 0.5
var attack_speed_mult := 1.0

signal lives_changed(current: int, maximum: int)
signal died

@onready var _sprite: AnimatedSprite2D = $GameVisual/Sprite2D


func _ready() -> void:
	sprite.play("idlefront")
	add_to_group("player")
	var cam: Camera2D = $Camera2D
	global_position = Vector2(
		(cam.limit_left + cam.limit_right) * 0.5,
		(cam.limit_top + cam.limit_bottom) * 0.5
	)
	$Hurtbox.body_entered.connect(_on_hurtbox_body_entered)
	collision_layer = 1
	collision_mask = 0


func get_attack_cooldown() -> float:
	return attack_cooldown_base / maxf(0.12, attack_speed_mult)


func get_attack_damage() -> int:
	return maxi(1, int(round(attack_damage * attack_damage_mult)))


func _physics_process(delta: float) -> void:
	invuln_time = maxf(0.0, invuln_time - delta)
	if invuln_time > 0.0:
		_sprite.modulate.a = 0.42 + 0.38 * sin(float(Time.get_ticks_msec()) / 70.0)
	else:
		_sprite.modulate.a = 1.0
	var direction := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	)
	if direction.length_squared() > 0.0:
		direction = direction.normalized()
	velocity = direction * BASE_SPEED * speed_mult
	move_and_slide()


func take_hit() -> void:
	if invuln_time > 0.0:
		return
	lives -= 1
	invuln_time = invuln_after_hit
	lives_changed.emit(lives, max_lives)
	if lives <= 0:
		died.emit()


func _on_hurtbox_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemy"):
		take_hit()


func apply_upgrade(id: String) -> void:
	match id:
		"speed":
			speed_mult *= 1.12
		"invuln":
			invuln_after_hit += 0.4
		"max_hp":
			max_lives += 1
			lives += 1
			lives_changed.emit(lives, max_lives)
		"heal":
			if lives < max_lives:
				lives += 1
				lives_changed.emit(lives, max_lives)
		"damage":
			attack_damage_mult *= 1.14
		"firerate":
			attack_speed_mult *= 1.12
		_:
			pass
