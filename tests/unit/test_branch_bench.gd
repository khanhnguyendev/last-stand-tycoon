extends GutTest
## E6 Task 8 (D-288, D-292.2): the FAST subset of the lane-type bench, in the unit suite. Flag on, pressure 12, each lane type, the PRIMARY
## measure only (total diner HP lost with an invulnerable diner, see tests/support/branch_bench.gd). The full bench (tie-breakers, pairs,
## the cap, the flag-off pins, the tables) is tests/bench/test_branch_bench_full.gd. Five configurations per lane type, 15 runs:
## unbranched, Longbow, Volley (with an unbranched fence) and Stone, Spike (with an unbranched tower).
##
## FLOOR: every branch loses no more diner HP than the unbranched building of its kind (tied within 0.001 counts as no worse).
## SPECIALIST: on its own lane type the specialist's HP lost <= 0.85 x the other branch's (lower is better). Own lane types: Longbow over
##   Volley and Stone over Spike on siege; Volley over Longbow and Spike over Stone on hare. A reference of 0 can never be beaten by 15%
##   (nothing is below 0), so it fails; the test also requires the specialist to be strictly lower.
## IDENTITY: Longbow loses the least of the three tower states on siege, Volley on hare (strictly less than both others); and on every
##   lane type unbranched is never best: some branch of each building kind loses strictly less than the unbranched building.

const PRESSURE := 12
const SAME := 0.001
const CFG := {
	&"base": [&"", &""], &"longbow": [&"longbow", &""], &"volley": [&"volley", &""], &"stone": [&"", &"stone"], &"spike": [&"", &"spike"],
}

var _lost := {}  ## lane -> config name -> diner HP lost
var _t0 := 0

func before_all() -> void:
	_t0 = Time.get_ticks_msec()
	Balance.reset()
	Balance.data.tiers.retune_enabled = true
	var runs := 0
	for lane in [&"siege", &"hare", &"neutral"]:
		_lost[lane] = {}
		for name in CFG:
			var cfg: Array = CFG[name]
			var r: Dictionary = await BranchBench.run(lane, cfg[0], cfg[1], PRESSURE)
			_lost[lane][name] = r.diner_lost
			runs += 1
			gut.p("  FAST %-8s %-8s diner lost %8.1f (%d ticks%s)" % [lane, name, r.diner_lost, r.ticks, ", TIMED OUT" if r.timed_out else ""])
	Balance.reset()
	gut.p("FAST SUBSET: %d runs in %.1f s" % [runs, (Time.get_ticks_msec() - _t0) / 1000.0])

func after_all() -> void:
	Balance.reset()

func _hp(lane: StringName, name: StringName) -> float:
	return float(_lost[lane][name])

func _no_worse(a: float, b: float) -> bool:
	return a <= b + SAME

func _beats_by_15(a: float, b: float) -> bool:
	return a < b - SAME and a <= 0.85 * b

func test_floor_every_branch_loses_no_more_than_the_unbranched_building() -> void:
	for lane in _lost:
		for name in [&"longbow", &"volley"]:
			assert_true(_no_worse(_hp(lane, name), _hp(lane, &"base")), "FLOOR %s: %s %.1f vs unbranched %.1f | fails when: Longbow damage cut to 30, Volley damage cut to 2" % [lane, name, _hp(lane, name), _hp(lane, &"base")])
		for name in [&"stone", &"spike"]:
			assert_true(_no_worse(_hp(lane, name), _hp(lane, &"base")), "FLOOR %s: %s %.1f vs unbranched %.1f | fails when: Spike hp cut to 100, Stone hp cut to 100" % [lane, name, _hp(lane, name), _hp(lane, &"base")])

func test_specialist_margin_on_its_own_lane_type() -> void:
	var rows := [
		[&"siege", &"longbow", &"volley", "Longbow over Volley", "Longbow kind multiplier 1.0"],
		[&"siege", &"stone", &"spike", "Stone over Spike", "Stone brute damage multiplier 1.0"],
		[&"hare", &"volley", &"longbow", "Volley over Longbow", "Volley damage cut to 5"],
		[&"hare", &"spike", &"stone", "Spike over Stone", "Spike pass damage 10"],
	]
	for r in rows:
		var a := _hp(r[0], r[1])
		var b := _hp(r[0], r[2])
		assert_true(_beats_by_15(a, b), "SPECIALIST %s lane, %s: %.1f vs %.1f (needs <= %.1f) | fails when: %s" % [r[0], r[3], a, b, 0.85 * b, r[4]])

func test_identity_longbow_on_siege_volley_on_hare_and_unbranched_never_best() -> void:
	var s := [_hp(&"siege", &"base"), _hp(&"siege", &"longbow"), _hp(&"siege", &"volley")]
	assert_true(s[1] < s[0] - SAME and s[1] < s[2] - SAME, "IDENTITY siege: Longbow %.1f must lose least (unbranched %.1f, Volley %.1f) | fails when: Longbow kind multiplier 1.0" % [s[1], s[0], s[2]])
	var h := [_hp(&"hare", &"base"), _hp(&"hare", &"longbow"), _hp(&"hare", &"volley")]
	assert_true(h[2] < h[0] - SAME and h[2] < h[1] - SAME, "IDENTITY hare: Volley %.1f must lose least (unbranched %.1f, Longbow %.1f) | fails when: Volley damage cut to 5" % [h[2], h[0], h[1]])
	for lane in _lost:
		var towers := minf(_hp(lane, &"longbow"), _hp(lane, &"volley"))
		var fences := minf(_hp(lane, &"stone"), _hp(lane, &"spike"))
		assert_lt(towers, _hp(lane, &"base") - SAME, "IDENTITY %s: unbranched tower is never the best (best branch %.1f vs %.1f)" % [lane, towers, _hp(lane, &"base")])
		assert_lt(fences, _hp(lane, &"base") - SAME, "IDENTITY %s: unbranched fence is never the best (best branch %.1f vs %.1f)" % [lane, fences, _hp(lane, &"base")])
