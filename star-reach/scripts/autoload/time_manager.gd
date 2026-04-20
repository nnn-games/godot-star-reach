extends Node

## Central tick source. Forwards scaled delta to GameState every frame.
## speed_multiplier is exposed so prestige boosts / debug speed-up / pause can
## modify the whole economy through one knob.

var speed_multiplier: float = 1.0

func _process(delta: float) -> void:
	if speed_multiplier <= 0.0:
		return
	GameState.tick(delta * speed_multiplier)

func pause() -> void:
	speed_multiplier = 0.0

func resume(multiplier: float = 1.0) -> void:
	speed_multiplier = multiplier
