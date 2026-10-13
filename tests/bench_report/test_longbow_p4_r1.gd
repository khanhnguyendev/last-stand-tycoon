extends GutTest
## E6 phase 4, tuning round 1 (D-292): the Longbow sensitivity grid, interval x damage per shot x brute multiplier, on the lane-type bench.
## A REPORT, not a CI test (outside tests/unit and tests/bench): it asserts nothing about the numbers. Flag ON, pressure 12, all other values as committed.
## Run it by hand (all 24 candidates, one process; about 40 min), or split by interval across up to 3 processes with LB_INTERVALS:
##   LB_INTERVALS=2.4,2.2 "$GODOT" --headless --path . --fixed-fps 60 -s res://addons/gut/gut_cmdln.gd -gconfig= -gtest=res://tests/bench_report/test_longbow_p4_r1.gd -gexit
## Each candidate prints one machine-readable line: `CAND interval dmg_pct mult | siege lost | hare lost | neutral lost | siege1 | siege2 | boars | RULES ok|FAIL <first failing rule>`.
## The references (unbranched, Volley, Stone, Spike on the three lanes; unbranched and Volley with 1 and 2 brutes and on the boars-only lane) print as `REF` lines.
## "siege1" / "siege2" = the siege lane with ONE / TWO brutes in the night (the last 1 or 2 waves carry one) instead of three (real play: 1 on the first tier-3 night, 2 on the second, 3 from the third: the last 1, 2 or 3 waves carry the lane's brute; brute_cap_main[3] is 1).
## "boars" = the neutral mix with every hare replaced by a boar (no brutes, no hares), the plain boar lane. The bench has no such lane type; this is the addition.

const LANES: Array[StringName] = [&"siege", &"hare", &"neutral"]
const PRESSURE := 12
const INTERVALS := [2.4, 2.2, 2.0, 1.8]
const DAMAGE_PCT := [0, 20, 40]
const MULTS := [2.0, 3.0]
const CONFIGS: Array = [[&"", &""], [&"longbow", &""], [&"volley", &""], [&"", &"stone"], [&"", &"spike"]]

var _cache := {}
var _t0 := 0

func before_all() -> void:
	_t0 = Time.get_ticks_msec()

func after_all() -> void:
	gut.p("LB WALL TIME %.1f s, %d bench runs" % [(Time.get_ticks_msec() - _t0) / 1000.0, _cache.size()])

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

func _intervals() -> Array:
	var env := OS.get_environment("LB_INTERVALS")
	if env == "":
		return INTERVALS
	var out: Array = []
	for t in env.split(","):
		out.append(float(t))
	return out

func _cn(cfg: Array) -> String:
	return BranchBench.cfg_name(cfg)

## Every bench rule over `res` (lane -> cfg name -> run), in the order floor, specialist, identity; the shared rule functions. [{name, ok}].
func _rules(res: Dictionary) -> Array:
	var out: Array = []
	for lane in LANES:
		for name in ["longbow/-", "volley/-", "-/stone", "-/spike"]:
			out.append({"name": "FLOOR %s %s" % [lane, name], "ok": BranchBench.no_worse(res[lane][name], res[lane]["-/-"], lane).ok})
	for row in BranchBench.SPECIALISTS:
		var v := BranchBench.specialist_verdict(row, res[row[0]][_cn(row[1])], res[row[0]][_cn(row[2])])
		out.append({"name": "SPEC %s %s" % [row[0], row[3]], "ok": v.ok})
	out.append({"name": "ID siege Longbow least", "ok": BranchBench.identity_longbow_siege(res[&"siege"]).ok})
	out.append({"name": "ID hare Volley least", "ok": BranchBench.identity_volley_hare(res[&"hare"]).ok})
	out.append({"name": "ID siege Stone stands longest", "ok": BranchBench.identity_stone_stands_longest(res[&"siege"]).ok})
	out.append({"name": "ID hare Spike fewest hares", "ok": BranchBench.identity_spike_fewest_hares(res[&"hare"]).ok})
	for lane in LANES:
		var b: Dictionary = res[lane]["-/-"]
		out.append({"name": "ID %s tower never best" % lane, "ok": minf(res[lane]["longbow/-"].diner_lost, res[lane]["volley/-"].diner_lost) < b.diner_lost - BranchBench.SAME})
		out.append({"name": "ID %s fence never best" % lane, "ok": minf(res[lane]["-/stone"].diner_lost, res[lane]["-/spike"].diner_lost) < b.diner_lost - BranchBench.SAME})
	return out

func test_1_grid() -> void:
	# The committed lanes' references (the Longbow levers do not touch these four configurations).
	var refs := {}
	for lane in LANES:
		refs[lane] = {}
		for cfg in CONFIGS:
			if cfg[0] == &"longbow":
				continue
			refs[lane][_cn(cfg)] = await _run(lane, cfg[0], cfg[1])
			gut.p("REF %s %s lost %.1f" % [lane, _cn(cfg), refs[lane][_cn(cfg)].diner_lost])
	for n in [1, 2]:
		for cfg in [[&"", &""], [&"volley", &""]]:
			gut.p("REF siege%d %s lost %.1f" % [n, _cn(cfg), (await _run(&"siege", cfg[0], cfg[1], {"brutes": n})).diner_lost])
	for cfg in [[&"", &""], [&"volley", &""]]:
		gut.p("REF boars %s lost %.1f" % [_cn(cfg), (await _run(&"neutral", cfg[0], cfg[1], {"boars_only": true})).diner_lost])
	var base_dmg: float = Balance.data.branches.longbow.damage
	for interval in _intervals():
		for pct in DAMAGE_PCT:
			for mult in MULTS:
				var ov := {"longbow_interval": interval, "longbow_damage": base_dmg * (1.0 + pct / 100.0), "longbow_brute_mult": mult}
				var res := {}
				for lane in LANES:
					res[lane] = refs[lane].duplicate()
					res[lane]["longbow/-"] = await _run(lane, &"longbow", &"", ov)
				var s1: Dictionary = await _run(&"siege", &"longbow", &"", ov.merged({"brutes": 1}))
				var s2: Dictionary = await _run(&"siege", &"longbow", &"", ov.merged({"brutes": 2}))
				var bo: Dictionary = await _run(&"neutral", &"longbow", &"", ov.merged({"boars_only": true}))
				var first := "-"
				var fails := 0
				for r in _rules(res):
					if not r.ok:
						fails += 1
						if first == "-":
							first = r.name
				gut.p("CAND %.1f %d %.1f | %.1f | %.1f | %.1f | %.1f | %.1f | %.1f | RULES %s %s" % [interval, pct, mult, res[&"siege"]["longbow/-"].diner_lost,
					res[&"hare"]["longbow/-"].diner_lost, res[&"neutral"]["longbow/-"].diner_lost, s1.diner_lost, s2.diner_lost, bo.diner_lost,
					"ok" if fails == 0 else "FAIL(%d)" % fails, first])
	pass_test("printed")
