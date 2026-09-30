class_name WaveSchedule
extends RefCounted
## Spawn times for one wave and the clear rule (spec 7.1, D-044).

static func build(wave: Dictionary, wb: WaveBalance) -> Array:
	var out: Array = []
	for i in int(wave.main_count):
		out.append({"t": i * wb.spawn_interval, "lane": String(wave.main), "side": false})
	for i in int(wave.side_count):
		out.append({"t": wb.side_group_delay + i * wb.spawn_interval, "lane": String(wave.side), "side": true})
	out.sort_custom(func(a, b):
		if not is_equal_approx(a.t, b.t):
			return a.t < b.t
		return not a.side and b.side)
	return out

static func is_cleared(planned: int, spawned: int, alive: int) -> bool:
	return spawned >= planned and alive == 0
