extends GutTest
## E6 task 2 (spec 3.1, D-282): the run's lane character. The literal pins are forever: saves depend on them.

const PINS := {
	1: ["east", "west"], 2: ["east", "north"], 3: ["sw", "west"], 4: ["west", "north"],
	5: ["east", "north"], 6: ["west", "sw"], 7: ["north", "sw"], 8: ["east", "north"],
}
const LANES := ["west", "north", "east", "sw"]

func test_same_seed_same_character() -> void:
	# Fails for an implementation that draws from a global or time-based RNG.
	for s in [1, 7, 20260930]:
		assert_eq(LaneCharacter.for_run(s), LaneCharacter.for_run(s), "seed %d" % s)

func test_pinned_characters_seeds_1_to_8() -> void:
	# Fails if the stream name, day, draw order, lane order or "others" order changes.
	for s in PINS:
		var c := LaneCharacter.for_run(s)
		assert_eq(c.siege, PINS[s][0], "seed %d siege" % s)
		assert_eq(c.hare, PINS[s][1], "seed %d hare" % s)

func test_siege_and_hare_differ_and_are_real_lanes() -> void:
	# Fails for an implementation that draws the hare lane from all four lanes.
	for s in range(1, 201):
		var c := LaneCharacter.for_run(s)
		assert_ne(c.siege, c.hare, "seed %d" % s)
		assert_true(LANES.has(c.siege) and LANES.has(c.hare), "seed %d lanes" % s)

func test_distribution_over_200_seeds() -> void:
	# Fails for a biased draw (always the first lane, or a modulo that skips a lane).
	var siege := {}
	var hare := {}
	for s in range(1, 201):
		var c := LaneCharacter.for_run(s)
		siege[c.siege] = int(siege.get(c.siege, 0)) + 1
		hare[c.hare] = int(hare.get(c.hare, 0)) + 1
	gut.p("siege counts %s" % [siege])
	gut.p("hare counts %s" % [hare])
	for lane in LANES:
		assert_gte(int(siege.get(lane, 0)), 30, "%s as siege" % lane)
		assert_gte(int(hare.get(lane, 0)), 30, "%s as hare" % lane)

func test_for_run_touches_only_its_own_stream() -> void:
	# Fails for an implementation that draws from another named stream or a shared RNG.
	for n in [&"lane_plan", &"cards", &"spawns", &"drops", &"travelers"]:
		var used := Rng.stream(77, 2, n)
		var a := [used.randi(), used.randi()]
		LaneCharacter.for_run(77)
		var b := [used.randi(), used.randi()]
		var fresh := Rng.stream(77, 2, n)
		assert_eq(a, [fresh.randi(), fresh.randi()], "%s first" % n)
		assert_eq(b, [fresh.randi(), fresh.randi()], "%s after for_run" % n)

func test_lane_type_literal_character() -> void:
	# Fails if siege and hare are swapped or a lane outside the character is not neutral.
	var c := {"siege": "east", "hare": "west"}
	assert_eq(LaneCharacter.lane_type(c, "east"), &"siege")
	assert_eq(LaneCharacter.lane_type(c, "west"), &"hare")
	assert_eq(LaneCharacter.lane_type(c, "north"), &"neutral")
	assert_eq(LaneCharacter.lane_type(c, "sw"), &"neutral")

func test_lane_type_empty_character_is_neutral() -> void:
	for lane in LANES:
		assert_eq(LaneCharacter.lane_type({}, lane), &"neutral", lane)

func test_spot_types_in_order() -> void:
	var c := {"siege": "east", "hare": "west"}
	assert_eq(LaneCharacter.spot_types(c, ["west", "north", "east"]), [&"hare", &"neutral", &"siege"])
	assert_eq(LaneCharacter.spot_types({}, ["west"]), [&"neutral"])

func test_scan_for_tuning_and_holdout_seeds() -> void:
	# Prints the first seeds per siege lane (tuning set) and the next two (hold-out set #1). Informational.
	var first := {}
	var nxt := {}
	for s in range(1, 400):
		var c := LaneCharacter.for_run(s)
		if not first.has(c.siege):
			first[c.siege] = s
		else:
			var a: Array = nxt.get(c.siege, [])
			if a.size() < 2:
				a.append(s)
			nxt[c.siege] = a
	gut.p("tuning set (first seed per siege lane): %s" % [first])
	gut.p("hold-out set #1 (next two per siege lane): %s" % [nxt])
	assert_eq(first.size(), 4)

# ---------------------------------------------------------------- E6 task 3: apply (spec 3.2, D-287)

func test_lane_type_empty_lane_is_neutral() -> void:
	# Fails for an implementation that lets an empty lane match a character with an empty siege or hare entry.
	assert_eq(LaneCharacter.lane_type({"siege": "", "hare": ""}, ""), &"neutral")
	assert_eq(LaneCharacter.lane_type({"siege": "east", "hare": "west"}, ""), &"neutral")

func _tb() -> TierBalance:
	return Balance.data.tiers

func _wave(main: String, side: String, mc: int, sc: int, fm: int, fs: int, bm := 0, bs := 0) -> Dictionary:
	return {"main": main, "side": side, "main_count": mc, "side_count": sc, "hp_mult": 1.0,
		"fast_main": fm, "fast_side": fs, "boss": false, "brute_main": bm, "brute_side": bs}

func _one(w: Dictionary, siege: String, hare: String) -> Dictionary:
	return LaneCharacter.apply([w], {"siege": siege, "hare": hare}, _tb())[0]

func _extra_total(w: Dictionary, key: String) -> int:
	var n := 0
	for e in w.get("extra", []):
		n += int(e[key])
	return n

func _totals(w: Dictionary) -> Array:
	return [int(w.main_count) + int(w.side_count) + _extra_total(w, "count"),
		int(w.fast_main) + int(w.fast_side) + _extra_total(w, "fast"),
		int(w.brute_main) + int(w.brute_side)]

func test_brutes_siege_is_main() -> void:
	# Fails for an implementation that always puts brutes on the side lane (or leaves them where the plan had them).
	var w := _one(_wave("east", "west", 6, 4, 0, 0, 0, 2), "east", "north")
	assert_eq([w.brute_main, w.brute_side, w.main, w.side], [2, 0, "east", "west"])

func test_brutes_siege_is_side() -> void:
	# Fails for an implementation that moves brutes to main.
	var w := _one(_wave("east", "west", 6, 4, 0, 0, 3, 0), "west", "north")
	assert_eq([w.brute_main, w.brute_side, w.main, w.side], [0, 3, "east", "west"])

func test_brutes_siege_is_neither_moves_the_side_group() -> void:
	# Fails for "side not moved" (brutes left on a non-siege lane) or an implementation that drops the group's count/hares.
	# The hare lane is main here, so the side group's count is untouched and one of its 2 hares moves to main (T = 1).
	var w := _one(_wave("east", "west", 6, 4, 0, 2, 1, 0), "sw", "east")
	assert_eq([w.side, w.side_count, w.fast_side, w.fast_main, w.brute_side, w.brute_main], ["sw", 4, 1, 1, 1, 0])
	assert_eq([w.main, w.main_count], ["east", 6])
	var n := _one(_wave("east", "west", 6, 4, 0, 0, 1, 0), "sw", "north")  # no hares: nothing else changes
	assert_eq([n.side, n.side_count, n.fast_side, n.main_count], ["sw", 4, 0, 6])

func test_no_brutes_leaves_lanes_untouched() -> void:
	# Fails for an implementation that moves the side group even when the wave has no brutes.
	var w := _one(_wave("east", "west", 6, 4, 0, 0), "sw", "north")
	assert_eq([w.main, w.side, w.side_count], ["east", "west", 4])

func test_brutes_with_no_side_group() -> void:
	# Fails for an implementation that crashes or leaves the brutes without a lane when side == "".
	var w := _one(_wave("east", "", 6, 0, 0, 0, 2, 0), "sw", "north")
	assert_eq([w.side, w.side_count, w.fast_side, w.brute_side, w.brute_main], ["sw", 0, 0, 2, 0])

func test_hares_lane_is_main_capped_by_count() -> void:
	# H = 10, T = 7; main has only 5 members: fast_main = 5 (the cap), the other 5 stay in the side group.
	# Fails for an implementation without the cap (fast_main 7 > main_count 5).
	var w := _one(_wave("east", "west", 5, 8, 2, 8), "sw", "east")
	assert_eq([w.fast_main, w.fast_side, w.extra if w.has("extra") else []], [5, 5, []])
	assert_eq(_totals(w), [13, 10, 0])

func test_hares_lane_is_main_uncapped() -> void:
	# H = 10, T = 7, main has room: fast_main 7, fast_side 3. Fails for "all hares to the hare lane" or no move.
	var w := _one(_wave("east", "west", 9, 9, 1, 9), "sw", "east")
	assert_eq([w.fast_main, w.fast_side], [7, 3])

func test_hares_lane_is_side() -> void:
	# H = 10, T = 7 on the side lane. Fails for an implementation that only handles the main case.
	var w := _one(_wave("east", "west", 9, 9, 9, 1), "sw", "west")
	assert_eq([w.fast_main, w.fast_side], [3, 7])
	var c := _one(_wave("east", "west", 9, 4, 9, 1), "sw", "west")  # side capped at its count 4
	assert_eq([c.fast_main, c.fast_side], [6, 4])

func test_hares_lane_neither_largest_remainder_5_to_2() -> void:
	# fast_main 5, fast_side 2, H = 7, T = roundi(0.7 x 7 = 4.9) = 5.
	# main: 5 x 5 / 7 = 3.571 (floor 3, remainder 4/7); side: 5 x 2 / 7 = 1.428 (floor 1, remainder 3/7).
	# 3 + 1 = 4 < 5, the leftover goes to the larger remainder: main. Split = main 4, side 1.
	# Fails for "hares taken from main only" (main would give 5, side 0) and for plain rounding (main 4 + side 1 = 5
	# only by luck; the leftover rule is pinned by the tie test below).
	var w := _one(_wave("east", "west", 9, 6, 5, 2), "sw", "north")
	assert_eq(w.extra, [{"lane": "north", "count": 5, "fast": 5}])
	assert_eq([w.main_count, w.fast_main, w.side_count, w.fast_side], [5, 1, 5, 1])
	assert_eq(_totals(w), [15, 7, 0])

func test_proportional_not_main_only() -> void:
	# fast 3 : 3, H = 6, T = roundi(4.2) = 4: 2 from each. Fails for "taken from main only" (main would give 3).
	var w := _one(_wave("east", "west", 9, 9, 3, 3), "sw", "north")
	assert_eq([w.fast_main, w.fast_side, w.main_count, w.side_count], [1, 1, 7, 7])
	assert_eq(w.extra[0].count, 4)

func test_split_tie_goes_to_main() -> void:
	# fast 1 : 1, H = 2, T = roundi(1.4) = 1: remainders equal (1/2 each); the tie goes to main.
	var w := _one(_wave("east", "west", 5, 5, 1, 1), "sw", "north")
	assert_eq([w.fast_main, w.fast_side], [0, 1])
	assert_eq(w.extra, [{"lane": "north", "count": 1, "fast": 1}])

func test_small_hare_counts_never_negative_and_sum_exact() -> void:
	# H = 1 -> T = 1 (0.7 rounds up), H = 2 -> T = 1. Fails for floor rounding (T = 0 for H = 1) or negatives.
	var a := _one(_wave("east", "west", 5, 5, 1, 0), "sw", "north")
	assert_eq([a.fast_main, a.fast_side, a.main_count, a.side_count], [0, 0, 4, 5])
	assert_eq(a.extra, [{"lane": "north", "count": 1, "fast": 1}])
	var b := _one(_wave("east", "west", 5, 5, 0, 2), "sw", "north")
	assert_eq([b.fast_main, b.fast_side, b.main_count, b.side_count], [0, 1, 5, 4])
	assert_eq(_totals(b), [10, 2, 0])

func test_no_hares_no_extra_group() -> void:
	# Fails for an implementation that appends an empty extra group when H = 0.
	var w := _one(_wave("east", "west", 5, 5, 0, 0), "sw", "north")
	assert_false(w.has("extra"))
	assert_eq(_totals(w), [10, 0, 0])

func test_order_side_was_hare_lane_then_replaced_by_siege() -> void:
	# The drawn side lane (west) IS the hare lane, but the brutes' siege lane (sw) replaces it, so the hare lane is
	# now neither main nor side and gets an extra group: exactly 3 active lanes. Fails if hares are placed before brutes.
	var w := _one(_wave("east", "west", 6, 4, 3, 3, 1, 0), "sw", "west")
	assert_eq(w.side, "sw")
	assert_eq(w.extra.size(), 1)
	assert_eq(w.extra[0].lane, "west")
	assert_eq(LaneCharacter.active_lanes(w).size(), 3)
	assert_eq(_totals(w), [10, 6, 1])

func test_siege_main_hare_side_has_no_extra_and_two_lanes() -> void:
	# Fails for an implementation that adds an extra group whenever the hare lane is not the drawn main.
	var w := _one(_wave("east", "west", 6, 4, 3, 3, 1, 0), "east", "west")
	assert_false(w.has("extra"))
	assert_eq(LaneCharacter.active_lanes(w).size(), 2)
	assert_eq(w.fast_side, 4)

func test_guard_skips_a_fourth_lane_and_is_counted() -> void:
	# A hand-made wave that already has an extra lane: a second extra would make 4 lanes, so it is skipped and counted.
	var w := _wave("east", "west", 5, 5, 3, 3)
	w["extra"] = [{"lane": "sw", "count": 2, "fast": 0}]
	var out := LaneCharacter.apply([w], {"siege": "sw", "hare": "north"}, _tb())
	assert_eq(LaneCharacter.guard_hits(out), 1)
	assert_eq(out[0].extra.size(), 1)
	assert_eq([out[0].fast_main, out[0].fast_side], [3, 3])
	assert_eq(LaneCharacter.guard_hits(LaneCharacter.apply([_wave("east", "west", 5, 5, 3, 3)], {"siege": "sw", "hare": "north"}, _tb())), 0)

func test_brute_lane_and_active_lanes_helpers() -> void:
	assert_eq(LaneCharacter.brute_lane(_wave("east", "west", 1, 1, 0, 0)), "")
	assert_eq(LaneCharacter.brute_lane(_wave("east", "west", 1, 1, 0, 0, 1, 0)), "east")
	assert_eq(LaneCharacter.brute_lane(_wave("east", "west", 1, 1, 0, 0, 0, 1)), "west")
	assert_eq(LaneCharacter.active_lanes(_wave("east", "", 3, 0, 0, 0)), ["east"])
	assert_eq(LaneCharacter.active_lanes(_wave("east", "west", 3, 0, 0, 0, 0, 1)), ["east", "west"])

func test_purity_and_identity() -> void:
	var ch := {"siege": "sw", "hare": "north"}
	var plan := LanePlanner.plan(5, 10, Balance.data.wave, 3, 1, _tb())
	var before: Array = plan.duplicate(true)
	var a := LaneCharacter.apply(plan, ch, _tb())
	assert_eq(plan, before, "input not mutated")
	assert_eq(a, LaneCharacter.apply(plan, ch, _tb()), "deterministic")
	assert_ne(a, plan, "a non-empty character changes a tier-3 plan")
	assert_eq(LaneCharacter.apply(plan, {}, _tb()), plan, "empty character: equal copy")
	for tier in [1, 2]:
		var p := LanePlanner.plan(5, 10, Balance.data.wave, tier, 1, _tb())
		assert_eq(LaneCharacter.apply(p, {}, _tb()), p, "tier %d" % tier)

func test_scan_invariants_200_seeds() -> void:
	# Fails for any rule that loses/duplicates enemies, leaves a brute off the siege lane, makes a 4th lane, or mutates input.
	var guard := 0
	var waves_with_brutes := 0
	for s in range(1, 201):
		var ch := LaneCharacter.for_run(s)
		for day in [1, 2, 3, 4, 10]:
			var plan := LanePlanner.plan(s, day, Balance.data.wave, 3, 1, _tb())
			var before: Array = plan.duplicate(true)
			var out := LaneCharacter.apply(plan, ch, _tb())
			assert_eq(plan, before, "seed %d day %d input mutated" % [s, day])
			guard += LaneCharacter.guard_hits(out)
			for i in plan.size():
				var win: Dictionary = plan[i]
				var w: Dictionary = out[i]
				var tag := "seed %d day %d wave %d" % [s, day, i]
				var tin := [int(win.main_count) + int(win.side_count), int(win.fast_main) + int(win.fast_side), int(win.brute_main) + int(win.brute_side)]
				if _totals(w) != tin:
					fail_test("%s totals %s != %s" % [tag, _totals(w), tin])
					return
				if LaneCharacter.brute_lane(w) != "":
					waves_with_brutes += 1
					if LaneCharacter.brute_lane(w) != ch.siege or (int(w.brute_main) > 0 and int(w.brute_side) > 0):
						fail_test("%s brutes off the siege lane" % tag)
						return
				if LaneCharacter.active_lanes(w).size() > 3:
					fail_test("%s more than 3 active lanes" % tag)
					return
				var groups: Array = [[w.main_count, w.fast_main], [w.side_count, w.fast_side]]
				for e in w.get("extra", []):
					groups.append([e.count, e.fast])
				for g in groups:
					if int(g[0]) < 0 or int(g[1]) < 0 or int(g[1]) > int(g[0]):
						fail_test("%s bad group %s" % [tag, g])
						return
				if int(w.brute_main) < 0 or int(w.brute_side) < 0:
					fail_test("%s negative brutes" % tag)
					return
	gut.p("scan: waves with brutes %d, LANE_CAP_GUARD hits %d" % [waves_with_brutes, guard])
	assert_gt(waves_with_brutes, 0)
	assert_eq(guard, 0, "guard count")

func test_hare_share_report_and_floor() -> void:
	# Fails for an implementation that leaves most hares off the hare lane (share below the author's 0.6 flag level).
	var shares: Array = []
	var per_seed: Array = []
	for s in range(1, 201):
		var ch := LaneCharacter.for_run(s)
		var plan := LanePlanner.plan(s, 10, Balance.data.wave, 3, 1, _tb())
		var sh := LaneCharacter.hare_share(LaneCharacter.apply(plan, ch, _tb()), ch)
		shares.append(sh)
		if s <= 14:
			per_seed.append("%d:%.3f" % [s, sh])
		assert_gte(sh, 0.6, "seed %d hare share" % s)
	gut.p("hare share day 10, seeds 1-14: %s" % [", ".join(per_seed)])
	var sorted := shares.duplicate()
	sorted.sort()
	gut.p("hare share over 200 seeds: min %.3f median %.3f max %.3f" % [sorted[0], (sorted[99] + sorted[100]) / 2.0, sorted[199]])
