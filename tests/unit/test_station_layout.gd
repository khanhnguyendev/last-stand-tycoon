extends GutTest
## E1 spec 5.2: the pads and the longer queue are fixed by these tests, not by eye.

func before_each() -> void:
	Balance.reset()

func _on_screen_from(p: Vector2, hero: Vector2) -> bool:
	var xf := CameraMath.camera_transform(CameraMath.focus_for(hero), Balance.ui)
	return CameraMath.on_screen(MapLayout.to3(p), xf, CameraMath.projection(Balance.ui))

func test_first_four_queue_slots_are_unchanged() -> void:
	assert_eq(MapLayout.QUEUE_SLOTS.slice(0, 4), [Vector2(0, 6.0), Vector2(-1.2, 7.0), Vector2(-2.4, 8.0), Vector2(-3.6, 9.0)])

func test_there_is_a_slot_for_every_queued_traveler() -> void:
	var most := 0
	for q in Balance.data.stations.queue_max:
		most = maxi(most, q)
	assert_gte(MapLayout.QUEUE_SLOTS.size(), most)

func test_queue_slots_are_in_bounds_and_north_of_the_road() -> void:
	var play := Rect2(MapLayout.BOUNDS_MIN, MapLayout.BOUNDS_MAX - MapLayout.BOUNDS_MIN)
	for s in MapLayout.QUEUE_SLOTS:
		assert_true(play.has_point(s), "%s in bounds" % s)
		assert_lt(s.y, MapLayout.ROAD_Z, "%s north of the road" % s)

func test_an_arriving_traveler_does_not_walk_through_the_queue() -> void:
	var slots: Array = MapLayout.QUEUE_SLOTS
	for k in range(1, slots.size()):
		for j in k:
			assert_gte(Geometry.dist_point_segment(slots[j], MapLayout.TRAVELER_ENTER, slots[k]), 1.0,
				"walking to slot %d passes slot %d" % [k, j])

func test_the_whole_queue_is_on_screen_from_the_counter() -> void:
	for s in MapLayout.QUEUE_SLOTS:
		assert_true(_on_screen_from(s, MapLayout.COUNTER_DROP), "%s on screen" % s)

func test_each_pad_is_on_screen_from_its_station() -> void:
	for id in StationEffects.IDS:
		assert_true(_on_screen_from(MapLayout.STATION_PADS[id], MapLayout.STATION_STAND[id]), String(id))

func test_pads_overlap_no_zone() -> void:
	var r := MapLayout.BUILD_RADIUS
	var zones := [[MapLayout.SIGN, MapLayout.STATION_RADIUS], [MapLayout.FREEZER_ZONE, MapLayout.STATION_RADIUS],
		[MapLayout.COUNTER_DROP, MapLayout.STATION_RADIUS], [MapLayout.GOLD_PILE, Balance.data.hero.magnet_radius],
		[MapLayout.HOME, 0.0], [MapLayout.NIGHT1_START, 0.0]]
	for id in MapLayout.SPOT_IDS:
		zones.append([MapLayout.spot_position(id), MapLayout.BUILD_RADIUS])
	for s in MapLayout.QUEUE_SLOTS:
		zones.append([s, 0.0])
	for id in StationEffects.IDS:
		var p: Vector2 = MapLayout.STATION_PADS[id]
		for z in zones:
			assert_gt(p.distance_to(z[0]), r + float(z[1]), "%s pad overlaps %s" % [id, z[0]])
		for lane in MapLayout.ZONE_RECTS:
			assert_gt(Geometry.dist_point_rect(p, MapLayout.ZONE_RECTS[lane]), r, "%s pad overlaps the %s lane zone" % [id, lane])

func test_pads_are_clear_of_the_bodies() -> void:
	var bodies := [
		Rect2(-MapLayout.DINER_HALF, -MapLayout.DINER_HALF, MapLayout.DINER_HALF * 2, MapLayout.DINER_HALF * 2),
		Rect2(MapLayout.COUNTER - MapLayout.COUNTER_SIZE / 2, MapLayout.COUNTER_SIZE),
		Rect2(MapLayout.FREEZER - MapLayout.FREEZER_SIZE / 2, MapLayout.FREEZER_SIZE),
	]
	for id in StationEffects.IDS:
		for b in bodies:
			assert_gt(Geometry.dist_point_rect(MapLayout.STATION_PADS[id], b), MapLayout.BUILD_RADIUS + MapLayout.HERO_RADIUS,
				"%s pad too close to a body" % id)

func test_pads_are_inside_the_bounds() -> void:
	var play := Rect2(MapLayout.BOUNDS_MIN, MapLayout.BOUNDS_MAX - MapLayout.BOUNDS_MIN).grow(-MapLayout.BUILD_RADIUS)
	for id in StationEffects.IDS:
		assert_true(play.has_point(MapLayout.STATION_PADS[id]), String(id))

func test_no_node_a_bot_stands_on_is_inside_a_pad() -> void:
	# D-228: front_e and se are inside a pad radius; bots only pass through them, and a zone needs a still hero.
	var g := WaypointGraph.create_default()
	for n in ["home", "sign", "gold_pile", "counter_drop", "freezer", "zone_west", "zone_north", "zone_east",
			"fence_w", "fence_n", "fence_e", "tower_nw", "tower_ne"]:
		for id in StationEffects.IDS:
			assert_gt(g.position_of(n).distance_to(MapLayout.STATION_PADS[id]), MapLayout.BUILD_RADIUS, "%s is on the %s pad" % [n, id])

func test_the_default_waypoint_graph_is_unchanged() -> void:
	# D-230: a new node would change nearest() and the planner's routes, and so the determinism baseline.
	var g := WaypointGraph.create_default()
	var names: Array = g.nodes.keys()
	names.sort()
	assert_eq(names, ["counter_drop", "e_mid", "fence_e", "fence_n", "fence_w", "freezer", "front_e", "gold_pile",
		"home", "ne", "nw", "se", "sign", "sw", "tower_ne", "tower_nw", "zone_east", "zone_north", "zone_west"])
	var links := 0
	for n in g.edges:
		links += (g.edges[n] as Array).size()
	assert_eq(links, 54, "27 undirected edges")
