extends GutTest
## E6 (D-304, D-305), E8 (spec 3.1) REPORT, not a CI test: the three rule sets of the full lane-type bench (the E8 RULES: ON, OFF, NEUTRAL;
## SPECIALIST; IDENTITY; tests/bench/test_branch_bench_full.gd) at EVERY pressure from tier_base[3] to tier_cap[3] (read from the balance; CI runs the
## base and the cap, the middle pressures live here), the shipped balance, with the cap as the control (it must reproduce the verdicts of the CI bench). Every rule is printed with its measured numbers and PASS or FAIL. It asserts
## nothing about the verdicts: a FAIL is a finding for the report, not something to tune. Run it by hand:
##   "$GODOT" --headless --path . --fixed-fps 60 -s res://addons/gut/gut_cmdln.gd -gconfig= -gtest=res://tests/bench_report/test_branch_bench_pressures.gd -gexit
## The rule logic is the bench's own: every verdict comes from the shared functions of tests/support/branch_bench.gd
## (RULES, rule_verdict, specialist_verdict, identity_*, SPECIALISTS, SAME); only the loops that print the rows live here, because the
## bench's loops are tied to its asserts and its CI row table.

## From the balance, never literals: tier_base[3] .. tier_cap[3].
static func _pressures() -> Array[int]:
	var out: Array[int] = []
	for p in range(int(Balance.data.tiers.tier_base[3]), int(Balance.data.tiers.tier_cap[3]) + 1):
		out.append(p)
	return out

const SAME := BranchBench.SAME

var _cache := {}
var _t0 := 0
var _fails := {}
var _rules := {}

func before_all() -> void:
	_t0 = Time.get_ticks_msec()

func after_all() -> void:
	gut.p("BENCH PRESSURES WALL TIME %.1f s, %d bench runs" % [(Time.get_ticks_msec() - _t0) / 1000.0, _cache.size()])

func before_each() -> void:
	Balance.reset()

func after_each() -> void:
	Balance.reset()

func _run(lane: StringName, tb: StringName, fb: StringName, pressure: int) -> Dictionary:
	var key := "%s|%s|%s|%d" % [lane, tb, fb, pressure]
	if not _cache.has(key):
		_cache[key] = await BranchBench.run(lane, tb, fb, pressure)
	return _cache[key]

func _fmt(r: Dictionary) -> String:
	return "lost %8.1f  fence %6.1f  stands %7.2f s  hares %2d  clear %7.2f s  timed_out %s" % [r.diner_lost, r.fence_hp_left, r.fence_stands_s, r.hares_in_zone, r.clear_s, str(r.timed_out)]

func _row(pressure: int, rule: String, numbers: String, ok: bool) -> void:
	_rules[pressure] = int(_rules.get(pressure, 0)) + 1
	if not ok:
		_fails[pressure] = int(_fails.get(pressure, 0)) + 1
	gut.p("  p%d %-62s %s  %s" % [pressure, rule, numbers, "PASS" if ok else "FAIL"])

## The CI bench asserts every run clears in time (test_branch_bench_full.gd): a timed-out run is a FAIL row here too (only a timed-out run prints a row).
func _timeout_row(pressure: int, lane: StringName, cfg_name: String, r: Dictionary) -> void:
	if r.timed_out:
		_row(pressure, "TIMEOUT %s %s did not clear in time" % [lane, cfg_name], "clear %.2f s" % r.clear_s, false)

func _rules_at(pressure: int) -> void:
	var res := {}
	for lane in BranchBench.LANES:
		res[lane] = {}
		for cfg in BranchBench.FAST_CONFIGS:
			res[lane][BranchBench.cfg_name(cfg)] = await _run(lane, cfg[0], cfg[1], pressure)
	for row in BranchBench.RULES:
		var v := BranchBench.rule_verdict(row, res[row[2]])
		_row(pressure, "%s %s" % [BranchBench.rule_name(row), row[2]], "%s %.2f vs %.2f, bound %s %.2f" % [v.measure, v.a, v.b, BranchBench.rule_op(row), v.bound], v.ok)

func _specialists(pressure: int) -> void:
	for row in BranchBench.SPECIALISTS:
		var spec: Dictionary = await _run(row[0], row[1][0], row[1][1], pressure)
		var ref: Dictionary = await _run(row[0], row[2][0], row[2][1], pressure)
		var v := BranchBench.specialist_verdict(row, spec, ref)
		var upper: bool = v.measure == "fence_stands_s" or v.measure == "fence_hp_left"
		_row(pressure, "SPECIALIST %s: %s" % [row[0], row[3]], "%s %.2f vs %.2f, bound %s %.2f" % [v.measure, v.a, v.b, ">=" if upper else "<=", v.bound], v.ok)

func _identity(pressure: int) -> void:
	var siege := {}
	var hare := {}
	for cfg in BranchBench.FAST_CONFIGS:
		siege[BranchBench.cfg_name(cfg)] = await _run(&"siege", cfg[0], cfg[1], pressure)
		hare[BranchBench.cfg_name(cfg)] = await _run(&"hare", cfg[0], cfg[1], pressure)
	for r in [["siege: Longbow best tower state", BranchBench.identity_longbow_siege(siege)], ["hare: Volley best tower state", BranchBench.identity_volley_hare(hare)],
			["siege: Stone's fence stands longest", BranchBench.identity_stone_stands_longest(siege)], ["hare: Spike fewest hares in the zone", BranchBench.identity_spike_fewest_hares(hare)]]:
		_row(pressure, "IDENTITY " + r[0], r[1].why, r[1].ok)
	for lane in [&"siege", &"hare"]:  # E8: the neutral lane is NEUTRAL's job
		var base: Dictionary = await _run(lane, &"", &"", pressure)
		var towers := minf((await _run(lane, &"longbow", &"", pressure)).diner_lost, (await _run(lane, &"volley", &"", pressure)).diner_lost)
		var fences := minf((await _run(lane, &"", &"stone", pressure)).diner_lost, (await _run(lane, &"", &"spike", pressure)).diner_lost)
		_row(pressure, "IDENTITY %s: unbranched tower never best" % lane, "best branch %.1f vs base %.1f" % [towers, base.diner_lost], towers < base.diner_lost - SAME)
		_row(pressure, "IDENTITY %s: unbranched fence never best" % lane, "best branch %.1f vs base %.1f" % [fences, base.diner_lost], fences < base.diner_lost - SAME)

## E8 phase 2 Task 8 (spec 4.5): the tier-4 base (tier_base[4]) and the tier-4 cap (tier_cap[4], the control: it must reproduce the CI bench), the RULES on the tier-4 mixes.
func test_rules_at_the_tier_4_base_and_cap() -> void:
	await wait_physics_frames(10)
	for p in [int(Balance.data.tiers.tier_base[4]), int(Balance.data.tiers.tier_cap[4])]:
		gut.p("TIER 4 PRESSURE %d (shipped balance)" % p)
		var res := {}
		for lane in BranchBench.LANES:
			res[lane] = {}
			for cfg in BranchBench.FAST_CONFIGS:
				var run: Dictionary = await BranchBench.run(lane, cfg[0], cfg[1], p, {"tier": 4})
				res[lane][BranchBench.cfg_name(cfg)] = run
				gut.p("  t4 p%d %-8s %-14s %s" % [p, lane, BranchBench.cfg_name(cfg), _fmt(run)])
				if run.timed_out:
					gut.p("  t4 p%d TIMEOUT %s %s did not clear in time  FAIL" % [p, lane, BranchBench.cfg_name(cfg)])
		var fails := 0
		for row in BranchBench.RULES:
			var v := BranchBench.rule_verdict(row, res[row[2]])
			fails += 0 if v.ok else 1
			gut.p("  t4 p%d %-62s %s  %s" % [p, "%s %s" % [BranchBench.rule_name(row), row[2]], "%s %.2f vs %.2f, bound %s %.2f" % [v.measure, v.a, v.b, BranchBench.rule_op(row), v.bound], "PASS" if v.ok else "FAIL"])
		gut.p("SUMMARY t4 p%d: %d rule(s) FAIL, %d PASS, %d rules" % [p, fails, BranchBench.RULES.size() - fails, BranchBench.RULES.size()])
	assert_true(true)

func test_rules_at_every_tier_3_pressure() -> void:
	await wait_physics_frames(10)
	var pressures := _pressures()
	for p in pressures:
		gut.p("PRESSURE %d (shipped balance)%s" % [p, "  [control: must reproduce the CI bench]" if p == pressures[-1] else ""])
		for lane in BranchBench.LANES:
			for cfg in BranchBench.FAST_CONFIGS:
				var run: Dictionary = await _run(lane, cfg[0], cfg[1], p)
				gut.p("  p%d %-8s %-14s %s" % [p, lane, BranchBench.cfg_name(cfg), _fmt(run)])
				_timeout_row(p, lane, BranchBench.cfg_name(cfg), run)
		await _rules_at(p)
		await _specialists(p)
		await _identity(p)
	for p in pressures:
		gut.p("SUMMARY p%d: %d rule(s) FAIL, %d PASS, %d rules" % [p, int(_fails.get(p, 0)), int(_rules.get(p, 0)) - int(_fails.get(p, 0)), int(_rules.get(p, 0))])
	assert_gt(_cache.size(), 0, "the report ran bench runs")
