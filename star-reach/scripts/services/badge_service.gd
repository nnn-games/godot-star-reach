class_name BadgeService
extends Node

## Awards Badges based on two rule families:
##   - region_first: first-clear of any destination in `region_id`
##   - win_count:    GameState.total_wins reaches `threshold`
## Phase 6 will route awarded badges into Steam / GPG / Game Center via the
## `achievement_id` field on BadgeDef.
## Idempotent: each badge id is added to GameState.badges_earned at most once.

const BADGES_DIR: String = "res://data/badges/"

var _region_first: Dictionary[StringName, BadgeDef] = {}
var _win_count: Array[BadgeDef] = []   ## sorted by threshold ascending

func _ready() -> void:
	_load_badges()
	EventBus.destination_completed.connect(_on_destination_completed)
	EventBus.launch_completed.connect(_on_launch_completed)

# --- Public API ---

func get_total_badges() -> int:
	return _region_first.size() + _win_count.size()

func get_earned_count() -> int:
	return GameState.badges_earned.size()

## Region-first badge for a given region id, or null if no badge for that region.
## LaunchResultModal uses this to show the earned badge on first clear.
func get_region_badge(region_id: String) -> BadgeDef:
	return _region_first.get(StringName(region_id))

## Flat list for panel rendering. Region-first badges first (stable by dict order),
## then win-count badges in threshold-ascending order (already sorted).
func get_all_badges() -> Array[BadgeDef]:
	var out: Array[BadgeDef] = []
	for b in _region_first.values():
		out.append(b)
	for b in _win_count:
		out.append(b)
	return out

# --- Internals ---

func _load_badges() -> void:
	var dir: DirAccess = DirAccess.open(BADGES_DIR)
	if dir == null:
		push_warning("[Badge] no badges dir at %s" % BADGES_DIR)
		return
	var win_count: Array[BadgeDef] = []
	for f in dir.get_files():
		if not f.ends_with(".tres"):
			continue
		var b: BadgeDef = load(BADGES_DIR.path_join(f)) as BadgeDef
		if b == null:
			continue
		match b.badge_type:
			"region_first": _region_first[StringName(b.region_id)] = b
			"win_count": win_count.append(b)
	# Cheaper to scan in threshold order each launch — small list (~8).
	win_count.sort_custom(func(a: BadgeDef, c: BadgeDef) -> bool: return a.threshold < c.threshold)
	_win_count = win_count
	print("[Badge] loaded %d region-first + %d win-count" % [_region_first.size(), _win_count.size()])

func _on_destination_completed(_d_id: String, payload: Dictionary) -> void:
	if not bool(payload.get("is_first_clear", false)):
		return
	# Resolve the destination to find its region_id.
	var d_id: String = String(_d_id)
	var path: String = "res://data/destinations/d_%s.tres" % d_id.substr(2).to_lower()
	var dest: Destination = load(path) as Destination
	if dest == null:
		return
	var badge: BadgeDef = _region_first.get(StringName(dest.region_id))
	if badge == null:
		return
	_award(badge)

func _on_launch_completed(_d_id: String) -> void:
	# total_wins is already incremented in LaunchService._finalize before signals fire.
	for b in _win_count:
		if GameState.total_wins >= b.threshold:
			_award(b)
		else:
			break  # sorted ascending — stop at first unmet threshold

func _award(badge: BadgeDef) -> void:
	if GameState.badges_earned.has(badge.id):
		return
	GameState.badges_earned.append(badge.id)
	EventBus.badge_awarded.emit(badge.id)
	# Phase 6: PlatformService.set_achievement(badge.achievement_id)
