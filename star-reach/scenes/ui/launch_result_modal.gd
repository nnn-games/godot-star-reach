class_name LaunchResultModal
extends PopupPanel

## Destination-cleared celebration modal. Redesigned so the 640×900 portrait
## popup earns its screen share: large title + colored reward rows with
## count-up numbers + first-clear Codex/Badge unlock cards + next-destination
## preview + hero Continue CTA. MainScreen now calls popup_centered(size) so
## the declared size is honored (earlier call was argument-less which forced
## Godot to auto-shrink to contents_min_size — the source of the "tall narrow
## box" bug).

signal closed

const ENTRY_SCALE_FROM: Vector2 = Vector2(0.88, 0.88)
const ENTRY_DURATION: float = 0.22
const COUNT_UP_DURATION: float = 0.5
const ROW_STAGGER: float = 0.08

const COLOR_XP: Color = Color(0.424, 0.788, 0.961, 1)
const COLOR_CREDIT: Color = Color(0.941, 0.725, 0.369, 1)
const COLOR_TECH: Color = Color(0.756, 0.56, 0.93, 1)
const COLOR_CODEX: Color = Color(0.5, 0.88, 0.78, 1)
const COLOR_BADGE: Color = Color(0.95, 0.82, 0.42, 1)
const COLOR_MILESTONE: Color = Color(1.0, 0.85, 0.3, 1)
const COLOR_NEXT_LOCKED: Color = Color(0.82, 0.4, 0.4, 1)

const ICON_SIZE: Vector2 = Vector2(26, 26)
const REWARD_VALUE_FONT_SIZE: int = 30
const REWARD_UNIT_FONT_SIZE: int = 16
const UNLOCK_ICON_SIZE: Vector2 = Vector2(20, 20)
const UNLOCK_FONT_SIZE: int = 18

@onready var _root: MarginContainer = $Root
@onready var _title: Label = %TitleLabel
@onready var _meta: Label = %MetaLabel
@onready var _rewards_list: VBoxContainer = %RewardsList
@onready var _unlocks_block: VBoxContainer = %UnlocksBlock
@onready var _unlocks_list: VBoxContainer = %UnlocksList
@onready var _next_label: Label = %NextLabel
@onready var _continue: Button = %ContinueButton

# Populated once service refs are resolved.
var _discovery: DiscoveryService
var _badges: BadgeService

func _ready() -> void:
	_continue.pressed.connect(_on_continue_pressed)
	_resolve_services()
	# Play entry animation — pivot from center so scale tween pops.
	_root.pivot_offset = _root.size * 0.5
	_root.scale = ENTRY_SCALE_FROM
	_root.modulate.a = 0.0
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(_root, "scale", Vector2.ONE, ENTRY_DURATION) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_root, "modulate:a", 1.0, ENTRY_DURATION * 0.7) \
		.set_trans(Tween.TRANS_LINEAR)

## Populate the modal. `next_d` is the destination auto-advance will jump to
## (null when current is terminal or tech-gated).
func setup(d: Destination, payload: Dictionary, next_d: Destination, is_milestone: bool) -> void:
	_apply_title(d, is_milestone)
	_meta.text = tr("RESULT_META_FMT") % [d.tier, d.required_stages]
	_build_rewards(payload)
	_build_unlocks(d, bool(payload.get("is_first_clear", false)))
	_apply_next(d, next_d)

# --- Title ---

func _apply_title(d: Destination, is_milestone: bool) -> void:
	if is_milestone:
		_title.text = tr("RESULT_MILESTONE_FMT") % d.display_name
		_title.modulate = COLOR_MILESTONE
	else:
		_title.text = tr("DEST_CLEARED_FMT") % d.display_name
		_title.modulate = Color.WHITE

# --- Rewards ---

func _build_rewards(payload: Dictionary) -> void:
	_clear_children(_rewards_list)
	var xp: int = int(payload.get("session_xp_earned", 0))
	var credit: int = int(payload.get("credit_gain", 0))
	var tech: int = int(payload.get("tech_level_gain", 0))
	# Order matches the HUD currency pills (XP · Credit · Tech) so the player's
	# eye tracks the same left-to-right mapping they just internalized above.
	var rows: Array = []
	if xp > 0:
		rows.append([xp, COLOR_XP, tr("RESULT_UNIT_XP")])
	if credit > 0:
		rows.append([credit, COLOR_CREDIT, tr("RESULT_UNIT_CREDIT")])
	if tech > 0:
		rows.append([tech, COLOR_TECH, tr("RESULT_UNIT_TECH")])
	for i in rows.size():
		var r: Array = rows[i]
		var row: Control = _build_reward_row(int(r[0]), Color(r[1]), String(r[2]), ROW_STAGGER * i)
		_rewards_list.add_child(row)

func _build_reward_row(target_value: int, color: Color, unit: String, delay: float) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER

	var icon: Panel = Panel.new()
	icon.custom_minimum_size = ICON_SIZE
	icon.size = ICON_SIZE
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = color
	sb.corner_radius_top_left = 7
	sb.corner_radius_top_right = 7
	sb.corner_radius_bottom_right = 7
	sb.corner_radius_bottom_left = 7
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = color.lightened(0.25)
	icon.add_theme_stylebox_override("panel", sb)
	row.add_child(icon)

	var value_label: Label = Label.new()
	value_label.text = "+0"
	value_label.add_theme_color_override("font_color", color.lightened(0.15))
	value_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	value_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	value_label.add_theme_constant_override("shadow_offset_x", 1)
	value_label.add_theme_constant_override("shadow_offset_y", 3)
	value_label.add_theme_constant_override("outline_size", 3)
	value_label.add_theme_font_size_override("font_size", REWARD_VALUE_FONT_SIZE)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.custom_minimum_size = Vector2(120, 0)
	row.add_child(value_label)

	var unit_label: Label = Label.new()
	unit_label.text = unit
	unit_label.modulate = Color(0.85, 0.9, 1.0, 0.9)
	unit_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	unit_label.add_theme_constant_override("shadow_offset_x", 1)
	unit_label.add_theme_constant_override("shadow_offset_y", 2)
	unit_label.add_theme_font_size_override("font_size", REWARD_UNIT_FONT_SIZE)
	unit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	unit_label.custom_minimum_size = Vector2(100, 0)
	row.add_child(unit_label)

	# Count-up from 0 with stagger. Tween owned by the row so it cancels if freed.
	var tween: Tween = create_tween()
	tween.tween_interval(delay)
	tween.tween_method(func(v: float) -> void:
		value_label.text = "+%d" % int(round(v)),
		0.0, float(target_value), COUNT_UP_DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	return row

# --- Unlocks (Codex / Badge) ---

func _build_unlocks(d: Destination, is_first_clear: bool) -> void:
	_clear_children(_unlocks_list)
	if not is_first_clear:
		_unlocks_block.visible = false
		return
	var shown: bool = false
	if _discovery != null:
		var entry: CodexEntry = _discovery.get_entry_for_destination(d.id)
		if entry != null:
			_unlocks_list.add_child(_build_unlock_row(
				tr("RESULT_UNLOCK_CODEX"), entry.display_name, COLOR_CODEX))
			shown = true
	if _badges != null:
		var badge: BadgeDef = _badges.get_region_badge(d.region_id)
		if badge != null:
			_unlocks_list.add_child(_build_unlock_row(
				tr("RESULT_UNLOCK_BADGE"), badge.display_name, COLOR_BADGE))
			shown = true
	_unlocks_block.visible = shown

func _build_unlock_row(kind: String, name_text: String, color: Color) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var icon: Panel = Panel.new()
	icon.custom_minimum_size = UNLOCK_ICON_SIZE
	icon.size = UNLOCK_ICON_SIZE
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = color
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_left = 10
	sb.corner_radius_bottom_right = 10
	icon.add_theme_stylebox_override("panel", sb)
	row.add_child(icon)

	var kind_label: Label = Label.new()
	kind_label.text = kind
	kind_label.modulate = Color(0.75, 0.82, 0.96, 0.85)
	kind_label.add_theme_font_size_override("font_size", 13)
	kind_label.add_theme_constant_override("outline_size", 2)
	kind_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	kind_label.custom_minimum_size = Vector2(60, 0)
	row.add_child(kind_label)

	var name_label: Label = Label.new()
	name_label.text = name_text
	name_label.add_theme_color_override("font_color", color)
	name_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	name_label.add_theme_constant_override("shadow_offset_x", 1)
	name_label.add_theme_constant_override("shadow_offset_y", 2)
	name_label.add_theme_constant_override("outline_size", 3)
	name_label.add_theme_font_size_override("font_size", UNLOCK_FONT_SIZE)
	row.add_child(name_label)
	return row

# --- Next destination ---

func _apply_next(_current: Destination, next_d: Destination) -> void:
	if next_d == null:
		_next_label.text = tr("RESULT_NEXT_END")
		_next_label.modulate = Color(0.82, 0.86, 0.98, 0.85)
		_continue.text = tr("RESULT_CONTINUE_END")
		return
	if GameState.tech_level < next_d.required_tech_level:
		_next_label.text = "%s — %s  (%s)" % [
			next_d.id, next_d.display_name,
			tr("RESULT_NEXT_LOCKED_FMT") % next_d.required_tech_level,
		]
		_next_label.modulate = COLOR_NEXT_LOCKED
		_continue.text = tr("RESULT_CONTINUE_END")
		return
	_next_label.text = "%s — %s" % [next_d.id, next_d.display_name]
	_next_label.modulate = Color.WHITE
	_continue.text = tr("RESULT_CONTINUE_NEXT")

# --- Close ---

func _on_continue_pressed() -> void:
	closed.emit()
	queue_free()

# --- Helpers ---

func _clear_children(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()

func _resolve_services() -> void:
	var main_screen: Node = get_tree().current_scene
	if main_screen == null:
		return
	_discovery = main_screen.get_node_or_null("DiscoveryService") as DiscoveryService
	_badges = main_screen.get_node_or_null("BadgeService") as BadgeService
