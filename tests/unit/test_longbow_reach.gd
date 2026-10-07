extends GutTest
## E5 tier 3 (spec 4.1, D-261.5, D-271): a hero-built tower must never be able to shoot into a third lane. For every tower spot and
## every lane, the distance to the lane is the smaller of the distance to the lane's nearest stop point and to its fence spot; sorted,
## the THIRD smallest must exceed the Longbow range, so the longest-ranged tower reaches at most two lanes.

# replaced by Balance.data.branches.tower(&"longbow").range when Task 5 merges (main session wiring)
const LONGBOW_RANGE_FOR_TEST := 9.98

func before_each() -> void:
	Balance.reset()

func _stop_points(lane: String) -> Array:
	var eb := Balance.data.enemy
	var pts: Array = []
	var length := MapLayout.path_length(lane)
	for i in 41:
		pts.append(EnemyPath.position_at(lane, length, lerpf(-1.0, 1.0, i / 40.0) * eb.lateral_spread, eb.offset_fade_distance))
	return pts

func _lane_distance(tower: Vector2, lane: String) -> float:
	var best := tower.distance_to(MapLayout.fence_spot(lane))
	for q in _stop_points(lane):
		best = minf(best, tower.distance_to(q))
	return best

## {tower id: [sorted lane distances]} over the tier-3 towers and lanes.
func _sorted_distances() -> Dictionary:
	var out := {}
	for id in MapLayout.spots_for_tier(3):
		if MapLayout.spot_kind(id) != "tower":
			continue
		var d: Array = []
		for lane in MapLayout.lanes_for_tier(3):
			d.append(_lane_distance(MapLayout.tower_spot(id), lane))
		d.sort()
		out[id] = d
	return out

## Towers whose third-nearest lane is within `range`.
func _violations(range: float) -> Array:
	var bad: Array = []
	var all := _sorted_distances()
	for id in all:
		if float(all[id][2]) <= range:
			bad.append(id)
	return bad

func test_all_five_towers_and_four_lanes_are_checked() -> void:
	var all := _sorted_distances()
	assert_eq(all.keys(), ["tower_nw", "tower_ne", "tower_w", "tower_e", "tower_sw"])
	for id in all:
		assert_eq((all[id] as Array).size(), 4, id)

func test_the_third_nearest_lane_is_beyond_the_longbow_range() -> void:
	var all := _sorted_distances()
	var limit := INF
	for id in all:
		gut.p("%s: lane distances %s" % [id, (all[id] as Array).map(func(v): return snappedf(v, 0.01))])
		assert_gt(float(all[id][2]), LONGBOW_RANGE_FOR_TEST, "%s: the third lane is out of Longbow range" % id)
		limit = minf(limit, float(all[id][2]))
	gut.p("Longbow limit (smallest third-lane distance over all towers) = %.2f" % limit)
	assert_gte(limit, 10.2, "the margin over the range is visible: at least 10.2 m")

func test_the_rule_has_teeth() -> void:
	# a Longbow longer than the limit would reach a third lane from some tower (the tier-3 map is what holds it back)
	assert_eq(_violations(LONGBOW_RANGE_FOR_TEST), [])
	assert_false(_violations(10.5).is_empty(), "range 10.5 reaches a third lane")

func test_the_south_west_lane_pairs_only_with_west_for_the_towers_beside_it() -> void:
	# tower_sw's two nearest lanes are sw and west; no tower's two nearest lanes include both north and sw
	var all := _sorted_distances()
	var near_sw := _lane_distance(MapLayout.tower_spot("tower_sw"), "sw")
	var near_west := _lane_distance(MapLayout.tower_spot("tower_sw"), "west")
	assert_lt(near_sw, near_west)
	assert_lt(near_west, _lane_distance(MapLayout.tower_spot("tower_sw"), "north"))
	assert_lt(near_west, float(all["tower_sw"][2]))
