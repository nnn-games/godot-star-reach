@tool
extends SceneTree

## Headless smoke test. Runs with:
##   godot --path star-reach --headless --script res://tools/smoke_test.gd
## Exits with non-zero code on any failure so CI can detect it.
##
## KNOWN LIMIT: --script mode does not load Autoload singletons. Scripts that
## reference EventBus / GameState / TimeManager will log "Identifier not found"
## compile errors during _check_scenes. Those are false alarms here — scenes
## still load and instantiate fine, and the real autoload-connected flow is
## verified by booting the game briefly:
##   godot --path star-reach --headless --quit-after 3
## That run triggers all autoload _ready() methods. No errors there = all good.

const SCENES: PackedStringArray = [
	"res://scenes/splash/splash.tscn",
	"res://scenes/main_menu/main_menu.tscn",
	"res://scenes/main/main_screen.tscn",
	"res://scenes/main/sky_layer.tscn",
	"res://scenes/ui/launch_result_modal.tscn",
	"res://scenes/ui/abort_screen.tscn",
	"res://scenes/ui/flash_overlay.tscn",
	"res://scenes/ui/offline_summary_modal.tscn",
]

const SCRIPTS: PackedStringArray = [
	"res://scripts/autoload/event_bus.gd",
	"res://scripts/autoload/game_state.gd",
	"res://scripts/autoload/time_manager.gd",
	"res://scripts/autoload/iap_service.gd",
	"res://scripts/autoload/save_system.gd",
	"res://scripts/services/launch_service.gd",
	"res://scripts/services/stress_service.gd",
	"res://scripts/services/sky_profile_applier.gd",
	"res://scripts/services/auto_launch_service.gd",
	"res://scripts/services/offline_progress_service.gd",
	"res://scripts/services/discovery_service.gd",
	"res://scripts/services/badge_service.gd",
	"res://scripts/services/mission_service.gd",
	"res://scripts/util/screen_shake.gd",
	"res://scripts/resources/iap_product.gd",
	"res://scripts/resources/launch_balance_config.gd",
	"res://scripts/resources/tier_segment.gd",
	"res://scripts/resources/destination.gd",
	"res://scripts/resources/stress_config.gd",
	"res://scripts/resources/tier_stress_params.gd",
	"res://scripts/resources/sky_profile.gd",
	"res://scripts/resources/codex_entry.gd",
	"res://scripts/resources/badge_def.gd",
	"res://scripts/resources/mission_def.gd",
	"res://scripts/iap/iap_backend.gd",
	"res://scripts/iap/mock_backend.gd",
	"res://scripts/iap/android_backend.gd",
	"res://scripts/iap/ios_backend.gd",
	"res://scripts/iap/steam_backend.gd",
]

const RESOURCES: PackedStringArray = [
	"res://data/launch_balance_config.tres",
	"res://data/stress_config.tres",
	"res://data/destinations/d_001.tres",
	"res://data/destinations/d_050.tres",
	"res://data/destinations/d_100.tres",
	"res://data/sky_profiles/zone_01_earth.tres",
	"res://data/sky_profiles/zone_05_jovian.tres",
	"res://data/sky_profiles/zone_11_deep_space.tres",
	"res://data/codex/body_mars.tres",
	"res://data/codex/body_jupiter.tres",
	"res://data/badges/badge_region_earth.tres",
	"res://data/badges/badge_wins_100.tres",
	"res://data/missions/dm_launch_20.tres",
]

var _failures: int = 0

func _init() -> void:
	print("== StarReach smoke test ==")
	_check_scripts()
	_check_resources()
	_check_scenes()
	_check_domain_logic()
	if _failures > 0:
		printerr("FAILED: %d issue(s)" % _failures)
		quit(1)
	else:
		print("OK: %d scenes + %d scripts + %d resources" % [SCENES.size(), SCRIPTS.size(), RESOURCES.size()])
		quit(0)

func _check_scripts() -> void:
	for path in SCRIPTS:
		var s: Script = load(path) as Script
		if s == null:
			_fail("Script load failed: %s" % path)
		else:
			print("  script   ok: %s" % path)

func _check_resources() -> void:
	for path in RESOURCES:
		var r: Resource = load(path)
		if r == null:
			_fail("Resource load failed: %s" % path)
		else:
			print("  resource ok: %s" % path)

func _check_scenes() -> void:
	for path in SCENES:
		var ps: PackedScene = load(path) as PackedScene
		if ps == null:
			_fail("Scene load failed: %s" % path)
			continue
		var inst: Node = ps.instantiate()
		if inst == null:
			_fail("Scene instantiate failed: %s" % path)
			continue
		inst.queue_free()
		print("  scene    ok: %s" % path)

## Phase 0~1 domain check.
func _check_domain_logic() -> void:
	# 1) LaunchBalanceConfig — 5 tiers, T1=50/85, T5=22/60.
	var lbc: LaunchBalanceConfig = load("res://data/launch_balance_config.tres") as LaunchBalanceConfig
	if lbc == null:
		_fail("LaunchBalanceConfig cast failed")
		return
	if lbc.tier_segments.size() != 5:
		_fail("expected 5 tier segments, got %d" % lbc.tier_segments.size())
		return
	var t1: TierSegment = lbc.segment_for_tier(1)
	if t1 == null or not is_equal_approx(t1.base_chance, 0.5) or not is_equal_approx(t1.max_chance, 0.85):
		_fail("T1 segment values wrong")
	var t5: TierSegment = lbc.segment_for_tier(5)
	if t5 == null or not is_equal_approx(t5.max_chance, 0.6):
		_fail("T5 max_chance expected 0.60")
	# 2) Destination — D_001 is the entry point with tier=1, required_stages=3.
	var d1: Destination = load("res://data/destinations/d_001.tres") as Destination
	if d1 == null:
		_fail("D_001 cast to Destination failed")
		return
	if d1.id != "D_001" or d1.tier != 1 or d1.required_stages != 3 or d1.required_tech_level != 0:
		_fail("D_001 fields wrong: id=%s tier=%d stages=%d req_tech=%d" % [d1.id, d1.tier, d1.required_stages, d1.required_tech_level])
	# 3) StressConfig — T1/T2 must be absent, T3 stress=10/abort=0.4/repair=300.
	var sc: StressConfig = load("res://data/stress_config.tres") as StressConfig
	if sc == null:
		_fail("StressConfig cast failed")
		return
	if sc.for_tier(1) != null or sc.for_tier(2) != null:
		_fail("Stress should be inactive for T1/T2")
	var t3p: TierStressParams = sc.for_tier(3)
	if t3p == null or not is_equal_approx(t3p.stress_per_fail, 10.0) or not is_equal_approx(t3p.abort_chance, 0.4) or t3p.repair_cost != 300:
		_fail("T3 stress params wrong")
	# 4) SkyProfile — Earth zone must match D_001's region_id.
	var earth: SkyProfile = load("res://data/sky_profiles/zone_01_earth.tres") as SkyProfile
	if earth == null or earth.region_id != "REGION_EARTH":
		_fail("Earth SkyProfile missing or wrong region_id")
	# 5) Phase 4 — D_050 must be Tier 4 Jovian, D_100 must be Tier 5 Deep Space ending.
	var d50: Destination = load("res://data/destinations/d_050.tres") as Destination
	if d50 == null or d50.tier != 4 or d50.region_id != "REGION_JOVIAN":
		_fail("D_050 must be Tier 4 Jovian")
	var d100: Destination = load("res://data/destinations/d_100.tres") as Destination
	if d100 == null or d100.tier != 5 or d100.region_id != "REGION_DEEP_SPACE":
		_fail("D_100 must be Tier 5 Deep Space (V1 ending)")
	# 6) Phase 4b — Codex / Badge / Mission resources cast and have expected fields.
	var mars_codex: CodexEntry = load("res://data/codex/body_mars.tres") as CodexEntry
	if mars_codex == null or mars_codex.id != "BODY_MARS" or mars_codex.destination_ids.size() < 5:
		_fail("BODY_MARS codex entry malformed")
	var earth_badge: BadgeDef = load("res://data/badges/badge_region_earth.tres") as BadgeDef
	if earth_badge == null or earth_badge.badge_type != "region_first" or earth_badge.region_id != "REGION_EARTH":
		_fail("BADGE_REGION_EARTH malformed")
	var win100_badge: BadgeDef = load("res://data/badges/badge_wins_100.tres") as BadgeDef
	if win100_badge == null or win100_badge.badge_type != "win_count" or win100_badge.threshold != 100:
		_fail("BADGE_WINS_100 malformed")
	var launch_mission: MissionDef = load("res://data/missions/dm_launch_20.tres") as MissionDef
	if launch_mission == null or launch_mission.condition_id != &"launches" or launch_mission.target != 20:
		_fail("DM_LAUNCH_20 malformed")
	print("  domain   ok: tiers + destinations + stress + sky + codex/badge/mission")

func _fail(msg: String) -> void:
	_failures += 1
	printerr("  FAIL: " + msg)
