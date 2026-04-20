extends Control

## Subscribes to EventBus.currency_changed for a single currency id and renders it.
## Drop this into any scene; no parent coordination needed.

@export var currency_id: StringName = &"coin"
@export var label_prefix: String = ""

@onready var _label: Label = %Label

func _ready() -> void:
	EventBus.currency_changed.connect(_on_currency_changed)
	_render(GameState.get_currency(currency_id))

func _on_currency_changed(id: StringName, amount: float) -> void:
	if id == currency_id:
		_render(amount)

func _render(amount: float) -> void:
	_label.text = "%s%d" % [label_prefix, int(amount)]
