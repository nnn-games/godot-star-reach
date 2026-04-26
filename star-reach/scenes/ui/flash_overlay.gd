class_name FlashOverlay
extends ColorRect

## Full-screen color flash for stage / abort feedback. Lives on a high-layer
## CanvasLayer so it draws on top of everything but the modals.
## flash() builds a fresh Tween each call, killing any in-flight one.

var _tween: Tween

func _ready() -> void:
	# Start invisible. mouse_filter = IGNORE so clicks pass through to the buttons.
	color = Color(0.0, 0.0, 0.0, 0.0)
	mouse_filter = MOUSE_FILTER_IGNORE

func flash(c: Color, duration: float = 0.25, peak_alpha: float = 0.7) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	color = Color(c.r, c.g, c.b, 0.0)
	_tween = create_tween()
	_tween.tween_property(self, "color:a", peak_alpha, duration * 0.3)
	_tween.tween_property(self, "color:a", 0.0, duration * 0.7)
