class_name LaneCharacter
extends RefCounted
## E6 (spec 3.1, D-282): the run's persistent lane character at tier 3. One SIEGE lane (all siege brutes walk it)
## and one HARE lane (most hares do), drawn once per run, so a permanent building choice can be informed by
## something that does not change every night. Pure: no scene or autoload access.

const SIEGE := &"siege"
const HARE := &"hare"
const NEUTRAL := &"neutral"

## Returns {"siege": lane, "hare": lane}. The result is pinned forever by saves, so the draw is exactly:
##   var rng := Rng.stream(run_seed, 0, &"lane_character")
##   siege = lanes[rng.randi_range(0, 3)]            # lanes = LanePlanner.lanes_for_tier(3)
##   hare  = others[rng.randi_range(0, 2)]           # others = lanes without siege, in the list's order
## Two draws, in that order. Never reorder, add a draw before them, or change the stream name or day.
static func for_run(run_seed: int) -> Dictionary:
	var lanes := LanePlanner.lanes_for_tier(3)
	var rng := Rng.stream(run_seed, 0, &"lane_character")
	var siege: String = lanes[rng.randi_range(0, lanes.size() - 1)]
	var others: Array = lanes.filter(func(l): return l != siege)
	var hare: String = others[rng.randi_range(0, others.size() - 1)]
	return {"siege": siege, "hare": hare}

## &"siege", &"hare" or &"neutral". An empty character is neutral on every lane.
static func lane_type(character: Dictionary, lane: String) -> StringName:
	if character.is_empty() or lane == "":
		return NEUTRAL
	if String(character.get("siege", "")) == lane:
		return SIEGE
	if String(character.get("hare", "")) == lane:
		return HARE
	return NEUTRAL

## The types of the lanes a building covers, in order.
static func spot_types(character: Dictionary, lanes: Array) -> Array:
	var out: Array = []
	for lane in lanes:
		out.append(lane_type(character, String(lane)))
	return out

## E6 (spec 3.2, D-287): the plan step. Pure and deterministic: no random draws, `plan` is not mutated (a deep copy is
## returned; an empty character returns an equal copy). Per wave, in this order:
##  a. BRUTES. B = brute_main + brute_side (unchanged). Siege lane = main: all on main. = side: all on side. Neither:
##     the SIDE group moves to the siege lane (side = siege; its count and hares travel with it). No side group
##     (side == ""): side = siege with side_count 0 and fast_side 0. B == 0: lanes untouched.
##  b. HARES. H = fast_main + fast_side (unchanged), T = roundi(hare_lane_share x H) (half away from zero).
##     Hare lane = main (or side): that group takes min(T, its count), the rest goes to the other group (capped at its
##     count; it always fits). Neither: an EXTRA group {lane, count: T, fast: T} is appended to wave.extra (T > 0), the T
##     hares taken from fast_main and fast_side proportionally by largest remainder (ties to main); each group's count
##     shrinks by what it gave.
##  c. GUARD. A wave never has more than 3 active lanes: if the extra group would make 4, it is skipped and the wave is
##     marked "lane_cap_guard": true (count them with guard_hits). Unreachable after (a); kept as an asserted guard.
##  d. Extra groups carry NO delay field: the consumer spawns them with the side-group delay.
## Idempotent: applying the result again with the same character changes nothing (a wave that already has an extra group
## on the hare lane is left alone). The caller still applies it once, to fresh LanePlanner.plan output.
## Rounding: roundi is "half away from zero"; with share 0.7 this is exact only for H up to 30 (max_wave_size, the
## largest group), since float error in 0.7 x H could otherwise flip a half case. T is clamped to H so a share above 1
## cannot make a count negative.
static func apply(plan: Array, character: Dictionary, tb: TierBalance) -> Array:
	var out: Array = plan.duplicate(true)
	if character.is_empty():
		return out
	var siege := String(character.get("siege", ""))
	var hare := String(character.get("hare", ""))
	for wave in out:
		_apply_brutes(wave, siege)
		_apply_hares(wave, hare, tb.hare_lane_share)
	return out

static func _apply_brutes(wave: Dictionary, siege: String) -> void:
	var b := int(wave.get("brute_main", 0)) + int(wave.get("brute_side", 0))
	if b <= 0 or siege == "":
		return
	if String(wave.main) == siege:
		wave["brute_main"] = b
		wave["brute_side"] = 0
		return
	if String(wave.side) == "":
		wave["side_count"] = 0
		wave["fast_side"] = 0
	wave["side"] = siege
	wave["brute_main"] = 0
	wave["brute_side"] = b

static func _apply_hares(wave: Dictionary, hare: String, share: float) -> void:
	var fm := int(wave.get("fast_main", 0))
	var fs := int(wave.get("fast_side", 0))
	var h := fm + fs
	var t := mini(roundi(share * h), h)
	if h <= 0 or t <= 0 or hare == "":
		return
	var mc := int(wave.main_count)
	var sc := int(wave.side_count)
	if String(wave.main) == hare:
		var new_m := mini(t, mc)
		var new_s := mini(h - new_m, sc)
		wave["fast_main"] = h - new_s
		wave["fast_side"] = new_s
	elif String(wave.side) == hare:
		var new_s := mini(t, sc)
		var new_m := mini(h - new_s, mc)
		wave["fast_side"] = h - new_m
		wave["fast_main"] = new_m
	else:
		for e in wave.get("extra", []):
			if String(e.lane) == hare:
				return  # already applied: a second pass leaves the wave as it is (idempotent)
		var lanes := _lane_set(wave)
		if not lanes.has(hare):
			lanes.append(hare)
		if lanes.size() > 3:
			wave["lane_cap_guard"] = true
			return
		var from_main := (t * fm) / h
		var from_side := (t * fs) / h
		var left := t - from_main - from_side
		if left > 0:
			if (t * fm) % h >= (t * fs) % h:
				from_main += 1
			else:
				from_side += 1
		wave["main_count"] = mc - from_main
		wave["fast_main"] = fm - from_main
		wave["side_count"] = sc - from_side
		wave["fast_side"] = fs - from_side
		var extra: Array = wave.get("extra", [])
		extra.append({"lane": hare, "count": t, "fast": t})
		wave["extra"] = extra

static func _lane_set(wave: Dictionary) -> Array:
	var lanes: Array = []
	var add := func(l: String, n: int) -> void:
		if l != "" and n > 0 and not lanes.has(l):
			lanes.append(l)
	add.call(String(wave.main), int(wave.get("main_count", 0)) + int(wave.get("brute_main", 0)))
	add.call(String(wave.side), int(wave.get("side_count", 0)) + int(wave.get("brute_side", 0)))
	for e in wave.get("extra", []):
		add.call(String(e.lane), int(e.count))
	return lanes

## Distinct lanes with at least one enemy: main, side (its group or brutes), extra groups.
static func active_lanes(wave: Dictionary) -> Array:
	return _lane_set(wave)

## The lane the wave's brutes walk ("" when it has none).
static func brute_lane(wave: Dictionary) -> String:
	if int(wave.get("brute_main", 0)) > 0:
		return String(wave.main)
	if int(wave.get("brute_side", 0)) > 0:
		return String(wave.side)
	return ""

## Night-level share of the plan's hares (main, side and extra groups) that walk the hare lane; 0.0 with no hares or
## an empty character.
static func hare_share(plan: Array, character: Dictionary) -> float:
	var hare := String(character.get("hare", ""))
	var total := 0
	var on := 0
	for wave in plan:
		var groups: Array = [[String(wave.main), int(wave.get("fast_main", 0))], [String(wave.side), int(wave.get("fast_side", 0))]]
		for e in wave.get("extra", []):
			groups.append([String(e.lane), int(e.fast)])
		for g in groups:
			total += int(g[1])
			if hare != "" and g[0] == hare:
				on += int(g[1])
	return float(on) / float(total) if total > 0 else 0.0

## How many waves of `plan_after` skipped their extra hare group because of the 3-lane guard (expected 0).
static func guard_hits(plan_after: Array) -> int:
	var n := 0
	for wave in plan_after:
		if bool(wave.get("lane_cap_guard", false)):
			n += 1
	return n
