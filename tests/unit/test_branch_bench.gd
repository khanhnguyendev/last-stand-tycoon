extends GutTest
## E6 Task 8/9 (D-288, D-292.2, D-294.6, D-294.7): the FAST subset of the lane-type bench, in the unit suite.
## THIS IS A SHORTER NIGHT THAN THE FULL BENCH, kept as an early warning: pressure 12, all three lane types, the LAST wave of each
## mix only (one wave instead of three), the five single-change configurations per lane type (15 runs): unbranched, Longbow, Volley (with an
## unbranched fence) and Stone, Spike (with an unbranched tower). The full three-wave bench (tie-breakers, pairs, the cap, the pins of the old table,
## the tables) is tests/bench/test_branch_bench_full.gd, the CI `bench` job. The rules live in tests/support/branch_bench.gd and are the same
## code the full bench runs; only the length of the night differs. The results are cached per process (BranchBench.fast_results()) and the
## identity test (test_branch_identity.gd) reuses them.
##
## RULES (E8, spec 3.1, replacing E6's FLOOR): ON, OFF and NEUTRAL per branch (BranchBench.RULES), at the last wave of pressure 12.
## SPECIALIST: on its own lane type the specialist beats the other branch by 15% on the first measure of its order that separates them:
##   Longbow over Volley (siege, diner HP lost), Volley over Longbow and Spike over Stone (hare, diner HP lost, then hares in the zone,
##   then time to clear) and, D-294.6, Stone over Spike on siege by how long the fence STANDS (fence_fell_s, higher is better, a fence that
##   never falls counts as INF = standing for the whole run; Stone >= 1.15 x Spike), diner HP lost breaking a tie.
## The rule table (rule, the two numbers, the bound, PASS/FAIL) is printed once at the end of the file.

var _rows: Array = []
var _t0 := 0
var _wall := 0.0

func before_all() -> void:
	_t0 = Time.get_ticks_msec()
	await BranchBench.fast_results()
	_wall = (Time.get_ticks_msec() - _t0) / 1000.0
	var f := BranchBench.fast_cached()
	for lane in f:
		for name in f[lane]:
			var r: Dictionary = f[lane][name]
			gut.p("  FAST %-8s %-10s diner lost %8.1f  fence left %6.1f  stands %7.2f s  hares %2d  clear %6.2f s (%d ticks%s)" % [lane, name, r.diner_lost, r.fence_hp_left, r.fence_stands_s, r.hares_in_zone, r.clear_s, r.ticks, ", TIMED OUT" if r.timed_out else ""])

func after_all() -> void:
	Balance.reset()
	gut.p("FAST SUBSET (last wave only, 15 runs, plus 2 whole-night siege runs for FULL_NIGHT_RULES = 17) wall time of the runs %.1f s (0 when another file computed them first)" % _wall)
	gut.p("FAST RULE TABLE: rule | the two numbers | bound | verdict")
	for r in _rows:
		gut.p("  %-52s %14s vs %-14s %-18s %s" % [r[0], r[1], r[2], r[3], "PASS" if r[4] else "FAIL"])

func _res(lane: StringName, name: String) -> Dictionary:
	var r: Dictionary = BranchBench.fast_cached()[lane][name]
	assert_false(r.timed_out, "%s %s did not clear before MAX_TICKS (timed out)" % [lane, name])
	return r

func _row(rule: String, a: String, b: String, bound: String, ok: bool) -> void:
	_rows.append([rule, a, b, bound, ok])

func test_rules_on_off_and_neutral() -> void:
	var f := BranchBench.fast_cached()
	for row in BranchBench.RULES:
		var lane_res: Dictionary = f["siege_full"] if BranchBench.rule_name(row) in BranchBench.FULL_NIGHT_RULES else f[row[2]]
		var v := BranchBench.rule_verdict(row, lane_res)
		for lane in f:
			for name in f[lane]:
				assert_false(f[lane][name].timed_out, "%s %s did not clear" % [lane, name])
		var whole := " (whole night)" if BranchBench.rule_name(row) in BranchBench.FULL_NIGHT_RULES else ""
		_row("%s p%d %s %s%s" % [row[0], BranchBench.PRESSURE, row[1], row[2], whole], "%s %.2f" % [v.measure, v.a], "%.2f" % v.b, "%s %.2f" % [BranchBench.rule_op(row), v.bound], v.ok)
		assert_true(v.ok, "%s %s on the %s lane: %s | fails when: %s" % [row[0], row[1], row[2], v.why, BranchBench.RULE_FAILS_WHEN[BranchBench.rule_name(row)]])

func test_specialist_margin_on_its_own_lane_type() -> void:
	for row in BranchBench.SPECIALISTS:
		var spec := _res(row[0], BranchBench.cfg_name(row[1]))
		var ref := _res(row[0], BranchBench.cfg_name(row[2]))
		var v := BranchBench.specialist_verdict(row, spec, ref)
		_row("SPECIALIST %s: %s" % [row[0], row[3]], "%s %.2f" % [v.measure, v.a], "%.2f" % v.b, "%s %.2f" % ["<=" if v.measure != "fence_stands_s" and v.measure != "fence_hp_left" else ">=", v.bound], v.ok)
		assert_true(v.ok, "SPECIALIST %s lane, %s by 15%%: %s | fails when: %s" % [row[0], row[3], v.why, row[5]])
