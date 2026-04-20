class_name IAPProduct
extends Resource

## Game-agnostic product definition for In-App Purchases.
## The SAME .tres files can power any game — the `grants` Dictionary is
## interpreted by the consuming game code via IAPService.purchase_completed.
##
## Register the SAME `sku` in every store backend (Play Console / App Store
## Connect / Steam partner) so one .tres maps to one purchase across platforms.

enum Kind {
	CONSUMABLE,       ## One-shot, repurchasable (e.g., coin pack)
	NON_CONSUMABLE,   ## Permanent entitlement (e.g., remove ads)
	SUBSCRIPTION,     ## Recurring
	DLC,              ## Steam-only: DLC ownership via isDLCInstalled
}

@export var sku: StringName
@export var kind: Kind = Kind.CONSUMABLE

@export var display_name: String
@export_multiline var description: String

## Fallback price string when store product details haven't loaded yet.
@export var fallback_price: String = ""

## Steam-only: DLC AppID for isDLCInstalled() checks. Ignored on other platforms.
@export var steam_dlc_app_id: int = 0

## Game-specific reward payload. The IAP module does NOT interpret this —
## the consuming game reads it in the `purchase_completed` signal handler.
## Example convention (games define their own):
##   { "currency": { "coin": 1000 }, "flags": ["ads_removed"] }
@export var grants: Dictionary = {}
