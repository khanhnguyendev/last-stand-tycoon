class_name Targeting
extends RefCounted
## Nearest-in-range selection; strict (distance, spawn_index) order (D-034).

static func select(origin: Vector3, attack_range: float, candidates: Array) -> Dictionary:
	var best := {}
	var best_d := INF
	for c in candidates:
		var pos: Vector3 = c.position
		var d := Vector2(pos.x - origin.x, pos.z - origin.z).length()
		if d > attack_range:
			continue
		if best.is_empty() or d < best_d or (d == best_d and int(c.spawn_index) < int(best.spawn_index)):
			best = c
			best_d = d
	return best
