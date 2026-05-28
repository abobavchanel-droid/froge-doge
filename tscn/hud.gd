extends CanvasLayer

@onready var _lives_bar: ProgressBar = %LivesBar
@onready var _xp_bar: ProgressBar = %XPBar
@onready var _xp_label: Label = %XPLabel
@onready var _wave_label: Label = %WaveLabel
@onready var _timer_label: Label = %TimerLabel

var _lives_value_label: Label
var _xp_value_label: Label


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

	_lives_bar.show_percentage = false
	_xp_bar.show_percentage = false
	_lives_value_label = _make_bar_value_label(_lives_bar)
	_xp_value_label = _make_bar_value_label(_xp_bar)


func set_lives(current: int, maximum: int) -> void:
	_lives_bar.max_value = maximum
	_lives_bar.value = current
	if _lives_value_label:
		_lives_value_label.text = "%d / %d" % [current, maximum]


func set_xp(current: int, need: int, level: int) -> void:
	_xp_bar.max_value = maxi(1, need)
	_xp_bar.value = clampi(current, 0, need)
	if _xp_value_label:
		_xp_value_label.text = "%d / %d" % [current, need]
	_xp_label.text = "Ур. %d   %d / %d XP" % [level, current, need]


func set_wave_info(wave_num: int, seconds_left: float) -> void:
	_wave_label.text = "Волна %d" % wave_num
	_timer_label.text = "%d с" % maxi(0, int(ceil(seconds_left)))


func _make_bar_value_label(bar: ProgressBar) -> Label:
	var lbl := Label.new()
	lbl.anchors_preset = Control.PRESET_FULL_RECT
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 13)
	bar.add_child(lbl)
	return lbl
