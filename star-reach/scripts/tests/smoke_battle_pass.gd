extends Node

## Phase 6c Battle Pass claim flow smoke. Verifies tier progression via BP XP,
## free vs premium gating, and that claims apply grants through GameState.apply_grants().

var _failures: int = 0

func _ready() -> void:
	print("== Phase 6c Battle Pass smoke ==")
	await _run()
	if _failures > 0:
		printerr("FAILED: %d issue(s)" % _failures)
		get_tree().quit(1)
	else:
		print("PASSED")
		get_tree().quit(0)

func _run() -> void:
	GameState.battle_pass_xp = 0
	GameState.battle_pass_claimed_free = []
	GameState.battle_pass_claimed_premium = []
	GameState.battle_pass_premium_unlocked = false
	GameState.credit = 0
	GameState.tech_level = 0
	GameState.active_boosts = {}

	var bp: BattlePassService = BattlePassService.new()
	add_child(bp)
	await get_tree().process_frame

	_expect(bp.get_season() != null, "season loaded")
	_expect(bp.get_season().tiers.size() == 10, "season has 10 tiers (got %d)" % bp.get_season().tiers.size())
	_expect(bp.get_current_tier_index() == 0, "current tier = 0 on fresh state")

	# Below threshold: tier 1 requires 50 XP; 49 should NOT be claimable.
	GameState.battle_pass_xp = 49
	_expect(not bp.is_claimable(1, false), "tier 1 free NOT claimable at 49 XP")

	# Reach tier 1 — free claimable, premium gated by unlock flag.
	GameState.battle_pass_xp = 50
	_expect(bp.get_current_tier_index() == 1, "current tier = 1 at 50 XP")
	_expect(bp.is_claimable(1, false), "tier 1 free claimable at 50 XP")
	_expect(not bp.is_claimable(1, true), "tier 1 premium NOT claimable without premium flag")

	var ok: bool = bp.claim(1, false)
	_expect(ok, "claim tier 1 free succeeds")
	_expect(GameState.credit == 50, "tier 1 free grants 50 credit (got %d)" % GameState.credit)
	_expect(GameState.battle_pass_claimed_free.has(1), "tier 1 recorded in claimed_free")

	# Re-claim same tier should fail.
	_expect(not bp.claim(1, false), "tier 1 free cannot be re-claimed")

	# Unlock premium and claim tier 1 premium.
	GameState.battle_pass_premium_unlocked = true
	_expect(bp.is_claimable(1, true), "tier 1 premium claimable after unlock")
	_expect(bp.claim(1, true), "claim tier 1 premium succeeds")
	_expect(GameState.credit == 150, "tier 1 premium adds 100 credit (got %d)" % GameState.credit)

	# Jump to tier 3 premium (boost grant).
	GameState.battle_pass_xp = 220
	_expect(bp.is_claimable(3, true), "tier 3 premium claimable at 220 XP")
	_expect(bp.claim(3, true), "claim tier 3 premium succeeds")
	var expire: int = int(GameState.active_boosts.get(&"AUTO_LAUNCH_PASS", 0))
	var now: int = int(Time.get_unix_time_from_system())
	_expect(expire >= now + 86400 - 2, "tier 3 premium grants ~1-day AUTO_LAUNCH_PASS (expire=%d now=%d)" % [expire, now])

	# IAP premium unlock path.
	GameState.battle_pass_premium_unlocked = false
	await _buy_and_wait(&"battle_pass_premium_s1")
	_expect(GameState.battle_pass_premium_unlocked, "battle_pass_premium_s1 sets premium_unlocked flag")

func _buy_and_wait(sku: StringName) -> void:
	var state: Array[bool] = [false]
	var handler: Callable = func(_p: IAPProduct, _r: Dictionary) -> void: state[0] = true
	IAPService.purchase_completed.connect(handler)
	IAPService.buy(sku)
	var waited: float = 0.0
	while not state[0] and waited < 2.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	IAPService.purchase_completed.disconnect(handler)

func _expect(cond: bool, msg: String) -> void:
	if cond:
		print("  ok: %s" % msg)
	else:
		_failures += 1
		printerr("  FAIL: %s" % msg)
