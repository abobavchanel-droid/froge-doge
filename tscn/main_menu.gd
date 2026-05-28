extends Control

const GAME_SCENE := "res://tscn/game.tscn"
const SAVE_PATH := "user://save_game.json"

@onready var _continue_btn: Button = $CenterContainer/VBox/Continue
@onready var _new_btn: Button = $CenterContainer/VBox/NewGame


func _ready() -> void:
	_continue_btn.disabled = not FileAccess.file_exists(SAVE_PATH)


func _on_continue_pressed() -> void:
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_new_game_pressed() -> void:
	var dir := DirAccess.open("user://")
	if dir and FileAccess.file_exists(SAVE_PATH):
		dir.remove("save_game.json")
	get_tree().change_scene_to_file(GAME_SCENE)
