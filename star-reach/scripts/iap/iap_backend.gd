@abstract
class_name IAPBackend
extends Node

## Abstract base for platform-specific IAP backends.
## Subclasses wrap a native store SDK (Google Play Billing, StoreKit, Steam)
## and translate its calls/signals to this uniform interface.
##
## Backends are Nodes so they can own child nodes (e.g., Android's BillingClient
## is a Node) and subscribe to engine signals. IAPService instantiates exactly
## one backend per run and adds it as its own child.

## Emitted when backend init completes. Consumers should wait for this before
## calling query_products / purchase.
signal ready_state_changed(is_ready: bool)

## Emitted on successful purchase with a platform receipt for server validation.
## receipt keys (typical): "sku", "transaction_id", plus one of:
##   Android: "purchase_token", "signature"
##   iOS: "receipt_data" (base64)
##   Steam: "order_id" (for MTX), or none for DLC
signal purchase_completed(sku: StringName, receipt: Dictionary)

signal purchase_failed(sku: StringName, reason: String)

## List of non-consumable / subscription SKUs the user still owns.
signal restore_completed(owned_skus: PackedStringArray)

## products keyed by sku → { "title", "price", "description" }
signal products_fetched(products: Dictionary)

@abstract func initialize() -> void
@abstract func query_products(skus: PackedStringArray) -> void
@abstract func purchase(sku: StringName, product_kind: int) -> void
@abstract func restore_purchases() -> void

## True if the user currently owns the sku (non-consumable/subscription only).
## Consumables always return false — they're granted and then "consumed".
@abstract func is_entitled(sku: StringName) -> bool
