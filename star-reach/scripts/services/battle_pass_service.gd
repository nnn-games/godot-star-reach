class_name BattlePassService
extends Node

## Battle Pass season orchestrator. Loads the active season tres, exposes tier
## state queries, and gates claims. XP accumulation happens in GameState via
## `add_battle_pass_xp()`; this service is stateless besides the loaded season.

const SEASON_PATH: String = "res://data/battle_pass/season_01.tres"

var _season: BattlePassSeasonDef

func _ready() -> void:
	_season = load(SEASON_PATH) as BattlePassSeasonDef
	if _season == null:
		push_warning("[BP] failed to load season at %s" % SEASON_PATH)

# --- Public API ---

func get_season() -> BattlePassSeasonDef:
	return _season

func get_xp() -> int:
	return GameState.battle_pass_xp

func is_premium_unlocked() -> bool:
	return GameState.battle_pass_premium_unlocked

## Highest tier whose xp_required <= current XP. 0 if none reached.
func get_current_tier_index() -> int:
	if _season == null:
		return 0
	var reached: int = 0
	for t in _season.tiers:
		if GameState.battle_pass_xp >= t.xp_required:
			reached = t.tier
		else:
			break
	return reached

func is_claimable(tier_num: int, premium: bool) -> bool:
	var tier: BattlePassTier = _get_tier(tier_num)
	if tier == null:
		return false
	if GameState.battle_pass_xp < tier.xp_required:
		return false
	if premium and not is_premium_unlocked():
		return false
	var claimed: Array[int] = GameState.battle_pass_claimed_premium if premium else GameState.battle_pass_claimed_free
	return not claimed.has(tier_num)

func claim(tier_num: int, premium: bool) -> bool:
	if not is_claimable(tier_num, premium):
		return false
	var tier: BattlePassTier = _get_tier(tier_num)
	var grants: Dictionary = tier.premium_reward if premium else tier.free_reward
	GameState.apply_grants(grants)
	var claimed: Array[int] = GameState.battle_pass_claimed_premium if premium else GameState.battle_pass_claimed_free
	claimed.append(tier_num)
	EventBus.battle_pass_tier_unlocked.emit(tier_num, &"premium" if premium else &"free")
	return true

# --- Internals ---

func _get_tier(tier_num: int) -> BattlePassTier:
	if _season == null:
		return null
	for t in _season.tiers:
		if t.tier == tier_num:
			return t
	return null
