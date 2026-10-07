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

func _n(tier: int, retries: int, frac: float, lost := 0, br := 0, gold := 0) -> Dictionary:
	return {"tier": tier, "retries": retries, "frac": frac, "fences_lost": lost, "branches": br, "branch_gold": gold}

func test_tier3_stats_counts_only_tier3_nights_and_uses_mean_and_median() -> void:
	var nights := [_n(2, 3, 0.05, 4), _n(3, 0, 0.2, 1, 1, 500), _n(3, 2, 0.9, 3, 2, 800), _n(3, 0, 1.0, 0, 0, 0), _n(1, 0, 0.0)]
	var s := SweepMath.tier3_stats(nights)
	assert_eq(s.nights, 3, "the tier-1 and tier-2 nights are not counted")
	assert_eq(s.retry_nights, 1, "the tier-2 night's 3 retries are not counted")
	assert_almost_eq(s.min, 0.2, 1e-9)
	assert_almost_eq(s.median, 0.9, 1e-9, "median, not the mean 0.7")
	assert_almost_eq(s.mean, 0.7, 1e-9, "mean, not the median 0.9")
	assert_almost_eq(s.fences_lost_mean, 4.0 / 3.0, 1e-9, "divided by the tier-3 nights (3), not all nights (5)")
	assert_eq(s.branches, 3)
	assert_eq(s.branch_gold, 1300)
	assert_eq(SweepMath.tier3_stats([_n(2, 1, 0.5)]).nights, 0)
	assert_eq(SweepMath.tier3_stats([]).mean, 0.0)

func test_ladder_done_needs_every_level_branch_and_station() -> void:
	var done := [{"kind": "tower", "level": 3, "branch": "longbow"}, {"kind": "fence", "level": 3, "branch": "stone"}, {"kind": "decoy", "level": 3, "branch": ""}]
	assert_true(SweepMath.ladder_done(done, [5, 5], 3, 5), "a spot kind that cannot branch needs no branch")
	assert_false(SweepMath.ladder_done([done[0], {"kind": "fence", "level": 3, "branch": ""}], [5, 5], 3, 5), "an unbranched fence")
	assert_false(SweepMath.ladder_done([done[0], {"kind": "fence", "level": 2, "branch": "stone"}], [5, 5], 3, 5), "a spot below max level")
	assert_false(SweepMath.ladder_done(done, [5, 4], 3, 5), "a station below max")
	assert_false(SweepMath.ladder_done([], [5, 5], 3, 5), "no spots is not done")

func _d(day: int, tier: int, cap3: bool, income: int, rebuild: int, unspent: int, done := false) -> Dictionary:
	return {"day": day, "tier": tier, "at_cap3": cap3, "income": income, "rebuild": rebuild, "unspent": unspent, "done": done}

func test_ladder_summary_ranges_medians_and_tiers() -> void:
	var days := [
		_d(8, 2, false, 300, 0, 1400),  # tier 2: saving for the plot, not the ladder
		_d(9, 3, false, 300, 0, 100),
		_d(10, 3, true, 600, 10, 640),
		_d(11, 3, true, 700, 30, 200, true),
		_d(12, 3, true, 640, 20, 9000),  # after the ladder: the pile-up is not counted
		_d(13, 3, true, 660, 500, 9500),
	]
	var s := SweepMath.ladder_summary(7, days)
	assert_eq(s.plot_day, 7)
	assert_eq(s.ladder_done_day, 11)
	assert_eq(s.max_unspent_during_ladder, 640, "tier-2 day 1400 and the days after 11 are out; day 11 itself is in")
	assert_eq(s.income_at_cap, 650, "median of 600, 700, 640, 660 is 650 (even count: the mean of the middle two)")
	assert_eq(s.fence_rebuild_gold_median_at_cap, 25, "median of 10, 30, 20, 500 is 25; the mean would be 140")

func test_ladder_summary_without_a_done_day_uses_every_tier3_day() -> void:
	var s := SweepMath.ladder_summary(-1, [_d(1, 1, false, 100, 0, 5000), _d(2, 3, false, 100, 0, 300), _d(3, 3, true, 100, 40, 200)])
	assert_eq(s.ladder_done_day, -1)
	assert_eq(s.max_unspent_during_ladder, 300)
	assert_eq(s.plot_day, -1)
	assert_eq(SweepMath.ladder_summary(-1, []).income_at_cap, 0)

func test_ladder_summary_done_day_is_the_first_done_day() -> void:
	var s := SweepMath.ladder_summary(3, [_d(4, 3, false, 0, 0, 10, true), _d(5, 3, false, 0, 0, 999, true)])
	assert_eq(s.ladder_done_day, 4, "the first, not the last")
	assert_eq(s.max_unspent_during_ladder, 10, "day 5 is after the first done day")

func _run(policy: String, mean_frac: float, retries: int) -> Dictionary:
	return {"policy": policy, "mean_frac": mean_frac, "retry_nights": retries}

func test_policy_ranking_averages_seeds_in_points_and_sums_retries() -> void:
	var runs := [_run("all_a", 0.8, 1), _run("all_a", 0.6, 0), _run("threat", 0.9, 2), _run("threat", 0.9, 1), _run("mixed", 0.5, 0), _run("mixed", 0.7, 4)]
	var r := SweepMath.policy_ranking(runs)
	assert_eq(r.rows.map(func(x): return x.policy), ["threat", "all_a", "mixed"])
	assert_almost_eq(r.rows[0].points, 90.0, 1e-9, "points are percent of diner max, not the fraction")
	assert_almost_eq(r.rows[1].points, 70.0, 1e-9)
	assert_eq(r.rows[0].retry_nights, 3, "retries are summed, not averaged")
	assert_almost_eq(r.gap, 30.0, 1e-9, "best minus worst")

func test_policy_verdicts_thresholds() -> void:
	var at := SweepMath.policy_verdicts(SweepMath.policy_ranking([_run("threat", 0.9, 0), _run("all_a", 0.75, 0)]))
	assert_eq(at[0], "DOMINANT_BRANCH: no (gap 15.0 points, threshold 15)", "exactly 15 is not above")
	var over := SweepMath.policy_verdicts(SweepMath.policy_ranking([_run("threat", 0.9, 0), _run("all_a", 0.7, 0)]))
	assert_eq(over[0], "DOMINANT_BRANCH: yes (gap 20.0 points, threshold 15)")
	assert_eq(over[1], "THREAT_BEST: yes (threat 90.0, best threat 90.0)")
	var behind := SweepMath.policy_verdicts(SweepMath.policy_ranking([_run("threat", 0.8, 0), _run("all_b", 0.85, 0), _run("mixed", 0.5, 0)]))
	assert_eq(behind[1], "THREAT_BEST: no (threat 80.0, best all_b 85.0)")
	var tie := SweepMath.policy_verdicts(SweepMath.policy_ranking([_run("all_b", 0.8, 0), _run("threat", 0.8, 0)]))
	assert_eq(tie[1], "THREAT_BEST: yes (threat 80.0, best all_b 80.0)", "a tie for first counts as best")
