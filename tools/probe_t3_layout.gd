extends SceneTree
## E5 tier 3 layout probe (spec 4, D-271). Headless, reads every coordinate from MapLayout (no private copies).
## Run: "$GODOT" --headless --path . -s res://tools/probe_t3_layout.gd
## Prints, for the four-lane tier-3 map:
##   1  the south-west lane's on-screen seconds before hero range at six aspects (hero at the zone centre and at the lane end);
##   D  the stop points against the zone; A' the number of lanes a reachable hero position reaches, and the 2-lane pairs;
##   B/C tower_sw reach; the Longbow rule per tower (third-smallest lane distance, lane distance = min(stop points, fence spot));
##   E  the SW path against towers and the diner; the service layout against the SW lane, zone and fence bar;
##   the tier-3 sign against today's west exit line; the front plot; the 18 branch pads (current MapLayout.BRANCH_PADS with their
##   smallest clearance and what limits it) and, last, a SEARCH for pad pairs per spot printed as BRANCH_PADS source text.
## Information only: the oracles are the unit tests (test_tier3_layout, test_branch_pad_layout, test_longbow_reach).

const ASPECTS := [0.30, 9.0 / 21.0, 720.0 / 1280.0, 16.0 / 9.0, 21.0 / 9.0, 32.0 / 9.0]
const SHOW_ASPECTS := [9.0 / 21.0, 720.0 / 1280.0, 16.0 / 9.0]
const TIER := 3

var ui
var bd
var spread: float
var fade: float

func lanes() -> Array[String]:
	return MapLayout.lanes_for_tier(TIER)

func towers() -> Dictionary:
	var d := {}
	for id in MapLayout.spots_for_tier(TIER):
		if MapLayout.spot_kind(id) == "tower":
			d[id] = MapLayout.spot_position(id)
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
	return [Rect2(-4, -4, 8, 8), Rect2(MapLayout.COUNTER - MapLayout.COUNTER_SIZE / 2, MapLayout.COUNTER_SIZE),
		Rect2(MapLayout.FREEZER - MapLayout.FREEZER_SIZE / 2, MapLayout.FREEZER_SIZE)]

## The fence bar of a lane: [end a, end b] (3 m across, perpendicular to the lane's tangent at the fence spot).
func fence_bar(lane: String) -> Array:
	var path: Array = MapLayout.lane_path(lane)
	var t := Geometry.tangent_at(path, Geometry.path_length(path) - MapLayout.FENCE_OFFSET_FROM_END)
	var n := Vector2(-t.y, t.x)
	var f := MapLayout.fence_spot(lane)
	return [f - n * 1.5, f + n * 1.5]

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
		checks.append([p.distance_to(q) - r - 0.3, "queue slot"])
		checks.append([Geometry.dist_point_segment(p, MapLayout.TRAVELER_ENTER, q) - r, "traveler entry line"])
	checks.append([Geometry.dist_point_segment(p, MapLayout.SERVICE_POINT, MapLayout.traveler_exit(TIER)) - r, "traveler exit line"])
	for c in colliders():
		checks.append([Geometry.dist_point_rect(p, c) - r, "collider"])
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

## True when the building at `spot` is on screen from a hero standing on `pad`, at the three show aspects.
func together_on_screen(spot: Vector2, pad: Vector2, _other: Vector2) -> bool:
	for a in SHOW_ASPECTS:
		if not on_screen_from(spot, pad, a):
			return false
	return true

func _initialize() -> void:
	root.get_node("Balance").reset()
	ui = root.get_node("Balance").ui
	bd = root.get_node("Balance").data
	spread = bd.enemy.lateral_spread
	fade = bd.enemy.offset_fade_distance
	var sw_path: Array = MapLayout.lane_path("sw")
	print("== SW path ", sw_path, " length %.2f m; zone %s; axis %s; fence spot %s; tower %s" % [Geometry.path_length(sw_path), MapLayout.zone_rect("sw"), MapLayout.zone_axis("sw"), MapLayout.fence_spot("sw"), MapLayout.tower_spot("tower_sw")])
	var v := visibility("sw")
	var parts: Array = []
	for a in ASPECTS:
		parts.append("%.3f: %.2f s" % [a, v[a]])
	print("1 visibility (SW lane): ", "  ".join(parts))
	var all_in := true
	for q in stops("sw"):
		all_in = all_in and Geometry.rect_contains(MapLayout.zone_rect("sw"), q)
	print("D SW stops inside zone: ", all_in)
	# A'
	var stops_by := {}
	for l in lanes():
		stops_by[l] = stops(l)
	var pairs := {}
	var max_l := 0
	var x := MapLayout.BOUNDS_MIN.x
	while x <= MapLayout.BOUNDS_MAX.x + 1e-6:
		var z := MapLayout.BOUNDS_MIN.y
		while z <= MapLayout.BOUNDS_MAX.y + 1e-6:
			var p := Vector2(x, z)
			var ok := true
			for r in colliders():
				ok = ok and Geometry.dist_point_rect(p, r) >= MapLayout.HERO_RADIUS
			if ok:
				var reached: Array = []
				for l in lanes():
					for q in stops_by[l]:
						if p.distance_to(q) <= bd.hero.attack_range:
							reached.append(l)
							break
				max_l = maxi(max_l, reached.size())
				if reached.size() == 2:
					var key := "+".join(reached)
					pairs[key] = int(pairs.get(key, 0)) + 1
			z += 0.25
		x += 0.25
	print("A' 4 lanes: max lanes reached = ", max_l, "  2-lane positions: ", pairs)
	# towers
	var tw := towers()
	var worst_c := 0.0
	for c in Geometry.rect_corners(MapLayout.zone_rect("sw")):
		worst_c = maxf(worst_c, MapLayout.tower_spot("tower_sw").distance_to(c))
	print("B tower_sw -> farthest SW zone corner %.2f (range L1 %.1f)   C -> SW fence %.2f" % [worst_c, bd.build.tower_range[0], MapLayout.tower_spot("tower_sw").distance_to(MapLayout.fence_spot("sw"))])
	print("Longbow rule per tower (lane distance = min(stop points, fence spot)), sorted:")
	var lim := INF
	for t in tw:
		var dl: Array = []
		for l in lanes():
			var m := (tw[t] as Vector2).distance_to(MapLayout.fence_spot(l))
			for q in stops_by[l]:
				m = minf(m, (tw[t] as Vector2).distance_to(q))
			dl.append([m, l])
		dl.sort_custom(func(a, b): return a[0] < b[0])
		print("  %-9s %s %.2f, %s %.2f, 3rd %s %.2f, 4th %s %.2f" % [t, dl[0][1], dl[0][0], dl[1][1], dl[1][0], dl[2][1], dl[2][0], dl[3][1], dl[3][0]])
		lim = minf(lim, dl[2][0])
	print("  => the Longbow range must stay below %.2f" % lim)
	# E
	var min_t := INF
	var min_name := ""
	var min_diner := INF
	var length := Geometry.path_length(sw_path)
	var d := 0.0
	while d <= length + 1e-4:
		for off in [-spread, 0.0, spread]:
			var p := EnemyPath.position_at("sw", d, off, fade)
			for t in tw:
				if p.distance_to(tw[t]) < min_t:
					min_t = p.distance_to(tw[t])
					min_name = t
			min_diner = minf(min_diner, Geometry.dist_point_rect(p, Rect2(-4, -4, 8, 8)))
		d += 0.1
	print("E SW path nearest tower: %s %.2f (need 1.5); nearest diner wall %.2f (need reach %.1f)" % [min_name, min_t, min_diner, bd.enemy.reach])
	# service layout
	var bar := fence_bar("sw")
	print("tier-3 service layout vs the SW lane (need > %.1f + 0.4), zone and fence bar:" % spread)
	var items := {"HOME": MapLayout.HOME, "close-up sign": MapLayout.SIGN, "gold pile": MapLayout.GOLD_PILE, "door": MapLayout.DINER_DOOR,
		"counter pad": MapLayout.STATION_PADS[&"counter"], "freezer pad": MapLayout.STATION_PADS[&"freezer"], "counter drop": MapLayout.COUNTER_DROP,
		"tier-3 sign": MapLayout.tier_sign(3), "tower_sw": MapLayout.tower_spot("tower_sw")}
	for i in MapLayout.queue_slots(TIER).size():
		items["queue slot %d" % i] = MapLayout.queue_slots(TIER)[i]
	for n in items:
		print("  %-14s lane %.2f  zone %.2f  fence bar %.2f" % [n, line_dist(items[n], "sw"), Geometry.dist_point_rect(items[n], MapLayout.zone_rect("sw")), Geometry.dist_point_segment(items[n], bar[0], bar[1])])
	var entry := INF
	for q in MapLayout.queue_slots(TIER):
		for k in 201:
			entry = minf(entry, Geometry.dist_point_segment(MapLayout.TRAVELER_ENTER.lerp(q, k / 200.0), bar[0], bar[1]))
	var exit_m := INF
	for k in 201:
		exit_m = minf(exit_m, Geometry.dist_point_segment(MapLayout.SERVICE_POINT.lerp(MapLayout.traveler_exit(TIER), k / 200.0), bar[0], bar[1]))
	print("traveler lines vs the SW fence bar: entry lines %.2f, exit line %.2f" % [entry, exit_m])
	var m2 := INF
	for k in 201:
		m2 = minf(m2, MapLayout.SERVICE_POINT.lerp(MapLayout.TRAVELER_EXIT, k / 200.0).distance_to(MapLayout.tier_sign(3)))
	print("tier-3 sign vs today's west exit line: %.2f (sign radius %.1f)" % [m2, MapLayout.STATION_RADIUS])
	var plot := MapLayout.yard_rect("front")
	print("plot ", plot, " contains tower_sw ", plot.has_point(MapLayout.tower_spot("tower_sw")), " fence ", plot.has_point(MapLayout.fence_spot("sw")), " tier-3 sign ", plot.has_point(MapLayout.tier_sign(3)), "; overlaps west yard ", plot.intersects(MapLayout.YARDS["west"]))
	# the committed pads
	print("committed BRANCH_PADS (radius %.1f): pad, distance to the spot, smallest clearance, limiting item, building on screen from the pad (3 aspects)" % MapLayout.BRANCH_PAD_RADIUS)
	var sp := spots()
	var placed: Array = []
	for id in MapLayout.BRANCH_PADS:
		for p in MapLayout.BRANCH_PADS[id]:
			placed.append(p)
	var worst_all := INF
	for id in MapLayout.BRANCH_PADS:
		var pads: Array = MapLayout.BRANCH_PADS[id]
		for i in 2:
			var others := placed.duplicate()
			others.erase(pads[i])
			var c := pad_clear(pads[i], id, others)
			worst_all = minf(worst_all, c[0])
			print("  %-9s %s  %.2f m from the spot  clr %.2f (%s)  on screen %s" % [id, pads[i], (pads[i] as Vector2).distance_to(sp[id]), c[0], c[1], together_on_screen(sp[id], pads[i], pads[1 - i])])
	print("  worst pad clearance: %.2f" % worst_all)
	# the search
	print("pad SEARCH (0.1 m grid within 2.8 m of the spot, clearance >= 0.3, pair apart >= 2.2, building on screen from either pad):")
	var found: Array = []
	var placed2: Array = []
	var ids := ["tower_sw", "fence_sw", "fence_w", "fence_n", "fence_e", "tower_nw", "tower_ne", "tower_w", "tower_e"]
	for id in ids:
		var c0: Vector2 = sp[id]
		var cands: Array = []
		for ix in range(-28, 29):
			for iz in range(-28, 29):
				var off := Vector2(ix, iz) * 0.1
				if off.length() > 2.8 or off.length() < 1.0:
					continue
				var p := (c0 + off).snapped(Vector2(0.1, 0.1))
				if p.distance_to(c0) > 2.8:
					continue
				var c := pad_clear(p, id, placed2)
				if c[0] >= 0.3:
					cands.append([p, minf(c[0], 0.6), c[1]])
		var best_pair: Array = []
		var best_score := -INF
		for i in cands.size():
			for j in range(i + 1, cands.size()):
				var a: Vector2 = cands[i][0]
				var b: Vector2 = cands[j][0]
				if a.distance_to(b) < 2.2 or not together_on_screen(c0, a, b) or not together_on_screen(c0, b, a):
					continue
				var left_right := 1.0 if (a.x - c0.x) * (b.x - c0.x) < 0.0 else 0.0
				var score := 10.0 * minf(cands[i][1], cands[j][1]) + 3.0 * left_right - 0.5 * (a.distance_to(c0) + b.distance_to(c0))
				if score > best_score:
					best_score = score
					best_pair = [a, b]
		if best_pair.is_empty():
			print("  %-9s NO PAIR (%d candidates)" % [id, cands.size()])
			continue
		placed2.append_array(best_pair)
		found.append([id, best_pair])
		print("  %-9s %d candidates, best pair %s %s" % [id, cands.size(), best_pair[0], best_pair[1]])
	print("const BRANCH_PADS := {")
	for f in found:
		print("\t\"%s\": [Vector2(%.1f, %.1f), Vector2(%.1f, %.1f)]," % [f[0], f[1][0].x, f[1][0].y, f[1][1].x, f[1][1].y])
	print("}")
	quit(0)
