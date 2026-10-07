class_name LanePlanner
extends RefCounted
## Seeded per-night lane plan (spec 6.2, D-026, D-028, D-095) and telegraph threat (D-029).

const LANES: Array[String] = ["west", "north", "east"]
## E5 tier 3 (spec 3.1): the south-west lane joins at tier 3.
const LANES_TIER3: Array[String] = ["west", "north", "east", "sw"]

## The lanes of a tier: LANES (the same array) below tier 3, the four-lane list from tier 3.
static func lanes_for_tier(tier: int) -> Array[String]:
	return LANES if tier < 3 else LANES_TIER3

## E5 (spec 4.1, 4.2): the lanes come from the day's stream exactly as before (so a save keeps its lane order); the
## counts and hp_mult come from the pressure; the hare counts from the tier's ramp. Defaults = tier 1 = today's plan.
static func plan(run_seed: int, day: int, wb: WaveBalance, tier := 1, tier_day := 1, tb: TierBalance = null) -> Array:
	if tb == null:
		tb = Balance.data.tiers
	var pressure := WaveMath.pressure(day, tier, tier_day, tb)
	var share := TierEffects.fast_share_now(day, tier, tier_day, tb)
	var rng := Rng.stream(run_seed, day, &"lane_plan")
	var lanes := lanes_for_tier(tier)
	var waves: Array = []
	for w in wb.base_counts.size():
		var main := ""
		if day == 1 and w == 0:
			main = "north"
		else:
			main = lanes[rng.randi_range(0, lanes.size() - 1)]
		var counts := WaveMath.split(pressure, w, wb)
		var side := ""
		if int(counts.side) > 0:
			var others: Array = lanes.filter(func(l): return l != main)
			side = others[rng.randi_range(0, others.size() - 1)]
		var fast := TierEffects.fast_counts(int(counts.main), int(counts.side), share)
		var brutes := TierEffects.brute_counts(day, tier, tier_day, w, wb.base_counts.size(), side != "", tb)
		var wave := {
			"main": main, "side": side,
			"main_count": int(counts.main), "side_count": int(counts.side),
			"hp_mult": WaveMath.hp_mult(pressure, w, wb),
			"fast_main": int(fast.fast_main), "fast_side": int(fast.fast_side), "boss": false,
		}
		if tier >= 3:  # tiers 1 and 2 keep today's exact wave dictionary (readers use .get("brute_main", 0))
			wave["brute_main"] = int(brutes.main)
			wave["brute_side"] = int(brutes.side)
		waves.append(wave)
	return waves

## A deep copy of `plan_waves` whose last wave carries the boss (E5 spec 4.2; the boss night is the capped night + 1).
static func with_boss(plan_waves: Array) -> Array:
	var out: Array = plan_waves.duplicate(true)
	if not out.is_empty():
		out[out.size() - 1].boss = true
	return out

## Threat (total hp) per lane of `tier`: tiers 1 and 2 return exactly west, north, east; tier 3 adds sw. `tier` is an
## optional parameter because a plan does not carry its tier. Brutes add stats(&"brute").hp x hp_mult to their lane; a boss wave
## adds the HP of the tier's boss (TierEffects.boss_kind_for: the King at tier 1, the Baron at tier 2, nothing at the top).
static func threat_by_lane(plan_waves: Array, base_hp: float, tier := 1) -> Dictionary:
	var t := {}
	for lane in lanes_for_tier(tier):
		t[lane] = 0.0
	var brute_hp: float = Balance.data.monsters.stats(&"brute").hp
	var boss_kind := TierEffects.boss_kind_for(tier, Balance.data.tiers)
	for wave in plan_waves:
		var m := float(wave.hp_mult)
		var hp := base_hp * m
		t[wave.main] = float(t.get(wave.main, 0.0)) + int(wave.main_count) * hp + int(wave.get("brute_main", 0)) * brute_hp * m
		if String(wave.side) != "":
			t[wave.side] = float(t.get(wave.side, 0.0)) + int(wave.side_count) * hp + int(wave.get("brute_side", 0)) * brute_hp * m
		if bool(wave.get("boss", false)) and boss_kind != &"":
			t[wave.main] += Balance.data.monsters.stats(boss_kind).hp * m
	return t

## Per lane of `tier`: {boar, hare, brute, boss} counts of the whole plan (the telegraph, spec 6.5). Boars are the
## group's count minus its hares; brutes are on top of the group counts.
static func composition_by_lane(plan_waves: Array, tier := 1) -> Dictionary:
	var out := {}
	for lane in lanes_for_tier(tier):
		out[lane] = {"boar": 0, "hare": 0, "brute": 0, "boss": 0}
	for wave in plan_waves:
		_add_group(out, String(wave.main), int(wave.main_count), int(wave.get("fast_main", 0)), int(wave.get("brute_main", 0)))
		if String(wave.side) != "":
			_add_group(out, String(wave.side), int(wave.side_count), int(wave.get("fast_side", 0)), int(wave.get("brute_side", 0)))
		if bool(wave.get("boss", false)):
			out[String(wave.main)].boss += 1
	return out

static func _add_group(out: Dictionary, lane: String, count: int, hares: int, brutes: int) -> void:
	if not out.has(lane):
		out[lane] = {"boar": 0, "hare": 0, "brute": 0, "boss": 0}
	out[lane].boar += count - hares
	out[lane].hare += hares
	out[lane].brute += brutes

static func marker_scale(threat: float, max_threat: float, min_s: float, max_s: float) -> float:
	if threat <= 0.0 or max_threat <= 0.0:
		return 0.0
	return lerpf(min_s, max_s, clampf(threat / max_threat, 0.0, 1.0))
