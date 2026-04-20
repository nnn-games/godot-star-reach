class_name IOSIAPBackend
extends IAPBackend

## Wraps the hrk4649/godot_ios_plugin_iap plugin.
## The plugin exposes a single generic request/response API:
##   iap.request(request_name: String, data: Dictionary) -> int
##   iap.response signal → _on_response(name: String, data: Dictionary)

const PLUGIN_SINGLETON: String = "IOSInAppPurchase"

var _iap: Object = null
var _owned: Dictionary[StringName, bool] = {}

func initialize() -> void:
	if not Engine.has_singleton(PLUGIN_SINGLETON):
		push_warning("[IAP/iOS] IOSInAppPurchase singleton missing; backend inactive")
		ready_state_changed.emit(false)
		return
	_iap = Engine.get_singleton(PLUGIN_SINGLETON)
	_iap.connect("response", Callable(self, "_on_response"))
	_iap.request("startUpdateTask", {})
	_iap.request("proceedUnfinishedTransactions", {})
	ready_state_changed.emit(true)

func query_products(skus: PackedStringArray) -> void:
	if _iap == null: return
	_iap.request("products", { "productIDs": Array(skus) })

func purchase(sku: StringName, _product_kind: int) -> void:
	if _iap == null:
		purchase_failed.emit(sku, "iOS IAP plugin not initialized")
		return
	var r: int = int(_iap.request("purchase", { "productID": str(sku) }))
	if r != 0:
		purchase_failed.emit(sku, "iOS purchase request rejected (code %d)" % r)

func restore_purchases() -> void:
	if _iap == null: return
	_iap.request("appStoreSync", {})

func is_entitled(sku: StringName) -> bool:
	return _owned.get(sku, false)

# --- Signal handler ---

func _on_response(response_name: String, data: Dictionary) -> void:
	match response_name:
		"products":
			var result: Dictionary = {}
			for p in data.get("products", []):
				var sku: StringName = StringName(p.get("productIdentifier", ""))
				result[sku] = {
					"title": p.get("localizedTitle", ""),
					"price": p.get("localizedPrice", ""),
					"description": p.get("localizedDescription", ""),
				}
			products_fetched.emit(result)
		"purchase":
			var tx_state: String = str(data.get("state", ""))
			var sku: StringName = StringName(data.get("productID", ""))
			if tx_state == "purchased" or tx_state == "restored":
				_owned[sku] = true
				purchase_completed.emit(sku, {
					"sku": sku,
					"transaction_id": data.get("transactionIdentifier", ""),
					"receipt_data": data.get("appStoreReceipt", ""),
				})
			elif tx_state == "failed":
				purchase_failed.emit(sku, str(data.get("error", "unknown")))
		"transactionCurrentEntitlements", "purchasedProducts", "appStoreSync":
			var owned: PackedStringArray = []
			for t in data.get("transactions", []):
				var sku: StringName = StringName(t.get("productID", ""))
				_owned[sku] = true
				owned.append(sku)
			restore_completed.emit(owned)
