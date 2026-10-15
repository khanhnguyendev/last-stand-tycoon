extends GutTest
## E8 Task 3 (spec 3.1, D-313.2, D-314.9): REPLACED TESTS (replaced, not dropped). Old test | what replaces it | why.
##  - bench test_3_matrix_flag_on_pressure_12 | test_3_matrix_at_the_cap | the matrix now prints at tier_cap[3] read from the balance (the cap is 12 today), not a literal.
##  - bench test_4_floor_pressure_12 (the FLOOR loop, no_worse) | test_4_rules_on_off_neutral_at_the_tier_base and test_5_rules_on_off_neutral_at_the_tier_cap
##    (BranchBench.RULES: 4 ON, 3 OFF, 4 NEUTRAL) | the FLOOR "paying never makes it worse" no longer holds by design: a specialist now pays on its off lane (OFF), and the
##    neutral lane keeps a one-sided bound (NEUTRAL). CI runs the rules at tier_base[3] and tier_cap[3]; the middle pressures live in tests/bench_report/.
##  - bench test_5_specialist_margin_pressure_12 | test_6_specialists_at_the_cap | same SPECIALISTS rows (their FAILS_WHEN restated), now at the cap read from the balance.
##  - bench test_6_identity_pressure_12 | test_7_identity_at_the_cap | same four identity rules; "unbranched is never best" is restated from every lane type to the siege and hare
##    lanes (the neutral lane is NEUTRAL's job, spec 3.1).
##  - bench test_7_the_rule_at_the_final_cap (skipped while the cap was 12) | folded into tests 3 to 7, which run at the cap | no rule runs only "when the cap differs" any more.
##  - unit test_branch_bench.gd::test_floor_every_branch_loses_no_more_than_the_unbranched_building | test_rules_on_off_and_neutral (last wave, pressure 12; OFF Spike on the whole night, see FULL_NIGHT_RULES) | same reason as the FLOOR.
##  - bench_report test_branch_bench_pressures.gd::test_rules_at_pressures_10_11_12 | test_rules_at_every_tier_3_pressure | FLOOR -> RULES at every pressure from tier_base[3] to tier_cap[3], read from the balance.
##  - bench_report test_branch_sensitivity.gd::_evaluate and test_longbow_p4_r1.gd::_rules (their FLOOR rows) | the RULES rows (BranchBench.RULES / rule_verdicts) | same reason; their "unbranched never best" loops are restated to siege and hare.
##  - unit test_branch_state.gd::test_spike_and_unbranched_take_full_brute_damage | test_spike_takes_four_times_a_brutes_hit_and_unbranched_takes_one_times | Spike's weakness (brute x4.0, D-314.18).
##  - unit test_branch_identity.gd::test_e6_identity_unbranched_is_never_the_best_at_any_named_measure_on_any_lane_type | test_e6_identity_unbranched_is_never_the_best_on_the_siege_and_hare_lanes | spec 3.1.
##  - unit test_branch_identity.gd::test_branch_spec_values | same test, with the three weakness tables asserted | the new stats.
##  - unit test_branch_identity.gd::test_m5_fence_holds_longest_against_one_brute_stone | same test, Spike holds 3 hits (3.0 s) | 8 x 4.0 x 4.0 = 128 per hit, ceil(320 / 128) = 3.
##  - unit test_branch_effects.gd::test_longbow_does_double_to_a_brute_and_exactly_120_to_the_rest | ..._double_to_a_brute_36_to_a_hare_and_exactly_120_to_the_rest | Longbow x0.3 against hares and the Baron.
##  - unit test_branch_effects.gd::test_unbranched_and_volley_do_their_old_damage_to_a_brute | ..._unbranched_does_its_old_damage_to_a_brute_and_volley_three_tenths_of_its_own | Volley x0.3 against brutes (3.0).
##  - unit test_branch_effects.gd::test_longbow_kind_mults_table | same test, tables {brute 2.0, hare 0.3} and Volley {brute 0.3} | the new tables.
## Mutation tables (RULE_FAILS_WHEN, SPECIALISTS[*][5], IDENTITY_FAILS_WHEN in tests/support/branch_bench.gd) were each applied and SEEN red at p12 (Task 3 report).
## E6 Task 8 (spec 4.2 and 4.3, D-283, D-288, D-292): the FULL lane-type bench, its own suite (tests/bench/), with tick budgets like the sims.
## Measures: tests/support/branch_bench.gd (an invulnerable diner: the primary measure is the TOTAL diner HP lost over the whole run).
## It ranks branches relatively; it does not predict a real night (the real-play report does).
##
## (E6 history; the FLOOR below was replaced by the E8 RULES, see the table above.) FLOOR (D-288.1): for every lane type and every branch, compared with the unbranched building of the SAME kind (the other building
## unbranched in both runs): no worse on the primary measure (diner HP lost) and, when tied there (within 0.001), no worse on the lane
## type's first tie-breaker: siege = fence HP left (higher is better), hare = hares reaching the attack zone (fewer), neutral = time to
## clear (shorter).
##
## SPECIALIST (D-288.2, refined by D-294.6): on its own lane type the specialist beats the OTHER branch of the same building (the other
## building unbranched) by at least 15% on the FIRST measure, in the rule's order, on which the two differ (by more than 0.001). Orders (all
## in tests/support/branch_bench.gd, shared with the unit suite's fast subset): siege TOWER = diner HP lost, then fence HP left; siege FENCE
## (Stone over Spike) = how long the fence STANDS (fence_fell_s; a fence that never falls counts as INF, standing for the whole run), then
## diner HP lost; hare = diner HP lost, then hares in the zone, then time to clear.
##   "15% better": lower-is-better measures (diner HP lost, hares in the zone, time to clear): specialist <= 0.85 x reference.
##   Higher-is-better (fence HP left, fence standing time): specialist >= 1.15 x reference (Stone's time >= 1.15 x Spike's).
##   Reference 0: lower-is-better, the two would be equal unless the specialist is worse, so it is never the deciding case and a non-zero
##   specialist fails; higher-is-better, any positive specialist value beats a reference of 0 (1.15 x 0 = 0).
##   If NO measure of the order separates the two, the assertion FAILS (the specialist is not clearly better on its own lane type).
## Own lane types: Longbow over Volley and Stone over Spike on siege; Volley over Longbow and Spike over Stone on hare.
##
## IDENTITY (spec 4.3, restated on these measures, D-294.6): Longbow loses the least diner HP of the three tower states on siege, Volley on hare;
## Stone wall's fence stands longest against the brutes (the longest fence_fell_s of unbranched / Stone / Spike on siege, strictly); Spike lets the fewest hares reach the zone on the hare mix; unbranched is never
## best (some branch of each kind is strictly better on the primary measure) on every lane type.
##
## Since E8: RULES at tier_base[3] and tier_cap[3]; the matrix, SPECIALISTS and IDENTITY at tier_cap[3] (A7). (The old-table rows of the single-branch configurations, the "before" numbers of the
## retune, were pinned as literals until the cleanup, D-307; they went with the off state.)
## The FLOOR keeps diner HP lost as primary on every lane type (D-294.6). The rule table (rule, the two numbers, the bound, PASS) is printed at the end.
## Results are cached per configuration inside this file; the TICKS of a test therefore include the runs it was the first to need.

const LANES: Array[StringName] = BranchBench.LANES
## The nine configurations of the matrix: [tower branch, fence branch].
const CONFIGS: Array = [
	[&"", &""], [&"longbow", &""], [&"volley", &""], [&"", &"stone"], [&"", &"spike"],
	[&"longbow", &"stone"], [&"longbow", &"spike"], [&"volley", &"stone"], [&"volley", &"spike"],
]
const SINGLES: Array = [[&"longbow", &""], [&"volley", &""], [&"", &"stone"], [&"", &"spike"]]
const MARGIN := BranchBench.MARGIN
const SAME := BranchBench.SAME
const PRESSURE := BranchBench.PRESSURE

var _cache := {}
var _t0 := 0
var _rows: Array = []

func before_all() -> void:
	_t0 = Time.get_ticks_msec()

func after_all() -> void:
	gut.p("FULL RULE TABLE: rule | the two numbers | bound | verdict")
	for r in _rows:
		gut.p("  %-58s %-26s vs %-14s %-16s %s" % [r[0], r[1], r[2], r[3], "PASS" if r[4] else "FAIL"])
	gut.p("BRANCH BENCH FULL FILE WALL TIME %.1f s, %d bench runs" % [(Time.get_ticks_msec() - _t0) / 1000.0, _cache.size()])

func before_each() -> void:
	Balance.reset()

func after_each() -> void:
	Balance.reset()

# ---- helpers -------------------------------------------------------------------------------------------------------------------

## One bench run, cached per (lane type, branches, pressure).
func _run(lane: StringName, tb: StringName, fb: StringName, pressure: int, tier := 3) -> Dictionary:
	var key := "%s|%s|%s|%d" % [lane, tb, fb, pressure] if tier == 3 else "%s|%s|%s|%d|t%d" % [lane, tb, fb, pressure, tier]
	if not _cache.has(key):
		_cache[key] = await BranchBench.run(lane, tb, fb, pressure, {"tier": tier} if tier != 3 else {})
	assert_false(_cache[key].timed_out, "%s did not clear in time" % key)
	return _cache[key]

func _cfg_name(cfg: Array) -> String:
	return BranchBench.cfg_name(cfg)

func _row(rule: String, a: String, b: String, bound: String, ok: bool) -> void:
	_rows.append([rule, a, b, bound, ok])

func _fmt(r: Dictionary) -> String:
	return "lost %8.1f  fence %6.1f  stands %7.2f s  hares %2d  clear %7.2f s  (%d ticks, %d kills)" % [r.diner_lost, r.fence_hp_left, r.fence_stands_s, r.hares_in_zone, r.clear_s, r.ticks, r.kills]

func _print_matrix(title: String, pressure: int, configs: Array) -> void:
	gut.p("MATRIX %s (pressure %d); columns: tower/fence branch" % [title, pressure])
	for lane in LANES:
		for cfg in configs:
			var r: Dictionary = await _run(lane, cfg[0], cfg[1], pressure)
			gut.p("  %-8s %-18s %s" % [lane, _cfg_name(cfg), _fmt(r)])

## E8 (spec 3.1): ON, OFF and NEUTRAL (BranchBench.RULES) at one pressure; every rule's numbers are printed.
func _check_rules(pressure: int, tier := 3) -> void:
	var res := {}
	for lane in LANES:
		res[lane] = {}
		for cfg in BranchBench.FAST_CONFIGS:
			res[lane][_cfg_name(cfg)] = await _run(lane, cfg[0], cfg[1], pressure, tier)
	for row in BranchBench.RULES:
		var v := BranchBench.rule_verdict(row, res[row[2]])
		var name := BranchBench.rule_name(row)
		gut.p("RULE t%d p%d %-16s %-8s %s: %s -> %s" % [tier, pressure, name, row[2], v.measure, v.why, "PASS" if v.ok else "FAIL"])
		_row("%s t%d p%d %s" % [name, tier, pressure, row[2]], "%s %.2f" % [v.measure, v.a], "%.2f" % v.b, "%s %.2f" % [BranchBench.rule_op(row), v.bound], v.ok)
		assert_true(v.ok, "%s t%d p%d %s lane: %s | unbranched %s | branch %s | fails when: %s" % [name, tier, pressure, row[2], v.why, _fmt(res[row[2]]["-/-"]), _fmt(res[row[2]][BranchBench.branch_cfg(row[1])]), BranchBench.RULE_FAILS_WHEN[name]])

func _check_specialists(pressure: int) -> void:
	for row in BranchBench.SPECIALISTS:
		var lane: StringName = row[0]
		var s: Array = row[1]
		var f: Array = row[2]
		var spec: Dictionary = await _run(lane, s[0], s[1], pressure)
		var ref: Dictionary = await _run(lane, f[0], f[1], pressure)
		var v := BranchBench.specialist_verdict(row, spec, ref)
		var upper: bool = v.measure == "fence_stands_s" or v.measure == "fence_hp_left"
		_row("SPECIALIST p%d %s: %s" % [pressure, lane, row[3]], "%s %.2f" % [v.measure, v.a], "%.2f" % v.b, "%s %.2f" % [">=" if upper else "<=", v.bound], v.ok)
		assert_true(v.ok, "SPECIALIST p%d %s lane, %s by 15%%: %s | spec %s | ref %s | fails when: %s" % [pressure, lane, row[3], v.why, _fmt(spec), _fmt(ref), row[5]])

func _check_identity(pressure: int) -> void:
	var siege := {}
	var hare := {}
	for cfg in [[&"", &""], [&"longbow", &""], [&"volley", &""], [&"", &"stone"], [&"", &"spike"]]:
		siege[_cfg_name(cfg)] = await _run(&"siege", cfg[0], cfg[1], pressure)
		hare[_cfg_name(cfg)] = await _run(&"hare", cfg[0], cfg[1], pressure)
	var rules := [
		["IDENTITY p%d siege: Longbow best tower state" % pressure, BranchBench.identity_longbow_siege(siege), "longbow_siege", "strictly least"],
		["IDENTITY p%d hare: Volley best tower state" % pressure, BranchBench.identity_volley_hare(hare), "volley_hare", "strictly least"],
		["IDENTITY p%d siege: Stone's fence stands longest" % pressure, BranchBench.identity_stone_stands_longest(siege), "stone_stands", "strictly longest"],
		["IDENTITY p%d hare: Spike fewest hares in the zone" % pressure, BranchBench.identity_spike_fewest_hares(hare), "spike_hares", "strictly fewest"],
	]
	for r in rules:
		_row(r[0], r[1].why, "", r[3], r[1].ok)
		assert_true(r[1].ok, "IDENTITY p%d %s | fails when: %s" % [pressure, r[1].why, BranchBench.IDENTITY_FAILS_WHEN[r[2]]])
	for lane in [&"siege", &"hare"]:
		var base: Dictionary = await _run(lane, &"", &"", pressure)
		var towers := minf((await _run(lane, &"longbow", &"", pressure)).diner_lost, (await _run(lane, &"volley", &"", pressure)).diner_lost)
		var fences := minf((await _run(lane, &"", &"stone", pressure)).diner_lost, (await _run(lane, &"", &"spike", pressure)).diner_lost)
		_row("IDENTITY p%d %s: unbranched tower never best" % [pressure, lane], "best branch %.1f" % towers, "base %.1f" % base.diner_lost, "strictly less", towers < base.diner_lost - SAME)
		_row("IDENTITY p%d %s: unbranched fence never best" % [pressure, lane], "best branch %.1f" % fences, "base %.1f" % base.diner_lost, "strictly less", fences < base.diner_lost - SAME)
		assert_lt(towers, base.diner_lost - SAME, "IDENTITY p%d %s: the unbranched tower is never best (best branch %.1f vs %.1f)" % [pressure, lane, towers, base.diner_lost])
		assert_lt(fences, base.diner_lost - SAME, "IDENTITY p%d %s: the unbranched fence is never best (best branch %.1f vs %.1f)" % [pressure, lane, fences, base.diner_lost])

# ---- the wave mixes ------------------------------------------------------------------------------------------------------------

func test_1_the_wave_mixes_at_pressure_12_are_the_real_formulas() -> void:
	await wait_physics_frames(10)  # records > 0 ticks: test_tick_budget requires every entry > 0
	for lane in LANES:
		var parts: Array = []
		for m in BranchBench.mix(lane, PRESSURE):
			parts.append("{boars %d, hares %d, brutes %d, hp_mult %.3f}" % [m.boars, m.hares, m.brutes, m.hp_mult])
		gut.p("MIX %s p%d: %s" % [lane, PRESSURE, " ".join(parts)])
	assert_eq(Balance.data.tiers.hare_lane_share, 0.7, "the share the mixes use")
	# Hand-checked (wave totals 19 / 29 / 30 of raw 19 / 29 / 39; side 9 / 13 / 14; hares main 4 / 6 / 6, side 3 / 5 / 5; hp_mult 2.65 x 39/30 on the last wave).
	var want := {
		&"siege": [[6, 1, 1], [10, 2, 1], [10, 2, 1]],
		&"hare": [[6, 5, 0], [10, 8, 0], [10, 8, 0]],
		&"neutral": [[6, 1, 0], [10, 2, 0], [10, 2, 0]],
	}
	for lane in want:
		var got: Array = BranchBench.mix(lane, PRESSURE)
		for w in 3:
			assert_eq([got[w].boars, got[w].hares, got[w].brutes], want[lane][w], "%s wave %d: boars, hares, brutes" % [lane, w])
		assert_almost_eq(float(got[0].hp_mult), 2.65, 1e-6, "wave 0 hp_mult")
		assert_almost_eq(float(got[2].hp_mult), 3.445, 1e-6, "wave 2 hp_mult carries the 39/30 oversize")

func test_2_the_bench_is_deterministic() -> void:
	await wait_physics_frames(10)  # records > 0 ticks: test_tick_budget requires every entry > 0
	var a: Dictionary = await BranchBench.run(&"hare", &"volley", &"spike", PRESSURE)
	var b: Dictionary = await BranchBench.run(&"hare", &"volley", &"spike", PRESSURE)
	assert_eq(a, b, "two runs of one configuration give identical dictionaries")
	assert_gt(int(a.ticks), 600, "the run really played the night (precondition)")
	assert_true(a.diner_lost > 0.0 and a.diner_lost < BranchBench.INVULNERABLE_HP, "the invulnerable diner took damage and never fell")

# ---- the matrix, the rules, the specialists, the identity -----------------------------------------------------------------------------------------------------------------

func _base() -> int:
	return int(Balance.data.tiers.tier_base[3])

func _cap() -> int:
	return int(Balance.data.tiers.tier_cap[3])

func test_3_matrix_at_the_cap() -> void:
	await wait_physics_frames(10)  # records > 0 ticks: test_tick_budget requires every entry > 0
	await _print_matrix("SHIPPED BALANCE, CAP", _cap(), CONFIGS)
	var r: Dictionary = await _run(&"siege", &"", &"", _cap())
	assert_gt(int(r.ticks), 600, "the matrix really ran")

func test_4_rules_on_off_neutral_at_the_tier_base() -> void:
	await wait_physics_frames(10)  # records > 0 ticks: test_tick_budget requires every entry > 0
	await _check_rules(_base())

func test_5_rules_on_off_neutral_at_the_tier_cap() -> void:
	await wait_physics_frames(10)  # records > 0 ticks: test_tick_budget requires every entry > 0
	await _check_rules(_cap())

func test_6_specialists_at_the_cap() -> void:
	await wait_physics_frames(10)  # records > 0 ticks: test_tick_budget requires every entry > 0
	await _check_specialists(_cap())

func test_7_identity_at_the_cap() -> void:
	await wait_physics_frames(10)  # records > 0 ticks: test_tick_budget requires every entry > 0
	await _check_identity(_cap())

## E8 phase 2 Task 8 (B9, D-314.26): ON, OFF and NEUTRAL at the tier-4 cap, on the tier-4 mixes (each lane type's group of the real planner's split, BranchBench.mix_tier4).
## THE RULE: every measure is summed over the four planner seeds BranchBench.T4_SEEDS (1, 2, 3, 4, in order): diner_lost and hares_in_zone are the sum, fence_stands_s the mean
## (BranchBench.sum_runs); each rule is then judged on the sums by the same functions as at tier 3. One seed's mix puts different lanes beside the brutes, so no one seed decides.
## OPEN ESCALATION (D-314.27): OFF Spike at the tier-4 cap, summed, FAILS on purpose and is left red (not weakened, skipped or retuned): it is a near tie, 25.46 s against
## 25.55 s mean stands (needs <= 22.99 s); Spike's brute multiplier 4.0 is at its widened maximum. Waiting for the author. Every other rule here passes.
## The per-seed numbers are printed. The micro-world is the same one-lane world as every other test here. CI runs the cap only; the base is in tests/bench_report/.
func test_8_rules_on_off_neutral_at_the_tier_4_cap_summed_over_four_seeds() -> void:
	await wait_physics_frames(10)  # records > 0 ticks: test_tick_budget requires every entry > 0
	var pressure := int(Balance.data.tiers.tier_cap[4])
	var res := {}
	for lane in LANES:
		res[lane] = {}
		for cfg in BranchBench.FAST_CONFIGS:
			var runs: Array = []
			for sd in BranchBench.T4_SEEDS:
				var key := "%s|%s|%s|%d|t4s%d" % [lane, cfg[0], cfg[1], pressure, sd]
				if not _cache.has(key):
					_cache[key] = await BranchBench.run(lane, cfg[0], cfg[1], pressure, {"tier": 4, "t4_seed": sd})
				assert_false(_cache[key].timed_out, "%s did not clear in time" % key)
				gut.p("  T4 seed %d %-8s %-12s %s" % [sd, lane, _cfg_name(cfg), _fmt(_cache[key])])
				runs.append(_cache[key])
			res[lane][_cfg_name(cfg)] = BranchBench.sum_runs(runs)
	for row in BranchBench.RULES:
		var v := BranchBench.rule_verdict(row, res[row[2]])
		var name := BranchBench.rule_name(row)
		gut.p("RULE t4 p%d SUMMED %-16s %-8s %s: %s -> %s" % [pressure, name, row[2], v.measure, v.why, "PASS" if v.ok else "FAIL"])
		_row("%s t4 p%d summed %s" % [name, pressure, row[2]], "%s %.2f" % [v.measure, v.a], "%.2f" % v.b, "%s %.2f" % [BranchBench.rule_op(row), v.bound], v.ok)
		assert_true(v.ok, "%s t4 p%d summed over seeds 1-4, %s lane: %s | fails when: %s" % [name, pressure, row[2], v.why, BranchBench.RULE_FAILS_WHEN[name]])
