class_name CodexEntry
extends Resource

## A single Discovery / Codex entry. Phase 4 minimal: id, display, summary,
## and the destination_ids whose first-clear contributes to this entry's
## progress. Sections / fact tiers (docs/celestial_codex_design_plan.md §6)
## arrive in Phase 5 alongside the codex panel UI.

@export var id: String = ""                       ## "BODY_MARS"
@export var display_name: String = ""             ## tr() key handled at UI layer
@export var summary: String = ""                  ## one-paragraph description
@export var destination_ids: Array[String] = []   ## ["D_021", "D_022", ...]
