class_name SkyProfile
extends Resource

## Visual atmosphere for one Region/Zone. Phase 3 placeholder uses sky_color only;
## Phase 5 will add background texture layers, star density, particle preset, BGM.
## See docs/systems/4-2-sky-transition.md.

@export var profile_id: String = ""        ## "zone_01_earth"
@export var region_id: String = ""         ## "REGION_EARTH" — matches Destination.region_id
@export var sky_color: Color = Color(0.7, 0.85, 1.0)
