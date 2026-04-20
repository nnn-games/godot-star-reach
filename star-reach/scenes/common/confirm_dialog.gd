extends Control

## Reusable modal confirmation dialog.
## Usage:
##   var dlg := preload("res://scenes/common/confirm_dialog.tscn").instantiate()
##   modal_layer.add_child(dlg)
##   dlg.setup("Prestige?", "Current progress will reset.")
##   var ok: bool = await dlg.closed
##   dlg.queue_free()
##   if ok: ...

signal closed(confirmed: bool)

@onready var _title: Label = %Title
@onready var _message: Label = %Message
@onready var _confirm_button: Button = %ConfirmButton
@onready var _cancel_button: Button = %CancelButton

func _ready() -> void:
	_confirm_button.pressed.connect(_on_confirm)
	_cancel_button.pressed.connect(_on_cancel)

func setup(title: String, message: String, confirm_text: String = "Confirm", cancel_text: String = "Cancel") -> void:
	_title.text = title
	_message.text = message
	_confirm_button.text = confirm_text
	_cancel_button.text = cancel_text

func _on_confirm() -> void:
	closed.emit(true)

func _on_cancel() -> void:
	closed.emit(false)
