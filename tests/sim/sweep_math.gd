class_name SweepMath
extends RefCounted
## Pure helpers of the manual sweep (tests/sim/sweep_runner.gd). Plain arrays in, numbers out; no autoloads.

## Monsters a night's plan sends: main plus side counts of every wave, plus 1 for the boss wave (E5 spec 8.3).
static func enemy_count(plan: Array) -> int:
	var n := 0
	for w in plan:
		n += int(w.main_count) + int(w.side_count)
		if bool(w.get("boss", false)):
			n += 1
	return n

## `nights`: one Dictionary per night played: {day, tier, boss_night, retries, at_cap} (tier and at_cap read at the
## night's start). Returns first_tier2_day (-1 if never), boss_retries, cap_nights, cap_retries (the TIER line, rule 4).
static func tier_summary(nights: Array) -> Dictionary:
	var out := {"first_tier2_day": -1, "boss_retries": 0, "cap_nights": 0, "cap_retries": 0}
	for n in nights:
		if int(n.tier) >= 2 and int(out.first_tier2_day) < 0:
			out.first_tier2_day = int(n.day)
		if bool(n.boss_night):
			out.boss_retries += int(n.retries)
		if bool(n.at_cap):
			out.cap_nights += 1
			out.cap_retries += int(n.retries)
	return out

## Tier-3 facts of one tier-bot run (the T3RUN line, the policy report). `nights`: one Dictionary per night played, from the sweep:
## {tier, tier_close (optional, default tier), retries, frac, fences_lost, branches, branch_gold}. `tier` = the tier at the night's start; `tier_close` = the tier at
## the day's close-up (the Baron's night starts at tier 2 and closes at tier 3). nights, retry_nights, min, median, mean and fences_lost_mean count the nights that
## STARTED at tier >= 3 (frac = the final attempt's lowest diner HP fraction, a failed night included as played); branches and branch_gold count every row that CLOSED at
## tier >= 3, so the tier-3 dawn day's purchases are in. Empty set: every number 0.
static func tier3_stats(nights: Array) -> Dictionary:
	var out := {"nights": 0, "retry_nights": 0, "min": 0.0, "median": 0.0, "mean": 0.0, "fences_lost_mean": 0.0, "branches": 0, "branch_gold": 0}
	var fracs: Array = []
	var lost := 0
	for n in nights:
		if int(n.get("tier_close", n.tier)) >= 3:
			out.branches += int(n.branches)
			out.branch_gold += int(n.branch_gold)
		if int(n.tier) < 3:
			continue
		fracs.append(float(n.frac))
		lost += int(n.fences_lost)
		out.retry_nights += 1 if int(n.retries) > 0 else 0
	out.nights = fracs.size()
	if fracs.is_empty():
		return out
	var sum := 0.0
	for f in fracs:
		sum += float(f)
	out.min = ReportMath.percentile(fracs, 0.0)
	out.median = ReportMath.median(fracs)
	out.mean = sum / fracs.size()
	out.fences_lost_mean = float(lost) / fracs.size()
	return out

## True when nothing purchasable remains at tier 3: every spot at `max_level`, every tower and fence branched, every station at
## `station_max`. `spots`: {kind, level, branch} per spot of the tier; `station_levels`: the stations' levels. No spots = not done.
## `need_branches` false (the `unbranched` policy, E6): branches are not part of what it can buy, so levels and stations are everything.
static func ladder_done(spots: Array, station_levels: Array, max_level: int, station_max: int, need_branches := true) -> bool:
	if spots.is_empty():
		return false
	for s in spots:
		if int(s.level) < max_level:
			return false
		if need_branches and String(s.kind) in ["tower", "fence"] and String(s.branch) == "":
			return false
	for l in station_levels:
		if int(l) < station_max:
			return false
	return true

## The LADDER line's numbers (see tests/sim/sweep_runner.gd header). Days are ROW numbers of the sweep (row N = the night that starts day N's loop pass, then
## the day phase that follows it). `plot_day` = the row whose day phase paid the tier-3 sign (-1 never). `days`: one Dictionary per row closed, in order:
## {day, tier, at_cap3, income, rebuild, rebranch, unspent, done}; tier = the tier AT CLOSE-UP (the Baron night's row closes at tier 3); at_cap3 = a tier-3 night
## at the cap; income = gold the day's sales paid; rebuild / rebranch = gold paid that day to rebuild fences that fell / to re-buy the branch they had lost;
## unspent = gold at close-up; done = ladder_done() at close-up.
## ladder_done_day = the first done row (-1 never); t3_days_to_done = the closed rows with tier >= 3 up to and including it (-1 when never);
## max_unspent_during_ladder = the largest unspent over the rows with tier >= 3 up to and including ladder_done_day (every such row when -1);
## max_unspent_while_purchasable = the same without the done row itself (something was still to buy); the medians run over the at_cap3 rows (0 when none);
## fence_rebuild_gold_median_at_cap is the median of rebuild + rebranch per row.
static func ladder_summary(plot_day: int, days: Array) -> Dictionary:
	var done_day := -1
	for d in days:
		if bool(d.done):
			done_day = int(d.day)
			break
	var max_unspent := 0
	var max_buying := 0
	var t3_days := 0
	var total: Array = []
	var rebuild: Array = []
	var rebranch: Array = []
	var income: Array = []
	for d in days:
		if int(d.tier) >= 3 and (done_day < 0 or int(d.day) <= done_day):
			max_unspent = maxi(max_unspent, int(d.unspent))
			t3_days += 1
			if int(d.day) != done_day:
				max_buying = maxi(max_buying, int(d.unspent))
		if bool(d.at_cap3):
			total.append(int(d.rebuild) + int(d.rebranch))
			rebuild.append(int(d.rebuild))
			rebranch.append(int(d.rebranch))
			income.append(int(d.income))
	return {"plot_day": plot_day, "ladder_done_day": done_day, "t3_days_to_done": t3_days if done_day >= 0 else -1,
		"max_unspent_during_ladder": max_unspent, "max_unspent_while_purchasable": max_buying,
		"fence_rebuild_gold_median_at_cap": int(round(ReportMath.median(total))), "rebuild_median": int(round(ReportMath.median(rebuild))),
		"rebranch_median": int(round(ReportMath.median(rebranch))), "income_at_cap": int(round(ReportMath.median(income)))}

## The spec's unspent target (section 8: at most 650 from the tier-3 dawn until the ladder completes). N/A when the ladder did not complete within the run.
static func unspent_target_line(ls: Dictionary) -> String:
	var done := int(ls.ladder_done_day) >= 0
	var verdict := "N/A" if not done else ("PASS" if int(ls.max_unspent_during_ladder) <= 650 else "FAIL")
	return "UNSPENT_TARGET: %s (max_unspent_during_ladder %d, max_unspent_while_purchasable %d, limit 650, ladder %s)" % [verdict, ls.max_unspent_during_ladder,
		ls.max_unspent_while_purchasable, "complete" if done else "incomplete"]

## The review-queue flag "brutes make fences a tax" (spec section 8): the median fence rebuild gold at the cap above 30% of the median income there. N/A without cap days.
static func fence_tax_line(ls: Dictionary) -> String:
	if int(ls.income_at_cap) <= 0:
		return "FENCE_TAX: N/A (no tier-3 cap day)"
	var share := 100.0 * float(ls.fence_rebuild_gold_median_at_cap) / float(ls.income_at_cap)
	return "FENCE_TAX: %s (share %.1f%%, threshold 30, rebuild %d, rebranch %d, median total %d of income %d)" % ["yes" if share > 30.0 else "no", share, ls.rebuild_median,
		ls.rebranch_median, ls.fence_rebuild_gold_median_at_cap, ls.income_at_cap]

## The policy report's summary. `runs`: {policy, mean_frac, retry_nights, fences_lost_mean (optional), branch_gold (optional)} per run. `only` (optional) limits it to
## those policies. Per policy: the mean over its runs of mean_frac in points (percent of the diner's maximum HP), the sum of retry_nights, and the means of
## fences_lost_mean and branch_gold. Best first; equal points keep the order of first appearance. gap = best minus worst, in points.
static func policy_ranking(runs: Array, only := []) -> Dictionary:
	var order: Array = []
	var sums := {}
	var counts := {}
	var retries := {}
	var lost := {}
	var gold := {}
	for r in runs:
		var p := String(r.policy)
		if not only.is_empty() and not p in only:
			continue
		if not sums.has(p):
			order.append(p)
			sums[p] = 0.0
			counts[p] = 0
			retries[p] = 0
			lost[p] = 0.0
			gold[p] = 0.0
		sums[p] = float(sums[p]) + float(r.mean_frac) * 100.0
		counts[p] = int(counts[p]) + 1
		retries[p] = int(retries[p]) + int(r.retry_nights)
		lost[p] = float(lost[p]) + float(r.get("fences_lost_mean", 0.0))
		gold[p] = float(gold[p]) + float(r.get("branch_gold", 0.0))
	var rows: Array = []
	for p in order:
		rows.append({"policy": p, "points": float(sums[p]) / int(counts[p]), "retry_nights": int(retries[p]), "fences_lost": float(lost[p]) / int(counts[p]),
			"branch_gold": float(gold[p]) / int(counts[p])})
	var idx := {}
	for i in order.size():
		idx[order[i]] = i
	rows.sort_custom(func(a, b): return a.points > b.points or (a.points == b.points and idx[a.policy] < idx[b.policy]))
	var gap := 0.0 if rows.is_empty() else float(rows[0].points) - float(rows[rows.size() - 1].points)
	return {"rows": rows, "gap": gap}

## `DOMINANT_BRANCH` style line (spec 9.2): a gap above 15 points is a possible dominant branch (exactly 15 is not).
static func dominant_line(label: String, ranking: Dictionary) -> String:
	var gap := float(ranking.gap)
	return "%s: %s (gap %.1f points, threshold 15)" % [label, "yes" if gap > 15.0 else "no", gap]

## THREAT_BEST over the spec's four policies (the report-only fifth is ignored). `runs`: {policy, seed, mean_frac}. The threat policy is compared with the best OTHER policy by
## mean points; diff = threat minus it, per seed and in mean. `tie` when the mean difference is under 2 points in size or the per-seed signs differ; else yes (threat ahead) or no.
static func threat_verdict(runs: Array, spec_policies: Array) -> String:
	var rank := policy_ranking(runs, spec_policies)
	var threat := -1.0
	var other := {}
	for r in rank.rows:
		if r.policy == "threat":
			threat = float(r.points)
		elif other.is_empty():
			other = r
	if threat < 0.0 or other.is_empty():
		return "THREAT_BEST: N/A (needs the threat policy and one other)"
	var diffs: Array = []
	for r in runs:
		if r.policy != "threat":
			continue
		for o in runs:
			if o.policy == other.policy and int(o.seed) == int(r.seed):
				diffs.append((float(r.mean_frac) - float(o.mean_frac)) * 100.0)
	var sum := 0.0
	var pos := false
	var neg := false
	for d in diffs:
		sum += float(d)
		pos = pos or float(d) > 0.0
		neg = neg or float(d) < 0.0
	var mean_d := sum / maxf(diffs.size(), 1)
	var verdict := "tie" if (absf(mean_d) < 2.0 or (pos and neg)) else ("yes" if mean_d > 0.0 else "no")
	return "THREAT_BEST: %s (threat %.1f, best other %s %.1f, mean difference %+.1f, per seed %s)" % [verdict, threat, other.policy, float(other.points), mean_d,
		" ".join(diffs.map(func(d): return "%+.1f" % d))]

## The 2 x 2 table of the report: tower branch (Longbow | Volley) x fence branch (Stone | Spike), from the policies all_a (Longbow, Stone), mixed (Longbow, Spike),
## volley_stone and all_b (Volley, Spike). `runs`: {policy, seed, mean_frac}. Returns {} when a cell has no run. cells[key] = {points, per_seed: [[seed, points]]}.
## tower_effect = Volley minus Longbow averaged over the fences; fence_effect = Stone minus Spike averaged over the towers;
## interaction = (Volley minus Longbow with Spike) minus (Volley minus Longbow with Stone).
const CELLS := {"longbow_stone": "all_a", "longbow_spike": "mixed", "volley_stone": "volley_stone", "volley_spike": "all_b"}
static func two_by_two(runs: Array) -> Dictionary:
	var cells := {}
	for key in CELLS:
		var per: Array = []
		var sum := 0.0
		for r in runs:
			if r.policy == CELLS[key]:
				per.append([int(r.seed), float(r.mean_frac) * 100.0])
				sum += float(r.mean_frac) * 100.0
		if per.is_empty():
			return {}
		cells[key] = {"points": sum / per.size(), "per_seed": per}
	var p := func(k): return float(cells[k].points)
	return {"cells": cells,
		"tower_effect": (p.call("volley_stone") + p.call("volley_spike")) / 2.0 - (p.call("longbow_stone") + p.call("longbow_spike")) / 2.0,
		"fence_effect": (p.call("longbow_stone") + p.call("volley_stone")) / 2.0 - (p.call("longbow_spike") + p.call("volley_spike")) / 2.0,
		"interaction": (p.call("volley_spike") - p.call("longbow_spike")) - (p.call("volley_stone") - p.call("longbow_stone"))}


# --- E6 Task 16: the retune report (tests/sim/report_retune.gd, spec 8.1, D-285, D-290, D-294) ---

const SIEGE_LANES := ["east", "sw", "west", "north"]
## The seed sets, pinned as literals (D-285). The rule: scan seeds upward from 1; a seed belongs to the lane `LaneCharacter.for_run(seed).siege`; per lane the first seed is
## the tuning set, the next two are hold-out set #1, the two after those hold-out set #2. report_retune.gd asserts the scan still gives exactly these.
const TUNING_SET := {"east": [1], "sw": [3], "west": [4], "north": [7]}
const HOLDOUT_SET_1 := {"east": [2, 5], "sw": [10, 12], "west": [6, 13], "north": [9, 14]}
const HOLDOUT_SET_2 := {"east": [8, 11], "sw": [21, 23], "west": [18, 25], "north": [16, 19]}
const FIXED_PAIRS := ["all_a", "all_b", "mixed", "volley_stone"]
const RETUNE_POLICIES := ["all_a", "all_b", "mixed", "volley_stone", "threat", "unbranched"]
## Policies whose towers are Longbow on the siege lane (all_a, mixed: every tower; threat: the tower covering the siege lane, spec 4.4).
const LONGBOW_POLICIES := ["all_a", "mixed", "threat"]
const EPS := 1e-9

## The scan. `siege_of`: Callable(seed) -> siege lane name. Returns {tuning, holdout1, holdout2}, each {lane: [seeds]} in scan order.
static func seed_scan(siege_of: Callable, lanes: Array, per_lane := 5, start := 1) -> Dictionary:
	var found := {}
	for l in lanes:
		found[l] = []
	var s := start
	var guard := 0
	while guard < 100000:
		var lane := String(siege_of.call(s))
		if found.has(lane) and found[lane].size() < per_lane:
			found[lane].append(s)
		var full := true
		for l in lanes:
			full = full and found[l].size() >= per_lane
		if full:
			break
		s += 1
		guard += 1
	var out := {"tuning": {}, "holdout1": {}, "holdout2": {}}
	for l in lanes:
		out.tuning[l] = found[l].slice(0, 1)
		out.holdout1[l] = found[l].slice(1, 3)
		out.holdout2[l] = found[l].slice(3, 5)
	return out

## The seeds of a set, lane order of SIEGE_LANES, scan order inside a lane.
static func set_seeds(set: Dictionary) -> Array:
	var out: Array = []
	for l in SIEGE_LANES:
		out.append_array(set.get(l, []))
	return out

static func seed_lane(set: Dictionary, seed: int) -> String:
	for l in set:
		if seed in set[l]:
			return String(l)
	return ""

## The set the report runs: "tuning", "1" or "2" -> its dictionary ({} for anything else).
static func set_by_id(set_id: String) -> Dictionary:
	return {"tuning": TUNING_SET, "1": HOLDOUT_SET_1, "2": HOLDOUT_SET_2}.get(set_id, {})

## D-290: hold-out sets run only with --final, and every such run records its commit and set number. `record`: the earlier runs {set id: [{commit}]}
## (tests/sim/out/retune_final.json). Returns {allowed, lines, record}: the header lines, and the record with this run appended. The tuning set needs no flag.
static func final_gate(set_id: String, final_flag: bool, commit: String, record: Dictionary) -> Dictionary:
	if set_id == "tuning":
		return {"allowed": true, "lines": [], "record": record}
	if not set_id in ["1", "2"]:
		return {"allowed": false, "lines": ["REFUSED: unknown set '%s' (tuning|1|2)" % set_id], "record": record}
	if not final_flag:
		return {"allowed": false, "lines": ["REFUSED: hold-out set #%s runs only with --final (D-290); no run was started" % set_id], "record": record}
	var lines: Array = ["FINAL set=#%s commit=%s" % [set_id, commit]]
	var earlier: Array = record.get(set_id, [])
	var differs := ""
	for e in earlier:
		lines.append("FINAL_EARLIER set=#%s commit=%s" % [set_id, e.commit])
		if String(e.commit) != commit:
			differs = String(e.commit)
	if not earlier.is_empty():
		if differs != "":
			lines.append("FINAL_REPEAT: set #%s was already run at commit %s; this run is at commit %s. A failed target ends tuning against this set (D-290): the next final run uses the next hold-out set" % [set_id, differs, commit])
		else:
			lines.append("FINAL_REPEAT: set #%s was already run at the same commit %s" % [set_id, commit])
	var out := record.duplicate(true)
	var list: Array = out.get(set_id, [])
	list.append({"commit": commit})
	out[set_id] = list
	return {"allowed": true, "lines": lines, "record": out}

## Per-run facts from the tier-3 nights of a retune-on sweep: `nights` rows {tier, frac, hare_share (-1 when the night has no hares), guard_hits}.
## first_t3_frac = the diner fraction of the first night that STARTED at tier >= 3 (-1 none); hare_share_mean / _min over the tier-3 nights that had hares (-1 none).
static func retune_run_stats(nights: Array) -> Dictionary:
	var out := {"first_t3_frac": -1.0, "hare_share_mean": -1.0, "hare_share_min": -1.0, "guard_hits": 0, "t3_nights": 0}
	var shares: Array = []
	for n in nights:
		if int(n.tier) < 3:
			continue
		if out.t3_nights == 0:
			out.first_t3_frac = float(n.frac)
		out.t3_nights += 1
		out.guard_hits += int(n.get("guard_hits", 0))
		if float(n.get("hare_share", -1.0)) >= 0.0:
			shares.append(float(n.hare_share))
	if not shares.is_empty():
		var sum := 0.0
		for v in shares:
			sum += float(v)
		out.hare_share_mean = sum / shares.size()
		out.hare_share_min = ReportMath.percentile(shares, 0.0)
	return out

# Run rows: {seed, lane, policy, mean_frac, retry_nights, first_t3_frac, fence_median, income_at_cap, hare_share, guard_hits, failed (optional)}.
# Every verdict returns {ok: bool, lines: [headline, "  seed ..." per seed, "  lane ..." per siege lane]}.

static func _ge(a: float, b: float) -> bool:
	return a >= b - EPS

static func _le(a: float, b: float) -> bool:
	return a <= b + EPS

static func _pts(r: Dictionary) -> float:
	return float(r.mean_frac) * 100.0

static func _of(rows: Array, policy: String) -> Array:
	return rows.filter(func(r): return r.policy == policy)

static func _mean(values: Array) -> float:
	if values.is_empty():
		return NAN
	var sum := 0.0
	for v in values:
		sum += float(v)
	return sum / values.size()

static func _policy_points(rows: Array, policy: String) -> float:
	return _mean(_of(rows, policy).map(func(r): return _pts(r)))

static func _distinct(rows: Array, key: String) -> Array:
	var out: Array = []
	for r in rows:
		if not r[key] in out:
			out.append(r[key])
	return out

static func _num(v: float, fmt: String) -> String:
	return "n/a" if is_nan(v) else fmt % v

## The per-seed and per-siege-lane lines. `fn`: Callable(rows) -> float (NAN = n/a) over the rows of one seed or one lane.
static func _breakdown(rows: Array, fn: Callable, fmt: String, flag_below := -INF) -> Array:
	var lines: Array = []
	for s in _distinct(rows, "seed"):
		var sub := rows.filter(func(r): return r.seed == s)
		var v := float(fn.call(sub))
		lines.append("  seed %d (%s): %s%s" % [s, sub[0].lane, _num(v, fmt), " FLAGGED" if (not is_nan(v) and v < flag_below - EPS) else ""])
	for l in SIEGE_LANES:
		var sub := rows.filter(func(r): return r.lane == l)
		if not sub.is_empty():
			lines.append("  lane %s: %s" % [l, _num(float(fn.call(sub)), fmt)])
	return lines

## The fixed pair with the best mean points over all the rows (ties: first in FIXED_PAIRS order).
static func best_fixed(rows: Array) -> String:
	var best := ""
	var best_v := -INF
	for p in FIXED_PAIRS:
		var v := _policy_points(rows, p)
		if not is_nan(v) and v > best_v + EPS:
			best_v = v
			best = p
	return best

static func _lead_of(rows: Array, best: String) -> float:
	var leads: Array = []
	for s in _distinct(rows, "seed"):
		var t := _of(rows.filter(func(r): return r.seed == s), "threat")
		var b := _of(rows.filter(func(r): return r.seed == s), best)
		if not t.is_empty() and not b.is_empty():
			leads.append(_pts(t[0]) - _pts(b[0]))
	return _mean(leads)

## THREAT_LEAD (D-285): the mean lead of threat over the best fixed pair (best by mean over all seeds, one pair for every seed) >= 5 points AND ahead (strictly) on at least
## 6 of 8 seeds (scaled for another set size: ceil(6 n / 8), so 3 of 4 on the tuning set).
static func threat_lead(rows: Array) -> Dictionary:
	var best := best_fixed(rows)
	var seeds := _distinct(rows, "seed")
	var ahead := 0
	for s in seeds:
		var sub := rows.filter(func(r): return r.seed == s)
		if _lead_of(sub, best) > EPS:
			ahead += 1
	var need := (6 * seeds.size() + 7) / 8
	var mean_lead := _lead_of(rows, best)
	var ok := not best.is_empty() and _ge(mean_lead, 5.0) and ahead >= need
	var head := "THREAT_LEAD: %s (mean lead %s points over %s, ahead on %d of %d seeds; needs >= 5.0 and >= %d)" % ["PASS" if ok else "FAIL", _num(mean_lead, "%+.1f"), best, ahead, seeds.size(), need]
	return {"ok": ok, "lines": [head] + _breakdown(rows, func(sub): return _lead_of(sub, best), "%+.1f")}

## THREAT_LEAD_BY_LANE: the mean lead (against the same best pair) is not negative on any siege lane.
static func threat_lead_by_lane(rows: Array) -> Dictionary:
	var best := best_fixed(rows)
	var ok := not best.is_empty()
	var parts: Array = []
	for l in SIEGE_LANES:
		var sub := rows.filter(func(r): return r.lane == l)
		if sub.is_empty():
			continue
		var v := _lead_of(sub, best)
		ok = ok and _ge(v, 0.0)
		parts.append("%s %s" % [l, _num(v, "%+.1f")])
	var head := "THREAT_LEAD_BY_LANE: %s (mean lead per siege lane over %s: %s; none may be negative)" % ["PASS" if ok else "FAIL", best, ", ".join(parts)]
	return {"ok": ok, "lines": [head] + _breakdown(rows, func(sub): return _lead_of(sub, best), "%+.1f")}

## RETRY_NIGHTS: zero for every policy (unbranched included).
static func retry_nights(rows: Array) -> Dictionary:
	var ok := true
	var parts: Array = []
	for p in RETUNE_POLICIES:
		var n := 0
		for r in _of(rows, p):
			n += int(r.retry_nights)
		ok = ok and n == 0
		parts.append("%s %d" % [p, n])
	var head := "RETRY_NIGHTS: %s (tier-3 retry nights summed over the seeds: %s; all must be 0)" % ["PASS" if ok else "FAIL", ", ".join(parts)]
	return {"ok": ok, "lines": [head] + _breakdown(rows, func(sub): return float(sub.map(func(r): return int(r.retry_nights)).reduce(func(a, b): return a + b, 0)), "%.0f")}

## FIRST_T3_NIGHT: no run's first tier-3 night below 25% of the diner's HP (exactly 25% passes).
static func first_t3_night(rows: Array) -> Dictionary:
	var lowest := INF
	for r in rows:
		lowest = minf(lowest, float(r.first_t3_frac) * 100.0)
	var ok := not rows.is_empty() and _ge(lowest, 25.0)
	var head := "FIRST_T3_NIGHT: %s (lowest first tier-3 night %s%% over %d runs; needs >= 25.0)" % ["PASS" if ok else "FAIL", _num(lowest if lowest < INF else NAN, "%.1f"), rows.size()]
	return {"ok": ok, "lines": [head] + _breakdown(rows, func(sub): return sub.map(func(r): return float(r.first_t3_frac) * 100.0).min(), "min %.1f%%")}

static func _fence_shares(rows: Array) -> Array:
	var out: Array = []
	for r in rows:
		if int(r.income_at_cap) > 0:
			out.append(100.0 * float(r.fence_median) / float(r.income_at_cap))
	return out

static func _median_or_nan(values: Array) -> float:
	return NAN if values.is_empty() else ReportMath.median(values)

## FENCE_TAX: the median over the runs of (fence rebuild + rebranch gold) / income at the tier-3 cap, in percent, <= 30. Shown with and without Longbow on the siege lane
## (all_a, mixed, threat | all_b, volley_stone, unbranched). The gate is the overall median. N/A (not a pass) when no run has a cap day.
static func fence_tax(rows: Array) -> Dictionary:
	var all := _fence_shares(rows)
	var with_lb := _fence_shares(rows.filter(func(r): return r.policy in LONGBOW_POLICIES))
	var without_lb := _fence_shares(rows.filter(func(r): return not r.policy in LONGBOW_POLICIES))
	var med := _median_or_nan(all)
	var ok := not is_nan(med) and _le(med, 30.0)
	var verdict := "N/A" if is_nan(med) else ("PASS" if ok else "FAIL")
	var head := "FENCE_TAX: %s (median %s%% of income at the cap over %d runs; needs <= 30.0)" % [verdict, _num(med, "%.1f"), all.size()]
	var lines: Array = [head,
		"  with Longbow on the siege lane (all_a, mixed, threat): median %s%%" % _num(_median_or_nan(with_lb), "%.1f"),
		"  without Longbow on the siege lane (all_b, volley_stone, unbranched): median %s%%" % _num(_median_or_nan(without_lb), "%.1f")]
	lines.append_array(_breakdown(rows, func(sub): return _median_or_nan(_fence_shares(sub)), "median %.1f%%"))
	return {"ok": ok, "lines": lines}

static func _spread(rows: Array) -> float:
	var vals: Array = []
	for p in FIXED_PAIRS:
		var v := _policy_points(rows, p)
		if not is_nan(v):
			vals.append(v)
	return NAN if vals.is_empty() else float(vals.max()) - float(vals.min())

## FIXED_SPREAD: best minus worst mean points of the four fixed pairs <= 15 (exactly 15 passes).
static func fixed_spread(rows: Array) -> Dictionary:
	var sp := _spread(rows)
	var ok := not is_nan(sp) and _le(sp, 15.0)
	var parts: Array = []
	for p in FIXED_PAIRS:
		parts.append("%s %s" % [p, _num(_policy_points(rows, p), "%.1f")])
	var head := "FIXED_SPREAD: %s (spread %s points: %s; needs <= 15.0)" % ["PASS" if ok else "FAIL", _num(sp, "%.1f"), ", ".join(parts)]
	return {"ok": ok, "lines": [head] + _breakdown(rows, func(sub): return _spread(sub), "spread %.1f")}

## HARE_SHARE: night-level share of the hares that walk the hare lane, per seed (mean over the six runs of the seed, each the mean over its tier-3 nights with hares);
## a seed below 0.6 is FLAGGED (exactly 0.6 is not). ok = nothing flagged.
static func hare_share(rows: Array) -> Dictionary:
	var flagged := 0
	for s in _distinct(rows, "seed"):
		var v := _mean(rows.filter(func(r): return r.seed == s).map(func(r): return float(r.hare_share)))
		if is_nan(v) or v < 0.6 - EPS:
			flagged += 1
	var ok := flagged == 0
	var head := "HARE_SHARE: %s (%d of %d seeds flagged below 0.60)" % ["PASS" if ok else "FLAGGED", flagged, _distinct(rows, "seed").size()]
	return {"ok": ok, "lines": [head] + _breakdown(rows, func(sub): return _mean(sub.map(func(r): return float(r.hare_share))), "%.3f", 0.6)}

## LANE_CAP_GUARD: waves whose extra hare group was skipped by the 3-lane guard, summed over all runs; expected 0.
static func lane_cap_guard(rows: Array) -> Dictionary:
	var n := 0
	for r in rows:
		n += int(r.guard_hits)
	var ok := n == 0
	var head := "LANE_CAP_GUARD: %s (hits %d, expected 0)" % ["PASS" if ok else "FAIL", n]
	return {"ok": ok, "lines": [head] + _breakdown(rows, func(sub): return float(sub.map(func(r): return int(r.guard_hits)).reduce(func(a, b): return a + b, 0)), "hits %.0f")}

## The whole report. `expected`: [[seed, policy], ...]. A missing run, a run with `failed`, or a run that never reached tier 3 (first_t3_frac < 0) = NO verdict lines, exit 1.
static func retune_report(rows: Array, expected: Array) -> Dictionary:
	var problems: Array = []
	for e in expected:
		var found: Array = rows.filter(func(r): return int(r.seed) == int(e[0]) and r.policy == e[1])
		if found.is_empty():
			problems.append("seed %d %s: missing" % [e[0], e[1]])
		elif bool(found[0].get("failed", false)):
			problems.append("seed %d %s: failed (hard break or no result)" % [e[0], e[1]])
		elif float(found[0].first_t3_frac) < 0.0:
			problems.append("seed %d %s: no tier-3 night" % [e[0], e[1]])
	if not problems.is_empty():
		return {"exit": 1, "ok": false, "lines": ["FAILED: a run is missing or failed; no verdict lines"] + problems}
	var lines: Array = []
	var all_ok := true
	for res in [threat_lead(rows), threat_lead_by_lane(rows), retry_nights(rows), first_t3_night(rows), fence_tax(rows), fixed_spread(rows), hare_share(rows), lane_cap_guard(rows)]:
		lines.append_array(res.lines)
		all_ok = all_ok and res.ok
	return {"exit": 0, "ok": all_ok, "lines": lines}
