extends Node

## Headless Phase 4b signal-flow check. Proves that
## DiscoveryService + BadgeService advance GameState meta fields when
## `destination_completed` fires with `is_first_clear=true`, and do NOT
## advance when `is_first_clear=false`.
##
## Run as a scene so project autoloads register:
##   godot --path star-reach --headless res://scripts/tests/smoke_phase4b_meta.tscn

var _failures: int = 0

func _ready() -> void:
	print("== Phase 4b meta signal-flow smoke ==")
	await _run()
	if _failures > 0:
		printerr("FAILED: %d issue(s)" % _failures)
		get_tree().quit(1)
	else:
		print("PASSED")
		get_tree().quit(0)

func _run() -> void:
	# Clean slate: simulate a "New Game".
	GameState.completed_destinations = []
	GameState.discovered_codex_entries = []
	GameState.codex_entry_progress = {}
	GameState.badges_earned = []
	GameState.total_wins = 0

	# Services are normally children of MainScreen. Spin up siblings here.
	var discovery: DiscoveryService = DiscoveryService.new()
	var badge: BadgeService = BadgeService.new()
	add_child(discovery)
	add_child(badge)
	await get_tree().process_frame  # let service _ready run

	# --- Case 1: first clear → Codex + region Badge advance.
	GameState.total_wins = 1
	EventBus.destination_completed.emit("D_001", {
		"credit_gain": 5, "tech_level_gain": 3, "tier": 1,
		"stages_cleared": 3, "session_xp_earned": 30,
		"is_first_clear": true,
	})
	EventBus.launch_completed.emit("D_001")
	await get_tree().process_frame

	_expect(GameState.discovered_codex_entries.has("REGION_EARTH_OVERVIEW"),
		"Codex unlocks REGION_EARTH_OVERVIEW on first D_001 clear")
	_expect(GameState.badges_earned.has("BADGE_REGION_EARTH"),
		"Badge awards BADGE_REGION_EARTH on first D_001 clear")

	# --- Case 2: repeat clear (is_first_clear=false) must NOT advance.
	var codex_before: int = GameState.discovered_codex_entries.size()
	var badge_before: int = GameState.badges_earned.size()
	EventBus.destination_completed.emit("D_001", {"credit_gain": 5, "is_first_clear": false})
	await get_tree().process_frame
	_expect(GameState.discovered_codex_entries.size() == codex_before,
		"Codex does NOT advance on repeat clear")
	_expect(GameState.badges_earned.size() == badge_before,
		"Region badge does NOT re-award on repeat clear")

	# --- Case 3: data-load sanity.
	_expect(discovery.get_total_entries() > 0, "Discovery loaded 0 entries — data missing?")
	_expect(badge.get_total_badges() > 0, "Badge loaded 0 defs — data missing?")
	print("  totals: codex=%d badges=%d" % [discovery.get_total_entries(), badge.get_total_badges()])

func _expect(cond: bool, msg: String) -> void:
	if cond:
		print("  ok: %s" % msg)
	else:
		_failures += 1
		printerr("  FAIL: %s" % msg)
