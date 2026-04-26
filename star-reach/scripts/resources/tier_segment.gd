class_name TierSegment
extends Resource

## Probability segment for one Tier. See docs/launch_balance_design.md §2.1.
## A LaunchBalanceConfig holds 5 of these (T1~T5).

@export var tier: int = 1
@export var stage_min: int = 1
@export var stage_max: int = 4
@export_range(0.0, 1.0) var base_chance: float = 0.5
@export_range(0.0, 1.0) var max_chance: float = 0.85
