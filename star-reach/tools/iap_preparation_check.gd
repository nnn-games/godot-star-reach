@tool
extends SceneTree

## IAP 준비 상태 진단. F5 없이 헤드리스로 "지금 어디까지 준비됐나"를 점검.
## 실행:
##   godot --path star-reach --headless --script res://tools/iap_preparation_check.gd
## 종료 코드: 0 = 준비 완료, 1 = 미비 항목 있음.

const REPORT_WIDTH: int = 72

var _sections: Array[Dictionary] = []
var _current: Dictionary = {}

func _init() -> void:
	_section("Plugin files (AI가 다운로드 완료한 상태)")
	_check("Android — GodotGooglePlayBilling plugin.cfg",
		FileAccess.file_exists("res://addons/GodotGooglePlayBilling/plugin.cfg"))
	_check("Android — release .aar bundled",
		FileAccess.file_exists("res://addons/GodotGooglePlayBilling/bin/release/GodotGooglePlayBilling-release.aar"))
	_check("iOS — ios-in-app-purchase.gdip",
		FileAccess.file_exists("res://ios/plugins/ios-in-app-purchase/ios-in-app-purchase.gdip"))
	_check("iOS — xcframework (release)",
		DirAccess.dir_exists_absolute(ProjectSettings.globalize_path("res://ios/plugins/ios-in-app-purchase/ios-in-app-purchase.release.xcframework")))
	_check("Steam — godotsteam.gdextension",
		FileAccess.file_exists("res://addons/godotsteam/godotsteam.gdextension"))
	_check("Steam — Windows x64 binary",
		FileAccess.file_exists("res://addons/godotsteam/win64/libgodotsteam.windows.template_release.x86_64.dll"))
	_check("Steam — steam_appid.txt (development)",
		FileAccess.file_exists("res://steam_appid.txt"))

	_section("project.godot configuration")
	var cfg: ConfigFile = ConfigFile.new()
	var loaded: bool = (cfg.load("res://project.godot") == OK)
	_check("project.godot readable", loaded)
	if loaded:
		_check("Autoload IAPService registered",
			cfg.has_section_key("autoload", "IAPService"))
		_check("Autoload GameState registered",
			cfg.has_section_key("autoload", "GameState"))
		var plugins: PackedStringArray = cfg.get_value("editor_plugins", "enabled", PackedStringArray())
		_check("Android plugin enabled (EditorPlugin)",
			plugins.has("res://addons/GodotGooglePlayBilling/plugin.cfg"))
		_check("Android Gradle custom build",
			cfg.get_value("android", "gradle_build/use_gradle_build", false) == true)
		_check("Portrait orientation (handheld)",
			cfg.get_value("display", "window/handheld/orientation", "") == 1)

	_section("IAP module files (game-agnostic)")
	_check("scripts/iap/iap_backend.gd",
		FileAccess.file_exists("res://scripts/iap/iap_backend.gd"))
	_check("scripts/iap/mock_backend.gd",
		FileAccess.file_exists("res://scripts/iap/mock_backend.gd"))
	_check("scripts/iap/android_backend.gd",
		FileAccess.file_exists("res://scripts/iap/android_backend.gd"))
	_check("scripts/iap/ios_backend.gd",
		FileAccess.file_exists("res://scripts/iap/ios_backend.gd"))
	_check("scripts/iap/steam_backend.gd",
		FileAccess.file_exists("res://scripts/iap/steam_backend.gd"))
	_check("scripts/iap/README.md (reuse guide)",
		FileAccess.file_exists("res://scripts/iap/README.md"))
	_check("scripts/resources/iap_product.gd",
		FileAccess.file_exists("res://scripts/resources/iap_product.gd"))
	_check("scripts/autoload/iap_service.gd",
		FileAccess.file_exists("res://scripts/autoload/iap_service.gd"))

	_section("Product catalog (game-specific — edit per game)")
	var dir: DirAccess = DirAccess.open("res://data/iap/")
	var products: PackedStringArray = []
	if dir != null:
		for f in dir.get_files():
			if f.ends_with(".tres"):
				products.append(f)
	_check("data/iap/ folder present", dir != null)
	_check("At least one IAPProduct .tres", products.size() > 0,
		"found %d: %s" % [products.size(), ", ".join(products)])

	_section("UI integration")
	_check("Shop panel scene",
		FileAccess.file_exists("res://scenes/game/panels/shop_panel.tscn"))
	_check("Shop row prefab",
		FileAccess.file_exists("res://scenes/game/panels/shop_row.tscn"))

	_section("Android build environment")
	_check("Android build template extracted (build.gradle)",
		FileAccess.file_exists("res://android/build/build.gradle"))
	_check("Gradle wrapper present",
		FileAccess.file_exists("res://android/build/gradlew"))

	_print_report()
	quit(0 if _all_ok() else 1)

# --- Helpers ---

func _section(title: String) -> void:
	if not _current.is_empty():
		_sections.append(_current)
	_current = { "title": title, "items": [] }

func _check(label: String, ok: bool, detail: String = "") -> void:
	_current.items.append({ "label": label, "ok": ok, "detail": detail })

func _all_ok() -> bool:
	_flush_current()
	for s in _sections:
		for item in s.items:
			if not item.ok:
				return false
	return true

func _flush_current() -> void:
	if not _current.is_empty() and not _sections.has(_current):
		_sections.append(_current)
		_current = {}

func _print_report() -> void:
	_flush_current()
	print(_line("="))
	print("  StarReach — IAP Preparation Check")
	print(_line("="))
	var total_ok: int = 0
	var total: int = 0
	for s in _sections:
		print("")
		print("  %s" % s.title)
		print("  %s" % _line("-", s.title.length() + 2))
		for item in s.items:
			var mark: String = "[OK]" if item.ok else "[--]"
			var line: String = "  %s  %s" % [mark, item.label]
			if not item.detail.is_empty():
				line += "   (%s)" % item.detail
			print(line)
			total += 1
			if item.ok: total_ok += 1
	print("")
	print(_line("="))
	print("  RESULT: %d / %d checks passed" % [total_ok, total])
	if total_ok == total:
		print("  STATUS: Ready — Mock backend will serve all purchases.")
		print("")
		print("  Remaining steps (account / infra — not auto-checkable):")
		print("   - Android: Google Play Console account + SKU registration")
		print("   - iOS:     macOS + Xcode build environment + Apple Developer")
		print("   - Steam:   Steamworks Partner + real AppID to replace 480")
		print("   - Server:  Receipt validation endpoint (Firebase/Nakama/self)")
	else:
		print("  STATUS: Incomplete — fix [--] items above.")
	print(_line("="))

func _line(ch: String, width: int = REPORT_WIDTH) -> String:
	var s: String = ""
	for i in width:
		s += ch
	return s
