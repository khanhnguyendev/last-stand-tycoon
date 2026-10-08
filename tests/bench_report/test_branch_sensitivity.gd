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
		gut.p("REFERENCE %-7s Longbow(committed x%.1f/%.0f/%.1f/%.2f): %s" % [lane, float(Balance.data.branches.longbow_kind_mult_retune[&"brute"]), Balance.data.branches.longbow.damage, Balance.data.branches.longbow_interval_retune, Balance.data.branches.longbow.attack_range, _fmt(await _run(lane, &"longbow", &""))])
		gut.p("REFERENCE %-7s Spike (committed pass %.0f/thorn %.0f)   : %s" % [lane, Balance.data.branches.spike_pass_damage_retune, Balance.data.branches.spike.thorn_damage, _fmt(await _run(lane, &"", &"spike"))])

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
	gut.p("TABLE longbow kind multiplier (damage 120, interval %.1f, range 9.98)" % Balance.data.branches.longbow_interval_retune)
	for m in [2.0, 3.0, 4.0]:
		await _longbow_row("mult x%.1f" % m, {} if is_equal_approx(m, 2.0) else {"longbow_brute_mult": m})
	pass_test("printed")

func test_3_longbow_damage_per_shot() -> void:
	gut.p("TABLE longbow damage per shot (interval %.1f s, mult x2.0)" % Balance.data.branches.longbow_interval_retune)
	for d in [120.0, 160.0, 200.0, 240.0]:
		await _longbow_row("damage %.0f" % d, {} if is_equal_approx(d, 120.0) else {"longbow_damage": d})
	pass_test("printed")

func test_4_longbow_interval() -> void:
	gut.p("TABLE longbow interval (damage 120, mult x2.0)")
	for i in [3.0, 2.4, 1.8, 1.2]:
		await _longbow_row("interval %.1f s" % i, {"longbow_interval": i})
	pass_test("printed")

func test_5_longbow_range() -> void:
	gut.p("TABLE longbow range (limit < 10.28 m)")
	for r in [9.98, 10.27]:
		await _longbow_row("range %.2f m" % r, {} if is_equal_approx(r, 9.98) else {"longbow_range": r})
	pass_test("printed")

func test_6_spike_pass_damage() -> void:
	gut.p("TABLE spike pass damage (thorns 6); hare HP 39.75 / 39.75 / 51.7: 40 kills waves 1-2 in the pass")
	for d in [16.0, 24.0, 32.0, 40.0]:
		await _spike_row("pass %.0f" % d, {"spike_pass": d})
	pass_test("printed")

func test_7_spike_thorn_damage() -> void:
	gut.p("TABLE spike thorn damage (pass %.0f); 3.0 is an extra row to see how much Spike's siege result moves" % Balance.data.branches.spike_pass_damage_retune)
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

# ---- candidate set, Stone wall data, fast-subset variants (coordinator request, D-292) ------------------------------------------

const CFG_NAMES := ["-/-", "longbow/-", "volley/-", "-/stone", "-/spike", "longbow/stone", "longbow/spike", "volley/stone", "volley/spike"]
const CONFIGS: Array = [
	[&"", &""], [&"longbow", &""], [&"volley", &""], [&"", &"stone"], [&"", &"spike"],
	[&"longbow", &"stone"], [&"longbow", &"spike"], [&"volley", &"stone"], [&"volley", &"spike"],
]
const FIVE: Array = [[&"", &""], [&"longbow", &""], [&"volley", &""], [&"", &"stone"], [&"", &"spike"]]
const FIRST_FOUR_LANES := [&"siege", &"hare"]

func _cn(cfg: Array) -> String:
	return "%s/%s" % [cfg[0] if cfg[0] != &"" else &"-", cfg[1] if cfg[1] != &"" else &"-"]

func _candidate(interval: float) -> Dictionary:
	return {"longbow_interval": interval, "spike_pass": 24.0}

## res[lane][cfg name] = bench result, for `configs` under the overrides `ov` (cached).
func _matrix(ov: Dictionary, configs: Array, lanes := LANES) -> Dictionary:
	var res := {}
	for lane in lanes:
		res[lane] = {}
		for cfg in configs:
			res[lane][_cn(cfg)] = await _run(lane, cfg[0], cfg[1], ov)
	return res

func _print_matrix(title: String, res: Dictionary) -> void:
	gut.p("MATRIX %s" % title)
	for lane in res:
		for name in res[lane]:
			var r: Dictionary = res[lane][name]
			gut.p("  %-8s %-14s %s  (%d ticks)" % [lane, name, _fmt(r), r.ticks])

func _rule(name: String, ok: bool, text: String) -> Dictionary:
	return {"name": name, "ok": ok, "text": text}

## Every rule of the fast file (full=false: primary measure only) or the full file (full=true: tie-breakers too) over `res`.
func _evaluate(res: Dictionary, full: bool) -> Array:
	var out: Array = []
	for lane in res:
		if not res[lane].has("-/-"):
			continue
		var base: Dictionary = res[lane]["-/-"]
		for name in ["longbow/-", "volley/-", "-/stone", "-/spike"]:
			if not res[lane].has(name):
				continue
			var r: Dictionary = res[lane][name]
			var ok := false
			var text := ""
			if full:
				ok = _floor(r, base, lane)
				var shown := "diner_lost"
				for m in FLOOR_ORDER[lane]:
					shown = m[0]
					if not _same(float(r[m[0]]), float(base[m[0]])):
						break
				text = "%s %.1f <= unbranched %.1f%s" % [shown, float(r[shown]), float(base[shown]), " (higher is better)" if shown == "fence_hp_left" else ""]
			else:
				ok = float(r.diner_lost) <= float(base.diner_lost) + SAME
				text = "lost %.1f <= unbranched %.1f" % [r.diner_lost, base.diner_lost]
			out.append(_rule("FLOOR %s %s" % [lane, name], ok, text))
	var specs := [
		[&"siege", "longbow/-", "volley/-", "Longbow over Volley"], [&"siege", "-/stone", "-/spike", "Stone over Spike"],
		[&"hare", "volley/-", "longbow/-", "Volley over Longbow"], [&"hare", "-/spike", "-/stone", "Spike over Stone"],
	]
	for s in specs:
		if not res.has(s[0]) or not res[s[0]].has(s[1]):
			continue
		var a: Dictionary = res[s[0]][s[1]]
		var b: Dictionary = res[s[0]][s[2]]
		if full:
			var v := _spec(a, b, s[0])
			out.append(_rule("SPEC %s lane, %s" % [s[0], s[3]], v.begins_with("PASS"), v))
		else:
			var ok := float(a.diner_lost) < float(b.diner_lost) - SAME and float(a.diner_lost) <= 0.85 * float(b.diner_lost)
			out.append(_rule("SPEC %s lane, %s" % [s[0], s[3]], ok, "lost %.1f <= 0.85 x %.1f = %.1f" % [a.diner_lost, b.diner_lost, 0.85 * float(b.diner_lost)]))
	var sg: Dictionary = res[&"siege"]
	out.append(_rule("ID siege: Longbow loses least tower state", sg["longbow/-"].diner_lost < sg["-/-"].diner_lost - SAME and sg["longbow/-"].diner_lost < sg["volley/-"].diner_lost - SAME,
		"Longbow %.1f < unbranched %.1f and < Volley %.1f" % [sg["longbow/-"].diner_lost, sg["-/-"].diner_lost, sg["volley/-"].diner_lost]))
	if res.has(&"hare"):
		var hr: Dictionary = res[&"hare"]
		out.append(_rule("ID hare: Volley loses least tower state", hr["volley/-"].diner_lost < hr["-/-"].diner_lost - SAME and hr["volley/-"].diner_lost < hr["longbow/-"].diner_lost - SAME,
			"Volley %.1f < unbranched %.1f and < Longbow %.1f" % [hr["volley/-"].diner_lost, hr["-/-"].diner_lost, hr["longbow/-"].diner_lost]))
		if full:
			out.append(_rule("ID hare: Spike lets fewest hares reach the zone", hr["-/spike"].hares_in_zone < hr["-/-"].hares_in_zone and hr["-/spike"].hares_in_zone < hr["-/stone"].hares_in_zone,
				"Spike %d < unbranched %d and < Stone %d" % [hr["-/spike"].hares_in_zone, hr["-/-"].hares_in_zone, hr["-/stone"].hares_in_zone]))
	if full:
		out.append(_rule("ID siege: Stone wall's fence stands longest (D-294.6)", sg["-/stone"].fence_stands_s > sg["-/-"].fence_stands_s and sg["-/stone"].fence_stands_s > sg["-/spike"].fence_stands_s,
			"Stone %.2f s > unbranched %.2f s and > Spike %.2f s" % [sg["-/stone"].fence_stands_s, sg["-/-"].fence_stands_s, sg["-/spike"].fence_stands_s]))
	for lane in res:
		var b2: Dictionary = res[lane]["-/-"]
		var tw := minf(res[lane]["longbow/-"].diner_lost, res[lane]["volley/-"].diner_lost)
		var fn := minf(res[lane]["-/stone"].diner_lost, res[lane]["-/spike"].diner_lost)
		out.append(_rule("ID %s: unbranched tower never best" % lane, tw < b2.diner_lost - SAME, "best branch %.1f < unbranched %.1f" % [tw, b2.diner_lost]))
		out.append(_rule("ID %s: unbranched fence never best" % lane, fn < b2.diner_lost - SAME, "best branch %.1f < unbranched %.1f" % [fn, b2.diner_lost]))
	return out

func _print_rules(title: String, rules: Array) -> void:
	var fails := 0
	gut.p("RULES %s" % title)
	for r in rules:
		if not r.ok:
			fails += 1
		gut.p("  %s  %s: %s" % ["PASS" if r.ok else "FAIL", r.name, r.text])
	gut.p("  -> %d of %d rules FAIL" % [fails, rules.size()])

func test_9_candidate_set_matrices_and_rules() -> void:
	for interval in [2.4, 2.2, 2.0]:
		var res := await _matrix(_candidate(interval), CONFIGS)
		_print_matrix("CANDIDATE Longbow interval %.1f s + Spike pass 24" % interval, res)
		_print_rules("FULL file, interval %.1f s + pass 24" % interval, _evaluate(res, true))
		_print_rules("FAST file, interval %.1f s + pass 24" % interval, _evaluate(res, false))
		var hv: Dictionary = res[&"hare"]
		gut.p("VOLLEY LEAD on hare (Longbow interval %.1f): Volley %.1f vs Longbow %.1f, bound 0.85 x Longbow = %.1f; Volley vs unbranched %.1f" % [interval, hv["volley/-"].diner_lost, hv["longbow/-"].diner_lost, 0.85 * float(hv["longbow/-"].diner_lost), hv["-/-"].diner_lost])
	pass_test("printed")

func _stone_row(label: String, ov: Dictionary, tower: StringName) -> void:
	var spike: Dictionary = await _run(&"siege", tower, &"spike", {"spike_pass": 24.0, "longbow_interval": 2.4})
	var base: Dictionary = await _run(&"siege", tower, &"", {"spike_pass": 24.0, "longbow_interval": 2.4})
	var o := ov.duplicate()
	o["spike_pass"] = 24.0
	o["longbow_interval"] = 2.4
	var stone: Dictionary = await _run(&"siege", tower, &"stone", o)
	var bound := 0.85 * float(spike.diner_lost)
	gut.p("  %-34s Stone lost %7.1f fence %5.1f hares %d clear %6.2f fell %6.2f absorbed %6.1f | Spike lost %7.1f fell %6.2f | unbranched lost %7.1f fell %6.2f | bound %7.1f %s" % [
		label, stone.diner_lost, stone.fence_hp_left, stone.hares_in_zone, stone.clear_s, stone.fence_fell_s, stone.fence_absorbed,
		spike.diner_lost, spike.fence_fell_s, base.diner_lost, base.fence_fell_s, bound, "PASS" if float(stone.diner_lost) <= bound else "FAIL"])

const STONE_ROWS := [
	["Stone today (640, x0.5)", {}], ["brute mult 0.4", {"stone_brute_mult": 0.4}], ["brute mult 0.33", {"stone_brute_mult": 0.33}],
	["brute mult 0.25", {"stone_brute_mult": 0.25}], ["HP 800", {"stone_hp": 800.0}], ["HP 960", {"stone_hp": 960.0}], ["HP 1280", {"stone_hp": 1280.0}],
]

func test_10_stone_wall_data() -> void:
	for tower in [&"", &"longbow"]:
		gut.p("STONE DATA siege lane, tower %s (Longbow interval 2.4 when Longbow), Spike pass 24" % ("unbranched" if tower == &"" else "candidate Longbow"))
		for row in STONE_ROWS:
			await _stone_row(row[0], row[1], tower)
		for row in STONE_COMBOS:
			await _stone_row(row[0], row[1], tower)
	# Fence fall time as the first measure (higher is better, 15% margin): Stone today vs Spike, unbranched tower.
	var st: Dictionary = await _run(&"siege", &"", &"stone", {"spike_pass": 24.0, "longbow_interval": 2.4})
	var sp: Dictionary = await _run(&"siege", &"", &"spike", {"spike_pass": 24.0, "longbow_interval": 2.4})
	gut.p("FENCE-FALL MEASURE: Stone today falls at %.2f s, Spike at %.2f s, bound 1.15 x Spike = %.2f -> %s" % [st.fence_fell_s, sp.fence_fell_s, 1.15 * float(sp.fence_fell_s), "PASS" if float(st.fence_fell_s) >= 1.15 * float(sp.fence_fell_s) else "FAIL"])
	pass_test("printed")

## Combined rows of the implementer's choice: HP 710 is the smallest single change found (HP 700 gives 1433, 710 gives 1413 against the bound 1422),
## the second row shows a mild two-lever mix.
const STONE_COMBOS := [
	["HP 710 (smallest single change found)", {"stone_hp": 710.0}], ["HP 700 (just below)", {"stone_hp": 700.0}],
	["mult 0.45 + HP 700", {"stone_brute_mult": 0.45, "stone_hp": 700.0}],
]

func _timed_variant(label: String, configs: Array, lanes: Array, ov: Dictionary) -> Dictionary:
	var t0 := Time.get_ticks_msec()
	var res := {}
	for lane in lanes:
		res[lane] = {}
		for cfg in configs:
			Balance.data.tiers.retune_enabled = true
			res[lane][_cn(cfg)] = await BranchBench.run(lane, cfg[0], cfg[1], PRESSURE, ov)
	var secs := (Time.get_ticks_msec() - t0) / 1000.0
	var ticks := 0
	for lane in res:
		for n in res[lane]:
			ticks += int(res[lane][n].ticks)
	gut.p("VARIANT %s: %d runs, %.1f s wall, %d ticks" % [label, lanes.size() * configs.size(), secs, ticks])
	return res

func _verdicts(rules: Array) -> Dictionary:
	var d := {}
	for r in rules:
		d[r.name] = r.ok
	return d

func test_11_fast_subset_variants() -> void:
	var ov := _candidate(2.4)
	var all15 := await _timed_variant("(i) 15 runs, three waves", FIVE, LANES, ov)
	var ten := await _timed_variant("(ii) 10 runs (siege and hare only), three waves", FIVE, FIRST_FOUR_LANES, ov)
	var last := await _timed_variant("(iii) 15 runs, LAST wave only", FIVE, LANES, ov.merged({"last_wave_only": true}))
	_print_matrix("(iii) last wave only", last)
	var v_all := _verdicts(_evaluate(all15, false))
	var v_ten := _verdicts(_evaluate(ten, false))
	var v_last := _verdicts(_evaluate(last, false))
	_print_rules("FAST rules, (i)", _evaluate(all15, false))
	_print_rules("FAST rules, (iii) last wave only", _evaluate(last, false))
	var flips: Array = []
	for k in v_all:
		if v_ten.has(k) and v_ten[k] != v_all[k]:
			flips.append("(ii) flips %s" % k)
		if v_last[k] != v_all[k]:
			flips.append("(iii) flips %s: three waves %s, last wave %s" % [k, v_all[k], v_last[k]])
	gut.p("FLIPPED verdicts vs (i): %s" % ("none" if flips.is_empty() else str(flips)))
	var full_v := _verdicts(_evaluate(all15, true))
	var flips_full: Array = []
	for k in v_all:
		if full_v.has(k) and full_v[k] != v_all[k]:
			flips_full.append(k)
	gut.p("Rules whose verdict differs between the fast (primary only) and full (tie-breaker) reading on the same runs: %s" % ("none" if flips_full.is_empty() else str(flips_full)))
	pass_test("printed")
