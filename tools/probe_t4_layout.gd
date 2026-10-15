extends SceneTree
## E8 phase 2 Task 6 probe (spec 4.3): the back lot. Pad search for the tier-4 towers, a copy of probe_t3_layout with TIER 4 (its older header follows).
## Run: "$GODOT" --headless --path . -s res://tools/probe_t4_layout.gd   (reads MapLayout.TIER_SPOTS[4]; prints the best pad pair per tier-4 tower)
## Env: SCAN="id;x1,x2;z1,z2" scans tower positions for `id`; MINPADX / MAXPADX / MAXPADZ limit the pads; NOSTONES=1 ignores the south-west lane stones
##   (the tier-4 stones skip the pads: LaneStrip tier 4).
## E5 tier 3 layout probe (spec 4, D-271). Headless, reads every coordinate from MapLayout (no private copies).
## Run: "$GODOT" --headless --path . -s res://tools/probe_t3_layout.gd
## Prints, for the four-lane tier-3 map:
##   1  the south-west lane's on-screen seconds before hero range at six aspects (hero at the zone centre and at the lane end);
##   D  the stop points against the zone; A' the number of lanes a reachable hero position reaches, and the 2-lane pairs;
##   B/C tower_sw reach; the Longbow rule per tower (third-smallest lane distance, lane distance = min(stop points, fence spot));
##   E  the SW path against towers and the diner; the service layout against the SW lane, zone and fence bar;
##   the tier-3 sign against today's west exit line; the front plot; the 18 branch pads (current MapLayout.BRANCH_PADS with their
##   smallest clearance and what limits it) and, last, a SEARCH (env PAD_KEEP=id,id keeps those spots' committed pads) for pad pairs per spot printed as BRANCH_PADS source text.
## The committed section reads MapLayout.BRANCH_PADS (the shipped table). With env RETUNE=1 it also applies the front lot's kerb as laid out, its props
##   (footprint, and the lean for a prop south of the pad) and the south-west lane's edge stones in the pad clearance, and the SEARCH prints
##   BRANCH_PADS_RETUNE source text.
## Information only: the oracles are the unit tests (test_tier3_layout, test_branch_pad_layout, test_longbow_reach).

const ASPECTS := [0.30, 9.0 / 21.0, 720.0 / 1280.0, 16.0 / 9.0, 21.0 / 9.0, 32.0 / 9.0]
const SHOW_ASPECTS := [9.0 / 21.0, 720.0 / 1280.0, 16.0 / 9.0]
const TIER := 4
const TRAVELER_RADIUS := 0.3  ## a queued traveler's body, kept clear of a pad

var ui
var bd
var spread: float
var fade: float

func lanes() -> Array[String]:
	return MapLayout.lanes_for_tier(3)

var cand_id := ""
var cand_pos := Vector2.ZERO

func towers() -> Dictionary:
	var d := {}
	for id in MapLayout.spots_for_tier(TIER):
		if MapLayout.spot_kind(id) == "tower":
			d[id] = MapLayout.spot_position(id)
	if cand_id != "":
		d[cand_id] = cand_pos
	return d

func spots() -> Dictionary:
	var d := {}
	for id in MapLayout.spots_for_tier(TIER):
		d[id] = MapLayout.spot_position(id)
	return d

func stops(lane: String) -> Array:
	var pts: Array = []
	for i in 41:
		pts.append(EnemyPath.position_at(lane, MapLayout.path_length(lane), lerpf(-1.0, 1.0, i / 40.0) * spread, fade))
	return pts

func line_dist(p: Vector2, lane: String) -> float:
	var path: Array = MapLayout.lane_path(lane)
	var best := INF
	for i in range(1, path.size()):
		best = minf(best, Geometry.dist_point_segment(p, path[i - 1], path[i]))
	return best

func colliders() -> Array:
	var h := MapLayout.DINER_HALF
	return [Rect2(-h, -h, h * 2.0, h * 2.0), Rect2(MapLayout.COUNTER - MapLayout.COUNTER_SIZE / 2, MapLayout.COUNTER_SIZE),
		Rect2(MapLayout.FREEZER - MapLayout.FREEZER_SIZE / 2, MapLayout.FREEZER_SIZE)]

## The fence bar of a lane: [end a, end b] (3 m across, perpendicular to the lane's tangent at the fence spot).
func fence_bar(lane: String) -> Array:
	var path: Array = MapLayout.lane_path(lane)
	var t := Geometry.tangent_at(path, Geometry.path_length(path) - MapLayout.FENCE_OFFSET_FROM_END)
	var n := Vector2(-t.y, t.x)
	var f := MapLayout.fence_spot(lane)
	return [f - n * MapLayout.FENCE_BAR_HALF, f + n * MapLayout.FENCE_BAR_HALF]

var _kerb: Array = []  ## [centre-line a, b] of every kerb piece of the tier-2 yards
var _props: Array = []  ## {pos, radius, height} of every owned-land prop of the tier-2 yards
var retune := false  ## env RETUNE=1: the retuned pad table and the lot rules (the shipped one)
var _lot_kerb: Array = []  ## [a, b] of every kerb piece of the front lot as laid out (retune only)
var _lot_props: Array = []  ## the front lot's props (retune only)
var _stones: Array = []  ## the south-west lane's edge stones (retune only)

func load_yard_obstacles() -> void:
	for id in MapLayout.yards_for_tier(2):
		for xf in YardStones.transforms(MapLayout.yard_rect(id)):
			var half := Vector2(xf.basis.x.x, xf.basis.x.z) * 0.5
			var c := Vector2(xf.origin.x, xf.origin.z)
			_kerb.append([c - half, c + half])
		for it in PropsLayout.OWNED.get(id, []):
			_props.append({"pos": it.pos, "radius": Props.owned_radius(it.kind, float(it.scale)), "height": Props.owned_height(it.kind, float(it.scale)), "what": "%s %s" % [it.kind, id]})

func load_lot_obstacles() -> void:
	for xf in YardStones.transforms(MapLayout.yard_rect("front"), true, bd.enemy.lateral_spread):
		var half := Vector2(xf.basis.x.x, xf.basis.x.z) * 0.5
		var c := Vector2(xf.origin.x, xf.origin.z)
		_lot_kerb.append([c - half, c + half])
	for it in PropsLayout.OWNED.get("front", []):
		_lot_props.append({"pos": it.pos, "radius": Props.owned_radius(it.kind, float(it.scale)), "height": Props.owned_height(it.kind, float(it.scale)), "what": "%s front" % it.kind})
	for xf in LaneStrip.edge_transforms(MapLayout.lane_path("sw"), LaneStrip.STONE_SPACING, LaneStrip.WIDTH, true):
		_stones.append(Vector2(xf.origin.x, xf.origin.z))

func visibility(lane: String) -> Dictionary:
	var out := {}
	var length := MapLayout.path_length(lane)
	var dt := 1.0 / 60.0
	for aspect in ASPECTS:
		var proj := CameraMath.projection(ui, aspect)
		var worst := INF
		for hero in [MapLayout.zone_rect(lane).get_center(), MapLayout.lane_end(lane)]:
			var xf := CameraMath.camera_transform(CameraMath.focus_for(hero), ui)
			for offset in [-spread, 0.0, spread]:
				var samples: Array = []
				var d := 0.0
				while d <= length:
					samples.append(EnemyPath.position_at(lane, d, offset, fade))
					d += bd.enemy.speed * dt
				var range_idx := -1
				for i in samples.size():
					if (samples[i] as Vector2).distance_to(hero) <= bd.hero.attack_range:
						range_idx = i
						break
				var fv := range_idx
				while fv > 0 and CameraMath.on_screen(MapLayout.to3(samples[fv - 1], 0.5), xf, proj):
					fv -= 1
				worst = minf(worst, (range_idx - fv) * dt)
		out[aspect] = worst
	return out

## [smallest clearance (m), what limits it] of a pad centre `p` at tier 3. `others` are the pad centres already placed.
func pad_clear(p: Vector2, own: String, others: Array) -> Array:
	var r := MapLayout.BRANCH_PAD_RADIUS
	var checks: Array = []
	for l in lanes():
		checks.append([line_dist(p, l) - spread - r, "lane " + l])
		checks.append([Geometry.dist_point_rect(p, MapLayout.zone_rect(l)) - r, "zone " + l])
		var bar := fence_bar(l)
		checks.append([Geometry.dist_point_segment(p, bar[0], bar[1]) - r, "fence bar " + l])
	var tw := towers()
	for t in tw:
		checks.append([p.distance_to(tw[t]) - r - MapLayout.TOWER_VISUAL_RADIUS, "own tower" if t == own else "tower " + t])
	for o in others:
		checks.append([p.distance_to(o) - 2.0 * r, "other pad"])
	checks.append([p.distance_to(MapLayout.SIGN) - r - MapLayout.STATION_RADIUS, "close-up sign"])
	checks.append([p.distance_to(MapLayout.FREEZER_ZONE) - r - MapLayout.STATION_RADIUS, "freezer zone"])
	checks.append([p.distance_to(MapLayout.COUNTER_DROP) - r - MapLayout.STATION_RADIUS, "counter drop"])
	for sp in MapLayout.STATION_PADS:
		checks.append([p.distance_to(MapLayout.STATION_PADS[sp]) - r - MapLayout.BUILD_RADIUS, "station pad " + str(sp)])
	checks.append([p.distance_to(MapLayout.GOLD_PILE) - r, "gold pile"])
	checks.append([p.distance_to(MapLayout.HOME) - r, "HOME"])
	checks.append([p.distance_to(MapLayout.DINER_DOOR) - r, "door"])
	# no tier-sign rule: the tier-3 sign sells tier 3 and is gone when a pad exists (pads need tier 3)
	for q in MapLayout.queue_slots(TIER):
		checks.append([p.distance_to(q) - r - TRAVELER_RADIUS, "queue slot"])
		checks.append([Geometry.dist_point_segment(p, MapLayout.TRAVELER_ENTER, q) - r, "traveler entry line"])
	checks.append([Geometry.dist_point_segment(p, MapLayout.SERVICE_POINT, MapLayout.traveler_exit(TIER)) - r, "traveler exit line"])
	for c in colliders():
		checks.append([Geometry.dist_point_rect(p, c) - r, "collider"])
	var lean_k := 1.0 / tan(deg_to_rad(absf(ui.camera_pitch)))
	for pr in _props:  # the prop's top leans over its base on screen, so the lean is kept in every direction (as test_yards does)
		checks.append([p.distance_to(pr.pos) - r - pr.radius - pr.height * lean_k, "owned prop " + pr.what])
	for k in _kerb:
		checks.append([Geometry.dist_point_segment(p, k[0], k[1]) - r - YardStones.WIDTH * 0.5, "yard kerb"])
	if retune:
		for pr in _lot_props:  # as test_branch_pad_layout: the lean only for a prop SOUTH of the pad
			checks.append([p.distance_to(pr.pos) - r - pr.radius - (pr.height * lean_k if pr.pos.y > p.y else 0.0), "owned prop " + pr.what])
		for k in _lot_kerb:
			checks.append([Geometry.dist_point_segment(p, k[0], k[1]) - r - YardStones.WIDTH * 0.5, "front lot kerb"])
		for q in (_stones if OS.get_environment("NOSTONES") != "1" else []):  # the tier-4 stones skip the pads (LaneStrip tier 4): no circular rule
			checks.append([p.distance_to(q) - r - LaneStrip.STONE_RADIUS, "south-west lane stone"])
	checks.append([minf(minf(p.x - MapLayout.BOUNDS_MIN.x, MapLayout.BOUNDS_MAX.x - p.x), minf(p.y - MapLayout.BOUNDS_MIN.y, MapLayout.BOUNDS_MAX.y - p.y)) - r, "bounds"])
	var best := INF
	var what := ""
	for c in checks:
		if c[0] < best:
			best = c[0]
			what = c[1]
	return [best, what]

func on_screen_from(p: Vector2, hero: Vector2, aspect: float) -> bool:
	var xf := CameraMath.camera_transform(CameraMath.focus_for(hero), ui)
	return CameraMath.on_screen(MapLayout.to3(p, 0.0), xf, CameraMath.projection(ui, aspect))

## True when the building at `spot` and the pair's `other` pad are on screen from a hero standing on `pad`, at the three show aspects.
func together_on_screen(spot: Vector2, pad: Vector2, other: Vector2) -> bool:
	for a in SHOW_ASPECTS:
		if not on_screen_from(spot, pad, a) or not on_screen_from(other, pad, a):
			return false
	return true

## The best pair for `id` whose every clearance is >= `thr`: {"cands": n, "pair": [a, b] or [], "loose": best pair ignoring the other-pad screen rule}.
func search_spot(id: String, c0: Vector2, placed2: Array, thr: float) -> Dictionary:
	var cands: Array = []
	for ix in range(-28, 29):
		for iz in range(-28, 29):
			var off := Vector2(ix, iz) * 0.1
			if off.length() > 2.8 or off.length() < 1.0:
				continue
			var p := (c0 + off).snapped(Vector2(0.1, 0.1))
			if OS.get_environment("MINPADX") != "" and p.x < float(OS.get_environment("MINPADX")):
				continue
			if OS.get_environment("MAXPADX") != "" and p.x > float(OS.get_environment("MAXPADX")):
				continue
			if OS.get_environment("MAXPADZ") != "" and p.y > float(OS.get_environment("MAXPADZ")):
				continue
			if p.distance_to(c0) > 2.8:
				continue
			var c := pad_clear(p, id, placed2)
			if c[0] >= thr and together_on_screen(c0, p, c0):
				cands.append([p, minf(c[0], 0.6), c[1]])
	var best_pair: Array = []
	var best_loose: Array = []
	var loose_score := -INF
	var best_score := -INF
	for i in cands.size():
		for j in range(i + 1, cands.size()):
			var a: Vector2 = cands[i][0]
			var b: Vector2 = cands[j][0]
			if a.distance_to(b) < 2.2:
				continue
			var left_right := 1.0 if (a.x - c0.x) * (b.x - c0.x) < 0.0 else 0.0
			var score := 10.0 * minf(cands[i][1], cands[j][1]) + 3.0 * left_right - 0.5 * (a.distance_to(c0) + b.distance_to(c0))
			if score > loose_score:
				loose_score = score
				best_loose = [a, b]
			if score > best_score and together_on_screen(c0, a, b) and together_on_screen(c0, b, a):
				best_score = score
				best_pair = [a, b]
	return {"cands": cands.size(), "pair": best_pair, "loose": best_loose}

func _initialize() -> void:
	root.get_node("Balance").reset()
	ui = root.get_node("Balance").ui
	bd = root.get_node("Balance").data
	retune = true
	load_yard_obstacles()
	load_lot_obstacles()
	spread = bd.enemy.lateral_spread
	fade = bd.enemy.offset_fade_distance
	var table := MapLayout.BRANCH_PADS
	var sp := spots()
	var placed: Array = []
	var t4: Array = MapLayout.TIER_SPOTS[4]
	for id in table:
		if not id in t4:
			placed.append_array(table[id])
	var ids := t4
	if OS.get_environment("SCAN") != "":
		var parts := OS.get_environment("SCAN").split(";")
		cand_id = parts[0]
		var xs := parts[1].split(",")
		var zs := parts[2].split(",")
		for xx in xs:
			for zz in zs:
				cand_pos = Vector2(float(xx), float(zz))
				var rr := {}
				for thr in [0.3, 0.2, 0.1]:
					rr = search_spot(cand_id, cand_pos, placed, thr)
					if not (rr.pair as Array).is_empty():
						print("SCAN %s -> clr %.1f pair %s (%d cands)" % [cand_pos, thr, rr.pair, rr.cands])
						break
				if (rr.pair as Array).is_empty():
					print("SCAN %s -> none (%d cands at 0.1)" % [cand_pos, rr.cands])
		quit(0)
		return
	for id in ids:
		print(id, " at ", sp[id])
		var r := {}
		var used := 0.0
		for thr in [0.3, 0.25, 0.2, 0.15, 0.1, 0.05, 0.0]:
			r = search_spot(id, sp[id], placed, thr)
			used = thr
			if not (r.pair as Array).is_empty():
				break
		print("  %d candidates at clearance >= %.2f, pair %s, loose %s" % [r.cands, used, r.pair, r.loose])
		if not (r.pair as Array).is_empty():
			placed.append_array(r.pair)
	quit(0)
