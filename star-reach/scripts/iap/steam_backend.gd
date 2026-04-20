class_name SteamIAPBackend
extends IAPBackend

## Wraps GodotSteam GDExtension (addons/godotsteam/).
##
## Steam has two purchase paths:
##   - DLC (IAPProduct.Kind.DLC): passive ownership. We check via isDLCInstalled()
##     and open the store overlay when purchase() is called so the user completes
##     the buy flow in Steam. The "purchase_completed" is deferred until
##     isDLCInstalled becomes true (polled on overlay close, or detected on next launch).
##   - Consumables / MicroTransactions: REQUIRE a server calling Steam WebAPI
##     InitTxn / FinalizeTxn. This backend does NOT implement that — integrate
##     your own server and emit purchase_completed from there. See README.
##
## Uses Engine.get_singleton("Steam") exclusively to avoid parse-time failures
## on platforms where the GodotSteam GDExtension is not loaded (mobile).

const PLUGIN_SINGLETON: String = "Steam"

var _steam: Object = null
var _dlc_by_sku: Dictionary[StringName, int] = {}  # sku -> app_id, populated by IAPService

func initialize() -> void:
	if not Engine.has_singleton(PLUGIN_SINGLETON):
		push_warning("[IAP/Steam] Steam singleton missing; backend inactive")
		ready_state_changed.emit(false)
		return
	_steam = Engine.get_singleton(PLUGIN_SINGLETON)
	# GodotSteam 4.14+ returns a bool. Older versions returned a Dictionary.
	var init_result: Variant = _steam.call("steamInit")
	var ok: bool = (typeof(init_result) == TYPE_BOOL and init_result) \
		or (typeof(init_result) == TYPE_DICTIONARY and int(init_result.get("status", 1)) == 1)
	if not ok:
		push_warning("[IAP/Steam] steamInit failed (Steam client not running?); falling back")
		ready_state_changed.emit(false)
		return
	ready_state_changed.emit(true)

## Called by IAPService after catalog load so we know which SKUs are DLCs.
func register_dlc_mapping(catalog: Array) -> void:
	for p: IAPProduct in catalog:
		if p.kind == IAPProduct.Kind.DLC and p.steam_dlc_app_id > 0:
			_dlc_by_sku[p.sku] = p.steam_dlc_app_id

func query_products(_skus: PackedStringArray) -> void:
	# Steam prices are displayed on the store page; no direct product lookup
	# for consumables without server. Emit empty so callers can proceed.
	products_fetched.emit({})

func purchase(sku: StringName, product_kind: int) -> void:
	if _steam == null:
		purchase_failed.emit(sku, "Steam not initialized")
		return
	match product_kind:
		IAPProduct.Kind.DLC:
			var app_id: int = _dlc_by_sku.get(sku, 0)
			if app_id == 0:
				purchase_failed.emit(sku, "No steam_dlc_app_id set for %s" % sku)
				return
			# Open the Steam store overlay for this DLC. The user completes
			# the buy flow externally; ownership becomes observable via
			# isDLCInstalled on next check.
			_steam.call("activateGameOverlayToStore", app_id, 0)
			# Optimistic: we emit completion if ownership is already true
			# (e.g., user returns to game after buying).
			if is_entitled(sku):
				purchase_completed.emit(sku, { "sku": sku, "platform": "steam", "dlc_app_id": app_id })
		IAPProduct.Kind.CONSUMABLE, IAPProduct.Kind.SUBSCRIPTION, IAPProduct.Kind.NON_CONSUMABLE:
			purchase_failed.emit(sku, "Steam consumables need a server-side MicroTransaction flow; see scripts/iap/README.md")

func restore_purchases() -> void:
	var owned: PackedStringArray = []
	for sku in _dlc_by_sku:
		if is_entitled(sku):
			owned.append(sku)
	restore_completed.emit(owned)

func is_entitled(sku: StringName) -> bool:
	if _steam == null: return false
	var app_id: int = _dlc_by_sku.get(sku, 0)
	if app_id == 0: return false
	return bool(_steam.call("isDLCInstalled", app_id))
