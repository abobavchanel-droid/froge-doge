extends Node2D

const ENEMY_SCENE := preload("res://tscn/enemy.tscn")
const XP_PICKUP_SCENE := preload("res://tscn/xp_pickup.tscn")

@onready var player: CharacterBody2D = $back/player
@onready var enemies_cont: Node2D = $back/EnemiesWorld
@onready var pickups_cont: Node2D = $back/Pickups
@onready var hud: CanvasLayer = $HUD
@onready var upgrade_ui: CanvasLayer = $UpgradeUI
@onready var game_over_layer: CanvasLayer = $GameOverLayer

var wave := 1
var wave_seconds_left := 0.0
## "wave" | "shop"
var phase := "wave"

var _spawn_accum := 0.0
var spawn_interval_mult := 1.0
var enemy_slow_mult := 1.0

## Опыт (Brotato-стиль: шкала обнуляется, порог растёт).
var xp := 0
var xp_needed := 10
var xp_level := 1
## Сколько апов шкалы XP случилось за текущую волну → столько выборов усилений после волны.
var level_ups_this_wave := 0

var _upgrade_picks_left := 0
var _pick_round_total := 0
var _current_pick_index := 1


func _ready() -> void:
	add_to_group("game_flow")
	randomize()
	player.lives_changed.connect(hud.set_lives)
	player.died.connect(_on_player_died)
	upgrade_ui.upgrade_chosen.connect(_on_upgrade_chosen)
	hud.set_lives(player.lives, player.max_lives)
	hud.set_xp(xp, xp_needed, xp_level)
	hud.set_wave_info(wave, wave_seconds_left)
	_start_wave()


func add_xp(amount: int) -> void:
	if amount <= 0 or phase != "wave":
		return
	xp += amount
	while xp >= xp_needed:
		xp -= xp_needed
		xp_level += 1
		level_ups_this_wave += 1
		xp_needed = int(xp_needed * 1.22) + 4
	hud.set_xp(xp, xp_needed, xp_level)


func spawn_xp_pickup(at: Vector2, amount: int) -> void:
	var p := XP_PICKUP_SCENE.instantiate()
	p.configure(amount)
	p.global_position = at
	pickups_cont.add_child(p)


func _process(delta: float) -> void:
	if phase != "wave" or get_tree().paused:
		return
	wave_seconds_left -= delta
	hud.set_wave_info(wave, wave_seconds_left)
	_spawn_accum += delta
	if _spawn_accum >= _current_spawn_interval():
		_spawn_accum = 0.0
		_spawn_enemy()
	if wave_seconds_left <= 0.0:
		_finish_wave()


func _current_spawn_interval() -> float:
	return maxf(0.65, 2.35 - (wave - 1) * 0.11) * spawn_interval_mult


func _start_wave() -> void:
	phase = "wave"
	wave_seconds_left = 22.0 + wave * 8.0
	_spawn_accum = 0.0
	hud.set_wave_info(wave, wave_seconds_left)


func _finish_wave() -> void:
	phase = "shop"
	get_tree().paused = true
	for c in enemies_cont.get_children():
		c.queue_free()
	for c in pickups_cont.get_children():
		c.queue_free()
	_spawn_accum = 0.0
	_upgrade_picks_left = level_ups_this_wave
	level_ups_this_wave = 0
	_pick_round_total = maxi(1, _upgrade_picks_left)
	_current_pick_index = 1
	if _upgrade_picks_left > 0:
		_open_next_upgrade_panel()
	else:
		_end_shop_phase()


func _open_next_upgrade_panel() -> void:
	upgrade_ui.show_random_choices(_current_pick_index, _pick_round_total)


func _on_upgrade_chosen(id: String) -> void:
	if id == "spawn_slow":
		spawn_interval_mult *= 1.15
	elif id == "enemy_slow":
		enemy_slow_mult *= 0.92
	else:
		player.apply_upgrade(id)
	_upgrade_picks_left -= 1
	_current_pick_index += 1
	if _upgrade_picks_left > 0:
		_open_next_upgrade_panel()
	else:
		_end_shop_phase()


func _end_shop_phase() -> void:
	get_tree().paused = false
	wave += 1
	_start_wave()


func _spawn_enemy() -> void:
	var e: CharacterBody2D = ENEMY_SCENE.instantiate() as CharacterBody2D
	var ang := randf() * TAU
	var dist := randf_range(420.0, 800.0)
	var pos: Vector2 = player.global_position + Vector2.from_angle(ang) * dist
	pos.x = clampf(pos.x, 120.0, 4680.0)
	pos.y = clampf(pos.y, 120.0, 2580.0)
	e.global_position = pos
	e.move_speed = 128.0 * (1.0 + (wave - 1) * 0.065) * enemy_slow_mult
	e.max_hp = 3 + wave * 2
	e.xp_reward = 3 + wave * 2
	enemies_cont.add_child(e)


func _on_player_died() -> void:
	get_tree().paused = true
	game_over_layer.visible = true
