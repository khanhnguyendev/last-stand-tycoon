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

# --- readability --------------------------------------------------------------

func _base_height(aspect: float) -> float:
	return maxf(1280.0, 720.0 / aspect)

## Projected height in base pixels of a vertical world length `len` centred at `p`, seen by a camera on `focus`.
func _px_height(p: Vector3, len: float, focus: Vector2, aspect: float) -> float:
	var xf := CameraMath.camera_transform(CameraMath.focus_for(focus), Balance.ui)
	var proj := CameraMath.projection(Balance.ui, aspect)
	var up := xf.basis.y * len * 0.5
	var a := CameraMath.to_ndc(p - up, xf, proj)
	var b := CameraMath.to_ndc(p + up, xf, proj)
	return absf(b.y - a.y) * 0.5 * _base_height(aspect)

func _full_plan() -> Array:  # every kind on every lane, and a boss on the last wave's main lane
	var w1 := _wave("west", 6, 2, "north", 5, 1, 1, 1)
	var w2 := _wave("east", 6, 2, "west", 5, 1, 1, 1)
	w2.boss = true
	return [w1, w2]

func test_icon_and_number_sizes_meet_the_ui_tuning_minimums() -> void:
	_tier3()
	await get_tree().physics_frame
	_set_plan(_full_plan())
	var worst_icon := INF
	var worst_num := INF
	for aspect in ASPECTS:
		var heroes := [MapLayout.HOME]
		for lane in MapLayout.lanes_for_tier(3):
			heroes.append(MapLayout.zone_rect(lane).get_center())
		for hero in heroes:
			for lane in main.world.telegraph_markers:
				var mk := _marker(lane)
				for kind in mk.items:
					var it: Dictionary = mk.items[kind]
					if not (it.icon as Node3D).visible:
						continue
					var ip := ((it.icon as Node3D).global_position)
					worst_icon = minf(worst_icon, _px_height(ip, Balance.ui.telegraph_icon_m, hero, aspect))
					if it.num != null:
						var l := it.num as Label3D
						worst_num = minf(worst_num, _px_height(l.global_position, float(l.font_size) * l.pixel_size, hero, aspect))
	gut.p("measured worst icon %.1f px, worst number em %.1f px (minimums %.0f, %.0f)" % [worst_icon, worst_num, Balance.ui.telegraph_icon_min_px, Balance.ui.telegraph_number_min_px])
	assert_gte(worst_icon, Balance.ui.telegraph_icon_min_px)
	assert_gte(worst_num, Balance.ui.telegraph_number_min_px)
	assert_eq(Balance.ui.telegraph_icon_min_px, 28.0, "the floors are the plan's 28")
	assert_eq(Balance.ui.telegraph_number_min_px, 28.0)

## The screen rectangle (base 720 wide, from HOME at `aspect`) of everything a row shows.
func _row_rect(mk: TelegraphMarker, aspect: float) -> Rect2:
	var xf := CameraMath.camera_transform(CameraMath.focus_for(MapLayout.HOME), Balance.ui)
	var proj := CameraMath.projection(Balance.ui, aspect)
	var rect := Rect2()
	var first := true
	for kind in mk.items:
		var it: Dictionary = mk.items[kind]
		if not (it.icon as Node3D).visible:
			continue
		var boxes: Array = []
		var c: Vector3 = (it.icon as Node3D).global_position
		var h := Balance.ui.telegraph_icon_m * 0.5
		boxes.append(AABB(c - Vector3(h, h, 0), Vector3(h * 2, h * 2, 0)))
		if it.num != null:
			var l := it.num as Label3D
			var bb := l.get_aabb()
			boxes.append(AABB(l.global_position + bb.position, bb.size))
		for b in boxes:
			for corner in [b.position, b.end, Vector3(b.position.x, b.end.y, b.position.z), Vector3(b.end.x, b.position.y, b.end.z)]:
				var n := CameraMath.to_ndc(corner, xf, proj)
				var pt := Vector2(n.x * 360.0, -n.y * 0.5 * _base_height(aspect))
				if first:
					rect = Rect2(pt, Vector2.ZERO)
					first = false
				else:
					rect = rect.expand(pt)
	return rect

func test_rows_of_neighbouring_markers_do_not_overlap_from_home_at_9_16() -> void:
	_set_plan(_full_plan())
	var lanes: Array = main.world.telegraph_markers.keys()
	var rects := {}
	for lane in lanes:
		if _marker(lane).shown().is_empty():
			continue
		rects[lane] = _row_rect(_marker(lane), 720.0 / 1280.0)
		gut.p("row %s: %s" % [lane, rects[lane]])
	assert_gte(rects.size(), 3, "all three lanes carry a row")
	for a in rects:
		for b in rects:
			if String(a) < String(b):
				assert_false((rects[a] as Rect2).intersects(rects[b]), "%s and %s overlap: %s vs %s" % [a, b, rects[a], rects[b]])
