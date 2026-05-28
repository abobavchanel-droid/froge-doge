extends Node2D

const ENEMY_SCENE := preload("res://tscn/enemy.tscn")
const XP_PICKUP_SCENE := preload("res://tscn/xp_pickup.tscn")
const SAVE_PATH := "user://save_game.json"

@onready var player: CharacterBody2D = $back/player
@onready var enemies_cont: Node2D = $back/EnemiesWorld
@onready var pickups_cont: Node2D = $back/Pickups
@onready var wall_layer: TileMapLayer = $"background-wall"
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
var _spawn_rect := Rect2(120.0, 120.0, 4560.0, 2460.0)
var _min_spawn_distance := 280.0
var _autosave_accum := 0.0


func _ready() -> void:
	add_to_group("game_flow")
	randomize()
	_rebuild_spawn_rect()
	player.lives_changed.connect(hud.set_lives)
	player.died.connect(_on_player_died)
	upgrade_ui.upgrade_chosen.connect(_on_upgrade_chosen)
	hud.set_lives(player.lives, player.max_lives)
	hud.set_xp(xp, xp_needed, xp_level)
	hud.set_wave_info(wave, wave_seconds_left)
	hud.set_hp_regen(player.hp_regen_per_sec)
	var loaded: bool = _load_progress()
	if loaded:
		phase = "wave"
		wave_seconds_left = maxf(1.0, wave_seconds_left)
	else:
		_start_wave()


func add_xp(amount: int) -> void:
	if amount <= 0 or phase != "wave":
		return
	xp += amount
	while xp >= xp_needed:
		xp -= xp_needed
		xp_level += 1
		level_ups_this_wave += 1
		xp_needed = _next_xp_needed(xp_level, xp_needed)
	hud.set_xp(xp, xp_needed, xp_level)


func spawn_xp_pickup(at: Vector2, amount: int) -> void:
	var p := XP_PICKUP_SCENE.instantiate()
	p.configure(amount)
	p.global_position = at
	pickups_cont.add_child(p)


func _process(delta: float) -> void:
	if player and hud:
		hud.set_hp_regen_preview(player.get_hp_visual_value(), player.max_lives)

	_autosave_accum += delta
	if _autosave_accum >= 2.0:
		_autosave_accum = 0.0
		_save_progress()

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
	_save_progress()
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
	var upg_power := _upgrade_power_scale()
	if id == "spawn_slow":
		spawn_interval_mult *= (1.12 + 0.03 * upg_power)
	elif id == "enemy_slow":
		enemy_slow_mult *= (0.93 - 0.02 * minf(1.0, (upg_power - 1.0) / 3.0))
	else:
		player.apply_upgrade(id, upg_power)
	hud.set_hp_regen(player.hp_regen_per_sec)
	_upgrade_picks_left -= 1
	_current_pick_index += 1
	if _upgrade_picks_left > 0:
		_open_next_upgrade_panel()
	else:
		_end_shop_phase()


func _end_shop_phase() -> void:
	get_tree().paused = false
	wave += 1
	_save_progress()
	_start_wave()


func _spawn_enemy() -> void:
	var count := _spawn_count_per_tick()
	for _i in range(count):
		var e := ENEMY_SCENE.instantiate()
		var pos := _find_enemy_spawn_position()
		e.global_position = pos
		e.move_speed = _enemy_speed_for_wave()
		e.max_hp = _enemy_hp_for_wave()
		e.xp_reward = _enemy_xp_reward_for_wave()
		e.contact_damage = _enemy_damage_for_wave()
		enemies_cont.add_child(e)


func _on_player_died() -> void:
	_clear_progress()
	get_tree().paused = true
	game_over_layer.visible = true


func _rebuild_spawn_rect() -> void:
	if wall_layer == null or wall_layer.tile_set == null:
		return
	var used: Rect2i = wall_layer.get_used_rect()
	if used.size.x <= 2 or used.size.y <= 2:
		return
	var tile_size: Vector2i = wall_layer.tile_set.tile_size
	var inner_origin := wall_layer.to_global(Vector2((used.position.x + 1) * tile_size.x, (used.position.y + 1) * tile_size.y))
	var inner_size := Vector2((used.size.x - 2) * tile_size.x, (used.size.y - 2) * tile_size.y)
	_spawn_rect = Rect2(inner_origin, inner_size)


func _is_wall_at_world(pos: Vector2) -> bool:
	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var q := PhysicsPointQueryParameters2D.new()
	q.position = pos
	q.collision_mask = 4
	q.collide_with_areas = false
	q.collide_with_bodies = true
	var hits: Array = space_state.intersect_point(q, 8)
	return hits.size() > 0


func _is_valid_enemy_spawn(pos: Vector2, check_player_distance: bool = true) -> bool:
	if not _spawn_rect.has_point(pos):
		return false
	if _is_wall_at_world(pos):
		return false
	if check_player_distance and player and pos.distance_to(player.global_position) < _min_spawn_distance:
		return false
	return true


func _find_enemy_spawn_position() -> Vector2:
	# Равномерный случайный спавн по всему полю внутри стен.
	for _i in range(120):
		var rnd := Vector2(
			randf_range(_spawn_rect.position.x, _spawn_rect.end.x),
			randf_range(_spawn_rect.position.y, _spawn_rect.end.y)
		)
		if _is_valid_enemy_spawn(rnd):
			return rnd
	# Экстренный вариант: если не нашли с дистанцией до игрока, спавним в любом валидном месте поля.
	for _k in range(72):
		var safe_rnd := Vector2(
			randf_range(_spawn_rect.position.x, _spawn_rect.end.x),
			randf_range(_spawn_rect.position.y, _spawn_rect.end.y)
		)
		if _is_valid_enemy_spawn(safe_rnd, false):
			return safe_rnd
	return Vector2(
		randf_range(_spawn_rect.position.x, _spawn_rect.end.x),
		randf_range(_spawn_rect.position.y, _spawn_rect.end.y)
	)


func _save_progress() -> void:
	if player == null:
		return
	var data: Dictionary = {
		"wave": wave,
		"xp": xp,
		"xp_needed": xp_needed,
		"xp_level": xp_level,
		"level_ups_this_wave": level_ups_this_wave,
		"spawn_interval_mult": spawn_interval_mult,
		"enemy_slow_mult": enemy_slow_mult,
		"phase": phase,
		"wave_seconds_left": wave_seconds_left,
		"player_position": [player.global_position.x, player.global_position.y],
		"player_lives": player.lives,
		"player_max_lives": player.max_lives,
		"player_speed_mult": player.speed_mult,
		"player_invuln_after_hit": player.invuln_after_hit,
		"player_attack_damage_mult": player.attack_damage_mult,
		"player_attack_speed_mult": player.attack_speed_mult,
		"player_attack_knockback_mult": player.attack_knockback_mult,
		"player_hp_regen_per_sec": player.hp_regen_per_sec
	}
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))


func _load_progress() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return false
	var raw: String = file.get_as_text()
	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	var data: Dictionary = parsed

	wave = int(data.get("wave", wave))
	xp = int(data.get("xp", xp))
	xp_needed = int(data.get("xp_needed", xp_needed))
	xp_level = int(data.get("xp_level", xp_level))
	level_ups_this_wave = int(data.get("level_ups_this_wave", 0))
	spawn_interval_mult = float(data.get("spawn_interval_mult", spawn_interval_mult))
	enemy_slow_mult = float(data.get("enemy_slow_mult", enemy_slow_mult))
	phase = String(data.get("phase", phase))
	wave_seconds_left = float(data.get("wave_seconds_left", 0.0))

	var arr: Variant = data.get("player_position", [player.global_position.x, player.global_position.y])
	if arr is Array and arr.size() >= 2:
		var p := Vector2(float(arr[0]), float(arr[1]))
		if _spawn_rect.has_point(p) and not _is_wall_at_world(p):
			player.global_position = p

	player.max_lives = int(data.get("player_max_lives", player.max_lives))
	player.lives = clampi(int(data.get("player_lives", player.lives)), 1, player.max_lives)
	player.speed_mult = float(data.get("player_speed_mult", player.speed_mult))
	player.invuln_after_hit = float(data.get("player_invuln_after_hit", player.invuln_after_hit))
	player.attack_damage_mult = float(data.get("player_attack_damage_mult", player.attack_damage_mult))
	player.attack_speed_mult = float(data.get("player_attack_speed_mult", player.attack_speed_mult))
	player.attack_knockback_mult = float(data.get("player_attack_knockback_mult", player.attack_knockback_mult))
	player.hp_regen_per_sec = float(data.get("player_hp_regen_per_sec", player.hp_regen_per_sec))
	hud.set_lives(player.lives, player.max_lives)
	hud.set_xp(xp, xp_needed, xp_level)
	hud.set_wave_info(wave, wave_seconds_left)
	hud.set_hp_regen(player.hp_regen_per_sec)
	return true


func _clear_progress() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var dir: DirAccess = DirAccess.open("user://")
	if dir:
		dir.remove("save_game.json")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_progress()


func _next_xp_needed(level: int, prev_need: int) -> int:
	# Чуть более щадящая прогрессия: стабильнее выбиваются 2-3 апгрейда за волну.
	var growth := 1.11 + minf(0.14, float(level) * 0.005)
	var flat_add := 3 + int(level / 3)
	return maxi(prev_need + 2, int(round(prev_need * growth)) + flat_add)


func _upgrade_power_scale() -> float:
	# Чем выше уровень, тем сильнее каждый апгрейд.
	return 1.0 + float(maxi(0, xp_level - 1)) * 0.05


func _spawn_count_per_tick() -> int:
	# Рост плотности врагов с волнами, но чуть мягче.
	return 1 + int((wave - 1) / 5)


func _enemy_hp_for_wave() -> int:
	return 4 + int(pow(float(wave), 1.22) * 1.8)


func _enemy_speed_for_wave() -> float:
	return (112.0 + float(wave - 1) * 7.4) * enemy_slow_mult


func _enemy_damage_for_wave() -> int:
	return 1 + int((wave - 1) / 6)


func _enemy_xp_reward_for_wave() -> int:
	return 3 + int((wave - 1) * 1.35)
