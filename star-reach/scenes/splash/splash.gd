extends Control

## Splash screen. Holds for min_display_time then transitions to main menu.
## Phase 0 keeps this minimal. Phase 2 will add ResourceLoader.load_threaded_request
## for background asset warmup (see study/splash_and_async_loading.md).

@export_file("*.tscn") var next_scene_path: String = "res://scenes/main_menu/main_menu.tscn"
@export var min_display_time_sec: float = 1.5

func _ready() -> void:
	await get_tree().create_timer(min_display_time_sec).timeout
	get_tree().change_scene_to_file(next_scene_path)
