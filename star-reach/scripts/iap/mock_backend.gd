class_name MockIAPBackend
extends IAPBackend

## In-memory stub backend — purchases succeed after a short delay.
## Used when no native plugin is available (desktop dev, first-run, CI).
## Keeps non-consumable entitlements across the session but loses them on quit.

const SIMULATED_LATENCY_SEC: float = 0.3

var _entitled: Dictionary[StringName, bool] = {}

func initialize() -> void:
	print("[IAP] Mock backend active (no native purchases)")
	ready_state_changed.emit(true)

func query_products(skus: PackedStringArray) -> void:
	var result: Dictionary = {}
	for sku in skus:
		result[sku] = {
			"title": str(sku),
			"price": "mock",
			"description": "",
		}
	products_fetched.emit(result)

func purchase(sku: StringName, kind: int) -> void:
	await get_tree().create_timer(SIMULATED_LATENCY_SEC).timeout
	if kind == IAPProduct.Kind.NON_CONSUMABLE or kind == IAPProduct.Kind.SUBSCRIPTION or kind == IAPProduct.Kind.DLC:
		_entitled[sku] = true
	var receipt: Dictionary = {
		"sku": sku,
		"transaction_id": "mock-%d" % Time.get_unix_time_from_system(),
		"mock": true,
	}
	purchase_completed.emit(sku, receipt)

func restore_purchases() -> void:
	var owned: PackedStringArray = []
	for sku in _entitled:
		if _entitled[sku]:
			owned.append(sku)
	restore_completed.emit(owned)

func is_entitled(sku: StringName) -> bool:
	return _entitled.get(sku, false)
