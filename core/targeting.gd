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

## The in-range candidates in the same strict (distance, spawn_index) order `select` uses, the first `n` of them.
## `select_many(...)[0]` is exactly what `select(...)` returns for the same inputs; one entry per candidate, never repeated.
static func select_many(origin: Vector3, attack_range: float, candidates: Array, n: int) -> Array:
	var keyed: Array = []
	for c in candidates:
		var pos: Vector3 = c.position
		var d := Vector2(pos.x - origin.x, pos.z - origin.z).length()
		if d > attack_range:
			continue
		keyed.append([d, int(c.spawn_index), c])
	keyed.sort_custom(func(a, b): return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	var out: Array = []
	for i in mini(n, keyed.size()):
		out.append(keyed[i][2])
	return out
