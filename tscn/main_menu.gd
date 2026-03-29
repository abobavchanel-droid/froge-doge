extends Control

const GAME_SCENE := "res://tscn/game.tscn"


func _on_play_pressed() -> void:
	get_tree().change_scene_to_file(GAME_SCENE)
