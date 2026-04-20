@tool
extends SceneTree

## Headless smoke test. Runs with:
##   godot --path star-reach --headless --script res://tools/smoke_test.gd
## Exits with non-zero code on any failure so CI can detect it.
##
## KNOWN LIMIT: --script mode does not load Autoload singletons. Scripts that
## reference EventBus / GameState / TimeManager will log "Identifier not found"
## compile errors during _check_scenes. Those are false alarms here — scenes
## still load and instantiate fine, and the real autoload-connected flow is
## verified by booting the game briefly:
##   godot --path star-reach --headless --quit-after 3
## That run triggers all autoload _ready() methods. No errors there = all good.

const SCENES: PackedStringArray = [
	"res://scenes/splash/splash.tscn",
	"res://scenes/main_menu/main_menu.tscn",
	"res://scenes/game/game.tscn",
	"res://scenes/game/generator_row.tscn",
	"res://scenes/game/panels/generator_panel.tscn",
	"res://scenes/game/panels/upgrade_panel.tscn",
	"res://scenes/game/panels/stats_panel.tscn",
	"res://scenes/game/panels/prestige_panel.tscn",
	"res://scenes/game/panels/settings_panel.tscn",
	"res://scenes/game/panels/shop_panel.tscn",
	"res://scenes/game/panels/shop_row.tscn",
	"res://scenes/common/confirm_dialog.tscn",
	"res://scenes/common/currency_counter.tscn",
]

const SCRIPTS: PackedStringArray = [
	"res://scripts/autoload/event_bus.gd",
	"res://scripts/autoload/game_state.gd",
	"res://scripts/autoload/time_manager.gd",
	"res://scripts/autoload/iap_service.gd",
	"res://scripts/resources/cost_curve.gd",
	"res://scripts/resources/exponential_cost.gd",
	"res://scripts/resources/currency_def.gd",
	"res://scripts/resources/generator_def.gd",
	"res://scripts/resources/iap_product.gd",
	"res://scripts/iap/iap_backend.gd",
	"res://scripts/iap/mock_backend.gd",
	"res://scripts/iap/android_backend.gd",
	"res://scripts/iap/ios_backend.gd",
	"res://scripts/iap/steam_backend.gd",
]

const RESOURCES: PackedStringArray = [
	"res://data/currencies/coin.tres",
	"res://data/generators/miner.tres",
	"res://data/generators/refinery.tres",
	"res://data/iap/pack_coins_small.tres",
	"res://data/iap/pack_coins_medium.tres",
	"res://data/iap/pack_coins_large.tres",
	"res://data/iap/remove_ads.tres",
]

var _failures: int = 0

func _init() -> void:
	print("== StarReach smoke test ==")
	_check_scripts()
	_check_resources()
	_check_scenes()
	_check_domain_logic()
	if _failures > 0:
		printerr("FAILED: %d issue(s)" % _failures)
		quit(1)
	else:
		print("OK: %d scenes + %d scripts + %d resources" % [SCENES.size(), SCRIPTS.size(), RESOURCES.size()])
		quit(0)

func _check_scripts() -> void:
	for path in SCRIPTS:
		var s: Script = load(path) as Script
		if s == null:
			_fail("Script load failed: %s" % path)
		else:
			print("  script   ok: %s" % path)

func _check_resources() -> void:
	for path in RESOURCES:
		var r: Resource = load(path)
		if r == null:
			_fail("Resource load failed: %s" % path)
		else:
			print("  resource ok: %s" % path)

func _check_scenes() -> void:
	for path in SCENES:
		var ps: PackedScene = load(path) as PackedScene
		if ps == null:
			_fail("Scene load failed: %s" % path)
			continue
		var inst: Node = ps.instantiate()
		if inst == null:
			_fail("Scene instantiate failed: %s" % path)
			continue
		inst.queue_free()
		print("  scene    ok: %s" % path)

## Phase 1 domain logic sanity check without running a full scene tree.
func _check_domain_logic() -> void:
	var miner: GeneratorDef = load("res://data/generators/miner.tres") as GeneratorDef
	if miner == null:
		_fail("miner cast to GeneratorDef failed")
		return
	if miner.id != &"miner":
		_fail("miner.id wrong: %s" % miner.id)
	if miner.cost_curve == null:
		_fail("miner.cost_curve is null")
		return
	var c0: float = miner.cost_curve.cost_at(0)
	var c1: float = miner.cost_curve.cost_at(1)
	if not is_equal_approx(c0, 10.0):
		_fail("miner cost_at(0) expected 10.0 got %f" % c0)
	if c1 <= c0:
		_fail("miner cost should grow with level, got c0=%f c1=%f" % [c0, c1])
	print("  domain   ok: miner cost_at(0)=%.2f cost_at(1)=%.2f base_rate=%.1f/s" % [c0, c1, miner.base_rate])

func _fail(msg: String) -> void:
	_failures += 1
	printerr("  FAIL: " + msg)
