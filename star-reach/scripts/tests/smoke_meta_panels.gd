extends Node

## Phase 5e meta-panel data smoke. Panels themselves are PopupPanel (Window)
## subclasses that hang in headless mode, so we verify the services they read
## from instead — the rendering is checked manually on F5.

var _failures: int = 0

func _ready() -> void:
	print("== Phase 5e meta panel data smoke ==")
	_run()
	if _failures > 0:
		printerr("FAILED: %d issue(s)" % _failures)
		get_tree().quit(1)
	else:
		print("PASSED")
		get_tree().quit(0)

func _run() -> void:
	# Clean state, matching what "New Game" + a fresh boot produces.
	GameState.completed_destinations = []
	GameState.discovered_codex_entries = []
	GameState.codex_entry_progress = {}
	GameState.badges_earned = []
	GameState.daily_mission = {}

	var discovery: DiscoveryService = DiscoveryService.new()
	var badge: BadgeService = BadgeService.new()
	var mission: MissionService = MissionService.new()
	add_child(discovery)
	add_child(badge)
	add_child(mission)

	# DiscoveryService.get_entries() drives the CodexPanel list.
	var entries: Array[CodexEntry] = discovery.get_entries()
	_expect(entries.size() == discovery.get_total_entries(),
		"discovery.get_entries() matches total count (%d)" % entries.size())
	_expect(entries.size() > 0, "at least one codex entry loaded from data/codex/")

	# BadgeService.get_all_badges() drives the BadgePanel list.
	var badges: Array[BadgeDef] = badge.get_all_badges()
	_expect(badges.size() == badge.get_total_badges(),
		"badge.get_all_badges() matches total count (%d)" % badges.size())
	var region_first_count: int = 0
	var win_count: int = 0
	for b in badges:
		match b.badge_type:
			"region_first": region_first_count += 1
			"win_count": win_count += 1
	_expect(region_first_count > 0 and win_count > 0,
		"both badge_type families are present (region_first=%d win_count=%d)" % [region_first_count, win_count])

	# MissionService rolls today's missions during _ready.
	_expect(mission.get_total_today() > 0,
		"mission.get_today_missions() populated after boot (today=%d)" % mission.get_total_today())
	for m in mission.get_today_missions():
		var def: MissionDef = mission.get_definition(StringName(m.get("id", "")))
		_expect(def != null,
			"get_definition resolves for today's mission id=%s" % String(m.get("id", "?")))

	# Simulate a first clear and confirm the codex panel's denominator-level
	# counters will advance (the panel reads these getters each open).
	EventBus.destination_completed.emit("D_001", {
		"credit_gain": 5, "tech_level_gain": 3, "tier": 1,
		"stages_cleared": 3, "session_xp_earned": 30,
		"is_first_clear": true,
	})
	# Signals are sync — state is updated by the time emit returns.
	_expect(discovery.get_unlocked_count() == 1,
		"codex unlocked count after first D_001 clear = 1 (got %d)" % discovery.get_unlocked_count())
	_expect(badge.get_earned_count() == 1,
		"badge earned count after first D_001 clear = 1 (got %d)" % badge.get_earned_count())

func _expect(cond: bool, msg: String) -> void:
	if cond:
		print("  ok: %s" % msg)
	else:
		_failures += 1
		printerr("  FAIL: %s" % msg)
