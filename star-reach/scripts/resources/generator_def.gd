class_name GeneratorDef
extends Resource

## Definition of a generator (idle-game producer). Purely static balancing data.
## Runtime state (current level, produced-so-far) lives in GameState keyed by id.

@export var id: StringName
@export var display_name: String
@export var description: String
@export var icon: Texture2D
@export var currency_id: StringName = &"coin"    # which currency it produces
@export var base_rate: float = 1.0                # per-level production per second
@export var cost_curve: CostCurve                 # Strategy: cost progression
@export var cost_currency_id: StringName = &"coin"  # which currency you pay with
