extends GutTest
## E5 spec 4.4: TierBalance shape and TierEffects.

var tb: TierBalance

func before_each() -> void:
	Balance.reset()
	tb = Balance.data.tiers

func test_arrays_cover_every_tier_including_the_top() -> void:
	var n := tb.tier_costs.size() + 1  # index 0 unused, tiers 1..top where top = tier_costs.size()
	for arr in [tb.tier_base, tb.tier_cap, tb.fast_share_start, tb.fast_share, tb.fast_ramp_days]:
		assert_eq((arr as Array).size(), n)

func test_tiers_are_ordered() -> void:
	for t in range(1, tb.tier_costs.size()):
		assert_lte(tb.tier_base[t], tb.tier_cap[t], "tier %d base <= cap" % t)
		assert_lt(tb.tier_cap[t], tb.tier_base[t + 1], "tier %d cap < next base" % t)
	var top := tb.tier_costs.size()
	assert_lte(tb.tier_base[top], tb.tier_cap[top])

func test_spec_values() -> void:
	assert_eq(Array(tb.tier_costs), [0, 500])
	assert_eq(Array(tb.tier_base), [0, 1, 8])
	assert_eq(tb.tier_base[1], 1, "tier 1 starts at pressure 1: the lane RNG draw order depends on it (D-095)")
	assert_gt(tb.boss_lead, 0.0, "the boss must spawn strictly before the wave's first monster (WaveSchedule sorts by time)")
	assert_eq(Array(tb.tier_cap), [0, 7, 11])
	assert_eq(TierEffects.top_tier(tb), 2)
	assert_eq(TierEffects.tier_cost(1, tb), 500)
	assert_eq(TierEffects.tier_cost(2, tb), -1)
	assert_eq(TierEffects.tier_cost(9, tb), -1)
	assert_eq(tb.boss_min_hold_s, 15.0)

func test_fast_share_ramps_then_caps() -> void:
	assert_almost_eq(TierEffects.fast_share_now(5, 1, 1, tb), 0.0, 1e-6)
	assert_almost_eq(TierEffects.fast_share_now(9, 2, 9, tb), 0.15, 1e-6)
	assert_almost_eq(TierEffects.fast_share_now(10, 2, 9, tb), 0.15 + (0.35 - 0.15) / 3.0, 1e-6)
	assert_almost_eq(TierEffects.fast_share_now(12, 2, 9, tb), 0.35, 1e-6)
	assert_almost_eq(TierEffects.fast_share_now(40, 2, 9, tb), 0.35, 1e-6)

func test_fast_counts_round_and_never_exceed() -> void:
	assert_eq(TierEffects.fast_counts(14, 0, 0.15), {"fast_main": 2, "fast_side": 0})
	assert_eq(TierEffects.fast_counts(21, 7, 0.35), {"fast_main": 7, "fast_side": 2})
	assert_eq(TierEffects.fast_counts(3, 1, 1.0), {"fast_main": 3, "fast_side": 1})
	assert_eq(TierEffects.fast_counts(5, 2, 0.0), {"fast_main": 0, "fast_side": 0})
