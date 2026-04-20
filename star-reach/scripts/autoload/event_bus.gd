extends Node

## Global signal hub. This file MUST contain only signal declarations — no state, no logic.
## Add a new signal here when a module needs to talk to another across the tree.

# --- Scene flow ---
signal scene_change_requested(path: String)

# --- Economy (Phase 1+) ---
signal currency_changed(currency_id: StringName, amount: float)
signal generator_purchased(gen_id: StringName, new_level: int)
signal generator_ticked(gen_id: StringName, produced: float)

# --- Upgrades / Prestige (Phase 2+) ---
signal upgrade_applied(upgrade_id: StringName)
signal prestige_reset

# --- System ---
signal save_completed
signal error_raised(code: StringName, message: String)
