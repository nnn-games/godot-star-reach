extends Node

## Central tick source. Forwards scaled delta to GameState every frame.
## speed_multiplier is exposed so prestige boosts / debug speed-up / pause can
## modify the whole economy through one knob.

## Max time credited for offline absence. Beyond this the rest is discarded —
## prevents a year-away player from getting astronomical resources on return.
const MAX_OFFLINE_SECONDS: float = 8.0 * 3600.0

var speed_multiplier: float = 1.0

func _process(delta: float) -> void:
	if speed_multiplier <= 0.0:
		return
	GameState.tick(delta * speed_multiplier)

## Compute offline delta from last save timestamp, clamp to MAX_OFFLINE_SECONDS,
## and apply via GameState.advance_simulation.
## Returns {elapsed_seconds, capped_seconds, produced: {gen_id: amount}}.
func apply_offline_progress(last_saved_unix: int) -> Dictionary:
	if last_saved_unix <= 0:
		return { "elapsed_seconds": 0.0, "capped_seconds": 0.0, "produced": {} }
	var now: int = int(Time.get_unix_time_from_system())
	var elapsed: float = max(0.0, float(now - last_saved_unix))
	var capped: float = min(elapsed, MAX_OFFLINE_SECONDS)
	var produced: Dictionary = GameState.advance_simulation(capped)
	return {
		"elapsed_seconds": elapsed,
		"capped_seconds": capped,
		"produced": produced,
	}

func pause() -> void:
	speed_multiplier = 0.0

func resume(multiplier: float = 1.0) -> void:
	speed_multiplier = multiplier
