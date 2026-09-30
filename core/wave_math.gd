class_name WaveMath
extends RefCounted
## Wave sizes and HP (spec 6.2, D-027, D-053, D-100).

static func raw_total(day: int, w: int, wb: WaveBalance) -> int:
	return int(round(wb.base_counts[w] * (1.0 + wb.count_growth * (day - 1))))

static func total_count(day: int, w: int, wb: WaveBalance) -> int:
	return mini(raw_total(day, w, wb), wb.max_wave_size)

static func hp_mult(day: int, w: int, wb: WaveBalance) -> float:
	var m := 1.0 + wb.hp_growth * (day - 1)
	var raw := raw_total(day, w, wb)
	if raw > wb.max_wave_size:
		m *= float(raw) / float(wb.max_wave_size)
	return m

static func side_share(day: int, wb: WaveBalance) -> float:
	if day < 2:
		return 0.0
	return minf(wb.side_share_base + wb.side_share_step * (day - 2), wb.side_share_cap)

static func split(day: int, w: int, wb: WaveBalance) -> Dictionary:
	var total := total_count(day, w, wb)
	var side := 0
	if day >= 2:
		side = maxi(1, int(round(total * side_share(day, wb))))
	return {"main": total - side, "side": side}
