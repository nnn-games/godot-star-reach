class_name ScreenShake
extends Node

## Phase 3 placeholder: shakes a target Control by offsetting its position.
## Phase 5 will swap to Camera2D.offset once the main scene becomes Node2D.
## Falloff is linear over the duration so the motion settles into stillness.

## Injected by MainScreen — the Control we offset.
var target: Control

var _amp: float = 0.0
var _dur: float = 0.0
var _elapsed: float = 0.0
var _initial_position: Vector2 = Vector2.ZERO
var _is_active: bool = false
var _rng: RandomNumberGenerator

func _ready() -> void:
	_rng = RandomNumberGenerator.new()
	_rng.randomize()
	set_process(false)

## Trigger a shake. New shakes during an active one don't reset the baseline,
## so chained calls feel additive instead of restarting from idle position.
func shake(amplitude: float, duration: float) -> void:
	if target == null:
		return
	if not _is_active:
		_initial_position = target.position
		_is_active = true
	_amp = amplitude
	_dur = duration
	_elapsed = 0.0
	set_process(true)

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= _dur:
		target.position = _initial_position
		_is_active = false
		set_process(false)
		return
	var falloff: float = 1.0 - (_elapsed / _dur)
	target.position = _initial_position + Vector2(
		_rng.randf_range(-1.0, 1.0) * _amp * falloff,
		_rng.randf_range(-1.0, 1.0) * _amp * falloff,
	)
