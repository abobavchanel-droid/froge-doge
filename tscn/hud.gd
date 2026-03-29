extends CanvasLayer

@onready var _lives_bar: ProgressBar = %LivesBar
@onready var _xp_bar: ProgressBar = %XPBar
@onready var _xp_label: Label = %XPLabel
@onready var _wave_label: Label = %WaveLabel
@onready var _timer_label: Label = %TimerLabel


func _ready() -> void:
	var life_bg := StyleBoxFlat.new()
	life_bg.bg_color = Color(0.18, 0.08, 0.08)
	var life_fill := StyleBoxFlat.new()
	life_fill.bg_color = Color(0.92, 0.2, 0.16)
	_lives_bar.add_theme_stylebox_override("background", life_bg)
	_lives_bar.add_theme_stylebox_override("fill", life_fill)

	var xp_bg := StyleBoxFlat.new()
	xp_bg.bg_color = Color(0.06, 0.12, 0.08)
	var xp_fill := StyleBoxFlat.new()
	xp_fill.bg_color = Color(0.35, 0.85, 0.38)
	_xp_bar.add_theme_stylebox_override("background", xp_bg)
	_xp_bar.add_theme_stylebox_override("fill", xp_fill)


func set_lives(current: int, maximum: int) -> void:
	_lives_bar.max_value = maximum
	_lives_bar.value = current


func set_xp(current: int, need: int, level: int) -> void:
	_xp_bar.max_value = maxi(1, need)
	_xp_bar.value = clampi(current, 0, need)
	_xp_label.text = "Ур. %d   %d / %d XP" % [level, current, need]


func set_wave_info(wave_num: int, seconds_left: float) -> void:
	_wave_label.text = "Волна %d" % wave_num
	_timer_label.text = "%d с" % maxi(0, int(ceil(seconds_left)))
