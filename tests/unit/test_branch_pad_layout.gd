extends GutTest
## E5 tier 3 (spec 4.3, D-263.4, D-266.2): the 18 branch pads (two per spot, radius 0.9) are fixed by these tests, not by eye.
## Every rule is re-derived here from MapLayout's lanes, zones, spots, stations and the tier-3 queue and traveler lines.

const NEAR := 2.8  # a pad stands within this of its spot
const APART := 2.2  # the two pads of a spot are at least this far apart
const MARGIN := 0.1  # every chosen pad clears every rule by at least this much (fence_w and fence_e are the tightest: the yards crowd them)
const TRAVELER_RADIUS := 0.3  # a queued traveler's body, kept clear of a pad
const NOT_BOTH_SIDES := ["tower_e", "tower_ne", "tower_nw", "tower_w"]  # pinned: their pads sit on one side of the building
const ASPECTS := [9.0 / 21.0, 720.0 / 1280.0, 16.0 / 9.0]
const PAD_COUNTER_NODE := "pad_counter"

var _tier := 3  # the tier whose spots _ids() lists: 3 for every test below but the tier-4 ones (E8 phase 2 Task 6)

func before_each() -> void:
	Balance.reset()
	_tier = 3

func _ids() -> Array:
	return MapLayout.spots_for_tier(_tier)

func _pad_list() -> Array:
	var out: Array = []
	for id in _ids():
		for i in 2:
			out.append({"id": id, "i": i, "pos": (MapLayout.BRANCH_PADS[id] as Array)[i]})
	return out

func _line_dist(p: Vector2, path: Array) -> float:
	var best := INF
	for i in range(1, path.size()):
		best = minf(best, Geometry.dist_point_segment(p, path[i - 1], path[i]))
	return best

## The 3 m fence bar of `lane`: perpendicular to the lane's tangent 4.0 m before its end, centred on the fence spot.
func _bar(lane: String) -> Array:
	var path: Array = MapLayout.lane_path(lane)
	var t := Geometry.tangent_at(path, Geometry.path_length(path) - MapLayout.FENCE_OFFSET_FROM_END)
	var n := Vector2(-t.y, t.x)
	var f := MapLayout.fence_spot(lane)
	return [f - n * MapLayout.FENCE_BAR_HALF, f + n * MapLayout.FENCE_BAR_HALF]

## Centre lines of every kerb piece of the open yards (tier 2): [a, b].
func _kerb_segments() -> Array:
	var out: Array = []
	for id in MapLayout.yards_for_tier(2):
		for xf in YardStones.transforms(MapLayout.yard_rect(id)):
			var half := Vector2(xf.basis.x.x, xf.basis.x.z) * 0.5
			var c := Vector2(xf.origin.x, xf.origin.z)
			out.append([c - half, c + half])
	return out

func _colliders() -> Array:
	return [
		Rect2(-MapLayout.DINER_HALF, -MapLayout.DINER_HALF, MapLayout.DINER_HALF * 2, MapLayout.DINER_HALF * 2),
		Rect2(MapLayout.COUNTER - MapLayout.COUNTER_SIZE / 2, MapLayout.COUNTER_SIZE),
		Rect2(MapLayout.FREEZER - MapLayout.FREEZER_SIZE / 2, MapLayout.FREEZER_SIZE),
	]

## [[clearance, what], ...] of the pad at `p` (clearance = distance minus the radii involved; the rule holds at >= 0).
func _clearances(p: Vector2, own: String, others: Array) -> Array:
	var out := _clearances_nokerb(p, own, others)
	for k in _kerb_segments():
		out.append([Geometry.dist_point_segment(p, k[0], k[1]) - MapLayout.BRANCH_PAD_RADIUS - YardStones.WIDTH * 0.5, "yard kerb"])
	return out

## The same without the tier-2 yards' kerb (a search caches that list).
func _clearances_nokerb(p: Vector2, own: String, others: Array) -> Array:
	var r := MapLayout.BRANCH_PAD_RADIUS
	var spread: float = Balance.data.enemy.lateral_spread
	var out: Array = []
	for lane in MapLayout.lanes_for_tier(3):
		out.append([_line_dist(p, MapLayout.lane_path(lane)) - spread - r, "lane " + lane])
		out.append([Geometry.dist_point_rect(p, MapLayout.zone_rect(lane)) - r, "attack zone " + lane])
		var bar := _bar(lane)
		out.append([Geometry.dist_point_segment(p, bar[0], bar[1]) - r, "fence bar " + lane])
	for id in _ids():
		if MapLayout.spot_kind(id) == "tower":
			out.append([p.distance_to(MapLayout.spot_position(id)) - r - MapLayout.TOWER_VISUAL_RADIUS, "own tower" if id == own else "tower " + id])
	for o in others:
		out.append([p.distance_to(o) - 2.0 * r, "other pad"])
	out.append([p.distance_to(MapLayout.SIGN) - r - MapLayout.STATION_RADIUS, "close-up sign"])
	out.append([p.distance_to(MapLayout.FREEZER_ZONE) - r - MapLayout.STATION_RADIUS, "freezer zone"])
	out.append([p.distance_to(MapLayout.COUNTER_DROP) - r - MapLayout.STATION_RADIUS, "counter zone"])
	for id in MapLayout.STATION_PADS:
		out.append([p.distance_to(MapLayout.STATION_PADS[id]) - r - MapLayout.BUILD_RADIUS, "station pad %s" % id])
	out.append([p.distance_to(MapLayout.GOLD_PILE) - r, "gold pile"])
	out.append([p.distance_to(MapLayout.HOME) - r, "HOME"])
	out.append([p.distance_to(MapLayout.DINER_DOOR) - r, "diner door"])
	for q in MapLayout.queue_slots(3):
		out.append([p.distance_to(q) - r - TRAVELER_RADIUS, "queue slot"])
		out.append([Geometry.dist_point_segment(p, MapLayout.TRAVELER_ENTER, q) - r, "traveler entry line"])
	out.append([Geometry.dist_point_segment(p, MapLayout.SERVICE_POINT, MapLayout.traveler_exit(3)) - r, "traveler exit line"])
	for c in _colliders():
		out.append([Geometry.dist_point_rect(p, c) - r, "hero collider"])
	# owned-land props of the open yards: the centres keep pad radius + prop radius apart, plus the camera-lean term for a prop SOUTH of the
	# pad (its top leans north over the pad on screen); test_yards applies the stricter every-direction lean to the same pads
	var lean_k := 1.0 / tan(deg_to_rad(absf(Balance.ui.camera_pitch)))
	for id in MapLayout.yards_for_tier(2):
		for it in PropsLayout.OWNED.get(id, []):
			var need := r + Props.owned_radius(it.kind, float(it.scale))
			if it.pos.y > p.y:
				need += Props.owned_height(it.kind, float(it.scale)) * lean_k
			out.append([p.distance_to(it.pos) - need, "owned %s in the %s yard" % [it.kind, id]])
	var inside := minf(minf(p.x - MapLayout.BOUNDS_MIN.x, MapLayout.BOUNDS_MAX.x - p.x), minf(p.y - MapLayout.BOUNDS_MIN.y, MapLayout.BOUNDS_MAX.y - p.y))
	out.append([inside - r, "map bounds"])
	return out

func _least(list: Array) -> Array:
	var best: Array = [INF, ""]
	for c in list:
		if c[0] < best[0]:
			best = c
	return best

func test_the_table_has_the_nine_spots_and_eighteen_pads() -> void:
	assert_eq(MapLayout.BRANCH_PAD_RADIUS, 0.9)
	var keys := MapLayout.BRANCH_PADS.keys()
	keys.sort()
	var want := _ids()
	want.sort()
	# E8 Task 6: the table gained the back lot's two spots; its tier-3 part is still exactly the nine, and the whole is one entry per tier-4 spot
	var t3_keys := keys.filter(func(k): return MapLayout.spot_tier(k) <= 3)
	assert_eq(t3_keys, want, "one entry per tier-3 spot")
	var all_want := MapLayout.spots_for_tier(4)
	all_want.sort()
	assert_eq(keys, all_want, "and one per tier-4 spot")
	assert_eq(want.size(), 9)
	for id in want:
		assert_eq((MapLayout.BRANCH_PADS[id] as Array).size(), 2, id)
	assert_eq(_pad_list().size(), 18)

func test_pads_are_on_a_tenth_of_a_metre() -> void:
	for pad in _pad_list():
		for v in [pad.pos.x, pad.pos.y]:
			assert_almost_eq(v * 10.0, roundf(v * 10.0), 1e-4, "%s pad %d: %s" % [pad.id, pad.i, pad.pos])

func test_each_pad_is_near_its_spot_and_the_pair_is_apart() -> void:
	for id in _ids():
		var pads: Array = MapLayout.BRANCH_PADS[id]
		for p in pads:
			assert_lte((p as Vector2).distance_to(MapLayout.spot_position(id)), NEAR, "%s pad %s within %.1f m of its spot" % [id, p, NEAR])
		assert_gte((pads[0] as Vector2).distance_to(pads[1]), APART, "%s: the two pads are %.1f m apart" % [id, APART])

func test_every_pad_clears_every_rule_with_margin() -> void:
	var all: Array = []
	for pad in _pad_list():
		all.append(pad.pos)
	var worst := INF
	for pad in _pad_list():
		var others := all.duplicate()
		others.erase(pad.pos)
		var list := _clearances(pad.pos, pad.id, others)
		for c in list:
			assert_gte(float(c[0]), 0.0, "%s pad %d at %s: %s" % [pad.id, pad.i, pad.pos, c[1]])
		var least := _least(list)
		worst = minf(worst, float(least[0]))
		gut.p("%-9s %s %s: smallest clearance %.2f m (%s)" % [pad.id, "ab"[pad.i], pad.pos, least[0], least[1]])
		assert_gte(float(least[0]), MARGIN, "%s pad %d keeps a margin of %.1f m (limit: %s)" % [pad.id, pad.i, MARGIN, least[1]])
	gut.p("worst pad clearance %.2f m" % worst)

func test_a_rule_would_catch_a_bad_pad() -> void:
	# negative controls: a pad on the SW lane, on the SW fence spot's bar, in the diner, and on top of its own tower
	var lane_pt := MapLayout.lane_path("sw")[1] as Vector2 - Vector2(2.0, 0.0)
	assert_lt(float(_least(_clearances(lane_pt, "tower_sw", []))[0]), 0.0)
	assert_lt(float(_least(_clearances(MapLayout.fence_spot("sw"), "fence_sw", []))[0]), 0.0)
	assert_lt(float(_least(_clearances(Vector2(0, 0), "tower_nw", []))[0]), 0.0)
	assert_lt(float(_least(_clearances(MapLayout.tower_spot("tower_sw") + Vector2(1.0, 0), "tower_sw", []))[0]), 0.0)

func test_the_building_and_the_other_pad_are_on_screen_from_either_pad() -> void:
	for pad in _pad_list():
		var spot := MapLayout.spot_position(pad.id)
		var other: Vector2 = (MapLayout.BRANCH_PADS[pad.id] as Array)[1 - pad.i]
		var xf := CameraMath.camera_transform(CameraMath.focus_for(pad.pos), Balance.ui)
		for aspect in ASPECTS:
			var proj := CameraMath.projection(Balance.ui, aspect)
			assert_true(CameraMath.on_screen(MapLayout.to3(spot), xf, proj), "%s from its pad %s at aspect %.3f" % [pad.id, pad.pos, aspect])
			assert_true(CameraMath.on_screen(MapLayout.to3(other), xf, proj), "%s: the other pad %s from pad %s at aspect %.3f" % [pad.id, other, pad.pos, aspect])

func test_pad_sides_as_the_camera_sees_them() -> void:
	# the camera looks north from the south, so x is left to right: a pair reads best with one pad clearly left (dx <= -0.5) and one
	# clearly right (dx >= +0.5) of the building. The spots that cannot (the yards and the diner crowd them) are pinned.
	var not_both: Array = []
	for id in _ids():
		var spot := MapLayout.spot_position(id)
		var pads: Array = MapLayout.BRANCH_PADS[id]
		var dx: Array = [pads[0].x - spot.x, pads[1].x - spot.x]
		gut.p("%-9s pads at dx %+.1f and %+.1f" % [id, dx[0], dx[1]])
		if not ((dx[0] <= -0.5 and dx[1] >= 0.5) or (dx[1] <= -0.5 and dx[0] >= 0.5)):
			not_both.append(id)
	not_both.sort()
	assert_eq(not_both, NOT_BOTH_SIDES)

# --- E6 (spec 5.3, D-284.5, D-307): the pads the retune moved --------------------------------------------------------------------
# MapLayout.BRANCH_PADS is the retuned table (the pre-retune one is gone). Every pad of it passes the rules above, and also the front lot's kerb,
# props and the south-west lane's edge stones (laid out with these pads, since round 2).

func _retune_pad_list() -> Array:
	var out: Array = []
	var table := MapLayout.BRANCH_PADS
	for id in _ids():
		for i in 2:
			out.append({"id": id, "i": i, "pos": (table[id] as Array)[i]})
	return out

## Rules the table-wide `_clearances` does not have: the front lot's kerb as laid out, the front lot's props (as the tier-2 yards' above), the
## south-west lane's edge stones. [[clearance, what]].
func _lot_clearances(p: Vector2) -> Array:
	var r := MapLayout.BRANCH_PAD_RADIUS
	var out: Array = []
	for xf in YardStones.transforms(MapLayout.yard_rect("front"), true, Balance.data.enemy.lateral_spread):
		var half := Vector2(xf.basis.x.x, xf.basis.x.z) * 0.5
		var c := Vector2(xf.origin.x, xf.origin.z)
		out.append([Geometry.dist_point_segment(p, c - half, c + half) - r - YardStones.WIDTH * 0.5, "front lot kerb"])
	var lean_k := 1.0 / tan(deg_to_rad(absf(Balance.ui.camera_pitch)))
	for it in PropsLayout.OWNED.get("front", []):  # the rule of the tier-2 yards above: footprint, plus the lean for a prop SOUTH of the pad
		var need := r + Props.owned_radius(it.kind, float(it.scale))
		if it.pos.y > p.y:
			need += Props.owned_height(it.kind, float(it.scale)) * lean_k
		out.append([p.distance_to(it.pos) - need, "front lot %s" % it.kind])
	for xf in LaneStrip.edge_transforms(MapLayout.lane_path("sw"), LaneStrip.STONE_SPACING, LaneStrip.WIDTH, true, _tier):
		out.append([p.distance_to(Vector2(xf.origin.x, xf.origin.z)) - r - LaneStrip.STONE_RADIUS, "south-west lane stone"])
	return out

## The shipped table, pinned as literals (the retune's pads; the pre-retune ones are gone). Mutation: a pad moved by a tenth.
const SHIPPED := {
	"tower_sw": [Vector2(-7.8, 4.1), Vector2(-5.1, 3.7)], "fence_sw": [Vector2(-5.6, 7.8), Vector2(-1.0, 10.5)],
	"fence_w": [Vector2(-9.6, -4.0), Vector2(-6.2, -6.2)], "fence_n": [Vector2(-2.3, -10.4), Vector2(2.3, -10.4)],
	"fence_e": [Vector2(6.1, -6.1), Vector2(9.5, -3.8)], "tower_nw": [Vector2(-3.6, -7.3), Vector2(-3.0, -5.1)],
	"tower_ne": [Vector2(3.2, -5.1), Vector2(3.5, -7.3)], "tower_w": [Vector2(-10.7, 2.4), Vector2(-8.7, 0.8)],
	"tower_e": [Vector2(6.8, 3.0), Vector2(7.5, 0.0)],
}

## E8 phase 2 Task 6: the back lot's pads, pinned as literals (the tier-3 table above is unchanged and still pinned).
const SHIPPED_T4 := {"tower_sw2": [Vector2(4.5, 11.6), Vector2(6.3, 12.9)], "tower_e2": [Vector2(11.3, -1.9), Vector2(11.6, -4.1)]}

func test_the_table_is_the_pinned_nine_spots_and_the_accessor_agrees() -> void:
	var t3_part := {}
	for id in MapLayout.BRANCH_PADS:
		if MapLayout.spot_tier(id) <= 3:
			t3_part[id] = MapLayout.BRANCH_PADS[id]
	assert_eq(t3_part, SHIPPED, "the nine tier-3 spots keep their pinned pads")
	var t4_part := {}
	for id in MapLayout.BRANCH_PADS:
		if MapLayout.spot_tier(id) == 4:
			t4_part[id] = MapLayout.BRANCH_PADS[id]
	assert_eq(t4_part, SHIPPED_T4, "the back lot's two")
	var keys := t3_part.keys()
	keys.sort()
	var want := _ids()
	want.sort()
	assert_eq(keys, want, "the nine spots")
	for id in _ids():
		for i in 2:
			assert_eq(MapLayout.branch_pad(id, i), (MapLayout.BRANCH_PADS[id] as Array)[i], "%s pad %d: the accessor agrees" % [id, i])
	# Task 14 round 5 (a Task 14 statement, not an author rule): fence_n's pads move 0.2 m toward each other so the NEAR glyph, centred in its ring, keeps 8 px from the lane badges
	assert_eq(MapLayout.branch_pad("fence_n", 0), Vector2(-2.3, -10.4))
	assert_eq(MapLayout.branch_pad("fence_n", 1), Vector2(2.3, -10.4))

func test_retune_pads_are_on_a_tenth_of_a_metre_near_their_spot_and_apart() -> void:
	for pad in _retune_pad_list():
		for v in [pad.pos.x, pad.pos.y]:
			assert_almost_eq(v * 10.0, roundf(v * 10.0), 1e-4, "%s pad %d: %s" % [pad.id, pad.i, pad.pos])
	var on := MapLayout.BRANCH_PADS
	for id in _ids():
		var pads: Array = on[id]
		for p in pads:
			assert_lte((p as Vector2).distance_to(MapLayout.spot_position(id)), NEAR, "%s pad %s within %.1f m of its spot" % [id, p, NEAR])
		assert_gte((pads[0] as Vector2).distance_to(pads[1]), APART, "%s: the two pads are %.1f m apart" % [id, APART])

func test_retune_every_pad_clears_every_rule_with_margin() -> void:
	var all: Array = []
	for pad in _retune_pad_list():
		all.append(pad.pos)
	var worst := INF
	for pad in _retune_pad_list():
		var others := all.duplicate()
		others.erase(pad.pos)
		var list := _clearances(pad.pos, pad.id, others)
		list.append_array(_lot_clearances(pad.pos))
		for c in list:
			assert_gte(float(c[0]), 0.0, "%s pad %d at %s: %s" % [pad.id, pad.i, pad.pos, c[1]])
		var least := _least(list)
		worst = minf(worst, float(least[0]))
		gut.p("%-9s %s %s: smallest clearance %.2f m (%s)%s" % [pad.id, "ab"[pad.i], pad.pos, least[0], least[1], ""])
		assert_gte(float(least[0]), MARGIN, "%s pad %d keeps a margin of %.1f m (limit: %s)" % [pad.id, pad.i, MARGIN, least[1]])
	gut.p("worst retune pad clearance %.2f m" % worst)

func test_retune_a_lot_rule_would_catch_a_bad_pad() -> void:
	# negative controls: a pad on the front lot's props, on its kerb, and on a south-west lane stone
	var prop: Vector2 = (PropsLayout.OWNED["front"] as Array)[0].pos
	assert_lt(float(_least(_lot_clearances(prop))[0]), 0.0, "on a front-lot prop")
	var kerb: Array = YardStones.transforms(MapLayout.yard_rect("front"), true, Balance.data.enemy.lateral_spread)
	var xf: Transform3D = kerb[0]
	assert_lt(float(_least(_lot_clearances(Vector2(xf.origin.x, xf.origin.z)))[0]), 0.0, "on the kerb")
	var stones: Array = LaneStrip.edge_transforms(MapLayout.lane_path("sw"), LaneStrip.STONE_SPACING, LaneStrip.WIDTH, true)
	assert_gt(stones.size(), 0)
	assert_lt(float(_least(_lot_clearances(Vector2(stones[0].origin.x, stones[0].origin.z)))[0]), 0.0, "on a lane stone")

func test_retune_the_building_and_the_other_pad_are_on_screen_from_either_pad() -> void:
	var on := MapLayout.BRANCH_PADS
	for pad in _retune_pad_list():
		var spot := MapLayout.spot_position(pad.id)
		var other: Vector2 = (on[pad.id] as Array)[1 - pad.i]
		var xf := CameraMath.camera_transform(CameraMath.focus_for(pad.pos), Balance.ui)
		for aspect in ASPECTS:
			var proj := CameraMath.projection(Balance.ui, aspect)
			assert_true(CameraMath.on_screen(MapLayout.to3(spot), xf, proj), "%s from its pad %s at aspect %.3f" % [pad.id, pad.pos, aspect])
			assert_true(CameraMath.on_screen(MapLayout.to3(other), xf, proj), "%s: the other pad %s from pad %s at aspect %.3f" % [pad.id, other, pad.pos, aspect])

## The bot walks to the pads where they stand: the graph's pad nodes are the table's, and the edges clear the colliders; a TierBot at tier 3 has them.
func test_retune_the_graph_and_the_bot_walk_to_the_moved_pads() -> void:
	var g := WaypointGraph.create_for_tier(3)
	var table := {}  # the tier-3 spots' pads: the tier-3 graph has no back lot (E8 B1)
	for id in MapLayout.BRANCH_PADS:
		if MapLayout.spot_tier(id) <= 3:
			table[id] = MapLayout.BRANCH_PADS[id]
	for id in table:
		for i in 2:
			var pad_name := "pad_%s_%s" % [id, "ab"[i]]
			assert_eq(g.position_of(pad_name), (table[id] as Array)[i], pad_name)
			assert_false(g.shortest("home", pad_name).is_empty(), "home reaches %s" % pad_name)
	var bodies := [Rect2(-4, -4, 8, 8), Rect2(MapLayout.COUNTER - MapLayout.COUNTER_SIZE / 2, MapLayout.COUNTER_SIZE),
		Rect2(MapLayout.FREEZER - MapLayout.FREEZER_SIZE / 2, MapLayout.FREEZER_SIZE)]
	for id in table:
		for i in 2:
			var pa: Vector2 = g.position_of("pad_%s_%s" % [id, "ab"[i]])
			var pb: Vector2 = g.position_of(id)
			for k in 101:
				for body in bodies:
					assert_true(Geometry.dist_point_rect(pa.lerp(pb, k / 100.0), body) >= MapLayout.HERO_RADIUS - 0.01, "edge pad_%s_%s-%s hits a collider" % [id, "ab"[i], id])
	var for_bot := WaypointGraph.create_for_bot(3)
	for id in table:
		for i in 2:
			assert_eq(for_bot.position_of("pad_%s_%s" % [id, "ab"[i]]), (table[id] as Array)[i], "the bot's graph: %s pad %d" % [id, i])
	# the bot itself: its graph at tier 3 holds the table's pads
	GameState.new_game(1)
	GameState.debug_set_tier(3, 1)
	var bot := TierBot.new()
	bot._sync_graph()
	for id in table:
		assert_eq(bot.graph.position_of("pad_%s_a" % id), (table[id] as Array)[0], "%s: the table's pad" % id)
	assert_eq(bot.graph.position_of(PAD_COUNTER_NODE), MapLayout.STATION_PADS[&"counter"], "the station pads are still there")
	bot.free()

## The kerb and the lane stones follow the pads (art/env/yard_stones.gd and lane_strip.gd read the same table): no kerb piece and no lane stone is within a
## pad's radius of any pad of the table.
func test_retune_no_kerb_piece_or_lane_stone_is_within_a_pad_radius() -> void:
	var r := MapLayout.BRANCH_PAD_RADIUS
	var spread: float = Balance.data.enemy.lateral_spread
	var pads: Array = []
	for id in MapLayout.BRANCH_PADS:
		if MapLayout.spot_tier(id) <= 3:  # the tier-4 pads are read by the tier-4 kerb (the test at the end of the file)
			pads.append_array(MapLayout.BRANCH_PADS[id])
	assert_eq(pads.size(), 18)
	var pieces := 0
	for yard in MapLayout.all_yards():
		if MapLayout.yard_tier(yard) > 3:
			continue
		var rect := MapLayout.yard_rect(yard)
		var t3 := MapLayout.yard_tier(yard) >= 3
		for xf in YardStones.transforms(rect, t3, spread):
			var half := Vector2(xf.basis.x.x, xf.basis.x.z) * 0.5
			var c := Vector2(xf.origin.x, xf.origin.z)
			pieces += 1
			if not t3:
				continue  # the tier-2 yards' kerb meets the pads through the layout test's yard-kerb rule
			for p in pads:
				assert_gte(Geometry.dist_point_segment(p, c - half, c + half), r, "a kerb piece at %s lies within the radius of the pad at %s" % [c, p])
	assert_gt(pieces, 0)
	var stones := 0
	for lane in MapLayout.lanes_for_tier(3):
		if lane in LaneStrip.DRAW_ORDER:
			continue
		for xf in LaneStrip.edge_transforms(MapLayout.lane_path(lane), LaneStrip.STONE_SPACING, LaneStrip.WIDTH, true):
			stones += 1
			for p in pads:
				assert_gte(p.distance_to(Vector2(xf.origin.x, xf.origin.z)), r, "a lane stone at %s lies within the radius of the pad at %s" % [xf.origin, p])
	assert_gt(stones, 0)

# --- E8 phase 2 Task 6 (spec 4.3): the back lot's four pads ------------------------------------------------------------------------
# The same rules, over the eleven spots and 22 pads of tier 4 (the tower and pad checks above stay the tier-3 ones: _tier is 3 there).

## Centre lines of every kerb piece of the tier-4 yards as the tier-4 world lays them out: [a, b].
func _kerb_t4() -> Array:
	var out: Array = []
	var spread: float = Balance.data.enemy.lateral_spread
	for id in MapLayout.yards_for_tier(4):
		if MapLayout.yard_tier(id) < 4:
			continue
		for xf in YardStones.transforms(MapLayout.yard_rect(id), true, spread, 4):
			var half := Vector2(xf.basis.x.x, xf.basis.x.z) * 0.5
			var c := Vector2(xf.origin.x, xf.origin.z)
			out.append([c - half, c + half])
	return out

func test_t4_every_pad_of_the_back_lot_clears_every_rule_with_margin() -> void:
	_tier = 4
	var all: Array = []
	for pad in _pad_list():
		all.append(pad.pos)
	assert_eq(all.size(), 22)
	var kerb := _kerb_t4()
	assert_gt(kerb.size(), 0, "the back lot has a kerb")
	var worst := INF
	for pad in _pad_list():
		var others := all.duplicate()
		others.erase(pad.pos)
		var list := _clearances(pad.pos, pad.id, others)
		list.append_array(_lot_clearances(pad.pos))
		for k in kerb:
			list.append([Geometry.dist_point_segment(pad.pos, k[0], k[1]) - MapLayout.BRANCH_PAD_RADIUS - YardStones.WIDTH * 0.5, "back lot kerb"])
		for c in list:
			assert_gte(float(c[0]), 0.0, "%s pad %d at %s: %s" % [pad.id, pad.i, pad.pos, c[1]])
		var least := _least(list)
		if MapLayout.spot_tier(pad.id) == 4:
			gut.p("%-9s %s %s: smallest clearance %.2f m (%s)" % [pad.id, "ab"[pad.i], pad.pos, least[0], least[1]])
		worst = minf(worst, float(least[0]))
		assert_gte(float(least[0]), MARGIN, "%s pad %d keeps a margin of %.1f m (limit: %s)" % [pad.id, pad.i, MARGIN, least[1]])
	gut.p("worst tier-4 pad clearance %.2f m" % worst)

func test_t4_the_back_lot_pads_are_on_a_tenth_near_their_spot_and_apart() -> void:
	for id in MapLayout.TIER_SPOTS[4]:
		var pads: Array = MapLayout.BRANCH_PADS[id]
		assert_eq(pads.size(), 2, id)
		for p in pads:
			for v in [p.x, p.y]:
				assert_almost_eq(v * 10.0, roundf(v * 10.0), 1e-4, "%s pad %s" % [id, p])
			assert_lte((p as Vector2).distance_to(MapLayout.spot_position(id)), NEAR, "%s pad %s within %.1f m of its spot" % [id, p, NEAR])
		assert_gte((pads[0] as Vector2).distance_to(pads[1]), APART, "%s: the two pads are %.1f m apart" % [id, APART])

func test_t4_the_building_and_the_other_pad_are_on_screen_from_either_pad() -> void:
	for id in MapLayout.TIER_SPOTS[4]:
		var spot := MapLayout.spot_position(id)
		var pads: Array = MapLayout.BRANCH_PADS[id]
		for i in 2:
			var xf := CameraMath.camera_transform(CameraMath.focus_for(pads[i]), Balance.ui)
			for aspect in ASPECTS:
				var proj := CameraMath.projection(Balance.ui, aspect)
				assert_true(CameraMath.on_screen(MapLayout.to3(spot), xf, proj), "%s from its pad %s at aspect %.3f" % [id, pads[i], aspect])
				assert_true(CameraMath.on_screen(MapLayout.to3(pads[1 - i]), xf, proj), "%s: the other pad from pad %s at aspect %.3f" % [id, pads[i], aspect])

func test_t4_a_rule_would_catch_a_bad_back_lot_pad() -> void:
	_tier = 4
	# negative controls: on the sw tower, on the east lane, on the queue's road line, and on the sw2 tower's own neighbour pad
	assert_lt(float(_least(_clearances(MapLayout.tower_spot("tower_sw2") + Vector2(0.5, 0), "tower_sw2", []))[0]), 0.0)
	assert_lt(float(_least(_clearances(Vector2(7.0, -3.0), "tower_e2", []))[0]), 0.0, "on the east lane")
	assert_lt(float(_least(_clearances(Vector2(4.5, 10.6), "tower_sw2", []))[0]), 0.0, "on the traveler road line")
	assert_lt(float(_least(_clearances(MapLayout.BRANCH_PADS["tower_sw2"][1] + Vector2(0.5, 0), "tower_sw2", [MapLayout.BRANCH_PADS["tower_sw2"][1]]))[0]), 0.0, "on another pad")

func test_t4_the_graph_reaches_the_back_lot_pads_and_tier_3_has_none() -> void:
	var g3 := WaypointGraph.create_for_tier(3)
	var g4 := WaypointGraph.create_for_tier(4)
	var bodies := [Rect2(-4, -4, 8, 8), Rect2(MapLayout.COUNTER - MapLayout.COUNTER_SIZE / 2, MapLayout.COUNTER_SIZE),
		Rect2(MapLayout.FREEZER - MapLayout.FREEZER_SIZE / 2, MapLayout.FREEZER_SIZE)]
	for id in MapLayout.TIER_SPOTS[4]:
		assert_false(g3.nodes.has(id), "%s is not in the tier-3 graph" % id)
		assert_true(g4.nodes.has(id))
		assert_lte(g4.position_of(id).distance_to(MapLayout.spot_position(id)), MapLayout.BUILD_RADIUS, "%s stand point inside the build radius" % id)
		assert_gte(g4.position_of(id).distance_to(MapLayout.spot_position(id)), MapLayout.TOWER_VISUAL_RADIUS, "%s stand point beside the mesh" % id)
		for i in 2:
			var pad_name := "pad_%s_%s" % [id, "ab"[i]]
			assert_false(g3.nodes.has(pad_name), pad_name + " is not in the tier-3 graph")
			assert_eq(g4.position_of(pad_name), (MapLayout.BRANCH_PADS[id] as Array)[i], pad_name)
			assert_false(g4.shortest("home", pad_name).is_empty(), "home reaches %s" % pad_name)
			var pa: Vector2 = g4.position_of(pad_name)
			var pb: Vector2 = g4.position_of(id)
			for k in 101:
				for body in bodies:
					assert_gte(Geometry.dist_point_rect(pa.lerp(pb, k / 100.0), body), MapLayout.HERO_RADIUS - 0.01, "edge %s-%s hits a collider" % [pad_name, id])
	# every edge the tier-4 graph adds clears the colliders
	for a in g4.edges:
		for b in g4.edges[a]:
			if g3.edges.has(a) and (g3.edges[a] as Array).has(b):
				continue
			var pa: Vector2 = g4.position_of(a)
			var pb: Vector2 = g4.position_of(b)
			var n := maxi(50, ceili(pa.distance_to(pb) / 0.05))
			for k in n + 1:
				for body in bodies:
					assert_gte(Geometry.dist_point_rect(pa.lerp(pb, float(k) / n), body), MapLayout.HERO_RADIUS - 0.01, "edge %s-%s hits a collider" % [a, b])
	assert_eq(g4.nodes.size(), g3.nodes.size() + 2 + 4)
	for n in g3.nodes:
		assert_eq(g4.position_of(n), g3.position_of(n), "%s keeps its position" % n)

## E8 B2: the kerb and the lane stones of tiers 1 to 3 are the same whether the tier-4 spots and pads are read or not, and the back lot's own kerb and the
## south-west lane's stones (tier 4) keep a pad radius off the back lot's pads.
func test_t4_the_tier_4_pads_move_no_older_kerb_piece_and_no_older_stone() -> void:
	var spread: float = Balance.data.enemy.lateral_spread
	for yard in MapLayout.yards_for_tier(3):
		var t3 := MapLayout.yard_tier(yard) >= 3
		var a := YardStones.transforms(MapLayout.yard_rect(yard), t3, spread, 3)
		var b := YardStones.transforms(MapLayout.yard_rect(yard), t3, spread, 4)
		assert_gt(a.size(), 0, yard)
		if yard != "east":
			assert_eq(a, b, "the %s yard's kerb is the same at tier 4" % yard)
			continue
		# the east yard: tower_e2 stands 1.7 m off its north edge (the only land in reach of the east zone, see test_tier3_layout), so tier 4 leaves a gap in the
		# kerb where that tower's pad touches the edge, as every spot at a yard edge does: no piece is added, and every piece that goes is near the tower
		var gone := 0
		var tower := MapLayout.spot_position("tower_e2")
		for xf in a:
			if not b.has(xf):
				gone += 1
				assert_lt(Vector2(xf.origin.x, xf.origin.z).distance_to(tower), YardStones.PAD_CLEAR + YardStones.SPACING, "a piece far from tower_e2 changed")
		for xf in b:
			assert_true(a.has(xf), "tier 4 adds no kerb piece to the east yard")
		gut.p("east yard kerb: %d pieces at tier 3, %d at tier 4 (%d gone beside tower_e2)" % [a.size(), b.size(), gone])
	var sw: Array = MapLayout.lane_path("sw")
	var s3 := LaneStrip.edge_transforms(sw, LaneStrip.STONE_SPACING, LaneStrip.WIDTH, true, 3)
	var s4 := LaneStrip.edge_transforms(sw, LaneStrip.STONE_SPACING, LaneStrip.WIDTH, true, 4)
	assert_gt(s3.size(), 0)
	assert_eq(s3, s4, "the south-west lane's stones are the same at tier 4")
	assert_eq(LaneStrip.edge_multimesh(["west", "north", "east", "sw"]).instance_count, LaneStrip.edge_multimesh(["west", "north", "east", "sw"], 4).instance_count)
	# the tier-4 kerb keeps off every tier-4 pad
	var pads: Array = []
	for id in MapLayout.TIER_SPOTS[4]:
		pads.append_array(MapLayout.BRANCH_PADS[id])
	for k in _kerb_t4():
		for p in pads:
			assert_gte(Geometry.dist_point_segment(p, k[0], k[1]), MapLayout.BRANCH_PAD_RADIUS, "a back-lot kerb piece on the pad at %s" % p)
	for xf in s4:
		for p in pads:
			assert_gte(p.distance_to(Vector2(xf.origin.x, xf.origin.z)), MapLayout.BRANCH_PAD_RADIUS, "a lane stone on the pad at %s" % p)
	# the default of the stone and kerb builders reads tier 3 only: a pad of tier 4 is in the tier-4 lists and not in the tier-3 ones
	assert_eq(YardStones.pad_points(3).size(), 11)
	assert_eq(YardStones.pad_points(4).size(), 13)
	assert_eq(YardStones.branch_pad_points(3).size(), 18)
	assert_eq(YardStones.branch_pad_points(4).size(), 22)
	assert_eq(LaneStrip.avoid_circles(4).size(), LaneStrip.avoid_circles(3).size() + 2 + 4 + 1, "two spots, four pads and the tier-4 sign")
