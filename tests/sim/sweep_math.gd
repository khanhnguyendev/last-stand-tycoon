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
## {tier, retries, frac, fences_lost, branches, branch_gold} (tier read at the night's start; frac = the final attempt's lowest diner HP
## fraction, a failed night included as played). Only nights with tier >= 3 count. Empty set: every number 0 and nights 0.
static func tier3_stats(nights: Array) -> Dictionary:
	var out := {"nights": 0, "retry_nights": 0, "min": 0.0, "median": 0.0, "mean": 0.0, "fences_lost_mean": 0.0, "branches": 0, "branch_gold": 0}
	var fracs: Array = []
	var lost := 0
	for n in nights:
		if int(n.tier) < 3:
			continue
		fracs.append(float(n.frac))
		lost += int(n.fences_lost)
		out.retry_nights += 1 if int(n.retries) > 0 else 0
		out.branches += int(n.branches)
		out.branch_gold += int(n.branch_gold)
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

## The LADDER line's numbers (see tests/sim/sweep_runner.gd header). `days`: one Dictionary per day closed, in order:
## {day, tier, at_cap3, income, rebuild, unspent, done}; tier = the tier at the night's start; at_cap3 = a tier-3 night at the cap;
## income = gold the day's sales paid; rebuild = gold paid that day for fences and fence branches; unspent = gold at close-up;
## done = ladder_done() at close-up. ladder_done_day = the first done day (-1 never); max_unspent counts tier-3 days up to and
## including ladder_done_day (every tier-3 day when it is -1); the two medians run over the at_cap3 days (0 when none).
static func ladder_summary(plot_day: int, days: Array) -> Dictionary:
	var done_day := -1
	for d in days:
		if bool(d.done):
			done_day = int(d.day)
			break
	var max_unspent := 0
	var rebuild: Array = []
	var income: Array = []
	for d in days:
		if int(d.tier) >= 3 and (done_day < 0 or int(d.day) <= done_day):
			max_unspent = maxi(max_unspent, int(d.unspent))
		if bool(d.at_cap3):
			rebuild.append(int(d.rebuild))
			income.append(int(d.income))
	return {"plot_day": plot_day, "ladder_done_day": done_day, "max_unspent_during_ladder": max_unspent,
		"fence_rebuild_gold_median_at_cap": int(round(ReportMath.median(rebuild))), "income_at_cap": int(round(ReportMath.median(income)))}

## The policy report's summary. `runs`: {policy, mean_frac, retry_nights} per run. Per policy: the mean over its runs of mean_frac,
## in points (percent of the diner's maximum HP), and the sum of retry_nights. Best first; equal points keep the order of first appearance.
## gap = best minus worst, in points.
static func policy_ranking(runs: Array) -> Dictionary:
	var order: Array = []
	var sums := {}
	var counts := {}
	var retries := {}
	for r in runs:
		var p := String(r.policy)
		if not sums.has(p):
			order.append(p)
			sums[p] = 0.0
			counts[p] = 0
			retries[p] = 0
		sums[p] = float(sums[p]) + float(r.mean_frac) * 100.0
		counts[p] = int(counts[p]) + 1
		retries[p] = int(retries[p]) + int(r.retry_nights)
	var rows: Array = []
	for p in order:
		rows.append({"policy": p, "points": float(sums[p]) / int(counts[p]), "retry_nights": int(retries[p])})
	var idx := {}
	for i in order.size():
		idx[order[i]] = i
	rows.sort_custom(func(a, b): return a.points > b.points or (a.points == b.points and idx[a.policy] < idx[b.policy]))
	var gap := 0.0 if rows.is_empty() else float(rows[0].points) - float(rows[rows.size() - 1].points)
	return {"rows": rows, "gap": gap}

## The two verdict lines of the policy report (spec 9.2): a gap above 15 points is a possible dominant branch (exactly 15 is not);
## the threat policy is best when no policy has more points (a tie counts).
static func policy_verdicts(ranking: Dictionary) -> Array:
	var rows: Array = ranking.rows
	var gap := float(ranking.gap)
	var lines: Array = ["DOMINANT_BRANCH: %s (gap %.1f points, threshold 15)" % ["yes" if gap > 15.0 else "no", gap]]
	var threat := -1.0
	for r in rows:
		if r.policy == "threat":
			threat = float(r.points)
	var best: Dictionary = rows[0] if not rows.is_empty() else {"policy": "none", "points": 0.0}
	lines.append("THREAT_BEST: %s (threat %.1f, best %s %.1f)" % ["yes" if threat >= float(best.points) else "no", threat, best.policy, float(best.points)])
	return lines
