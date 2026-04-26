extends Node

## SFX + BGM. Auto-subscribes to EventBus audio cues; the rest of the game
## just emits signals and hears sound.
##
## Asset strategy: `play_sfx(id)` first tries `res://assets/audio/sfx/<id>.{ogg,wav}`.
## If missing, it synthesizes a procedural placeholder once and caches it — so
## F5 has audible feedback before real assets land, and dropping a real file
## into `res://assets/audio/sfx/` transparently overrides the placeholder.
##
## Volumes are stored in `GameState.settings["sfx_volume"|"bgm_volume"]` as linear
## 0..1 floats; this service converts to dB and applies to the bus. Setters
## persist back through GameState so the settings panel just calls here.

const SFX_DIR: String = "res://assets/audio/sfx/"
const BGM_DIR: String = "res://assets/audio/bgm/"
const SFX_EXTENSIONS: Array[String] = [".ogg", ".wav"]
const SFX_POOL_SIZE: int = 8

# Procedural synthesis: short, calm, mobile-friendly. Frequencies intentionally
# below 1kHz so they stay pleasant even without mastering.
const SYNTH_MIX_RATE: int = 22050

enum Shape { TONE, SWEEP_UP, SWEEP_DOWN, CHORD, NOISE_BURST }

var _sfx_pool: Array[AudioStreamPlayer] = []
var _bgm_player: AudioStreamPlayer
var _next_sfx: int = 0
var _stream_cache: Dictionary[StringName, AudioStream] = {}

# Default procedural descriptors — overridden transparently by real asset drops.
# (shape, param_a, param_b, duration_sec, gain)
var _procedural: Dictionary[StringName, Array] = {
	&"sfx_launch":        [Shape.SWEEP_UP,    220.0, 440.0, 0.35, 0.55],
	&"sfx_stage_pass":    [Shape.SWEEP_UP,    440.0, 660.0, 0.18, 0.50],
	&"sfx_stage_fail":    [Shape.SWEEP_DOWN,  440.0, 180.0, 0.26, 0.55],
	&"sfx_clear":         [Shape.CHORD,       523.25, 784.0, 0.55, 0.45],
	&"sfx_abort":         [Shape.NOISE_BURST, 0.0,   0.0,   0.45, 0.60],
	&"sfx_badge":         [Shape.SWEEP_UP,    880.0, 1320.0, 0.22, 0.40],
	&"sfx_codex":         [Shape.CHORD,       659.26, 987.77, 0.35, 0.35],
	&"sfx_button":        [Shape.TONE,        660.0, 0.0,   0.06, 0.30],
}

func _ready() -> void:
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.bus = &"BGM"
	add_child(_bgm_player)
	for i in SFX_POOL_SIZE:
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.bus = &"SFX"
		add_child(p)
		_sfx_pool.append(p)
	# Restore volumes from GameState (already loaded by SaveSystem per autoload order).
	_apply_bus_volume(&"SFX", float(GameState.settings.get("sfx_volume", 1.0)))
	_apply_bus_volume(&"BGM", float(GameState.settings.get("bgm_volume", 1.0)))
	# Hook game events.
	EventBus.launch_started.connect(_on_launch_started)
	EventBus.stage_succeeded.connect(_on_stage_succeeded)
	EventBus.stage_failed.connect(_on_stage_failed)
	EventBus.launch_completed.connect(_on_launch_completed)
	EventBus.abort_triggered.connect(_on_abort_triggered)
	EventBus.badge_awarded.connect(_on_badge_awarded)
	EventBus.codex_entry_unlocked.connect(_on_codex_entry_unlocked)

# --- Public API ---

func play_sfx(id: StringName) -> void:
	var stream: AudioStream = _get_or_make_stream(id, true)
	if stream == null:
		return
	# Round-robin across the pool so overlapping cues don't cut each other off.
	var player: AudioStreamPlayer = _sfx_pool[_next_sfx]
	_next_sfx = (_next_sfx + 1) % _sfx_pool.size()
	player.stream = stream
	player.play()

func play_bgm(id: StringName) -> void:
	var stream: AudioStream = _get_or_make_stream(id, false)
	if stream == null:
		_bgm_player.stop()
		return
	if _bgm_player.stream == stream and _bgm_player.playing:
		return
	_bgm_player.stream = stream
	_bgm_player.play()

func stop_bgm() -> void:
	_bgm_player.stop()

## Linear 0..1. Persists into GameState.settings so SaveSystem captures it.
func set_sfx_volume(linear: float) -> void:
	linear = clamp(linear, 0.0, 1.0)
	GameState.settings["sfx_volume"] = linear
	_apply_bus_volume(&"SFX", linear)

func set_bgm_volume(linear: float) -> void:
	linear = clamp(linear, 0.0, 1.0)
	GameState.settings["bgm_volume"] = linear
	_apply_bus_volume(&"BGM", linear)

func get_sfx_volume() -> float:
	return float(GameState.settings.get("sfx_volume", 1.0))

func get_bgm_volume() -> float:
	return float(GameState.settings.get("bgm_volume", 1.0))

# --- Internals ---

func _apply_bus_volume(bus_name: StringName, linear: float) -> void:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx < 0:
		push_warning("[Sound] unknown bus %s — check default_bus_layout.tres" % bus_name)
		return
	# Mute the bus at 0 rather than -80dB so silence is silent (avoids click-on-unmute).
	if linear <= 0.0001:
		AudioServer.set_bus_mute(idx, true)
		return
	AudioServer.set_bus_mute(idx, false)
	AudioServer.set_bus_volume_db(idx, linear_to_db(linear))

func _get_or_make_stream(id: StringName, is_sfx: bool) -> AudioStream:
	if _stream_cache.has(id):
		return _stream_cache[id]
	var dir: String = SFX_DIR if is_sfx else BGM_DIR
	for ext in SFX_EXTENSIONS:
		var path: String = dir + String(id) + ext
		if ResourceLoader.exists(path):
			var s: AudioStream = load(path) as AudioStream
			if s != null:
				_stream_cache[id] = s
				return s
	if not is_sfx:
		return null  # no procedural BGM — silence until assets land
	var desc: Array = _procedural.get(id, [])
	if desc.is_empty():
		return null
	var stream: AudioStreamWAV = _synthesize(desc)
	_stream_cache[id] = stream
	return stream

func _synthesize(desc: Array) -> AudioStreamWAV:
	var shape: int = desc[0]
	var a: float = desc[1]
	var b: float = desc[2]
	var dur: float = desc[3]
	var gain: float = desc[4]
	var n: int = int(dur * SYNTH_MIX_RATE)
	var data: PackedByteArray = PackedByteArray()
	data.resize(n * 2)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 0xA1FA
	for i in n:
		var t: float = float(i) / SYNTH_MIX_RATE
		var env: float = _envelope(t, dur)
		var sample: float = 0.0
		match shape:
			Shape.TONE:
				sample = sin(TAU * a * t)
			Shape.SWEEP_UP, Shape.SWEEP_DOWN:
				# Linear frequency sweep from a → b over duration.
				var f: float = lerp(a, b, t / dur)
				sample = sin(TAU * f * t)
			Shape.CHORD:
				# Root + fifth for a bright resolve.
				sample = 0.5 * (sin(TAU * a * t) + sin(TAU * b * t))
			Shape.NOISE_BURST:
				sample = rng.randf_range(-1.0, 1.0)
		var pcm: int = clamp(int(sample * env * gain * 32000.0), -32767, 32767)
		data.encode_s16(i * 2, pcm)
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SYNTH_MIX_RATE
	wav.stereo = false
	wav.data = data
	return wav

## Quick attack, gentle linear decay. Keeps beeps from clicking on start.
func _envelope(t: float, dur: float) -> float:
	const ATTACK: float = 0.01
	if t < ATTACK:
		return t / ATTACK
	var remaining: float = dur - ATTACK
	if remaining <= 0.0:
		return 1.0
	return clamp(1.0 - (t - ATTACK) / remaining, 0.0, 1.0)

# --- Event hooks ---

func _on_launch_started() -> void:
	play_sfx(&"sfx_launch")

func _on_stage_succeeded(_stage_index: int, _chance: float) -> void:
	play_sfx(&"sfx_stage_pass")

func _on_stage_failed(_stage_index: int, _chance: float) -> void:
	play_sfx(&"sfx_stage_fail")

func _on_launch_completed(_d_id: String) -> void:
	# launch_completed only fires on SUCCESS (LaunchService._finalize branch);
	# failures go through stage_failed only.
	play_sfx(&"sfx_clear")

func _on_abort_triggered(_repair_cost: int) -> void:
	play_sfx(&"sfx_abort")

func _on_badge_awarded(_badge_id: String) -> void:
	play_sfx(&"sfx_badge")

func _on_codex_entry_unlocked(_entry_id: String) -> void:
	play_sfx(&"sfx_codex")
