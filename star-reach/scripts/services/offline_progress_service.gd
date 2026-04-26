class_name OfflineProgressService
extends Node

## Computes and applies offline auto-launch progress. Subscribes to SaveSystem's
## profile_loaded signal so it runs once per app boot. Phase 4a uses a closed-form
## expectation (no per-launch RNG); Phase 5 will replace with deterministic
## seeded simulation if balance demands it.
## See docs/systems/1-3-auto-launch.md §4.6.

const OFFLINE_CAP_SEC: float = 8.0 * 3600.0
const MIN_SUMMARY_SEC: float = 60.0
const XP_PER_STAGE: int = 10

## Injected by MainScreen.
var auto_launch_service: AutoLaunchService
var destinations: Array[Destination] = []

func _ready() -> void:
	# profile_loaded fires after SaveSystem reads the save and populates GameState.
	EventBus.profile_loaded.connect(_on_profile_loaded)

func _on_profile_loaded() -> void:
	if not _can_simulate():
		return
	var summary: Dictionary = SaveSystem.last_offline_summary
	if summary.is_empty():
		return
	var elapsed: float = float(summary.get("elapsed_seconds", 0.0))
	if elapsed < MIN_SUMMARY_SEC:
		return
	var capped: float = min(elapsed, OFFLINE_CAP_SEC)
	var rate: float = auto_launch_service.get_rate()
	var d: Destination = _find_destination(GameState.current_destination_id)
	if d == null:
		return
	var sim: Dictionary = _simulate(capped, rate, d)
	if sim.get("simulated_launches", 0) <= 0:
		return
	# Apply rewards + record.
	GameState.add_xp(int(sim["xp_earned"]))
	GameState.add_credit(int(sim["credit_earned"]))
	GameState.add_tech_level(int(sim["tech_level_earned"]))
	GameState.total_launches += int(sim["simulated_launches"])
	GameState.total_wins += int(sim["wins"])
	sim["destination_name"] = d.display_name
	sim["elapsed_seconds"] = elapsed
	sim["capped_seconds"] = capped
	sim["was_capped"] = elapsed > capped
	EventBus.offline_summary_ready.emit(sim)

# --- Internals ---

func _can_simulate() -> bool:
	return auto_launch_service != null \
		and auto_launch_service.is_unlocked() \
		and GameState.auto_launch_enabled

## Closed-form expected reward over N simulated launches.
## per_stage_chance follows the same Tier-conquest rule LaunchService uses,
## so the headline "passive vs active" earnings stay consistent.
func _simulate(elapsed: float, rate: float, d: Destination) -> Dictionary:
	var sim_count: int = int(floor(elapsed * rate))
	if sim_count <= 0:
		return {"simulated_launches": 0}
	var lbc: LaunchBalanceConfig = load("res://data/launch_balance_config.tres") as LaunchBalanceConfig
	if lbc == null:
		return {"simulated_launches": 0}
	var seg: TierSegment = lbc.segment_for_tier(d.tier)
	if seg == null:
		return {"simulated_launches": 0}
	var per_stage_chance: float = seg.base_chance
	if GameState.highest_completed_tier >= seg.tier:
		per_stage_chance = seg.max_chance
	# E[XP per launch] = Σ XP * P(reach stage k)  — partial credit on early failure.
	var xp_per_launch: float = 0.0
	var prob_reaching: float = 1.0
	for _stage in d.required_stages:
		prob_reaching *= per_stage_chance
		xp_per_launch += XP_PER_STAGE * prob_reaching
	var clear_prob: float = prob_reaching
	var wins: int = int(round(sim_count * clear_prob))
	return {
		"simulated_launches": sim_count,
		"wins": wins,
		"xp_earned": int(round(sim_count * xp_per_launch)),
		"credit_earned": int(round(sim_count * d.reward_credit * clear_prob)),
		"tech_level_earned": int(round(sim_count * d.reward_tech_level * clear_prob)),
	}

func _find_destination(id: String) -> Destination:
	for d in destinations:
		if d.id == id:
			return d
	return null
