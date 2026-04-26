class_name BadgePanel
extends PopupPanel

## Phase 5e badge viewer. Lists every BadgeDef (region_first grouped first, then
## win_count ascending by threshold). Earned badges show display_name + subtitle;
## unearned ones show "???" with a hint of how to earn.

const NAME_DIM: Color = Color(0.62, 0.65, 0.78, 1)
const HINT_DIM: Color = Color(0.5, 0.53, 0.66, 1)

@onready var _progress: Label = %ProgressLabel
@onready var _list: VBoxContainer = %ListVBox
@onready var _close: Button = %CloseButton

var _badges: BadgeService

func _ready() -> void:
	_badges = _find_badge_service()
	_close.pressed.connect(_on_close)
	_refresh()

func _refresh() -> void:
	if _badges == null:
		_progress.text = "—"
		return
	_progress.text = tr("PANEL_BADGES_PROGRESS_FMT") % [
		_badges.get_earned_count(), _badges.get_total_badges()
	]
	for child in _list.get_children():
		child.queue_free()
	for b in _badges.get_all_badges():
		_list.add_child(_build_row(b))

func _build_row(b: BadgeDef) -> Control:
	var row: VBoxContainer = VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	var name_label: Label = Label.new()
	name_label.add_theme_font_size_override("font_size", 18)
	row.add_child(name_label)
	var hint: Label = Label.new()
	hint.add_theme_font_size_override("font_size", 13)
	row.add_child(hint)

	var earned: bool = GameState.badges_earned.has(b.id)
	if earned:
		name_label.text = b.display_name
		hint.text = _describe_badge(b)
	else:
		name_label.text = tr("ENTRY_LOCKED")
		name_label.modulate = NAME_DIM
		hint.text = _describe_badge(b)
		hint.modulate = HINT_DIM
	return row

func _describe_badge(b: BadgeDef) -> String:
	match b.badge_type:
		"region_first": return tr("BADGE_REGION_FMT")
		"win_count":    return tr("BADGE_WIN_FMT") % b.threshold
	return ""

func _find_badge_service() -> BadgeService:
	var main_screen: Node = get_tree().current_scene
	if main_screen == null:
		return null
	return main_screen.get_node_or_null("BadgeService") as BadgeService

func _on_close() -> void:
	hide()
	queue_free()
