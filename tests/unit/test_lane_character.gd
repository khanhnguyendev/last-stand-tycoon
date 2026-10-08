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
