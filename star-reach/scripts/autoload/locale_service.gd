extends Node

## Loads CSV translations at runtime and registers them with TranslationServer,
## bypassing Godot's editor-driven CSV-import pipeline (which requires an
## `.import` file + reimport pass to generate per-locale `.translation` files).
##
## CSV format: first row is the header `keys,<locale1>,<locale2>,...`; each
## subsequent row is `<key>,<value1>,<value2>,...`. Quoted fields with embedded
## delimiters or newlines are handled by FileAccess.get_csv_line().
##
## Registered at boot order: EventBus → LocaleService → GameState → …, so any
## autoload can call `tr()` safely. The saved language is applied by SaveSystem
## after load so the user's chosen locale takes effect before the first scene.

const CSV_PATH: String = "res://locale/strings.csv"

func _ready() -> void:
	_load_translations()

func _load_translations() -> void:
	var f: FileAccess = FileAccess.open(CSV_PATH, FileAccess.READ)
	if f == null:
		push_warning("[Locale] missing translation CSV at %s" % CSV_PATH)
		return
	var header: PackedStringArray = f.get_csv_line()
	if header.size() < 2:
		push_warning("[Locale] CSV header missing locale columns")
		return
	var locales: Array[String] = []
	for i in range(1, header.size()):
		locales.append(String(header[i]))
	var translations: Array[Translation] = []
	for locale in locales:
		var t: Translation = Translation.new()
		t.locale = locale
		translations.append(t)
	var row_count: int = 0
	while not f.eof_reached():
		var row: PackedStringArray = f.get_csv_line()
		if row.size() < 2:
			continue
		var key: String = String(row[0])
		if key.is_empty() or key == "keys":
			continue
		for i in range(locales.size()):
			var col: int = i + 1
			var value: String = String(row[col]) if col < row.size() else key
			translations[i].add_message(StringName(key), value)
		row_count += 1
	for t in translations:
		TranslationServer.add_translation(t)
	print("[Locale] loaded %d keys × %d locales (%s)" % [row_count, translations.size(), ", ".join(locales)])
