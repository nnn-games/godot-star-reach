extends Node

## Phase 5d localization smoke. Confirms the CSV is imported, a representative
## sample of keys translate for both locales, and unknown keys fall through to
## the key itself (so a missing string shows as BOGUS_KEY — not empty).

const SAMPLES: Dictionary = {
	"MENU_PLAY":            {"ko": "플레이", "en": "Play"},
	"MENU_NEW_GAME":        {"ko": "새 게임", "en": "New Game"},
	"MENU_QUIT":            {"ko": "종료", "en": "Quit"},
	"LAUNCH_BUTTON":        {"ko": "발사", "en": "LAUNCH"},
	"SETTINGS_SFX_VOLUME":  {"ko": "효과음 볼륨", "en": "SFX Volume"},
	"OFFLINE_TITLE":        {"ko": "다시 오신 것을 환영합니다!", "en": "Welcome back!"},
	"ABORT_RETRY":          {"ko": "재시도", "en": "Try Again"},
	"BTN_CONTINUE":         {"ko": "계속", "en": "Continue"},
}

var _failures: int = 0

func _ready() -> void:
	print("== Phase 5d localization smoke ==")
	_run()
	if _failures > 0:
		printerr("FAILED: %d issue(s)" % _failures)
		get_tree().quit(1)
	else:
		print("PASSED")
		get_tree().quit(0)

func _run() -> void:
	for locale in ["ko", "en"]:
		TranslationServer.set_locale(locale)
		for key in SAMPLES:
			var expected: String = SAMPLES[key][locale]
			var got: String = tr(key)
			_expect(got == expected,
				"[%s] tr(%s) = %s  (expected %s)" % [locale, key, got, expected])

	# Unknown keys fall through so missing strings are obvious in-game rather than blank.
	_expect(tr("DEFINITELY_NOT_A_KEY") == "DEFINITELY_NOT_A_KEY",
		"unknown key falls through to itself")

	# Multi-line translation (quoted CSV value) preserves the embedded newline.
	TranslationServer.set_locale("ko")
	_expect(tr("CONFIRM_NEW_GAME_BODY").contains("\n"),
		"CONFIRM_NEW_GAME_BODY preserves embedded newline (multi-line CSV)")

func _expect(cond: bool, msg: String) -> void:
	if cond:
		print("  ok: %s" % msg)
	else:
		_failures += 1
		printerr("  FAIL: %s" % msg)
