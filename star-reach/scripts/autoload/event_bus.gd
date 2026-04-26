extends Node

## Global signal hub. This file MUST contain only signal declarations — no state, no logic.
## Each signal documented with the *why*: which producer→consumer pair motivated it.
## See docs/system_mapping_analysis.md §4.2 for the full architectural rationale.

# --- Boot / scene flow ---
signal scene_change_requested(path: String)
## Emitted by SaveSystem after first load + offline progress applied.
## Subscribers: services that need GameState fully populated before init.
signal profile_loaded
## Emitted by SaveSystem after each successful save (periodic / on quit / manual).
signal save_completed
signal error_raised(code: StringName, message: String)

# --- Launch loop (Phase 1+) ---
signal launch_session_started
signal launch_session_ended
signal launch_started
## Stage judged successfully. chance is the *applied* probability (post-modifier, pre-roll).
signal stage_succeeded(stage_index: int, chance: float)
signal stage_failed(stage_index: int, chance: float)
## All required stages passed for the current destination.
signal launch_completed(destination_id: String)
## State driven by main scene cinematic: idle / ascending / holding / pullback / falling / landed.
signal cinematic_state_changed(state: StringName)

# --- Progression (Phase 2+) ---
signal destination_completed(destination_id: String, reward: Dictionary)
signal region_first_visited(region_id: String)
signal region_mastery_level_up(region_id: String, level: int)

# --- Codex / Badge (Phase 4) ---
signal codex_entry_unlocked(entry_id: String)
signal codex_entry_updated(entry_id: String)
signal codex_section_unlocked(entry_id: String, section_id: String)
signal codex_entry_completed(entry_id: String)
signal badge_awarded(badge_id: String)

# --- Economy (Phase 1+) ---
## currency_type: "xp" / "credit" / "tech_level".
signal currency_changed(currency_type: StringName, new_value: int)
## category: "launch_tech" / "facility" / "iap".
signal upgrade_purchased(category: StringName, item_id: StringName)

# --- Stress / Risk (Phase 2) ---
signal stress_changed(new_value: float)
signal abort_triggered(repair_cost: int)

# --- Monetization (Phase 6) ---
signal iap_purchased(product_id: StringName, transaction_id: String)
signal iap_consumed(product_id: StringName)
signal subscription_renewed(expire_at: int)
signal battle_pass_tier_unlocked(tier: int, track: StringName)
## Fired by GameState when an IAP grants a time-limited boost (new or stacked).
## `expire_at` is the unix timestamp when the boost ends.
signal boost_activated(boost_id: StringName, expire_at: int)

# --- UI input lock (Phase 3+) ---
## Reason-counted: same reason can be acquired/released multiple times safely.
signal input_lock_acquired(reason: StringName)
signal input_lock_released(reason: StringName)

# --- Offline progress (Phase 4) ---
## Emitted by SaveSystem on boot when capped offline delta > threshold.
signal offline_summary_ready(summary: Dictionary)
