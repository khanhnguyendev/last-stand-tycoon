class_name LaneCharacter
extends RefCounted
## E6 (spec 3.1, D-282): the run's persistent lane character at tier 3. One SIEGE lane (all siege brutes walk it)
## and one HARE lane (most hares do), drawn once per run, so a permanent building choice can be informed by
## something that does not change every night. Pure: no scene or autoload access.

const SIEGE := &"siege"
const HARE := &"hare"
const NEUTRAL := &"neutral"

## E6 (D-289.4): the flavour banners, at most 6 words each, per lane and kind. Source strings (CardCatalog's pattern: a table, translated
## on use). The author tone-checks them through docs/REVIEW_QUEUE.md.
const FLAVOUR := {
	"west": {SIEGE: "Heavy tracks on the west road...", HARE: "Quick paws in the west grass..."},
	"north": {SIEGE: "Heavy tracks on the north path...", HARE: "Quick paws in the north grass..."},
	"east": {SIEGE: "Heavy tracks on the east road...", HARE: "Quick paws in the east grass..."},
	"sw": {SIEGE: "Heavy tracks on the south road...", HARE: "Quick paws in the south grass..."},
}

## The banner for `lane` and kind (&"siege" or &"hare"), translated; "" for any other pair.
static func flavour(lane: String, type: StringName) -> String:
	var row: Dictionary = FLAVOUR.get(lane, {})
	if not row.has(type):
		return ""
	return TranslationServer.translate(row[type])

## [siege line, hare line] for a lane character; [] for an empty one.
static func flavour_lines(character: Dictionary) -> Array[String]:
	if character.is_empty():
		return []
	return [flavour(String(character.siege), SIEGE), flavour(String(character.hare), HARE)]

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
##  Tier 4 (E8 spec 4.4, B7): a wave with a side2 group has three groups and never an extra one. Step a puts all brutes on
##     whichever group is the siege lane. Step b is a greedy fill: the hare lane's group takes min(T, its count), the
##     rest fill the other groups in main, side, side2 order, each capped at its count; what still does not fit goes to
##     the hare lane's group (it always fits).
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
	if wave.has("side2"):
		_apply_brutes_3(wave, siege)
		return
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

## Three groups: the brutes all go to the group whose lane is the siege lane (the planner guarantees it is one of them).
static func _apply_brutes_3(wave: Dictionary, siege: String) -> void:
	var b := int(wave.get("brute_main", 0)) + int(wave.get("brute_side", 0)) + int(wave.get("brute_side2", 0))
	if b <= 0 or siege == "":
		return
	var target := ""
	for g in [["main", "brute_main"], ["side", "brute_side"], ["side2", "brute_side2"]]:
		if String(wave[g[0]]) == siege:
			target = g[1]
	if target == "":
		return
	wave["brute_main"] = 0
	wave["brute_side"] = 0
	wave["brute_side2"] = 0
	wave[target] = b

## Three groups: the greedy fill of the class comment.
static func _apply_hares_3(wave: Dictionary, hare: String, share: float) -> void:
	var names := ["main", "side", "side2"]
	var h := 0
	for n in names:
		h += int(wave.get("fast_" + n, 0))
	var t := mini(roundi(share * h), h)
	if h <= 0 or t <= 0 or hare == "":
		return
	var hare_group := ""
	for n in names:
		if String(wave[n]) == hare:
			hare_group = n
	if hare_group == "":
		return  # the planner always puts the hare lane in a tier-4 wave; never an extra group here
	var taken := {}
	var rem := h - mini(t, int(wave[hare_group + "_count"]))
	var placed := 0
	for n in names:
		if n == hare_group:
			continue
		var take := mini(rem, int(wave[n + "_count"]))
		taken[n] = take
		rem -= take
		placed += take
	for n in names:
		wave["fast_" + n] = h - placed if n == hare_group else int(taken[n])

static func _apply_hares(wave: Dictionary, hare: String, share: float) -> void:
	if wave.has("side2"):
		_apply_hares_3(wave, hare, share)
		return
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
	if wave.has("side2"):
		add.call(String(wave.side2), int(wave.get("side2_count", 0)) + int(wave.get("brute_side2", 0)))
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
	if wave.has("side2") and int(wave.get("brute_side2", 0)) > 0:
		return String(wave.side2)
	return ""

## Night-level share of the plan's hares (main, side and extra groups) that walk the hare lane; 0.0 with no hares or
## an empty character.
static func hare_share(plan: Array, character: Dictionary) -> float:
	var hare := String(character.get("hare", ""))
	var total := 0
	var on := 0
	for wave in plan:
		var groups: Array = [[String(wave.main), int(wave.get("fast_main", 0))], [String(wave.side), int(wave.get("fast_side", 0))]]
		if wave.has("side2"):
			groups.append([String(wave.side2), int(wave.get("fast_side2", 0))])
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
