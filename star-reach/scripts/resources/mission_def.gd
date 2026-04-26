class_name MissionDef
extends Resource

## A single daily mission. Pool of these is rolled once per day (3 picked).
## Phase 4 condition_id values that MissionService tracks automatically:
##   - "launches"           total launches in current day
##   - "successes"          destinations completed in current day
##   - "stage_streak"       longest consecutive stage-success run in current day
##   - "play_minutes"       seconds_played / 60
##   - "auto_launch_minutes" seconds with auto-launch on / 60
##   - "new_destinations"   first-clears of new destinations in current day
##   - "facility_upgrade"   facility-upgrade purchases (Phase 5+ only)

@export var id: String = ""                       ## "DM_LAUNCH_20"
@export var display_name: String = ""
@export var condition_id: StringName = &""        ## see header for valid values
@export var target: int = 1
@export var reward_tech_level: int = 10
