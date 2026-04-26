class_name Destination
extends Resource

## A single launch destination. See docs/destination_config.md / docs/contents.md.
## 100 of these are authored as data/destinations/d_001.tres ~ d_100.tres.

@export var id: String = ""                          ## "D_001"
@export var display_name: String = ""                ## tr() key handled at UI layer
@export var tier: int = 1                            ## Probability segment to use (1~5)
@export var region_id: String = ""                   ## "REGION_EARTH" — for mastery / first-arrival badge
@export var required_stages: int = 3                 ## N independent probability checks
@export var reward_credit: int = 0
@export var reward_tech_level: int = 0
@export var required_tech_level: int = 0             ## Gate: cannot select if GameState.tech_level < this
