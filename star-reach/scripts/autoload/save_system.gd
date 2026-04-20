extends Node

## Persists GameState to user://savegame.json.
## Features:
##   - Schema version field + migration hook
##   - Atomic write (temp file → rename) to survive crashes mid-save
##   - Periodic auto-save every PERIODIC_SAVE_INTERVAL_SEC
##   - Save on NOTIFICATION_WM_CLOSE_REQUEST (desktop close / mobile background)
##   - On boot: auto-load + apply_offline_progress (clamped to 8h)
##   - last_offline_summary exposed for UI (Welcome Back dialog in game.gd)

const SAVE_PATH: String = "user://savegame.json"
const TEMP_PATH: String = "user://savegame.json.tmp"
const BACKUP_PATH: String = "user://savegame.json.bak"
const SAVE_VERSION: int = 1
const PERIODIC_SAVE_INTERVAL_SEC: float = 10.0

var last_offline_summary: Dictionary = {}
var _last_saved_unix: int = 0
var _save_timer: Timer

func _ready() -> void:
	# Force save-on-quit for desktop (mobile background is handled by OS).
	get_tree().set_auto_accept_quit(false)
	# Auto-load happens after GameState._ready (autoload order puts us last).
	if has_save():
		_auto_load_on_boot()
	_save_timer = Timer.new()
	_save_timer.wait_time = PERIODIC_SAVE_INTERVAL_SEC
	_save_timer.one_shot = false
	_save_timer.timeout.connect(func(): save_game())
	add_child(_save_timer)
	_save_timer.start()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		save_game()
		if what == NOTIFICATION_WM_CLOSE_REQUEST:
			get_tree().quit()

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func save_game() -> bool:
	var now: int = int(Time.get_unix_time_from_system())
	var payload: Dictionary = {
		"version": SAVE_VERSION,
		"saved_at": now,
		"state": GameState.to_dict(),
	}
	var text: String = JSON.stringify(payload, "  ")
	var f: FileAccess = FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if f == null:
		push_error("[Save] cannot open temp file: %d" % FileAccess.get_open_error())
		return false
	f.store_string(text)
	f.close()
	# Rename temp → save. If rename fails, previous save stays intact.
	var da: DirAccess = DirAccess.open("user://")
	if da == null:
		push_error("[Save] cannot access user://")
		return false
	if da.file_exists(SAVE_PATH.get_file()):
		da.rename(SAVE_PATH.get_file(), BACKUP_PATH.get_file())
	var err: int = da.rename(TEMP_PATH.get_file(), SAVE_PATH.get_file())
	if err != OK:
		push_error("[Save] rename failed: %d" % err)
		return false
	_last_saved_unix = now
	EventBus.save_completed.emit()
	return true

## Restore state. Returns dict with offline_summary or empty if no save.
func load_game() -> Dictionary:
	if not has_save():
		return {}
	var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		push_error("[Save] cannot read save: %d" % FileAccess.get_open_error())
		return {}
	var text: String = f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("[Save] corrupt save (parse failed). Keeping seeded defaults.")
		return {}
	var data: Dictionary = parsed
	_migrate(data)
	GameState.from_dict(data.get("state", {}))
	var saved_at: int = int(data.get("saved_at", 0))
	_last_saved_unix = saved_at
	return TimeManager.apply_offline_progress(saved_at)

## Clears save and reseeds state. Used for "New Game" button.
func reset() -> void:
	var da: DirAccess = DirAccess.open("user://")
	if da != null:
		if da.file_exists(SAVE_PATH.get_file()):
			da.remove(SAVE_PATH.get_file())
		if da.file_exists(BACKUP_PATH.get_file()):
			da.remove(BACKUP_PATH.get_file())
	GameState.from_dict({})  # reseed via defaults
	_last_saved_unix = 0
	last_offline_summary = {}

# --- Internals ---

func _auto_load_on_boot() -> void:
	var summary: Dictionary = load_game()
	if summary.is_empty():
		return
	if float(summary.get("elapsed_seconds", 0.0)) > 1.0:
		last_offline_summary = summary

## Forward-upgrade old saves in-place. Keep additive — never break old data.
func _migrate(data: Dictionary) -> void:
	var v: int = int(data.get("version", 0))
	if v == SAVE_VERSION:
		return
	# Example for future v1 → v2:
	#   if v < 2: data.state["new_field"] = default_value
	# After all steps:
	data["version"] = SAVE_VERSION
