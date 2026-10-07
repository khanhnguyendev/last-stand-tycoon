extends GutTest
## E5 tier 3 Task 14 (spec 6.5, D-264): each lane's telegraph marker shows WHAT comes down the lane tonight: an icon and a
## count per kind above 0 (Boar, hare, brute) and the boss icon on the boss lane. Every expected number below is written
## out by hand from the literal plans, never from a second call of LanePlanner.

const ASPECTS := [9.0 / 21.0, 720.0 / 1280.0, 16.0 / 9.0]

var main: Main

func before_each() -> void:
	Balance.reset()
	main = Main.create()
	add_child_autofree(main)
	main.hero.input.player_control = false
	main.phase_controller.start_new_game(41)
	main.phase_controller.debug_skip_to_day()

func _wave(m: String, mc: int, fm: int, s: String, sc: int, fs: int, bm := 0, bs := 0) -> Dictionary:
	return {"main": m, "side": s, "main_count": mc, "side_count": sc, "hp_mult": 1.0,
		"fast_main": fm, "fast_side": fs, "boss": false, "brute_main": bm, "brute_side": bs}

## Tiers 1 and 2: west gets 5 (2 hares) + 4 (1 hare) = boar 6, hare 3; east gets 3 = boar 3; north nothing.
func _plan_t2() -> Array:
	return [_wave("west", 5, 2, "east", 3, 0), _wave("west", 4, 1, "", 0, 0)]

## Tier 3: west boar 3, hare 2, brute 1; sw boar 3+3 = 6, hare 1, brute 2; north boar 2, brute 1; east nothing.
func _plan_t3() -> Array:
	return [_wave("west", 5, 2, "sw", 3, 0, 1, 0), _wave("sw", 4, 1, "north", 2, 0, 2, 1)]

func _set_plan(plan: Array) -> void:
	GameState.lane_plan = plan
	for m in main.world.telegraph_markers.values():
		m.refresh()

func _tier3() -> void:
	if Balance.data.tiers.tier_costs.size() < 3:
		Balance.data.tiers.tier_costs.append(1500)  # test-only: the build knows tier 3
	GameState.debug_set_tier(3, 5)

func _marker(lane: String) -> TelegraphMarker:
	return main.world.telegraph_markers[lane]

func test_tier2_rows_show_exactly_the_kinds_and_counts_of_the_plan() -> void:
	_set_plan(_plan_t2())
	assert_eq(_marker("west").shown(), {&"boar": 6, &"hare": 3})
	assert_eq(_marker("east").shown(), {&"boar": 3}, "a kind with 0 is absent")
	assert_eq(_marker("north").shown(), {}, "a lane with no monsters shows nothing")
	assert_false(_marker("north").visible, "and its marker hides, as before")
	assert_true(_marker("west").visible)

func test_tier1_with_no_hares_and_no_boss_shows_a_boar_with_the_count() -> void:
	_set_plan([_wave("north", 4, 0, "", 0, 0), _wave("north", 3, 0, "west", 2, 0)])
	assert_eq(GameState.tier, 1)
	assert_eq(_marker("north").shown(), {&"boar": 7})
	assert_eq(_marker("west").shown(), {&"boar": 2})
	var num: Label3D = _marker("north").items[&"boar"].num
	assert_eq(num.text, "7")
	assert_true(num.visible)

func test_tier3_rows_show_brutes_and_the_sw_lane() -> void:
	_tier3()
	await get_tree().physics_frame
	_set_plan(_plan_t3())
	assert_eq(_marker("west").shown(), {&"boar": 3, &"hare": 2, &"brute": 1})
	assert_eq(_marker("sw").shown(), {&"boar": 6, &"hare": 1, &"brute": 2})
	assert_eq(_marker("north").shown(), {&"boar": 2, &"brute": 1})
	assert_eq(_marker("east").shown(), {})

func test_the_boss_icon_is_on_the_boss_lane_only_and_arrives_when_the_tier_is_paid() -> void:
	_set_plan(_plan_t2())
	for lane in ["west", "east", "north"]:
		assert_false(_marker(lane).shown().has(&"boss"), "no boss yet on " + lane)
	GameState.add_gold(500)
	GameState.pay_into_tier(500)
	assert_true(GameState.boss_pending)
	assert_eq(_marker("west").shown(), {&"boar": 6, &"hare": 3, &"boss": 1}, "the last wave's main lane, at once")
	assert_eq(_marker("east").shown(), {&"boar": 3})
	assert_false(_marker("north").shown().has(&"boss"))
	assert_eq(_marker("west").items[&"boss"].num, null, "the boss icon carries no number")

func test_rows_hide_at_night_and_return_at_day_with_the_new_plan() -> void:
	_set_plan(_plan_t2())
	main.phase_controller.debug_skip_to_night()
	await get_tree().physics_frame
	for lane in main.world.telegraph_markers:
		assert_false(_marker(lane).row.is_visible_in_tree(), "hidden at night: " + lane)
	main.phase_controller.debug_skip_to_day()
	await get_tree().physics_frame
	# the new day's plan: read it back, and check the row follows it (hand-computed from the plan dictionaries)
	var want := {}
	for w in GameState.lane_plan:
		for side in ["main", "side"]:
			var lane := String(w[side])
			if lane == "":
				continue
			var n := int(w[side + "_count"])
			var h := int(w.get("fast_" + side, 0))
			want[lane] = want.get(lane, {&"boar": 0, &"hare": 0})
			want[lane][&"boar"] += n - h
			want[lane][&"hare"] += h
	for lane in main.world.telegraph_markers:
		var exp := {}
		for k in want.get(lane, {}):
			if want[lane][k] > 0:
				exp[k] = want[lane][k]
		assert_eq(_marker(lane).shown(), exp, "day row of " + lane)
		assert_eq(_marker(lane).row.is_visible_in_tree(), not exp.is_empty(), "row visibility of " + lane)

# --- readability and placement ---------------------------------------------------

func _base_height(aspect: float) -> float:
	return maxf(1280.0, 720.0 / aspect)

class View:
	var xf: Transform3D
	var proj: Projection
	var aspect: float
	func _init(focus: Vector2, p_aspect: float) -> void:
		xf = CameraMath.camera_transform(CameraMath.focus_for(focus), Balance.ui)
		proj = CameraMath.projection(Balance.ui, p_aspect)
		aspect = p_aspect
	## Base-pixel point (x centred, y down) of a world point.
	func pt(w: Vector3) -> Vector2:
		var n := CameraMath.to_ndc(w, xf, proj)
		return Vector2(n.x * 360.0, -n.y * 0.5 * maxf(1280.0, 720.0 / aspect))
	## The bounds of a camera-facing quad (billboard) of size `sz` centred at c.
	func quad(c: Vector3, sz: Vector2) -> Rect2:
		return bounds([c + xf.basis.x * sz.x * 0.5 + xf.basis.y * sz.y * 0.5, c - xf.basis.x * sz.x * 0.5 + xf.basis.y * sz.y * 0.5,
			c + xf.basis.x * sz.x * 0.5 - xf.basis.y * sz.y * 0.5, c - xf.basis.x * sz.x * 0.5 - xf.basis.y * sz.y * 0.5])
	func box(b: AABB) -> Rect2:
		var pts: Array = []
		for k in 8:
			pts.append(b.position + Vector3(b.size.x * (k & 1), b.size.y * ((k >> 1) & 1), b.size.z * ((k >> 2) & 1)))
		return bounds(pts)
	func bounds(pts: Array) -> Rect2:
		var r := Rect2(pt(pts[0]), Vector2.ZERO)
		for q in pts:
			r = r.expand(pt(q))
		return r

## Projected height in base pixels of a vertical world length `len` at `p`.
func _px_height(p: Vector3, len: float, focus: Vector2, aspect: float) -> float:
	return View.new(focus, aspect).quad(p, Vector2(0.0, len)).size.y

## The rendered height of an icon: its mesh's own bounds times the node's scale (billboard_keep_scale makes the scale count).
func _icon_height_m(icon: MeshInstance3D) -> float:
	return icon.mesh.get_aabb().size.y * icon.scale.y

func _full_plan() -> Array:  # every kind on every lane, and a boss on the last wave's main lane
	var w1 := _wave("west", 6, 2, "north", 5, 1, 1, 1)
	var w2 := _wave("east", 6, 2, "west", 5, 1, 1, 1)
	w2.boss = true
	return [w1, w2]

## Every lane (tier 3 has four) with three pairs and a boss: main and side of both waves.
func _full_plan_t3() -> Array:
	var w1 := _wave("west", 6, 2, "sw", 5, 1, 1, 1)
	var w2 := _wave("east", 6, 2, "north", 5, 1, 1, 1)
	var w3 := _wave("sw", 6, 2, "west", 5, 1, 1, 1)
	var w4 := _wave("east", 6, 2, "north", 5, 1, 1, 1)
	w4.boss = true
	return [w1, w2, w3, w4]

## Every lane carries Boar, hare and brute (three pairs) and the boss is on `boss_lane`: the widest row each lane can show.
func _plan_boss_on(boss_lane: String) -> Array:
	var w1 := _wave("west", 6, 2, "east", 5, 1, 1, 1)
	var w2 := _wave("north", 6, 2, "sw", 5, 1, 1, 1)
	var w3 := _wave(boss_lane, 6, 2, "north" if boss_lane != "north" else "west", 5, 1, 1, 1)
	w3.boss = true
	return [w1, w2, w3]

func _foci(tier: int) -> Array:
	var out: Array = [MapLayout.HOME, MapLayout.SIGN]
	for lane in MapLayout.lanes_for_tier(tier):
		out.append(MapLayout.zone_rect(lane).get_center())
	for id in MapLayout.spots_for_tier(tier):
		out.append(MapLayout.spot_position(id))
	if tier >= 3:
		for id in MapLayout.BRANCH_PADS:
			for pad in MapLayout.BRANCH_PADS[id]:
				out.append(pad)
	return out

func test_icon_and_number_sizes_meet_the_ui_tuning_minimums() -> void:
	_tier3()
	await get_tree().physics_frame
	_set_plan(_full_plan_t3())
	var worst_icon := INF
	var worst_num := INF
	for aspect in ASPECTS:
		for hero in [MapLayout.HOME] + MapLayout.lanes_for_tier(3).map(func(l): return MapLayout.zone_rect(l).get_center()):
			for lane in main.world.telegraph_markers:
				var mk := _marker(lane)
				for kind in mk.items:
					var it: Dictionary = mk.items[kind]
					if not (it.icon as Node3D).visible:
						continue
					var ic := it.icon as MeshInstance3D
					worst_icon = minf(worst_icon, _px_height(ic.global_position, _icon_height_m(ic), hero, aspect))
					if it.num != null:
						var l := it.num as Label3D
						worst_num = minf(worst_num, _px_height(l.global_position, float(l.font_size) * l.pixel_size, hero, aspect))
	gut.p("measured worst rendered icon %.1f px, worst number em %.1f px (minimums %.0f, %.0f)" % [worst_icon, worst_num, Balance.ui.telegraph_icon_min_px, Balance.ui.telegraph_number_min_px])
	assert_gte(worst_icon, Balance.ui.telegraph_icon_min_px)
	assert_gte(worst_num, Balance.ui.telegraph_number_min_px)
	assert_gte(worst_num * 0.7, 20.0, "a digit (about 0.7 em) is at least 20 base px")
	assert_eq(Balance.ui.telegraph_icon_min_px, 28.0, "the floors are the plan's 28")
	assert_eq(Balance.ui.telegraph_number_min_px, 28.0)

func test_the_icon_size_knob_scales_the_rendered_quad() -> void:
	_set_plan(_plan_t2())
	var ic := _marker("west").items[&"boar"].icon as MeshInstance3D
	var base := _icon_height_m(ic)
	Balance.ui.telegraph_icon_m *= 0.5
	_set_plan(_plan_t2())
	assert_almost_eq(_icon_height_m(ic), base * 0.5, 1e-4, "the node scale is the size knob")
	assert_true(LaneIcons.material().billboard_keep_scale, "and the billboard keeps it")

## The rect of everything a marker's row shows, in `v`.
func _row_rect(mk: TelegraphMarker, v: View) -> Rect2:
	var rect := Rect2()
	var first := true
	for kind in mk.items:
		var it: Dictionary = mk.items[kind]
		if not (it.icon as Node3D).visible:
			continue
		var ic := it.icon as MeshInstance3D
		var bb := ic.mesh.get_aabb()
		var rs: Array = [v.quad(ic.global_position + v.xf.basis.x * (bb.get_center().x * ic.scale.x) + v.xf.basis.y * (bb.get_center().y * ic.scale.y), Vector2(bb.size.x, bb.size.y) * ic.scale.x)]
		if it.num != null:
			var l := it.num as Label3D
			var lb := l.get_aabb()
			# the glyphs, not the line box: a digit is about 0.75 em tall, centred on the label's origin
			rs.append(v.quad(l.global_position + v.xf.basis.x * lb.get_center().x, Vector2(lb.size.x, 0.75 * float(l.font_size) * l.pixel_size)))
		for r in rs:
			rect = r if first else rect.merge(r)
			first = false
	return rect

## Cost-label and level-pip rects of every spot at every level (unbuilt and built heights).
func _spot_rects(v: View) -> Array:
	var out: Array = []
	for id in main.world.build_spots:
		var sp: BuildSpot = main.world.build_spots[id]
		for lvl in range(0, Balance.data.build.max_level + 1):
			out.append([id + " label L%d" % lvl, v.quad(sp.global_position + Vector3(0, sp._label_y(lvl), 0), Vector2(1.2, 0.6))])
			if lvl >= 1:
				out.append([id + " pips L%d" % lvl, v.quad(sp.global_position + Vector3(0, sp._pip_y(lvl), 0), Vector2(1.1, 0.4))])
	return out

func _hero_rect(at: Vector2, v: View) -> Rect2:
	return v.box(AABB(Vector3(at.x - 0.4, 0.0, at.y - 0.05), Vector3(0.8, 1.8, 0.1)))

func _clear_rows_at(tier: int, plan: Array) -> float:
	var worst := INF  # the smallest gap between a row and a cost label or pip, in base px
	for aspect in ASPECTS:
		for f in _foci(tier):
			var v := View.new(f, aspect)
			var labels := _spot_rects(v)
			var hero := _hero_rect(f, v)
			var rows := {}
			for lane in main.world.telegraph_markers:
				if not _marker(lane).shown().is_empty():
					rows[lane] = _row_rect(_marker(lane), v)
			for lane in rows:
				var r: Rect2 = rows[lane]
				for e in labels:
					var lr: Rect2 = e[1]
					assert_false(r.intersects(lr), "tier %d %.2f focus %s: the %s row %s overlaps %s %s" % [tier, aspect, f, lane, r, e[0], lr])
					worst = minf(worst, maxf(maxf(lr.position.x - r.end.x, r.position.x - lr.end.x), maxf(lr.position.y - r.end.y, r.position.y - lr.end.y)))
				assert_false(r.intersects(hero), "tier %d %.2f focus %s: the %s row %s is on the hero %s" % [tier, aspect, f, lane, r, hero])
				for other in rows:
					if String(lane) < String(other):
						assert_false(r.intersects(rows[other]), "%s and %s rows overlap at focus %s" % [lane, other, f])
	return worst

func test_tier2_rows_clear_every_cost_label_pip_and_the_hero() -> void:
	GameState.debug_set_tier(2, 5)
	await get_tree().physics_frame
	var worst := INF
	for boss in ["west", "north", "east"]:
		_set_plan(_plan_boss_on(boss))
		worst = minf(worst, _clear_rows_at(2, []))
	gut.p("tier 2 smallest gap between a row and a label or pip: %.1f base px" % worst)

func test_tier3_rows_clear_every_cost_label_pip_the_hero_and_the_queue() -> void:
	_tier3()
	await get_tree().physics_frame
	var worst := INF
	for boss in ["west", "north", "east", "sw"]:
		_set_plan(_plan_boss_on(boss))
		worst = minf(worst, _clear_rows_at(3, []))
	_set_plan(_plan_boss_on("east"))
	gut.p("tier 3 smallest gap between a row and a label or pip: %.1f base px" % worst)
	# the queue: a traveler body on every queue slot
	for aspect in ASPECTS:
		for f in [MapLayout.HOME, MapLayout.SIGN]:
			var v := View.new(f, aspect)
			for slot in MapLayout.queue_slots(3):
				var body := _hero_rect(slot, v)
				for lane in main.world.telegraph_markers:
					if not _marker(lane).shown().is_empty():
						assert_false(_row_rect(_marker(lane), v).intersects(body), "%s row on the queue slot %s" % [lane, slot])

func test_rows_with_three_pairs_and_the_boss_are_fully_on_screen_from_home() -> void:
	_tier3()
	await get_tree().physics_frame
	for aspect in [9.0 / 21.0, 720.0 / 1280.0]:
		var v := View.new(MapLayout.HOME, aspect)
		for lane in ["west", "east", "sw", "north"]:
			_set_plan(_plan_boss_on(lane))
			var mk := _marker(lane)
			assert_eq(mk.shown().size(), 4, "%s carries three pairs and the boss" % lane)
			var r := _row_rect(mk, v)
			gut.p("home %.2f %s row %s" % [aspect, lane, r])
			assert_gte(r.position.x, -360.0, lane + " left edge on screen")
			assert_lte(r.end.x, 360.0, lane + " right edge on screen")
			assert_gte(r.position.y, -_base_height(aspect) * 0.5)
			assert_lte(r.end.y, _base_height(aspect) * 0.5)

func test_the_row_is_up_path_of_its_marker_at_a_fixed_height_and_grows_inward() -> void:
	_tier3()
	await get_tree().physics_frame
	_set_plan(_full_plan_t3())
	for lane in main.world.telegraph_markers:
		var mk := _marker(lane)
		var a := mk.row_anchor()
		assert_almost_eq(a.y, Balance.ui.telegraph_row_height_m, 1e-6, "fixed height, no threat term")
		assert_almost_eq(a.y, 1.0, 0.25, "about 1 m")
		if lane != "sw":  # the three northern lanes: the row is further from the diner than the marker, along the lane's side
			var end: Vector2 = MapLayout.lane_path(lane).back()
			assert_gt(Vector2(a.x, a.z).distance_to(end), Vector2(mk.global_position.x, mk.global_position.z).distance_to(end), lane + ": up-path of the marker")
		var xs: Array = []
		for kind in mk.items:
			if (mk.items[kind].icon as Node3D).visible:
				xs.append((mk.items[kind].icon as Node3D).global_position.x)
		if mk.row_align() == -1:
			assert_gte(xs.min(), a.x - 1e-4, lane + " grows toward +x")
		elif mk.row_align() == 1:
			assert_lte(xs.max(), a.x + 1e-4, lane + " grows toward -x")
		else:
			assert_lt(xs.min(), a.x, lane + " is centred on its anchor")
			assert_gt(xs.max(), a.x)
	assert_eq(_marker("north").row_align(), 0)
	assert_eq(_marker("west").row_align(), -1)
	assert_eq(_marker("sw").row_align(), -1)
	assert_eq(_marker("east").row_align(), 1)

func test_every_glyph_triangulates_every_layer_and_stays_off_gold() -> void:
	for kind in LaneIcons.KINDS:
		assert_eq(LaneIcons.mesh(kind).surface_get_array_len(0), LaneIcons.expected_vertices(kind), "%s: every layer triangulated" % kind)
		for l in LaneIcons.layers(kind):
			assert_eq(Geometry2D.triangulate_polygon(l[0]).size(), 3 * (l[0].size() - 2), "%s: a fill layer is a simple polygon" % kind)
			assert_false(String(l[1]).begins_with("gold"), "%s: gold is the hero-and-reward colour" % kind)
			assert_false(String(l[1]).contains("white"), "%s: no white" % kind)
