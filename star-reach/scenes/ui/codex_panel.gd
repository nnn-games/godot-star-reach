class_name CodexPanel
extends PopupPanel

## Phase 5e codex viewer. Lists all CodexEntry resources; unlocked ones reveal
## display_name + summary + per-destination progress, locked ones show "???".
## Content is built at _ready from DiscoveryService (the service is not passed
## in — we look it up via /root to keep the panel standalone).

const NAME_DIM: Color = Color(0.62, 0.65, 0.78, 1)
const SUMMARY_DIM: Color = Color(0.5, 0.53, 0.66, 1)

@onready var _title: Label = %TitleLabel
@onready var _progress: Label = %ProgressLabel
@onready var _list: VBoxContainer = %ListVBox
@onready var _close: Button = %CloseButton

var _discovery: DiscoveryService

func _ready() -> void:
	_discovery = _find_discovery_service()
	_close.pressed.connect(_on_close)
	_refresh()

func _refresh() -> void:
	if _discovery == null:
		_progress.text = "—"
		return
	_progress.text = tr("PANEL_CODEX_PROGRESS_FMT") % [
		_discovery.get_unlocked_count(), _discovery.get_total_entries()
	]
	for child in _list.get_children():
		child.queue_free()
	for entry in _discovery.get_entries():
		_list.add_child(_build_row(entry))

func _build_row(entry: CodexEntry) -> Control:
	var row: VBoxContainer = VBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var header: HBoxContainer = HBoxContainer.new()
	row.add_child(header)
	var name_label: Label = Label.new()
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 18)
	header.add_child(name_label)
	var progress_label: Label = Label.new()
	progress_label.add_theme_font_size_override("font_size", 14)
	header.add_child(progress_label)
	var summary: Label = Label.new()
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.add_theme_font_size_override("font_size", 13)
	row.add_child(summary)

	var unlocked: bool = GameState.discovered_codex_entries.has(entry.id)
	if unlocked:
		name_label.text = entry.display_name
		summary.text = entry.summary
		progress_label.text = tr("CODEX_PROGRESS_FMT") % [
			_discovery.get_progress(entry.id), entry.destination_ids.size()
		]
	else:
		name_label.text = tr("ENTRY_LOCKED")
		summary.text = tr("CODEX_LOCKED_SUMMARY")
		name_label.modulate = NAME_DIM
		summary.modulate = SUMMARY_DIM
		progress_label.text = ""
	return row

## Panel is instantiated under MainScreen's ModalLayer, so DiscoveryService
## lives under MainScreen itself.
func _find_discovery_service() -> DiscoveryService:
	var main_screen: Node = get_tree().current_scene
	if main_screen == null:
		return null
	return main_screen.get_node_or_null("DiscoveryService") as DiscoveryService

func _on_close() -> void:
	hide()
	queue_free()
