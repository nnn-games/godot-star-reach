class_name TierStressParams
extends Resource

## Per-tier stress parameters. See docs/systems/1-4-stress-abort.md §5.2.
## T1 and T2 have no entries (stress system inactive below T3).

@export var tier: int = 3
@export var stress_per_fail: float = 10.0
@export_range(0.0, 1.0) var abort_chance: float = 0.4
@export var repair_cost: int = 300
