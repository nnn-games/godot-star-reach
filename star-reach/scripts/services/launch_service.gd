class_name LaunchService
extends Node

## Owns the launch loop: pre-launch abort check, stage probability rolls,
## XP grants, completion / failure, Pity counter.
## Phase 2 features now active:
##   - Tier conquest: stages in already-cleared tiers return segment.max_chance
##   - Pity System: silent +1%p per fail past PITY_START_THRESHOLD, capped
##   - Stress Abort pre-check (delegated to StressService)
## See docs/systems/1-2-multi-stage-probability.md and 1-4-stress-abort.md.

const STAGE_DURATION_SEC: float = 2.0
const XP_PER_STAGE: int = 10  # Phase 3+: + Telemetry bonus, × Fuel Optimization

# Pity tuning. UI never shows this value — silent floor.
const PITY_START_THRESHOLD: int = 5      # bonus kicks in at the 5th consecutive failure
const PITY_BONUS_PER_FAIL: float = 0.01  # +1%p per fail past threshold
const PITY_MAX_BONUS: float = 0.15       # cap at +15%p

@export var balance_config: LaunchBalanceConfig

## Injected by parent scene (MainScreen). Optional — without it, no abort check.
var stress_service: StressService

var _rng: RandomNumberGenerator
var _is_launching: bool = false
var _current_destination: Destination
var _current_stage: int = 0
var _stages_cleared: int = 0
var _session_xp_earned: int = 0

func _ready() -> void:
	if balance_config == null:
		balance_config = load("res://data/launch_balance_config.tres") as LaunchBalanceConfig
	assert(balance_config != null, "LaunchBalanceConfig missing")
	_rng = RandomNumberGenerator.new()
	# Seed from saved state for deterministic offline simulation. Initialize on
	# first run so two players still get different sequences.
	if GameState.rng_seed == 0:
		_rng.randomize()
		GameState.rng_seed = int(_rng.seed)
	else:
		_rng.seed = GameState.rng_seed

# --- Public API ---

func is_launching() -> bool:
	return _is_launching

func get_current_destination() -> Destination:
	return _current_destination

func set_destination(d: Destination) -> void:
	if _is_launching:
		push_warning("[Launch] cannot change destination mid-launch")
		return
	_current_destination = d
	GameState.current_destination_id = d.id
	_current_stage = 0
	_stages_cleared = 0

func start_launch() -> void:
	if _is_launching:
		return
	if _current_destination == null:
		push_error("[Launch] no destination set")
		return
	# Pre-launch abort check. If StressService aborts, we don't even fire
	# launch_started — UI stays in idle and the AbortScreen modal handles UX.
	if stress_service != null and stress_service.try_abort(_current_destination.tier):
		return
	_is_launching = true
	_current_stage = 0
	_stages_cleared = 0
	_session_xp_earned = 0
	SaveSystem.pause_autosave()
	EventBus.launch_started.emit()
	_run_stages()

# --- Stage loop ---

func _run_stages() -> void:
	while _current_stage < _current_destination.required_stages:
		_current_stage += 1
		await get_tree().create_timer(STAGE_DURATION_SEC).timeout
		# Bail out if scene was freed mid-await (e.g. Back to Menu while ascending).
		if not is_inside_tree() or not _is_launching:
			return
		var chance: float = _compute_chance(_current_stage)
		var roll: float = _rng.randf()
		# Persist evolving RNG state so a crash mid-launch resumes deterministically.
		GameState.rng_seed = int(_rng.state)
		if roll < chance:
			_session_xp_earned += XP_PER_STAGE
			_stages_cleared += 1
			GameState.add_xp(XP_PER_STAGE)
			GameState.add_battle_pass_xp(XP_PER_STAGE)
			EventBus.stage_succeeded.emit(_current_stage, chance)
		else:
			EventBus.stage_failed.emit(_current_stage, chance)
			# Notify StressService for tier-aware accumulation (T3+ only).
			if stress_service != null:
				stress_service.on_stage_failed(_current_destination.tier)
			_finalize(false)
			return
	_finalize(true)

## Tier conquest first, otherwise base + pity bonus, clamped to max_chance.
## Phase 3+ will add Launch Tech / Facility / IAP bonuses to the upgrade term.
func _compute_chance(stage_index: int) -> float:
	var seg: TierSegment = balance_config.segment_for_stage(stage_index)
	if seg == null:
		push_error("[Launch] no TierSegment for stage %d" % stage_index)
		return 0.0
	if GameState.highest_completed_tier >= seg.tier:
		return seg.max_chance
	var upgrade_bonus: float = 0.0  # Phase 3+: launch_tech + facility + iap
	var pity: float = _compute_pity_bonus()
	return min(seg.base_chance + upgrade_bonus + pity, seg.max_chance)

func _compute_pity_bonus() -> float:
	var fails: int = GameState.consecutive_failures
	if fails < PITY_START_THRESHOLD:
		return 0.0
	var bonus: float = float(fails - PITY_START_THRESHOLD + 1) * PITY_BONUS_PER_FAIL
	return min(bonus, PITY_MAX_BONUS)

func _finalize(success: bool) -> void:
	_is_launching = false
	GameState.total_launches += 1
	SaveSystem.resume_autosave()
	if success:
		GameState.total_wins += 1
		GameState.consecutive_failures = 0
		var d: Destination = _current_destination
		GameState.add_credit(d.reward_credit)
		GameState.add_tech_level(d.reward_tech_level)
		if d.tier > GameState.highest_completed_tier:
			GameState.highest_completed_tier = d.tier
			if not GameState.cleared_tiers.has(d.tier):
				GameState.cleared_tiers.append(d.tier)
		# Snapshot before mutating so the modal can highlight first-clear / milestone.
		var is_first_clear: bool = not GameState.completed_destinations.has(d.id)
		if is_first_clear:
			GameState.completed_destinations.append(d.id)
		EventBus.launch_completed.emit(d.id)
		EventBus.destination_completed.emit(d.id, {
			"credit_gain": d.reward_credit,
			"tech_level_gain": d.reward_tech_level,
			"tier": d.tier,
			"stages_cleared": _stages_cleared,
			"session_xp_earned": _session_xp_earned,
			"is_first_clear": is_first_clear,
		})
	else:
		GameState.consecutive_failures += 1
	# Force a save on big events so a power-loss right after a clear doesn't lose it.
	SaveSystem.save_game()
