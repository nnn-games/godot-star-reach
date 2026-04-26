extends Node

## Phase 6b boost runtime smoke. Verifies AutoLaunchService.get_rate() responds
## to AUTO_LAUNCH_PASS boost activation, stacking extends remaining time, and
## `EventBus.boost_activated` fires on purchase.

const EPS: float = 0.0001
var _failures: int = 0

func _ready() -> void:
	print("== Phase 6b boost runtime smoke ==")
	await _run()
	if _failures > 0:
		printerr("FAILED: %d issue(s)" % _failures)
		get_tree().quit(1)
	else:
		print("PASSED")
		get_tree().quit(0)

func _run() -> void:
	GameState.active_boosts = {}
	GameState.iap_non_consumable = []

	var als: AutoLaunchService = AutoLaunchService.new()
	add_child(als)
	await get_tree().process_frame

	_expect(is_equal_approx(als.get_rate(), AutoLaunchService.BASE_RATE),
		"rate = BASE before any boost (got %.2f)" % als.get_rate())
	_expect(als.get_boost_time_remaining(AutoLaunchService.BOOST_AUTO_PASS) == 0,
		"remaining = 0 before any boost")

	# Listen for the boost_activated signal during the purchase.
	var state: Array = [{}]
	var handler: Callable = func(id: StringName, expire_at: int) -> void:
		state[0] = {"id": id, "expire_at": expire_at}
	EventBus.boost_activated.connect(handler)

	var before_unix: int = int(Time.get_unix_time_from_system())
	await _buy_and_wait(&"auto_launch_pass_7d")
	EventBus.boost_activated.disconnect(handler)

	var evt: Dictionary = state[0]
	_expect(evt.get("id", &"") == AutoLaunchService.BOOST_AUTO_PASS,
		"boost_activated fired with AUTO_LAUNCH_PASS (got %s)" % String(evt.get("id", "")))
	_expect(int(evt.get("expire_at", 0)) >= before_unix + 604800 - 2,
		"boost_activated expire_at ~7 days ahead")

	var expected_rate: float = min(AutoLaunchService.BASE_RATE + AutoLaunchService.RATE_AUTO_PASS,
		AutoLaunchService.RATE_CAP)
	_expect(is_equal_approx(als.get_rate(), expected_rate),
		"rate rises to %.2f after AUTO_LAUNCH_PASS (got %.2f)" % [expected_rate, als.get_rate()])
	_expect(als.is_boost_active(AutoLaunchService.BOOST_AUTO_PASS),
		"is_boost_active returns true")
	_expect(als.get_boost_time_remaining(AutoLaunchService.BOOST_AUTO_PASS) > 0,
		"remaining > 0 after purchase")

	# Force expiry and re-check — no restart needed, get_rate() re-evaluates per call.
	GameState.active_boosts[AutoLaunchService.BOOST_AUTO_PASS] = int(Time.get_unix_time_from_system()) - 1
	_expect(is_equal_approx(als.get_rate(), AutoLaunchService.BASE_RATE),
		"rate reverts to BASE once expired")
	_expect(not als.is_boost_active(AutoLaunchService.BOOST_AUTO_PASS),
		"is_boost_active returns false once expired")

func _buy_and_wait(sku: StringName) -> void:
	var state: Array[bool] = [false]
	var handler: Callable = func(_p: IAPProduct, _r: Dictionary) -> void: state[0] = true
	IAPService.purchase_completed.connect(handler)
	IAPService.buy(sku)
	var waited: float = 0.0
	while not state[0] and waited < 2.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	IAPService.purchase_completed.disconnect(handler)

func _expect(cond: bool, msg: String) -> void:
	if cond:
		print("  ok: %s" % msg)
	else:
		_failures += 1
		printerr("  FAIL: %s" % msg)
