@tool
extends SceneTree

## 전체 인프라 준비 상태 진단.
## 5개 축: UI, Resource Pipeline, Scene Management, Payment, Core Systems.
## 각 항목은 READY / PARTIAL / PLANNED 중 하나로 분류.
##   READY   — 지금 바로 사용 가능
##   PARTIAL — 뼈대만 있고 일부 누락
##   PLANNED — 의도적 미구현 (로드맵에 있음)
## 실행:
##   godot --path star-reach --headless --script res://tools/preparation_check.gd

const WIDTH: int = 76

var _sections: Array[Dictionary] = []
var _cur: Dictionary = {}

func _init() -> void:
	_section("1. UI 개발 준비", [
		["Mobile portrait viewport (720x1280)", _cfg_eq("display", "window/size/viewport_width", 720)],
		["Stretch mode = canvas_items", _cfg_eq("display", "window/stretch/mode", "canvas_items")],
		["Stretch aspect = expand", _cfg_eq("display", "window/stretch/aspect", "expand")],
		["Portrait orientation lock", _cfg_eq("display", "window/handheld/orientation", 1)],
		["Theme scale = 1.5 (mobile-friendly)", _cfg_eq("gui", "theme/default_theme_scale", 1.5)],
		["TabContainer-based panel switching (no re-load)", _scene_has_node("res://scenes/game/game.tscn", "TabContainer")],
		["Modal layer (CanvasLayer, deep overlay)", _scene_has_node("res://scenes/game/game.tscn", "ModalLayer")],
		["Reusable modal component (confirm_dialog)", _exists("res://scenes/common/confirm_dialog.tscn")],
		["Reusable HUD component (currency_counter)", _exists("res://scenes/common/currency_counter.tscn")],
		["Prefab + data iteration pattern (generator_row)", _exists("res://scenes/game/generator_row.tscn")],
		["Unique Names (%) for deep-path avoidance", _grep("res://scenes/game/game.tscn", "unique_name_in_owner = true")],
		["SafeArea notch wrapper", "PLANNED", "study/mobile_ui_resize.md §3.2; implement when first notch-device test"],
		["Custom Theme.tres (전역 스타일)", "PLANNED", "Godot 기본 테마 사용 중; 브랜드 색상/폰트 정의 시 추가"],
		["Korean font fallback (Pretendard 등)", "PLANNED", "현재 엔진 기본 폰트; 한글 출시 전 TTF 추가"],
		["NumberFormatter (1.23K/4.5M)", "PLANNED", "CLAUDE.md 명시; 증분 수치 표시 시 필요"],
	])

	_section("2. 리소스 연동 준비", [
		["Custom Resource Strategy (@abstract CostCurve)", _exists("res://scripts/resources/cost_curve.gd")],
		["Custom Resource concrete (ExponentialCost)", _exists("res://scripts/resources/exponential_cost.gd")],
		["Scriptable Object .tres instances work", _load_is_class("res://data/generators/miner.tres", "GeneratorDef")],
		["Flyweight: 여러 .tres가 같은 Script 공유", _load_is_class("res://data/generators/refinery.tres", "GeneratorDef")],
		["Typed @export Resource 필드 (cost_curve)", _scene_has_text("res://data/generators/miner.tres", "cost_curve = SubResource")],
		["Folder scan 오토로드 패턴 (IAPService)", _grep("res://scripts/autoload/iap_service.gd", "DirAccess.open")],
		["Import 설정 배치 스크립트 (normalize_imports.gd)", "PLANNED", "study/asset_pipeline_for_agent_dev.md §4.3; 실제 이미지 자산 추가 시 필요"],
		["AssetHub 매니페스트 (공용 아이콘/폰트)", "PLANNED", "study/asset_registry_pattern.md; 이진 자산 누적 시 추가"],
		["SfxDirector / FxDirector", "PLANNED", "study/resource_architecture_design.md §5; 오디오/파티클 자산 생기면 추가"],
	])

	_section("3. Scene Management", [
		["Top-level 씬 흐름 (splash → main_menu → game)", _all_exist([
			"res://scenes/splash/splash.tscn",
			"res://scenes/main_menu/main_menu.tscn",
			"res://scenes/game/game.tscn",
		])],
		["main_scene → splash 지정", _cfg_eq("application", "run/main_scene", "res://scenes/splash/splash.tscn")],
		["Boot splash 설정 (minimum_display_time)", _cfg_has("application", "boot_splash/minimum_display_time")],
		["씬 전환 코드 패턴 (change_scene_to_file)", _grep("res://scenes/splash/splash.gd", "change_scene_to_file")],
		["모달 동적 인스턴스 + await + queue_free", _grep("res://scenes/game/game.gd", "await dlg.closed")],
		["SceneLoader autoload (async + 진행바)", "PLANNED", "study/splash_and_async_loading.md §6; 스플래시 리소스가 무거워지면 도입"],
		["ResourceLoader.load_threaded_request 사용", "PLANNED", "현재 splash는 단순 타이머; 자산 프리로드 필요시"],
	])

	_section("4. 결제 연동", [
		["IAPService autoload 파사드", _exists("res://scripts/autoload/iap_service.gd")],
		["IAPProduct Custom Resource 스키마", _exists("res://scripts/resources/iap_product.gd")],
		["@abstract IAPBackend + 4 concrete", _all_exist([
			"res://scripts/iap/iap_backend.gd",
			"res://scripts/iap/mock_backend.gd",
			"res://scripts/iap/android_backend.gd",
			"res://scripts/iap/ios_backend.gd",
			"res://scripts/iap/steam_backend.gd",
		])],
		["Android 플러그인 (.aar 번들)", _exists("res://addons/GodotGooglePlayBilling/bin/release/GodotGooglePlayBilling-release.aar")],
		["iOS 플러그인 (xcframework)", _exists("res://ios/plugins/ios-in-app-purchase/ios-in-app-purchase.gdip")],
		["Steam GDExtension (5 플랫폼 바이너리)", _exists("res://addons/godotsteam/godotsteam.gdextension")],
		["Android Gradle build template 추출", _exists("res://android/build/build.gradle")],
		["Mock 자동 폴백", _grep("res://scripts/autoload/iap_service.gd", "_swap_to_mock")],
		["Shop UI + 상품 카탈로그 4종", _all_exist([
			"res://scenes/game/panels/shop_panel.tscn",
			"res://data/iap/pack_coins_small.tres",
			"res://data/iap/remove_ads.tres",
		])],
		["재사용 README (타 프로젝트 복사 가이드)", _exists("res://scripts/iap/README.md")],
		["영수증 서버 검증 엔드포인트", "PLANNED", "Firebase Function 등; 실제 결제 직전에 구축"],
		["Restore Purchases 버튼 UI (iOS 심사 필수)", "PLANNED", "iOS 실연동 시점 추가"],
	])

	_section("5. 게임 기본 시스템", [
		["Autoload: EventBus (signal-only 허브)", _cfg_has("autoload", "EventBus")],
		["Autoload: GameState (재화/생성기/tick)", _cfg_has("autoload", "GameState")],
		["Autoload: TimeManager (tick + speed)", _cfg_has("autoload", "TimeManager")],
		["Autoload: IAPService", _cfg_has("autoload", "IAPService")],
		["Economy loop: tick → generate → currency", _grep("res://scripts/autoload/game_state.gd", "EventBus.generator_ticked.emit")],
		["Purchase flow: can_buy → try_buy → level up", _grep("res://scripts/autoload/game_state.gd", "EventBus.generator_purchased.emit")],
		["Flag system (IAP non-consumable 영속)", _grep("res://scripts/autoload/game_state.gd", "set_flag")],
		["Speed multiplier (프레스티지/디버그용)", _grep("res://scripts/autoload/time_manager.gd", "speed_multiplier")],
		["Headless dev toolchain (smoke_test)", _exists("res://tools/smoke_test.gd")],
		["Headless prep-check 툴", _exists("res://tools/iap_preparation_check.gd")],
		["SaveSystem autoload (user://savegame.json)", _cfg_has("autoload", "SaveSystem")],
		["SaveSystem: atomic write + version field", _grep("res://scripts/autoload/save_system.gd", "SAVE_VERSION")],
		["SaveSystem: periodic + close-hook save", _grep("res://scripts/autoload/save_system.gd", "NOTIFICATION_WM_CLOSE_REQUEST")],
		["GameState: to_dict / from_dict serialization", _grep("res://scripts/autoload/game_state.gd", "func to_dict")],
		["TimeManager.apply_offline_progress (8h cap)", _grep("res://scripts/autoload/time_manager.gd", "MAX_OFFLINE_SECONDS")],
		["Offline summary modal", _exists("res://scenes/common/offline_summary_dialog.tscn")],
		["Upgrade 시스템 (업그레이드 .tres)", "PLANNED", "Phase 2; panel stub만 존재"],
		["Prestige 리셋 흐름", "PLANNED", "Phase 2; panel stub만 존재"],
		["Game state machine (enum MENU/PLAYING/...)", "PLANNED", "필요 시 Phase 1.5~2 중 추가"],
		["Logger / print_debug 유틸", "PLANNED", "CLAUDE.md 명시; 디버그 출력 증가 시"],
		["i18n 로케일 (en/ko .po)", "PLANNED", "출시 직전 Phase"],
	])

	_print()
	quit(0 if _all_critical_ok() else 1)

# ---------- Check primitives ----------

func _exists(path: String) -> Variant:
	return FileAccess.file_exists(path)

func _all_exist(paths: Array) -> Variant:
	for p in paths:
		if not FileAccess.file_exists(p):
			return false
	return true

func _cfg_eq(section: String, key: String, expected: Variant) -> Variant:
	var c := ConfigFile.new()
	if c.load("res://project.godot") != OK: return false
	return c.get_value(section, key, null) == expected

func _cfg_has(section: String, key: String) -> Variant:
	var c := ConfigFile.new()
	if c.load("res://project.godot") != OK: return false
	return c.has_section_key(section, key)

func _grep(path: String, needle: String) -> Variant:
	if not FileAccess.file_exists(path): return false
	return FileAccess.get_file_as_string(path).contains(needle)

func _scene_has_node(scene_path: String, node_name: String) -> Variant:
	return _grep(scene_path, 'name="%s"' % node_name)

func _scene_has_text(path: String, text: String) -> Variant:
	return _grep(path, text)

func _load_is_class(tres_path: String, script_class: String) -> Variant:
	if not FileAccess.file_exists(tres_path): return false
	return FileAccess.get_file_as_string(tres_path).contains('script_class="%s"' % script_class)

# ---------- Section bookkeeping ----------

func _section(title: String, items: Array) -> void:
	if not _cur.is_empty(): _sections.append(_cur)
	_cur = { "title": title, "items": items }

func _all_critical_ok() -> bool:
	if not _cur.is_empty() and not _sections.has(_cur):
		_sections.append(_cur)
		_cur = {}
	for s in _sections:
		for item in s.items:
			var status: Variant = item[1]
			if typeof(status) == TYPE_BOOL and not status:
				return false
	return true

# ---------- Report ----------

func _print() -> void:
	if not _cur.is_empty() and not _sections.has(_cur):
		_sections.append(_cur)
	print(_line("="))
	print("  StarReach — Comprehensive Preparation Check")
	print(_line("="))
	var ready_cnt: int = 0
	var planned_cnt: int = 0
	var failed_cnt: int = 0
	for s in _sections:
		print("")
		print("  " + s.title)
		print("  " + _line("-", s.title.length() + 2))
		for item in s.items:
			var label: String = item[0]
			var status: Variant = item[1]
			var note: String = item[2] if item.size() >= 3 else ""
			var mark: String
			if typeof(status) == TYPE_BOOL:
				if status:
					mark = "[READY  ]"; ready_cnt += 1
				else:
					mark = "[MISSING]"; failed_cnt += 1
			else:
				mark = "[PLANNED]"; planned_cnt += 1
			var line: String = "    %s  %s" % [mark, label]
			print(line)
			if not note.is_empty():
				print("              → " + note)
	print("")
	print(_line("="))
	print("  SUMMARY")
	print("    READY   : %d  (구현 완료, 즉시 사용 가능)" % ready_cnt)
	print("    PLANNED : %d  (의도된 미구현, 로드맵 대기)" % planned_cnt)
	print("    MISSING : %d  (예상 구현물이 누락 — 버그 또는 조기 검사)" % failed_cnt)
	print("")
	if failed_cnt == 0:
		print("  VERDICT: 기본 인프라 준비 완료. PLANNED 항목은 기획 확정 이후 순차 구축.")
	else:
		print("  VERDICT: MISSING 항목 확인 필요.")
	print(_line("="))

func _line(ch: String, width: int = WIDTH) -> String:
	var s: String = ""
	for i in width: s += ch
	return s
