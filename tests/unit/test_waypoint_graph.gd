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

# --- E8 B1: the tier-3 graphs, pinned before the back lot (phase 2 Task 6) -----------------------------------------------------------
# The node and edge lists of create_for_tier(3) and create_for_bot(3) as they were at the start of Task 6 (captured from the code before the change):
# names with positions in insertion order, and every node's neighbours in insertion order. The back lot adds nodes only in _add_tier4, so these
# stay as they are; a pad read from the whole BRANCH_PADS table in _add_tier3 would break them.

const NODES_TIER3 := [
	["home", Vector2(0.0, 9.5)],
	["sign", Vector2(0.0, 8.0)],
	["gold_pile", Vector2(-2.5, 5.5)],
	["front_e", Vector2(3.0, 6.5)],
	["counter_drop", Vector2(2.2, 4.8)],
	["freezer", Vector2(5.5, 6.3)],
	["sw", Vector2(-6.8, 6.8)],
	["se", Vector2(6.8, 6.8)],
	["nw", Vector2(-7.0, -7.0)],
	["ne", Vector2(7.0, -7.0)],
	["e_mid", Vector2(7.0, 3.0)],
	["zone_west", Vector2(-5.2, 0.0)],
	["zone_north", Vector2(0.0, -5.2)],
	["zone_east", Vector2(5.2, 0.0)],
	["fence_w", Vector2(-7.0656, -3.5383)],
	["fence_n", Vector2(0.0, -9.2)],
	["fence_e", Vector2(7.0656, -3.5383)],
	["tower_nw", Vector2(-5.75, -5.75)],
	["tower_ne", Vector2(5.75, -5.75)],
	["tier_sign", Vector2(-10.0, 7.5)],
	["tower_w", Vector2(-11.35, 1.35)],
	["tower_e", Vector2(9.55, 1.85)],
	["tower_sw", Vector2(-7.35, 6.35)],
	["fence_sw", Vector2(-3.263, 9.167)],
	["tier_sign_3", Vector2(-4.7, 8.5)],
	["pad_fence_e_a", Vector2(6.1, -6.1)],
	["pad_fence_e_b", Vector2(9.5, -3.8)],
	["pad_fence_n_a", Vector2(-2.3, -10.4)],
	["pad_fence_n_b", Vector2(2.3, -10.4)],
	["pad_fence_sw_a", Vector2(-5.6, 7.8)],
	["pad_fence_sw_b", Vector2(-1.0, 10.5)],
	["pad_fence_w_a", Vector2(-9.6, -4.0)],
	["pad_fence_w_b", Vector2(-6.2, -6.2)],
	["pad_tower_e_a", Vector2(6.8, 3.0)],
	["pad_tower_e_b", Vector2(7.5, 0.0)],
	["pad_tower_ne_a", Vector2(3.2, -5.1)],
	["pad_tower_ne_b", Vector2(3.5, -7.3)],
	["pad_tower_nw_a", Vector2(-3.6, -7.3)],
	["pad_tower_nw_b", Vector2(-3.0, -5.1)],
	["pad_tower_sw_a", Vector2(-7.8, 4.1)],
	["pad_tower_sw_b", Vector2(-5.1, 3.7)],
	["pad_tower_w_a", Vector2(-10.7, 2.4)],
	["pad_tower_w_b", Vector2(-8.7, 0.8)],
]
const EDGES_TIER3 := {
	"home": ["sign", "sw", "se", "front_e", "gold_pile", "fence_sw", "tier_sign_3"],
	"sign": ["home"],
	"gold_pile": ["home", "sw"],
	"front_e": ["home", "freezer", "counter_drop"],
	"counter_drop": ["front_e"],
	"freezer": ["front_e", "se"],
	"sw": ["home", "gold_pile", "nw", "zone_west", "tier_sign", "tower_w", "tower_sw", "fence_sw", "tier_sign_3"],
	"se": ["home", "freezer", "ne", "e_mid", "tower_e"],
	"nw": ["sw", "zone_west", "zone_north", "fence_w", "fence_n", "tower_nw"],
	"ne": ["se", "zone_east", "zone_north", "fence_e", "fence_n", "tower_ne"],
	"e_mid": ["se", "zone_east"],
	"zone_west": ["sw", "nw", "fence_w", "tower_w"],
	"zone_north": ["nw", "ne", "fence_n"],
	"zone_east": ["e_mid", "ne", "fence_e", "tower_e"],
	"fence_w": ["nw", "zone_west", "pad_fence_w_a", "pad_fence_w_b"],
	"fence_n": ["nw", "ne", "zone_north", "pad_fence_n_a", "pad_fence_n_b"],
	"fence_e": ["ne", "zone_east", "pad_fence_e_a", "pad_fence_e_b"],
	"tower_nw": ["nw", "pad_tower_nw_a", "pad_tower_nw_b"],
	"tower_ne": ["ne", "pad_tower_ne_a", "pad_tower_ne_b"],
	"tier_sign": ["sw"],
	"tower_w": ["sw", "zone_west", "pad_tower_w_a", "pad_tower_w_b"],
	"tower_e": ["se", "zone_east", "pad_tower_e_a", "pad_tower_e_b"],
	"tower_sw": ["sw", "pad_tower_sw_a", "pad_tower_sw_b"],
	"fence_sw": ["sw", "home", "pad_fence_sw_a", "pad_fence_sw_b"],
	"tier_sign_3": ["sw", "home"],
	"pad_fence_e_a": ["fence_e"],
	"pad_fence_e_b": ["fence_e"],
	"pad_fence_n_a": ["fence_n"],
	"pad_fence_n_b": ["fence_n"],
	"pad_fence_sw_a": ["fence_sw"],
	"pad_fence_sw_b": ["fence_sw"],
	"pad_fence_w_a": ["fence_w"],
	"pad_fence_w_b": ["fence_w"],
	"pad_tower_e_a": ["tower_e"],
	"pad_tower_e_b": ["tower_e"],
	"pad_tower_ne_a": ["tower_ne"],
	"pad_tower_ne_b": ["tower_ne"],
	"pad_tower_nw_a": ["tower_nw"],
	"pad_tower_nw_b": ["tower_nw"],
	"pad_tower_sw_a": ["tower_sw"],
	"pad_tower_sw_b": ["tower_sw"],
	"pad_tower_w_a": ["tower_w"],
	"pad_tower_w_b": ["tower_w"],
}

const NODES_BOT3 := [
	["home", Vector2(0.0, 9.5)],
	["sign", Vector2(0.0, 8.0)],
	["gold_pile", Vector2(-2.5, 5.5)],
	["front_e", Vector2(3.0, 6.5)],
	["counter_drop", Vector2(2.2, 4.8)],
	["freezer", Vector2(5.5, 6.3)],
	["sw", Vector2(-6.8, 6.8)],
	["se", Vector2(6.8, 6.8)],
	["nw", Vector2(-7.0, -7.0)],
	["ne", Vector2(7.0, -7.0)],
	["e_mid", Vector2(7.0, 3.0)],
	["zone_west", Vector2(-5.2, 0.0)],
	["zone_north", Vector2(0.0, -5.2)],
	["zone_east", Vector2(5.2, 0.0)],
	["fence_w", Vector2(-7.0656, -3.5383)],
	["fence_n", Vector2(0.0, -9.2)],
	["fence_e", Vector2(7.0656, -3.5383)],
	["tower_nw", Vector2(-5.75, -5.75)],
	["tower_ne", Vector2(5.75, -5.75)],
	["tier_sign", Vector2(-10.0, 7.5)],
	["tower_w", Vector2(-11.35, 1.35)],
	["tower_e", Vector2(9.55, 1.85)],
	["tower_sw", Vector2(-7.35, 6.35)],
	["fence_sw", Vector2(-3.263, 9.167)],
	["tier_sign_3", Vector2(-4.7, 8.5)],
	["pad_fence_e_a", Vector2(6.1, -6.1)],
	["pad_fence_e_b", Vector2(9.5, -3.8)],
	["pad_fence_n_a", Vector2(-2.3, -10.4)],
	["pad_fence_n_b", Vector2(2.3, -10.4)],
	["pad_fence_sw_a", Vector2(-5.6, 7.8)],
	["pad_fence_sw_b", Vector2(-1.0, 10.5)],
	["pad_fence_w_a", Vector2(-9.6, -4.0)],
	["pad_fence_w_b", Vector2(-6.2, -6.2)],
	["pad_tower_e_a", Vector2(6.8, 3.0)],
	["pad_tower_e_b", Vector2(7.5, 0.0)],
	["pad_tower_ne_a", Vector2(3.2, -5.1)],
	["pad_tower_ne_b", Vector2(3.5, -7.3)],
	["pad_tower_nw_a", Vector2(-3.6, -7.3)],
	["pad_tower_nw_b", Vector2(-3.0, -5.1)],
	["pad_tower_sw_a", Vector2(-7.8, 4.1)],
	["pad_tower_sw_b", Vector2(-5.1, 3.7)],
	["pad_tower_w_a", Vector2(-10.7, 2.4)],
	["pad_tower_w_b", Vector2(-8.7, 0.8)],
	["zone_sw", Vector2(-2.75, 5.2)],
]
const EDGES_BOT3 := {
	"home": ["sign", "sw", "se", "front_e", "gold_pile", "fence_sw", "tier_sign_3"],
	"sign": ["home"],
	"gold_pile": ["home", "sw"],
	"front_e": ["home", "freezer", "counter_drop"],
	"counter_drop": ["front_e"],
	"freezer": ["front_e", "se"],
	"sw": ["home", "gold_pile", "nw", "zone_west", "tier_sign", "tower_w", "tower_sw", "fence_sw", "tier_sign_3", "zone_sw"],
	"se": ["home", "freezer", "ne", "e_mid", "tower_e"],
	"nw": ["sw", "zone_west", "zone_north", "fence_w", "fence_n", "tower_nw"],
	"ne": ["se", "zone_east", "zone_north", "fence_e", "fence_n", "tower_ne"],
	"e_mid": ["se", "zone_east"],
	"zone_west": ["sw", "nw", "fence_w", "tower_w"],
	"zone_north": ["nw", "ne", "fence_n"],
	"zone_east": ["e_mid", "ne", "fence_e", "tower_e"],
	"fence_w": ["nw", "zone_west", "pad_fence_w_a", "pad_fence_w_b"],
	"fence_n": ["nw", "ne", "zone_north", "pad_fence_n_a", "pad_fence_n_b"],
	"fence_e": ["ne", "zone_east", "pad_fence_e_a", "pad_fence_e_b"],
	"tower_nw": ["nw", "pad_tower_nw_a", "pad_tower_nw_b"],
	"tower_ne": ["ne", "pad_tower_ne_a", "pad_tower_ne_b"],
	"tier_sign": ["sw"],
	"tower_w": ["sw", "zone_west", "pad_tower_w_a", "pad_tower_w_b"],
	"tower_e": ["se", "zone_east", "pad_tower_e_a", "pad_tower_e_b"],
	"tower_sw": ["sw", "pad_tower_sw_a", "pad_tower_sw_b"],
	"fence_sw": ["sw", "home", "pad_fence_sw_a", "pad_fence_sw_b", "zone_sw"],
	"tier_sign_3": ["sw", "home"],
	"pad_fence_e_a": ["fence_e"],
	"pad_fence_e_b": ["fence_e"],
	"pad_fence_n_a": ["fence_n"],
	"pad_fence_n_b": ["fence_n"],
	"pad_fence_sw_a": ["fence_sw"],
	"pad_fence_sw_b": ["fence_sw"],
	"pad_fence_w_a": ["fence_w"],
	"pad_fence_w_b": ["fence_w"],
	"pad_tower_e_a": ["tower_e"],
	"pad_tower_e_b": ["tower_e"],
	"pad_tower_ne_a": ["tower_ne"],
	"pad_tower_ne_b": ["tower_ne"],
	"pad_tower_nw_a": ["tower_nw"],
	"pad_tower_nw_b": ["tower_nw"],
	"pad_tower_sw_a": ["tower_sw"],
	"pad_tower_sw_b": ["tower_sw"],
	"pad_tower_w_a": ["tower_w"],
	"pad_tower_w_b": ["tower_w"],
	"zone_sw": ["sw", "fence_sw"],
}

func _node_list(g: WaypointGraph) -> Array:
	var out: Array = []
	for n in g.nodes:
		out.append([n, Vector2(snappedf(g.nodes[n].x, 0.0001), snappedf(g.nodes[n].y, 0.0001))])
	return out

func test_the_tier_3_graph_is_pinned() -> void:
	var t3 := WaypointGraph.create_for_tier(3)
	assert_eq(_node_list(t3), NODES_TIER3)
	assert_eq(t3.edges, EDGES_TIER3)

func test_the_tier_3_bot_graph_is_pinned() -> void:
	var b3 := WaypointGraph.create_for_bot(3)
	assert_eq(_node_list(b3), NODES_BOT3)
	assert_eq(b3.edges, EDGES_BOT3)

func test_the_tier_4_graph_is_the_tier_3_graph_plus_the_back_lot() -> void:
	var t3 := WaypointGraph.create_for_tier(3)
	var t4 := WaypointGraph.create_for_tier(4)
	var extra: Array = []
	for n in t4.nodes:
		if not t3.nodes.has(n):
			extra.append(n)
	extra.sort()
	assert_eq(extra, ["pad_tower_e2_a", "pad_tower_e2_b", "pad_tower_n2_a", "pad_tower_n2_b", "tower_e2", "tower_n2"])
	for n in t3.nodes:
		assert_eq(t4.position_of(n), t3.position_of(n), n)
