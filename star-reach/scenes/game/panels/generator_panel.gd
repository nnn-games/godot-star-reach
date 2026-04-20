extends Control

## Iterates GameState.generator_defs and instantiates one GeneratorRow per def.
## No per-generator logic here — Row subscribes to EventBus itself.

const ROW_SCENE: PackedScene = preload("res://scenes/game/generator_row.tscn")

@onready var _list: VBoxContainer = %List

func _ready() -> void:
	for def in GameState.generator_defs:
		var row: Node = ROW_SCENE.instantiate()
		_list.add_child(row)
		row.bind(def)
