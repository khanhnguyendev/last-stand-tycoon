class_name WaveSchedule
extends RefCounted
## Spawn times for one wave and the clear rule (spec 7.1, D-044).

## E5 (spec 4.2): entries carry `kind`. The last fast_main / fast_side entries of each group are hares (they spawn behind
## the boars and overtake them). A boss wave puts one boss entry first at t = 0 (the kind of `tier`, TierEffects.boss_kind_for:
## the Boar King leaving tier 1, Baron von Hop leaving tier 2) and shifts the rest by boss_lead; a tier with no boss (the top)
## gets neither the entry nor the lead.
## Brutes (E5 tier 3) are appended after each group. A wave without the new keys (a schema 4 plan before its first dawn) is all boars.
static func build(wave: Dictionary, wb: WaveBalance, tb: TierBalance = null, tier := 1) -> Array:
	var out: Array = []
	var main_n := int(wave.main_count)
	var side_n := int(wave.side_count)
	var fast_main := int(wave.get("fast_main", 0))
	var fast_side := int(wave.get("fast_side", 0))
	var brute_main := int(wave.get("brute_main", 0))
	var brute_side := int(wave.get("brute_side", 0))
	var lead := 0.0
	if bool(wave.get("boss", false)):
		if tb == null:
			tb = Balance.data.tiers
		var boss_kind := TierEffects.boss_kind_for(tier, tb)
		if boss_kind != &"":
			lead = tb.boss_lead
			out.append({"t": 0.0, "lane": String(wave.main), "side": false, "kind": boss_kind})
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
	# E6: extra groups (LaneCharacter.apply) start with the side group, on their own lane, hares last; "side": true and
	# "extra": true (the key exists only on these entries, so a wave without extra is entry-for-entry what it was).
	var extras: Array = wave.get("extra", [])
	for k in extras.size():
		var e: Dictionary = extras[k]
		var n := int(e.count)
		var fast := int(e.fast)
		for i in n:
			var kind: StringName = &"hare" if i >= n - fast else &"boar"
			out.append({"t": lead + wb.side_group_delay + i * wb.spawn_interval, "lane": String(e.lane), "side": true, "extra": true, "kind": kind})
	if extras.is_empty():
		out.sort_custom(func(a, b):
			if not is_equal_approx(a.t, b.t):
				return a.t < b.t
			return not a.side and b.side)
		return out
	return _sorted_with_extras(out)

## Ties at the same time break by group rank (boss and main 0, side 1, extra groups 2), then by build order (the boss
## first, then main, brutes, side, then extra groups in wave.extra order): a total order, so the result never depends
## on the sort's stability.
static func _sorted_with_extras(entries: Array) -> Array:
	var keyed: Array = []
	for i in entries.size():
		var e: Dictionary = entries[i]
		var rank := 1 if bool(e.side) else 0
		if bool(e.get("extra", false)):
			rank = 2
		keyed.append([e, rank, i])
	keyed.sort_custom(func(a, b):
		if not is_equal_approx(a[0].t, b[0].t):
			return a[0].t < b[0].t
		if a[1] != b[1]:
			return a[1] < b[1]
		return a[2] < b[2])
	return keyed.map(func(k): return k[0])

static func is_cleared(planned: int, spawned: int, alive: int) -> bool:
	return spawned >= planned and alive == 0
