extends Control

## Shop panel. Iterates IAPService catalog and shows a Buy button per product.
## Uses Mock backend during development — real platform backends hook in the
## same way once plugins are active.

const ROW_SCENE: PackedScene = preload("res://scenes/game/panels/shop_row.tscn")

@onready var _list: VBoxContainer = %List
@onready var _status_label: Label = %StatusLabel

func _ready() -> void:
	_render_status()
	IAPService.ready_state_changed.connect(func(_r): _render_status())
	for product in IAPService.get_all_products():
		var row: Node = ROW_SCENE.instantiate()
		_list.add_child(row)
		row.bind(product)

func _render_status() -> void:
	var backend_name: String = IAPService._backend.get_class() if IAPService._backend != null else "None"
	var ready_str: String = "ready" if IAPService.is_ready() else "not ready"
	_status_label.text = "Backend: %s  •  %s  •  OS: %s" % [backend_name, ready_str, OS.get_name()]
