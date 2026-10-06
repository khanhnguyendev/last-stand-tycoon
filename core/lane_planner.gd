class_name LanePlanner
extends RefCounted
## Seeded per-night lane plan (spec 6.2, D-026, D-028, D-095) and telegraph threat (D-029).

const LANES: Array[String] = ["west", "north", "east"]

## E5 (spec 4.1, 4.2): the lanes come from the day's stream exactly as before (so a save keeps its lane order); the
## counts and hp_mult come from the pressure; the hare counts from the tier's ramp. Defaults = tier 1 = today's plan.
static func plan(run_seed: int, day: int, wb: WaveBalance, tier := 1, tier_day := 1, tb: TierBalance = null) -> Array:
	if tb == null:
		tb = Balance.data.tiers
	var pressure := WaveMath.pressure(day, tier, tier_day, tb)
	var share := TierEffects.fast_share_now(day, tier, tier_day, tb)
	var rng := Rng.stream(run_seed, day, &"lane_plan")
	var waves: Array = []
	for w in wb.base_counts.size():
		var main := ""
		if day == 1 and w == 0:
			main = "north"
		else:
			main = LANES[rng.randi_range(0, LANES.size() - 1)]
		var counts := WaveMath.split(pressure, w, wb)
		var side := ""
		if int(counts.side) > 0:
			var others: Array = LANES.filter(func(l): return l != main)
			side = others[rng.randi_range(0, others.size() - 1)]
		var fast := TierEffects.fast_counts(int(counts.main), int(counts.side), share)
		waves.append({
			"main": main, "side": side,
			"main_count": int(counts.main), "side_count": int(counts.side),
			"hp_mult": WaveMath.hp_mult(pressure, w, wb),
			"fast_main": int(fast.fast_main), "fast_side": int(fast.fast_side), "boss": false,
		})
	return waves

## A deep copy of `plan_waves` whose last wave carries the boss (E5 spec 4.2; the boss night is the capped night + 1).
static func with_boss(plan_waves: Array) -> Array:
	var out: Array = plan_waves.duplicate(true)
	if not out.is_empty():
		out[out.size() - 1].boss = true
	return out

static func threat_by_lane(plan_waves: Array, base_hp: float) -> Dictionary:
	var t := {"west": 0.0, "north": 0.0, "east": 0.0}
	for wave in plan_waves:
		var hp := base_hp * float(wave.hp_mult)
		t[wave.main] += int(wave.main_count) * hp
		if String(wave.side) != "":
			t[wave.side] += int(wave.side_count) * hp
		if bool(wave.get("boss", false)):
			t[wave.main] += Balance.data.monsters.stats(&"boss").hp * float(wave.hp_mult)
	return t

static func marker_scale(threat: float, max_threat: float, min_s: float, max_s: float) -> float:
	if threat <= 0.0 or max_threat <= 0.0:
		return 0.0
	return lerpf(min_s, max_s, clampf(threat / max_threat, 0.0, 1.0))
