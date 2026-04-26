class_name AutoLaunchService
extends Node

## Periodic launch trigger that lets the game progress without manual taps.
## Unlocks naturally after the first T1 clear OR 10 manual launches.
## Phase 6 IAP bonuses: both are stored as time-limited boosts in
## GameState.active_boosts (keys: AUTO_LAUNCH_PASS, AUTO_FUEL). The rate
## recomputes per process tick, so expiry transitions revert automatically.
## See docs/systems/1-3-auto-launch.md.

const BOOST_AUTO_PASS: StringName = &"AUTO_LAUNCH_PASS"   ## +0.35 rate while active (7-day pass by default)
const BOOST_AUTO_FUEL: StringName = &"AUTO_FUEL"          ## +0.5 rate while active (60-min consumable, Phase 6c)

const BASE_RATE: float = 1.0
const RATE_AUTO_PASS: float = 0.35
const RATE_AUTO_FUEL: float = 0.5
const RATE_CAP: float = 2.5
const UNLOCK_AFTER_LAUNCHES: int = 10

## Injected by MainScreen.
var launch_service: LaunchService

var _accumulator: float = 0.0

func _ready() -> void:
	set_process(false)
	# Latch unlock state so a player who lost it (e.g. data wipe of total_launches
	# but not flags) keeps the QoL.
	if _check_unlock_now():
		GameState.auto_launch_unlocked = true
	# Resume auto-launch if it was on at save time.
	if is_unlocked() and GameState.auto_launch_enabled:
		set_process(true)

# --- Public API ---

func is_unlocked() -> bool:
	return GameState.auto_launch_unlocked or _check_unlock_now()

func is_enabled() -> bool:
	return GameState.auto_launch_enabled

func set_enabled(on: bool) -> void:
	if on and not is_unlocked():
		return
	GameState.auto_launch_enabled = on
	if on:
		GameState.auto_launch_unlocked = true
	_accumulator = 0.0
	set_process(on)

## Effective launches per second after IAP bonuses, clamped to RATE_CAP.
func get_rate() -> float:
	var rate: float = BASE_RATE
	if _is_boost_active(BOOST_AUTO_PASS):
		rate += RATE_AUTO_PASS
	if _is_boost_active(BOOST_AUTO_FUEL):
		rate += RATE_AUTO_FUEL
	return min(rate, RATE_CAP)

## Seconds until this boost ends, 0 if inactive. Used by UI for remaining-time labels.
func get_boost_time_remaining(boost_id: StringName) -> int:
	var expire: int = int(GameState.active_boosts.get(boost_id, 0))
	var remaining: int = expire - int(Time.get_unix_time_from_system())
	return max(0, remaining)

func is_boost_active(boost_id: StringName) -> bool:
	return _is_boost_active(boost_id)

# --- Internals ---

func _process(delta: float) -> void:
	if launch_service == null:
		set_process(false)
		return
	# Wait for the current launch (if any) to finish before queueing another.
	if launch_service.is_launching():
		return
	_accumulator += delta
	var period: float = 1.0 / get_rate()
	if _accumulator < period:
		return
	_accumulator -= period
	launch_service.start_launch()

func _check_unlock_now() -> bool:
	return GameState.highest_completed_tier >= 1 or GameState.total_launches >= UNLOCK_AFTER_LAUNCHES

func _is_boost_active(boost_id: StringName) -> bool:
	var expire: int = int(GameState.active_boosts.get(boost_id, 0))
	return expire > int(Time.get_unix_time_from_system())
