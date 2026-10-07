class_name WaveSchedule
extends RefCounted
## Spawn times for one wave and the clear rule (spec 7.1, D-044).

## E5 (spec 4.2): entries carry `kind`. The last fast_main / fast_side entries of each group are hares (they spawn behind
## the boars and overtake them). A boss wave puts one &"boss" entry first at t = 0 and shifts the rest by boss_lead.
## Brutes (E5 tier 3) are appended after each group. A wave without the new keys (a schema 4 plan before its first dawn) is all boars.
static func build(wave: Dictionary, wb: WaveBalance, tb: TierBalance = null) -> Array:
	var out: Array = []
	var main_n := int(wave.main_count)
	var side_n := int(wave.side_count)
	var fast_main := int(wave.get("fast_main", 0))
	var fast_side := int(wave.get("fast_side", 0))
	var brute_main := int(wave.get("brute_main", 0))
	var brute_side := int(wave.get("brute_side", 0))
	var boss := bool(wave.get("boss", false))
	var lead := 0.0
	if boss:
		if tb == null:
			tb = Balance.data.tiers
		lead = tb.boss_lead
		out.append({"t": 0.0, "lane": String(wave.main), "side": false, "kind": &"boss"})
	for i in main_n:
		var kind: StringName = &"hare" if i >= main_n - fast_main else &"boar"
		out.append({"t": lead + i * wb.spawn_interval, "lane": String(wave.main), "side": false, "kind": kind})
	for j in brute_main:  # brutes follow the group's boars and hares, at the group's spacing
		out.append({"t": lead + (main_n + j) * wb.spawn_interval, "lane": String(wave.main), "side": false, "kind": &"brute"})
	for i in side_n:
		var kind: StringName = &"hare" if i >= side_n - fast_side else &"boar"
		out.append({"t": lead + wb.side_group_delay + i * wb.spawn_interval, "lane": String(wave.side), "side": true, "kind": kind})
	for j in brute_side:
		out.append({"t": lead + wb.side_group_delay + (side_n + j) * wb.spawn_interval, "lane": String(wave.side), "side": true, "kind": &"brute"})
	out.sort_custom(func(a, b):
		if not is_equal_approx(a.t, b.t):
			return a.t < b.t
		return not a.side and b.side)
	return out

static func is_cleared(planned: int, spawned: int, alive: int) -> bool:
	return spawned >= planned and alive == 0
