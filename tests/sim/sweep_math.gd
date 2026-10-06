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
