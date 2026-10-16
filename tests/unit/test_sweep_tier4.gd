extends GutTest
## E8 phase 2 Task 10 (spec 4.5, 4.6, plan B16): tier-4 nights are counted apart from tier-3 nights; the tier-4 targets; BOSS_NIGHT; the set-5 tier-3 check gate; the capped-run tag.

const LANES4 := ["east", "sw", "west", "north"]
const PAIRS := ["all_a", "all_b", "mixed", "volley_stone"]
const DATE := "2026-10-16T10:00:00+02:00"

func before_each() -> void:
	Balance.reset()

# ---- night rows -----------------------------------------------------------------------------------------------------------------------------

func _night(tier: int, retries: int, frac: float, extra := {}) -> Dictionary:
	var n := {"day": 10, "tier": tier, "tier_close": tier, "retries": retries, "frac": frac, "first_frac": frac, "failed": false, "boss_night": false, "at_cap3": false, "at_cap4": false,
		"fences_lost": 0, "branches": 0, "branch_gold": 0, "guard_hits": 0, "hare_share": -1.0}
	n.merge(extra, true)
	return n

## Mutation: counting tier-4 nights in the tier-3 statistics (the old `>= 3` reading).
func test_the_tier_3_statistics_count_tier_3_nights_only() -> void:
	var nights := [_night(3, 0, 0.6), _night(3, 1, 0.4), _night(4, 2, 0.1, {"fences_lost": 5}), _night(4, 0, 0.9)]
	var s := SweepMath.tier3_stats(nights)
	assert_eq(s.nights, 2)
	assert_eq(s.retry_nights, 1, "the tier-4 night's retries are not tier-3 retries")
	assert_almost_eq(s.min, 0.4, 1e-9)
	assert_almost_eq(s.mean, 0.5, 1e-9)
	assert_almost_eq(s.fences_lost_mean, 0.0, 1e-9)
	var held := SweepMath.tier3_held_stats(nights.map(func(n): return n.merged({"at_cap3": false})))
	assert_eq(held.nights, 2)
	assert_eq(held.retries, 1)
	var us := SweepMath.unspent_split([{"day": 1, "tier": 3, "unspent": 100, "done": false}, {"day": 2, "tier": 4, "unspent": 900, "done": false}])
	assert_eq(us.before, [100], "a tier-4 day is not a tier-3 day")
	var ls := SweepMath.ladder_summary(3, [{"day": 1, "tier": 3, "at_cap3": false, "income": 0, "rebuild": 0, "rebranch": 0, "unspent": 100, "done": false}, {"day": 2, "tier": 4, "at_cap3": false, "income": 0, "rebuild": 0, "rebranch": 0, "unspent": 900, "done": false}])
	assert_eq(ls.max_unspent_during_ladder, 100)

## The row of the Wrecker night closes at tier 4: its purchases are tier-4 facts. Mutation: `>= 3` on tier_close.
func test_the_wrecker_nights_day_purchases_are_not_tier_3_branches() -> void:
	var s := SweepMath.tier3_stats([_night(3, 0, 0.5, {"tier_close": 3, "branches": 2, "branch_gold": 300}), _night(3, 0, 0.5, {"tier_close": 4, "branches": 4, "branch_gold": 900, "boss_night": true})])
	assert_eq(s.branches, 2)
	assert_eq(s.branch_gold, 300)

## B16. Mutation: counting the boss night's retries in RETRY_NIGHTS' inputs.
func test_the_tier_3_boss_nights_retries_are_left_out_of_the_retry_counts() -> void:
	var nights := [_night(3, 0, 0.6), _night(3, 2, 0.4, {"boss_night": true, "day": 20, "at_cap3": true}), _night(3, 1, 0.5, {"day": 22, "at_cap3": true})]
	var s := SweepMath.tier3_stats(nights)
	assert_eq(s.nights, 3, "the boss night is still a tier-3 night")
	assert_eq(s.retry_nights, 1, "only the ordinary night counts")
	var held := SweepMath.tier3_held_stats(nights)
	assert_eq(held.retries, 1)
	assert_eq(held.retry_nights, 1)
	assert_eq(held.cap_retry_nights, 1)
	var rt := SweepMath.retune_run_stats(nights)
	assert_eq(rt.max_retries, 1)
	assert_eq(rt.max_retries_day, 22)

## LANE_CAP_GUARD reads all nights; every other RETUNE number reads tier 3 only.
func test_guard_hits_count_every_night_from_tier_3_on_the_other_figures_only_tier_3() -> void:
	var nights := [_night(2, 0, 0.5, {"guard_hits": 7}), _night(3, 0, 0.5, {"guard_hits": 1, "hare_share": 0.8}), _night(4, 1, 0.2, {"guard_hits": 2, "hare_share": 0.1})]
	var rt := SweepMath.retune_run_stats(nights)
	assert_eq(rt.guard_hits, 3, "tier 3 and tier 4, not tier 2")
	assert_eq(rt.t3_nights, 1)
	assert_almost_eq(rt.hare_share_mean, 0.8, 1e-9)
	assert_eq(rt.max_retries, 0)
	assert_almost_eq(rt.first_t3_frac, 0.5, 1e-9)

# ---- tier4_stats ------------------------------------------------------------------------------------------------------------------------------

func test_tier4_stats_empty_set_is_all_zero_and_unseen() -> void:
	var t := SweepMath.tier4_stats([_night(2, 0, 0.5), _night(3, 0, 0.5)])
	assert_eq(t.nights, 0)
	assert_eq(t.first_t4_frac, -1.0)
	assert_false(t.boss_seen)
	assert_eq(t.fence_median, 0)

func test_tier4_stats_reads_tier_4_nights_the_first_night_and_the_worst_first_attempt() -> void:
	var nights := [_night(3, 0, 0.7), _night(4, 2, 0.6, {"first_frac": 0.0, "day": 31, "fences_lost": 2}), _night(4, 0, 0.9, {"day": 32, "at_cap4": true, "fences_lost": 0}), _night(4, 0, 0.3, {"day": 33, "at_cap4": true, "failed": false})]
	var t := SweepMath.tier4_stats(nights)
	assert_eq(t.nights, 3)
	assert_eq(t.retry_nights, 1)
	assert_eq(t.retries, 2)
	assert_almost_eq(t.first_t4_frac, 0.6, 1e-9, "the first tier-4 night, its mercy attempt")
	assert_eq(t.first_t4_retries, 2)
	assert_almost_eq(t.mean, 0.6, 1e-9)
	assert_almost_eq(t.min, 0.3, 1e-9)
	assert_almost_eq(t.median, 0.6, 1e-9)
	assert_almost_eq(t.fences_lost_mean, 2.0 / 3.0, 1e-9)
	assert_eq(t.cap_nights, 2)
	assert_almost_eq(t.worst_night_frac, 0.0, 1e-9, "the lowest FIRST attempt")
	assert_eq(t.worst_night_day, 31)

func test_tier4_stats_boss_night_is_the_tier_3_boss_night_only() -> void:
	var baron := _night(2, 3, 0.5, {"boss_night": true, "tier_close": 3})
	var wrecker := _night(3, 2, 0.5, {"boss_night": true, "tier_close": 4})
	var t := SweepMath.tier4_stats([baron, wrecker, _night(4, 0, 0.5)])
	assert_true(t.boss_seen)
	assert_eq(t.boss_retries, 2, "the Baron night (it started at tier 2) is not the tier-3 boss night")
	assert_false(t.boss_failed)
	assert_eq(t.nights, 1, "the Wrecker night is not a tier-4 night")
	var lost := SweepMath.tier4_stats([_night(3, 4, 0.0, {"boss_night": true, "failed": true})])
	assert_true(lost.boss_failed)
	assert_eq(lost.nights, 0)
	assert_false(SweepMath.tier4_stats([baron]).boss_seen)

func test_tier4_stats_fence_and_income_are_the_medians_over_the_tier_4_cap_rows() -> void:
	var days := [{"at_cap4": true, "rebuild": 10, "rebranch": 5, "income": 100}, {"at_cap4": true, "rebuild": 30, "rebranch": 10, "income": 200}, {"at_cap4": false, "rebuild": 999, "rebranch": 0, "income": 9999},
		{"at_cap4": true, "rebuild": 0, "rebranch": 0, "income": 300}]
	var t := SweepMath.tier4_stats([_night(4, 0, 0.5)], days)
	assert_eq(t.fence_median, 15, "median of 15, 40, 0")
	assert_eq(t.income_at_cap, 200)

# ---- run rows and the target functions ----------------------------------------------------------------------------------------------------------

func test_run_row_reads_the_t4run_line_and_defaults_to_no_tier_4_night() -> void:
	var kv := {"mean": "0.5", "retry_nights": "0"}
	var plain := SweepMath.run_row(1, "east", "threat", kv, {"ladder_done_day": "3"}, {})
	assert_eq(plain.first_t4_frac, -1.0)
	assert_false(plain.boss_seen)
	var t4 := {"nights": "7", "retry_nights": "1", "mean": "0.62", "first_t4_frac": "0.55", "first_t4_retries": "0", "boss_seen": "1", "boss_retries": "2", "boss_failed": "0",
		"fence_rebuild_gold_median_at_cap": "40", "income_at_cap": "400", "worst_night_frac": "0.3", "worst_night_day": "33"}
	var row := SweepMath.run_row(1, "east", "threat", kv, {"ladder_done_day": "3"}, {}, t4)
	assert_eq(row.t4_nights, 7)
	assert_eq(row.t4_retry_nights, 1)
	assert_almost_eq(row.t4_mean, 0.62, 1e-9)
	assert_almost_eq(row.first_t4_frac, 0.55, 1e-9)
	assert_true(row.boss_seen)
	assert_eq(row.boss_retries, 2)
	assert_false(row.boss_failed)
	assert_eq(row.t4_fence_median, 40)
	assert_eq(row.t4_income_at_cap, 400)

func _row(seed: int, lane: String, policy: String, frac: float, extra := {}) -> Dictionary:
	var r := {"seed": seed, "lane": lane, "policy": policy, "mean_frac": 0.5, "retry_nights": 0, "first_t3_frac": 0.5, "fence_median": 10, "income_at_cap": 100, "hare_share": 0.7, "hare_share_min": 0.7,
		"guard_hits": 0, "max_retries": 0, "max_retries_day": -1, "unspent_before": [], "unspent_after": [], "unspent_last": 0, "ladder_done": false, "first_t3_retries": 0, "worst_night_frac": 0.5, "worst_night_day": 20,
		"t4_nights": 5, "t4_retry_nights": 0, "t4_mean": frac, "first_t4_frac": 0.6, "first_t4_retries": 0, "t4_fence_median": 10, "t4_income_at_cap": 100, "boss_seen": true, "boss_retries": 0, "boss_failed": false}
	r.merge(extra, true)
	return r

## 8 seeds x 6 policies: the fixed pairs sit at `fixed`, threat at fixed + lead/100, unbranched at 0.40 (tier-4 mean fractions).
func _grid(fixed := 0.50, lead := 10.0) -> Array:
	var rows: Array = []
	for s in SweepMath.set_seeds(SweepMath.MEASURE_SET_6):
		var lane := SweepMath.seed_lane(SweepMath.MEASURE_SET_6, s)
		for p in PAIRS:
			rows.append(_row(s, lane, p, fixed))
		rows.append(_row(s, lane, "threat", fixed + lead / 100.0))
		rows.append(_row(s, lane, "unbranched", 0.40))
	return rows

func _expected(rows: Array) -> Array:
	return rows.map(func(r): return [r.seed, r.policy])

func _put(rows: Array, policy: String, seed: int, extra: Dictionary) -> void:
	for r in rows:
		if r.policy == policy and r.seed == seed:
			r.merge(extra, true)

func _line(res: Dictionary, prefix: String) -> String:
	for l in res.lines:
		if String(l).begins_with(prefix):
			return l
	return ""

## Mutation: the tier-3 mean_frac read instead of the tier-4 one (the grid's tier-3 numbers are all 0.5: no lead).
func test_threat_lead_t4_reads_the_tier_4_nights_and_passes_at_exactly_5_points() -> void:
	var res := SweepMath.threat_lead_t4(_grid(0.50, 5.0), true)
	assert_true(res.ok, "5.0 exactly passes")
	assert_ne(_line(res, "THREAT_LEAD_T4: PASS"), "")
	assert_false(SweepMath.threat_lead_t4(_grid(0.50, 4.9), true).ok)
	assert_ne(_line(SweepMath.threat_lead_t4(_grid(0.50, 4.9), true), "THREAT_LEAD_T4: FAIL"), "")
	assert_false(SweepMath.threat_lead(_grid(0.50, 5.0), true).ok, "the tier-3 target on the same rows reads the tier-3 numbers: no lead")

func test_threat_lead_t4_final_needs_six_of_eight_seeds_ahead() -> void:
	var rows := _grid(0.50, 10.0)
	var seeds := SweepMath.set_seeds(SweepMath.MEASURE_SET_6)
	for i in 3:  # three seeds level: threat ahead on 5 of 8 only, but the mean lead stays above 5
		_put(rows, "threat", seeds[i], {"t4_mean": 0.50})
	var res := SweepMath.threat_lead_t4(rows, true)
	assert_false(res.ok, "ahead on 5 of 8")
	assert_true(SweepMath.threat_lead_t4(rows, false).ok, "the tuning reading is the mean alone")
	_put(rows, "threat", seeds[2], {"t4_mean": 0.60})
	assert_true(SweepMath.threat_lead_t4(rows, true).ok, "ahead on 6 of 8")

func test_threat_lead_by_lane_t4_fails_on_a_negative_lane() -> void:
	assert_true(SweepMath.threat_lead_by_lane_t4(_grid()).ok)
	var rows := _grid()
	for r in rows:
		if r.lane == "west" and r.policy == "threat":
			r.t4_mean = 0.30
	var res := SweepMath.threat_lead_by_lane_t4(rows)
	assert_false(res.ok)
	assert_ne(_line(res, "THREAT_LEAD_BY_LANE_T4: FAIL"), "")

func test_retry_nights_t4_is_zero_for_branch_policies_and_unbranched_is_a_reference() -> void:
	assert_true(SweepMath.retry_nights_t4(_grid()).ok)
	var rows := _grid()
	_put(rows, "unbranched", rows[0].seed, {"t4_retry_nights": 3})
	assert_true(SweepMath.retry_nights_t4(rows).ok)
	_put(rows, "mixed", rows[0].seed, {"t4_retry_nights": 1})
	var res := SweepMath.retry_nights_t4(rows)
	assert_false(res.ok)
	assert_string_contains(res.lines[0], "mixed 1")
	assert_ne(_line(res, "RETRY_NIGHTS_T4: FAIL"), "")

## Tier-3 retry nights of a branch policy never fail the tier-4 target (they are read in the tier-3 block).
func test_retry_nights_t4_does_not_read_the_tier_3_retry_nights() -> void:
	var rows := _grid()
	_put(rows, "threat", rows[0].seed, {"retry_nights": 4})
	assert_true(SweepMath.retry_nights_t4(rows).ok)
	assert_false(SweepMath.retry_nights(rows).ok)

func test_first_t4_night_passes_at_exactly_25_percent_and_covers_unbranched() -> void:
	var rows := _grid()
	_put(rows, "unbranched", rows[0].seed, {"first_t4_frac": 0.25})
	var res := SweepMath.first_t4_night(rows)
	assert_true(res.ok, "exactly 25 passes")
	assert_ne(_line(res, "FIRST_T4_NIGHT: PASS"), "")
	_put(rows, "unbranched", rows[0].seed, {"first_t4_frac": 0.249})
	assert_false(SweepMath.first_t4_night(rows).ok, "unbranched is included")

func test_first_t4_night_that_needed_a_retry_counts_as_lost_whatever_the_mercy_result() -> void:
	var rows := _grid()
	_put(rows, "threat", rows[0].seed, {"first_t4_retries": 1, "first_t4_frac": 0.95})
	var res := SweepMath.first_t4_night(rows)
	assert_false(res.ok)
	assert_string_contains("\n".join(res.lines), "retried first night")
	assert_string_contains(res.lines[0], "0.0%")

func _band_rows(fracs: Array) -> Array:
	var rows: Array = []
	var i := 0
	for p in SweepMath.BRANCH_POLICIES:
		for sd in SweepMath.set_seeds(SweepMath.MEASURE_SET_6):
			rows.append(_row(sd, SweepMath.seed_lane(SweepMath.MEASURE_SET_6, sd), p, 0.5, {"first_t4_frac": fracs[i % fracs.size()]}))
			i += 1
	return rows

func test_first_night_band_t4_is_inclusive_at_50_and_80_and_fails_outside() -> void:
	assert_true(SweepMath.first_night_band_t4(_band_rows([0.50])).ok)
	assert_true(SweepMath.first_night_band_t4(_band_rows([0.80])).ok)
	assert_false(SweepMath.first_night_band_t4(_band_rows([0.49])).ok)
	assert_false(SweepMath.first_night_band_t4(_band_rows([0.81])).ok)
	assert_ne(_line(SweepMath.first_night_band_t4(_band_rows([0.60])), "FIRST_NIGHT_BAND_T4: PASS"), "")

func test_first_night_band_t4_counts_a_retried_first_night_as_zero_and_leaves_unbranched_out() -> void:
	var rows := _band_rows([0.70])
	var k := 0
	for r in rows:
		if k < 21:  # 21 of 40 retried: the pooled median is 0
			r.first_t4_retries = 1
			r.first_t4_frac = 0.99
		k += 1
	var res := SweepMath.first_night_band_t4(rows)
	assert_almost_eq(float(res.median), 0.0, 1e-9)
	assert_false(res.ok)
	var with_ref := _band_rows([0.60])
	with_ref.append(_row(9, "east", "unbranched", 0.5, {"first_t4_frac": 0.0}))
	assert_true(SweepMath.first_night_band_t4(with_ref).ok, "the reference policy is not pooled")

func test_fence_tax_t4_is_30_percent_of_the_tier_4_income() -> void:
	var rows := _grid()
	for r in rows:
		r.t4_fence_median = 30
		r.t4_income_at_cap = 100
	assert_true(SweepMath.fence_tax_t4(rows).ok, "exactly 30 passes")
	for r in rows:
		r.t4_fence_median = 31
	var res := SweepMath.fence_tax_t4(rows)
	assert_false(res.ok)
	assert_ne(_line(res, "FENCE_TAX_T4: FAIL"), "")
	for r in rows:
		r.t4_income_at_cap = 0
	assert_false(SweepMath.fence_tax_t4(rows).ok, "no cap day is N/A, not a pass")

# ---- BOSS_NIGHT ---------------------------------------------------------------------------------------------------------------------------------

func test_boss_night_constant_equals_the_balance_value() -> void:
	assert_eq(SweepMath.BOSS_NIGHT_MAX_RETRIES, Balance.data.sim.boss_night_max_retries)

func test_boss_night_passes_within_the_allowed_retries_and_fails_past_them() -> void:
	var rows := _grid()
	for r in rows:
		r.boss_retries = 2
	assert_true(SweepMath.boss_night(rows).ok, "exactly the allowed retries")
	_put(rows, "all_b", rows[0].seed, {"boss_retries": 3})
	var res := SweepMath.boss_night(rows)
	assert_false(res.ok)
	assert_string_contains("\n".join(res.lines), "won late")
	assert_ne(_line(res, "BOSS_NIGHT: FAIL"), "")

func test_boss_night_fails_a_lost_or_never_met_boss_and_ignores_the_unbranched_reference() -> void:
	var rows := _grid()
	_put(rows, "unbranched", rows[0].seed, {"boss_retries": 4, "boss_failed": true})
	assert_true(SweepMath.boss_night(rows).ok, "unbranched is a reference")
	assert_string_contains(SweepMath.boss_night(rows).lines[0], "unbranched 4 (reference)")
	_put(rows, "threat", rows[0].seed, {"boss_failed": true, "boss_retries": 4})
	assert_string_contains("\n".join(SweepMath.boss_night(rows).lines), "lost")
	assert_false(SweepMath.boss_night(rows).ok)
	var unseen := _grid()
	_put(unseen, "mixed", unseen[0].seed, {"boss_seen": false})
	assert_false(SweepMath.boss_night(unseen).ok)
	assert_string_contains("\n".join(SweepMath.boss_night(unseen).lines), "never met")

# ---- the tier-4 report block ---------------------------------------------------------------------------------------------------------------------

func test_retune_report_t4_prints_every_tier_4_verdict_and_exits_0() -> void:
	var rows := _grid()
	var res := SweepMath.retune_report_t4(rows, _expected(rows), true)
	assert_eq(res.exit, 0)
	for key in ["THREAT_LEAD_T4:", "THREAT_LEAD_BY_LANE_T4:", "RETRY_NIGHTS_T4:", "FIRST_T4_NIGHT:", "FIRST_NIGHT_BAND_T4:", "FENCE_TAX_T4:", "BOSS_NIGHT:", "LANE_CAP_GUARD:"]:
		assert_ne(_line(res, key), "", key)
	assert_true(res.ok, "the grid passes: %s" % [res.failed])
	var bad := _grid()
	_put(bad, "threat", bad[0].seed, {"boss_failed": true})
	var r2 := SweepMath.retune_report_t4(bad, _expected(bad), true)
	assert_eq(r2.failed, ["BOSS_NIGHT"])
	assert_false(r2.ok)

func test_retune_report_t4_a_run_without_a_tier_4_night_gives_no_verdicts_and_exit_1() -> void:
	var rows := _grid()
	rows[4].first_t4_frac = -1.0
	var res := SweepMath.retune_report_t4(rows, _expected(rows))
	assert_eq(res.exit, 1)
	assert_string_contains(res.lines[0], "TIER4 FAILED")
	assert_eq(_line(res, "THREAT_LEAD_T4"), "")
	var missing := _grid()
	var exp := _expected(missing)
	missing.remove_at(7)
	assert_eq(SweepMath.retune_report_t4(missing, exp).exit, 1)
	var broke := _grid()
	broke[3].failed = true
	assert_eq(SweepMath.retune_report_t4(broke, _expected(broke)).exit, 1)

## The tier-3 block is untouched by the tier-4 fields: the same rows give the same tier-3 report with or without them.
func test_the_tier_3_report_ignores_the_tier_4_fields() -> void:
	var with := _grid()
	var without := _grid()
	for r in without:
		for k in ["t4_nights", "t4_retry_nights", "t4_mean", "first_t4_frac", "first_t4_retries", "t4_fence_median", "t4_income_at_cap", "boss_seen", "boss_retries", "boss_failed"]:
			r.erase(k)
	assert_eq(SweepMath.retune_report(with, _expected(with), true).lines, SweepMath.retune_report(without, _expected(without), true).lines)

# ---- the set-5 tier-3 check (D-314.12) and the capped tag ------------------------------------------------------------------------------------------

func test_set_5_may_be_re_run_without_final_only_capped_at_tier_3_and_at_32_days() -> void:
	var rec := {"history": [{"set": "5", "commit": "abc1234", "date": DATE, "days": 32, "bot_rule": "walk", "done": true, "ok": true}]}
	var g := SweepMath.final_gate("5", false, "abc1234-dirty", rec, DATE, 32, "walk", 3)
	assert_true(g.allowed, "no --final, a dirty tree: a plain report run")
	assert_string_contains(g.lines[0], "TIER3_CHECK")
	assert_string_contains(g.lines[0], "NOT written")
	assert_eq(g.record, rec, "the history is untouched")
	assert_false(SweepMath.final_gate("5", false, "abc1234", rec, DATE, 32, "walk", 0).allowed, "uncapped: still needs --final")
	assert_false(SweepMath.final_gate("5", false, "abc1234", rec, DATE, 32, "walk", 4).allowed, "capped at 4 is not the check")
	assert_false(SweepMath.final_gate("5", false, "abc1234", rec, DATE, 45, "walk", 3).allowed, "32 days only")
	for id in ["3", "4", "6"]:
		assert_false(SweepMath.final_gate(id, false, "abc1234", rec, DATE, SweepMath.final_days(id), "walk", 3).allowed, "set #%s has no such allowance" % id)
	assert_false(SweepMath.final_gate("tuning", true, "abc1234", rec, DATE, 32, "walk", 3).allowed)

## With --final the capped run goes through the normal rules: a spent set stays refused, and a fresh entry says it was capped.
func test_a_final_run_keeps_the_normal_rules_and_records_the_cap() -> void:
	var done := {"history": [{"set": "5", "commit": "abc1234", "date": DATE, "days": 32, "bot_rule": "walk", "done": true, "ok": true}]}
	assert_false(SweepMath.final_gate("5", true, "def5678", done, DATE, 32, "walk", 3).allowed, "set #5 already ran with the walk rule")
	var g := SweepMath.final_gate("6", true, "def5678", {"history": []}, DATE, 45, "walk", 3)
	assert_true(g.allowed)
	assert_eq(g.record.history[0].bot_max_tier, 3)
	var plain := SweepMath.final_gate("6", true, "def5678", {"history": []}, DATE, 45, "walk")
	assert_false(plain.record.history[0].has("bot_max_tier"), "an uncapped entry is what it always was")

func test_the_run_tag_carries_the_bot_max_tier() -> void:
	assert_eq(SweepMath.run_tag("5", "walk"), "5_walk")
	assert_eq(SweepMath.run_tag("5", "walk", 0), "5_walk")
	assert_eq(SweepMath.run_tag("5", "walk", 3), "5_walk_mt3")
	assert_ne(SweepMath.run_tag("5", "walk", 3), SweepMath.run_tag("5", "walk"), "a capped run never overwrites an uncapped one's logs")
