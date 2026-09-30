class_name LanePlanner
extends RefCounted
## Seeded per-night lane plan (spec 6.2, D-026, D-028, D-095) and telegraph threat (D-029).

const LANES: Array[String] = ["west", "north", "east"]

static func plan(run_seed: int, day: int, wb: WaveBalance) -> Array:
	var rng := Rng.stream(run_seed, day, &"lane_plan")
	var waves: Array = []
	for w in wb.base_counts.size():
		var main := ""
		if day == 1 and w == 0:
			main = "north"
		else:
			main = LANES[rng.randi_range(0, LANES.size() - 1)]
		var counts := WaveMath.split(day, w, wb)
		var side := ""
		if int(counts.side) > 0:
			var others: Array = LANES.filter(func(l): return l != main)
			side = others[rng.randi_range(0, others.size() - 1)]
		waves.append({
			"main": main, "side": side,
			"main_count": int(counts.main), "side_count": int(counts.side),
			"hp_mult": WaveMath.hp_mult(day, w, wb),
		})
	return waves

static func threat_by_lane(plan_waves: Array, base_hp: float) -> Dictionary:
	var t := {"west": 0.0, "north": 0.0, "east": 0.0}
	for wave in plan_waves:
		var hp := base_hp * float(wave.hp_mult)
		t[wave.main] += int(wave.main_count) * hp
		if String(wave.side) != "":
			t[wave.side] += int(wave.side_count) * hp
	return t

static func marker_scale(threat: float, max_threat: float, min_s: float, max_s: float) -> float:
	if threat <= 0.0 or max_threat <= 0.0:
		return 0.0
	return lerpf(min_s, max_s, clampf(threat / max_threat, 0.0, 1.0))
