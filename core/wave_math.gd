class_name WaveMath
extends RefCounted
## Wave sizes and HP (spec 6.2, D-027, D-053, D-100). Since E5 (spec 4.1) every function takes the PRESSURE, not the
## day: pressure(day, tier, tier_day) ramps from the tier's base and stops at its cap. At tier 1 pressure == day for
## days 1 to 7 (D-237).

static func pressure(day: int, tier: int, tier_day: int, tb: TierBalance) -> int:
	return clampi(tb.tier_base[tier] + (day - tier_day), tb.tier_base[tier], tb.tier_cap[tier])

static func raw_total(pressure: int, w: int, wb: WaveBalance) -> int:
	return int(round(wb.base_counts[w] * (1.0 + wb.count_growth * (pressure - 1))))

static func total_count(pressure: int, w: int, wb: WaveBalance) -> int:
	return mini(raw_total(pressure, w, wb), wb.max_wave_size)

static func hp_mult(pressure: int, w: int, wb: WaveBalance) -> float:
	var m := 1.0 + wb.hp_growth * (pressure - 1)
	var raw := raw_total(pressure, w, wb)
	if raw > wb.max_wave_size:
		m *= float(raw) / float(wb.max_wave_size)
	return m

static func side_share(pressure: int, wb: WaveBalance) -> float:
	if pressure < 2:
		return 0.0
	return minf(wb.side_share_base + wb.side_share_step * (pressure - 2), wb.side_share_cap)

static func split(pressure: int, w: int, wb: WaveBalance) -> Dictionary:
	var total := total_count(pressure, w, wb)
	var side := 0
	if pressure >= 2:
		side = maxi(1, int(round(total * side_share(pressure, wb))))
	return {"main": total - side, "side": side}
