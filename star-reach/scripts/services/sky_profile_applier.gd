class_name SkyProfileApplier
extends Node

## Maps a Destination's region_id to a SkyProfile and drives the SkyLayer
## transition Tween. MainScreen injects the SkyLayer reference on _ready.
## See docs/systems/4-2-sky-transition.md.

const PROFILES_DIR: String = "res://data/sky_profiles/"
const TRANSITION_SEC: float = 2.0

## Injected by MainScreen.
var sky_layer: SkyLayer

var _by_region: Dictionary[StringName, SkyProfile] = {}
var _current: SkyProfile

func _ready() -> void:
	_load_profiles()

# --- Public API ---

## Snap to the destination's sky without animation. Used on boot.
func apply_immediate(d: Destination) -> void:
	var p: SkyProfile = _profile_for(d)
	if p == null or sky_layer == null:
		return
	_current = p
	sky_layer.apply_immediate(p)

## Tween to the destination's sky over TRANSITION_SEC. No-op if same profile.
func transition_to(d: Destination) -> void:
	var p: SkyProfile = _profile_for(d)
	if p == null or sky_layer == null:
		return
	if p == _current:
		return
	_current = p
	sky_layer.transition_to(p, TRANSITION_SEC)

# --- Internals ---

func _profile_for(d: Destination) -> SkyProfile:
	if d == null:
		return null
	return _by_region.get(StringName(d.region_id))

func _load_profiles() -> void:
	var dir: DirAccess = DirAccess.open(PROFILES_DIR)
	if dir == null:
		push_error("[SkyApplier] cannot open %s" % PROFILES_DIR)
		return
	for f in dir.get_files():
		if not f.ends_with(".tres"):
			continue
		var p: SkyProfile = load(PROFILES_DIR.path_join(f)) as SkyProfile
		if p == null or p.region_id.is_empty():
			push_warning("[SkyApplier] skipped %s (not a SkyProfile or missing region_id)" % f)
			continue
		_by_region[StringName(p.region_id)] = p
	print("[SkyApplier] loaded %d profiles" % _by_region.size())
