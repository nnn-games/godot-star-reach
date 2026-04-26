class_name RocketTrack
extends Control

## Phase 7 stage indicator with constant-velocity scroll illusion.
## The rocket is visually fixed at the center of the track with a tiny bob;
## a procedural star field scrolls downward behind it. Velocity has only two
## steady states:
##   idle    (~14 px/s)  — between launches, subtle atmosphere drift
##   launch  (~150 px/s) — engines on: stage transitions do NOT change it
##
## Stage success / failure / completion are intentionally not animated here.
## MainScreen already routes those events into `FlashOverlay` + `ScreenShake`
## global effects, which act as the "camera" — flash, kick, tremor — while
## the rocket itself continues its steady climb. Ticks at the top confirm
## discrete progress; flame cuts off at crash or destination-reached.
##
## Swap points for rocket_journey_animation.md upgrades:
##   - star ColorRects → ParallaxBackground + real star sprites
##   - rocket Panel → AnimatedSprite2D (mk1..mk3 + warp)
##   - background ColorRect → SkyProfile-driven gradient / shader

const ROCKET_SIZE: Vector2 = Vector2(38, 60)
const FLAME_SIZE: Vector2 = Vector2(22, 18)
const TICK_SIZE: Vector2 = Vector2(26, 5)
const STAR_COUNT: int = 60
const STAR_SIZES: Array[int] = [1, 2, 3]   # index = parallax depth (far→near)

const ROCKET_REST_Y_FRAC: float = 0.48     # lower-middle of playable area (clear zone ≈ 0.13–0.77 on 720×1280)
const TICK_ROW_TOP_Y: float = 180.0        # below the top HUD + destination overlay panels
const BOB_AMPLITUDE: float = 3.5
const BOB_HZ: float = 0.55

const SCROLL_IDLE_VELOCITY: float = 40.0
const SCROLL_LAUNCH_VELOCITY: float = 360.0
const VELOCITY_LERP_RATE: float = 6.0       # smooth ignition / engine-cut transitions

const TICK_COLOR_IDLE: Color = Color(0.26, 0.29, 0.42, 1)
const TICK_COLOR_PASS: Color = Color(0.35, 0.85, 0.5, 1)
const TICK_COLOR_FAIL: Color = Color(0.9, 0.3, 0.3, 1)
const ROCKET_COLOR: Color = Color(0.98, 0.78, 0.35, 1)
const FLAME_COLOR: Color = Color(1.0, 0.55, 0.18, 1)

var _rocket: Panel
var _flame: ColorRect
var _ticks: Array[ColorRect] = []
var _stars: Array[Dictionary] = []       # {rect, base_x, base_y, parallax, size, seed_x, seed_y}
var _stage_count: int = 0
var _scroll: float = 0.0
var _target_velocity: float = SCROLL_IDLE_VELOCITY
var _velocity: float = SCROLL_IDLE_VELOCITY
var _elapsed: float = 0.0

func _ready() -> void:
	custom_minimum_size = Vector2(320, 480)
	clip_contents = true
	_build_stars()
	_build_rocket()
	resized.connect(_relayout)
	_relayout()
	set_process(true)

# --- Public API ---

func set_stage_count(n: int) -> void:
	_stage_count = n
	_rebuild_ticks()
	reset()
	if n > 0:
		_target_velocity = SCROLL_LAUNCH_VELOCITY
		_flame.visible = true

func reset() -> void:
	_rocket.modulate = ROCKET_COLOR
	_rocket.rotation = 0.0
	_rocket.scale = Vector2.ONE
	_target_velocity = SCROLL_IDLE_VELOCITY
	_flame.visible = false
	for tick in _ticks:
		tick.color = TICK_COLOR_IDLE

## Stage cleared. Track stays at launch velocity — the camera (FlashOverlay +
## ScreenShake in MainScreen) is the only visual reaction.
func advance_stage(stage_index: int) -> void:
	if stage_index > 0 and stage_index <= _ticks.size():
		_ticks[stage_index - 1].color = TICK_COLOR_PASS

## Stage failed — engines cut. Decelerate to idle drift, flame off, tick red.
## No rocket fall / rotation / tint: the failure "camera" (big red flash +
## heavy shake) is wired from MainScreen.
func crash(stage_index: int) -> void:
	if stage_index > 0 and stage_index <= _ticks.size():
		_ticks[stage_index - 1].color = TICK_COLOR_FAIL
	_flame.visible = false
	_target_velocity = SCROLL_IDLE_VELOCITY

## Destination reached — engines cut. Scroll coasts back to idle.
func complete() -> void:
	_flame.visible = false
	_target_velocity = SCROLL_IDLE_VELOCITY

## Global screen position of the rocket's center — used by MainScreen to spawn
## floating reward / result text anchored to the rocket.
func get_rocket_global_position() -> Vector2:
	if _rocket == null:
		return Vector2.ZERO
	return _rocket.global_position + ROCKET_SIZE * 0.5

# --- Per-frame ---

func _process(delta: float) -> void:
	_elapsed += delta
	_velocity = lerpf(_velocity, _target_velocity, clamp(VELOCITY_LERP_RATE * delta, 0.0, 1.0))
	_scroll += _velocity * delta
	_apply_star_positions()
	_apply_rocket_bob()
	_sync_flame()

func _apply_star_positions() -> void:
	if size.y <= 0.0:
		return
	for s in _stars:
		var rect: ColorRect = s["rect"]
		var y: float = fposmod(float(s["base_y"]) + _scroll * float(s["parallax"]), size.y)
		rect.position = Vector2(float(s["base_x"]), y)

func _apply_rocket_bob() -> void:
	var cx: float = size.x * 0.5
	var base_y: float = size.y * ROCKET_REST_Y_FRAC - ROCKET_SIZE.y * 0.5
	var bob: float = sin(_elapsed * TAU * BOB_HZ) * BOB_AMPLITUDE
	_rocket.position = Vector2(cx - ROCKET_SIZE.x * 0.5, base_y + bob)

# --- Build / layout ---

func _build_stars() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 0xBEEF
	for i in STAR_COUNT:
		var sz_idx: int = rng.randi_range(0, STAR_SIZES.size() - 1)
		var sz: int = STAR_SIZES[sz_idx]
		var parallax: float = lerp(0.4, 1.0, float(sz_idx) / float(max(1, STAR_SIZES.size() - 1)))
		var star: ColorRect = ColorRect.new()
		star.size = Vector2(sz, sz)
		# Bumped alpha range: stars now render over SkyLayer (which varies per
		# destination tier), so they need to stay visible against lighter skies.
		star.color = Color(1.0, 1.0, 1.0, rng.randf_range(0.55, 1.0))
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(star)
		_stars.append({
			"rect": star,
			"base_x": 0.0,
			"base_y": 0.0,
			"parallax": parallax,
			"size": sz,
			"seed_x": rng.randf(),
			"seed_y": rng.randf(),
		})

func _build_rocket() -> void:
	_flame = ColorRect.new()
	_flame.color = FLAME_COLOR
	_flame.size = FLAME_SIZE
	_flame.visible = false
	_flame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flame)

	_rocket = Panel.new()
	_rocket.size = ROCKET_SIZE
	_rocket.custom_minimum_size = ROCKET_SIZE
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color.WHITE
	sb.corner_radius_top_left = 16
	sb.corner_radius_top_right = 16
	sb.corner_radius_bottom_left = 5
	sb.corner_radius_bottom_right = 5
	sb.border_width_bottom = 3
	sb.border_color = Color(0.3, 0.22, 0.1, 1)
	_rocket.add_theme_stylebox_override("panel", sb)
	_rocket.modulate = ROCKET_COLOR
	_rocket.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rocket)

func _rebuild_ticks() -> void:
	for tick in _ticks:
		tick.queue_free()
	_ticks.clear()
	if _stage_count <= 0:
		return
	var total_width: float = _stage_count * TICK_SIZE.x + max(0, _stage_count - 1) * 4.0
	var start_x: float = (size.x - total_width) * 0.5
	var top_y: float = TICK_ROW_TOP_Y
	for i in _stage_count:
		var tick: ColorRect = ColorRect.new()
		tick.size = TICK_SIZE
		tick.color = TICK_COLOR_IDLE
		tick.position = Vector2(start_x + i * (TICK_SIZE.x + 4.0), top_y)
		tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(tick)
		_ticks.append(tick)
	move_child(_rocket, get_child_count() - 1)
	move_child(_flame, get_child_count() - 2)

func _relayout() -> void:
	if _rocket == null:
		return
	for s in _stars:
		s["base_x"] = float(s["seed_x"]) * max(size.x - float(s["size"]), 1.0)
		s["base_y"] = float(s["seed_y"]) * max(size.y - float(s["size"]), 1.0)
	if _stage_count > 0:
		_rebuild_ticks()
	_apply_rocket_bob()

# --- Helpers ---

func _sync_flame() -> void:
	if not _flame.visible:
		return
	_flame.position = Vector2(
		_rocket.position.x + (ROCKET_SIZE.x - FLAME_SIZE.x) * 0.5,
		_rocket.position.y + ROCKET_SIZE.y - 1.0,
	)
