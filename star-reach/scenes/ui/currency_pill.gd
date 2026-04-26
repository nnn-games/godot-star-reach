class_name CurrencyPill
extends HBoxContainer

## Icon + number display for a single currency. Replaces the raw text labels
## ("XP: 500") with a compact pill that (a) gives each currency its own color
## identity, (b) count-up animates on change so the number reads as a reward,
## (c) shares a common shape language across all 3 currencies.
##
## Icon is a placeholder Panel rectangle tinted by the currency color; swap in
## an actual icon Texture when art drops.

const ICON_SIZE: Vector2 = Vector2(18, 18)
const COUNT_UP_DURATION: float = 0.35
const BUMP_DURATION: float = 0.25
const BUMP_SCALE: Vector2 = Vector2(1.22, 1.22)

@export var icon_color: Color = Color(0.42, 0.79, 0.96, 1)
@export var font_size: int = 20

var _icon: Panel
var _label: Label
var _value: int = 0
var _display_value: int = 0
var _value_tween: Tween
var _bump_tween: Tween

func _ready() -> void:
	add_theme_constant_override("separation", 6)
	alignment = BoxContainer.ALIGNMENT_CENTER
	_build_icon()
	_build_label()
	_refresh_label()

## Set the value. If `animate` is false, the display jumps instantly.
func set_value(v: int, animate: bool = true) -> void:
	var previous: int = _value
	_value = v
	if not animate:
		_display_value = v
		_refresh_label()
		return
	if _value_tween != null and _value_tween.is_valid():
		_value_tween.kill()
	_value_tween = create_tween()
	_value_tween.tween_method(_set_display_value, _display_value, v, COUNT_UP_DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if v != previous:
		_bump()

func _bump() -> void:
	if _bump_tween != null and _bump_tween.is_valid():
		_bump_tween.kill()
	_label.pivot_offset = _label.size * 0.5
	_bump_tween = create_tween()
	_bump_tween.tween_property(_label, "scale", BUMP_SCALE, BUMP_DURATION * 0.35)
	_bump_tween.tween_property(_label, "scale", Vector2.ONE, BUMP_DURATION * 0.65) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func set_icon_color(c: Color) -> void:
	icon_color = c
	if _icon != null:
		_apply_icon_style()

# --- Internals ---

func _set_display_value(v: float) -> void:
	_display_value = int(round(v))
	_refresh_label()

func _refresh_label() -> void:
	if _label != null:
		_label.text = _format_number(_display_value)

## Thousands-separator formatting. `1500 → 1,500`. K/M abbreviation can slot in
## here later once economy spans orders of magnitude.
static func _format_number(v: int) -> String:
	var negative: bool = v < 0
	var digits: String = str(abs(v))
	var out: String = ""
	var count: int = 0
	for i in range(digits.length() - 1, -1, -1):
		out = digits[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return ("-" if negative else "") + out

func _build_icon() -> void:
	_icon = Panel.new()
	_icon.custom_minimum_size = ICON_SIZE
	_icon.size = ICON_SIZE
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_icon_style()
	add_child(_icon)

func _apply_icon_style() -> void:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = icon_color
	sb.corner_radius_top_left = 5
	sb.corner_radius_top_right = 5
	sb.corner_radius_bottom_left = 5
	sb.corner_radius_bottom_right = 5
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = icon_color.lightened(0.25)
	_icon.add_theme_stylebox_override("panel", sb)

func _build_label() -> void:
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", font_size)
	_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_label.add_theme_constant_override("shadow_offset_x", 1)
	_label.add_theme_constant_override("shadow_offset_y", 2)
	_label.add_theme_constant_override("outline_size", 3)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
