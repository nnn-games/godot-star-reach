class_name SettingsPanel
extends PopupPanel

## Volume + language settings. Opened from MainMenu and MainScreen.
## Delegates all persistence to SoundService (volumes) and direct
## GameState.settings writes for language; TranslationServer is switched
## live so the Settings panel's own labels update after the CSV lands in
## Phase 5d.

const LANGUAGES: Array = [
	{"locale": "ko", "label": "한국어"},
	{"locale": "en", "label": "English"},
]

const MAIN_MENU_SCENE_PATH: String = "res://scenes/main_menu/main_menu.tscn"

@onready var _sfx_slider: HSlider = %SfxSlider
@onready var _sfx_value: Label = %SfxValueLabel
@onready var _bgm_slider: HSlider = %BgmSlider
@onready var _bgm_value: Label = %BgmValueLabel
@onready var _language_option: OptionButton = %LanguageOption
@onready var _back_to_menu_button: Button = %BackToMenuButton
@onready var _close_button: Button = %CloseButton

func _ready() -> void:
	_sfx_slider.value = SoundService.get_sfx_volume() * 100.0
	_bgm_slider.value = SoundService.get_bgm_volume() * 100.0
	_refresh_volume_labels()
	_populate_languages()
	_sfx_slider.value_changed.connect(_on_sfx_changed)
	_bgm_slider.value_changed.connect(_on_bgm_changed)
	_language_option.item_selected.connect(_on_language_selected)
	_back_to_menu_button.pressed.connect(_on_back_to_menu_pressed)
	_close_button.pressed.connect(_on_close)

# --- Volumes ---

func _on_sfx_changed(v: float) -> void:
	SoundService.set_sfx_volume(v / 100.0)
	_refresh_volume_labels()

func _on_bgm_changed(v: float) -> void:
	SoundService.set_bgm_volume(v / 100.0)
	_refresh_volume_labels()

func _refresh_volume_labels() -> void:
	_sfx_value.text = "%d%%" % int(round(_sfx_slider.value))
	_bgm_value.text = "%d%%" % int(round(_bgm_slider.value))

# --- Language ---

func _populate_languages() -> void:
	_language_option.clear()
	var current: String = String(GameState.settings.get("language", "ko"))
	var selected_idx: int = 0
	for i in LANGUAGES.size():
		var entry: Dictionary = LANGUAGES[i]
		_language_option.add_item(String(entry["label"]), i)
		_language_option.set_item_metadata(i, String(entry["locale"]))
		if String(entry["locale"]) == current:
			selected_idx = i
	_language_option.select(selected_idx)

func _on_language_selected(idx: int) -> void:
	var locale: String = String(_language_option.get_item_metadata(idx))
	GameState.settings["language"] = locale
	# TranslationServer is set here so the CSV pipeline in 5d picks it up;
	# until then this is a no-op aside from the persisted setting.
	TranslationServer.set_locale(locale)

# --- Navigation ---

func _on_back_to_menu_pressed() -> void:
	SaveSystem.save_game()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)

# --- Close ---

func _on_close() -> void:
	SaveSystem.save_game()  # settings changes deserve an immediate persist
	hide()
	queue_free()
