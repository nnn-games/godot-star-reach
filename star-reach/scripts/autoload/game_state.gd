extends Node

## Central mutable game state. Owns the 3-currency wallet (xp / credit / tech_level),
## progression flags (current destination, cleared tiers, completed destinations),
## and per-session ephemeral state. All mutations emit through EventBus so UI
## stays purely reactive.
##
## The 3-currency split is a design contract enforced here:
##   - xp:         session-scoped, resets on destination change, spent on Launch Tech
##   - credit:     permanent, spent on Facility upgrades / Stress repair
##   - tech_level: monotonic, never spent (gate for destination unlock)
## See docs/prd.md §5 and docs/porting/03-economy.md.

# --- Currencies (3-currency model, integer only) ---
var xp: int = 0
var credit: int = 0
var tech_level: int = 0

# --- Progression ---
var current_destination_id: String = "D_001"
var highest_completed_tier: int = 0
var cleared_tiers: Array[int] = []
var completed_destinations: Array[String] = []
var total_launches: int = 0
var total_wins: int = 0
## Pity counter: failed launches since the last successful destination clear.
## Reset to 0 on success. Drives the (silent) Pity bonus in LaunchService.
var consecutive_failures: int = 0

# --- Session-scoped (resets on destination change) ---
## Launch Tech levels keyed by upgrade id (engine_precision, telemetry, ...).
var launch_tech_levels: Dictionary[StringName, int] = {}

# --- Permanent upgrades ---
var facility_upgrade_levels: Dictionary[StringName, int] = {}

# --- Stress (Phase 2) ---
var stress_value: float = 0.0
var stress_last_decay_at: int = 0

# --- Auto Launch (Phase 4) ---
var auto_launch_enabled: bool = false
var auto_launch_unlocked: bool = false

# --- Discovery / Codex (Phase 4b) ---
var discovered_codex_entries: Array[String] = []
## entry_id → list of destination_ids that contributed (for progress %).
var codex_entry_progress: Dictionary[StringName, Array] = {}

# --- Badges (Phase 4b) ---
var badges_earned: Array[String] = []

# --- Daily Mission (Phase 4b) ---
## { date: "YYYY-MM-DD", missions: [{id, progress, claimed}, ...], daily_tech_earned: int }
var daily_mission: Dictionary = {}

# --- Battle Pass (Phase 6c) ---
## Cumulative XP earned via GAMEPLAY only. IAP XP grants don't contribute — we
## want the pass to reward play, not spending.
var battle_pass_xp: int = 0
var battle_pass_claimed_free: Array[int] = []
var battle_pass_claimed_premium: Array[int] = []
var battle_pass_premium_unlocked: bool = false

# --- IAP / boosts (Phase 6) ---
var iap_non_consumable: Array[String] = []
## Ledger of consumable purchases for idempotency guard. Dict entries are
## { transaction_id: String, product_id: String, purchased_at: int }.
## Kept untyped because JSON round-trip yields a plain Array, not Array[Dictionary].
var iap_consumable_log: Array = []
var active_boosts: Dictionary[StringName, int] = {}  # boost_id → expire_unix
var shield_inventory: Dictionary[StringName, int] = {}
var purge_inventory: int = 0

# --- Settings / meta ---
var settings: Dictionary = {
	"sfx_volume": 1.0,
	"bgm_volume": 1.0,
	"auto_skip_cinematics": false,
	"language": "ko",
}
var total_play_time_sec: int = 0
var rng_seed: int = 0

func _ready() -> void:
	# Phase 6 IAP integration. Non-consumable / restore reapplies entitlements.
	IAPService.purchase_completed.connect(_on_iap_purchase_completed)
	IAPService.restore_completed.connect(_on_iap_restore_completed)

# --- Tick / simulation hooks (TimeManager forwards delta here) ---

## Per-frame tick. Phase 1 stub — Phase 2+ will wire Stress decay / Auto Launch / etc.
func tick(_delta: float) -> void:
	pass

## Bulk time advance for offline progress. Phase 1 stub returning empty result.
## Phase 4 OfflineProgressService will replace with real auto-launch simulation.
func advance_simulation(_dt: float) -> Dictionary:
	return {}

# --- Currency API ---

func add_xp(amount: int) -> void:
	assert(amount >= 0, "use spend_xp for negative")
	xp += amount
	EventBus.currency_changed.emit(&"xp", xp)

func spend_xp(amount: int) -> bool:
	assert(amount >= 0)
	if xp < amount:
		return false
	xp -= amount
	EventBus.currency_changed.emit(&"xp", xp)
	return true

func add_credit(amount: int) -> void:
	assert(amount >= 0, "use spend_credit/spend_credit_clamped for negative")
	credit += amount
	EventBus.currency_changed.emit(&"credit", credit)

func spend_credit(amount: int) -> bool:
	assert(amount >= 0)
	if credit < amount:
		return false
	credit -= amount
	EventBus.currency_changed.emit(&"credit", credit)
	return true

## Stress Abort uses this: deducts up to balance, returns actual spent.
## Never blocks, never goes negative — keeps poor players from being locked.
func spend_credit_clamped(amount: int) -> int:
	assert(amount >= 0)
	var spent: int = min(amount, credit)
	credit -= spent
	EventBus.currency_changed.emit(&"credit", credit)
	return spent

func add_tech_level(amount: int) -> void:
	assert(amount >= 0, "tech_level is monotonic")
	tech_level += amount
	EventBus.currency_changed.emit(&"tech_level", tech_level)

## Battle Pass XP is gameplay-only. Call this alongside add_xp() from the
## gameplay code path (LaunchService stage success). Not from IAP grants.
func add_battle_pass_xp(amount: int) -> void:
	assert(amount >= 0)
	battle_pass_xp += amount

## Shared grant applier for IAP purchases and Battle Pass claims. Handles the
## currency + boost + shield keys; caller handles flag-style grants
## (non_consumable, battle_pass_premium) separately.
func apply_grants(grants: Dictionary) -> void:
	if grants.has("xp"):
		add_xp(int(grants["xp"]))
	if grants.has("credit"):
		add_credit(int(grants["credit"]))
	if grants.has("tech_level"):
		add_tech_level(int(grants["tech_level"]))
	if grants.has("boosts"):
		var now: int = int(Time.get_unix_time_from_system())
		var boosts: Dictionary = grants["boosts"]
		for boost_id in boosts:
			var duration: int = int(boosts[boost_id])
			var existing: int = int(active_boosts.get(StringName(boost_id), 0))
			var base: int = max(existing, now)
			var new_expiry: int = base + duration
			active_boosts[StringName(boost_id)] = new_expiry
			EventBus.boost_activated.emit(StringName(boost_id), new_expiry)
	if grants.has("shields"):
		var shield_counts: Dictionary = grants["shields"]
		for tier in shield_counts:
			var key: StringName = StringName(tier)
			var current: int = int(shield_inventory.get(key, 0))
			shield_inventory[key] = current + int(shield_counts[tier])

# --- Save / load ---

## Serialize for SaveSystem. Keep keys stable across versions.
func to_dict() -> Dictionary:
	return {
		"xp": xp,
		"credit": credit,
		"tech_level": tech_level,
		"current_destination_id": current_destination_id,
		"highest_completed_tier": highest_completed_tier,
		"cleared_tiers": cleared_tiers.duplicate(),
		"completed_destinations": completed_destinations.duplicate(),
		"total_launches": total_launches,
		"total_wins": total_wins,
		"consecutive_failures": consecutive_failures,
		"launch_tech_levels": _dict_stringname_to_string(launch_tech_levels),
		"facility_upgrade_levels": _dict_stringname_to_string(facility_upgrade_levels),
		"stress_value": stress_value,
		"stress_last_decay_at": stress_last_decay_at,
		"auto_launch_enabled": auto_launch_enabled,
		"auto_launch_unlocked": auto_launch_unlocked,
		"discovered_codex_entries": discovered_codex_entries.duplicate(),
		"codex_entry_progress": _dict_stringname_to_string(codex_entry_progress),
		"badges_earned": badges_earned.duplicate(),
		"daily_mission": daily_mission.duplicate(true),
		"battle_pass_xp": battle_pass_xp,
		"battle_pass_claimed_free": battle_pass_claimed_free.duplicate(),
		"battle_pass_claimed_premium": battle_pass_claimed_premium.duplicate(),
		"battle_pass_premium_unlocked": battle_pass_premium_unlocked,
		"iap_non_consumable": iap_non_consumable.duplicate(),
		"iap_consumable_log": iap_consumable_log.duplicate(true),
		"active_boosts": _dict_stringname_to_string(active_boosts),
		"shield_inventory": _dict_stringname_to_string(shield_inventory),
		"purge_inventory": purge_inventory,
		"settings": settings.duplicate(true),
		"total_play_time_sec": total_play_time_sec,
		"rng_seed": rng_seed,
	}

## Restore from a dict produced by to_dict. Missing keys keep defaults from this file.
## Emits currency_changed for all 3 currencies so UI rebinds.
func from_dict(d: Dictionary) -> void:
	xp = int(d.get("xp", 0))
	credit = int(d.get("credit", 0))
	tech_level = int(d.get("tech_level", 0))
	current_destination_id = String(d.get("current_destination_id", "D_001"))
	highest_completed_tier = int(d.get("highest_completed_tier", 0))
	cleared_tiers = _to_int_array(d.get("cleared_tiers", []))
	completed_destinations = _to_string_array(d.get("completed_destinations", []))
	total_launches = int(d.get("total_launches", 0))
	total_wins = int(d.get("total_wins", 0))
	consecutive_failures = int(d.get("consecutive_failures", 0))
	launch_tech_levels = _string_keys_to_stringname_int(d.get("launch_tech_levels", {}))
	facility_upgrade_levels = _string_keys_to_stringname_int(d.get("facility_upgrade_levels", {}))
	stress_value = float(d.get("stress_value", 0.0))
	stress_last_decay_at = int(d.get("stress_last_decay_at", 0))
	auto_launch_enabled = bool(d.get("auto_launch_enabled", false))
	auto_launch_unlocked = bool(d.get("auto_launch_unlocked", false))
	discovered_codex_entries = _to_string_array(d.get("discovered_codex_entries", []))
	codex_entry_progress.clear()
	var raw_codex: Dictionary = d.get("codex_entry_progress", {})
	for k in raw_codex:
		var arr: Array = []
		if raw_codex[k] is Array:
			for v in raw_codex[k]:
				arr.append(String(v))
		codex_entry_progress[StringName(k)] = arr
	badges_earned = _to_string_array(d.get("badges_earned", []))
	daily_mission = (d.get("daily_mission", {}) as Dictionary).duplicate(true) if d.has("daily_mission") else {}
	battle_pass_xp = int(d.get("battle_pass_xp", 0))
	battle_pass_claimed_free = _to_int_array(d.get("battle_pass_claimed_free", []))
	battle_pass_claimed_premium = _to_int_array(d.get("battle_pass_claimed_premium", []))
	battle_pass_premium_unlocked = bool(d.get("battle_pass_premium_unlocked", false))
	iap_non_consumable = _to_string_array(d.get("iap_non_consumable", []))
	var raw_log: Variant = d.get("iap_consumable_log", [])
	iap_consumable_log = raw_log if raw_log is Array else []
	active_boosts = _string_keys_to_stringname_int(d.get("active_boosts", {}))
	shield_inventory = _string_keys_to_stringname_int(d.get("shield_inventory", {}))
	purge_inventory = int(d.get("purge_inventory", 0))
	settings = (d.get("settings", {}) as Dictionary).duplicate(true) if d.has("settings") else settings
	total_play_time_sec = int(d.get("total_play_time_sec", 0))
	rng_seed = int(d.get("rng_seed", 0))
	EventBus.currency_changed.emit(&"xp", xp)
	EventBus.currency_changed.emit(&"credit", credit)
	EventBus.currency_changed.emit(&"tech_level", tech_level)

# --- IAP integration (preserved from previous infra) ---

## IAPService contract: product.grants is a game-defined Dictionary.
## StarReach convention: { "credit": <int>, "xp": <int>, "boosts": { "<id>": <duration_sec> }, "non_consumable": <bool> }
func _on_iap_purchase_completed(product: IAPProduct, _receipt: Dictionary) -> void:
	var grants: Dictionary = product.grants
	apply_grants(grants)
	if grants.has("non_consumable") and bool(grants["non_consumable"]):
		var sku: String = String(product.sku)
		if not iap_non_consumable.has(sku):
			iap_non_consumable.append(sku)
	if grants.has("battle_pass_premium") and bool(grants["battle_pass_premium"]):
		battle_pass_premium_unlocked = true

func _on_iap_restore_completed(owned_products: Array) -> void:
	for p in owned_products:
		if p is IAPProduct and bool(p.grants.get("non_consumable", false)):
			var sku: String = String(p.sku)
			if not iap_non_consumable.has(sku):
				iap_non_consumable.append(sku)

# --- Helpers ---

## StringName keys don't survive JSON. Normalize to String on save.
static func _dict_stringname_to_string(src: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k in src:
		out[String(k)] = src[k]
	return out

static func _string_keys_to_stringname_int(src: Dictionary) -> Dictionary[StringName, int]:
	var out: Dictionary[StringName, int] = {}
	for k in src:
		out[StringName(k)] = int(src[k])
	return out

static func _to_int_array(src: Variant) -> Array[int]:
	var out: Array[int] = []
	if src is Array:
		for v in src:
			out.append(int(v))
	return out

static func _to_string_array(src: Variant) -> Array[String]:
	var out: Array[String] = []
	if src is Array:
		for v in src:
			out.append(String(v))
	return out
