class_name WaypointGraph
extends RefCounted
## Fixed bot navigation graph (D-057, D-112). Dijkstra with deterministic ties by name.

var nodes := {}   # name -> Vector2
var edges := {}   # name -> Array[String]

func add_node(node_name: String, pos: Vector2) -> void:
	nodes[node_name] = pos
	if not edges.has(node_name):
		edges[node_name] = []

func add_edge(a: String, b: String) -> void:
	if not b in edges[a]:
		edges[a].append(b)
	if not a in edges[b]:
		edges[b].append(a)

func position_of(node_name: String) -> Vector2:
	return nodes[node_name]

func nearest(p: Vector2) -> String:
	var names := nodes.keys()
	names.sort()
	var best := ""
	var best_d := INF
	for n in names:
		var d := p.distance_to(nodes[n])
		if d < best_d - 1e-6:
			best = n
			best_d = d
	return best

func shortest(from: String, to: String) -> Array:
	if not nodes.has(from) or not nodes.has(to):
		return []
	var dist := {}
	var prev := {}
	var open: Array = nodes.keys()
	for n in open:
		dist[n] = INF
	dist[from] = 0.0
	while not open.is_empty():
		open.sort_custom(func(a, b): return dist[a] < dist[b] or (dist[a] == dist[b] and a < b))
		var u: String = open.pop_front()
		if u == to or dist[u] == INF:
			break
		for v in edges[u]:
			var alt: float = dist[u] + (nodes[u] as Vector2).distance_to(nodes[v])
			if alt < dist[v] - 1e-9:
				dist[v] = alt
				prev[v] = u
	if dist[to] == INF:
		return []
	var path: Array = [to]
	while path[0] != from:
		path.push_front(prev[path[0]])
	return path

func route_from(p: Vector2, goal: String) -> Array:
	var start := nearest(p)
	var pts: Array = []
	for n in shortest(start, goal):
		pts.append(nodes[n])
	if not pts.is_empty() and p.distance_to(pts[0]) < 0.05:
		pts.pop_front()
	return pts

static func create_default() -> WaypointGraph:
	var g := WaypointGraph.new()
	g.add_node("home", MapLayout.HOME)
	g.add_node("sign", MapLayout.SIGN)
	g.add_node("gold_pile", MapLayout.GOLD_PILE)
	g.add_node("front_e", Vector2(3.0, 6.5))
	g.add_node("counter_drop", MapLayout.COUNTER_DROP)
	g.add_node("freezer", MapLayout.FREEZER_ZONE)
	g.add_node("sw", Vector2(-6.8, 6.8))
	g.add_node("se", Vector2(6.8, 6.8))
	g.add_node("nw", Vector2(-7, -7))
	g.add_node("ne", Vector2(7, -7))
	g.add_node("e_mid", Vector2(7.0, 3.0))  # D-144: a direct se–zone_east edge crosses the freezer
	for lane in ["west", "north", "east"]:
		g.add_node("zone_" + lane, MapLayout.lane_end(lane))
	g.add_node("fence_w", MapLayout.fence_spot("west"))
	g.add_node("fence_n", MapLayout.fence_spot("north"))
	g.add_node("fence_e", MapLayout.fence_spot("east"))
	g.add_node("tower_nw", MapLayout.tower_spot("tower_nw") + Vector2(-0.75, -0.75))
	g.add_node("tower_ne", MapLayout.tower_spot("tower_ne") + Vector2(0.75, -0.75))
	for e in [
		["home", "sign"], ["home", "sw"], ["home", "se"], ["home", "front_e"], ["home", "gold_pile"], ["sw", "gold_pile"],
		["front_e", "freezer"], ["front_e", "counter_drop"], ["se", "freezer"],
		["sw", "nw"], ["se", "ne"], ["sw", "zone_west"], ["se", "e_mid"], ["e_mid", "zone_east"],
		["nw", "zone_west"], ["nw", "zone_north"], ["nw", "fence_w"], ["nw", "fence_n"], ["nw", "tower_nw"],
		["ne", "zone_east"], ["ne", "zone_north"], ["ne", "fence_e"], ["ne", "fence_n"], ["ne", "tower_ne"],
		["zone_west", "fence_w"], ["zone_north", "fence_n"], ["zone_east", "fence_e"],
	]:
		g.add_edge(e[0], e[1])
	return g

## E5 (spec 5.2): the default graph plus the tier's sign and yard spots. create_default() stays frozen (D-230);
## only tests use this; TierBot walks create_for_bot(tier), which builds on it.
static func create_for_tier(tier: int) -> WaypointGraph:
	var g := create_default()
	if tier >= 2:
		g.add_node("tier_sign", MapLayout.TIER_SIGN)
		g.add_node("tower_w", MapLayout.tower_spot("tower_w") + Vector2(-0.75, 0.75))
		g.add_node("tower_e", MapLayout.tower_spot("tower_e") + Vector2(0.75, 0.75))
		for e in [["sw", "tier_sign"], ["sw", "tower_w"], ["zone_west", "tower_w"], ["se", "tower_e"], ["zone_east", "tower_e"]]:
			g.add_edge(e[0], e[1])
	if tier >= 3:
		_add_tier3(g)
	return g

## E5 tier 3 (spec 4.1, 4.3): the south-west tower stand point, the south-west fence spot, the tier-3 sign and every branch pad
## (`pad_<spot_id>_a` / `_b`, joined to the node of their own spot). Every new edge clears the diner, counter and freezer (test_tier3_layout).
static func _add_tier3(g: WaypointGraph) -> void:
	g.add_node("tower_sw", MapLayout.tower_spot("tower_sw") + Vector2(-0.75, 0.75))
	g.add_node("fence_sw", MapLayout.fence_spot("sw"))
	g.add_node("tier_sign_3", MapLayout.tier_sign(3))
	for e in [["sw", "tower_sw"], ["sw", "fence_sw"], ["home", "fence_sw"], ["sw", "tier_sign_3"], ["home", "tier_sign_3"]]:
		g.add_edge(e[0], e[1])
	var ids: Array = MapLayout.BRANCH_PADS.keys()
	ids.sort()
	for id in ids:
		var pads: Array = MapLayout.BRANCH_PADS[id]
		for i in pads.size():
			var pad_name := "pad_%s_%s" % [id, "ab"[i]]
			g.add_node(pad_name, pads[i])
			g.add_edge(pad_name, id)

## E5 tier 3 (Task 22): the graph the TierBot walks at `tier`. Tier 1 is the tier-2 graph it always had (byte-identical routes). Tier 2 adds
## the tier-3 sign on the front lot. Tier 3 adds the south-west zone node (the bot's night post, joined like the other zones to its
## corner and its fence). create_for_tier() stays as it is (test_tier3_layout pins its node and edge counts).
static func create_for_bot(tier: int) -> WaypointGraph:
	if tier < 3:
		var g := create_for_tier(2)
		if tier == 2:
			g.add_node("tier_sign_3", MapLayout.tier_sign(3))
			for e in [["sw", "tier_sign_3"], ["home", "tier_sign_3"]]:
				g.add_edge(e[0], e[1])
		return g
	var g3 := create_for_tier(3)
	g3.add_node("zone_sw", MapLayout.lane_end("sw"))
	for e in [["sw", "zone_sw"], ["fence_sw", "zone_sw"]]:
		g3.add_edge(e[0], e[1])
	return g3
