extends GutTest

func test_enemy_count_sums_waves_and_boss() -> void:
	var plan := [{"main_count": 10, "side_count": 4, "boss": false}, {"main_count": 6, "side_count": 0, "boss": false}]
	assert_eq(SweepMath.enemy_count(plan), 20)
	plan[1].boss = true
	assert_eq(SweepMath.enemy_count(plan), 21)
	assert_eq(SweepMath.enemy_count([]), 0)

func test_tier_summary() -> void:
	var nights := [
		{"day": 1, "tier": 1, "boss_night": false, "retries": 0, "at_cap": false},
		{"day": 8, "tier": 1, "boss_night": true, "retries": 2, "at_cap": false},
		{"day": 9, "tier": 2, "boss_night": false, "retries": 1, "at_cap": true},
		{"day": 10, "tier": 2, "boss_night": false, "retries": 0, "at_cap": true},
		{"day": 11, "tier": 2, "boss_night": false, "retries": 3, "at_cap": false},
	]
	assert_eq(SweepMath.tier_summary(nights), {"first_tier2_day": 9, "boss_retries": 2, "cap_nights": 2, "cap_retries": 1})
	assert_eq(SweepMath.tier_summary([]).first_tier2_day, -1)

func test_sweep_enemy_count_matches_the_economy_kill_count() -> void:
	for d in range(1, 9):
		var plan := LanePlanner.plan(20260930, d, Balance.data.wave)
		assert_eq(SweepMath.enemy_count(plan), Economy.night_kills(mini(d, 7), Balance.data.wave), "day %d" % d)

# --- Task 24: tier-3 run stats, the ladder numbers, the policy ranking ---

func _n(tier: int, retries: int, frac: float, lost := 0, br := 0, gold := 0, close := -1) -> Dictionary:
	return {"tier": tier, "tier_close": tier if close < 0 else close, "retries": retries, "frac": frac, "fences_lost": lost, "branches": br, "branch_gold": gold}

## Mutations: counting tier-1/2 nights; the mean for the median (or the reverse); dividing by all nights; dropping the Baron row's day purchases (tier read at the night's start).
func test_tier3_stats_counts_tier3_nights_but_the_dawn_days_purchases() -> void:
	var nights := [_n(2, 3, 0.05, 4), _n(2, 0, 0.6, 0, 2, 800, 3), _n(3, 0, 0.2, 1, 1, 500), _n(3, 2, 0.9, 3, 2, 800), _n(3, 0, 1.0, 0, 0, 0), _n(1, 0, 0.0)]
	var s := SweepMath.tier3_stats(nights)
	assert_eq(s.nights, 3, "the tier-1 and tier-2 nights (the Baron's included) are not counted as nights")
	assert_eq(s.retry_nights, 1, "the tier-2 night's 3 retries are not counted")
	assert_almost_eq(s.min, 0.2, 1e-9)
	assert_almost_eq(s.median, 0.9, 1e-9, "median, not the mean 0.7")
	assert_almost_eq(s.mean, 0.7, 1e-9, "mean, not the median 0.9")
	assert_almost_eq(s.fences_lost_mean, 4.0 / 3.0, 1e-9, "divided by the tier-3 nights (3), not all nights (6)")
	assert_eq(s.branches, 5, "the Baron row closes at tier 3: its 2 branches count")
	assert_eq(s.branch_gold, 2100)
	assert_eq(SweepMath.tier3_stats([_n(2, 1, 0.5)]).nights, 0)
	assert_eq(SweepMath.tier3_stats([]).mean, 0.0)

func test_ladder_done_needs_every_level_branch_and_station() -> void:
	var done := [{"kind": "tower", "level": 3, "branch": "longbow"}, {"kind": "fence", "level": 3, "branch": "stone"}, {"kind": "decoy", "level": 3, "branch": ""}]
	assert_true(SweepMath.ladder_done(done, [5, 5], 3, 5), "a spot kind that cannot branch needs no branch")
	assert_false(SweepMath.ladder_done([done[0], {"kind": "fence", "level": 3, "branch": ""}], [5, 5], 3, 5), "an unbranched fence")
	assert_false(SweepMath.ladder_done([done[0], {"kind": "fence", "level": 2, "branch": "stone"}], [5, 5], 3, 5), "a spot below max level")
	assert_false(SweepMath.ladder_done(done, [5, 4], 3, 5), "a station below max")
	assert_false(SweepMath.ladder_done([], [5, 5], 3, 5), "no spots is not done")

func _d(day: int, tier: int, cap3: bool, income: int, rebuild: int, unspent: int, done := false, rebranch := 0) -> Dictionary:
	return {"day": day, "tier": tier, "at_cap3": cap3, "income": income, "rebuild": rebuild, "rebranch": rebranch, "unspent": unspent, "done": done}

## Rows: 8 closes at tier 2 (the sign was paid in its day phase: plot_day = 8), 9 is the Baron row (closes at tier 3), 10 and 11 follow, 12 and 13 come after the ladder.
## Mutations: reading the tier at the night's start (row 9 dropped: max would be 640 not 700, days 2 not 3); counting row 12 (9000); dropping the done row (11) from
## max_unspent_during_ladder; counting it in max_unspent_while_purchasable; mean for median; the rebranch part left out of the total.
func test_ladder_summary_rows_close_up_tier_medians_and_parts() -> void:
	var days := [
		_d(8, 2, false, 300, 0, 1400),
		_d(9, 3, false, 300, 0, 700),  # the Baron row: closes at tier 3
		_d(10, 3, true, 600, 10, 640, false, 0),
		_d(11, 3, true, 700, 30, 200, true, 300),
		_d(12, 3, true, 640, 20, 9000, false, 0),
		_d(13, 3, true, 660, 500, 9500, false, 0),
	]
	var s := SweepMath.ladder_summary(8, days)
	assert_eq(s.plot_day, 8)
	assert_eq(s.ladder_done_day, 11)
	assert_eq(s.t3_days_to_done, 3, "rows 9, 10, 11: from the tier-3 dawn to the done row inclusive")
	assert_eq(s.max_unspent_during_ladder, 700, "the Baron row counts; the tier-2 row 1400 and the rows after 11 do not")
	assert_eq(s.max_unspent_while_purchasable, 700, "without the done row (200)")
	assert_eq(s.income_at_cap, 650, "median of 600, 700, 640, 660 (even count: the mean of the middle two)")
	assert_eq(s.fence_rebuild_gold_median_at_cap, 175, "totals 10, 330, 20, 500 (rebuild + rebranch): sorted 10 20 330 500, median 175; the rebuild part alone would give 25, the mean 215")

func test_ladder_summary_without_a_done_day_uses_every_tier3_row() -> void:
	var s := SweepMath.ladder_summary(-1, [_d(1, 1, false, 100, 0, 5000), _d(2, 3, false, 100, 0, 300), _d(3, 3, true, 100, 40, 200)])
	assert_eq(s.ladder_done_day, -1)
	assert_eq(s.t3_days_to_done, -1)
	assert_eq(s.max_unspent_during_ladder, 300)
	assert_eq(s.plot_day, -1)
	assert_eq(SweepMath.ladder_summary(-1, []).income_at_cap, 0)

func test_ladder_summary_done_day_is_the_first_done_day_and_while_purchasable_excludes_it() -> void:
	var s := SweepMath.ladder_summary(3, [_d(4, 3, false, 0, 0, 10, false), _d(5, 3, false, 0, 0, 500, true), _d(6, 3, false, 0, 0, 999, true)])
	assert_eq(s.ladder_done_day, 5, "the first, not the last")
	assert_eq(s.max_unspent_during_ladder, 500, "row 6 is after the first done row")
	assert_eq(s.max_unspent_while_purchasable, 10, "the done row's own leftover (500) is not unspent while something is to buy")
	assert_eq(s.t3_days_to_done, 2)

## Mutations: PASS on an incomplete ladder (the vacuous pass); the limit applied to the while-purchasable value; > 650 written as >= 650.
func test_unspent_target_is_na_until_the_ladder_completes() -> void:
	var open := SweepMath.ladder_summary(3, [_d(4, 3, false, 0, 0, 100)])
	assert_true(SweepMath.unspent_target_line(open).begins_with("UNSPENT_TARGET: N/A"))
	var ok := SweepMath.ladder_summary(3, [_d(4, 3, false, 0, 0, 650, true)])
	assert_true(SweepMath.unspent_target_line(ok).begins_with("UNSPENT_TARGET: PASS"), "650 passes")
	var bad := SweepMath.ladder_summary(3, [_d(4, 3, false, 0, 0, 651, true)])
	assert_true(SweepMath.unspent_target_line(bad).begins_with("UNSPENT_TARGET: FAIL"))

## Mutations: share over the rebuild part only (no rebranch); threshold 30 inclusive; share over the wrong median.
func test_fence_tax_share_uses_rebuild_plus_rebranch_over_income() -> void:
	var at := SweepMath.ladder_summary(1, [_d(2, 3, true, 1000, 100, 0, false, 200)])
	assert_true(SweepMath.fence_tax_line(at).begins_with("FENCE_TAX: no (share 30.0%"), "exactly 30% is not above")
	var over := SweepMath.ladder_summary(1, [_d(2, 3, true, 1000, 101, 0, false, 200)])
	assert_true(SweepMath.fence_tax_line(over).begins_with("FENCE_TAX: yes (share 30.1%"))
	assert_true(SweepMath.fence_tax_line(SweepMath.ladder_summary(1, [])).begins_with("FENCE_TAX: N/A"))

func _run(policy: String, mean_frac: float, retries := 0, seed_value := 1, lost := 0.0, gold := 0) -> Dictionary:
	return {"policy": policy, "seed": seed_value, "mean_frac": mean_frac, "retry_nights": retries, "fences_lost_mean": lost, "branch_gold": gold}

func test_policy_ranking_averages_seeds_in_points_sums_retries_and_averages_the_extras() -> void:
	var runs := [_run("all_a", 0.8, 1, 1, 1.0, 100), _run("all_a", 0.6, 0, 2, 2.0, 300), _run("threat", 0.9, 2), _run("threat", 0.9, 1), _run("mixed", 0.5), _run("mixed", 0.7, 4)]
	var r := SweepMath.policy_ranking(runs)
	assert_eq(r.rows.map(func(x): return x.policy), ["threat", "all_a", "mixed"])
	assert_almost_eq(r.rows[0].points, 90.0, 1e-9, "points are percent of diner max, not the fraction")
	assert_eq(r.rows[0].retry_nights, 3, "retries are summed, not averaged")
	assert_almost_eq(r.gap, 30.0, 1e-9, "best minus worst")
	assert_almost_eq(r.rows[1].fences_lost, 1.5, 1e-9)
	assert_almost_eq(r.rows[1].branch_gold, 200.0, 1e-9)
	assert_eq(SweepMath.policy_ranking(runs, ["all_a", "mixed"]).rows.size(), 2, "the `only` list limits the ranking")

func test_dominant_line_threshold_is_strictly_above_15() -> void:
	assert_eq(SweepMath.dominant_line("DOMINANT_BRANCH", SweepMath.policy_ranking([_run("threat", 0.9), _run("all_a", 0.75)])), "DOMINANT_BRANCH: no (gap 15.0 points, threshold 15)")
	assert_eq(SweepMath.dominant_line("DOMINANT_BRANCH_2x2", SweepMath.policy_ranking([_run("threat", 0.9), _run("all_a", 0.7)])), "DOMINANT_BRANCH_2x2: yes (gap 20.0 points, threshold 15)")

const SPEC := ["all_a", "all_b", "mixed", "threat"]

## Mutations: yes/no from the sign of the mean alone; a tie threshold of 1 or 3 points; the sign test dropped; the report-only policy taken as "best other".
func test_threat_verdict_yes_no_tie() -> void:
	var yes := SweepMath.threat_verdict([_run("threat", 0.80, 0, 1), _run("threat", 0.80, 0, 2), _run("all_b", 0.77, 0, 1), _run("all_b", 0.77, 0, 2)], SPEC)
	assert_true(yes.begins_with("THREAT_BEST: yes (threat 80.0, best other all_b 77.0, mean difference +3.0, per seed +3.0 +3.0"), yes)
	var no := SweepMath.threat_verdict([_run("threat", 0.74, 0, 1), _run("threat", 0.74, 0, 2), _run("all_b", 0.77, 0, 1), _run("all_b", 0.77, 0, 2)], SPEC)
	assert_true(no.begins_with("THREAT_BEST: no (threat 74.0"), no)
	var close := SweepMath.threat_verdict([_run("threat", 0.76, 0, 1), _run("threat", 0.76, 0, 2), _run("all_b", 0.77, 0, 1), _run("all_b", 0.77, 0, 2)], SPEC)
	assert_true(close.begins_with("THREAT_BEST: tie"), "a 1 point mean difference is a tie: " + close)
	var split := SweepMath.threat_verdict([_run("threat", 0.95, 0, 1), _run("threat", 0.55, 0, 2), _run("all_b", 0.60, 0, 1), _run("all_b", 0.90, 0, 2)], SPEC)
	assert_true(split.begins_with("THREAT_BEST: tie"), "mean +0.0 would also tie; the signs differ: " + split)
	var split_far := SweepMath.threat_verdict([_run("threat", 0.95, 0, 1), _run("threat", 0.60, 0, 2), _run("all_b", 0.50, 0, 1), _run("all_b", 0.65, 0, 2)], SPEC)
	assert_true(split_far.begins_with("THREAT_BEST: tie (threat 77.5, best other all_b 57.5, mean difference +20.0"), "a large mean with opposite per-seed signs is a tie: " + split_far)
	var fifth := SweepMath.threat_verdict([_run("threat", 0.80), _run("all_b", 0.70), _run("volley_stone", 0.95)], SPEC)
	assert_true(fifth.begins_with("THREAT_BEST: yes (threat 80.0, best other all_b 70.0"), "volley_stone is not one of the four: " + fifth)

## Mutations: effects computed on the wrong axis (tower and fence swapped), a missing /2, an interaction with the wrong sign, cells mapped to the wrong policy.
func test_two_by_two_effects_and_cells() -> void:
	var runs := [_run("all_a", 0.60, 0, 1), _run("all_a", 0.70, 0, 2), _run("mixed", 0.40), _run("all_b", 0.80), _run("volley_stone", 0.90)]
	var t := SweepMath.two_by_two(runs)
	assert_almost_eq(t.cells.longbow_stone.points, 65.0, 1e-9, "all_a: Longbow and Stone")
	assert_eq(t.cells.longbow_stone.per_seed, [[1, 60.0], [2, 70.0]])
	assert_almost_eq(t.cells.longbow_spike.points, 40.0, 1e-9, "mixed: Longbow and Spike")
	assert_almost_eq(t.cells.volley_spike.points, 80.0, 1e-9, "all_b: Volley and Spike")
	assert_almost_eq(t.cells.volley_stone.points, 90.0, 1e-9)
	assert_almost_eq(t.tower_effect, 32.5, 1e-9, "Volley (85) minus Longbow (52.5)")
	assert_almost_eq(t.fence_effect, 17.5, 1e-9, "Stone (77.5) minus Spike (60)")
	assert_almost_eq(t.interaction, 15.0, 1e-9, "(80 - 40) - (90 - 65)")
	assert_eq(SweepMath.two_by_two([_run("all_a", 0.5)]), {})
