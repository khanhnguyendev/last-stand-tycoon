extends GutTest
## E6 Task 8 (spec 4.2 and 4.3, D-283, D-288, D-292): the FULL lane-type bench, its own suite (tests/bench/), with tick budgets like the sims.
## Measures: tests/support/branch_bench.gd (an invulnerable diner: the primary measure is the TOTAL diner HP lost over the whole run).
## It ranks branches relatively; it does not predict a real night (the real-play report does).
##
## FLOOR (D-288.1): for every lane type and every branch, compared with the unbranched building of the SAME kind (the other building
## unbranched in both runs): no worse on the primary measure (diner HP lost) and, when tied there (within 0.001), no worse on the lane
## type's first tie-breaker: siege = fence HP left (higher is better), hare = hares reaching the attack zone (fewer), neutral = time to
## clear (shorter).
##
## SPECIALIST (D-288.2): on its own lane type the specialist beats the OTHER branch of the same building (the other building unbranched)
## by at least 15% on the FIRST measure, in the lane type's order, on which the two differ (by more than 0.001). Orders: siege = diner HP
## lost, then fence HP left; hare = diner HP lost, then hares in the zone, then time to clear.
##   "15% better": lower-is-better measures (diner HP lost, hares in the zone, time to clear): specialist <= 0.85 x reference.
##   Higher-is-better (fence HP left): specialist >= 1.15 x reference.
##   Reference 0: lower-is-better, the two would be equal unless the specialist is worse, so it is never the deciding case and a non-zero
##   specialist fails; higher-is-better, any positive specialist value beats a reference of 0 (1.15 x 0 = 0).
##   If NO measure of the order separates the two, the assertion FAILS (the specialist is not clearly better on its own lane type).
## Own lane types: Longbow over Volley and Stone over Spike on siege; Volley over Longbow and Spike over Stone on hare.
##
## IDENTITY (spec 4.3, restated on these measures): Longbow loses the least diner HP of the three tower states on siege, Volley on hare;
## Stone keeps the most fence HP against the siege mix; Spike lets the fewest hares reach the zone on the hare mix; unbranched is never
## best (some branch of each kind is strictly better on the primary measure) on every lane type.
##
## Run at pressure 12 and at the final cap (skipped with a note while tier_cap[3] is 12), flag ON; the flag-OFF rows of the single-branch
## configurations are printed and the siege and hare ones pinned as literals (the "before" numbers of the retune).
## Results are cached per configuration inside this file; the TICKS of a test therefore include the runs it was the first to need.

const LANES: Array[StringName] = [&"siege", &"hare", &"neutral"]
## The nine configurations of the matrix: [tower branch, fence branch].
const CONFIGS: Array = [
	[&"", &""], [&"longbow", &""], [&"volley", &""], [&"", &"stone"], [&"", &"spike"],
	[&"longbow", &"stone"], [&"longbow", &"spike"], [&"volley", &"stone"], [&"volley", &"spike"],
]
const SINGLES: Array = [[&"longbow", &""], [&"volley", &""], [&"", &"stone"], [&"", &"spike"]]
## [measure, higher_is_better]
const FLOOR_ORDER := {
	&"siege": [["diner_lost", false], ["fence_hp_left", true]],
	&"hare": [["diner_lost", false], ["hares_in_zone", false]],
	&"neutral": [["diner_lost", false], ["clear_s", false]],
}
const SPECIALIST_ORDER := {
	&"siege": [["diner_lost", false], ["fence_hp_left", true]],
	&"hare": [["diner_lost", false], ["hares_in_zone", false], ["clear_s", false]],
}
## [specialist [tower, fence], reference [tower, fence], what changed, the mutation that fails the assertion]
const SPECIALISTS := {
	&"siege": [
		[[&"longbow", &""], [&"volley", &""], "Longbow over Volley", "Longbow kind multiplier 1.0 (longbow_kind_mult_retune[brute] = 1.0)"],
		[[&"", &"stone"], [&"", &"spike"], "Stone over Spike", "Stone's brute damage multiplier 1.0 (stone.damage_taken_mult_by_kind[brute] = 1.0)"],
	],
	&"hare": [
		[[&"volley", &""], [&"longbow", &""], "Volley over Longbow", "Volley damage cut to 5 (volley.damage = 5.0)"],
		[[&"", &"spike"], [&"", &"stone"], "Spike over Stone", "Spike pass damage 10 (spike_pass_damage_retune = 10.0)"],
	],
}
const MARGIN := 0.15
const SAME := 0.001
const PRESSURE := 12

var _cache := {}
var _t0 := 0

func before_all() -> void:
	_t0 = Time.get_ticks_msec()

func after_all() -> void:
	gut.p("BRANCH BENCH FULL FILE WALL TIME %.1f s, %d bench runs" % [(Time.get_ticks_msec() - _t0) / 1000.0, _cache.size()])

func before_each() -> void:
	Balance.reset()

func after_each() -> void:
	Balance.reset()

# ---- helpers -------------------------------------------------------------------------------------------------------------------

## One bench run, cached per (flag, lane type, branches, pressure). The flag is set BEFORE the run creates its world.
func _run(flag: bool, lane: StringName, tb: StringName, fb: StringName, pressure: int) -> Dictionary:
	var key := "%s|%s|%s|%s|%d" % [flag, lane, tb, fb, pressure]
	if not _cache.has(key):
		Balance.data.tiers.retune_enabled = flag
		_cache[key] = await BranchBench.run(lane, tb, fb, pressure)
		assert_false(_cache[key].timed_out, "%s did not clear in time" % key)
	return _cache[key]

func _cfg_name(cfg: Array) -> String:
	return "%s/%s" % [cfg[0] if cfg[0] != &"" else &"-", cfg[1] if cfg[1] != &"" else &"-"]

func _fmt(r: Dictionary) -> String:
	return "lost %8.1f  fence %6.1f  hares %2d  clear %7.2f s  (%d ticks, %d kills)" % [r.diner_lost, r.fence_hp_left, r.hares_in_zone, r.clear_s, r.ticks, r.kills]

func _print_matrix(title: String, flag: bool, pressure: int, configs: Array) -> void:
	gut.p("MATRIX %s (flag %s, pressure %d); columns: tower/fence branch" % [title, "ON" if flag else "OFF", pressure])
	for lane in LANES:
		for cfg in configs:
			var r: Dictionary = await _run(flag, lane, cfg[0], cfg[1], pressure)
			gut.p("  %-8s %-18s %s" % [lane, _cfg_name(cfg), _fmt(r)])

func _same(a: float, b: float) -> bool:
	return absf(a - b) <= SAME

## Is `a` no worse than `b` for this lane type's floor order? Returns {ok, why}.
func _no_worse(a: Dictionary, b: Dictionary, lane: StringName) -> Dictionary:
	for m in FLOOR_ORDER[lane]:
		var name: String = m[0]
		var higher: bool = m[1]
		if _same(float(a[name]), float(b[name])):
			continue
		var better: bool = float(a[name]) > float(b[name]) if higher else float(a[name]) < float(b[name])
		return {"ok": better, "why": "%s %s vs %s" % [name, snappedf(float(a[name]), 0.01), snappedf(float(b[name]), 0.01)]}
	return {"ok": true, "why": "tied on every floor measure"}

## Does the specialist beat the reference by MARGIN on the first measure that separates them? Returns {ok, why}.
func _beats_by_margin(spec: Dictionary, ref: Dictionary, lane: StringName) -> Dictionary:
	for m in SPECIALIST_ORDER[lane]:
		var name: String = m[0]
		var higher: bool = m[1]
		var a := float(spec[name])
		var b := float(ref[name])
		if _same(a, b):
			continue
		var need := (1.0 + MARGIN) * b if higher else (1.0 - MARGIN) * b
		var ok: bool = a >= need if higher else a <= need
		return {"ok": ok, "why": "first separating measure %s: specialist %.2f vs reference %.2f (needs %s %.2f)" % [name, a, b, ">=" if higher else "<=", need]}
	return {"ok": false, "why": "no measure separates the two (specialist %s | reference %s)" % [_fmt(spec), _fmt(ref)]}

func _check_floor(pressure: int) -> void:
	for lane in LANES:
		var base: Dictionary = await _run(true, lane, &"", &"", pressure)
		for cfg in SINGLES:
			var r: Dictionary = await _run(true, lane, cfg[0], cfg[1], pressure)
			var v := _no_worse(r, base, lane)
			assert_true(v.ok, "FLOOR p%d %s lane, %s must be no worse than unbranched: %s | unbranched %s | branch %s | fails when: Longbow damage cut to 30, Spike hp cut to 100, Volley damage cut to 2" % [pressure, lane, _cfg_name(cfg), v.why, _fmt(base), _fmt(r)])

func _check_specialists(pressure: int) -> void:
	for lane in SPECIALISTS:
		for row in SPECIALISTS[lane]:
			var s: Array = row[0]
			var f: Array = row[1]
			var spec: Dictionary = await _run(true, lane, s[0], s[1], pressure)
			var ref: Dictionary = await _run(true, lane, f[0], f[1], pressure)
			var v := _beats_by_margin(spec, ref, lane)
			assert_true(v.ok, "SPECIALIST p%d %s lane, %s by 15%%: %s | fails when: %s" % [pressure, lane, row[2], v.why, row[3]])

func _check_identity(pressure: int) -> void:
	var siege := {}
	var hare := {}
	for cfg in [[&"", &""], [&"longbow", &""], [&"volley", &""], [&"", &"stone"], [&"", &"spike"]]:
		siege[_cfg_name(cfg)] = await _run(true, &"siege", cfg[0], cfg[1], pressure)
		hare[_cfg_name(cfg)] = await _run(true, &"hare", cfg[0], cfg[1], pressure)
	var lb: float = siege["longbow/-"].diner_lost
	assert_true(lb < siege["-/-"].diner_lost - SAME and lb < siege["volley/-"].diner_lost - SAME, "IDENTITY p%d siege: Longbow %.1f loses least of unbranched %.1f / Volley %.1f | fails when: Longbow kind multiplier 1.0" % [pressure, lb, siege["-/-"].diner_lost, siege["volley/-"].diner_lost])
	var vy: float = hare["volley/-"].diner_lost
	assert_true(vy < hare["-/-"].diner_lost - SAME and vy < hare["longbow/-"].diner_lost - SAME, "IDENTITY p%d hare: Volley %.1f loses least of unbranched %.1f / Longbow %.1f | fails when: Volley damage cut to 5" % [pressure, vy, hare["-/-"].diner_lost, hare["longbow/-"].diner_lost])
	var st: float = siege["-/stone"].fence_hp_left
	assert_true(st > siege["-/-"].fence_hp_left + SAME and st > siege["-/spike"].fence_hp_left + SAME, "IDENTITY p%d siege: Stone keeps the most fence HP (%.1f vs unbranched %.1f, Spike %.1f) | fails when: Stone brute multiplier 1.0" % [pressure, st, siege["-/-"].fence_hp_left, siege["-/spike"].fence_hp_left])
	var sp: int = hare["-/spike"].hares_in_zone
	assert_true(sp < hare["-/-"].hares_in_zone and sp < hare["-/stone"].hares_in_zone, "IDENTITY p%d hare: Spike lets the fewest hares reach the zone (%d vs unbranched %d, Stone %d) | fails when: Spike pass damage 10" % [pressure, sp, hare["-/-"].hares_in_zone, hare["-/stone"].hares_in_zone])
	for lane in LANES:
		var base: Dictionary = await _run(true, lane, &"", &"", pressure)
		var towers := minf((await _run(true, lane, &"longbow", &"", pressure)).diner_lost, (await _run(true, lane, &"volley", &"", pressure)).diner_lost)
		var fences := minf((await _run(true, lane, &"", &"stone", pressure)).diner_lost, (await _run(true, lane, &"", &"spike", pressure)).diner_lost)
		assert_lt(towers, base.diner_lost - SAME, "IDENTITY p%d %s: the unbranched tower is never best (best branch %.1f vs %.1f)" % [pressure, lane, towers, base.diner_lost])
		assert_lt(fences, base.diner_lost - SAME, "IDENTITY p%d %s: the unbranched fence is never best (best branch %.1f vs %.1f)" % [pressure, lane, fences, base.diner_lost])

# ---- the wave mixes ------------------------------------------------------------------------------------------------------------

func test_1_the_wave_mixes_at_pressure_12_are_the_real_formulas() -> void:
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
	Balance.data.tiers.retune_enabled = true
	var a: Dictionary = await BranchBench.run(&"hare", &"volley", &"spike", PRESSURE)
	var b: Dictionary = await BranchBench.run(&"hare", &"volley", &"spike", PRESSURE)
	assert_eq(a, b, "two runs of one configuration give identical dictionaries")
	assert_gt(int(a.ticks), 600, "the run really played the night (precondition)")
	assert_true(a.diner_lost > 0.0 and a.diner_lost < BranchBench.INVULNERABLE_HP, "the invulnerable diner took damage and never fell")

# ---- flag ON -------------------------------------------------------------------------------------------------------------------

func test_3_matrix_flag_on_pressure_12() -> void:
	await _print_matrix("FLAG ON", true, PRESSURE, CONFIGS)
	var r: Dictionary = await _run(true, &"siege", &"", &"", PRESSURE)
	assert_gt(int(r.ticks), 600, "the matrix really ran")

func test_4_floor_pressure_12() -> void:
	await _check_floor(PRESSURE)

func test_5_specialist_margin_pressure_12() -> void:
	await _check_specialists(PRESSURE)

func test_6_identity_pressure_12() -> void:
	await _check_identity(PRESSURE)

func test_7_the_rule_at_the_final_cap() -> void:
	var cap: int = Balance.data.tiers.tier_cap[3]
	if cap == PRESSURE:
		gut.p("CAP PASS skipped: tier_cap[3] is %d, the pressure the tests above already ran" % cap)
		assert_eq(cap, PRESSURE, "the cap pass is skipped only while the cap equals the pressure of the 12 tests")
		return
	await _print_matrix("FLAG ON, CAP", true, cap, CONFIGS)
	await _check_floor(cap)
	await _check_specialists(cap)
	await _check_identity(cap)

# ---- flag OFF ------------------------------------------------------------------------------------------------------------------

## Today's values (flag off, pressure 12, invulnerable diner), recorded at this task's base: [diner_lost, fence_hp_left, hares_in_zone, clear_s, ticks].
## These are the "before" numbers of the retune. Longbow does no extra damage to brutes, Spike's pass damage is 10.
const OFF_PINS := {
	"siege|-/-": [1780.0, 0.0, 5, 173.27, 10696], "siege|longbow/-": [1657.0, 0.0, 4, 175.58, 10835], "siege|volley/-": [706.0, 0.0, 3, 185.65, 11439],
	"siege|-/stone": [1478.0, 0.0, 4, 173.37, 10702], "siege|-/spike": [1673.0, 0.0, 5, 167.22, 10333],
	"hare|-/-": [1693.0, 0.0, 21, 138.58, 8615], "hare|longbow/-": [2313.0, 0.0, 20, 166.90, 10314], "hare|volley/-": [395.0, 0.0, 17, 101.10, 6366],
	"hare|-/stone": [1355.0, 0.0, 21, 138.58, 8615], "hare|-/spike": [1062.0, 0.0, 20, 121.80, 7608],
}

func test_8_flag_off_rows_and_pins() -> void:
	await _print_matrix("FLAG OFF (unbranched and single changes)", false, PRESSURE, [[&"", &""]] + SINGLES)
	for lane in [&"siege", &"hare"]:
		for cfg in [[&"", &""]] + SINGLES:
			var key := "%s|%s" % [lane, _cfg_name(cfg)]
			var r: Dictionary = await _run(false, lane, cfg[0], cfg[1], PRESSURE)
			assert_true(OFF_PINS.has(key), "pinned: %s" % key)
			if not OFF_PINS.has(key):
				continue
			var p: Array = OFF_PINS[key]
			assert_almost_eq(float(r.diner_lost), float(p[0]), SAME, "%s diner_lost (flag off)" % key)
			assert_almost_eq(float(r.fence_hp_left), float(p[1]), SAME, "%s fence_hp_left (flag off)" % key)
			assert_eq(int(r.hares_in_zone), int(p[2]), "%s hares_in_zone (flag off)" % key)
			assert_almost_eq(float(r.clear_s), float(p[3]), 0.01, "%s clear_s (flag off)" % key)
			assert_eq(int(r.ticks), int(p[4]), "%s ticks (flag off)" % key)
