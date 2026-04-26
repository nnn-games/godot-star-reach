extends Node

## Phase 6a IAP smoke. Uses MockIAPBackend (selected automatically on desktop
## without Steam running) to verify end-to-end grants for each catalog kind:
## credit, tech_level, non_consumable flag, time-based boost. Also checks that
## a second purchase of a stacking boost extends expiry rather than resetting.

var _failures: int = 0

func _ready() -> void:
	print("== Phase 6a IAP purchase smoke ==")
	await _run()
	if _failures > 0:
		printerr("FAILED: %d issue(s)" % _failures)
		get_tree().quit(1)
	else:
		print("PASSED")
		get_tree().quit(0)

func _run() -> void:
	# Reset the wallet and IAP state to known baselines.
	GameState.credit = 0
	GameState.tech_level = 0
	GameState.iap_non_consumable = []
	GameState.active_boosts = {}

	_expect(IAPService.get_all_products().size() >= 4,
		"catalog has at least 4 products (got %d)" % IAPService.get_all_products().size())

	# Small credit pack — consumable, grants credit.
	await _buy_and_wait(&"pack_credit_small")
	_expect(GameState.credit == 500, "pack_credit_small grants 500 credit (got %d)" % GameState.credit)

	# Repurchase — consumables stack.
	await _buy_and_wait(&"pack_credit_small")
	_expect(GameState.credit == 1000, "pack_credit_small stacks on repurchase (got %d)" % GameState.credit)

	# Starter pack — non_consumable, grants credit + tech_level.
	await _buy_and_wait(&"starter_pack")
	_expect(GameState.credit == 3000, "starter_pack adds 2000 credit (got %d)" % GameState.credit)
	_expect(GameState.tech_level == 20, "starter_pack adds 20 tech_level (got %d)" % GameState.tech_level)
	_expect(GameState.iap_non_consumable.has("starter_pack"),
		"starter_pack recorded in iap_non_consumable")

	# Remove Ads — non_consumable flag only, no grants beyond entitlement.
	await _buy_and_wait(&"remove_ads")
	_expect(GameState.iap_non_consumable.has("remove_ads"),
		"remove_ads recorded in iap_non_consumable")

	# Auto Launch Pass — 7-day boost; check expiry set.
	var before_unix: int = int(Time.get_unix_time_from_system())
	await _buy_and_wait(&"auto_launch_pass_7d")
	var expiry: int = int(GameState.active_boosts.get(&"AUTO_LAUNCH_PASS", 0))
	_expect(expiry >= before_unix + 604800 - 2,
		"auto_launch_pass_7d sets expiry ~7 days out (expiry=%d, before=%d)" % [expiry, before_unix])

	# Stacking: a second pass should extend expiry by another 7 days, not reset.
	var prev: int = expiry
	await _buy_and_wait(&"auto_launch_pass_7d")
	var stacked: int = int(GameState.active_boosts.get(&"AUTO_LAUNCH_PASS", 0))
	_expect(stacked >= prev + 604800 - 2,
		"boost stacks (prev=%d stacked=%d delta=%d)" % [prev, stacked, stacked - prev])

func _buy_and_wait(sku: StringName) -> void:
	# GDScript lambdas capture locals by value; route the flag through a mutable
	# container so the handler's write is observable from the caller.
	var state: Array[bool] = [false]
	var handler: Callable = func(_p: IAPProduct, _r: Dictionary) -> void: state[0] = true
	IAPService.purchase_completed.connect(handler)
	IAPService.buy(sku)
	var waited: float = 0.0
	while not state[0] and waited < 2.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	IAPService.purchase_completed.disconnect(handler)
	_expect(state[0], "purchase_completed fired for %s" % sku)

func _expect(cond: bool, msg: String) -> void:
	if cond:
		print("  ok: %s" % msg)
	else:
		_failures += 1
		printerr("  FAIL: %s" % msg)
