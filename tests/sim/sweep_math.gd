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
static func ladder_done(spots: Array, station_levels: Array, max_level: int, station_max: int) -> bool:
	if spots.is_empty():
		return false
	for s in spots:
		if int(s.level) < max_level:
			return false
		if String(s.kind) in ["tower", "fence"] and String(s.branch) == "":
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
