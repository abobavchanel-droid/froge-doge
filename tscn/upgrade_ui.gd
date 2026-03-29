extends CanvasLayer

signal upgrade_chosen(upgrade_id: String)

@onready var _title: Label = %UpTitle
@onready var _b1: Button = %UpgradeButton1
@onready var _b2: Button = %UpgradeButton2
@onready var _b3: Button = %UpgradeButton3


const POOL := [
	{"id": "speed", "title": "Скорость +12%"},
	{"id": "damage", "title": "Урон +14%"},
	{"id": "firerate", "title": "Скорость атаки +12%"},
	{"id": "invuln", "title": "Неуязвимость после удара +0.4 с"},
	{"id": "max_hp", "title": "Максимум жизней +1 (и +1 сейчас)"},
	{"id": "heal", "title": "Восстановить 1 жизнь"},
	{"id": "spawn_slow", "title": "Враги появляются реже (волны)"},
	{"id": "enemy_slow", "title": "Враги медленнее на 8%"},
]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_b1.pressed.connect(_pick.bind(_b1))
	_b2.pressed.connect(_pick.bind(_b2))
	_b3.pressed.connect(_pick.bind(_b3))


func show_random_choices(pick_index: int = 1, pick_total: int = 1) -> void:
	var pi := maxi(1, pick_index)
	var pt := maxi(1, pick_total)
	_title.text = "Усиление (%d из %d)" % [pi, pt]

	var opts: Array = []
	var pool_copy: Array = POOL.duplicate()
	pool_copy.shuffle()
	for i in mini(3, pool_copy.size()):
		opts.append(pool_copy[i])
	while opts.size() < 3:
		opts.append(POOL[0])
	_b1.text = opts[0]["title"]
	_b1.set_meta("upgrade_id", opts[0]["id"])
	_b2.text = opts[1]["title"]
	_b2.set_meta("upgrade_id", opts[1]["id"])
	_b3.text = opts[2]["title"]
	_b3.set_meta("upgrade_id", opts[2]["id"])
	visible = true


func hide_ui() -> void:
	visible = false


func _pick(which: Button) -> void:
	var id: String = which.get_meta("upgrade_id", "")
	upgrade_chosen.emit(id)
	hide_ui()
