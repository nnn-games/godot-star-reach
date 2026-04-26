extends Node

## Headless Phase 5b check: every placeholder sfx id synthesizes a valid cached
## stream, buses exist, and volume setters don't crash.
##
## Run:
##   godot --path star-reach --headless res://scripts/tests/smoke_sound_service.tscn

const SFX_IDS: Array[StringName] = [
	&"sfx_launch", &"sfx_stage_pass", &"sfx_stage_fail",
	&"sfx_clear", &"sfx_abort", &"sfx_badge", &"sfx_codex", &"sfx_button",
]

var _failures: int = 0

func _ready() -> void:
	print("== Phase 5b SoundService smoke ==")
	await _run()
	if _failures > 0:
		printerr("FAILED: %d issue(s)" % _failures)
		get_tree().quit(1)
	else:
		print("PASSED")
		get_tree().quit(0)

func _run() -> void:
	await get_tree().process_frame  # let autoloads finish _ready

	# Buses from default_bus_layout.tres
	_expect(AudioServer.get_bus_index(&"Master") >= 0, "Master bus exists")
	_expect(AudioServer.get_bus_index(&"BGM") >= 0, "BGM bus exists")
	_expect(AudioServer.get_bus_index(&"SFX") >= 0, "SFX bus exists")

	# Each placeholder id must synthesize & cache without error.
	for id in SFX_IDS:
		SoundService.play_sfx(id)
	await get_tree().process_frame

	# Volume setters: 0 mutes, 1 unmutes, mid range updates dB.
	SoundService.set_sfx_volume(0.0)
	_expect(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"SFX")),
		"sfx_volume=0 mutes the bus")
	SoundService.set_sfx_volume(0.5)
	_expect(not AudioServer.is_bus_mute(AudioServer.get_bus_index(&"SFX")),
		"sfx_volume=0.5 unmutes the bus")
	_expect(is_equal_approx(GameState.settings["sfx_volume"], 0.5),
		"sfx_volume persisted to GameState.settings")

	SoundService.set_bgm_volume(0.7)
	_expect(is_equal_approx(GameState.settings["bgm_volume"], 0.7),
		"bgm_volume persisted to GameState.settings")

	# Event-driven playback exercises the hooked paths (no crashes = pass).
	EventBus.launch_started.emit()
	EventBus.stage_succeeded.emit(1, 0.5)
	EventBus.stage_failed.emit(1, 0.5)
	EventBus.launch_completed.emit("D_001")
	EventBus.abort_triggered.emit(100)
	EventBus.badge_awarded.emit("BADGE_REGION_EARTH")
	EventBus.codex_entry_unlocked.emit("REGION_EARTH_OVERVIEW")
	await get_tree().process_frame
	print("  event hooks fired without error")

func _expect(cond: bool, msg: String) -> void:
	if cond:
		print("  ok: %s" % msg)
	else:
		_failures += 1
		printerr("  FAIL: %s" % msg)
