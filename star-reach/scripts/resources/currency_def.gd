class_name CurrencyDef
extends Resource

## Defines a currency: identifier, display properties. Balances live in GameState.

@export var id: StringName
@export var display_name: String
@export var icon: Texture2D
@export var initial_amount: float = 0.0
