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

## E5 tier 3: the default graph is frozen; the tier-3 graph reaches the SW tower, fence, sign and every branch pad from home.
func test_tier_3_graph_extends_without_touching_the_default() -> void:
	var t3 := WaypointGraph.create_for_tier(3)
	assert_eq(g.nodes.size(), 19)
	for n in g.nodes:
		assert_eq(t3.position_of(n), g.position_of(n), "%s keeps its position" % n)
	for n in ["tower_sw", "fence_sw", "tier_sign_3", "pad_tower_sw_a", "pad_fence_sw_b", "pad_fence_n_a", "pad_tower_e_b"]:
		assert_gt(t3.shortest("home", n).size(), 0, "unreachable: " + n)

## Task 22: the graph the tier bot walks. Mutations: tier 1 gaining tier_sign_3 (routes of tier-1 runs could change), tier 2 without the
## front-lot sign, tier 3 without zone_sw, or a zone_sw edge through the diner, counter or freezer.
func test_the_bot_graph_follows_the_tier() -> void:
	var one := WaypointGraph.create_for_bot(1)
	var base := WaypointGraph.create_for_tier(2)
	assert_eq(one.nodes, base.nodes, "tier 1 is the tier-2 graph it always had")
	assert_eq(one.edges, base.edges)
	var two := WaypointGraph.create_for_bot(2)
	assert_eq(two.position_of("tier_sign_3"), MapLayout.tier_sign(3))
	assert_false(two.nodes.has("zone_sw"))
	assert_false(two.shortest("home", "tier_sign_3").is_empty())
	assert_true(two.nodes.has("tier_sign"), "the west sign stays")
	var three := WaypointGraph.create_for_bot(3)
	assert_eq(three.position_of("zone_sw"), MapLayout.lane_end("sw"))
	for n in ["tower_sw", "fence_sw", "tier_sign_3", "pad_tower_sw_a", "pad_fence_sw_b"]:
		assert_false(three.shortest("zone_sw", n).is_empty(), n)
	var bodies := [Rect2(-4, -4, 8, 8), Rect2(MapLayout.COUNTER - MapLayout.COUNTER_SIZE / 2, MapLayout.COUNTER_SIZE),
		Rect2(MapLayout.FREEZER - MapLayout.FREEZER_SIZE / 2, MapLayout.FREEZER_SIZE)]
	for e in [["sw", "zone_sw"], ["fence_sw", "zone_sw"], ["sw", "tier_sign_3"]]:
		var pa: Vector2 = three.position_of(e[0])
		var pb: Vector2 = three.position_of(e[1])
		assert_true(e[1] in three.edges[e[0]], "edge %s-%s exists" % e)
		for k in 101:
			for body in bodies:
				assert_true(Geometry.dist_point_rect(pa.lerp(pb, k / 100.0), body) >= MapLayout.HERO_RADIUS - 0.01, "edge %s-%s hits a collider" % e)
