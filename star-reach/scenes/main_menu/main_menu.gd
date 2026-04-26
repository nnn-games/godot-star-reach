extends Control

## Top-level menu. Three actions:
##   - Play: continue from save
##   - New Game: confirm → SaveSystem.reset() → enter game from a clean slate
##   - Quit: get_tree().quit()
## "New Game" is the QA-friendly path for verifying first-clear / first-region
## triggers (Codex unlock, region badge, milestone modal) without manually
## deleting user://savegame.json.

const GAME_SCENE_PATH: String = "res://scenes/main/main_screen.tscn"
const SETTINGS_PANEL_SCENE: PackedScene = preload("res://scenes/ui/settings_panel.tscn")

@onready var _play_button: Button = %PlayButton
@onready var _new_game_button: Button = %NewGameButton
@onready var _settings_button: Button = %SettingsButton
@onready var _quit_button: Button = %QuitButton
@onready var _confirm_dialog: ConfirmationDialog = %ConfirmDialog

func _ready() -> void:
	_play_button.pressed.connect(_on_play_pressed)
	_new_game_button.pressed.connect(_on_new_game_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	_confirm_dialog.confirmed.connect(_on_new_game_confirmed)
	_apply_translations()

## ConfirmationDialog.dialog_text / title / button_text aren't auto-translated by
## Godot, so we re-apply them whenever the locale changes.
func _apply_translations() -> void:
	_confirm_dialog.title = tr("CONFIRM_NEW_GAME_TITLE")
	_confirm_dialog.dialog_text = tr("CONFIRM_NEW_GAME_BODY")
	_confirm_dialog.ok_button_text = tr("CONFIRM_NEW_GAME_OK")
	_confirm_dialog.cancel_button_text = tr("BTN_CANCEL")

func _notification(what: int) -> void:
	# NOTIFICATION_TRANSLATION_CHANGED can arrive before _ready() — before @onready
	# vars are resolved — when the engine flushes a pending locale change as the
	# scene enters the tree. Skip until the node is ready; _ready() calls
	# _apply_translations() itself for the initial pass.
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_apply_translations()

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file(GAME_SCENE_PATH)

## Show the confirmation modal. Actual reset happens on `confirmed`.
func _on_new_game_pressed() -> void:
	_confirm_dialog.popup_centered(Vector2i(520, 240))

func _on_new_game_confirmed() -> void:
	SaveSystem.reset()
	get_tree().change_scene_to_file(GAME_SCENE_PATH)

func _on_settings_pressed() -> void:
	var panel: SettingsPanel = SETTINGS_PANEL_SCENE.instantiate()
	add_child(panel)
	panel.popup_centered(panel.size)

func _on_quit_pressed() -> void:
	get_tree().quit()
