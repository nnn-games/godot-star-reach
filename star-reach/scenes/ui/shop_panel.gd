class_name ShopPanel
extends PopupPanel

## Phase 6a storefront. Lists all IAPProduct resources with Buy buttons.
## Purchase goes through IAPService.buy(sku) → backend (Mock on desktop dev,
## Steam / GPGS on real builds) → GameState._on_iap_purchase_completed applies
## grants. The panel only shows status feedback; it owns no economy state.
##
## Non-consumable products show OWNED once entitled and disable Buy.

const OWNED_DIM: Color = Color(0.5, 0.53, 0.66, 1)
const ACCENT_GOLD: Color = Color(0.941, 0.725, 0.369, 1)
const FAIL_RED: Color = Color(0.89, 0.37, 0.37, 1)

@onready var _progress: Label = %ProgressLabel
@onready var _list: VBoxContainer = %ListVBox
@onready var _restore_button: Button = %RestoreButton
@onready var _close: Button = %CloseButton

func _ready() -> void:
	_close.pressed.connect(_on_close)
	_restore_button.pressed.connect(_on_restore_pressed)
	IAPService.purchase_completed.connect(_on_purchase_completed)
	IAPService.purchase_failed.connect(_on_purchase_failed)
	IAPService.restore_completed.connect(_on_restore_completed)
	_refresh()

func _refresh() -> void:
	_progress.text = "" if IAPService.is_ready() else tr("SHOP_BACKEND_NOT_READY")
	for child in _list.get_children():
		child.queue_free()
	for p in IAPService.get_all_products():
		_list.add_child(_build_row(p))

func _build_row(product: IAPProduct) -> Control:
	var row: VBoxContainer = VBoxContainer.new()
	row.add_theme_constant_override("separation", 4)

	var header: HBoxContainer = HBoxContainer.new()
	row.add_child(header)

	var name_label: Label = Label.new()
	name_label.text = tr(product.display_name)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 18)
	header.add_child(name_label)

	var price_label: Label = Label.new()
	price_label.text = product.fallback_price
	price_label.add_theme_font_size_override("font_size", 14)
	header.add_child(price_label)

	var desc_label: Label = Label.new()
	desc_label.text = tr(product.description)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_font_size_override("font_size", 13)
	row.add_child(desc_label)

	var buy_button: Button = Button.new()
	buy_button.custom_minimum_size = Vector2(0, 42)
	buy_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(buy_button)

	_configure_buy(buy_button, product, name_label, desc_label)
	return row

## Non-consumable / subscription / DLC items show OWNED + disabled if entitled.
## Consumables always allow repurchase.
func _configure_buy(btn: Button, product: IAPProduct, name_label: Label, desc_label: Label) -> void:
	var non_consumable: bool = product.kind != IAPProduct.Kind.CONSUMABLE
	var owned: bool = non_consumable and GameState.iap_non_consumable.has(String(product.sku))
	if owned:
		btn.text = tr("SHOP_OWNED")
		btn.disabled = true
		name_label.modulate = OWNED_DIM
		desc_label.modulate = OWNED_DIM
	else:
		btn.text = tr("SHOP_BUY")
		btn.disabled = false
		btn.pressed.connect(_on_buy_pressed.bind(product))

func _on_buy_pressed(product: IAPProduct) -> void:
	IAPService.buy(product.sku)

func _on_purchase_completed(product: IAPProduct, _receipt: Dictionary) -> void:
	_progress.text = tr("SHOP_PURCHASE_SUCCESS_FMT") % tr(product.display_name)
	_progress.modulate = ACCENT_GOLD
	_refresh()

func _on_purchase_failed(sku: StringName, reason: String) -> void:
	_progress.text = tr("SHOP_PURCHASE_FAILED_FMT") % ("%s (%s)" % [String(sku), reason])
	_progress.modulate = FAIL_RED

func _on_restore_pressed() -> void:
	IAPService.restore()

func _on_restore_completed(_owned: Array) -> void:
	_refresh()

func _on_close() -> void:
	hide()
	queue_free()
