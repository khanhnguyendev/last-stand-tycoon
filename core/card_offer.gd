class_name CardOffer
extends RefCounted
## Dawn card offers (S2 spec 4.3, D-166). The draw is pinned (golden test) so every build gives the same offers.

static func make(run_seed: int, day: int, levels: Dictionary, cb: CardBalance) -> Array[StringName]:
	var rng := Rng.stream(run_seed, day, &"cards")
	var out: Array[StringName] = []
	if not _any_picked(levels):
		out.append(&"archer")
		out.append(&"tank")
		out.append(CardCatalog.UPGRADES[rng.randi_range(0, CardCatalog.UPGRADES.size() - 1)])
		return out
	var pool: Array[StringName] = []
	for id in CardCatalog.IDS:
		if CardEffects.level_of(levels, id) < cb.max_level:
			pool.append(id)
	for i in mini(cb.offer_size, pool.size()):
		out.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
	return out

## "No card picked yet": no id at level >= 1 (a zero entry does not count).
static func _any_picked(levels: Dictionary) -> bool:
	for id in levels:
		if int(levels[id]) >= 1:
			return true
	return false
