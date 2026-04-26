class_name LaunchBalanceConfig
extends Resource

## Probability balance for the launch loop. Holds 5 TierSegment entries (T1~T5).
## Single source of truth referenced by LaunchService — no hardcoded chances elsewhere.
## Authored as data/launch_balance_config.tres; designers tune via Inspector.

@export var tier_segments: Array[TierSegment] = []

## Resolve the segment that owns the given stage index (1-based).
## Returns null if no segment covers the stage (config error).
func segment_for_stage(stage_index: int) -> TierSegment:
	for seg in tier_segments:
		if stage_index >= seg.stage_min and stage_index <= seg.stage_max:
			return seg
	return null

## Resolve the segment for a Tier number (1~5).
func segment_for_tier(tier: int) -> TierSegment:
	for seg in tier_segments:
		if seg.tier == tier:
			return seg
	return null
