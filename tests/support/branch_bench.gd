class_name BranchBench
extends RefCounted
## E6 Task 8 (spec 4.2, D-283, D-288, D-292): a micro-simulation of ONE lane at tier 3, for the rule "paying never makes it worse".
## Test support, not shipped. Everything fires through the REAL code: a real `Main`, the real `TowerSpot` / `Attacker` / `Projectile`,
## the real `FenceSpot`, `Boar` and `WaveDirector` (no arithmetic model of damage). Nothing in production is changed.
##
## WHAT IT IS NOT (D-292.1): it ranks branches RELATIVELY on one lane with one tower, one fence, no hero and no guards. It does not
## predict a real night; the real-play report (tests/sim/report_retune.gd) judges real outcomes.
##
## Choices of the world (all of them, so a later reader can check the measure is not polluted):
##  - Tier 3 (`debug_set_tier(3, 1)`), the shipped balance (D-307: no flag; the Longbow's 2.0 s and brute x2.0 and Spike's 24 are its own stats).
##  - ONE lane: `sw`, with `tower_sw` (the only tower that covers a single lane) and `fence_sw`, both bought to the top level through the
##    real payment API and then given the requested branch through `pay_into_branch`. Every other spot stays at level 0 (unbuilt).
##  - INVULNERABLE DINER (D-292.1), without a production hook: before the world exists `Balance.data.build.diner_max_hp` is raised in
##    memory to INVULNERABLE_HP (10 million; restored on return), so `new_game`/our reset give the diner that HP and the night can never
##    end the run by felling it. The measure is the SUM of the `amount` of every `EventBus.diner_damaged` emission (the real damage the
##    monsters dealt through `GameState.damage_diner`). All three waves always spawn and play out until no monster is alive.
##  - No hero influence: the hero is placed with the bus event `hero_place_requested` at (22, -22), the far north-east corner, 45 m from the
##    lane's spawn and 40 m from the diner. It is out of reach of every monster (attack range 4 m, monsters only walk the sw lane) and the steaks
##    drop on the sw lane, so it collects nothing; `player_control` is off so nothing moves it. No bot, no guards (GameState.guards is empty),
##    no cards, stations at level 0 and irrelevant (no travelers: the phase stays NIGHT).
##  - `phase_controller.failing = true`: the PhaseController then ignores `wave_cleared` and `diner_fell`, so the night does not run the dawn
##    (which would heal the diner and the fence before they are read) nor the fail-restore. The bench reads the state itself.
##  - The night: `wave_director.stop()` cancels the night the new game started, then `start_night(plan)` plays THREE waves with the sw lane as
##    the MAIN lane and no side lane, built from the real formulas (see `mix()`). GameState.lane_plan is set to the same plan, so Spike's
##    scaling by the night's HP multiplier (D-272.1) sees the same hp_mult the monsters have.
##  - Fixed run seed (71), day 1: the spawn offsets come from the real `spawns` stream, so two runs of one configuration are identical.
##
## Measures (read each tick from the signal, GameState and the live monsters):
##  - diner_lost    total diner HP lost over the whole run (sum of the diner_damaged amounts).
##  - fence_hp_left HP of fence_sw when the night ends (0 when it was destroyed).
##  - hares_in_zone distinct hares that were inside the sw attack zone (`MapLayout.zone_rect`, grown by 5 cm) at the end of any tick.
##  - clear_s       seconds from the tick of the first spawn until no monster is alive after the last wave spawned out.
##  - ticks         physics ticks simulated by the whole run, from the night's start (this includes the 5 s first-wave delay).
##  - kills         monsters killed (information).
##  - fence_fell_s  seconds from the first spawn to the tick the fence's HP first reached 0; -1 if it never fell.
##  - fence_absorbed the fence's HP lost over the run (start HP minus HP at the end; overkill is not counted).
##  - fence_stands_s how long the fence STANDS (D-294.6): fence_fell_s, or INF when the fence never fell (it stood for the whole run, whatever
##                  that run's length; INF compares equal to INF and above every finite time). Higher is better.
## `timed_out` is true when MAX_TICKS passed before the night cleared (clear_s is then MAX_TICKS / 60; expected never).

const SEED := 71
const PARK := Vector2(22, -22)
const MAX_TICKS := 60 * 600
const INVULNERABLE_HP := 1.0e7
const LANE := "sw"
const TOWER_ID := "tower_sw"
const FENCE_ID := "fence_sw"

# ---- the rules, shared by the unit-suite fast subset, the identity test and the full bench ---------------------------------------
const MARGIN := 0.15
const SAME := 0.001
const PRESSURE := 12
## The five single-change configurations [tower branch, fence branch], and their names ("-" = unbranched).
const FAST_CONFIGS: Array = [[&"", &""], [&"longbow", &""], [&"volley", &""], [&"", &"stone"], [&"", &"spike"]]
const LANES: Array[StringName] = [&"siege", &"hare", &"neutral"]
## The measures deciding a SPECIALIST rule: the first one on which the two differ (by more than SAME) decides, at the 15% margin.
const ORDER_SIEGE_TOWER := [["diner_lost", false], ["fence_hp_left", true]]
## D-294.6: the siege FENCE rule is decided by how long the fence stands (higher is better), diner HP lost breaking a tie.
const ORDER_SIEGE_FENCE := [["fence_stands_s", true], ["diner_lost", false]]
const ORDER_HARE := [["diner_lost", false], ["hares_in_zone", false], ["clear_s", false]]
## [lane, specialist [tower, fence], reference [tower, fence], name, order, the mutation that fails the rule]
const SPECIALISTS: Array = [
	[&"siege", [&"longbow", &""], [&"volley", &""], "Longbow over Volley", ORDER_SIEGE_TOWER, "Longbow damage 60 (longbow.damage = 60.0): siege lost 2835 against the bound"],
	[&"siege", [&"", &"stone"], [&"", &"spike"], "Stone over Spike (fence fall time)", ORDER_SIEGE_FENCE, "Stone wall HP 160 (stone.hp = 160.0; 320 still passes: it stands 31.23 s against Spike's 25.23 s)"],
	[&"hare", [&"volley", &""], [&"longbow", &""], "Volley over Longbow", ORDER_HARE, "Volley damage 5 (volley.damage = 5.0)"],
	[&"hare", [&"", &"spike"], [&"", &"stone"], "Spike over Stone", ORDER_HARE, "Spike pass damage 0 (spike.pass_damage = 0.0)"],
]

static func cfg_name(cfg: Array) -> String:
	return "%s/%s" % [cfg[0] if cfg[0] != &"" else &"-", cfg[1] if cfg[1] != &"" else &"-"]

## Equal within SAME; two infinities (a fence that never fell in both runs) are equal.
static func same(a: float, b: float) -> bool:
	if is_inf(a) or is_inf(b):
		return is_inf(a) and is_inf(b) and signf(a) == signf(b)
	return absf(a - b) <= SAME

## Does the specialist beat the reference by MARGIN on the first measure of `order` that separates them?
## {ok, measure, a, b, bound, why}. `margin` (default MARGIN): lower-is-better a <= (1 - margin) b; higher-is-better a >= (1 + margin) b (INF if b is INF; a reference of 0 is beaten by any positive a).
## If no measure separates them, ok is false.
static func beats_by_margin(spec: Dictionary, ref: Dictionary, order: Array, margin := MARGIN) -> Dictionary:
	for m in order:
		var name: String = m[0]
		var higher: bool = m[1]
		var a := float(spec[name])
		var b := float(ref[name])
		if same(a, b):
			continue
		var need := (1.0 + margin) * b if higher else (1.0 - margin) * b
		var ok: bool = a >= need if higher else a <= need
		return {"ok": ok, "measure": name, "a": a, "b": b, "bound": need,
			"why": "first separating measure %s: specialist %.2f vs reference %.2f (needs %s %.2f)" % [name, a, b, ">=" if higher else "<=", need]}
	return {"ok": false, "measure": "none", "a": 0.0, "b": 0.0, "bound": 0.0, "why": "no measure separates the two"}

# ---- E8 rules (spec 3.1, D-313.2, D-314.14): ON, OFF and NEUTRAL, as pure functions on result dictionaries -----------------------
## [rule, branch, lane, measure, higher, refs, order]. `refs` are cfg_name()s of the reference configurations: ON names the unbranched
## building and the other branch of its kind; OFF and NEUTRAL name unbranched. `order` is the tie-break order, primary measure first
## (ON only; OFF and NEUTRAL read the single `measure`). One row per line of spec 3.1: 4 ON, 3 OFF (the Stone wall has none, D-314.4), 4 NEUTRAL.
## The Stone wall's ON order: how long the fence stands, then diner HP lost, then fence HP left (spec 3.1 tie-breakers, D-314.17).
const ORDER_STONE_ON := [["fence_stands_s", true], ["diner_lost", false], ["fence_hp_left", true]]
const ORDER_SPIKE_ON := [["hares_in_zone", false], ["diner_lost", false], ["clear_s", false]]
const RULES: Array = [
	[&"ON", &"longbow", &"siege", "diner_lost", false, ["-/-", "volley/-"], ORDER_SIEGE_TOWER],
	[&"ON", &"volley", &"hare", "diner_lost", false, ["-/-", "longbow/-"], ORDER_HARE],
	[&"ON", &"stone", &"siege", "fence_stands_s", true, ["-/-", "-/spike"], ORDER_STONE_ON],
	[&"ON", &"spike", &"hare", "hares_in_zone", false, ["-/-", "-/stone"], ORDER_SPIKE_ON],
	[&"OFF", &"longbow", &"hare", "diner_lost", false, ["-/-"], []],
	[&"OFF", &"volley", &"siege", "diner_lost", false, ["-/-"], []],
	[&"OFF", &"spike", &"siege", "fence_stands_s", true, ["-/-"], []],
	[&"NEUTRAL", &"longbow", &"neutral", "diner_lost", false, ["-/-"], []],
	[&"NEUTRAL", &"volley", &"neutral", "diner_lost", false, ["-/-"], []],
	[&"NEUTRAL", &"stone", &"neutral", "diner_lost", false, ["-/-"], []],
	[&"NEUTRAL", &"spike", &"neutral", "diner_lost", false, ["-/-"], []],
]

static func _verdict(ok: bool, measure: String, a: float, b: float, bound: float, why: String) -> Dictionary:
	return {"ok": ok, "measure": measure, "a": a, "b": b, "bound": bound, "why": why}

## Is `x` strictly better than `y`? The first measure of `order` that separates them decides; tied on all -> false.
static func _better(x: Dictionary, y: Dictionary, order: Array) -> bool:
	for m in order:
		var name: String = m[0]
		if same(float(x[name]), float(y[name])):
			continue
		return float(x[name]) > float(y[name]) if m[1] else float(x[name]) < float(y[name])
	return false

## ON: ONE beats_by_margin call against the better reference on the primary measure (order[0]), at m_on. A tie on the primary measure
## fails unless a tie-breaker of `order` separates the runs in the specialist's favour (D-314.14).
static func on_rule(spec: Dictionary, refs: Array, order: Array) -> Dictionary:
	var best: Dictionary = refs[0]
	for r in refs:
		if _better(r, best, order):
			best = r
	return beats_by_margin(spec, best, order, float(Balance.data.branches.bench_m_on))

## OFF: the branch is worse than unbranched by m_off. L: a >= (1 + m_off) u + a_floor. H: a <= (1 - m_off) u.
## Both runs INF, or both 0, fail (D-314.14).
static func off_rule(spec: Dictionary, unbranched: Dictionary, measure: String, higher: bool) -> Dictionary:
	var a := float(spec[measure])
	var u := float(unbranched[measure])
	var m := float(Balance.data.branches.bench_m_off)
	var floor_hp := float(Balance.data.branches.bench_a_floor)
	if same(a, u) and (is_inf(a) or absf(a) <= SAME):
		return _verdict(false, measure, a, u, u, "%s ties with unbranched (%s vs %s): no off-lane cost" % [measure, a, u])
	var bound := (1.0 - m) * u if higher else (1.0 + m) * u + floor_hp
	var ok: bool = a <= bound if higher else a >= bound
	return _verdict(ok, measure, a, u, bound, "%s: branch %.2f vs unbranched %.2f (needs %s %.2f)" % [measure, a, u, "<=" if higher else ">=", bound])

## NEUTRAL (one-sided): diner HP lost <= (1 + m_neu) x unbranched + a_floor. Far better than unbranched passes.
static func neutral_rule(spec: Dictionary, unbranched: Dictionary) -> Dictionary:
	var a := float(spec["diner_lost"])
	var u := float(unbranched["diner_lost"])
	var bound := (1.0 + float(Balance.data.branches.bench_m_neu)) * u + float(Balance.data.branches.bench_a_floor)
	return _verdict(a <= bound, "diner_lost", a, u, bound, "diner_lost: branch %.2f vs unbranched %.2f (needs <= %.2f)" % [a, u, bound])

## The cfg_name of a branch alone on its building ("longbow" -> "longbow/-", "stone" -> "-/stone").
static func branch_cfg(branch: StringName) -> String:
	return "%s/-" % branch if branch in [&"longbow", &"volley"] else "-/%s" % branch

## The verdict of one RULES row over the results of its lane (cfg_name -> run): {ok, measure, a, b, bound, why}.
static func rule_verdict(row: Array, lane_res: Dictionary) -> Dictionary:
	var spec: Dictionary = lane_res[branch_cfg(row[1])]
	match row[0]:
		&"ON":
			var refs: Array = []
			for r in row[5]:
				refs.append(lane_res[r])
			return on_rule(spec, refs, row[6])
		&"OFF":
			return off_rule(spec, lane_res[row[5][0]], row[3], row[4])
	return neutral_rule(spec, lane_res[row[5][0]])

## The comparison the branch's number must satisfy against the bound, for display.
static func rule_op(row: Array) -> String:
	match row[0]:
		&"ON":
			return ">=" if row[4] else "<="
		&"OFF":
			return "<=" if row[4] else ">="
	return "<="

static func rule_name(row: Array) -> String:
	return "%s %s" % [row[0], row[1]]

## The verdicts of every RULES row over `res` (lane -> cfg_name -> run): [{name, lane, ...verdict}].
static func rule_verdicts(res: Dictionary) -> Array:
	var out: Array = []
	for row in RULES:
		var v := rule_verdict(row, res[row[2]])
		v["name"] = rule_name(row)
		v["lane"] = row[2]
		out.append(v)
	return out

## E8 (A4): the mutation that turns each RULE red under the shipped (E8) values. Key "<rule> <branch>"; each value is the BranchBench.run override (or in-memory
## balance edit) and the numbers it gives. WHERE SEEN RED: every row was applied at p12 on the FULL 3-wave night (the numbers quoted below are those runs, a
## scratch harness over the shared rule functions) AND through the fast subset (BranchBench.fast_results(): last wave only, p12; OFF Spike on the whole night),
## where each one turned its own rule red (and its SPECIALIST / IDENTITY twin where one exists). Not run through the CI bench file itself with the mutation in place.
const RULE_FAILS_WHEN := {
	"ON longbow": "Longbow damage 60 (longbow.damage = 60.0): siege lost 2835 against the bound 1513 (p12, 3 waves)",
	"ON volley": "Volley damage 5 (volley.damage = 5.0): hare lost 2867 against the bound 1439",
	"ON stone": "Stone wall HP 160 (stone.hp = 160.0): the fence stands 25.18 s against the bound 32.47 s",
	"ON spike": "Spike pass damage 0 (spike.pass_damage = 0.0): hares_in_zone ties with the Stone wall's, so the deciding measure is diner_lost: 1275 against the bound 1151.75 on the hare lane",
	"OFF longbow": "Longbow hare multiplier 1.0 (override longbow_hare_mult = 1.0): hare lost 828 against the bound 1882",
	"OFF volley": "Volley brute multiplier 1.0 (override volley_brute_mult = 1.0): siege lost 706 against the bound 1978",
	"OFF spike": "Spike brute multiplier 1.0 (override spike_brute_mult = 1.0): the fence stands 30.23 s against the bound 25.41 s",
	"NEUTRAL longbow": "Longbow damage 30 (longbow.damage = 30.0): neutral lost 4828 against the bound 664",
	"NEUTRAL volley": "Volley damage 5 (volley.damage = 5.0): neutral lost 1291 against the bound 664",
	"NEUTRAL stone": "Stone wall HP 160 (stone.hp = 160.0): neutral lost 690 against the bound 664",
	"NEUTRAL spike": "Spike takes 10 x from boars and hares (damage_taken_mult_by_kind[boar] = [hare] = 10.0): neutral lost 775 against the bound 664 (the purchase keeps the level-3 HP, so an HP value cannot fail this row)",
}
## The mutation that turns each IDENTITY rule red under the E8 values. Seen red through the fast subset (last wave, p12) and on the full 3-wave night (p12), by the same
## scratch harness as RULE_FAILS_WHEN; not run through the CI test files with the mutation in place.
const IDENTITY_FAILS_WHEN := {
	"longbow_siege": "Longbow damage 60 (longbow.damage = 60.0)",
	"volley_hare": "Volley damage 5 (volley.damage = 5.0)",
	"stone_stands": "Stone wall HP 160 (stone.hp = 160.0): stands 25.18 s against Spike's 25.23 s",
	"spike_hares": "Spike pass damage 0 (spike.pass_damage = 0.0)",
}

## D-294.6, the siege FENCE rule, in ONE place: Stone beats Spike by the margin on how long the fence STANDS (higher is better, a fence that
## never falls is INF), diner HP lost breaking a tie. {ok, measure, a, b, bound, why}. Used by the fast file, the full bench and the report.
static func stone_over_spike(stone: Dictionary, spike: Dictionary) -> Dictionary:
	return beats_by_margin(stone, spike, ORDER_SIEGE_FENCE)

## The verdict of one SPECIALISTS row; the Stone-over-Spike row goes through stone_over_spike().
static func specialist_verdict(row: Array, spec: Dictionary, ref: Dictionary) -> Dictionary:
	if row[4] == ORDER_SIEGE_FENCE:
		return stone_over_spike(spec, ref)
	return beats_by_margin(spec, ref, row[4])

## IDENTITY (spec 4.3 restated, D-294.6). Each takes the results of one lane type (cfg_name -> run) and returns {ok, why}.
static func identity_longbow_siege(siege: Dictionary) -> Dictionary:
	var lb := float(siege["longbow/-"].diner_lost)
	var base := float(siege["-/-"].diner_lost)
	var vol := float(siege["volley/-"].diner_lost)
	return {"ok": lb < base - SAME and lb < vol - SAME,
		"why": "siege: Longbow %.1f loses least diner HP of unbranched %.1f / Volley %.1f" % [lb, base, vol]}

static func identity_volley_hare(hare: Dictionary) -> Dictionary:
	var vy := float(hare["volley/-"].diner_lost)
	var base := float(hare["-/-"].diner_lost)
	var lb := float(hare["longbow/-"].diner_lost)
	return {"ok": vy < base - SAME and vy < lb - SAME,
		"why": "hare: Volley %.1f loses least diner HP of unbranched %.1f / Longbow %.1f" % [vy, base, lb]}

static func identity_stone_stands_longest(siege: Dictionary) -> Dictionary:
	var st := float(siege["-/stone"].fence_stands_s)
	var base := float(siege["-/-"].fence_stands_s)
	var sp := float(siege["-/spike"].fence_stands_s)
	return {"ok": st > base and st > sp,
		"why": "siege: Stone's fence stands %.2f s vs unbranched %.2f s / Spike %.2f s" % [st, base, sp]}

static func identity_spike_fewest_hares(hare: Dictionary) -> Dictionary:
	var sp := int(hare["-/spike"].hares_in_zone)
	var base := int(hare["-/-"].hares_in_zone)
	var st := int(hare["-/stone"].hares_in_zone)
	return {"ok": sp < base and sp < st,
		"why": "hare: Spike lets %d hares reach the zone vs unbranched %d / Stone %d" % [sp, base, st]}

## Rules the fast subset judges on the whole night (`fast_results()["siege_full"]`, 2 more runs), see fast_results().
const FULL_NIGHT_RULES: Array[String] = ["OFF spike"]

## The FAST subset's results (pressure 12, the LAST wave of each mix only, the five single-change configurations on all
## three lane types: 15 runs, plus the two whole-night siege runs of FULL_NIGHT_RULES), computed once per process and cached: lane -> cfg_name -> run result. The identity test reuses it.
static var _fast := {}

## The cached results, for synchronous code after `await fast_results()` has run (empty before).
static func fast_cached() -> Dictionary:
	return _fast

static func fast_results() -> Dictionary:
	if not _fast.is_empty():
		return _fast
	Balance.reset()
	var out := {}
	for lane in LANES:
		out[lane] = {}
		for cfg in FAST_CONFIGS:
			out[lane][cfg_name(cfg)] = await run(lane, cfg[0], cfg[1], PRESSURE, {"last_wave_only": true})
	# OFF Spike (siege) is judged on the WHOLE night: in the last wave alone the fence falls to the boars and Spike's thorns keep it up longer than
	# the unbranched fence at any brute multiplier (measured at 4.0, 5.0, 6.0, 8.0: 25.78 s against 23.38 s), so the last wave cannot show the rule.
	out["siege_full"] = {}
	for cfg in [[&"", &""], [&"", &"spike"]]:
		out["siege_full"][cfg_name(cfg)] = await run(&"siege", cfg[0], cfg[1], PRESSURE)
	Balance.reset()
	_fast = out
	return _fast

## The three waves of the lane type at `pressure`, from WaveMath / TierEffects, with the tier-3 hare share.
## Per wave: {boars, hares, brutes, hp_mult}.
##  - boars: the non-hare part of the wave's MAIN group (`WaveMath.split(...).main - fast_main`); the group count includes its hares.
##  - hares: HARE lane: round(hare_lane_share x all the wave's hares). NEUTRAL and SIEGE lane: the MAIN group's share of the leftover:
##           round((H - round(share x H)) x fast_main / H), with H = fast_main + fast_side.
##  - brutes: SIEGE lane: brute_cap_main[3] on every wave (full ramp); 0 otherwise.
## `brutes` (sensitivity tables only, default -1 = all waves): how many of the night's waves, counted from the LAST one, carry the siege lane's brute
## (TierEffects.brute_counts: a tier-3 night has 1 brute on its first night, 2 on its second, 3 from the third; brute_cap_main[3] is 1 per wave).
## `boars_only` (default false): every hare of the mix is a boar instead (same monster count), the "plain boar lane" of the Longbow study.
static func mix(lane_type: StringName, pressure: int, brutes := -1, boars_only := false) -> Array:
	var wb: WaveBalance = Balance.data.wave
	var tb: TierBalance = Balance.data.tiers
	var share: float = tb.hare_lane_share
	var out: Array = []
	for w in wb.base_counts.size():
		var sp := WaveMath.split(pressure, w, wb)
		var fast := TierEffects.fast_counts(int(sp.main), int(sp.side), tb.fast_share[3])
		var h_total := int(fast.fast_main) + int(fast.fast_side)
		var on_hare_lane := int(round(share * h_total))
		var hares := 0
		match lane_type:
			LaneCharacter.HARE:
				hares = on_hare_lane
			_:
				hares = int(round(float(h_total - on_hare_lane) * float(fast.fast_main) / float(h_total))) if h_total > 0 else 0
		var boars := int(sp.main) - int(fast.fast_main)
		if boars_only:
			boars += hares
			hares = 0
		var carries := brutes < 0 or w >= wb.base_counts.size() - brutes
		var n_brutes: int = tb.brute_cap_main[3] if carries else 0
		out.append({
			"boars": boars, "hares": hares,
			"brutes": n_brutes if lane_type == LaneCharacter.SIEGE else 0,
			"hp_mult": WaveMath.hp_mult(pressure, w, wb),
		})
	return out

static func plan_for(lane_type: StringName, pressure: int, brutes := -1, boars_only := false) -> Array:
	var waves: Array = []
	for m in mix(lane_type, pressure, brutes, boars_only):
		waves.append({
			"main": LANE, "side": "", "main_count": int(m.boars) + int(m.hares), "side_count": 0, "hp_mult": float(m.hp_mult),
			"fast_main": int(m.hares), "fast_side": 0, "boss": false, "brute_main": int(m.brutes), "brute_side": 0,
		})
	return waves

## `overrides` (sensitivity tables only), applied in memory before the world exists and undone on return:
## longbow_brute_mult, longbow_hare_mult, volley_brute_mult, spike_brute_mult, longbow_damage, longbow_interval (sets the RETUNE field), longbow_range, spike_pass, spike_thorn, stone_brute_mult, stone_hp (all floats), and
## brutes (int, siege lane: how many waves from the last carry a brute, see mix()), boars_only (bool: no hares, see mix()), last_wave_only (bool: the director plays only the LAST wave of the mix; GameState.lane_plan keeps the full plan so Spike's scale is unchanged).
## `&""` as a branch = unbranched.
static func run(lane_type: StringName, tower_branch: StringName, fence_branch: StringName, pressure: int, overrides := {}) -> Dictionary:
	var tree := Engine.get_main_loop() as SceneTree
	var bb: BranchBalance = Balance.data.branches
	var saved := {
		"mult": bb.longbow.kind_mults.duplicate(), "pass": bb.spike.pass_damage, "thorn": bb.spike.thorn_damage,
		"dmg": bb.longbow.damage, "int": bb.longbow.interval, "rng": bb.longbow.attack_range,
		"vmult": bb.volley.kind_mults.duplicate(), "spike_mult": bb.spike.damage_taken_mult_by_kind.duplicate(),
		"diner": Balance.data.build.diner_max_hp, "stone_mult": bb.stone.damage_taken_mult_by_kind.duplicate(), "stone_hp": bb.stone.hp,
	}
	if overrides.has("longbow_brute_mult"):
		bb.longbow.kind_mults[&"brute"] = float(overrides.longbow_brute_mult)
	if overrides.has("longbow_hare_mult"):
		bb.longbow.kind_mults[&"hare"] = float(overrides.longbow_hare_mult)
	if overrides.has("volley_brute_mult"):
		bb.volley.kind_mults[&"brute"] = float(overrides.volley_brute_mult)
	if overrides.has("spike_brute_mult"):
		bb.spike.damage_taken_mult_by_kind[&"brute"] = float(overrides.spike_brute_mult)
	if overrides.has("longbow_damage"):
		bb.longbow.damage = float(overrides.longbow_damage)
	if overrides.has("longbow_interval"):
		bb.longbow.interval = float(overrides.longbow_interval)
	if overrides.has("longbow_range"):
		bb.longbow.attack_range = float(overrides.longbow_range)
	if overrides.has("spike_pass"):
		bb.spike.pass_damage = float(overrides.spike_pass)
	if overrides.has("spike_thorn"):
		bb.spike.thorn_damage = float(overrides.spike_thorn)
	if overrides.has("stone_brute_mult"):
		bb.stone.damage_taken_mult_by_kind[&"brute"] = float(overrides.stone_brute_mult)
	if overrides.has("stone_hp"):
		bb.stone.hp = float(overrides.stone_hp)
	Balance.data.build.diner_max_hp = INVULNERABLE_HP
	var plan := plan_for(lane_type, pressure, int(overrides.get("brutes", -1)), bool(overrides.get("boars_only", false)))

	var main := Main.create()
	tree.root.add_child(main)
	main.hero.input.player_control = false
	main.phase_controller.start_new_game(SEED)
	await tree.physics_frame
	main.phase_controller.wave_director.stop()
	main.phase_controller.failing = true
	GameState.debug_set_tier(3, 1)
	main.world.rebuild_for_tier()
	EventBus.hero_place_requested.emit(PARK)
	GameState.gold = 1000000
	for id in [TOWER_ID, FENCE_ID]:
		var guard := 0
		while GameState.next_level_cost(id) >= 0 and guard < 10:
			GameState.pay_into_spot(id, 1000000)
			guard += 1
	if tower_branch != &"":
		GameState.pay_into_branch(TOWER_ID, tower_branch, 1000000)
	if fence_branch != &"":
		GameState.pay_into_branch(FENCE_ID, fence_branch, 1000000)
	GameState.gold = 0
	GameState.diner_hp = INVULNERABLE_HP
	GameState.lane_plan = plan
	var played: Array = [plan[plan.size() - 1]] if overrides.get("last_wave_only", false) else plan
	var fence_start := float(GameState.buildings[FENCE_ID].hp)
	var fence_fell_tick := -1
	var wd: WaveDirector = main.phase_controller.wave_director
	var zone := MapLayout.zone_rect(LANE).grow(0.05)
	var seen := {}
	var lost := [0.0]
	var kills := [0]
	var on_hit := func(amount: float, _hp_left: float): lost[0] += amount
	var on_kill := func(_i: int, _l: StringName, _p: Vector3, _k: StringName): kills[0] += 1
	EventBus.diner_damaged.connect(on_hit)
	EventBus.enemy_killed.connect(on_kill)
	var ticks := 0
	var first_spawn_tick := -1
	var end_tick := -1
	wd.start_night(played)
	while ticks < MAX_TICKS:
		await tree.physics_frame
		ticks += 1
		var alive := wd.alive_enemies()
		if first_spawn_tick < 0 and not alive.is_empty():
			first_spawn_tick = ticks
		for e in alive:
			var b: Boar = e
			if b.kind == &"hare" and not seen.has(b.spawn_index) and zone.has_point(Vector2(b.global_position.x, b.global_position.z)):
				seen[b.spawn_index] = true
		if first_spawn_tick >= 0 and fence_fell_tick < 0 and float(GameState.buildings[FENCE_ID].hp) <= 0.0:
			fence_fell_tick = ticks
		if first_spawn_tick >= 0 and wd.wave_index == played.size() - 1 and wd.state == WaveDirector.State.IDLE and alive.is_empty():
			end_tick = ticks
			break
	var result := {
		"diner_lost": lost[0],
		"fence_hp_left": float(GameState.buildings[FENCE_ID].hp),
		"hares_in_zone": seen.size(),
		"clear_s": float(end_tick - first_spawn_tick) / 60.0 if end_tick >= 0 else float(MAX_TICKS) / 60.0,
		"ticks": ticks, "kills": kills[0], "timed_out": end_tick < 0,
		"fence_fell_s": float(fence_fell_tick - first_spawn_tick) / 60.0 if fence_fell_tick >= 0 else -1.0,
		"fence_absorbed": fence_start - float(GameState.buildings[FENCE_ID].hp),
		"fence_stands_s": float(fence_fell_tick - first_spawn_tick) / 60.0 if fence_fell_tick >= 0 else INF,
	}
	EventBus.diner_damaged.disconnect(on_hit)
	EventBus.enemy_killed.disconnect(on_kill)
	wd.stop()
	tree.root.remove_child(main)
	main.free()
	bb.longbow.kind_mults = saved.mult
	bb.volley.kind_mults = saved.vmult
	bb.spike.damage_taken_mult_by_kind = saved.spike_mult
	bb.spike.pass_damage = saved["pass"]
	bb.spike.thorn_damage = saved.thorn
	bb.longbow.damage = saved.dmg
	bb.longbow.interval = saved["int"]
	bb.longbow.attack_range = saved.rng
	bb.stone.damage_taken_mult_by_kind = saved.stone_mult
	bb.stone.hp = saved.stone_hp
	Balance.data.build.diner_max_hp = saved.diner
	return result
