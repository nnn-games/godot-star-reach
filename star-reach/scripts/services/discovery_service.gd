class_name DiscoveryService
extends Node

## Discovery / Codex tracker. Phase 4b loads CodexEntry resources, subscribes to
## destination_completed, and unlocks / advances entries automatically.
## See docs/celestial_codex_design_plan.md for the design (Lite B = 12 entries).
## Phase 5 will surface the panel UI; for now, only EventBus signals + persistent
## state are produced.

const ENTRIES_DIR: String = "res://data/codex/"

var _entries: Array[CodexEntry] = []
## destination_id → entry for quick reverse lookup at runtime.
var _entry_for_destination: Dictionary[StringName, CodexEntry] = {}

func _ready() -> void:
	_load_entries()
	EventBus.destination_completed.connect(_on_destination_completed)

# --- Public API ---

func get_total_entries() -> int:
	return _entries.size()

func get_unlocked_count() -> int:
	return GameState.discovered_codex_entries.size()

func get_progress(entry_id: String) -> int:
	var arr: Array = GameState.codex_entry_progress.get(StringName(entry_id), [])
	return arr.size()

func get_entries() -> Array[CodexEntry]:
	return _entries

## Reverse lookup — which CodexEntry this destination contributes to (or null).
## Used by LaunchResultModal to surface the unlocked entry on first clear.
func get_entry_for_destination(d_id: String) -> CodexEntry:
	return _entry_for_destination.get(StringName(d_id))

# --- Internals ---

func _load_entries() -> void:
	var dir: DirAccess = DirAccess.open(ENTRIES_DIR)
	if dir == null:
		push_warning("[Discovery] no codex dir at %s" % ENTRIES_DIR)
		return
	for f in dir.get_files():
		if not f.ends_with(".tres"):
			continue
		var e: CodexEntry = load(ENTRIES_DIR.path_join(f)) as CodexEntry
		if e == null:
			continue
		_entries.append(e)
		for d_id in e.destination_ids:
			_entry_for_destination[StringName(d_id)] = e
	print("[Discovery] loaded %d codex entries" % _entries.size())

func _on_destination_completed(d_id: String, payload: Dictionary) -> void:
	# Only first-time clears advance the codex (per design).
	if not bool(payload.get("is_first_clear", false)):
		return
	var entry: CodexEntry = _entry_for_destination.get(StringName(d_id))
	if entry == null:
		return
	# Track the destination under this entry's progress dict.
	var key: StringName = StringName(entry.id)
	var progressed: Array = GameState.codex_entry_progress.get(key, [])
	if not progressed.has(d_id):
		progressed.append(d_id)
		GameState.codex_entry_progress[key] = progressed
	# Unlock on first contribution.
	var was_unlocked: bool = GameState.discovered_codex_entries.has(entry.id)
	if not was_unlocked:
		GameState.discovered_codex_entries.append(entry.id)
		EventBus.codex_entry_unlocked.emit(entry.id)
	else:
		EventBus.codex_entry_updated.emit(entry.id)
	# Completion = all destination_ids in this entry have been first-cleared.
	if progressed.size() >= entry.destination_ids.size():
		EventBus.codex_entry_completed.emit(entry.id)
