class_name StationEffects
extends RefCounted
## Station level -> value (E1 spec 5.2). Pure: no scene access, no GameState.

const IDS: Array[StringName] = [&"counter", &"freezer"]

static func _at(arr: Array, level: int) -> Variant:
	return arr[clampi(level, 0, arr.size() - 1)]

## Gold for the step from `level` to `level + 1`; -1 at max level.
static func level_cost(id: StringName, level: int, sb: StationBalance) -> int:
	assert(id in IDS, "unknown station %s" % id)
	if level >= sb.max_level:
		return -1
	var base := sb.counter_cost if id == &"counter" else sb.freezer_cost
	return int(round(base * pow(sb.cost_mult, level)))

static func queue_max(level: int, sb: StationBalance) -> int:
	return int(_at(sb.queue_max, level))

static func traveler_interval(level: int, sb: StationBalance) -> float:
	return float(_at(sb.traveler_interval, level))

static func service_time(level: int, sb: StationBalance) -> float:
	return float(_at(sb.service_time, level))

static func counter_capacity(level: int, sb: StationBalance) -> int:
	return int(_at(sb.counter_capacity, level))

static func carry_bonus(level: int, sb: StationBalance) -> int:
	return int(_at(sb.carry_bonus, level))

static func load_per_tick(level: int, sb: StationBalance) -> int:
	return int(_at(sb.load_per_tick, level))

## The largest carry the hero can ever have: every carry card plus a max-level freezer.
static func max_carry(hb: HeroBalance, cb: CardBalance, sb: StationBalance) -> int:
	return hb.carry_capacity + cb.carry_step * cb.max_level + carry_bonus(sb.max_level, sb)

## Travelers alive at once at max level: a full queue, plus the ones still walking out, plus a margin.
static func traveler_pool_size(sb: StationBalance, eb: EconomyBalance) -> int:
	var walk_out := MapLayout.SERVICE_POINT.distance_to(MapLayout.TRAVELER_EXIT) / eb.traveler_speed
	return queue_max(sb.max_level, sb) + int(ceil(walk_out / service_time(sb.max_level, sb))) + 2
