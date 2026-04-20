extends Control

## Root of the in-game screen. Lives for the entire play session — panels switch
## via TabContainer (visibility only), never via scene changes.
## Modals are instantiated into %ModalLayer and awaited via their `closed` signal.

const MAIN_MENU_PATH: String = "res://scenes/main_menu/main_menu.tscn"
const CONFIRM_DIALOG: PackedScene = preload("res://scenes/common/confirm_dialog.tscn")

@onready var _back_button: Button = %BackButton
@onready var _modal_layer: CanvasLayer = %ModalLayer

func _ready() -> void:
	_back_button.pressed.connect(_on_back_pressed)

func _on_back_pressed() -> void:
	var dlg: Node = CONFIRM_DIALOG.instantiate()
	_modal_layer.add_child(dlg)
	dlg.setup("Exit to menu?", "Your progress will be saved automatically.")
	var ok: bool = await dlg.closed
	dlg.queue_free()
	if ok:
		get_tree().change_scene_to_file(MAIN_MENU_PATH)
