class_name Economy
extends RefCounted
## Costs and yields (spec 8.6, 8.9, D-063, D-065, D-067).

static func base_cost(spot_id: String, bb: BuildBalance) -> int:
	return bb.tower_cost if MapLayout.spot_kind(spot_id) == "tower" else bb.fence_cost

static func level_cost(spot_id: String, level: int, bb: BuildBalance) -> int:
	if level >= bb.max_level:
		return -1
	return int(round(base_cost(spot_id, bb) * pow(bb.level_cost_mult, level)))

static func drain_per_tick(cost: int, bb: BuildBalance) -> int:
	return maxi(1, int(ceil(float(cost) / float(bb.drain_divisor))))
