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

# --- E6 Task 16: the retune report (tests/sim/report_retune.gd), pure maths on literal rows ---

const LANES4 := ["east", "sw", "west", "north"]
const PAIRS := ["all_a", "all_b", "mixed", "volley_stone"]

## The pinned sets, written out by hand (the scan of LaneCharacter.for_run from seed 1; set #2 computed once, then pinned).
func test_seed_sets_are_the_pinned_literals_and_the_scan_reproduces_them() -> void:
	var scan_tuning := {"east": [1], "sw": [3], "west": [4], "north": [7]}
	var tuning := {"east": [1], "sw": [3], "west": [4], "north": [7, 14]}
	var h1 := {"east": [2, 5], "sw": [10, 12], "west": [6, 13], "north": [9, 14]}
	var h2 := {"east": [8, 11], "sw": [21, 23], "west": [18, 25], "north": [16, 19]}
	var m3 := {"east": [15, 17], "sw": [28, 29], "west": [30, 36], "north": [22, 26]}
	var m4 := {"east": [20, 24], "sw": [33, 34], "west": [39, 48], "north": [27, 32]}
	assert_eq(SweepMath.MEASURE_SET_3, m3, "E7 measurement set #3: scan positions 6 and 7")
	assert_eq(SweepMath.MEASURE_SET_4, m4, "E7 measurement set #4: scan positions 8 and 9")
	assert_eq(SweepMath.SCAN_TUNING_SET, scan_tuning)
	assert_eq(SweepMath.PROMOTED_TO_TUNING, {"north": [14]}, "D-304: seed 14 is promoted")
	assert_eq(SweepMath.TUNING_SET, tuning, "D-304: the tuning set is the scan's tuning seeds plus north 14")
	assert_eq(SweepMath.HOLDOUT_SET_1, h1, "retired, the literal is kept for the history")
	assert_eq(SweepMath.HOLDOUT_SET_2, h2)
	var scan := SweepMath.seed_scan(func(s): return String(LaneCharacter.for_run(s).siege), LANES4)
	assert_eq(scan.tuning, scan_tuning, "the scan, not the constant, is the rule")
	assert_eq(scan.holdout1, h1)
	assert_eq(scan.holdout2, h2)
	assert_eq(scan.set3, m3, "set #3 is positions 6 and 7 of the same scan")
	assert_eq(scan.set4, m4, "set #4 is positions 8 and 9 of the same scan")
	assert_eq(SweepMath.SCAN_PER_LANE, 9, "positions 10 and 11 are not scanned, so not named")
	assert_eq(SweepMath.with_promotion(scan.tuning, SweepMath.PROMOTED_TO_TUNING), SweepMath.TUNING_SET)

func test_with_promotion_appends_per_lane_once() -> void:
	var base := {"east": [1], "north": [7]}
	assert_eq(SweepMath.with_promotion(base, {"north": [14]}), {"east": [1], "north": [7, 14]})
	assert_eq(SweepMath.with_promotion(base, {"north": [7]}), base, "a seed already there is not added twice")
	assert_eq(SweepMath.with_promotion(base, {}), base)
	assert_eq(base, {"east": [1], "north": [7]}, "the input is not changed")
	assert_eq(SweepMath.set_seeds(SweepMath.TUNING_SET), [1, 3, 4, 7, 14], "lane order east, sw, west, north; two seeds on north")

func test_hold_out_set_1_is_retired_set_2_is_spent_and_set_3_is_open() -> void:
	var r := SweepMath.retired_gate("1")
	assert_true(r.refused)
	assert_string_contains(String(r.lines[0]), "retired (D-304)")
	var sp := SweepMath.retired_gate("2")
	assert_true(sp.refused)
	assert_string_contains(String(sp.lines[0]), "D-307")
	assert_string_contains(String(sp.lines[0]), "spent")
	assert_eq(SweepMath.SPENT_SETS, ["2"])
	assert_false(SweepMath.set_by_id("2").is_empty(), "the literal stays readable for the history")
	for ok_id in ["tuning", "3", "4"]:
		assert_false(SweepMath.retired_gate(ok_id).refused, ok_id)
		assert_true(SweepMath.retired_gate(ok_id).lines.is_empty())
	assert_false(SweepMath.set_by_id("1").is_empty(), "the literal stays readable for the history")
	assert_eq(SweepMath.RETIRED_SETS, ["1"])

## A lane with two tuning seeds (north 7 and 14): the per-lane lines average over both seeds and list each.
func test_lane_verdicts_work_with_two_tuning_seeds_on_one_lane() -> void:
	var rows: Array = []
	for s in SweepMath.set_seeds(SweepMath.TUNING_SET):
		var lane := SweepMath.seed_lane(SweepMath.TUNING_SET, s)
		for p in PAIRS:
			rows.append(_row(s, lane, p, 0.50))
		rows.append(_row(s, lane, "threat", 0.60))
		rows.append(_row(s, lane, "unbranched", 0.40))
	_put(rows, "threat", 7, {"mean_frac": 0.56})
	_put(rows, "threat", 14, {"mean_frac": 0.46})  # north: (+6 + -4) / 2 = +1
	var res := SweepMath.threat_lead_by_lane(rows)
	assert_true(res.ok, "north mean +1.0 is not negative")
	assert_string_contains(_line(res, "  lane north"), "+1.0")
	assert_string_contains(_line(res, "  seed 7"), "+6.0")
	assert_string_contains(_line(res, "  seed 14"), "-4.0")
	assert_string_contains(_line(res, "  lane east"), "+10.0")
	_put(rows, "threat", 14, {"mean_frac": 0.40})  # north: (+6 + -10) / 2 = -2
	assert_false(SweepMath.threat_lead_by_lane(rows).ok, "north mean -2.0 fails")
	var lead := SweepMath.threat_lead(rows)
	assert_string_contains(lead.lines[0], "of 5 seeds")

func test_the_three_sets_are_disjoint_and_in_scan_order() -> void:
	# D-304: the scan's tuning set, retired set #1 and set #2 are disjoint and in scan order; the run tuning set differs from the scan's only by the promoted seed 14,
	# which is also in the retired set #1 literal (the one allowed overlap).
	var seen := {}
	for set in [SweepMath.SCAN_TUNING_SET, SweepMath.HOLDOUT_SET_1, SweepMath.HOLDOUT_SET_2, SweepMath.MEASURE_SET_3, SweepMath.MEASURE_SET_4]:
		for s in SweepMath.set_seeds(set):
			assert_false(seen.has(s), "seed %d is in two sets" % s)
			seen[s] = true
	assert_eq(seen.size(), 4 + 8 + 8 + 8 + 8)
	for lane in LANES4:
		var all: Array = SweepMath.SCAN_TUNING_SET[lane] + SweepMath.HOLDOUT_SET_1[lane] + SweepMath.HOLDOUT_SET_2[lane] + SweepMath.MEASURE_SET_3[lane] + SweepMath.MEASURE_SET_4[lane]
		var sorted_all := all.duplicate()
		sorted_all.sort()
		assert_eq(all, sorted_all, "%s: tuning, then #1, #2, #3, #4, each later in the scan" % lane)
	var overlap: Array = []
	for s in SweepMath.set_seeds(SweepMath.TUNING_SET):
		assert_false(s in SweepMath.set_seeds(SweepMath.MEASURE_SET_3), "tuning seed %d must not be in the measurement set #3" % s)
		assert_false(s in SweepMath.set_seeds(SweepMath.MEASURE_SET_4), "tuning seed %d must not be in the measurement set #4" % s)
		if s in SweepMath.set_seeds(SweepMath.HOLDOUT_SET_1):
			overlap.append(s)
	assert_eq(overlap, [14], "the only seed the run tuning set shares with the retired set #1 is the promoted one")
	assert_eq(SweepMath.set_seeds(SweepMath.HOLDOUT_SET_1), [2, 5, 10, 12, 6, 13, 9, 14], "lane order east, sw, west, north; scan order inside a lane")

## A made-up lane function: seed % 4 picks the lane. Mutation: a scan that restarts at a wrong value, or takes seeds in a different order.
func test_seed_scan_on_a_synthetic_lane_function() -> void:
	var scan := SweepMath.seed_scan(func(s): return LANES4[s % 4], LANES4)
	assert_eq(scan.tuning, {"east": [4], "sw": [1], "west": [2], "north": [3]}, "first seed per lane, scanning from 1")
	assert_eq(scan.holdout1, {"east": [8, 12], "sw": [5, 9], "west": [6, 10], "north": [7, 11]})
	assert_eq(scan.holdout2, {"east": [16, 20], "sw": [13, 17], "west": [14, 18], "north": [15, 19]})

# rows: {seed, lane, policy, mean_frac, retry_nights, first_t3_frac, fence_median, income_at_cap, hare_share, guard_hits}
func _row(seed: int, lane: String, policy: String, frac: float, extra := {}) -> Dictionary:
	var r := {"seed": seed, "lane": lane, "policy": policy, "mean_frac": frac, "retry_nights": 0, "first_t3_frac": 0.5, "fence_median": 10, "income_at_cap": 100,
		"hare_share": 0.7, "hare_share_min": 0.7, "guard_hits": 0, "max_retries": 0, "max_retries_day": -1, "unspent_before": [], "unspent_after": [], "unspent_last": 0, "ladder_done": false, "first_t3_retries": 0, "worst_night_frac": 0.5, "worst_night_day": 20}
	r.merge(extra, true)
	return r

## 8 seeds (hold-out #1) x 6 policies. The four fixed pairs sit at `fixed` (fraction), threat at `fixed + lead/100` on every seed, unbranched at 0.40.
func _grid(fixed := 0.50, lead := 10.0) -> Array:
	var rows: Array = []
	var seeds := SweepMath.set_seeds(SweepMath.HOLDOUT_SET_1)
	for s in seeds:
		var lane := ""
		for l in LANES4:
			if s in SweepMath.HOLDOUT_SET_1[l]:
				lane = l
		for p in PAIRS:
			rows.append(_row(s, lane, p, fixed))
		rows.append(_row(s, lane, "threat", fixed + lead / 100.0))
		rows.append(_row(s, lane, "unbranched", 0.40))
	return rows

func _put(rows: Array, policy: String, seed: int, extra: Dictionary) -> void:
	for r in rows:
		if r.policy == policy and r.seed == seed:
			r.merge(extra, true)

func _line(res: Dictionary, prefix: String) -> String:
	for l in res.lines:
		if String(l).begins_with(prefix):
			return l
	return ""

func test_threat_lead_passes_at_exactly_five_points_and_fails_just_below() -> void:
	assert_true(SweepMath.threat_lead(_grid(0.50, 5.0)).ok, "mean lead 5.0 is inside")
	var low := SweepMath.threat_lead(_grid(0.50, 4.9))
	assert_false(low.ok, "mean lead 4.9 is outside")
	assert_string_contains(low.lines[0], "THREAT_LEAD: FAIL")
	assert_string_contains(SweepMath.threat_lead(_grid(0.50, 10.0)).lines[0], "THREAT_LEAD: PASS")

## Ahead on 6 of 8 passes, on 5 of 8 fails, with the mean lead kept at 10 in both cases. Mutation: counting ties as ahead.
func test_threat_lead_final_set_needs_six_of_eight_seeds_ahead() -> void:
	var rows := _grid(0.50, 10.0)
	var seeds := SweepMath.set_seeds(SweepMath.HOLDOUT_SET_1)
	# seeds 0 and 1 of the list: threat ties the fixed pairs (lead 0); seeds 2 and 3 get +20 so the mean stays 10.
	for i in 2:
		_put(rows, "threat", seeds[i], {"mean_frac": 0.50})
	for i in [2, 3]:
		_put(rows, "threat", seeds[i], {"mean_frac": 0.70})
	var six := SweepMath.threat_lead(rows, true)
	assert_true(six.ok, "ahead on 6 of 8 (the two ties are not ahead): %s" % six.lines[0])
	_put(rows, "threat", seeds[4], {"mean_frac": 0.50})
	_put(rows, "threat", seeds[5], {"mean_frac": 0.70})
	var five := SweepMath.threat_lead(rows, true)
	assert_false(five.ok, "ahead on 5 of 8 fails even though the mean lead is %s" % five.lines[0])

## The best fixed pair is the one with the best MEAN over the seeds, one pair for every seed. Mutation: the best pair per seed (lead 0 here).
func test_threat_lead_compares_with_the_best_pair_by_mean() -> void:
	var rows := _grid(0.50, 10.0)
	var seeds := SweepMath.set_seeds(SweepMath.HOLDOUT_SET_1)
	_put(rows, "all_a", seeds[0], {"mean_frac": 0.62})  # all_a: mean 0.515, the best pair; on seed 0 it is above threat's 0.60
	var res := SweepMath.threat_lead(rows)
	assert_string_contains(res.lines[0], "all_a")
	assert_string_contains(res.lines[0], "on 7 of 8", "seed 0 is behind all_a (0.60 < 0.62)")
	assert_string_contains(res.lines[0], "mean lead +8.5", "(60 - 51.5)")

func test_threat_lead_by_lane_is_not_negative_on_any_lane() -> void:
	var rows := _grid(0.50, 10.0)
	var east: Array = SweepMath.HOLDOUT_SET_1.east
	for s in east:
		_put(rows, "threat", s, {"mean_frac": 0.50})  # lead 0 on east: not negative
	assert_true(SweepMath.threat_lead_by_lane(rows).ok, "a lane mean of exactly 0 is inside")
	_put(rows, "threat", east[0], {"mean_frac": 0.49})  # east mean -0.5
	var res := SweepMath.threat_lead_by_lane(rows)
	assert_false(res.ok, "a lane mean below 0 is outside, although the overall lead is 7.4")
	assert_string_contains(_line(res, "  lane east"), "-0.5")
	assert_true(SweepMath.threat_lead(rows).ok, "the overall target alone still passes: the lane line is what catches it")

func test_per_lane_lead_values_in_the_by_lane_lines() -> void:
	var rows := _grid(0.50, 10.0)
	for s in SweepMath.HOLDOUT_SET_1.sw:
		_put(rows, "threat", s, {"mean_frac": 0.58})
	var res := SweepMath.threat_lead_by_lane(rows)
	assert_true(res.ok)
	assert_string_contains(_line(res, "  lane sw"), "+8.0")
	assert_string_contains(_line(res, "  lane west"), "+10.0")
	assert_string_contains(_line(res, "  seed 10"), "+8.0")

func test_retry_nights_is_zero_for_every_policy_except_unbranched_which_is_only_a_reference() -> void:
	assert_true(SweepMath.retry_nights(_grid()).ok)
	var rows := _grid()
	_put(rows, "unbranched", 14, {"retry_nights": 3})
	var res := SweepMath.retry_nights(rows)
	assert_true(res.ok, "unbranched retries never change the verdict")
	assert_string_contains(res.lines[0], "unbranched 3 (reference, not a target)")
	_put(rows, "threat", 9, {"retry_nights": 1})
	var bad := SweepMath.retry_nights(rows)
	assert_false(bad.ok, "another policy's single retry night still fails it")
	assert_string_contains(bad.lines[0], "threat 1")

func test_first_t3_night_covers_unbranched_too() -> void:
	var rows := _grid()
	_put(rows, "unbranched", 5, {"first_t3_frac": 0.24})
	assert_false(SweepMath.first_t3_night(rows).ok, "an unbranched first night at 24% fails the verdict")
	_put(rows, "unbranched", 5, {"first_t3_frac": 0.25})
	assert_true(SweepMath.first_t3_night(rows).ok)

## UNBRANCHED_FLAG: more than 2 mercy retries on a night, or more than 3 retry nights on a seed.
func test_unbranched_flag_boundaries() -> void:
	var rows := _grid()
	_put(rows, "unbranched", 5, {"retry_nights": 3, "max_retries": 2, "max_retries_day": 22})
	var no := SweepMath.unbranched_report(rows)
	assert_string_contains(_line(no, "UNBRANCHED_FLAG:"), "UNBRANCHED_FLAG: no")
	assert_string_contains(_line(no, "UNBRANCHED_RETRIES"), "5:3")
	_put(rows, "unbranched", 5, {"max_retries": 3})
	var yes := SweepMath.unbranched_report(rows)
	assert_string_contains(_line(yes, "UNBRANCHED_FLAG:"), "UNBRANCHED_FLAG: yes")
	assert_string_contains(_line(yes, "UNBRANCHED_FLAG:"), "seed 5 night day 22 needed 3 retries")
	_put(rows, "unbranched", 5, {"max_retries": 2, "retry_nights": 4})
	var many := SweepMath.unbranched_report(rows)
	assert_string_contains(_line(many, "UNBRANCHED_FLAG:"), "UNBRANCHED_FLAG: yes")
	assert_string_contains(_line(many, "UNBRANCHED_FLAG:"), "seed 5 had 4 retry nights")
	assert_false(SweepMath.unbranched_report(_grid()).flag)
	_put(rows, "threat", 5, {"retry_nights": 9, "max_retries": 4})
	_put(rows, "unbranched", 5, {"max_retries": 0, "retry_nights": 0})
	assert_false(SweepMath.unbranched_report(rows).flag, "only the unbranched rows count")

## Unspent gold at close-up over the tier-3 days: pooled over the seeds; before the ladder completes, from the completion day on, and the last day.
func test_unspent_lines_pool_the_seeds_and_split_at_the_ladder() -> void:
	var rows := _grid()
	for r in rows:
		r.unspent_before = []
		r.unspent_after = []
		r.unspent_last = 0
	_put(rows, "threat", 2, {"unspent_before": [100, 300, 200], "unspent_after": [400, 500], "unspent_last": 500, "ladder_done": true})
	_put(rows, "threat", 5, {"unspent_before": [50], "unspent_after": [900, 700], "unspent_last": 700, "ladder_done": true})
	_put(rows, "threat", 9, {"unspent_before": [10, 20], "unspent_after": [], "unspent_last": 20, "ladder_done": false})
	var lines := SweepMath.unspent_lines(rows)
	var before := _line({"lines": lines}, "UNSPENT_T3 threat")
	assert_string_contains(before, "median 75.0", "100 300 200 50 10 20: sorted 10 20 50 100 200 300")
	assert_string_contains(before, "max 300")
	var after := _line({"lines": lines}, "UNSPENT_AFTER_LADDER threat")
	assert_string_contains(after, "median 600.0", "400 500 900 700")
	assert_string_contains(after, "max 900")
	assert_string_contains(after, "ladder completed in 2 of 8 runs")
	assert_string_contains(after, "last-day median 0.0", "median over the 8 seeds of the last day: 0 0 0 0 0 20 500 700")
	var none := _line({"lines": lines}, "UNSPENT_AFTER_LADDER all_a")
	assert_string_contains(none, "n/a")
	assert_string_contains(none, "ladder completed in 0 of 8 runs")

func test_targets_summary_names_the_failing_targets_and_ignores_hare_share_and_unbranched_lines() -> void:
	var good := SweepMath.retune_report(_grid(), _expected(), true)
	assert_eq(good.failed, [])
	assert_true(good.ok)
	var rows := _grid()
	_put(rows, "threat", 9, {"retry_nights": 1})
	for r in rows:
		if r.seed == 13:
			r.hare_share = 0.1
		r.guard_hits = 0
	_put(rows, "mixed", 9, {"guard_hits": 1})
	var res := SweepMath.retune_report(rows, _expected(), true)
	assert_eq(res.failed, ["RETRY_NIGHTS", "LANE_CAP_GUARD"], "HARE_SHARE flags are not a target")
	assert_false(res.ok)
	var unb := _grid()
	_put(unb, "unbranched", 9, {"retry_nights": 5, "max_retries": 4, "max_retries_day": 3})
	var r2 := SweepMath.retune_report(unb, _expected(), true)
	assert_true(r2.ok, "the unbranched flag never changes ALL PASS")
	assert_ne(_line(r2, "UNBRANCHED_FLAG: yes"), "")

func test_retune_run_stats_max_retries_and_unspent_split() -> void:
	var nights := [
		{"day": 3, "tier": 2, "frac": 0.1, "retries": 4},
		{"day": 22, "tier": 3, "frac": 0.4, "retries": 1},
		{"day": 23, "tier": 3, "frac": 0.5, "retries": 3},
		{"day": 24, "tier": 3, "frac": 0.6, "retries": 3},
	]
	var s := SweepMath.retune_run_stats(nights)
	assert_eq(s.max_retries, 3, "tier-3 nights only: the tier-2 night's 4 does not count")
	assert_eq(s.max_retries_day, 23, "the first night with the maximum")
	var days := [{"day": 21, "tier": 3, "unspent": 100, "done": false}, {"day": 22, "tier": 3, "unspent": 300, "done": false},
		{"day": 23, "tier": 3, "unspent": 500, "done": true}, {"day": 24, "tier": 3, "unspent": 900, "done": true}, {"day": 20, "tier": 2, "unspent": 50, "done": false}]
	var u := SweepMath.unspent_split(days)
	assert_eq(u.before, [100, 300], "tier-3 days before the completion day")
	assert_eq(u.after, [500, 900], "from the completion day on")
	var never := SweepMath.unspent_split([days[0], days[1]])
	assert_eq(never.before, [100, 300])
	assert_eq(never.after, [])

func test_first_t3_night_below_25_percent_fails() -> void:
	var rows := _grid()
	_put(rows, "all_b", 5, {"first_t3_frac": 0.25})
	assert_true(SweepMath.first_t3_night(rows).ok, "exactly 25% is inside")
	_put(rows, "all_b", 5, {"first_t3_frac": 0.249})
	var res := SweepMath.first_t3_night(rows)
	assert_false(res.ok, "24.9% is outside")
	assert_string_contains(_line(res, "  seed 5"), "24.9")

func test_fence_tax_30_percent_median_with_and_without_longbow() -> void:
	var rows := _grid()  # every run: 10 of 100 = 10%
	var res := SweepMath.fence_tax(rows)
	assert_true(res.ok)
	assert_string_contains(res.lines[0], "FENCE_TAX: PASS")
	assert_string_contains(_line(res, "  with Longbow on the siege lane"), "10.0")
	assert_string_contains(_line(res, "  without Longbow on the siege lane"), "10.0")
	for r in rows:
		r.fence_median = 30
	assert_true(SweepMath.fence_tax(rows).ok, "a median of exactly 30% is inside")
	for r in rows:
		r.fence_median = 31
	assert_false(SweepMath.fence_tax(rows).ok, "31% is outside")

## The groups differ: Longbow policies (all_a, mixed, threat) at 20%, the others at 40%. Median of the 48 shares = 30.
func test_fence_tax_groups_are_split_by_longbow_and_the_gate_is_the_overall_median() -> void:
	var rows := _grid()
	for r in rows:
		r.fence_median = 20 if r.policy in ["all_a", "mixed", "threat"] else 40
	var res := SweepMath.fence_tax(rows)
	assert_string_contains(_line(res, "  with Longbow on the siege lane"), "20.0")
	assert_string_contains(_line(res, "  without Longbow on the siege lane"), "40.0")
	assert_true(res.ok, "overall median (24 runs at 20, 24 at 40) is 30")
	_put(rows, "threat", 2, {"fence_median": 41})  # one low run moves up: 23 low, 25 high
	assert_false(SweepMath.fence_tax(rows).ok, "25 of 48 runs above 30: the median is above 30")

func test_fence_tax_without_a_cap_day_is_na_and_not_a_pass() -> void:
	var rows := _grid()
	for r in rows:
		r.income_at_cap = 0
	var res := SweepMath.fence_tax(rows)
	assert_false(res.ok)
	assert_string_contains(res.lines[0], "FENCE_TAX: N/A")

func test_fixed_spread_within_15_points() -> void:
	var rows := _grid()
	for r in rows:
		if r.policy == "all_a":
			r.mean_frac = 0.55
		elif r.policy == "volley_stone":
			r.mean_frac = 0.40
	assert_true(SweepMath.fixed_spread(rows).ok, "55 minus 40 is 15.0, inside")
	for r in rows:
		if r.policy == "volley_stone":
			r.mean_frac = 0.399
	assert_false(SweepMath.fixed_spread(rows).ok, "15.1 is outside")
	for r in rows:
		if r.policy == "volley_stone":
			r.mean_frac = 0.40  # back to the passing 15.0 state
		elif r.policy == "threat":
			r.mean_frac = 0.99
		elif r.policy == "unbranched":
			r.mean_frac = 0.01
	assert_true(SweepMath.fixed_spread(rows).ok, "threat and unbranched are not fixed pairs: the passing verdict does not move")

func test_hare_share_is_flagged_below_0_6_per_seed() -> void:
	var rows := _grid()
	for r in rows:
		if r.seed == 13:
			r.hare_share = 0.6
	assert_true(SweepMath.hare_share(rows).ok, "exactly 0.6 is not flagged")
	for r in rows:
		if r.seed == 13:
			r.hare_share = 0.59
	var res := SweepMath.hare_share(rows)
	assert_false(res.ok)
	assert_string_contains(_line(res, "  seed 13"), "FLAGGED")
	assert_false("FLAGGED" in _line(res, "  seed 14"))

func test_lane_cap_guard_counts_hits() -> void:
	assert_true(SweepMath.lane_cap_guard(_grid()).ok)
	var rows := _grid()
	_put(rows, "mixed", 9, {"guard_hits": 2})
	var res := SweepMath.lane_cap_guard(rows)
	assert_false(res.ok)
	assert_string_contains(res.lines[0], "hits 2")

func test_retune_run_stats_first_night_hare_share_and_guard() -> void:
	var nights := [
		{"tier": 2, "frac": 0.05, "hare_share": -1.0, "guard_hits": 0},
		{"tier": 3, "frac": 0.40, "hare_share": 0.6, "guard_hits": 0},
		{"tier": 3, "frac": 0.90, "hare_share": -1.0, "guard_hits": 1},
		{"tier": 3, "frac": 0.80, "hare_share": 0.8, "guard_hits": 2},
	]
	var s := SweepMath.retune_run_stats(nights)
	assert_almost_eq(s.first_t3_frac, 0.40, 1e-9, "the first night that STARTED at tier 3, not the tier-2 night")
	assert_almost_eq(s.hare_share_mean, 0.7, 1e-9, "nights without hares are left out")
	assert_almost_eq(s.hare_share_min, 0.6, 1e-9)
	assert_eq(s.guard_hits, 3)
	assert_eq(s.t3_nights, 3)
	var none := SweepMath.retune_run_stats([nights[0]])
	assert_eq(none.t3_nights, 0)
	assert_eq(none.first_t3_frac, -1.0)

const DATE := "2026-10-13T10:00:00+02:00"

func test_final_gate_refuses_hold_out_sets_without_final() -> void:
	for set_id in ["3", "4"]:
		var g := SweepMath.final_gate(set_id, false, "abc1234", {"history": []}, DATE)
		assert_false(g.allowed, "set %s without --final" % set_id)
		assert_string_contains(g.lines[0], "REFUSED")
		assert_string_contains(g.lines[0], "--final", "the reason is the missing flag")
		assert_eq(g.record, {"history": []}, "nothing recorded when refused")
	var t := SweepMath.final_gate("tuning", false, "abc1234", {"history": []}, DATE)
	assert_true(t.allowed, "the tuning set needs no flag")
	assert_eq(t.record, {"history": []})

## D-304: the retired set is refused inside final_gate too, with and without --final, on a clean commit; nothing is recorded.
func test_final_gate_refuses_the_retired_set_1_always() -> void:
	for final_flag in [false, true]:
		var g := SweepMath.final_gate("1", final_flag, "abc1234", {"history": []}, DATE)
		assert_false(g.allowed, "retired set #1, final=%s" % final_flag)
		assert_string_contains(g.lines[0], "REFUSED")
		assert_string_contains(g.lines[0], "retired")
		assert_eq(g.lines, SweepMath.retired_gate("1").lines, "the same message as retired_gate")
		assert_eq(g.record, {"history": []}, "nothing recorded")

## D-307: the spent set #2 is refused always, naming D-307; nothing is recorded.
func test_final_gate_refuses_the_spent_set_2_always() -> void:
	for final_flag in [false, true]:
		var g := SweepMath.final_gate("2", final_flag, "abc1234", {"history": []}, DATE)
		assert_false(g.allowed, "spent set #2, final=%s" % final_flag)
		assert_string_contains(g.lines[0], "D-307")
		assert_eq(g.lines, SweepMath.retired_gate("2").lines)
		assert_eq(g.record, {"history": []}, "nothing recorded")

## E7: set #3 needs --final; it may run twice with different bot rules, never twice with the same rule.
func test_final_gate_set_3_needs_final_and_runs_once_per_bot_rule() -> void:
	var no := SweepMath.final_gate("3", false, "abc1234", {"history": []}, DATE, 32, "old")
	assert_false(no.allowed)
	assert_string_contains(no.lines[0], "--final")
	var first := SweepMath.final_gate("3", true, "abc1234", {"history": []}, DATE, 32, "old")
	assert_true(first.allowed)
	assert_eq(first.record.history[0].bot_rule, "old")
	assert_string_contains(_line(first, "FINAL set=#3"), "bot_rule=old")
	var done := SweepMath.final_finish(first.record, false)
	var second := SweepMath.final_gate("3", true, "def5678", done, DATE, 32, "walk")
	assert_true(second.allowed, "a different bot rule is the second allowed run")
	assert_eq(second.record.history.size(), 2)
	assert_eq(second.record.history[1].bot_rule, "walk")
	assert_string_contains(_line(second, "FINAL_REPEAT"), "abc1234")
	var done2 := SweepMath.final_finish(second.record, true)
	for rule in ["old", "walk"]:
		var again := SweepMath.final_gate("3", true, "fff9999", done2, DATE, 32, rule)
		assert_false(again.allowed, "a repeat with rule %s is refused" % rule)
		assert_string_contains(again.lines[0], "bot rule '%s'" % rule)
		assert_eq(again.record, done2, "nothing recorded when refused")
	var bad := SweepMath.final_gate("3", true, "abc1234", {"history": []}, DATE, 32, "weird")
	assert_false(bad.allowed)
	# an entry from a set #1 / #2 run never blocks set #3
	var other := {"history": [{"set": "2", "commit": "b820c89", "date": DATE, "days": 32, "done": true, "ok": false}]}
	assert_true(SweepMath.final_gate("3", true, "abc1234", other, DATE, 32, "walk").allowed)

## Escalation 16: three rules, one run each per measurement set; a history entry `new` (before the walk-time rule) is the never-cross bot, `far`; set #4 is gated like set #3 and independent of it.
func test_final_gate_three_bot_rules_set_4_and_the_legacy_new_entry() -> void:
	assert_eq(SweepMath.BOT_RULES, ["walk", "far", "old"])
	var legacy := {"history": [{"set": "3", "commit": "9a86ae2", "date": DATE, "days": 32, "bot_rule": "new", "done": true, "ok": false, "complete": true}]}
	assert_false(SweepMath.final_gate("3", true, "abc1234", legacy, DATE, 32, "far").allowed, "a legacy `new` entry is a far run")
	assert_true(SweepMath.final_gate("3", true, "abc1234", legacy, DATE, 32, "walk").allowed, "set #3 with the walk-time rule is still open")
	assert_true(SweepMath.final_gate("3", true, "abc1234", legacy, DATE, 32, "old").allowed)
	assert_false(SweepMath.final_gate("3", true, "abc1234", legacy, DATE, 32, "new").allowed, "`new` is no longer a rule to run")
	var h: Dictionary = {"history": []}
	for rule in ["walk", "far", "old"]:
		var g := SweepMath.final_gate("4", true, "abc1234", h, DATE, 32, rule)
		assert_true(g.allowed, "set #4, rule %s, first run" % rule)
		assert_string_contains(_line(g, "FINAL set=#4"), "bot_rule=%s" % rule)
		h = SweepMath.final_finish(g.record, false, "", true)
	for rule in ["walk", "far", "old"]:
		assert_false(SweepMath.final_gate("4", true, "def5678", h, DATE, 32, rule).allowed, "set #4, rule %s, second run" % rule)
	assert_false(SweepMath.final_gate("4", false, "abc1234", {"history": []}, DATE, 32, "walk").allowed, "set #4 needs --final")
	assert_true(SweepMath.final_gate("3", true, "abc1234", h, DATE, 32, "walk").allowed, "set #4 entries never block set #3")
	assert_eq(SweepMath.canon_bot_rule("new"), "far")
	assert_eq(SweepMath.canon_bot_rule("walk"), "walk")

## A run that printed no verdict (complete false) did not read the set: it does not block a re-run with its bot rule; a complete entry, or one without the field, does.
func test_final_gate_incomplete_entry_does_not_block_a_rerun() -> void:
	var first := SweepMath.final_gate("3", true, "abc1234", {"history": []}, DATE, 32, "old")
	var incomplete := SweepMath.final_finish(first.record, false, "", false)
	assert_false(incomplete.history[0].complete)
	var again := SweepMath.final_gate("3", true, "def5678", incomplete, DATE, 32, "old")
	assert_true(again.allowed, "an incomplete entry does not block")
	assert_string_contains(_line(again, "FINAL_EARLIER"), "complete=false")
	var complete := SweepMath.final_finish(first.record, false, "", true)
	assert_true(complete.history[0].complete)
	var blocked := SweepMath.final_gate("3", true, "def5678", complete, DATE, 32, "old")
	assert_false(blocked.allowed, "a complete entry blocks")
	var nofield := {"history": [{"set": "3", "commit": "abc1234", "date": DATE, "days": 32, "bot_rule": "old", "done": true, "ok": false}]}
	assert_false(SweepMath.final_gate("3", true, "def5678", nofield, DATE, 32, "old").allowed, "a missing field counts as complete")
	assert_string_contains(_line(SweepMath.final_gate("3", true, "def5678", nofield, DATE, 32, "walk"), "FINAL_EARLIER"), "complete=true")

func test_far_walks_total_line_sums_per_policy() -> void:
	var rows: Array = [{"policy": "all_a", "far_walks": 2}, {"policy": "all_a", "far_walks": 3}, {"policy": "threat", "far_walks": 1}, {"policy": "mixed"}]
	var line := SweepMath.far_walks_total_line(rows)
	assert_string_contains(line, "FAR_WALKS_TOTAL ")
	assert_string_contains(line, "all_a=5")
	assert_string_contains(line, "threat=1")
	assert_string_contains(line, "mixed=0")
	assert_string_contains(line, "all=6")
	var kv := {"mean": "0.5", "hard_break_day": "-1"}
	assert_eq(SweepMath.run_row(5, "east", "threat", kv, {"x": "1"}, {"far_walks": "4", "far_kept": "7", "first_t3_frac": "0.5"}).far_walks, 4)
	assert_eq(SweepMath.run_row(5, "east", "threat", kv, {"x": "1"}, {"far_walks": "4", "far_kept": "7", "first_t3_frac": "0.5"}).far_kept, 7)
	assert_string_contains(SweepMath.far_walks_total_line([{"policy": "all_a", "far_kept": 3}, {"policy": "threat", "far_kept": 2}], "far_kept", "FAR_KEPT_TOTAL"), "FAR_KEPT_TOTAL all_a=3")

func test_final_gate_refuses_final_with_the_tuning_set() -> void:
	var g := SweepMath.final_gate("tuning", true, "abc1234", {"history": []}, DATE)
	assert_false(g.allowed, "--final without --set must not run the tuning set silently")
	assert_string_contains(g.lines[0], "REFUSED")
	assert_string_contains(g.lines[0], "--final")
	assert_eq(g.record, {"history": []})

func test_final_gate_refuses_a_dirty_tree_and_an_unknown_commit() -> void:
	for c in ["abc1234-dirty", "unknown", ""]:
		var g := SweepMath.final_gate("3", true, c, {"history": []}, DATE)
		assert_false(g.allowed, "commit '%s'" % c)
		assert_string_contains(g.lines[0], "REFUSED")
		assert_eq(g.record, {"history": []}, "nothing recorded")
	assert_true(SweepMath.final_gate("3", true, "abc1234", {"history": []}, DATE).allowed, "a clean commit is fine")

func test_final_gate_records_set_commit_and_date_then_finish_marks_done_and_ok() -> void:
	var g := SweepMath.final_gate("3", true, "abc1234", {"history": []}, DATE)
	assert_true(g.allowed)
	assert_string_contains(g.lines[0], "FINAL set=#3 commit=abc1234")
	assert_eq(g.record, {"history": [{"set": "3", "commit": "abc1234", "date": DATE, "days": 32, "bot_rule": "walk", "done": false, "ok": false}]}, "recorded at the start: done is false until the run ends")
	var fin := SweepMath.final_finish(g.record, true)
	assert_eq(fin.history[0].done, true)
	assert_eq(fin.history[0].ok, true)
	assert_eq(g.record.history[0].done, false, "the input record is not mutated")
	var bad := SweepMath.final_finish(g.record, false)
	assert_eq([bad.history[0].done, bad.history[0].ok], [true, false])

## A second --final on set #3 (the other bot rule) at another commit shows in the output; every earlier entry (any set, here a retired set #1 entry already in the history file) is printed.
func test_final_gate_shows_every_earlier_entry_and_a_repeat_at_a_different_commit() -> void:
	var old := {"history": [{"set": "1", "commit": "abc1234", "date": DATE, "days": 32, "done": true, "ok": false}]}
	var two := SweepMath.final_gate("3", true, "bbb2222", old, DATE, 32, "old")
	assert_eq(_line(two, "FINAL_REPEAT"), "", "set #3 was never run")
	assert_string_contains(_line(two, "FINAL_EARLIER set=#1 commit=abc1234"), "ok=false")
	var again := SweepMath.final_gate("3", true, "def5678", SweepMath.final_finish(two.record, false), DATE, 32, "walk")
	assert_true(again.allowed)
	var earlier: Array = again.lines.filter(func(l): return String(l).begins_with("FINAL_EARLIER"))
	assert_eq(earlier.size(), 2, "one line per earlier entry, both sets")
	assert_string_contains(_line(again, "FINAL_REPEAT"), "bbb2222")
	assert_string_contains(_line(again, "FINAL_REPEAT"), "def5678")
	assert_eq(again.record.history.size(), 3)
	var same := SweepMath.final_gate("3", true, "bbb2222", two.record, DATE, 32, "walk")
	assert_string_contains(_line(same, "FINAL_REPEAT"), "same commit")

func test_parse_record_accepts_empty_and_valid_text_and_rejects_a_broken_file() -> void:
	assert_true(SweepMath.parse_record("").valid, "no file yet")
	assert_eq(SweepMath.parse_record("").record, {"history": []})
	var ok := SweepMath.parse_record('{"history": [{"set": "1", "commit": "abc", "date": "d", "done": true, "ok": true}]}')
	assert_true(ok.valid)
	assert_eq(ok.record.history.size(), 1)
	for bad in ["{not json", "[1,2]", '{"history": 5}', '{"other": []}']:
		assert_false(SweepMath.parse_record(bad).valid, bad)

func test_parse_record_keeps_days_an_int_so_a_rewrite_prints_32_not_32_point_0() -> void:
	var r := SweepMath.parse_record('{"history": [{"set": "1", "commit": "abc", "date": "d", "days": 32, "done": true, "ok": false}]}')
	assert_true(r.record.history[0].days is int, "days is an int after parsing")
	assert_eq(r.record.history[0].days, 32)
	assert_string_contains(JSON.stringify(r.record), '"days":32')
	assert_false(JSON.stringify(r.record).contains("32.0"))

## The seed-weighting line is derived from TUNING_SET (north has 2 of its 5 seeds) and only printed for the tuning set.
func test_the_seed_weighting_line_is_derived_for_the_tuning_set_and_absent_for_a_final_set() -> void:
	var total := 0
	for l in SweepMath.TUNING_SET:
		total += (SweepMath.TUNING_SET[l] as Array).size()
	var north: int = (SweepMath.TUNING_SET.north as Array).size()
	var tuning: Array = SweepMath.threat_lead(_grid(0.50, 10.0)).lines.filter(func(l): return String(l).contains("seed-weighted"))
	assert_eq(tuning.size(), 1, "present for the tuning set")
	assert_string_contains(tuning[0], "north has %d of the %d tuning seeds" % [north, total])
	var final: Array = SweepMath.threat_lead(_grid(0.50, 10.0), true).lines.filter(func(l): return String(l).contains("seed-weighted"))
	assert_eq(final.size(), 0, "absent for a final set")

func test_a_child_log_with_a_script_error_or_a_bad_exit_is_a_failed_run() -> void:
	var clean := "T3RUN x\nERROR: 8 resources still in use at exit (run with --verbose for details).\n"
	assert_false(SweepMath.child_failed(0, clean), "a benign plain ERROR at the end is not a failure")
	assert_true(SweepMath.child_failed(1, clean), "exit code 1")
	assert_true(SweepMath.child_failed(0, "x\nSCRIPT ERROR: Parse Error: y\n"), "a SCRIPT ERROR line")

func test_hare_share_ignores_rows_without_hares() -> void:
	var rows := _grid()
	for r in rows:
		if r.seed == 13:
			r.hare_share = 0.7 if r.policy in ["all_a", "threat"] else -1.0  # four runs had no hares: the mean over all six would be 0.7*2-4 over 6 = negative
	var res := SweepMath.hare_share(rows)
	assert_true(res.ok, "only the runs with hares count: mean 0.7")
	assert_false("FLAGGED" in _line(res, "  seed 13"))
	for r in rows:
		if r.seed == 13:
			r.hare_share = -1.0
	assert_string_contains(_line(SweepMath.hare_share(rows), "  seed 13"), "n/a")

func test_hare_share_min_is_printed_per_seed() -> void:
	var rows := _grid()
	for r in rows:
		r.hare_share_min = 0.5
		if r.seed == 14 and r.policy == "mixed":
			r.hare_share_min = 0.31
	var res := SweepMath.hare_share(rows)
	assert_string_contains(_line(res, "  seed 14"), "min night 0.310")
	assert_string_contains(_line(res, "  seed 13"), "min night 0.500")

## The tuning set (4 seeds) is judged by the mean lead alone; "ahead on k of 4" is information.
func test_threat_lead_on_the_tuning_set_needs_only_the_mean() -> void:
	var rows: Array = []
	var leads := [20.0, 20.0, 0.0, 0.0]  # mean 10, ahead on 2 of 4
	var i := 0
	for l in SweepMath.SIEGE_LANES:
		var s: int = SweepMath.TUNING_SET[l][0]
		for p in PAIRS:
			rows.append(_row(s, l, p, 0.50))
		rows.append(_row(s, l, "threat", 0.50 + leads[i] / 100.0))
		rows.append(_row(s, l, "unbranched", 0.40))
		i += 1
	var res := SweepMath.threat_lead(rows)
	assert_true(res.ok, res.lines[0])
	assert_string_contains(res.lines[0], "on 2 of 4")
	assert_false(SweepMath.threat_lead(rows, true).ok, "the same rows as a final set: ahead on 2 of 4 fails the final rule")
	rows[4].mean_frac = 0.52  # lane 1: lead 20 -> 2, lane 2: 20 -> 0: the mean falls to 0.5
	rows[10].mean_frac = 0.50
	rows[16].mean_frac = 0.50
	assert_false(SweepMath.threat_lead(rows).ok, "mean lead below 5 fails on the tuning set too")

## Information line: the lead against each seed's own best fixed pair (never the verdict).
func test_threat_lead_prints_the_lead_against_each_seeds_own_best_pair_as_information() -> void:
	var rows := _grid(0.50, 10.0)
	var seeds := SweepMath.set_seeds(SweepMath.HOLDOUT_SET_1)
	_put(rows, "all_a", seeds[0], {"mean_frac": 0.62})  # leads -2 against it on seed 0
	_put(rows, "all_b", seeds[1], {"mean_frac": 0.62})  # leads -2 against it on seed 1; all_a and all_b tie on the mean, all_a is first
	var res := SweepMath.threat_lead(rows)
	assert_string_contains(_line(res, "  info: lead against each seed's own best pair"), "+7.0", "(-2 -2 + 6 x 10) / 8")
	assert_string_contains(_line(res, "THREAT_LEAD:"), "mean lead +8.5", "the verdict still uses the best pair by mean: (-2 + 7 x 10) / 8")

func _expected() -> Array:
	var out: Array = []
	for r in _grid():
		out.append([r.seed, r.policy])
	return out

func test_report_with_every_run_prints_the_eight_verdict_lines_and_exits_0() -> void:
	var res := SweepMath.retune_report(_grid(), _expected())
	assert_eq(res.exit, 0)
	for key in ["THREAT_LEAD:", "THREAT_LEAD_BY_LANE:", "RETRY_NIGHTS:", "FIRST_T3_NIGHT:", "FENCE_TAX:", "FIXED_SPREAD:", "HARE_SHARE:", "LANE_CAP_GUARD:"]:
		assert_ne(_line(res, key), "", key)

## A missing run (no row), a failed run (hard break) and a run that never reached tier 3 each remove every verdict line and give exit 1.
func test_report_with_a_missing_or_failed_run_has_no_verdicts_and_exits_1() -> void:
	var missing := _grid()
	missing.remove_at(7)
	var cases := {"missing": missing}
	var broke := _grid()
	broke[3].failed = true
	cases["hard break"] = broke
	var no_t3 := _grid()
	no_t3[5].first_t3_frac = -1.0
	cases["no tier-3 night"] = no_t3
	for k in cases:
		var res := SweepMath.retune_report(cases[k], _expected())
		assert_eq(res.exit, 1, k)
		assert_string_contains(res.lines[0], "FAILED")
		for key in ["THREAT_LEAD", "RETRY_NIGHTS", "FIRST_T3_NIGHT", "FENCE_TAX", "FIXED_SPREAD", "HARE_SHARE", "LANE_CAP_GUARD"]:
			assert_eq(_line(res, key), "", "%s: no %s line" % [k, key])

func test_ladder_done_for_the_unbranched_policy_needs_no_branches() -> void:
	var spots := [{"kind": "tower", "level": 3, "branch": ""}, {"kind": "fence", "level": 3, "branch": ""}, {"kind": "grill", "level": 3, "branch": ""}]
	assert_false(SweepMath.ladder_done(spots, [3, 3], 3, 3), "default: a tower and a fence still need their branch")
	assert_true(SweepMath.ladder_done(spots, [3, 3], 3, 3, false), "unbranched: levels and stations are everything it can buy")
	spots[2].level = 2
	assert_false(SweepMath.ladder_done(spots, [3, 3], 3, 3, false), "a level still to buy")
	assert_false(SweepMath.ladder_done(spots.slice(0, 2), [3, 2], 3, 3, false), "a station still to buy")


# --- Whole-branch review round: a retried first tier-3 night is lost; --final needs 32 days; honest lead lines ---

func test_first_t3_night_that_needed_a_retry_counts_as_lost_whatever_the_mercy_result() -> void:
	var rows := _grid()
	_put(rows, "unbranched", 5, {"first_t3_frac": 0.912, "first_t3_retries": 1})
	var res := SweepMath.first_t3_night(rows)
	assert_false(res.ok, "attempt 1 lost, the mercy attempt cleared at 91.2%: still a lost night")
	assert_string_contains(_line(res, "  retried first night: seed 5 unbranched"), "1 retries")
	_put(rows, "unbranched", 5, {"first_t3_frac": 0.26, "first_t3_retries": 0})
	assert_true(SweepMath.first_t3_night(rows).ok, "no retry at 26% passes")
	_put(rows, "unbranched", 5, {"first_t3_frac": 0.24, "first_t3_retries": 0})
	assert_false(SweepMath.first_t3_night(rows).ok, "no retry at 24% fails")
	assert_eq(_line(SweepMath.first_t3_night(_grid()), "  retried first night"), "", "no retried line without a retry")

func test_retune_run_stats_first_night_retries_and_the_worst_first_attempt() -> void:
	var nights := [
		{"day": 21, "tier": 2, "frac": 0.1, "retries": 0, "first_frac": 0.1},
		{"day": 22, "tier": 3, "frac": 0.912, "retries": 2, "first_frac": 0.0},
		{"day": 23, "tier": 3, "frac": 0.8, "retries": 0, "first_frac": 0.8},
		{"day": 24, "tier": 3, "frac": 0.3, "retries": 0, "first_frac": 0.3},
	]
	var s := SweepMath.retune_run_stats(nights)
	assert_eq(s.first_t3_retries, 2, "the first tier-3 night's own retries")
	assert_almost_eq(s.first_t3_frac, 0.912, 1e-9, "the final attempt's number is kept (the verdict zeroes it when retried)")
	assert_almost_eq(s.worst_night_frac, 0.0, 1e-9, "the lowest FIRST attempt over the tier-3 nights")
	assert_eq(s.worst_night_day, 22)
	var none := SweepMath.retune_run_stats([nights[0]])
	assert_eq([none.first_t3_retries, none.worst_night_frac, none.worst_night_day], [0, -1.0, -1])

func test_final_gate_refuses_any_days_but_32_and_records_days() -> void:
	for d in [31, 33, 14]:
		var g := SweepMath.final_gate("3", true, "abc1234", {"history": []}, DATE, d)
		assert_false(g.allowed, "days %d" % d)
		assert_string_contains(g.lines[0], "32")
	var ok := SweepMath.final_gate("3", true, "abc1234", {"history": []}, DATE, 32)
	assert_true(ok.allowed)
	assert_eq(ok.record.history[0].days, 32)
	assert_true(SweepMath.final_gate("tuning", false, "abc1234", {"history": []}, DATE, 5).allowed, "the tuning set may use any days")

func test_final_finish_marks_not_ok_when_the_commit_changed_during_the_run() -> void:
	var g := SweepMath.final_gate("3", true, "abc1234", {"history": []}, DATE, 32)
	var same := SweepMath.final_finish(g.record, true, "abc1234")
	assert_true(same.history[0].ok)
	var moved := SweepMath.final_finish(g.record, true, "def5678")
	assert_false(moved.history[0].ok, "HEAD changed during the run")
	assert_eq(moved.history[0].changed_to, "def5678")
	var dirty := SweepMath.final_finish(g.record, true, "abc1234-dirty")
	assert_false(dirty.history[0].ok, "the tree changed during the run")
	assert_true(SweepMath.final_finish(g.record, true).history[0].ok, "no end commit given: no check")

func test_a_run_without_a_ladder_line_is_a_failed_run_not_a_dropped_one() -> void:
	var kv := {"mean": "0.5", "retry_nights": "0", "hard_break_day": "-1", "unspent_last_day": "10"}
	var rt := {"siege": "east", "first_t3_frac": "0.5", "hare_share_mean": "0.7", "hare_share_min": "0.7", "guard_hits": "0"}
	var ld := {"fence_rebuild_gold_median_at_cap": "10", "income_at_cap": "100", "ladder_done_day": "21"}
	var good := SweepMath.run_row(5, "east", "threat", kv, ld, rt)
	assert_false(good.failed)
	assert_eq(good.income_at_cap, 100)
	assert_eq(good.first_t3_retries, 0, "an absent new field defaults to 0")
	var bad := SweepMath.run_row(5, "east", "threat", kv, {}, rt)
	assert_true(bad.failed)
	assert_string_contains(bad.failed_reason, "LADDER")
	var rows := _grid()
	_put(rows, "threat", 5, {"failed": true, "failed_reason": "LADDER line missing"})
	var res := SweepMath.retune_report(rows, _expected(), true)
	assert_eq(res.exit, 1)
	assert_eq(_line(res, "THREAT_LEAD"), "", "no verdict lines")
	assert_string_contains("\n".join(res.lines), "LADDER line missing")

func test_fence_tax_notes_the_lower_bound() -> void:
	assert_string_contains(_line(SweepMath.fence_tax(_grid()), "  note:"), "lower bound")

func test_worst_night_and_spread_by_seed_lines() -> void:
	var rows := _grid()
	_put(rows, "mixed", 6, {"worst_night_frac": 0.21, "worst_night_day": 25})
	_put(rows, "mixed", 9, {"worst_night_frac": 0.33, "worst_night_day": 23})
	var lines := SweepMath.worst_night_lines(rows)
	assert_string_contains(_line({"lines": lines}, "WORST_NIGHT mixed"), "21.0% (seed 6, day 25)")
	assert_string_contains(_line({"lines": lines}, "WORST_NIGHT threat"), "50.0%")
	_put(rows, "all_a", 13, {"mean_frac": 0.62})  # fixed pairs on seed 13: 62, 50, 50, 50 -> spread 12
	var sp := _line({"lines": lines}, "SPREAD_BY_SEED")
	assert_string_contains(sp, "max 0.0 points")
	var lines2 := SweepMath.worst_night_lines(rows)
	assert_string_contains(_line({"lines": lines2}, "SPREAD_BY_SEED"), "max 12.0 points (seed 13)")
	var res := SweepMath.retune_report(rows, _expected(), true)
	assert_ne(_line(res, "WORST_NIGHT"), "")

## "Ahead" needs a lead of at least AHEAD_MARGIN (1.0); the count of level seeds (within +-1.0) is printed; the own-best-pair lead is on the main line.
func test_threat_lead_counts_ahead_only_from_one_point_and_prints_level_seeds() -> void:
	var rows := _grid(0.50, 10.0)
	var seeds := SweepMath.set_seeds(SweepMath.HOLDOUT_SET_1)
	_put(rows, "threat", seeds[0], {"mean_frac": 0.509})  # lead 0.9: level
	_put(rows, "threat", seeds[1], {"mean_frac": 0.51})   # lead 1.0: ahead
	_put(rows, "threat", seeds[2], {"mean_frac": 0.491})  # lead -0.9: level
	_put(rows, "threat", seeds[3], {"mean_frac": 0.49})   # lead -1.0: behind
	var res := SweepMath.threat_lead(rows, true)
	var head := String(res.lines[0])
	assert_string_contains(head, "ahead (>= 1.0) on 5 of 8")
	assert_string_contains(head, "level (within +-1.0) on 2")
	assert_string_contains(head, "own best pair")
	assert_eq(SweepMath.AHEAD_MARGIN, 1.0)
	# the final rule counts the margin: 5 of 8 ahead fails even though 6 have a positive lead
	assert_false(res.ok)

