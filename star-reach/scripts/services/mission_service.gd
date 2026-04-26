class_name MissionService
extends Node

## Daily mission tracker. Phase 4b auto-rolls 3 missions per day from the pool,
## subscribes to gameplay signals, and increments progress. Auto-claims the
## TechLevel reward on completion (Phase 5 will add an explicit Claim button).
## Daily TechLevel cap = MISSION_DAILY_TECH_CAP. Missions exceeding the cap
## still complete but grant 0 TechLevel.

const MISSIONS_DIR: String = "res://data/missions/"
const DAILY_PICK: int = 3
const MISSION_DAILY_TECH_CAP: int = 50

var _pool: Array[MissionDef] = []
var _by_id: Dictionary[StringName, MissionDef] = {}

# Streak tracker for stage_streak missions; resets on any failure.
var _stage_streak_today: int = 0

func _ready() -> void:
	_load_pool()
	_ensure_today_rolled()
	EventBus.launch_started.connect(_on_launch_started)
	EventBus.launch_completed.connect(_on_launch_completed)
	EventBus.stage_succeeded.connect(_on_stage_succeeded)
	EventBus.stage_failed.connect(_on_stage_failed)
	EventBus.destination_completed.connect(_on_destination_completed)

# --- Public API ---

func get_today_missions() -> Array:
	return GameState.daily_mission.get("missions", [])

func get_claimed_count() -> int:
	var count: int = 0
	for m in get_today_missions():
		if bool(m.get("claimed", false)):
			count += 1
	return count

func get_total_today() -> int:
	return get_today_missions().size()

func get_definition(id: StringName) -> MissionDef:
	return _by_id.get(id)

# --- Daily roll ---

func _ensure_today_rolled() -> void:
	var today: String = Time.get_date_string_from_system()
	if String(GameState.daily_mission.get("date", "")) == today:
		return
	# Determined seed: same date+pool yields the same picks across reinstalls.
	var seed: int = today.hash()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed
	var picks: Array[MissionDef] = []
	var pool_copy: Array[MissionDef] = _pool.duplicate()
	for _i in DAILY_PICK:
		if pool_copy.is_empty():
			break
		var idx: int = rng.randi_range(0, pool_copy.size() - 1)
		picks.append(pool_copy[idx])
		pool_copy.remove_at(idx)
	var mission_dicts: Array = []
	for m in picks:
		mission_dicts.append({
			"id": m.id,
			"progress": 0,
			"claimed": false,
		})
	GameState.daily_mission = {
		"date": today,
		"missions": mission_dicts,
		"daily_tech_earned": 0,
	}

# --- Tracking ---

func _on_launch_started() -> void:
	_increment(&"launches", 1)

func _on_launch_completed(_d_id: String) -> void:
	_increment(&"successes", 1)

func _on_stage_succeeded(_idx: int, _chance: float) -> void:
	_stage_streak_today += 1
	_set_max(&"stage_streak", _stage_streak_today)

func _on_stage_failed(_idx: int, _chance: float) -> void:
	_stage_streak_today = 0

func _on_destination_completed(_d_id: String, payload: Dictionary) -> void:
	if bool(payload.get("is_first_clear", false)):
		_increment(&"new_destinations", 1)

# --- Mission progress ---

func _increment(condition: StringName, amount: int) -> void:
	_ensure_today_rolled()
	var changed: bool = false
	for m in GameState.daily_mission.get("missions", []):
		var def: MissionDef = _by_id.get(StringName(m.get("id", "")))
		if def == null or def.condition_id != condition:
			continue
		if bool(m.get("claimed", false)):
			continue
		var p: int = int(m.get("progress", 0)) + amount
		m["progress"] = p
		changed = true
		if p >= def.target:
			_auto_claim(m, def)
	if changed:
		# Persisted on the next autosave; no need to force one for cheap progress ticks.
		pass

## stage_streak uses max-tracking semantics, not accumulation.
func _set_max(condition: StringName, value: int) -> void:
	_ensure_today_rolled()
	for m in GameState.daily_mission.get("missions", []):
		var def: MissionDef = _by_id.get(StringName(m.get("id", "")))
		if def == null or def.condition_id != condition:
			continue
		if bool(m.get("claimed", false)):
			continue
		if value > int(m.get("progress", 0)):
			m["progress"] = value
		if value >= def.target:
			_auto_claim(m, def)

func _auto_claim(m: Dictionary, def: MissionDef) -> void:
	if bool(m.get("claimed", false)):
		return
	m["claimed"] = true
	# Daily TechLevel cap: cut the grant to whatever fits under the cap.
	var earned: int = int(GameState.daily_mission.get("daily_tech_earned", 0))
	var room: int = max(0, MISSION_DAILY_TECH_CAP - earned)
	var grant: int = min(def.reward_tech_level, room)
	if grant > 0:
		GameState.add_tech_level(grant)
		GameState.daily_mission["daily_tech_earned"] = earned + grant

# --- Internals ---

func _load_pool() -> void:
	var dir: DirAccess = DirAccess.open(MISSIONS_DIR)
	if dir == null:
		push_warning("[Mission] no missions dir at %s" % MISSIONS_DIR)
		return
	for f in dir.get_files():
		if not f.ends_with(".tres"):
			continue
		var m: MissionDef = load(MISSIONS_DIR.path_join(f)) as MissionDef
		if m == null:
			continue
		_pool.append(m)
		_by_id[StringName(m.id)] = m
	print("[Mission] loaded %d definitions" % _pool.size())
