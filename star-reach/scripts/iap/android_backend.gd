class_name AndroidIAPBackend
extends IAPBackend

## Wraps the GodotGooglePlayBilling plugin's BillingClient.
## Plugin source: res://addons/GodotGooglePlayBilling/
##
## Lifecycle:
##   initialize() → start_connection() → connected signal → query_products()
##   purchase(sku) → on_purchase_updated → consume/acknowledge per product kind

const PLUGIN_SINGLETON: String = "GodotGooglePlayBilling"
const BILLING_CLIENT_PATH: String = "res://addons/GodotGooglePlayBilling/BillingClient.gd"

var _billing: Node = null
var _owned: Dictionary[StringName, bool] = {}
## Remember kind per purchased sku so we know consume vs acknowledge.
var _pending_kinds: Dictionary[StringName, int] = {}

func initialize() -> void:
	if not Engine.has_singleton(PLUGIN_SINGLETON):
		push_warning("[IAP/Android] GodotGooglePlayBilling singleton missing; backend inactive")
		ready_state_changed.emit(false)
		return
	var billing_client_script: Script = load(BILLING_CLIENT_PATH) as Script
	if billing_client_script == null:
		push_error("[IAP/Android] BillingClient.gd not found at %s" % BILLING_CLIENT_PATH)
		ready_state_changed.emit(false)
		return
	_billing = billing_client_script.new()
	add_child(_billing)
	_billing.connected.connect(_on_connected)
	_billing.disconnected.connect(_on_disconnected)
	_billing.connect_error.connect(_on_connect_error)
	_billing.query_product_details_response.connect(_on_product_details)
	_billing.query_purchases_response.connect(_on_purchases_queried)
	_billing.on_purchase_updated.connect(_on_purchase_updated)
	_billing.consume_purchase_response.connect(_on_consume_response)
	_billing.acknowledge_purchase_response.connect(_on_acknowledge_response)
	_billing.start_connection()

func query_products(skus: PackedStringArray) -> void:
	if _billing == null: return
	_billing.query_product_details(skus, 0)  # 0 = INAPP

func purchase(sku: StringName, product_kind: int) -> void:
	if _billing == null:
		purchase_failed.emit(sku, "Android billing not connected")
		return
	_pending_kinds[sku] = product_kind
	var result: Dictionary = _billing.purchase(str(sku))
	var code: int = int(result.get("status", -1))
	if code != 0:  # BillingResponseCode.OK
		purchase_failed.emit(sku, "Play Billing error %d: %s" % [code, result.get("debug_message", "")])
		_pending_kinds.erase(sku)

func restore_purchases() -> void:
	if _billing == null: return
	_billing.query_purchases(0)  # INAPP

func is_entitled(sku: StringName) -> bool:
	return _owned.get(sku, false)

# --- Signal handlers ---

func _on_connected() -> void:
	ready_state_changed.emit(true)
	restore_purchases()

func _on_disconnected() -> void:
	ready_state_changed.emit(false)

func _on_connect_error(code: int, msg: String) -> void:
	push_error("[IAP/Android] connect error %d: %s" % [code, msg])
	ready_state_changed.emit(false)

func _on_product_details(response: Dictionary) -> void:
	var result: Dictionary = {}
	var details_list: Array = response.get("product_details_list", [])
	for d in details_list:
		var sku: StringName = StringName(d.get("product_id", ""))
		result[sku] = {
			"title": d.get("title", ""),
			"price": d.get("one_time_purchase_offer_details", {}).get("formatted_price", ""),
			"description": d.get("description", ""),
		}
	products_fetched.emit(result)

func _on_purchases_queried(response: Dictionary) -> void:
	var owned: PackedStringArray = []
	for p in response.get("purchases_list", []):
		if int(p.get("purchase_state", 0)) != 1:  # 1 = PURCHASED
			continue
		for pid in p.get("products", []):
			var sku: StringName = StringName(pid)
			_owned[sku] = true
			owned.append(sku)
	restore_completed.emit(owned)

func _on_purchase_updated(response: Dictionary) -> void:
	var code: int = int(response.get("response_code", -1))
	if code != 0:  # Not OK
		var skus: Array = response.get("products", [])
		for pid in skus:
			purchase_failed.emit(StringName(pid), "Play Billing response %d" % code)
		return
	for p in response.get("purchases_list", []):
		if int(p.get("purchase_state", 0)) != 1:  # not yet PURCHASED
			continue
		for pid in p.get("products", []):
			var sku: StringName = StringName(pid)
			var token: String = p.get("purchase_token", "")
			var receipt: Dictionary = {
				"sku": sku,
				"purchase_token": token,
				"signature": p.get("signature", ""),
				"order_id": p.get("order_id", ""),
			}
			_owned[sku] = true
			purchase_completed.emit(sku, receipt)
			var kind: int = _pending_kinds.get(sku, IAPProduct.Kind.CONSUMABLE)
			_pending_kinds.erase(sku)
			if kind == IAPProduct.Kind.CONSUMABLE:
				_billing.consume_purchase(token)
			else:
				_billing.acknowledge_purchase(token)

func _on_consume_response(response: Dictionary) -> void:
	if int(response.get("response_code", -1)) != 0:
		push_warning("[IAP/Android] consume failed: %s" % response)
	# Consumed — remove local entitlement so it can be bought again.
	for pid in response.get("products", []):
		_owned.erase(StringName(pid))

func _on_acknowledge_response(response: Dictionary) -> void:
	if int(response.get("response_code", -1)) != 0:
		push_warning("[IAP/Android] acknowledge failed: %s" % response)
