class_name StressConfig
extends Resource

## Stress system configuration. Holds TierStressParams for each tier that has
## the risk layer active (T3~T5). T1/T2 return null and the system no-ops.
## See docs/systems/1-4-stress-abort.md.

@export var tier_params: Array[TierStressParams] = []

## Returns the params for the given tier, or null if stress is inactive there.
func for_tier(tier: int) -> TierStressParams:
	for p in tier_params:
		if p.tier == tier:
			return p
	return null
