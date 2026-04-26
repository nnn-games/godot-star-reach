class_name BadgeDef
extends Resource

## A single Badge / Achievement. Phase 4 supports two earn rules:
##   - "region_first": first destination cleared whose region_id matches `region_id`
##   - "win_count":    GameState.total_wins reaches `threshold`
## Phase 6 hooks `achievement_id` into Steam / GPG / Game Center via PlatformService.

@export var id: String = ""                       ## "BADGE_REGION_FIRST_EARTH"
@export var display_name: String = ""
@export_enum("region_first", "win_count") var badge_type: String = "region_first"
@export var region_id: String = ""                ## used when badge_type == "region_first"
@export var threshold: int = 0                    ## used when badge_type == "win_count"
@export var achievement_id: String = ""           ## external mapping for Phase 6
