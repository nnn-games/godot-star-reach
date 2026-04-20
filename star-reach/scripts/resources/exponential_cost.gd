class_name ExponentialCost
extends CostCurve

## Standard idle-game cost curve: base * growth^level.
## At level 0: cost = base. At level N: cost = base * growth^N.

@export var base: float = 10.0
@export var growth: float = 1.15

func cost_at(level: int) -> float:
	return base * pow(growth, level)
