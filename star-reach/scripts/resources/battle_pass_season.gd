class_name BattlePassSeasonDef
extends Resource

## Battle Pass season = ordered list of tiers. Only one active season at a time.
## Phase 6c V1 ships a single season tres; future seasons add more files and a
## "currently active season" selector.

@export var id: String = ""
@export var display_name: String = ""
@export var tiers: Array[BattlePassTier] = []
