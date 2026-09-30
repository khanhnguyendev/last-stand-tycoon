extends GutTest
## Spec 6.3 tests A′ and B–E, plus the Geometry helpers. Re-run after any path change (D-076).

func before_each() -> void:
	Balance.reset()

func test_helpers() -> void:
	var path := [Vector2(0, 0), Vector2(0, 10), Vector2(10, 10)]
	assert_almost_eq(Geometry.path_length(path), 20.0, 0.0001)
	assert_true(Geometry.point_at(path, 15.0).is_equal_approx(Vector2(5, 10)))
	assert_true(Geometry.point_back_from_end(path, 4.0).is_equal_approx(Vector2(6, 10)))
	assert_almost_eq(Geometry.dist_point_segment(Vector2(5, 3), Vector2(0, 0), Vector2(10, 0)), 3.0, 0.0001)
	assert_almost_eq(Geometry.dist_point_rect(Vector2(6, 0), Rect2(-4, -4, 8, 8)), 2.0, 0.0001)
	assert_true(Geometry.rect_contains(Rect2(4, -1.5, 1.2, 3), Vector2(5.2, 0)))
	var r := Geometry.enclosing_radius([Vector2(-1, 0), Vector2(1, 0), Vector2(0, 0.5)])
	assert_almost_eq(r, 1.0, 0.0001)
	assert_eq(Geometry.enclosing_radius([]), 0.0)
	assert_eq(Geometry.enclosing_radius([Vector2(3, 3)]), 0.0)

func _zone_points() -> Array:
	var pts: Array = []
	for lane in LanePlanner.LANES:
		pts.append_array(Geometry.rect_corners(MapLayout.ZONE_RECTS[lane]))
	return pts

## Colliders the hero cannot enter (D-094, D-125): diner, counter, freezer. Towers and fences are walk-through.
func _hero_colliders() -> Array:
	return [
		Rect2(-MapLayout.DINER_HALF, -MapLayout.DINER_HALF, MapLayout.DINER_HALF * 2, MapLayout.DINER_HALF * 2),
		Rect2(MapLayout.COUNTER - MapLayout.COUNTER_SIZE / 2, MapLayout.COUNTER_SIZE),
		Rect2(MapLayout.FREEZER - MapLayout.FREEZER_SIZE / 2, MapLayout.FREEZER_SIZE),
	]

func _reachable(p: Vector2, colliders: Array) -> bool:
	for r in colliders:
		if Geometry.dist_point_rect(p, r) < MapLayout.HERO_RADIUS:
			return false
	return true

func test_A_prime_no_reachable_position_hits_all_three_lanes() -> void:
	# D-123 (supersedes the D-054 enclosing-circle assertion): sample every hero-reachable point on a
	# 0.25 m grid; count lanes with at least one possible enemy stop point (D-111 model, full lateral
	# spread) within hero range. No point may reach all 3 lanes.
	var eb := Balance.data.enemy
	var hero_range := Balance.data.hero.attack_range
	var stops := {}
	for lane in LanePlanner.LANES:
		var pts: Array = []
		var length := MapLayout.path_length(lane)
		for i in 41:
			var offset := lerpf(-1.0, 1.0, i / 40.0) * eb.lateral_spread
			pts.append(EnemyPath.position_at(lane, length, offset, eb.offset_fade_distance))
		stops[lane] = pts
	var colliders := _hero_colliders()
	var pairs := {}
	var max_lanes := 0
	var positions := 0
	var x := MapLayout.BOUNDS_MIN.x
	while x <= MapLayout.BOUNDS_MAX.x + 1e-6:
		var z := MapLayout.BOUNDS_MIN.y
		while z <= MapLayout.BOUNDS_MAX.y + 1e-6:
			var p := Vector2(x, z)
			if _reachable(p, colliders):
				positions += 1
				var reached: Array = []
				for lane in LanePlanner.LANES:
					if p.distance_to(MapLayout.lane_end(lane)) > hero_range + eb.lateral_spread + 0.01:
						continue
					for q in stops[lane]:
						if p.distance_to(q) <= hero_range:
							reached.append(lane)
							break
				max_lanes = maxi(max_lanes, reached.size())
				if reached.size() == 2:
					var key := "+".join(reached)
					pairs[key] = int(pairs.get(key, 0)) + 1
			z += 0.25
		x += 0.25
	gut.p("A': %d reachable positions, max lanes reached = %d" % [positions, max_lanes])
	gut.p("A' info: 2-lane positions per pair = %s" % [pairs])
	gut.p("info only: enclosing radius of zone corners = %.3f" % Geometry.enclosing_radius(_zone_points()))
	assert_lt(max_lanes, 3, "a reachable position covers all three lanes")

func test_B_towers_reach_adjacent_zones() -> void:
	var tower_range: float = Balance.data.build.tower_range[0]
	for spot_id in MapLayout.TOWER_SPOTS:
		var t: Vector2 = MapLayout.TOWER_SPOTS[spot_id]
		for lane in MapLayout.TOWER_LANES[spot_id]:
			for c in Geometry.rect_corners(MapLayout.ZONE_RECTS[lane]):
				assert_true(t.distance_to(c) <= tower_range, "%s -> %s corner %s" % [spot_id, lane, c])

func test_C_towers_reach_adjacent_fences() -> void:
	var tower_range: float = Balance.data.build.tower_range[0]
	for spot_id in MapLayout.TOWER_SPOTS:
		var t: Vector2 = MapLayout.TOWER_SPOTS[spot_id]
		for lane in MapLayout.TOWER_LANES[spot_id]:
			assert_true(t.distance_to(MapLayout.fence_spot(lane)) <= tower_range, "%s -> fence %s" % [spot_id, lane])

func test_D_stop_points_inside_zone() -> void:
	var eb := Balance.data.enemy
	for lane in LanePlanner.LANES:
		var length := MapLayout.path_length(lane)
		for i in 1001:
			var offset := lerpf(-1.0, 1.0, i / 1000.0) * eb.lateral_spread
			var p := EnemyPath.position_at(lane, length, offset, eb.offset_fade_distance)
			assert_true(Geometry.rect_contains(MapLayout.ZONE_RECTS[lane], p), "%s offset %.3f -> %s" % [lane, offset, p])

func test_E_paths_clear_towers_and_diner() -> void:
	var eb := Balance.data.enemy
	var diner := Rect2(-MapLayout.DINER_HALF, -MapLayout.DINER_HALF, MapLayout.DINER_HALF * 2, MapLayout.DINER_HALF * 2)
	for lane in LanePlanner.LANES:
		var length := MapLayout.path_length(lane)
		var d := 0.0
		while d <= length + 0.0001:
			for offset in [-eb.lateral_spread, 0.0, eb.lateral_spread]:
				var p := EnemyPath.position_at(lane, d, offset, eb.offset_fade_distance)
				for spot_id in MapLayout.TOWER_SPOTS:
					assert_true(p.distance_to(MapLayout.TOWER_SPOTS[spot_id]) >= 1.5 - 1e-4, "%s near %s at %.1f" % [lane, spot_id, d])
				assert_true(Geometry.dist_point_rect(p, diner) >= eb.reach - 0.001, "%s inside diner reach at %.1f" % [lane, d])
			d += 0.1

func test_home_and_night1_start_are_clear() -> void:
	# D-122, D-126: both spawn points are outside every station/build zone, off every lane, reachable.
	var zones := [[MapLayout.SIGN, MapLayout.STATION_RADIUS], [MapLayout.FREEZER_ZONE, MapLayout.STATION_RADIUS],
		[MapLayout.COUNTER_DROP, MapLayout.STATION_RADIUS], [MapLayout.GOLD_PILE, Balance.data.hero.magnet_radius]]
	for id in MapLayout.SPOT_IDS:
		zones.append([MapLayout.spot_position(id), MapLayout.BUILD_RADIUS])
	for p in [MapLayout.HOME, MapLayout.NIGHT1_START]:
		assert_true(_reachable(p, _hero_colliders()), "%s not reachable" % [p])
		for z in zones:
			assert_gt(p.distance_to(z[0]), float(z[1]), "%s inside zone at %s" % [p, z[0]])
		for lane in LanePlanner.LANES:
			var path: Array = MapLayout.LANE_PATHS[lane]
			for i in range(1, path.size()):
				assert_gt(Geometry.dist_point_segment(p, path[i - 1], path[i]),
					Balance.data.enemy.lateral_spread + MapLayout.HERO_RADIUS, "%s on lane %s" % [p, lane])
	# night 1, wave 0 comes up the north lane: it passes within hero range of the start
	var north: Array = MapLayout.LANE_PATHS["north"]
	assert_lt(Geometry.dist_point_segment(MapLayout.NIGHT1_START, north[0], north[1]), Balance.data.hero.attack_range)

func test_fence_spots_match_spec() -> void:
	assert_true(MapLayout.fence_spot("north").is_equal_approx(Vector2(0, -9.2)))
	assert_almost_eq(MapLayout.fence_spot("west").x, -7.07, 0.02)
	assert_almost_eq(MapLayout.fence_spot("west").y, -3.54, 0.02)
	assert_almost_eq(MapLayout.fence_spot("east").x, 7.07, 0.02)
	assert_almost_eq(MapLayout.fence_spot("east").y, -3.54, 0.02)
	# spec 6.1: telegraph markers sit 1.5 m up-path from each fence spot
	for lane in LanePlanner.LANES:
		assert_almost_eq(MapLayout.telegraph_spot(lane).distance_to(MapLayout.fence_spot(lane)), 1.5, 0.001, lane)

## Perpendicular of the path's last segment, same convention as EnemyPath (D-111).
func _end_perp(lane: String) -> Vector2:
	var path: Array = MapLayout.LANE_PATHS[lane]
	var t := (path[path.size() - 1] as Vector2 - path[path.size() - 2] as Vector2).normalized()
	return Vector2(-t.y, t.x)

func test_zone_axis_matches_end_perp() -> void:
	for lane in LanePlanner.LANES:
		assert_gt((MapLayout.ZONE_AXIS[lane] as Vector2).dot(_end_perp(lane)), 0.0, "%s axis opposes end perpendicular" % lane)

func test_offset_blend_never_crosses_centerline() -> void:
	# D-111: an enemy's lateral offset must stay on one side of the lane centerline while it blends onto the zone axis.
	var eb := Balance.data.enemy
	for lane in LanePlanner.LANES:
		var length := MapLayout.path_length(lane)
		var end_perp := _end_perp(lane)
		for o in [-1.0, -0.5, 0.5, 1.0]:
			var offset: float = o * eb.lateral_spread
			var want := signf(offset)
			var d := length - eb.offset_fade_distance - 1.0
			while d <= length + 1e-6:
				var base := EnemyPath.position_at(lane, d, 0.0, eb.offset_fade_distance)
				var side := (EnemyPath.position_at(lane, d, offset, eb.offset_fade_distance) - base).dot(end_perp)
				assert_gt(side * want, 1e-3, "%s offset %.2f crosses centerline at d=%.2f (side %.4f)" % [lane, offset, d, side])
				d += 0.05
