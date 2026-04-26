class_name MissionPanel
extends PopupPanel

## Phase 5e daily missions viewer. Shows today's 3 missions with progress and
## claim status. MissionService auto-claims; this panel is a read-only summary
## (an explicit Claim button arrives when manual claim is added in a later pass).

const CLAIMED_NAME: Color = Color(0.5, 0.53, 0.66, 1)
const ACCENT_GOLD: Color = Color(0.941, 0.725, 0.369, 1)

@onready var _progress: Label = %ProgressLabel
@onready var _daily_cap: Label = %DailyCapLabel
@onready var _list: VBoxContainer = %ListVBox
@onready var _close: Button = %CloseButton

var _missions: MissionService

func _ready() -> void:
	_missions = _find_mission_service()
	_close.pressed.connect(_on_close)
	_refresh()

func _refresh() -> void:
	if _missions == null:
		_progress.text = "—"
		_daily_cap.text = ""
		return
	_progress.text = tr("PANEL_MISSIONS_PROGRESS_FMT") % [
		_missions.get_claimed_count(), _missions.get_total_today()
	]
	var tech_earned: int = int(GameState.daily_mission.get("daily_tech_earned", 0))
	_daily_cap.text = tr("MISSION_DAILY_CAP_FMT") % [tech_earned, MissionService.MISSION_DAILY_TECH_CAP]
	for child in _list.get_children():
		child.queue_free()
	for m in _missions.get_today_missions():
		_list.add_child(_build_row(m))

func _build_row(m: Dictionary) -> Control:
	var def: MissionDef = _missions.get_definition(StringName(m.get("id", "")))
	var row: VBoxContainer = VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	var header: HBoxContainer = HBoxContainer.new()
	row.add_child(header)
	var name_label: Label = Label.new()
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 17)
	header.add_child(name_label)
	var status_label: Label = Label.new()
	status_label.add_theme_font_size_override("font_size", 14)
	header.add_child(status_label)

	if def == null:
		name_label.text = String(m.get("id", "?"))
		status_label.text = ""
		return row

	name_label.text = def.display_name
	var progress: int = int(m.get("progress", 0))
	var claimed: bool = bool(m.get("claimed", false))
	if claimed:
		status_label.text = tr("MISSION_CLAIMED")
		status_label.modulate = ACCENT_GOLD
		name_label.modulate = CLAIMED_NAME
	else:
		status_label.text = "%d / %d" % [min(progress, def.target), def.target]
	return row

func _find_mission_service() -> MissionService:
	var main_screen: Node = get_tree().current_scene
	if main_screen == null:
		return null
	return main_screen.get_node_or_null("MissionService") as MissionService

func _on_close() -> void:
	hide()
	queue_free()
