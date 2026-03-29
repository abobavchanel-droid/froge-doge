extends CanvasLayer

@onready var _resume_btn: Button = $Center/Panel/VBox/ResumeButton
@onready var _quit_btn: Button = $Center/Panel/VBox/QuitButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_resume_btn.pressed.connect(resume_game)
	_quit_btn.pressed.connect(quit_game)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	if get_tree().paused:
		resume_game()
	else:
		get_tree().paused = true
		visible = true
	get_viewport().set_input_as_handled()


func resume_game() -> void:
	get_tree().paused = false
	visible = false


func quit_game() -> void:
	get_tree().paused = false
	get_tree().quit()
