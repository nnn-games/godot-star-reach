extends Control

const GAME_SCENE_PATH: String = "res://scenes/game/game.tscn"

@onready var _play_button: Button = %PlayButton
@onready var _quit_button: Button = %QuitButton

func _ready() -> void:
	_play_button.pressed.connect(_on_play_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file(GAME_SCENE_PATH)

func _on_quit_pressed() -> void:
	get_tree().quit()
