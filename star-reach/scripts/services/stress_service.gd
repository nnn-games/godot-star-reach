class_name StressService
extends Node

## Owns the Stress / Overload / Abort risk layer for T3+ launches.
## - Accumulates on stage failure (tier-scaled via StressConfig)
## - Decays idle after IDLE_THRESHOLD_SEC at DECAY_RATE_PER_SEC
## - At OVERLOAD_THRESHOLD, next launch rolls against abort_chance
## - Abort deducts repair_cost (clamped) and resets stress to 0
## See docs/systems/1-4-stress-abort.md.

const OVERLOAD_THRESHOLD: float = 100.0
const MAX_STRESS: float = 200.0  # internal cap for buff overshoot (docs §5.7)
const IDLE_THRESHOLD_SEC: float = 5.0
const DECAY_RATE_PER_SEC: float = 2.0
const EMIT_THROTTLE_SEC: float = 0.1

@export var config: StressConfig

var _rng: RandomNumberGenerator
var _last_activity_ms: int = 0
var _emit_accum: float = 0.0

func _ready() -> void:
	if config == null:
		config = load("res://data/stress_config.tres") as StressConfig
	assert(config != null, "StressConfig missing")
	_rng = RandomNumberGenerator.new()
	_rng.randomize()
	_last_activity_ms = Time.get_ticks_msec()
	EventBus.launch_started.connect(_on_launch_started)

# --- Public API (called by LaunchService) ---

## Accumulates stress when a launch stage fails. No-op below T3.
func on_stage_failed(tier: int) -> void:
	var params: TierStressParams = config.for_tier(tier)
	if params == null:
		return
	GameState.stress_value = min(GameState.stress_value + params.stress_per_fail, MAX_STRESS)
	EventBus.stress_changed.emit(GameState.stress_value)

## Pre-launch abort roll. Returns true + emits abort_triggered if an abort occurs,
## in which case LaunchService must not start the launch.
func try_abort(tier: int) -> bool:
	if GameState.stress_value < OVERLOAD_THRESHOLD:
		return false
	var params: TierStressParams = config.for_tier(tier)
	if params == null:
		return false
	if _rng.randf() >= params.abort_chance:
		return false
	var spent: int = GameState.spend_credit_clamped(params.repair_cost)
	GameState.stress_value = 0.0
	EventBus.stress_changed.emit(0.0)
	EventBus.abort_triggered.emit(spent)
	return true

## True when the gauge is in the overload band (next launch may abort).
func is_overloaded() -> bool:
	return GameState.stress_value >= OVERLOAD_THRESHOLD

# --- Internals ---

func _process(delta: float) -> void:
	if GameState.stress_value <= 0.0:
		return
	var sec_since_activity: float = float(Time.get_ticks_msec() - _last_activity_ms) / 1000.0
	if sec_since_activity < IDLE_THRESHOLD_SEC:
		return
	GameState.stress_value = max(GameState.stress_value - DECAY_RATE_PER_SEC * delta, 0.0)
	_emit_accum += delta
	if _emit_accum >= EMIT_THROTTLE_SEC:
		_emit_accum = 0.0
		EventBus.stress_changed.emit(GameState.stress_value)

func _on_launch_started() -> void:
	_last_activity_ms = Time.get_ticks_msec()
