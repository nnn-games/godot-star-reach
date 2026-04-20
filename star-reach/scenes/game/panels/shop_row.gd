extends PanelContainer

## Single product row in the shop. Subscribes to IAPService to reflect
## entitlement changes (e.g., hides Buy after remove_ads is granted).

@onready var _name: Label = %Name
@onready var _desc: Label = %Desc
@onready var _price: Label = %Price
@onready var _buy_btn: Button = %BuyBtn
@onready var _owned_label: Label = %OwnedLabel

var _product: IAPProduct

func bind(product: IAPProduct) -> void:
	_product = product
	_name.text = product.display_name
	_desc.text = product.description
	_price.text = product.fallback_price
	_buy_btn.pressed.connect(_on_buy)
	IAPService.purchase_completed.connect(_on_purchase_completed)
	IAPService.products_fetched.connect(_on_products_fetched)
	_refresh_entitlement()

func _on_buy() -> void:
	_buy_btn.disabled = true
	_buy_btn.text = "..."
	IAPService.buy(_product.sku)

func _on_purchase_completed(product: IAPProduct, _receipt: Dictionary) -> void:
	if product.sku == _product.sku:
		_refresh_entitlement()
	_buy_btn.text = "Buy"
	_buy_btn.disabled = false

func _on_products_fetched(products: Dictionary) -> void:
	var info: Dictionary = products.get(_product.sku, {})
	var p: String = str(info.get("price", ""))
	if not p.is_empty():
		_price.text = p

func _refresh_entitlement() -> void:
	var owns: bool = IAPService.is_entitled(_product.sku)
	_owned_label.visible = owns and _product.kind != IAPProduct.Kind.CONSUMABLE
	_buy_btn.visible = not _owned_label.visible
