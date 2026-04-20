@abstract
class_name CostCurve
extends Resource

## Strategy base for purchase cost progression. Concrete subclasses implement
## cost_at(level) to return the price to buy the (level+1)-th unit.
## Using @abstract (Godot 4.5+) prevents accidental .new() and forces overrides.

@abstract func cost_at(level: int) -> float
