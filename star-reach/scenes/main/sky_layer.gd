class_name SkyLayer
extends Control

## Phase 3 placeholder: a single full-screen ColorRect that we Tween to the
## current SkyProfile's sky_color. Phase 5 will add ParallaxBackground texture
## layers + star field on top.
## See docs/systems/4-2-sky-transition.md.

@onready var _background: ColorRect = $BackgroundRect

func apply_immediate(profile: SkyProfile) -> void:
	if profile == null:
		return
	_background.color = profile.sky_color

func transition_to(profile: SkyProfile, duration: float = 2.0) -> void:
	if profile == null:
		return
	var tween: Tween = create_tween()
	tween.tween_property(_background, "color", profile.sky_color, duration)
