extends GutTest
## E5 spec 5.3: the yards, the yard towers and the tier sign are fixed by these tests, not by eye (D-240).

const MARGIN := 1.0  # on top of lateral_spread

func before_each() -> void:
	Balance.reset()

func _on_screen_from(p: Vector2, hero: Vector2) -> bool:
	var xf := CameraMath.camera_transform(CameraMath.focus_for(hero), Balance.ui)
	return CameraMath.on_screen(MapLayout.to3(p), xf, CameraMath.projection(Balance.ui))

func _lane_clearance(p: Vector2) -> float:
	var best := INF
	for lane in MapLayout.LANE_PATHS:
		var path: Array = MapLayout.LANE_PATHS[lane]
		for i in range(1, path.size()):
			best = minf(best, Geometry.dist_point_segment(p, path[i - 1], path[i]))
	return best

func _rect_lane_clearance(r: Rect2) -> float:
	var best := INF
	for corner in [r.position, r.end, Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.position.y)]:
		best = minf(best, _lane_clearance(corner))
	# edges: sample every 0.25 m
	var x := r.position.x
	while x <= r.end.x + 1e-6:
		best = minf(best, _lane_clearance(Vector2(x, r.position.y)))
		best = minf(best, _lane_clearance(Vector2(x, r.end.y)))
		x += 0.25
	var z := r.position.y
	while z <= r.end.y + 1e-6:
		best = minf(best, _lane_clearance(Vector2(r.position.x, z)))
		best = minf(best, _lane_clearance(Vector2(r.end.x, z)))
		z += 0.25
	return best

func test_spot_lists() -> void:
	assert_eq(MapLayout.SPOT_IDS, ["tower_nw", "tower_ne", "fence_w", "fence_n", "fence_e"], "SPOT_IDS is frozen")
	assert_eq(MapLayout.spots_for_tier(1), MapLayout.SPOT_IDS)
	assert_eq(MapLayout.spots_for_tier(2), ["tower_nw", "tower_ne", "fence_w", "fence_n", "fence_e", "tower_w", "tower_e"])
	assert_eq(MapLayout.ALL_SPOT_IDS, MapLayout.spots_for_tier(2))
	assert_eq([MapLayout.spot_tier("fence_n"), MapLayout.spot_tier("tower_w")], [1, 2])
	assert_eq(MapLayout.spot_kind("tower_w"), "tower")
	assert_eq(MapLayout.TOWER_LANES["tower_w"], ["west"])
	assert_eq(MapLayout.TOWER_LANES["tower_e"], ["east"])
	assert_eq(MapLayout.yards_for_tier(1), [])
	assert_eq(MapLayout.yards_for_tier(2), ["west", "east"])

func test_yards_and_yard_spots_clear_the_lanes() -> void:
	var need: float = Balance.data.enemy.lateral_spread + MARGIN
	for id in MapLayout.YARDS:
		assert_gte(_rect_lane_clearance(MapLayout.YARDS[id]), need, "%s yard clears the lanes by %.2f" % [id, need])
	for id in MapLayout.TIER_SPOTS[2]:
		assert_gte(_lane_clearance(MapLayout.spot_position(id)) - MapLayout.TOWER_VISUAL_RADIUS, need, id)
	assert_gte(_lane_clearance(MapLayout.TIER_SIGN) - MapLayout.STATION_RADIUS, need, "tier sign")

func _keep_clear() -> Array:
	# [centre, radius] pairs everything new must stay outside of
	var out := [[MapLayout.SIGN, MapLayout.STATION_RADIUS], [MapLayout.FREEZER_ZONE, MapLayout.STATION_RADIUS],
		[MapLayout.COUNTER_DROP, MapLayout.STATION_RADIUS], [MapLayout.GOLD_PILE, Balance.data.hero.magnet_radius],
		[MapLayout.HOME, 0.0], [MapLayout.NIGHT1_START, 0.0], [MapLayout.guard_post(&"tank"), Balance.data.guards.tank.body_radius],
		[MapLayout.guard_post(&"archer"), 0.0]]
	for id in MapLayout.SPOT_IDS:
		out.append([MapLayout.spot_position(id), MapLayout.BUILD_RADIUS])
	for id in StationEffects.IDS:
		out.append([MapLayout.STATION_PADS[id], MapLayout.BUILD_RADIUS])
	for s in MapLayout.QUEUE_SLOTS:
		out.append([s, 0.0])
	return out

func _bodies() -> Array:
	return [
		Rect2(-MapLayout.DINER_HALF, -MapLayout.DINER_HALF, MapLayout.DINER_HALF * 2, MapLayout.DINER_HALF * 2),
		Rect2(MapLayout.COUNTER - MapLayout.COUNTER_SIZE / 2, MapLayout.COUNTER_SIZE),
		Rect2(MapLayout.FREEZER - MapLayout.FREEZER_SIZE / 2, MapLayout.FREEZER_SIZE),
	]

func test_yards_overlap_nothing_that_exists() -> void:
	for id in MapLayout.YARDS:
		var r: Rect2 = MapLayout.YARDS[id]
		for z in _keep_clear():
			assert_gt(Geometry.dist_point_rect(z[0], r), float(z[1]), "%s yard overlaps %s" % [id, z[0]])
		for b in _bodies():
			assert_false(r.intersects(b.grow(MapLayout.HERO_RADIUS)), "%s yard overlaps a body" % id)
		for lane in MapLayout.ZONE_RECTS:
			assert_false(r.intersects(MapLayout.ZONE_RECTS[lane]), "%s yard overlaps the %s zone" % [id, lane])
		var path := MapLayout.tank_return_path()
		for i in range(1, path.size()):
			var a: Vector2 = path[i - 1]
			var b: Vector2 = path[i]
			for k in 21:
				assert_false(r.has_point(a.lerp(b, k / 20.0)), "%s yard crosses the Tank's return path" % id)

func test_sign_and_yard_spots_overlap_nothing_that_exists() -> void:
	var pts := [[MapLayout.TIER_SIGN, MapLayout.STATION_RADIUS, "tier sign"]]
	for id in MapLayout.TIER_SPOTS[2]:
		pts.append([MapLayout.spot_position(id), MapLayout.BUILD_RADIUS, id])
	for p in pts:
		for z in _keep_clear():
			assert_gt((p[0] as Vector2).distance_to(z[0]), float(p[1]) + float(z[1]), "%s overlaps %s" % [p[2], z[0]])
		for b in _bodies():
			assert_gt(Geometry.dist_point_rect(p[0], b), float(p[1]) + MapLayout.HERO_RADIUS, "%s too close to a body" % p[2])
		for lane in MapLayout.ZONE_RECTS:
			assert_gt(Geometry.dist_point_rect(p[0], MapLayout.ZONE_RECTS[lane]), float(p[1]), "%s overlaps the %s zone" % [p[2], lane])

func test_sign_stands_on_the_west_yard() -> void:
	assert_true((MapLayout.YARDS["west"] as Rect2).has_point(MapLayout.TIER_SIGN), "the sign stands on the land it sells (D-240)")
	for id in MapLayout.TIER_SPOTS[2]:
		var yard: Rect2 = MapLayout.YARDS["west" if id == "tower_w" else "east"]
		assert_true(yard.grow(-MapLayout.TOWER_VISUAL_RADIUS).has_point(MapLayout.spot_position(id)), "%s stands on its yard" % id)

func test_new_points_are_far_from_props() -> void:
	var pts := [MapLayout.TIER_SIGN]
	for id in MapLayout.TIER_SPOTS[2]:
		pts.append(MapLayout.spot_position(id))
	for p in pts:
		for item in PropsLayout.ITEMS:
			assert_gt((p as Vector2).distance_to(item.pos), 3.0, "%s is within 3 m of a prop at %s" % [p, item.pos])

func test_yards_inside_the_bounds_and_the_ground() -> void:
	var play := Rect2(MapLayout.BOUNDS_MIN, MapLayout.BOUNDS_MAX - MapLayout.BOUNDS_MIN)
	for id in MapLayout.YARDS:
		assert_true(play.encloses(MapLayout.YARDS[id]), "%s yard inside BOUNDS" % id)
		assert_true(World.ground_rect().encloses(MapLayout.YARDS[id]), "%s yard on the ground" % id)

func test_on_screen_from_their_stand_points() -> void:
	assert_true(_on_screen_from(MapLayout.TIER_SIGN, MapLayout.TIER_SIGN), "sign")
	assert_true(_on_screen_from(MapLayout.TIER_SIGN + Vector2(0, -(Balance.ui.tier_sign_label_y + 0.4)), MapLayout.TIER_SIGN), "sign label (its top, tier_sign_label_y + 0.4 m up, read as that many m north at this pitch, conservative)")
	var g := WaypointGraph.create_for_tier(2)
	for id in MapLayout.TIER_SPOTS[2]:
		assert_true(_on_screen_from(MapLayout.spot_position(id), g.position_of(id)), id)

func test_yard_towers_reach_their_lane() -> void:
	var r: float = Balance.data.build.tower_range[0]
	for id in MapLayout.TIER_SPOTS[2]:
		var t := MapLayout.spot_position(id)
		for lane in MapLayout.TOWER_LANES[id]:
			var z: Rect2 = MapLayout.ZONE_RECTS[lane]
			for corner in [z.position, z.end, Vector2(z.position.x, z.end.y), Vector2(z.end.x, z.position.y)]:
				assert_lte(t.distance_to(corner), r, "%s -> %s zone corner %s" % [id, lane, corner])
			assert_lte(t.distance_to(MapLayout.fence_spot(lane)), r, "%s -> %s fence" % [id, lane])

func test_create_for_tier() -> void:
	var d := WaypointGraph.create_default()
	var one := WaypointGraph.create_for_tier(1)
	assert_eq(one.nodes, d.nodes)
	assert_eq(one.edges, d.edges)
	var two := WaypointGraph.create_for_tier(2)
	for n in ["tier_sign", "tower_w", "tower_e"]:
		assert_true(two.nodes.has(n), n)
	assert_eq(two.nodes.size(), d.nodes.size() + 3)
	assert_true(MapLayout.spot_position("tower_w").distance_to(two.position_of("tower_w")) <= MapLayout.BUILD_RADIUS)
	assert_true(MapLayout.spot_position("tower_e").distance_to(two.position_of("tower_e")) <= MapLayout.BUILD_RADIUS)
	for goal in ["tier_sign", "tower_w", "tower_e"]:
		assert_false(two.shortest("home", goal).is_empty(), "home reaches %s" % goal)
	# the frozen default did not change (D-230)
	var names: Array = d.nodes.keys()
	names.sort()
	assert_eq(names.size(), 19)

func test_new_edges_clear_the_colliders() -> void:
	var two := WaypointGraph.create_for_tier(2)
	var d := WaypointGraph.create_default()
	for a in two.edges:
		for b in two.edges[a]:
			if d.edges.has(a) and (d.edges[a] as Array).has(b):
				continue
			var pa: Vector2 = two.position_of(a)
			var pb: Vector2 = two.position_of(b)
			for body in _bodies():
				for k in 41:
					assert_false(body.grow(MapLayout.HERO_RADIUS).has_point(pa.lerp(pb, k / 40.0)), "edge %s-%s crosses a body" % [a, b])
