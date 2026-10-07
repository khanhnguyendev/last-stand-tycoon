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

## The tower spots standing at `tier`.
func _towers_at(tier: int) -> Array:
	return MapLayout.spots_for_tier(tier).filter(func(id): return MapLayout.spot_kind(id) == "tower")

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

## Every hero-reachable point on a 0.25 m grid against the possible enemy stop points of `lanes` (D-111 model, full lateral spread):
## {"max": most lanes one position reaches, "pairs": {"a+b": positions reaching exactly those two}, "positions": n}.
func _lane_coverage(lanes: Array) -> Dictionary:
	var eb := Balance.data.enemy
	var hero_range := Balance.data.hero.attack_range
	var stops := {}
	for lane in lanes:
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
				for lane in lanes:
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
	return {"max": max_lanes, "pairs": pairs, "positions": positions}

func test_A_prime_no_reachable_position_hits_all_three_lanes() -> void:
	# D-123 (supersedes the D-054 enclosing-circle assertion): sample every hero-reachable point on a
	# 0.25 m grid; count lanes with at least one possible enemy stop point (D-111 model, full lateral
	# spread) within hero range. No point may reach all 3 lanes. Tiers 1 and 2 keep today's three lanes and numbers.
	assert_eq(MapLayout.lanes_for_tier(1), MapLayout.lanes_for_tier(2), "tiers 1 and 2 share the three lanes")
	var r := _lane_coverage(LanePlanner.LANES)
	gut.p("A': %d reachable positions, max lanes reached = %d" % [r.positions, r.max])
	gut.p("A' info: 2-lane positions per pair = %s" % [r.pairs])
	gut.p("info only: enclosing radius of zone corners = %.3f" % Geometry.enclosing_radius(_zone_points()))
	assert_lt(r.max, 3, "a reachable position covers all three lanes")
	assert_eq(r.max, 2, "today's three-lane map reaches at most two (and does reach two)")
	assert_eq(r.pairs, {"west+north": 16, "north+east": 16}, "today's three-lane pairs (numbers captured before tier 3)")

func test_A_prime_tier3_no_reachable_position_hits_three_of_four_lanes() -> void:
	# E5 D-261.2: with the south-west lane no hero-reachable position reaches three lanes; the sw lane pairs only with west.
	var lanes := MapLayout.lanes_for_tier(3)
	assert_eq(lanes, ["west", "north", "east", "sw"])
	var r := _lane_coverage(lanes)
	gut.p("A' tier 3: %d reachable positions, max lanes reached = %d, pairs %s" % [r.positions, r.max, r.pairs])
	assert_eq(r.max, 2, "no position reaches three lanes")
	assert_gt(int(r.pairs.get("west+sw", 0)), 0, "west and sw can be covered together")
	for key in r.pairs:
		if "sw" in key.split("+"):
			assert_eq(key, "west+sw", "sw pairs only with west")
	assert_eq(int(r.pairs.get("west+north", 0)), 16, "the old pairs are unchanged")
	assert_eq(int(r.pairs.get("north+east", 0)), 16, "the old pairs are unchanged")

## tower_sw lists "west" second in TOWER_LANES (spec 4.1) but only reaches the west zone's corners at the top level (7.24 m against 7.5 and 8.0),
## and never its fence: the level-1 reach of B and C is claimed for the first lane only; the second lane has its own check (B).
const SECONDARY_LANES := {"tower_sw": ["west"]}

func _primary_lanes(spot_id: String) -> Array:
	return MapLayout.tower_lanes(spot_id).filter(func(l): return not (SECONDARY_LANES.get(spot_id, []) as Array).has(l))

func test_B_towers_reach_adjacent_zones() -> void:
	var tower_range: float = Balance.data.build.tower_range[0]
	for tier in [2, 3]:
		for spot_id in _towers_at(tier):
			var t: Vector2 = MapLayout.tower_spot(spot_id)
			for lane in _primary_lanes(spot_id):
				for c in Geometry.rect_corners(MapLayout.zone_rect(lane)):
					assert_true(t.distance_to(c) <= tower_range, "tier %d: %s -> %s corner %s" % [tier, spot_id, lane, c])
	var top: float = Balance.data.build.tower_range[Balance.data.build.tower_range.size() - 1]
	for c in Geometry.rect_corners(MapLayout.zone_rect("west")):
		assert_lte(MapLayout.tower_spot("tower_sw").distance_to(c), top, "tower_sw reaches the west zone corner %s at the top level" % c)
	var worst := 0.0
	for c in Geometry.rect_corners(MapLayout.zone_rect("sw")):
		worst = maxf(worst, MapLayout.tower_spot("tower_sw").distance_to(c))
	gut.p("B: tower_sw -> farthest SW zone corner %.2f (range %.1f)" % [worst, tower_range])

func test_C_towers_reach_adjacent_fences() -> void:
	var tower_range: float = Balance.data.build.tower_range[0]
	for tier in [2, 3]:
		for spot_id in _towers_at(tier):
			var t: Vector2 = MapLayout.tower_spot(spot_id)
			for lane in _primary_lanes(spot_id):
				assert_true(t.distance_to(MapLayout.fence_spot(lane)) <= tower_range, "tier %d: %s -> fence %s" % [tier, spot_id, lane])

func test_D_stop_points_inside_zone() -> void:
	var eb := Balance.data.enemy
	for tier in [1, 3]:
		for lane in MapLayout.lanes_for_tier(tier):
			var length := MapLayout.path_length(lane)
			for i in 1001:
				var offset := lerpf(-1.0, 1.0, i / 1000.0) * eb.lateral_spread
				var p := EnemyPath.position_at(lane, length, offset, eb.offset_fade_distance)
				assert_true(Geometry.rect_contains(MapLayout.zone_rect(lane), p), "tier %d: %s offset %.3f -> %s" % [tier, lane, offset, p])

func test_E_paths_clear_towers_and_diner() -> void:
	var eb := Balance.data.enemy
	var diner := Rect2(-MapLayout.DINER_HALF, -MapLayout.DINER_HALF, MapLayout.DINER_HALF * 2, MapLayout.DINER_HALF * 2)
	for tier in [2, 3]:
		for lane in MapLayout.lanes_for_tier(tier):
			var length := MapLayout.path_length(lane)
			var d := 0.0
			while d <= length + 0.0001:
				for offset in [-eb.lateral_spread, 0.0, eb.lateral_spread]:
					var p := EnemyPath.position_at(lane, d, offset, eb.offset_fade_distance)
					for spot_id in _towers_at(tier):
						assert_true(p.distance_to(MapLayout.tower_spot(spot_id)) >= 1.5 - 1e-4, "tier %d: %s near %s at %.1f" % [tier, lane, spot_id, d])
					assert_true(Geometry.dist_point_rect(p, diner) >= eb.reach - 0.001, "tier %d: %s inside diner reach at %.1f" % [tier, lane, d])
				d += 0.1

func test_home_and_night1_start_are_clear() -> void:
	# D-122, D-126: both spawn points are outside every station/build zone, off every lane, reachable.
	var zones := [[MapLayout.SIGN, MapLayout.STATION_RADIUS], [MapLayout.FREEZER_ZONE, MapLayout.STATION_RADIUS],
		[MapLayout.COUNTER_DROP, MapLayout.STATION_RADIUS], [MapLayout.GOLD_PILE, Balance.data.hero.magnet_radius]]
	for id in MapLayout.spots_for_tier(3):
		zones.append([MapLayout.spot_position(id), MapLayout.BUILD_RADIUS])
	for p in [MapLayout.HOME, MapLayout.NIGHT1_START]:
		assert_true(_reachable(p, _hero_colliders()), "%s not reachable" % [p])
		for z in zones:
			assert_gt(p.distance_to(z[0]), float(z[1]), "%s inside zone at %s" % [p, z[0]])
		for lane in MapLayout.lanes_for_tier(3):
			var path: Array = MapLayout.lane_path(lane)
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
	for lane in MapLayout.lanes_for_tier(3):
		assert_almost_eq(MapLayout.telegraph_spot(lane).distance_to(MapLayout.fence_spot(lane)), 1.5, 0.001, lane)

## Perpendicular of the path's last segment, same convention as EnemyPath (D-111).
func _end_perp(lane: String) -> Vector2:
	var path: Array = MapLayout.lane_path(lane)
	var t := (path[path.size() - 1] as Vector2 - path[path.size() - 2] as Vector2).normalized()
	return Vector2(-t.y, t.x)

func test_zone_axis_matches_end_perp() -> void:
	for lane in MapLayout.lanes_for_tier(3):
		assert_gt(MapLayout.zone_axis(lane).dot(_end_perp(lane)), 0.0, "%s axis opposes end perpendicular" % lane)

func test_offset_blend_never_crosses_centerline() -> void:
	# D-111: an enemy's lateral offset must stay on one side of the lane centerline while it blends onto the zone axis.
	var eb := Balance.data.enemy
	for lane in MapLayout.lanes_for_tier(3):
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

func _offsets() -> Array:
	var s := Balance.data.enemy.lateral_spread
	return [-s, -s * 0.5, 0.0, s * 0.5, s]

func test_tank_post_on_west_lane() -> void:
	var p := MapLayout.guard_post(&"tank")
	assert_almost_eq(p.x, -6.599, 0.01)
	assert_almost_eq(p.y, -2.654, 0.01)

func test_every_west_boar_comes_within_reach_of_the_tank() -> void:
	var post := MapLayout.guard_post(&"tank")
	var r := Balance.data.enemy.reach + Balance.data.guards.tank.body_radius
	var fade := Balance.data.enemy.offset_fade_distance
	var length := MapLayout.path_length("west")
	for off in _offsets():
		var best := INF
		var d := 0.0
		while d <= length:
			best = minf(best, EnemyPath.position_at("west", d, off, fade).distance_to(post))
			d += 0.05
		assert_lte(best, r, "offset %.2f closest %.3f" % [off, best])

func test_tank_is_behind_the_fence_stop_and_hits_fence_held_boars() -> void:
	var post := MapLayout.guard_post(&"tank")
	var t := Balance.data.guards.tank
	var reach := Balance.data.enemy.reach
	var stop := MapLayout.path_length("west") - MapLayout.FENCE_OFFSET_FROM_END - reach
	var s := float(Balance.data.enemy.lateral_spread)
	var fade := Balance.data.enemy.offset_fade_distance
	assert_gt(Geometry.dist_point_segment(post, EnemyPath.position_at("west", stop, -s, fade), EnemyPath.position_at("west", stop, s, fade)), reach + t.body_radius)
	for off in _offsets():
		var q := EnemyPath.position_at("west", stop, off, Balance.data.enemy.offset_fade_distance)
		var dd := q.distance_to(post)
		assert_gt(dd, reach + t.body_radius, "a boar at the fence does not target the tank (offset %.2f)" % off)
		assert_lte(dd, t.attack_range, "the tank reaches a fence-held boar (offset %.2f, %.3f m)" % [off, dd])

func test_tank_range_covers_its_attackers() -> void:
	var t := Balance.data.guards.tank
	assert_gte(t.attack_range, Balance.data.enemy.reach + t.body_radius)

func test_archer_covers_lane_ends_and_north_east_fence_stops() -> void:
	var a := MapLayout.guard_post(&"archer")
	var rng := Balance.data.guards.archer.attack_range
	var fade := Balance.data.enemy.offset_fade_distance
	for lane in ["west", "north", "east"]:
		for off in _offsets():
			var e := EnemyPath.position_at(lane, MapLayout.path_length(lane), off, fade)
			assert_lte(e.distance_to(a), rng, "%s end offset %.2f" % [lane, off])
	for lane in ["north", "east"]:
		var stop := MapLayout.path_length(lane) - MapLayout.FENCE_OFFSET_FROM_END - Balance.data.enemy.reach
		for off in _offsets():
			assert_lte(EnemyPath.position_at(lane, stop, off, fade).distance_to(a), rng, "%s fence stop" % lane)

func test_tank_return_path_is_clear() -> void:
	var path := MapLayout.tank_return_path()
	assert_eq(path[0], MapLayout.DINER_DOOR)
	assert_eq(path[path.size() - 1], MapLayout.guard_post(&"tank"))
	var r := Balance.data.guards.tank.body_radius
	var box := Rect2(-MapLayout.DINER_HALF, -MapLayout.DINER_HALF, MapLayout.DINER_HALF * 2.0, MapLayout.DINER_HALF * 2.0)
	for i in path.size() - 1:
		var a: Vector2 = path[i]
		var b: Vector2 = path[i + 1]
		var n := int(ceil(a.distance_to(b) / 0.05))
		for k in n + 1:
			var p := a.lerp(b, float(k) / float(n))
			assert_gte(Geometry.dist_point_rect(p, box), r + 0.025, "segment %d clears the diner" % i)
		for id in _towers_at(3):
			assert_gte(Geometry.dist_point_segment(MapLayout.tower_spot(id), a, b), MapLayout.TOWER_VISUAL_RADIUS + r, "segment %d clears %s" % [i, id])
