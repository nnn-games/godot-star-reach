class_name FloatingText
extends Label

## One-shot "+10 XP" style floater. Spawned by MainScreen on stage / destination
## events, anchored to the rocket's current global position. Lifetime ~1s —
## the node queue_frees itself after the tween completes.

const FLOAT_UP_PX: float = 80.0
const DURATION: float = 1.0

func _ready() -> void:
	pivot_offset = size * 0.5

## Call immediately after instantiate / add_child. Takes a *global* screen
## position; the label centers itself on that point then floats upward.
func setup(txt: String, color: Color, at_global: Vector2, font_size: int = 24) -> void:
	text = txt
	add_theme_color_override("font_color", color)
	add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	add_theme_constant_override("shadow_offset_x", 1)
	add_theme_constant_override("shadow_offset_y", 2)
	add_theme_constant_override("outline_size", 4)
	add_theme_font_size_override("font_size", font_size)
	# Wait a frame so the Label computes its own size before we center it.
	await get_tree().process_frame
	pivot_offset = size * 0.5
	global_position = at_global - size * 0.5
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(self, "global_position:y", global_position.y - FLOAT_UP_PX, DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, DURATION) \
		.set_trans(Tween.TRANS_LINEAR)
	tween.chain().tween_callback(queue_free)
