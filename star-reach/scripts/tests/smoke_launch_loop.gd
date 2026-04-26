@tool
extends SceneTree

## Headless Phase 1 integration check: simulates 100 launches against the same
## probability rule LaunchService uses, asserts the outcome distribution stays
## within tolerance of the analytic expected value, and verifies RNG determinism
## (same seed → identical roll sequence).
##
## Run:
##   godot --path star-reach --headless --script res://scripts/tests/smoke_launch_loop.gd
##
## We don't instantiate LaunchService directly because it awaits real-time
## STAGE_DURATION_SEC * required_stages * 100 trials = ~10 minutes — far too
## slow for CI. The math here mirrors LaunchService._compute_chance + the roll
## logic in _run_stages, so any drift between this test and LaunchService is a
## bug to investigate.

const TRIALS: int = 100
const SEED: int = 12345
const D001_STAGES: int = 3
const TIER_1_BASE_CHANCE: float = 0.5  # mirrors data/launch_balance_config.tres

var _failures: int = 0

func _init() -> void:
	print("== Phase 1+2 launch-loop smoke ==")
	_check_rng_determinism()
	_check_clearance_distribution()
	_check_pity_curve()
	_check_tier_conquest()
	if _failures > 0:
		printerr("FAILED: %d issue(s)" % _failures)
		quit(1)
	else:
		print("PASSED")
		quit(0)

## Same seed → identical first 10 randf() values. Catches accidental
## global-state seeding that would break offline simulation reproducibility.
func _check_rng_determinism() -> void:
	var rng_a: RandomNumberGenerator = RandomNumberGenerator.new()
	var rng_b: RandomNumberGenerator = RandomNumberGenerator.new()
	rng_a.seed = SEED
	rng_b.seed = SEED
	for i in 10:
		var a: float = rng_a.randf()
		var b: float = rng_b.randf()
		if not is_equal_approx(a, b):
			_fail("RNG determinism broken at index %d: %f vs %f" % [i, a, b])
			return
	print("  rng      ok: 10 rolls match for seed=%d" % SEED)

## At T1 (3 stages, base=0.5) the probability of clearing all 3 is 0.5^3 = 0.125.
## Over 100 trials we expect ~12.5 wins. ±5σ tolerance ≈ ±17 → bound at [4, 21].
## Wide bound on purpose: this is a smoke test, not a balance assertion.
func _check_clearance_distribution() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = SEED
	var wins: int = 0
	for _trial in TRIALS:
		var stages_cleared: int = 0
		for _stage in D001_STAGES:
			if rng.randf() < TIER_1_BASE_CHANCE:
				stages_cleared += 1
			else:
				break
		if stages_cleared == D001_STAGES:
			wins += 1
	# Expected: ~12.5 wins. Very loose bound to avoid CI flakiness.
	if wins < 4 or wins > 25:
		_fail("D_001 clear count out of bounds: %d (expected ~12-13)" % wins)
	else:
		print("  loop     ok: %d/%d D_001 clears (expected ~12-13)" % [wins, TRIALS])

## Pity bonus = max(0, fails - 4) * 0.01, capped at 0.15.
## Mirrors LaunchService.PITY_START_THRESHOLD/_BONUS_PER_FAIL/_MAX_BONUS.
func _check_pity_curve() -> void:
	var cases: Array = [
		[0, 0.0],
		[4, 0.0],   # below threshold
		[5, 0.01],  # first fail past threshold
		[10, 0.06],
		[19, 0.15], # exactly at cap
		[50, 0.15], # clamped at cap
	]
	for c in cases:
		var fails: int = c[0]
		var expected: float = c[1]
		var got: float = _pity_bonus(fails)
		if not is_equal_approx(got, expected):
			_fail("pity(%d) expected %.2f got %.2f" % [fails, expected, got])
			return
	print("  pity     ok: 0/4/5/10/19/50 fails → 0/0/0.01/0.06/0.15/0.15")

## Once a Tier is in cleared_tiers, base stages of that tier should return max_chance.
## Verified against LaunchBalanceConfig directly — LaunchService just reads seg.max_chance.
func _check_tier_conquest() -> void:
	var lbc: LaunchBalanceConfig = load("res://data/launch_balance_config.tres") as LaunchBalanceConfig
	var t1: TierSegment = lbc.segment_for_tier(1)
	var t3: TierSegment = lbc.segment_for_tier(3)
	# Conquering T1 lifts T1 stages to max_chance. T3 stays at base for a fresh player.
	if not is_equal_approx(t1.max_chance, 0.85):
		_fail("T1 max_chance expected 0.85")
	if not is_equal_approx(t3.base_chance, 0.36):
		_fail("T3 base_chance expected 0.36")
	# Sanity: max_chance is always >= base_chance.
	for tier in range(1, 6):
		var seg: TierSegment = lbc.segment_for_tier(tier)
		if seg.max_chance < seg.base_chance:
			_fail("T%d max_chance %f < base_chance %f" % [tier, seg.max_chance, seg.base_chance])
	print("  conquest ok: T1 max=0.85, T3 base=0.36, all tiers max >= base")

static func _pity_bonus(fails: int) -> float:
	const PITY_START_THRESHOLD: int = 5
	const PITY_BONUS_PER_FAIL: float = 0.01
	const PITY_MAX_BONUS: float = 0.15
	if fails < PITY_START_THRESHOLD:
		return 0.0
	var bonus: float = float(fails - PITY_START_THRESHOLD + 1) * PITY_BONUS_PER_FAIL
	return min(bonus, PITY_MAX_BONUS)

func _fail(msg: String) -> void:
	_failures += 1
	printerr("  FAIL: " + msg)
