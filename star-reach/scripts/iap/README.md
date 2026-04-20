# IAP Module — Reusable across Godot 4 Projects

This folder (`scripts/iap/`) plus `scripts/resources/iap_product.gd` and
`scripts/autoload/iap_service.gd` is **game-agnostic**. Drop it into any
Godot 4.4+ project and the Mock backend works immediately. Replace Mock with
real platform backends by installing the corresponding plugin.

## What lives where

```
scripts/iap/
├── iap_backend.gd         @abstract base (uniform interface)
├── mock_backend.gd        In-memory stub (works everywhere, no plugins)
├── android_backend.gd     Wraps GodotGooglePlayBilling plugin
├── ios_backend.gd         Wraps hrk4649/godot_ios_plugin_iap plugin
├── steam_backend.gd       Wraps GodotSteam GDExtension
└── README.md              (this file)

scripts/resources/iap_product.gd   IAPProduct Custom Resource (Scriptable Object)
scripts/autoload/iap_service.gd    Facade autoload — OS dispatch + catalog + grants relay

data/iap/*.tres                    Your game's product catalog (edit per game)
```

## Copying to a new project

1. Copy the three files above verbatim.
2. Register `IAPService` as Autoload in `project.godot`:
   ```ini
   [autoload]
   IAPService="*res://scripts/autoload/iap_service.gd"
   ```
3. Create `data/iap/` and drop your product `.tres` files. Each `.tres` is a
   `IAPProduct` with a unique `sku` and game-specific `grants` Dictionary.
4. In your `GameState` (or equivalent), subscribe to `IAPService.purchase_completed`:
   ```gdscript
   IAPService.purchase_completed.connect(_on_purchase)

   func _on_purchase(product: IAPProduct, receipt: Dictionary) -> void:
       var grants := product.grants
       if grants.has("currency"):
           for c_id in grants.currency:
               add_currency(StringName(c_id), grants.currency[c_id])
       if grants.has("flags"):
           for key in grants.flags:
               set_flag(StringName(key), true)
   ```
5. Mock backend is automatic when no native plugin is loaded. F5 and buy.

That's it. No other edits required for cross-platform readiness.

## Activating real platform backends

### Android — Google Play Billing

- Install [godot-sdk-integrations/godot-google-play-billing](https://github.com/godot-sdk-integrations/godot-google-play-billing) into `addons/GodotGooglePlayBilling/`
- Enable in `project.godot [editor_plugins]`:
  ```
  enabled=PackedStringArray("res://addons/GodotGooglePlayBilling/plugin.cfg")
  ```
- Set `[android] gradle_build/use_gradle_build=true`
- Install Android Build Template (editor: Project → Install Android Build Template)
- Register the same `sku` values in Play Console as in-app products

### iOS — StoreKit

- Install [hrk4649/godot_ios_plugin_iap](https://github.com/hrk4649/godot_ios_plugin_iap) into `ios/plugins/ios-in-app-purchase/`
- Enable in iOS Export preset → Options → Plugins
- Build on macOS with Xcode
- Register the same `sku` values in App Store Connect

### Steam — GodotSteam GDExtension

- Install [GodotSteam GDExtension](https://codeberg.org/godotsteam/godotsteam/releases) into `addons/godotsteam/`
- Place `steam_appid.txt` in project root (`480` for dev testing; real AppID for ship)
- **DLC mode** (recommended for non-consumables): register DLC AppIDs in Steamworks,
  set `steam_dlc_app_id` on the corresponding `IAPProduct.tres`, set `kind = DLC`
- **Consumable mode (MicroTransactions)** requires a game server using Steam
  WebAPI `InitTxn`/`FinalizeTxn`. This module does NOT implement that. See:
  https://partner.steamgames.com/doc/features/microtransactions

## Server-side receipt validation (SECURITY CRITICAL)

Client-side IAP is inherently spoofable on rooted/jailbroken devices.
**Do not grant paid content in production without server-side validation.**

`IAPService._on_backend_purchase_completed` is the hook point — extend it to POST
`{ platform, sku, receipt }` to your server BEFORE emitting `purchase_completed`,
and the server validates against:

- Google Play Developer API (`androidpublisher.purchases.products.get`)
- App Store (`verifyReceipt` or StoreKit 2 JWS verification)
- Steam WebAPI (`ISteamMicroTxn/FinalizeTxn`)

Options:
- Firebase Cloud Functions (free tier, minimal code)
- Nakama (open-source game server)
- [flobuk/godot-receiptvalidator](https://github.com/flobuk/godot-receiptvalidator) SaaS
- Self-hosted Node/Go/Python endpoint

## IAPProduct.grants Dictionary convention (per game)

The IAP module treats `grants` as opaque — it's interpreted by game code.
StarReach example:
```gdscript
grants = {
    "currency": { "coin": 1000.0, "gem": 5.0 },  # add to balances
    "flags": ["ads_removed", "premium_theme"],    # set boolean flags
}
```

Other games might use `{ "unlock_character": "wizard", "bonus_percent": 10 }`
etc. Document your convention in your project's README.

## Limitations / known gotchas

- Steam consumables require a server (see above).
- iOS plugin (`hrk4649`) uses StoreKit 1 — subscription state detection is
  limited. Migrate to an OpenIAP/StoreKit 2 plugin when available.
- After adding new `class_name` resources, Godot's global class cache needs
  a one-time populate: `godot --editor --headless --quit-after 4`.
- GodotSteam's `Steam.steamInit()` call requires the Steam client to be running;
  SteamBackend handles init failure gracefully (emits `ready_state_changed(false)`).

## License

This module: same license as the host game project.
Bundled plugins: see each plugin's own license file.
