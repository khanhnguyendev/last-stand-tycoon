extends GutTest

var g: WaypointGraph

func before_each() -> void:
	g = WaypointGraph.create_default()

func test_all_nodes_connected() -> void:
	for n in g.nodes:
		assert_gt(g.shortest("home", n).size(), 0, "unreachable: " + n)

## D-125: every edge is traversable with hero-radius clearance against the hero's only colliders.
func test_edges_traversable_against_colliders() -> void:
	var diner := Rect2(-MapLayout.DINER_HALF, -MapLayout.DINER_HALF, MapLayout.DINER_HALF * 2, MapLayout.DINER_HALF * 2)
	var freezer := Rect2(MapLayout.FREEZER - MapLayout.FREEZER_SIZE / 2, MapLayout.FREEZER_SIZE)
	var counter := Rect2(MapLayout.COUNTER - MapLayout.COUNTER_SIZE / 2, MapLayout.COUNTER_SIZE)
	for a in g.edges:
		for b in g.edges[a]:
			var pa := g.position_of(a)
			var pb := g.position_of(b)
			var n := maxi(50, ceili(pa.distance_to(pb) / 0.05))
			for i in n + 1:
				var p := pa.lerp(pb, float(i) / n)
				for r in [diner, freezer, counter]:
					assert_true(Geometry.dist_point_rect(p, r) >= MapLayout.HERO_RADIUS - 0.01, "%s-%s hits box at %s" % [a, b, p])

func test_route_home_to_zone_north_goes_around() -> void:
	var names := g.shortest("home", "zone_north")
	assert_eq(names[0], "home")
	assert_eq(names[names.size() - 1], "zone_north")
	assert_true("nw" in names or "ne" in names)

func test_route_from_position_ends_at_goal() -> void:
	var pts := g.route_from(MapLayout.HOME, "freezer")
	assert_eq(pts[pts.size() - 1], g.position_of("freezer"))

func test_tower_stand_points_inside_build_radius() -> void:
	for id in ["tower_nw", "tower_ne"]:
		var d := g.position_of(id).distance_to(MapLayout.TOWER_SPOTS[id])
		assert_true(d <= MapLayout.BUILD_RADIUS)
		assert_true(d >= MapLayout.TOWER_VISUAL_RADIUS, "stand beside the mesh, not inside it")

func test_route_home_to_zone_east_uses_e_mid() -> void:
	assert_eq(g.shortest("home", "zone_east"), ["home", "se", "e_mid", "zone_east"])

func test_shortest_unknown_node_returns_empty() -> void:
	assert_eq(g.shortest("home", "nope"), [])
	assert_eq(g.shortest("nope", "home"), [])
