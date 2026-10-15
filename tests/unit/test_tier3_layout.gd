extends GutTest
## E5 tier 3 (spec 3.1, 4.1, 4.2, D-271): the south-west lane, its zone, fence, tower and plot, the tier-dependent service layout and
## the tier-3 graph are fixed by these tests; tiers 1 and 2 keep every constant (identity) and the shared dictionaries stay three-lane.

func before_each() -> void:
	Balance.reset()
	GameState.new_game(20260930)

func _edge_ends(g: WaypointGraph) -> int:
	var n := 0
	for k in g.edges:
		n += (g.edges[k] as Array).size()
	return n

func _bar(lane: String) -> Array:
	var path: Array = MapLayout.lane_path(lane)
	var t := Geometry.tangent_at(path, Geometry.path_length(path) - MapLayout.FENCE_OFFSET_FROM_END)
	var n := Vector2(-t.y, t.x)
	var f := MapLayout.fence_spot(lane)
	return [f - n * MapLayout.FENCE_BAR_HALF, f + n * MapLayout.FENCE_BAR_HALF]

func _line_dist(p: Vector2, path: Array) -> float:
	var best := INF
	for i in range(1, path.size()):
		best = minf(best, Geometry.dist_point_segment(p, path[i - 1], path[i]))
	return best

## Smallest distance from the segment a-b (sampled every 2 cm) to the segment c-d.
func _seg_to_seg(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> float:
	var best := INF
	var n := maxi(50, ceili(a.distance_to(b) / 0.02))
	for k in n + 1:
		best = minf(best, Geometry.dist_point_segment(a.lerp(b, float(k) / n), c, d))
	return best

# --- identity ---------------------------------------------------------------------------------------------------------------------

func test_tier_1_and_2_constants_are_frozen() -> void:
	assert_eq(MapLayout.SPOT_IDS, ["tower_nw", "tower_ne", "fence_w", "fence_n", "fence_e"])
	assert_eq(MapLayout.QUEUE_SLOTS, [Vector2(0, 6.0), Vector2(-1.2, 7.0), Vector2(-2.4, 8.0), Vector2(-3.6, 9.0),
		Vector2(-3.0, 10.3), Vector2(-1.8, 10.3), Vector2(-0.6, 10.3), Vector2(0.6, 10.3), Vector2(1.8, 10.3)])
	assert_eq(MapLayout.TRAVELER_EXIT, Vector2(-24, 11))
	assert_eq(MapLayout.TIER_SIGN, Vector2(-10.0, 7.5))
	assert_eq(LanePlanner.LANES, ["west", "north", "east"] as Array[String])
	assert_eq(MapLayout.TIER_SPOTS[2], ["tower_w", "tower_e"])

func test_the_shared_dictionaries_stay_three_lane() -> void:
	# art/env/ground.gd and lane_strip.gd iterate LANE_PATHS by key: a fourth key would draw the SW strip at tier 1
	for d in [MapLayout.LANE_PATHS, MapLayout.ZONE_RECTS, MapLayout.ZONE_AXIS, MapLayout.LANE_FENCE]:
		var keys: Array = d.keys()
		keys.sort()
		assert_eq(keys, ["east", "north", "west"])
	var spots: Array = MapLayout.TOWER_SPOTS.keys()
	spots.sort()
	assert_eq(spots, ["tower_e", "tower_ne", "tower_nw", "tower_w"])
	var fences: Array = MapLayout.FENCE_LANE.keys()
	fences.sort()
	assert_eq(fences, ["fence_e", "fence_n", "fence_w"])
	assert_eq(MapLayout.TOWER_LANES.size(), 4)
	var yards: Array = MapLayout.YARDS.keys()
	yards.sort()
	assert_eq(yards, ["east", "west"])
	assert_eq(MapLayout.LANE_PATHS["west"], [Vector2(-16, -24), Vector2(-11, -11), Vector2(-5.2, 0)])

func test_getters_return_today_s_values_below_tier_3() -> void:
	for tier in [1, 2]:
		assert_eq(MapLayout.lanes_for_tier(tier), ["west", "north", "east"] as Array[String])
		assert_eq(MapLayout.queue_slots(tier), MapLayout.QUEUE_SLOTS)
		assert_eq(MapLayout.traveler_exit(tier), MapLayout.TRAVELER_EXIT)
	assert_eq(MapLayout.tier_sign(2), MapLayout.TIER_SIGN)
	assert_eq(MapLayout.spots_for_tier(1), MapLayout.SPOT_IDS)
	assert_eq(MapLayout.spots_for_tier(2), ["tower_nw", "tower_ne", "fence_w", "fence_n", "fence_e", "tower_w", "tower_e"])
	assert_eq(MapLayout.yards_for_tier(1), [])
	assert_eq(MapLayout.yards_for_tier(2), ["west", "east"])
	for lane in MapLayout.lanes_for_tier(2):
		assert_eq(MapLayout.lane_path(lane), MapLayout.LANE_PATHS[lane])
		assert_eq(MapLayout.zone_rect(lane), MapLayout.ZONE_RECTS[lane])
		assert_eq(MapLayout.zone_axis(lane), MapLayout.ZONE_AXIS[lane])
		assert_eq(MapLayout.lane_fence(lane), MapLayout.LANE_FENCE[lane])

func test_graphs_below_tier_3_are_unchanged() -> void:
	# counts captured before E5 tier 3 (nodes, summed edge ends)
	var d := WaypointGraph.create_default()
	assert_eq([d.nodes.size(), _edge_ends(d)], [19, 54])
	var one := WaypointGraph.create_for_tier(1)
	assert_eq([one.nodes.size(), _edge_ends(one)], [19, 54])
	assert_eq(one.nodes, d.nodes)
	assert_eq(one.edges, d.edges)
	var two := WaypointGraph.create_for_tier(2)
	assert_eq([two.nodes.size(), _edge_ends(two)], [22, 64])
	for n in ["tower_sw", "fence_sw", "tier_sign_3"]:
		assert_false(two.nodes.has(n), "%s only exists in the tier-3 graph" % n)

# --- the lane, zone, fence, tower, plot -------------------------------------------------------------------------------------------

func test_lanes_and_spots_per_tier() -> void:
	assert_eq(MapLayout.lanes_for_tier(3), ["west", "north", "east", "sw"] as Array[String])
	assert_eq(MapLayout.lanes_for_tier(4), MapLayout.lanes_for_tier(3))
	assert_eq(MapLayout.spots_for_tier(3), MapLayout.spots_for_tier(2) + ["tower_sw", "fence_sw"])
	assert_eq(MapLayout.ALL_SPOT_IDS, MapLayout.spots_for_tier(4), "ALL_SPOT_IDS lists every spot of the build; tier 3's are its first nine")
	assert_eq(MapLayout.spots_for_tier(4), MapLayout.spots_for_tier(3) + ["tower_n2", "tower_e2"])
	assert_eq(MapLayout.TIER_SPOTS[4], ["tower_n2", "tower_e2"])
	assert_eq([MapLayout.spot_tier("tower_n2"), MapLayout.spot_tier("tower_e2")], [4, 4])
	assert_eq(MapLayout.yards_for_tier(4), ["west", "east", "front", "north", "northeast"])
	assert_eq([MapLayout.spot_tier("tower_sw"), MapLayout.spot_tier("fence_sw")], [3, 3])
	assert_eq([MapLayout.spot_kind("tower_sw"), MapLayout.spot_kind("fence_sw")], ["tower", "fence"])
	assert_eq(MapLayout.TIER_SPOTS[3], ["tower_sw", "fence_sw"])
	assert_eq(MapLayout.yards_for_tier(3), ["west", "east", "front"])

func test_the_south_west_lane_is_the_spec_s() -> void:
	assert_eq(MapLayout.lane_path("sw"), [Vector2(-24, 11), Vector2(-3.5, 11.0), Vector2(-2.75, 5.2)])
	assert_almost_eq(MapLayout.path_length("sw"), 26.35, 0.01)
	assert_eq(MapLayout.lane_end("sw"), Vector2(-2.75, 5.2))
	assert_eq(MapLayout.zone_rect("sw"), Rect2(-4.0, 4.0, 2.5, 1.2))
	assert_eq(MapLayout.zone_axis("sw"), Vector2(1, 0))
	assert_eq(MapLayout.tower_spot("tower_sw"), Vector2(-6.6, 5.6))
	assert_eq(MapLayout.tower_lanes("tower_sw"), ["sw"], "only the lane it reaches at level 1; west is its second lane by distance only")
	assert_eq(MapLayout.fence_lane("fence_sw"), "sw")
	assert_eq(MapLayout.lane_fence("sw"), "fence_sw")
	assert_eq(MapLayout.spot_position("tower_sw"), MapLayout.tower_spot("tower_sw"))
	assert_eq(MapLayout.spot_position("fence_sw"), MapLayout.fence_spot("sw"))

func test_the_fence_spot_is_four_metres_back_on_the_last_segment() -> void:
	var f := MapLayout.fence_spot("sw")
	assert_almost_eq(f.x, -3.263, 0.01)
	assert_almost_eq(f.y, 9.167, 0.01)
	# re-derived: walk back from the end along the last segment
	var path: Array = MapLayout.lane_path("sw")
	var end: Vector2 = path[2]
	var seg: Vector2 = (path[1] as Vector2 - end).normalized()
	assert_true(f.is_equal_approx(end + seg * MapLayout.FENCE_OFFSET_FROM_END))
	assert_almost_eq(MapLayout.telegraph_spot("sw").distance_to(f), 1.5, 0.001)

func test_enemy_path_reads_the_south_west_lane() -> void:
	var eb := Balance.data.enemy
	assert_eq(EnemyPath.position_at("sw", 0.0, 0.0, eb.offset_fade_distance), Vector2(-24, 11))
	assert_true(EnemyPath.position_at("sw", 1000.0, 0.0, eb.offset_fade_distance).is_equal_approx(Vector2(-2.75, 5.2)))
	var side := EnemyPath.position_at("sw", 1000.0, eb.lateral_spread, eb.offset_fade_distance)
	assert_true(side.is_equal_approx(Vector2(-1.75, 5.2)), "a full offset lands on the zone axis (1, 0): %s" % side)

func test_the_plot_owns_the_tower_the_fence_and_the_tier_3_sign() -> void:
	var plot := MapLayout.yard_rect("front")
	assert_eq(plot, Rect2(-7.6, 5.6, 6.1, 4.3))
	assert_eq(MapLayout.yard_tier("front"), 3)
	assert_true(plot.has_point(MapLayout.tower_spot("tower_sw")), "the tower stands on the plot")
	assert_true(plot.has_point(MapLayout.fence_spot("sw")))
	assert_true(plot.has_point(MapLayout.tier_sign(3)), "the sign stands on the land it sells (D-240)")
	for id in MapLayout.yards_for_tier(2):
		assert_false(plot.intersects(MapLayout.yard_rect(id)), "the plot overlaps the %s yard" % id)
	for lane in MapLayout.lanes_for_tier(3):
		assert_false(plot.intersects(MapLayout.zone_rect(lane)), "the plot overlaps the %s zone" % lane)
	for b in [Rect2(-4, -4, 8, 8), Rect2(MapLayout.COUNTER - MapLayout.COUNTER_SIZE / 2, MapLayout.COUNTER_SIZE)]:
		assert_false(plot.intersects(b), "the plot overlaps a body")
	assert_true(Rect2(MapLayout.BOUNDS_MIN, MapLayout.BOUNDS_MAX - MapLayout.BOUNDS_MIN).encloses(plot), "inside the bounds")
	assert_true(World.ground_rect().encloses(plot), "on the ground")

func test_the_tier_3_sign_is_off_the_exit_line_the_zone_and_the_fence_spot() -> void:
	var s := MapLayout.tier_sign(3)
	assert_eq(s, Vector2(-4.7, 8.5))
	# today's west exit line: the traveler walks from the service point to TRAVELER_EXIT (a tier 1 and 2 walk, and a tier-2 sign position)
	var exit_line := _seg_to_seg(s, s, MapLayout.SERVICE_POINT, MapLayout.TRAVELER_EXIT)
	gut.p("tier-3 sign to today's west exit line: %.2f m" % exit_line)
	assert_gt(exit_line, MapLayout.STATION_RADIUS + MapLayout.HERO_RADIUS, "the sign is off the exit line")
	assert_gt(Geometry.dist_point_rect(s, MapLayout.zone_rect("sw")), MapLayout.STATION_RADIUS, "outside the SW zone")
	# Fix round 1 ruling A: the sign is gone once tier 3 is bought and the fence does not exist before, so they never coexist: the sign only keeps off the
	# future pad's circle (BUILD_RADIUS), no longer sign radius + pad radius (was > 2.2 from the spot centre and > 0.5 from the bar).
	assert_gt(s.distance_to(MapLayout.fence_spot("sw")), MapLayout.BUILD_RADIUS, "off the SW fence spot's pad")
	assert_gt(s.distance_to(MapLayout.tower_spot("tower_sw")), MapLayout.STATION_RADIUS + MapLayout.BUILD_RADIUS, "off the SW tower's pad")
	var bar := _bar("sw")
	assert_gt(Geometry.dist_point_segment(s, bar[0], bar[1]), 0.3, "not on the fence bar (nearest tip)")
	for lane in MapLayout.lanes_for_tier(2):
		assert_gte(_line_dist(s, MapLayout.lane_path(lane)) - MapLayout.STATION_RADIUS, Balance.data.enemy.lateral_spread + 1.0, "clear of the %s lane" % lane)
	assert_eq(MapLayout.TIER_SIGNS.keys(), [2, 3, 4])

func test_signs_exist_only_for_tiers_2_to_4() -> void:
	# tier_sign(1) and tier_sign(5) assert with "no sign sells tier N" (an assert cannot run inside a test); has_tier_sign guards callers
	assert_eq([1, 2, 3, 4, 5].map(func(t): return MapLayout.has_tier_sign(t)), [false, true, true, true, false])
	assert_eq(MapLayout.tier_sign(2), MapLayout.TIER_SIGN)
	assert_eq(MapLayout.tier_sign(3), Vector2(-4.7, 8.5))
	assert_ne(MapLayout.tier_sign(2), MapLayout.tier_sign(3))

# --- the tier-dependent service layout --------------------------------------------------------------------------------------------

func test_today_s_queue_slots_sit_on_the_south_west_lane() -> void:
	# why the layout is tier-dependent: slots 2 to 4 would stand on the lane or in the fence at tier 3
	var need: float = Balance.data.enemy.lateral_spread + MapLayout.HERO_RADIUS
	var bar := _bar("sw")
	var bad := 0
	for q in MapLayout.QUEUE_SLOTS:
		if _line_dist(q, MapLayout.lane_path("sw")) < need or Geometry.dist_point_segment(q, bar[0], bar[1]) < MapLayout.HERO_RADIUS + 0.3:
			bad += 1
	assert_gte(bad, 3, "slots of tiers 1 and 2 would block the south-west lane")
	var worst := INF
	for q in MapLayout.QUEUE_SLOTS:
		worst = minf(worst, Geometry.dist_point_segment(q, bar[0], bar[1]))
	assert_lt(worst, 0.2, "the worst is 0.12 m from the bar")

func test_tier_3_queue_slots() -> void:
	var slots: Array = MapLayout.queue_slots(3)
	assert_eq(slots, [Vector2(0, 6.0), Vector2(1.1, 6.9), Vector2(1.3, 8.0), Vector2(1.4, 9.1), Vector2(1.8, 10.3),
		Vector2(3.0, 10.3), Vector2(4.2, 10.3), Vector2(5.4, 10.3), Vector2(6.6, 10.3)])
	assert_eq(slots.size(), MapLayout.QUEUE_SLOTS.size())
	assert_eq(slots[0], MapLayout.SERVICE_POINT, "the first slot is the service point")
	var spread: float = Balance.data.enemy.lateral_spread
	var bar := _bar("sw")
	var diner := Rect2(-4, -4, 8, 8)
	for i in slots.size():
		var q: Vector2 = slots[i]
		assert_gt(_line_dist(q, MapLayout.lane_path("sw")), spread + MapLayout.HERO_RADIUS, "slot %d off the SW lane" % i)
		assert_gt(Geometry.dist_point_rect(q, MapLayout.zone_rect("sw")), MapLayout.HERO_RADIUS, "slot %d outside the SW zone" % i)
		assert_gt(q.distance_to(MapLayout.fence_spot("sw")), MapLayout.HERO_RADIUS + 1.0, "slot %d off the SW fence spot" % i)
		assert_gt(Geometry.dist_point_segment(q, bar[0], bar[1]), MapLayout.HERO_RADIUS + 1.0, "slot %d clear of the fence bar" % i)
		assert_gt(Geometry.dist_point_rect(q, diner), MapLayout.HERO_RADIUS, "slot %d off the diner" % i)
		for lane in MapLayout.lanes_for_tier(3):
			assert_gt(Geometry.dist_point_rect(q, MapLayout.zone_rect(lane)), 0.0, "slot %d in the %s zone" % [i, lane])
		if i > 0:
			assert_gte(q.distance_to(slots[i - 1]), 1.0, "slots %d and %d are not stacked" % [i - 1, i])
	# nearest items (spec 4.2): the counter pad 1.53 m, the close-up sign 1.30 m, HOME 1.46 m
	var near_pad := INF
	var near_sign := INF
	var near_home := INF
	for q in slots:
		near_pad = minf(near_pad, q.distance_to(MapLayout.STATION_PADS[&"counter"]))
		near_sign = minf(near_sign, q.distance_to(MapLayout.SIGN))
		near_home = minf(near_home, q.distance_to(MapLayout.HOME))
	gut.p("slots: counter pad %.2f, close-up sign %.2f, HOME %.2f" % [near_pad, near_sign, near_home])
	assert_gt(near_pad, MapLayout.HERO_RADIUS + 1.0)
	assert_gt(near_sign, MapLayout.HERO_RADIUS + 0.5)
	assert_gt(near_home, MapLayout.HERO_RADIUS + 0.5)

func test_the_rest_of_the_service_layout_clears_the_south_west_lane() -> void:
	var spread: float = Balance.data.enemy.lateral_spread
	var bar := _bar("sw")
	var stations := {"HOME": [MapLayout.HOME, 0.0], "close-up sign": [MapLayout.SIGN, MapLayout.STATION_RADIUS],
		"counter drop": [MapLayout.COUNTER_DROP, MapLayout.STATION_RADIUS], "freezer zone": [MapLayout.FREEZER_ZONE, MapLayout.STATION_RADIUS],
		"counter pad": [MapLayout.STATION_PADS[&"counter"], MapLayout.BUILD_RADIUS], "freezer pad": [MapLayout.STATION_PADS[&"freezer"], MapLayout.BUILD_RADIUS],
		"tier-3 sign": [MapLayout.tier_sign(3), 0.0]}
	for n in stations:
		var p: Vector2 = stations[n][0]
		var r: float = stations[n][1]
		assert_gt(_line_dist(p, MapLayout.lane_path("sw")), spread + maxf(r, MapLayout.HERO_RADIUS), "%s off the SW lane" % n)
		assert_gt(Geometry.dist_point_rect(p, MapLayout.zone_rect("sw")), r, "%s outside the SW zone" % n)
		assert_gt(p.distance_to(MapLayout.fence_spot("sw")), r + MapLayout.HERO_RADIUS, "%s off the SW fence spot" % n)
		# the tier-3 sign and the fence never coexist (ruling A, fix round 1): it keeps 0.3 m from the bar's tip, the others the hero's radius
		assert_gt(Geometry.dist_point_segment(p, bar[0], bar[1]), 0.3 if n == "tier-3 sign" else MapLayout.HERO_RADIUS, "%s off the SW fence bar" % n)
	# the two documented exceptions (spec 4.2): the gold pile is 0.29 m from the lane line (it is empty at night, another task proves it)
	# and the diner door stands strictly INSIDE the SW zone (the guards' respawn, never a hero stand point at night)
	assert_true(MapLayout.zone_rect("sw").has_point(MapLayout.DINER_DOOR), "the door is inside the SW zone")
	assert_almost_eq(_line_dist(MapLayout.GOLD_PILE, MapLayout.lane_path("sw")), 0.29, 0.02, "the gold pile is 0.29 m from the lane line")
	assert_almost_eq(_line_dist(MapLayout.DINER_DOOR, MapLayout.lane_path("sw")), 0.65, 0.02, "the door is 0.65 m from the lane line")

func test_traveler_lines_clear_every_fence_bar_per_tier() -> void:
	var need := 1.0
	for tier in [1, 2, 3]:
		var slots: Array = MapLayout.queue_slots(tier)
		var out := MapLayout.traveler_exit(tier)
		for lane in MapLayout.lanes_for_tier(tier):
			var bar := _bar(lane)
			for q in slots:
				assert_gt(_seg_to_seg(MapLayout.TRAVELER_ENTER, q, bar[0], bar[1]), need, "tier %d: the entry line to %s crosses the %s fence" % [tier, q, lane])
			assert_gt(_seg_to_seg(MapLayout.SERVICE_POINT, out, bar[0], bar[1]), need, "tier %d: the exit line crosses the %s fence" % [tier, lane])
	var bar := _bar("sw")
	var exit_m := _seg_to_seg(MapLayout.SERVICE_POINT, MapLayout.traveler_exit(3), bar[0], bar[1])
	gut.p("tier-3 exit line to the SW fence bar: %.2f m" % exit_m)
	assert_almost_eq(exit_m, 3.8, 0.1)

func test_the_tier_3_exit_is_the_entry_point_and_today_s_west_exit_would_not_do() -> void:
	assert_eq(MapLayout.traveler_exit(3), MapLayout.TRAVELER_ENTER)
	var tower := MapLayout.tower_spot("tower_sw")
	var west_exit := _seg_to_seg(MapLayout.SERVICE_POINT, MapLayout.TRAVELER_EXIT, tower, tower)
	var east_exit := _seg_to_seg(MapLayout.SERVICE_POINT, MapLayout.traveler_exit(3), tower, tower)
	gut.p("SW tower to today's west exit line %.2f m, to the tier-3 exit line %.2f m" % [west_exit, east_exit])
	assert_almost_eq(west_exit, 1.74, 0.05, "today's west exit line to tower_sw, centre distance")
	assert_almost_eq(west_exit - MapLayout.BUILD_RADIUS, 0.54, 0.05, "and clear of the tower's pad by only this much")
	assert_gt(east_exit, west_exit + 3.0, "the tier-3 exit is far from it")

# --- save validation --------------------------------------------------------------------------------------------------------------

func test_a_tier_3_spot_is_rejected_in_a_tier_2_save() -> void:
	GameState.debug_set_tier(2, 1)
	var s := GameState.to_dict()
	s.buildings["tower_sw"] = {"level": 0, "paid": 0, "hp": 0.0}
	assert_eq(SaveCodec.validate(s, Balance.data), "building tier tower_sw", "spot_tier 3 is above the known tier 2")
	s = GameState.to_dict()
	s.buildings["fence_sw"] = {"level": 0, "paid": 0, "hp": 0.0}
	assert_eq(SaveCodec.validate(s, Balance.data), "building tier fence_sw")
	s = GameState.to_dict()
	s.buildings["castle"] = {"level": 0, "paid": 0, "hp": 0.0}
	assert_eq(SaveCodec.validate(s, Balance.data), "building castle", "an unknown id is still unknown")

# --- the graph --------------------------------------------------------------------------------------------------------------------

func test_the_tier_3_graph_reaches_every_new_node() -> void:
	var g := WaypointGraph.create_for_tier(3)
	var two := WaypointGraph.create_for_tier(2)
	assert_eq(g.nodes.size(), two.nodes.size() + 3 + 18)
	for n in two.nodes:
		assert_eq(g.position_of(n), two.position_of(n), "%s keeps its position" % n)
	for n in ["tower_sw", "fence_sw", "tier_sign_3"]:
		assert_false(g.shortest("home", n).is_empty(), "home reaches %s" % n)
	assert_eq(g.position_of("fence_sw"), MapLayout.fence_spot("sw"))
	assert_eq(g.position_of("tier_sign_3"), MapLayout.tier_sign(3))
	assert_lte(g.position_of("tower_sw").distance_to(MapLayout.tower_spot("tower_sw")), MapLayout.BUILD_RADIUS)
	assert_gte(g.position_of("tower_sw").distance_to(MapLayout.tower_spot("tower_sw")), MapLayout.TOWER_VISUAL_RADIUS)
	for id in MapLayout.BRANCH_PADS:
		if MapLayout.spot_tier(id) > 3:
			continue  # the back lot's pads are in the tier-4 graph only (E8 B1)
		for i in 2:
			var pad_name := "pad_%s_%s" % [id, "ab"[i]]
			assert_true(g.nodes.has(pad_name), pad_name)
			assert_eq(g.position_of(pad_name), (MapLayout.BRANCH_PADS[id] as Array)[i])
			assert_false(g.shortest("home", pad_name).is_empty(), "home reaches %s" % pad_name)

func test_the_tier_3_edges_clear_the_colliders() -> void:
	var g := WaypointGraph.create_for_tier(3)
	var two := WaypointGraph.create_for_tier(2)
	var bodies := [Rect2(-4, -4, 8, 8), Rect2(MapLayout.COUNTER - MapLayout.COUNTER_SIZE / 2, MapLayout.COUNTER_SIZE),
		Rect2(MapLayout.FREEZER - MapLayout.FREEZER_SIZE / 2, MapLayout.FREEZER_SIZE)]
	var checked := 0
	for a in g.edges:
		for b in g.edges[a]:
			if two.edges.has(a) and (two.edges[a] as Array).has(b):
				continue
			checked += 1
			var pa: Vector2 = g.position_of(a)
			var pb: Vector2 = g.position_of(b)
			var n := maxi(50, ceili(pa.distance_to(pb) / 0.05))
			for k in n + 1:
				var p := pa.lerp(pb, float(k) / n)
				for body in bodies:
					assert_true(Geometry.dist_point_rect(p, body) >= MapLayout.HERO_RADIUS - 0.01, "edge %s-%s hits a collider at %s" % [a, b, p])
	assert_gt(checked, 40, "the new edges were checked")

func test_tier_3_spots_are_clear_of_the_tier_2_kerb() -> void:
	# the tier-2 yard kerb is untouched: the new spots' pads stay more than PAD_CLEAR from every tier-2 yard rect
	for id in MapLayout.TIER_SPOTS[3]:
		for y in MapLayout.yards_for_tier(2):
			assert_gt(Geometry.dist_point_rect(MapLayout.spot_position(id), MapLayout.yard_rect(y)), YardStones.PAD_CLEAR, "%s vs the %s yard" % [id, y])

# --- E8 phase 2 Task 6 (spec 4.3, D-314.5): the back lot --------------------------------------------------------------------------
# Two parcels: "north" (tower_n2, north of the diner beside the north lane) and "northeast" (tower_e2 and the tier-4 sign, north of the east yard). Every number is
# pinned here, as D-240 asks; the clearances are the rules of the tier-2 yards and the tier-3 lot, over the tier-4 map.

const T4_TOWERS := ["tower_n2", "tower_e2"]
const ASPECTS_T4 := [9.0 / 21.0, 720.0 / 1280.0, 16.0 / 9.0]

func _t4_lane_dist(p: Vector2) -> float:
	var best := INF
	for lane in MapLayout.lanes_for_tier(4):
		best = minf(best, _line_dist(p, MapLayout.lane_path(lane)))
	return best

func _t4_rect_lane_dist(r: Rect2) -> float:
	var best := INF
	var x := r.position.x
	while x <= r.end.x + 1e-6:
		best = minf(best, minf(_t4_lane_dist(Vector2(x, r.position.y)), _t4_lane_dist(Vector2(x, r.end.y))))
		x += 0.05
	var z := r.position.y
	while z <= r.end.y + 1e-6:
		best = minf(best, minf(_t4_lane_dist(Vector2(r.position.x, z)), _t4_lane_dist(Vector2(r.end.x, z))))
		z += 0.05
	return best

## [centre, radius, what] of everything that exists at tier 4 and a spot's build circle (BUILD_RADIUS) must stay outside of.
func _t4_obstacles() -> Array:
	var out := [[MapLayout.SIGN, MapLayout.STATION_RADIUS, "close-up sign"], [MapLayout.FREEZER_ZONE, MapLayout.STATION_RADIUS, "freezer zone"],
		[MapLayout.COUNTER_DROP, MapLayout.STATION_RADIUS, "counter drop"], [MapLayout.GOLD_PILE, Balance.data.hero.magnet_radius, "gold pile"],
		[MapLayout.HOME, 0.0, "HOME"], [MapLayout.NIGHT1_START, 0.0, "night-1 start"], [MapLayout.DINER_DOOR, MapLayout.STATION_RADIUS, "door"],
		[MapLayout.guard_post(&"tank"), Balance.data.guards.tank.body_radius, "tank post"], [MapLayout.guard_post(&"archer"), 0.0, "archer post"]]
	for id in MapLayout.STATION_PADS:
		out.append([MapLayout.STATION_PADS[id], MapLayout.BUILD_RADIUS, "station pad"])
	for q in MapLayout.queue_slots(3):
		out.append([q, 0.3, "queue slot"])
	for id in MapLayout.spots_for_tier(3):
		out.append([MapLayout.spot_position(id), MapLayout.BUILD_RADIUS, id])
	return out

## The tier-3 pads a new tower keeps clear of: pad radius + the tower's mesh radius + 0.1 m (tower_ne is 1.56 m from fence_e's pad centre; the
## precedent never put a build circle outside a neighbour's pad, so the rule is the pad rule's own: a pad keeps a tower's mesh off it).
func _t4_pads() -> Array:
	var out := []
	for id in MapLayout.spots_for_tier(3):
		for p in MapLayout.BRANCH_PADS[id]:
			out.append([p, MapLayout.BRANCH_PAD_RADIUS, "pad of " + id])
	return out

func _t4_road_lines() -> Array:
	var out: Array = [[MapLayout.SERVICE_POINT, MapLayout.traveler_exit(3)]]
	for q in MapLayout.queue_slots(3):
		out.append([MapLayout.TRAVELER_ENTER, q])
	var tp := MapLayout.tank_return_path()
	for i in range(1, tp.size()):
		out.append([tp[i - 1], tp[i]])
	return out

func test_t4_the_towers_clear_the_lanes_and_everything_that_exists() -> void:
	var need: float = Balance.data.enemy.lateral_spread + 1.0
	for id in T4_TOWERS:
		var t := MapLayout.spot_position(id)
		assert_gte(_t4_lane_dist(t) - MapLayout.TOWER_VISUAL_RADIUS, need, "%s clears the lanes by lateral_spread + 1 m" % id)
		for o in _t4_obstacles():
			assert_gt(t.distance_to(o[0]), MapLayout.BUILD_RADIUS + float(o[1]), "%s build circle overlaps %s" % [id, o[2]])
		for lane in MapLayout.lanes_for_tier(4):
			assert_gt(Geometry.dist_point_rect(t, MapLayout.zone_rect(lane)), MapLayout.BUILD_RADIUS, "%s in the %s zone" % [id, lane])
			var bar := _bar(lane)
			assert_gt(Geometry.dist_point_segment(t, bar[0], bar[1]), MapLayout.BUILD_RADIUS, "%s on the %s fence bar" % [id, lane])
		for b in [Rect2(-4, -4, 8, 8), Rect2(MapLayout.COUNTER - MapLayout.COUNTER_SIZE / 2, MapLayout.COUNTER_SIZE), Rect2(MapLayout.FREEZER - MapLayout.FREEZER_SIZE / 2, MapLayout.FREEZER_SIZE)]:
			assert_gt(Geometry.dist_point_rect(t, b), MapLayout.BUILD_RADIUS + MapLayout.HERO_RADIUS, "%s too close to a body" % id)
		for line in _t4_road_lines():
			assert_gt(Geometry.dist_point_segment(t, line[0], line[1]), MapLayout.BUILD_RADIUS, "%s build circle on a traveler or tank line" % id)
		for y in MapLayout.yards_for_tier(3):
			# the east yard's kerb: tower_e2 is 1.7 m off it, inside PAD_CLEAR (1.85), so the kerb leaves a gap there (a spot at a yard edge always does;
			# test_branch_pad_layout pins the gap); every other yard keeps the full PAD_CLEAR, and no kerb piece is under any build circle
			var kerb_need: float = MapLayout.BUILD_RADIUS + YardStones.WIDTH * 0.5 if (id == "tower_e2" and y == "east") else YardStones.PAD_CLEAR
			assert_gt(Geometry.dist_point_rect(t, MapLayout.yard_rect(y)), kerb_need, "%s vs the %s yard's kerb" % [id, y])
		for pd in _t4_pads():
			assert_gte(t.distance_to(pd[0]), float(pd[1]) + MapLayout.TOWER_VISUAL_RADIUS + 0.1, "%s on %s" % [id, pd[2]])
		for other in MapLayout.spots_for_tier(4):
			if other != id:
				assert_gt(t.distance_to(MapLayout.spot_position(other)), 2.0 * MapLayout.BUILD_RADIUS, "%s and %s build circles overlap" % [id, other])

func test_t4_the_pinned_coordinates() -> void:
	assert_eq(MapLayout.tower_spot("tower_n2"), Vector2(-5.0, -11.0))
	assert_eq(MapLayout.tower_spot("tower_e2"), Vector2(9.6, -2.2))
	assert_eq(MapLayout.tower_lanes("tower_n2"), ["north"])
	assert_eq(MapLayout.tower_lanes("tower_e2"), ["east"])
	assert_eq(MapLayout.yard_rect("north"), Rect2(-8.2, -13.6, 4.8, 3.2))
	assert_eq(MapLayout.yard_rect("northeast"), Rect2(9.1, -2.8, 4.6, 1.3))
	assert_eq([MapLayout.yard_tier("north"), MapLayout.yard_tier("northeast")], [4, 4])
	assert_eq(MapLayout.tier_sign(4), Vector2(13.0, -2.2))
	assert_eq(MapLayout.spot_kind("tower_n2"), "tower")
	assert_eq(MapLayout.spot_position("tower_n2"), MapLayout.tower_spot("tower_n2"), "spot_position knows TOWER_SPOTS_T4")
	assert_eq(MapLayout.spot_position("tower_e2"), MapLayout.tower_spot("tower_e2"))
	assert_eq(MapLayout.all_yards(), ["west", "east", "front", "north", "northeast"])
	# the shared and tier-3 dictionaries do not hold the back lot (D-271, D-277)
	for d in [MapLayout.TOWER_SPOTS, MapLayout.TOWER_LANES, MapLayout.TOWER_SPOTS_T3, MapLayout.TOWER_LANES_T3, MapLayout.YARDS, MapLayout.YARDS_T3]:
		for id in T4_TOWERS + ["north", "northeast"]:
			assert_false(d.has(id), "%s is in a lower tier's table" % id)

func test_t4_the_yards_are_on_the_land_clear_of_lanes_zones_bodies_and_other_yards() -> void:
	var need: float = Balance.data.enemy.lateral_spread + 1.0
	var play := Rect2(MapLayout.BOUNDS_MIN, MapLayout.BOUNDS_MAX - MapLayout.BOUNDS_MIN)
	for id in ["north", "northeast"]:
		var r := MapLayout.yard_rect(id)
		assert_gte(_t4_rect_lane_dist(r), need, "%s yard clears the lanes by %.2f" % [id, need])
		assert_true(play.encloses(r), "%s inside the bounds" % id)
		assert_true(World.ground_rect().encloses(r), "%s on the ground" % id)
		for lane in MapLayout.lanes_for_tier(4):
			assert_false(r.intersects(MapLayout.zone_rect(lane)), "%s overlaps the %s zone" % [id, lane])
		for b in [Rect2(-4, -4, 8, 8), Rect2(MapLayout.COUNTER - MapLayout.COUNTER_SIZE / 2, MapLayout.COUNTER_SIZE), Rect2(MapLayout.FREEZER - MapLayout.FREEZER_SIZE / 2, MapLayout.FREEZER_SIZE)]:
			assert_false(r.intersects(b.grow(MapLayout.HERO_RADIUS)), "%s overlaps a body" % id)
		for other in MapLayout.all_yards():
			if other != id:
				assert_false(r.grow(0.5).intersects(MapLayout.yard_rect(other)), "%s is within 0.5 m of the %s yard" % [id, other])
		for o in _t4_obstacles():
			assert_gt(Geometry.dist_point_rect(o[0], r), float(o[1]), "%s yard overlaps %s" % [id, o[2]])
		for pd in _t4_pads():  # the tier-3 pads: a yard keeps off every pad's circle (the northeast one first overlapped fence_e's second pad)
			assert_gt(Geometry.dist_point_rect(pd[0], r), float(pd[1]), "%s yard overlaps %s" % [id, pd[2]])
		for line in _t4_road_lines():
			for k in 21:
				var p: Vector2 = (line[0] as Vector2).lerp(line[1], k / 20.0)
				assert_false(r.has_point(p), "%s yard crosses a traveler or tank line at %s" % [id, p])

func test_t4_every_tower_and_the_sign_stand_on_their_land() -> void:
	assert_true(MapLayout.yard_rect("north").grow(-MapLayout.TOWER_VISUAL_RADIUS).has_point(MapLayout.spot_position("tower_n2")), "tower_n2 on the north yard")
	assert_true(MapLayout.yard_rect("northeast").grow(-MapLayout.TOWER_VISUAL_RADIUS).has_point(MapLayout.spot_position("tower_e2")), "tower_e2 on the north-east yard")
	assert_true(MapLayout.yard_rect("northeast").has_point(MapLayout.tier_sign(4)), "the tier-4 sign stands on the land it sells (D-240)")
	for id in MapLayout.yards_for_tier(3):
		assert_false(MapLayout.yard_rect(id).has_point(MapLayout.tier_sign(4)), "and not on the %s yard" % id)

func test_t4_the_tower_and_the_sign_are_on_screen_from_where_the_hero_stands() -> void:
	var g := WaypointGraph.create_for_tier(4)
	for id in T4_TOWERS:
		for aspect in ASPECTS_T4:
			var xf := CameraMath.camera_transform(CameraMath.focus_for(g.position_of(id)), Balance.ui)
			assert_true(CameraMath.on_screen(MapLayout.to3(MapLayout.spot_position(id)), xf, CameraMath.projection(Balance.ui, aspect)), "%s from its stand point at %.2f" % [id, aspect])
	var s := MapLayout.tier_sign(4)
	for aspect in ASPECTS_T4:
		var xf := CameraMath.camera_transform(CameraMath.focus_for(s), Balance.ui)
		assert_true(CameraMath.on_screen(MapLayout.to3(s), xf, CameraMath.projection(Balance.ui, aspect)), "the sign from itself at %.2f" % aspect)
	# tower_e2 is not in the HOME camera at 9:16 (documented: the tier-2 and tier-3 yard towers are not either); tower_n2 is, at the top of the screen
	var home := CameraMath.camera_transform(CameraMath.focus_for(MapLayout.HOME), Balance.ui)
	var p916 := CameraMath.projection(Balance.ui, 720.0 / 1280.0)
	assert_false(CameraMath.on_screen(MapLayout.to3(MapLayout.spot_position("tower_e2")), home, p916), "tower_e2 is off the HOME view")
	assert_true(CameraMath.on_screen(MapLayout.to3(MapLayout.spot_position("tower_n2")), home, p916), "tower_n2 is on the HOME view")

## B2: a capped bot (tier 3) must never pay the tier-4 sign by standing near it: it stands farther than STATION_RADIUS + HERO_RADIUS from every node of
## its graph, from every pad and from every stand point. (`tier_sign_4` itself, the node Task 8 adds, is not counted.)
func test_t4_the_sign_is_far_from_everything_a_tier_3_bot_stands_on() -> void:
	var need := MapLayout.STATION_RADIUS + MapLayout.HERO_RADIUS
	var s := MapLayout.tier_sign(4)
	var g := WaypointGraph.create_for_bot(3)
	var nearest := INF
	for n in g.nodes:
		if n == "tier_sign_4":
			continue
		nearest = minf(nearest, s.distance_to(g.position_of(n)))
		assert_gt(s.distance_to(g.position_of(n)), need, "the sign is within %.1f m of the bot's node %s" % [need, n])
	for id in MapLayout.spots_for_tier(3):
		for p in MapLayout.BRANCH_PADS[id]:
			assert_gt(s.distance_to(p), need, "the sign is near the pad of %s" % id)
		assert_gt(s.distance_to(MapLayout.spot_position(id)), need, "the sign is near %s" % id)
	for id in MapLayout.STATION_PADS:
		assert_gt(s.distance_to(MapLayout.STATION_PADS[id]), need, "station pad %s" % id)
	for id in MapLayout.STATION_STAND:
		assert_gt(s.distance_to(MapLayout.STATION_STAND[id]), need, "stand point %s" % id)
	for p in [MapLayout.HOME, MapLayout.SIGN, MapLayout.COUNTER_DROP, MapLayout.FREEZER_ZONE, MapLayout.GOLD_PILE, MapLayout.SERVICE_POINT, MapLayout.tier_sign(3)]:
		assert_gt(s.distance_to(p), need)
	gut.p("tier-4 sign to the nearest bot-3 graph node: %.2f m (need > %.1f)" % [nearest, need])
	# and off the traveler lines, the lanes and the back lot's own future pads
	for line in _t4_road_lines():
		assert_gt(Geometry.dist_point_segment(s, line[0], line[1]), need, "the sign is on a traveler line")
	assert_gte(_t4_lane_dist(s) - MapLayout.STATION_RADIUS, Balance.data.enemy.lateral_spread + 1.0, "clear of the lanes")
	for id in T4_TOWERS:
		assert_gt(s.distance_to(MapLayout.tower_spot(id)), MapLayout.STATION_RADIUS + MapLayout.BUILD_RADIUS, "off the future pad of %s" % id)

## D-314.24 (spec 4.3 second fallback): a tower's lane in the tables is a lane whose FENCE SPOT it reaches at level 1 (tower_range[0]), like every table before.
## After tier 4 every lane is covered by at least two towers except the south-west lane, which keeps its one tower: no free land reaches its fence spot at
## level 1 clear of the telegraph rows, the queue, the lanes and the pads (spec 4.3, searched again for D-314.24).
func test_t4_every_lane_but_sw_is_covered_by_at_least_two_towers_and_the_geometry_holds() -> void:
	var l1: float = Balance.data.build.tower_range[0]
	var count := {}
	for lane in MapLayout.lanes_for_tier(4):
		count[lane] = 0
	for id in MapLayout.spots_for_tier(4):
		if MapLayout.spot_kind(id) != "tower":
			continue
		for lane in MapLayout.tower_lanes(id):
			count[lane] += 1
			assert_lte(MapLayout.spot_position(id).distance_to(MapLayout.fence_spot(lane)), l1, "%s lists %s but does not reach its fence spot at level 1" % [id, lane])
	gut.p("towers per lane at tier 4: %s" % count)
	for lane in count:
		if lane == "sw":
			assert_eq(int(count[lane]), 1, "the south-west lane keeps its one tower (D-314.24)")
		else:
			assert_gte(int(count[lane]), 2, "lane %s is covered by %d tower(s)" % [lane, count[lane]])
	# the geometry assert has teeth: a tower moved 5 m away from its lane's fence would fail it
	for id in T4_TOWERS:
		var lane: String = MapLayout.tower_lanes(id)[0]
		var away := MapLayout.spot_position(id) + (MapLayout.spot_position(id) - MapLayout.fence_spot(lane)).normalized() * 5.0
		assert_gt(away.distance_to(MapLayout.fence_spot(lane)), l1, "a tower 5 m farther out would not reach %s's fence spot" % lane)
	# and no free tower of tier 4 reaches the sw fence spot at level 1
	for id in MapLayout.spots_for_tier(4):
		if MapLayout.spot_kind(id) == "tower" and not "sw" in MapLayout.tower_lanes(id):
			gut.p("%s to the sw fence spot: %.2f m" % [id, MapLayout.spot_position(id).distance_to(MapLayout.fence_spot("sw"))])

## What the back-lot towers reach, as information and pinned: the fence spot of their lane (the rule), the nearest stop point and the far zone corner.
func test_t4_what_the_back_lot_towers_reach() -> void:
	var l1: float = Balance.data.build.tower_range[0]
	var eb := Balance.data.enemy
	for id in T4_TOWERS:
		var t := MapLayout.spot_position(id)
		for lane in MapLayout.tower_lanes(id):
			var nearest := INF
			for i in 41:
				nearest = minf(nearest, t.distance_to(EnemyPath.position_at(lane, MapLayout.path_length(lane), lerpf(-1.0, 1.0, i / 40.0) * eb.lateral_spread, eb.offset_fade_distance)))
			var far_corner := 0.0
			for c in Geometry.rect_corners(MapLayout.zone_rect(lane)):
				far_corner = maxf(far_corner, t.distance_to(c))
			gut.p("%s -> %s: fence spot %.2f, nearest stop point %.2f, far zone corner %.2f (level-1 range %.1f)" % [id, lane, t.distance_to(MapLayout.fence_spot(lane)), nearest, far_corner, l1])
			if id == "tower_e2":
				assert_lte(far_corner, l1, "tower_e2 reaches every corner of the east zone at level 1")
				assert_lte(nearest, l1)

## The Longbow rule (test_longbow_reach) over the tier-4 towers: the third-nearest lane is beyond the Longbow range and beyond the 10.2 m margin.
func test_t4_the_third_nearest_lane_is_beyond_the_longbow_range() -> void:
	var longbow: float = Balance.data.branches.tower(&"longbow").attack_range
	var eb := Balance.data.enemy
	for id in T4_TOWERS:
		var t := MapLayout.spot_position(id)
		var d: Array = []
		for lane in MapLayout.lanes_for_tier(4):
			var best := t.distance_to(MapLayout.fence_spot(lane))
			for i in 41:
				best = minf(best, t.distance_to(EnemyPath.position_at(lane, MapLayout.path_length(lane), lerpf(-1.0, 1.0, i / 40.0) * eb.lateral_spread, eb.offset_fade_distance)))
			d.append(best)
		d.sort()
		gut.p("%s: lane distances %s" % [id, d.map(func(v): return snappedf(v, 0.01))])
		assert_gt(float(d[2]), longbow, "%s: the third lane is out of Longbow range" % id)
		assert_gte(float(d[2]), 10.2, "%s: the margin over the range is at least 10.2 m" % id)

func test_t4_the_bot_graph_follows_the_tier() -> void:
	var three := WaypointGraph.create_for_bot(3)
	var four := WaypointGraph.create_for_bot(4)
	for id in T4_TOWERS:
		assert_false(three.nodes.has(id), "%s is not in the tier-3 bot graph" % id)
		assert_true(four.nodes.has(id), "%s is in the tier-4 bot graph" % id)
		for i in 2:
			assert_false(four.shortest("zone_sw", "pad_%s_%s" % [id, "ab"[i]]).is_empty())
	assert_true(four.nodes.has("zone_sw"))
	var five := WaypointGraph.create_for_bot(5)
	assert_eq(five.nodes, four.nodes, "a tier above 4 is the tier-4 graph")
	assert_eq(five.edges, four.edges)
