extends GutTest
## E5 tier 3 (spec 4.3, D-263.4, D-266.2): the 18 branch pads (two per spot, radius 0.9) are fixed by these tests, not by eye.
## Every rule is re-derived here from MapLayout's lanes, zones, spots, stations and the tier-3 queue and traveler lines.

const NEAR := 2.8  # a pad stands within this of its spot
const APART := 2.2  # the two pads of a spot are at least this far apart
const MARGIN := 0.1  # every chosen pad clears every rule by at least this much (fence_w and fence_e are the tightest: the yards crowd them)
const TRAVELER_RADIUS := 0.3  # a queued traveler's body, kept clear of a pad
const NOT_BOTH_SIDES := ["tower_e", "tower_ne", "tower_nw", "tower_w"]  # pinned: their pads sit on one side of the building
const ASPECTS := [9.0 / 21.0, 720.0 / 1280.0, 16.0 / 9.0]

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
	for k in _kerb_segments():
		out.append([Geometry.dist_point_segment(p, k[0], k[1]) - r - YardStones.WIDTH * 0.5, "yard kerb"])
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
