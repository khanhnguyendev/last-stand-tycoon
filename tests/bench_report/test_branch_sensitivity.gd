extends GutTest
## E6 Task 8 (D-292): SENSITIVITY tables of the lane-type bench for the numeric levers the author pre-authorized (Longbow's kind
## multiplier, damage per shot, interval and range; Spike's pass and thorn damage). A REPORT for the tuning round, not a CI test: it
## asserts nothing about the numbers (it is outside tests/unit and tests/bench). Run it by hand:
##   "$GODOT" --headless --path . --fixed-fps 60 -s res://addons/gut/gut_cmdln.gd -gconfig= -gtest=res://tests/bench_report/test_branch_sensitivity.gd -gexit
## Flag ON, pressure 12, an invulnerable diner (tests/support/branch_bench.gd). Every row is a real bench run with the lever set in memory.
##
## Reading a row: "lost" = total diner HP lost, "fence" = fence HP left, "hares" = hares reaching the zone, "clear" = seconds to clear.
## FLOOR: no worse than the unbranched building (primary, then the lane type's first tie-breaker). SPEC: the 15% margin over the other
## branch, on the first measure that separates them (siege order: lost, fence; hare order: lost, hares, clear); shown for Longbow on
## siege (over Volley) and for Spike on hare (over Stone). ID: Longbow loses least of the three tower states (siege).
##
## Longbow range limit (D-271 / D-266, tests/unit/test_longbow_reach.gd): the THIRD-nearest lane of every tower must be farther than the
## Longbow range; the smallest such distance over the five towers is 10.28 m (tower_nw), so a Longbow range must stay BELOW 10.28 m
## (the rule test also requires the limit to stay >= 10.2 and a 10.5 m range to violate it). The largest range used here is 10.27 m.
## A hare has 15 x hp_mult HP: 39.75 in waves 1 and 2 and 51.7 in wave 3 (hp_mult 2.65 and 3.445). A hare passes the fence line ONCE,
## so Spike's pass damage is one hit: 40 or more kills a wave-1/2 hare in the pass, no value up to 51 kills a wave-3 hare in the pass;
## there is no second pass. Spike scales with the first wave's hp_mult over the tier base's, which is 1.0 at pressure 12.

const LANES: Array[StringName] = [&"siege", &"hare", &"neutral"]
const PRESSURE := 12
const SAME := 0.001
const MARGIN := 0.15
const FLOOR_ORDER := {
	&"siege": [["diner_lost", false], ["fence_hp_left", true]],
	&"hare": [["diner_lost", false], ["hares_in_zone", false]],
	&"neutral": [["diner_lost", false], ["clear_s", false]],
}
const SPEC_ORDER := {
	&"siege": [["diner_lost", false], ["fence_hp_left", true]],
	&"hare": [["diner_lost", false], ["hares_in_zone", false], ["clear_s", false]],
}
## The smallest change I (the implementer) believe meets floor + specialist on all three lane types. A SUGGESTION, not a decision.
const SUGGEST_LONGBOW := {"longbow_interval": 2.5}
const SUGGEST_SPIKE := {"spike_pass": 24.0}

var _cache := {}
var _t0 := 0

func before_all() -> void:
	_t0 = Time.get_ticks_msec()

func after_all() -> void:
	gut.p("SENSITIVITY WALL TIME %.1f s, %d bench runs" % [(Time.get_ticks_msec() - _t0) / 1000.0, _cache.size()])

func before_each() -> void:
	Balance.reset()

func after_each() -> void:
	Balance.reset()

func _run(lane: StringName, tb: StringName, fb: StringName, ov := {}) -> Dictionary:
	var key := "%s|%s|%s|%s" % [lane, tb, fb, ov]
	if not _cache.has(key):
		Balance.data.tiers.retune_enabled = true
		_cache[key] = await BranchBench.run(lane, tb, fb, PRESSURE, ov)
	return _cache[key]

func _fmt(r: Dictionary) -> String:
	return "lost %7.1f fence %5.1f hares %2d clear %6.2f" % [r.diner_lost, r.fence_hp_left, r.hares_in_zone, r.clear_s]

func _same(a: float, b: float) -> bool:
	return absf(a - b) <= SAME

func _floor(a: Dictionary, b: Dictionary, lane: StringName) -> bool:
	for m in FLOOR_ORDER[lane]:
		var x := float(a[m[0]])
		var y := float(b[m[0]])
		if _same(x, y):
			continue
		return x > y if m[1] else x < y
	return true

func _spec(a: Dictionary, b: Dictionary, lane: StringName) -> String:
	for m in SPEC_ORDER[lane]:
		var x := float(a[m[0]])
		var y := float(b[m[0]])
		if _same(x, y):
			continue
		var need := (1.0 + MARGIN) * y if m[1] else (1.0 - MARGIN) * y
		var ok: bool = x >= need if m[1] else x <= need
		return "%s on %s (%.1f vs %.1f, needs %s %.1f)" % ["PASS" if ok else "fail", m[0], x, y, ">=" if m[1] else "<=", need]
	return "fail: nothing separates"

func _references() -> void:
	for lane in LANES:
		gut.p("REFERENCE %-7s unbranched: %s" % [lane, _fmt(await _run(lane, &"", &""))])
		gut.p("REFERENCE %-7s Volley    : %s" % [lane, _fmt(await _run(lane, &"volley", &""))])
		gut.p("REFERENCE %-7s Stone     : %s" % [lane, _fmt(await _run(lane, &"", &"stone"))])
		gut.p("REFERENCE %-7s Longbow(today x2.0/120/3.0/9.98): %s" % [lane, _fmt(await _run(lane, &"longbow", &""))])
		gut.p("REFERENCE %-7s Spike (today pass 16/thorn 6)   : %s" % [lane, _fmt(await _run(lane, &"", &"spike"))])

func _longbow_row(label: String, ov: Dictionary) -> void:
	for lane in LANES:
		var base := await _run(lane, &"", &"")
		var r := await _run(lane, &"longbow", &"", ov)
		var line := "  %-26s %-7s Longbow %s | floor %s" % [label, lane, _fmt(r), "ok" if _floor(r, base, lane) else "FAIL"]
		if lane == &"siege":
			var vol := await _run(lane, &"volley", &"")
			line += " | spec vs Volley: %s | ID %s" % [_spec(r, vol, lane), "ok" if r.diner_lost < base.diner_lost - SAME and r.diner_lost < vol.diner_lost - SAME else "FAIL"]
		gut.p(line)

func _spike_row(label: String, ov: Dictionary) -> void:
	for lane in LANES:
		var base := await _run(lane, &"", &"")
		var r := await _run(lane, &"", &"spike", ov)
		var line := "  %-26s %-7s Spike %s | floor %s" % [label, lane, _fmt(r), "ok" if _floor(r, base, lane) else "FAIL"]
		if lane == &"hare":
			line += " | spec vs Stone: %s" % _spec(r, await _run(lane, &"", &"stone"), lane)
		if lane == &"siege":
			line += " | Stone vs this Spike (needs Stone <= 0.85 x Spike): %s" % _spec(await _run(lane, &"", &"stone"), r, lane)
		gut.p(line)

func test_1_references() -> void:
	await _references()
	pass_test("printed")

func test_2_longbow_kind_multiplier() -> void:
	gut.p("TABLE longbow kind multiplier (damage 120, interval 3.0, range 9.98)")
	for m in [2.0, 3.0, 4.0]:
		await _longbow_row("mult x%.1f" % m, {} if is_equal_approx(m, 2.0) else {"longbow_brute_mult": m})
	pass_test("printed")

func test_3_longbow_damage_per_shot() -> void:
	gut.p("TABLE longbow damage per shot (interval 3.0 s, mult x2.0)")
	for d in [120.0, 160.0, 200.0, 240.0]:
		await _longbow_row("damage %.0f" % d, {} if is_equal_approx(d, 120.0) else {"longbow_damage": d})
	pass_test("printed")

func test_4_longbow_interval() -> void:
	gut.p("TABLE longbow interval (damage 120, mult x2.0)")
	for i in [3.0, 2.4, 1.8, 1.2]:
		await _longbow_row("interval %.1f s" % i, {} if is_equal_approx(i, 3.0) else {"longbow_interval": i})
	pass_test("printed")

func test_5_longbow_range() -> void:
	gut.p("TABLE longbow range (limit < 10.28 m)")
	for r in [9.98, 10.27]:
		await _longbow_row("range %.2f m" % r, {} if is_equal_approx(r, 9.98) else {"longbow_range": r})
	pass_test("printed")

func test_6_spike_pass_damage() -> void:
	gut.p("TABLE spike pass damage (thorns 6); hare HP 39.75 / 39.75 / 51.7: 40 kills waves 1-2 in the pass")
	for d in [16.0, 24.0, 32.0, 40.0]:
		await _spike_row("pass %.0f" % d, {} if is_equal_approx(d, 16.0) else {"spike_pass": d})
	pass_test("printed")

func test_7_spike_thorn_damage() -> void:
	gut.p("TABLE spike thorn damage (pass 16); 3.0 is an extra row to see how much Spike's siege result moves")
	for t in [3.0, 6.0, 9.0, 12.0]:
		await _spike_row("thorn %.0f" % t, {} if is_equal_approx(t, 6.0) else {"spike_thorn": t})
	pass_test("printed")

func test_8_suggestions() -> void:
	gut.p("SUGGESTION (implementer's guess, not a decision) Longbow %s, Spike %s" % [SUGGEST_LONGBOW, SUGGEST_SPIKE])
	if not SUGGEST_LONGBOW.is_empty():
		await _longbow_row("SUGGESTED Longbow", SUGGEST_LONGBOW)
	if not SUGGEST_SPIKE.is_empty():
		await _spike_row("SUGGESTED Spike", SUGGEST_SPIKE)
	pass_test("printed")
