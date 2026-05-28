extends CharacterBody2D

@export var sprite: AnimatedSprite2D

const BASE_SPEED := 350

var speed_mult := 1.0
var invuln_after_hit := 1.15
var max_lives := 15
var lives := 15
var invuln_time := 0.0

var attack_damage := 1
var attack_damage_mult := 1.0
var attack_cooldown_base := 0.5
var attack_speed_mult := 1.0
var attack_knockback_force := 210.0
var attack_knockback_mult := 1.0
var hp_regen_per_sec := 0.10
var _hp_regen_accum := 0.0

signal lives_changed(current: int, maximum: int)
signal died

@onready var _sprite: AnimatedSprite2D = $GameVisual/Sprite2D


func _ready() -> void:
	_sprite.play("idlefront")
	add_to_group("player")

	var cam: Camera2D = $Camera2D
	global_position = Vector2(
		(cam.limit_left + cam.limit_right) * 0.5,
		(cam.limit_top + cam.limit_bottom) * 0.5
	)

	$Hurtbox.body_entered.connect(_on_hurtbox_body_entered)

	collision_layer = 1
	# Стены лежат в physics layer 4 (бит 3), чтобы игрок не проходил сквозь TileMapLayer стен.
	collision_mask = 4


func _physics_process(delta: float) -> void:
	invuln_time = maxf(0.0, invuln_time - delta)
	_apply_regen(delta)

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

	# 👉 ВОТ ТУТ АНИМАЦИЯ
	_update_animation(direction)


func _apply_regen(delta: float) -> void:
	if lives <= 0 or lives >= max_lives:
		_hp_regen_accum = 0.0
		return
	_hp_regen_accum += hp_regen_per_sec * delta
	if _hp_regen_accum < 1.0:
		return
	var heal := int(floor(_hp_regen_accum))
	_hp_regen_accum -= float(heal)
	lives = mini(max_lives, lives + heal)
	lives_changed.emit(lives, max_lives)


func _update_animation(direction: Vector2) -> void:
	# СТОИМ
	if direction == Vector2.ZERO:
		_sprite.play("idlefront")
		return

	# ДВИЖЕНИЕ (всегда одна анимация)
	_sprite.play("gofront")

	# ФЛИП ТОЛЬКО ВЛЕВО/ВПРАВО
	if direction.x > 0:
		_sprite.flip_h = true   # влево
	elif direction.x < 0:
		_sprite.flip_h = false  # вправо


func take_hit(amount: int = 1) -> void:
	if invuln_time > 0.0:
		return

	lives -= maxi(1, amount)
	invuln_time = invuln_after_hit
	lives_changed.emit(lives, max_lives)

	if lives <= 0:
		died.emit()


func _on_hurtbox_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemy"):
		var dmg := 1
		if body.has_method("get_contact_damage"):
			dmg = int(body.get_contact_damage())
		take_hit(dmg)


func get_attack_cooldown() -> float:
	return attack_cooldown_base / maxf(0.12, attack_speed_mult)


func get_attack_damage() -> int:
	return maxi(1, int(round(attack_damage * attack_damage_mult)))


func get_attack_knockback_force() -> float:
	return attack_knockback_force * attack_knockback_mult


func get_hp_visual_value() -> float:
	return minf(float(max_lives), float(lives) + _hp_regen_accum)


func apply_upgrade(id: String, power_scale: float = 1.0) -> void:
	var p := maxf(1.0, power_scale)
	match id:
		"speed":
			speed_mult *= (1.10 + 0.02 * p)
		"invuln":
			invuln_after_hit += 0.28 + 0.10 * p
		"max_hp":
			max_lives += 1
			lives += 1
			lives_changed.emit(lives, max_lives)
		"heal":
			if lives < max_lives:
				lives = mini(max_lives, lives + maxi(1, int(floor(0.5 + 0.5 * p))))
				lives_changed.emit(lives, max_lives)
		"damage":
			attack_damage_mult *= (1.12 + 0.03 * p)
		"firerate":
			attack_speed_mult *= (1.10 + 0.025 * p)
		"knockback":
			attack_knockback_mult *= (1.18 + 0.04 * p)
		"regen":
			hp_regen_per_sec += 0.04 + 0.02 * p
		_:
			pass
