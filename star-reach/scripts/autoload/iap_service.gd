extends Node

## Game-agnostic IAP facade. Selects a backend by OS + plugin presence,
## loads the product catalog from res://data/iap/, and re-emits backend signals
## with IAPProduct objects (not raw SKUs) so game code gets the grants payload.
##
## USAGE (game code):
##   IAPService.purchase_completed.connect(_on_purchase)
##   IAPService.buy(&"pack_coins_small")
##
##   func _on_purchase(product: IAPProduct, receipt: Dictionary):
##       var grants: Dictionary = product.grants
##       if grants.has("currency"): ...
##       if grants.has("flags"): ...

signal ready_state_changed(is_ready: bool)
signal purchase_completed(product: IAPProduct, receipt: Dictionary)
signal purchase_failed(sku: StringName, reason: String)
signal restore_completed(owned_products: Array)
signal products_fetched(products: Dictionary)

const PRODUCT_DIR: String = "res://data/iap/"

var _backend: IAPBackend
var _catalog: Dictionary[StringName, IAPProduct] = {}
var _is_ready: bool = false

func _ready() -> void:
	_scan_catalog()
	_install_backend(_select_backend())

func _install_backend(backend: IAPBackend) -> void:
	_backend = backend
	add_child(_backend)
	_wire_backend_signals()
	if _backend is SteamIAPBackend:
		(_backend as SteamIAPBackend).register_dlc_mapping(_catalog.values())
	_backend.initialize()

func buy(sku: StringName) -> void:
	var product: IAPProduct = _catalog.get(sku)
	if product == null:
		purchase_failed.emit(sku, "SKU not in catalog: %s" % sku)
		return
	_backend.purchase(sku, product.kind)

func restore() -> void:
	_backend.restore_purchases()

func is_ready() -> bool:
	return _is_ready

func is_entitled(sku: StringName) -> bool:
	return _backend.is_entitled(sku)

func get_product(sku: StringName) -> IAPProduct:
	return _catalog.get(sku)

func get_all_products() -> Array[IAPProduct]:
	var arr: Array[IAPProduct] = []
	for v in _catalog.values():
		arr.append(v)
	return arr

# --- Internals ---

func _scan_catalog() -> void:
	var dir: DirAccess = DirAccess.open(PRODUCT_DIR)
	if dir == null:
		push_warning("[IAP] no %s dir; catalog empty" % PRODUCT_DIR)
		return
	for f in dir.get_files():
		if not f.ends_with(".tres"):
			continue
		var r: Resource = load(PRODUCT_DIR.path_join(f))
		if r is IAPProduct:
			_catalog[r.sku] = r
		else:
			push_warning("[IAP] skipped non-IAPProduct: %s" % f)
	print("[IAP] loaded %d products from %s" % [_catalog.size(), PRODUCT_DIR])

func _select_backend() -> IAPBackend:
	match OS.get_name():
		"Android":
			if Engine.has_singleton("GodotGooglePlayBilling"):
				return AndroidIAPBackend.new()
		"iOS":
			if Engine.has_singleton("IOSInAppPurchase"):
				return IOSIAPBackend.new()
		"Windows", "macOS", "Linux":
			if Engine.has_singleton("Steam"):
				return SteamIAPBackend.new()
	return MockIAPBackend.new()

func _wire_backend_signals() -> void:
	_backend.ready_state_changed.connect(_on_ready_changed)
	_backend.purchase_completed.connect(_on_backend_purchase_completed)
	_backend.purchase_failed.connect(purchase_failed.emit)
	_backend.restore_completed.connect(_on_restore_completed)
	_backend.products_fetched.connect(products_fetched.emit)

func _on_ready_changed(is_ready_state: bool) -> void:
	_is_ready = is_ready_state
	ready_state_changed.emit(is_ready_state)
	if is_ready_state:
		_backend.query_products(PackedStringArray(_catalog.keys()))
		return
	# Backend failed to initialize — fall back to Mock so the game stays playable.
	if not (_backend is MockIAPBackend):
		push_warning("[IAP] Native backend init failed; swapping to Mock")
		_swap_to_mock()

func _swap_to_mock() -> void:
	if _backend != null:
		_backend.queue_free()
		_backend = null
	_install_backend(MockIAPBackend.new())

func _on_backend_purchase_completed(sku: StringName, receipt: Dictionary) -> void:
	var product: IAPProduct = _catalog.get(sku)
	if product == null:
		push_warning("[IAP] purchase_completed for unknown sku: %s" % sku)
		return
	# Hook point: server-side receipt validation would go here. See README.
	purchase_completed.emit(product, receipt)

func _on_restore_completed(owned_skus: PackedStringArray) -> void:
	var owned_products: Array[IAPProduct] = []
	for sku in owned_skus:
		var p: IAPProduct = _catalog.get(StringName(sku))
		if p != null:
			owned_products.append(p)
	restore_completed.emit(owned_products)
