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

func before_each() -> void:
	Balance.reset()

func _ids() -> Array:
	return MapLayout.spots_for_tier(3)

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
	assert_eq(keys, want, "one entry per tier-3 spot")
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

# --- E6 (spec 5.3, D-284.5, D-286): the pads the retune moves --------------------------------------------------------------------
# MapLayout.branch_pads(true) is BRANCH_PADS with the spots of BRANCH_PADS_RETUNE replaced. Every pad of it passes the rules above, and the
# moved ones also the front lot's kerb, props and the south-west lane's edge stones (laid out with the moved pads, since round 2); the flag-off table is untouched.

func _retune_pad_list() -> Array:
	var out: Array = []
	var table := MapLayout.branch_pads(true)
	for id in _ids():
		for i in 2:
			out.append({"id": id, "i": i, "pos": (table[id] as Array)[i]})
	return out

## Rules the table-wide `_clearances` does not have: the front lot's kerb as laid out, the front lot's props (as the tier-2 yards' above), the
## south-west lane's edge stones. [[clearance, what]].
func _lot_clearances(p: Vector2) -> Array:
	var r := MapLayout.BRANCH_PAD_RADIUS
	var out: Array = []
	for xf in YardStones.transforms(MapLayout.yard_rect("front"), true, Balance.data.enemy.lateral_spread, true):
		var half := Vector2(xf.basis.x.x, xf.basis.x.z) * 0.5
		var c := Vector2(xf.origin.x, xf.origin.z)
		out.append([Geometry.dist_point_segment(p, c - half, c + half) - r - YardStones.WIDTH * 0.5, "front lot kerb"])
	var lean_k := 1.0 / tan(deg_to_rad(absf(Balance.ui.camera_pitch)))
	for it in PropsLayout.OWNED.get("front", []):  # the rule of the tier-2 yards above: footprint, plus the lean for a prop SOUTH of the pad
		var need := r + Props.owned_radius(it.kind, float(it.scale))
		if it.pos.y > p.y:
			need += Props.owned_height(it.kind, float(it.scale)) * lean_k
		out.append([p.distance_to(it.pos) - need, "front lot %s" % it.kind])
	for xf in LaneStrip.edge_transforms(MapLayout.lane_path("sw"), LaneStrip.STONE_SPACING, LaneStrip.WIDTH, true, true):
		out.append([p.distance_to(Vector2(xf.origin.x, xf.origin.z)) - r - LaneStrip.STONE_RADIUS, "south-west lane stone"])
	return out

func test_retune_the_table_replaces_only_the_listed_spots() -> void:
	assert_eq(MapLayout.branch_pads(false), MapLayout.BRANCH_PADS, "flag off: today's table itself")
	var on := MapLayout.branch_pads(true)
	var keys := on.keys()
	keys.sort()
	var want := _ids()
	want.sort()
	assert_eq(keys, want, "still the nine spots")
	for id in MapLayout.BRANCH_PADS_RETUNE:
		assert_true(id in MapLayout.BRANCH_PADS, "%s is a spot" % id)
		assert_eq((MapLayout.BRANCH_PADS_RETUNE[id] as Array).size(), 2, id)
		assert_ne(MapLayout.BRANCH_PADS_RETUNE[id], MapLayout.BRANCH_PADS[id], "%s is listed because it moves" % id)
	for id in _ids():
		for i in 2:
			assert_eq(MapLayout.branch_pad(id, i, true), (on[id] as Array)[i], "%s pad %d: the accessors agree" % [id, i])
			assert_eq(MapLayout.branch_pad(id, i, false), (MapLayout.BRANCH_PADS[id] as Array)[i])
			if not MapLayout.BRANCH_PADS_RETUNE.has(id):
				assert_eq((on[id] as Array)[i], (MapLayout.BRANCH_PADS[id] as Array)[i], "%s keeps its pads" % id)
	var moved := MapLayout.BRANCH_PADS_RETUNE.keys()
	moved.sort()
	for must in ["tower_e", "tower_ne", "tower_nw"]:
		assert_true(must in moved, "%s moves (D-284.5)" % must)
	assert_true("fence_sw" in moved, "fence_sw moves (D-284.5)")
	# Task 14 round 5 (a Task 14 statement, not an author rule): fence_n's pads move 0.2 m toward each other so the NEAR glyph, centred in its ring, keeps 8 px from the lane badges
	assert_true("fence_n" in moved, "fence_n moves 0.2 m (D-294.8: 8 px between world labels)")
	assert_eq(MapLayout.branch_pad("fence_n", 0, true), Vector2(-2.3, -10.4))
	assert_eq(MapLayout.branch_pad("fence_n", 1, true), Vector2(2.3, -10.4))

func test_retune_pads_are_on_a_tenth_of_a_metre_near_their_spot_and_apart() -> void:
	for pad in _retune_pad_list():
		for v in [pad.pos.x, pad.pos.y]:
			assert_almost_eq(v * 10.0, roundf(v * 10.0), 1e-4, "%s pad %d: %s" % [pad.id, pad.i, pad.pos])
	var on := MapLayout.branch_pads(true)
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
		if MapLayout.BRANCH_PADS_RETUNE.has(pad.id):
			list.append_array(_lot_clearances(pad.pos))
		for c in list:
			assert_gte(float(c[0]), 0.0, "%s pad %d at %s: %s" % [pad.id, pad.i, pad.pos, c[1]])
		var least := _least(list)
		worst = minf(worst, float(least[0]))
		gut.p("%-9s %s %s: smallest clearance %.2f m (%s)%s" % [pad.id, "ab"[pad.i], pad.pos, least[0], least[1], "  MOVED" if MapLayout.BRANCH_PADS_RETUNE.has(pad.id) else ""])
		assert_gte(float(least[0]), MARGIN, "%s pad %d keeps a margin of %.1f m (limit: %s)" % [pad.id, pad.i, MARGIN, least[1]])
	gut.p("worst retune pad clearance %.2f m" % worst)

func test_retune_a_lot_rule_would_catch_a_bad_pad() -> void:
	# negative controls: a pad on the front lot's props, on its kerb, and on a south-west lane stone
	var prop: Vector2 = (PropsLayout.OWNED["front"] as Array)[0].pos
	assert_lt(float(_least(_lot_clearances(prop))[0]), 0.0, "on a front-lot prop")
	var kerb: Array = YardStones.transforms(MapLayout.yard_rect("front"), true, Balance.data.enemy.lateral_spread, true)
	var xf: Transform3D = kerb[0]
	assert_lt(float(_least(_lot_clearances(Vector2(xf.origin.x, xf.origin.z)))[0]), 0.0, "on the kerb")
	var stones: Array = LaneStrip.edge_transforms(MapLayout.lane_path("sw"), LaneStrip.STONE_SPACING, LaneStrip.WIDTH, true, true)
	assert_gt(stones.size(), 0)
	assert_lt(float(_least(_lot_clearances(Vector2(stones[0].origin.x, stones[0].origin.z)))[0]), 0.0, "on a lane stone")

func test_retune_the_building_and_the_other_pad_are_on_screen_from_either_pad() -> void:
	var on := MapLayout.branch_pads(true)
	for pad in _retune_pad_list():
		var spot := MapLayout.spot_position(pad.id)
		var other: Vector2 = (on[pad.id] as Array)[1 - pad.i]
		var xf := CameraMath.camera_transform(CameraMath.focus_for(pad.pos), Balance.ui)
		for aspect in ASPECTS:
			var proj := CameraMath.projection(Balance.ui, aspect)
			assert_true(CameraMath.on_screen(MapLayout.to3(spot), xf, proj), "%s from its pad %s at aspect %.3f" % [pad.id, pad.pos, aspect])
			assert_true(CameraMath.on_screen(MapLayout.to3(other), xf, proj), "%s: the other pad %s from pad %s at aspect %.3f" % [pad.id, other, pad.pos, aspect])

## The bot walks to the pads where they stand: with the flag on the graph's pad nodes are the retune table's, with it off today's; the new
## edges clear the colliders either way, and a TierBot rebuilds its graph when the flag turns on.
func test_retune_the_graph_and_the_bot_walk_to_the_moved_pads() -> void:
	for retune in [false, true]:
		var g := WaypointGraph.create_for_tier(3, retune)
		var table := MapLayout.branch_pads(retune)
		for id in table:
			for i in 2:
				var pad_name := "pad_%s_%s" % [id, "ab"[i]]
				assert_eq(g.position_of(pad_name), (table[id] as Array)[i], "%s (retune %s)" % [pad_name, retune])
				assert_false(g.shortest("home", pad_name).is_empty(), "home reaches %s (retune %s)" % [pad_name, retune])
		var bodies := [Rect2(-4, -4, 8, 8), Rect2(MapLayout.COUNTER - MapLayout.COUNTER_SIZE / 2, MapLayout.COUNTER_SIZE),
			Rect2(MapLayout.FREEZER - MapLayout.FREEZER_SIZE / 2, MapLayout.FREEZER_SIZE)]
		for id in table:
			for i in 2:
				var pa: Vector2 = g.position_of("pad_%s_%s" % [id, "ab"[i]])
				var pb: Vector2 = g.position_of(id)
				for k in 101:
					for body in bodies:
						assert_true(Geometry.dist_point_rect(pa.lerp(pb, k / 100.0), body) >= MapLayout.HERO_RADIUS - 0.01, "edge pad_%s_%s-%s hits a collider (retune %s)" % [id, "ab"[i], id, retune])
	assert_eq(WaypointGraph.create_for_bot(3).nodes, WaypointGraph.create_for_bot(3, false).nodes, "the default is the flag off")
	var off := WaypointGraph.create_for_bot(3, false)
	var on := WaypointGraph.create_for_bot(3, true)
	for id in MapLayout.BRANCH_PADS_RETUNE:
		var moved := 0
		for i in 2:
			var pad_name := "pad_%s_%s" % [id, "ab"[i]]
			assert_eq(on.position_of(pad_name), (MapLayout.BRANCH_PADS_RETUNE[id] as Array)[i], "%s with the flag on" % pad_name)
			assert_eq(off.position_of(pad_name), (MapLayout.BRANCH_PADS[id] as Array)[i], "%s with the flag off" % pad_name)
			moved += int(on.position_of(pad_name) != off.position_of(pad_name))
		assert_gt(moved, 0, "%s: the graph's pads move" % id)
	# the bot itself: its graph at tier 3 follows the flag (a flip rebuilds it)
	GameState.new_game(1)
	GameState.debug_set_tier(3, 1)
	var bot := TierBot.new()
	bot._sync_graph()
	var any_id: String = MapLayout.BRANCH_PADS_RETUNE.keys()[0]
	assert_eq(bot.graph.position_of("pad_%s_a" % any_id), MapLayout.BRANCH_PADS[any_id][0], "flag off: today's pad")
	Balance.data.tiers.retune_enabled = true
	bot._sync_graph()
	assert_eq(bot.graph.position_of("pad_%s_a" % any_id), MapLayout.BRANCH_PADS_RETUNE[any_id][0], "flag on: the moved pad")
	Balance.data.tiers.retune_enabled = false
	bot._sync_graph()
	assert_eq(bot.graph.position_of("pad_%s_a" % any_id), MapLayout.BRANCH_PADS[any_id][0], "flag off again")
	assert_eq(bot.graph.position_of(PAD_COUNTER_NODE), MapLayout.STATION_PADS[&"counter"], "the station pads are still there")
	bot.free()

## The kerb and the lane stones follow the pads (art/env/yard_stones.gd and lane_strip.gd take the same accessor): with the flag on no kerb
## piece and no lane stone is within a pad's radius of any pad of the retune table, and no piece or stone is lost to the OLD positions
## (the retune's pads, not the old ones, keep them away); with it off the transforms are exactly the default call's.
func test_retune_no_kerb_piece_or_lane_stone_is_within_a_pad_radius_and_the_off_state_is_unchanged() -> void:
	var r := MapLayout.BRANCH_PAD_RADIUS
	var spread: float = Balance.data.enemy.lateral_spread
	var pads: Array = []
	for id in MapLayout.branch_pads(true):
		pads.append_array(MapLayout.branch_pads(true)[id])
	assert_eq(pads.size(), 18)
	var pieces := 0
	for yard in MapLayout.all_yards():
		var rect := MapLayout.yard_rect(yard)
		var t3 := MapLayout.yard_tier(yard) >= 3
		for xf in YardStones.transforms(rect, t3, spread, true):
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
		for xf in LaneStrip.edge_transforms(MapLayout.lane_path(lane), LaneStrip.STONE_SPACING, LaneStrip.WIDTH, true, true):
			stones += 1
			for p in pads:
				assert_gte(p.distance_to(Vector2(xf.origin.x, xf.origin.z)), r, "a lane stone at %s lies within the radius of the pad at %s" % [xf.origin, p])
	assert_gt(stones, 0)
	# flag off: the same transforms as the default call, piece for piece
	for yard in MapLayout.all_yards():
		var t3 := MapLayout.yard_tier(yard) >= 3
		assert_eq(YardStones.transforms(MapLayout.yard_rect(yard), t3, spread, false), YardStones.transforms(MapLayout.yard_rect(yard), t3, spread))
	assert_eq(LaneStrip.edge_transforms(MapLayout.lane_path("sw"), LaneStrip.STONE_SPACING, LaneStrip.WIDTH, true, false), LaneStrip.edge_transforms(MapLayout.lane_path("sw"), LaneStrip.STONE_SPACING, LaneStrip.WIDTH, true))
