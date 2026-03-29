extends Node2D

## Область травы совпадает с region фона (ширина × высота).
const MAP := Rect2(0, 0, 4800, 2700)
## Минимальное расстояние между центрами кустов (чем больше — реже трава).
const MIN_SEPARATION := 50.0
## Попыток найти соседа для каждой активной точки (алгоритм Бридсона).
const POISSON_K := 30

@onready var _trava1: PackedScene = preload("res://tscn/trava_1.tscn")
@onready var _trava2: PackedScene = preload("res://tscn/trava_2.tscn")


func _ready() -> void:
	var points: Array[Vector2] = _poisson_disk(MAP, MIN_SEPARATION, POISSON_K)
	for p in points:
		var scene: PackedScene = _trava1 if randf() < 0.5 else _trava2
		var inst: Node2D = scene.instantiate()
		inst.position = p
		add_child(inst)


func _poisson_disk(rect: Rect2, r: float, k: int) -> Array[Vector2]:
	var cell: float = r / sqrt(2.0)
	var gw: int = maxi(1, int(ceil(rect.size.x / cell)))
	var gh: int = maxi(1, int(ceil(rect.size.y / cell)))
	var grid: PackedInt32Array = PackedInt32Array()
	grid.resize(gw * gh)
	grid.fill(-1)

	var samples: Array[Vector2] = []
	var active: Array[Vector2] = []

	var first := Vector2(
		randf_range(rect.position.x, rect.end.x),
		randf_range(rect.position.y, rect.end.y)
	)
	samples.append(first)
	active.append(first)
	grid[_poisson_cell_index(first, rect, cell, gw, gh)] = 0

	var rng := RandomNumberGenerator.new()
	rng.randomize()

	while active.size() > 0:
		var ai: int = rng.randi_range(0, active.size() - 1)
		var pt: Vector2 = active[ai]
		var added: bool = false
		for _t in k:
			var ang: float = rng.randf() * TAU
			var dist: float = rng.randf_range(r, 2.0 * r)
			var np: Vector2 = pt + Vector2.from_angle(ang) * dist
			if not rect.has_point(np):
				continue
			if not _poisson_valid(np, samples, grid, rect, cell, gw, gh, r):
				continue
			var si: int = samples.size()
			samples.append(np)
			grid[_poisson_cell_index(np, rect, cell, gw, gh)] = si
			active.append(np)
			added = true
		if not added:
			active.remove_at(ai)

	return samples


func _poisson_cell_index(p: Vector2, rect: Rect2, cell: float, gw: int, gh: int) -> int:
	var gx: int = clampi(int((p.x - rect.position.x) / cell), 0, gw - 1)
	var gy: int = clampi(int((p.y - rect.position.y) / cell), 0, gh - 1)
	return gy * gw + gx


func _poisson_valid(
	p: Vector2,
	samples: Array[Vector2],
	grid: PackedInt32Array,
	rect: Rect2,
	cell: float,
	gw: int,
	gh: int,
	r: float
) -> bool:
	var gx0: int = int((p.x - rect.position.x) / cell)
	var gy0: int = int((p.y - rect.position.y) / cell)
	for oy in range(-2, 3):
		for ox in range(-2, 3):
			var gx: int = gx0 + ox
			var gy: int = gy0 + oy
			if gx < 0 or gy < 0 or gx >= gw or gy >= gh:
				continue
			var j: int = grid[gy * gw + gx]
			if j != -1 and samples[j].distance_to(p) < r:
				return false
	return true
