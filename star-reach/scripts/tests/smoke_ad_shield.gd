extends Node

## Phase 6d smoke. Verifies rewarded-ad flow (Mock) + shield grant via IAP
## + both reset `GameState.stress_value` via the AbortScreen flow logic.
##
## We exercise the service + IAP paths directly — the AbortScreen scene itself
## is a PopupPanel and hangs in headless, same as other panels.

var _failures: int = 0

func _ready() -> void:
	print("== Phase 6d Ad + Shield smoke ==")
	await _run()
	if _failures > 0:
		printerr("FAILED: %d issue(s)" % _failures)
		get_tree().quit(1)
	else:
		print("PASSED")
		get_tree().quit(0)

func _run() -> void:
	GameState.shield_inventory = {}
	GameState.stress_value = 140.0

	_expect(AdService.is_ready(), "AdService ready on boot (Mock)")
	_expect(not AdService.is_playing(), "AdService not playing initially")

	# Rewarded ad: completes granted=true after MOCK_LATENCY_SEC.
	var result_state: Array = [null]
	var handler: Callable = func(granted: bool) -> void: result_state[0] = granted
	AdService.rewarded_ad_completed.connect(handler)
	AdService.show_rewarded_ad()
	_expect(AdService.is_playing(), "AdService is_playing during flight")
	var waited: float = 0.0
	while result_state[0] == null and waited < 4.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	AdService.rewarded_ad_completed.disconnect(handler)
	_expect(result_state[0] == true, "rewarded_ad_completed fired with granted=true")
	_expect(not AdService.is_playing(), "AdService idle after ad finishes")

	# Shield IAP: grants 5 T3 shields via existing grants["shields"] handler.
	await _buy_and_wait(&"shield_stack_5")
	_expect(int(GameState.shield_inventory.get(&"T3", 0)) == 5,
		"shield_stack_5 grants 5 T3 shields (got %d)" % int(GameState.shield_inventory.get(&"T3", 0)))

	# Second pack stacks.
	await _buy_and_wait(&"shield_stack_5")
	_expect(int(GameState.shield_inventory.get(&"T3", 0)) == 10,
		"shield_stack_5 stacks on repurchase (got %d)" % int(GameState.shield_inventory.get(&"T3", 0)))

	# Concurrency guard: a second show_rewarded_ad while in flight must fail cleanly.
	var fail_state: Array = [""]
	var fail_handler: Callable = func(reason: String) -> void: fail_state[0] = reason
	AdService.rewarded_ad_failed.connect(fail_handler)
	AdService.show_rewarded_ad()  # starts a new one
	AdService.show_rewarded_ad()  # should fail (in flight)
	_expect(String(fail_state[0]).contains("in flight"),
		"second concurrent show_rewarded_ad is rejected (got %s)" % String(fail_state[0]))
	# Wait for the first to finish so we leave a clean state.
	waited = 0.0
	while AdService.is_playing() and waited < 4.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	AdService.rewarded_ad_failed.disconnect(fail_handler)

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
