extends GutTest
## E5 spec 6.3: the 4 -> 5 step (it now ends at schema 6 through the 5 -> 6 step), tier validation, the tier clamp.

func before_each() -> void:
	Balance.reset()
	SaveCodec.MIGRATIONS.clear()
	GameState.new_game(20260930)

func after_each() -> void:
	Balance.reset()
	GameState.new_game(1)

func _v4_state(day := 12) -> Dictionary:
	# a schema 4 state as E1 wrote it: no tier keys, lane_plan without fast_*/boss
	var s := GameState.to_dict()
	s.v = 4
	s.day = day
	for k in ["tier", "tier_day", "tier_paid", "boss_pending"]:
		s.erase(k)
	for w in s.lane_plan:
		for k in ["fast_main", "fast_side", "boss"]:
			w.erase(k)
	for id in s.buildings:
		s.buildings[id].erase("branch")
		s.buildings[id].erase("branch_paid")
	return s

func _decode(s: Dictionary) -> Dictionary:
	return SaveCodec.decode(SaveCodec.encode(s, "t", 0), GameState.SCHEMA_VERSION, Balance.data)

func test_schema_4_migrates_to_5_at_tier_1() -> void:
	var r := _decode(_v4_state(12))
	assert_true(r.ok, r.reason)
	assert_eq([r.state.v, r.state.tier, r.state.tier_day, r.state.tier_paid, r.state.boss_pending], [6, 1, 1, 0, false])
	var keys: Array = r.state.buildings.keys()
	keys.sort()  # the codec writes sorted keys
	var want := MapLayout.spots_for_tier(1)
	want.sort()
	assert_eq(keys, want)
	for w in r.state.lane_plan:
		assert_eq([w.fast_main, w.fast_side, w.boss], [0, 0, false])
	for id in r.state.buildings:
		assert_eq([r.state.buildings[id].branch, r.state.buildings[id].branch_paid], ["", {}], id)
	assert_eq(int(r.state.day), 12, "a day-12 tier-1 save keeps its day; it meets day-7 pressure from its next dawn")

func test_built_in_step_survives_a_cleared_hook_table() -> void:
	SaveCodec.MIGRATIONS.clear()
	assert_true(_decode(_v4_state()).ok)

func test_round_trip_at_tier_2() -> void:
	GameState.day = 9  # test-only setup: tier_day may not exceed day
	GameState.debug_set_tier(2, 9)
	GameState.add_gold(70)
	var r := _decode(GameState.to_dict())
	assert_true(r.ok, r.reason)
	assert_eq(r.state.tier, 2)
	assert_true(r.state.buildings.has("tower_w"))

func test_rejects_bad_tier_fields() -> void:
	var bad := [
		["tier", 0, "range tier"], ["tier", Balance.data.tiers.max_tier + 1, "range tier"], ["tier", "two", "type tier"],
		["tier_day", 0, "range tier_day"], ["tier_day", 99, "range tier_day"],
		["tier_paid", -1, "range tier_paid"], ["boss_pending", 1, "type boss_pending"],
	]
	for b in bad:
		var s := GameState.to_dict()
		s[b[0]] = b[1]
		assert_eq(SaveCodec.validate(s, Balance.data), b[2], str(b))
	var missing := GameState.to_dict()
	missing.erase("tier_paid")
	assert_eq(SaveCodec.validate(missing, Balance.data), "missing tier_paid")

func test_rejects_spot_tier_mismatches() -> void:
	var s := GameState.to_dict()  # tier 1
	s.buildings["tower_w"] = {"level": 0, "paid": 0, "hp": 0.0}
	assert_eq(SaveCodec.validate(s, Balance.data), "building tier tower_w", "a tier-2 spot in a tier-1 save")
	GameState.debug_set_tier(2, 1)
	var s2 := GameState.to_dict()
	s2.buildings.erase("tower_e")
	assert_eq(SaveCodec.validate(s2, Balance.data), "missing building tower_e")
	s2 = GameState.to_dict()
	s2.buildings["castle"] = {"level": 0, "paid": 0, "hp": 0.0}
	assert_eq(SaveCodec.validate(s2, Balance.data), "building castle")

func test_rejects_bad_wave_keys() -> void:
	var s := GameState.to_dict()
	s.lane_plan[0].fast_main = int(s.lane_plan[0].main_count) + 1
	assert_eq(SaveCodec.validate(s, Balance.data), "lane fast")
	s = GameState.to_dict()
	s.lane_plan[0].boss = true
	assert_eq(SaveCodec.validate(s, Balance.data), "lane boss", "the boss only rides the last wave")
	s = GameState.to_dict()
	s.lane_plan[2].boss = true
	assert_eq(SaveCodec.validate(s, Balance.data), "", "a boss in the last wave is fine without boss_pending (fixtures)")
	s = GameState.to_dict()
	s.lane_plan[0].erase("boss")
	assert_eq(SaveCodec.validate(s, Balance.data), "lane_plan fields")
	s = GameState.to_dict()
	s.lane_plan[0].fast_main = "many"
	assert_eq(SaveCodec.validate(s, Balance.data), "lane fields", "a non-numeric fast count")
	s = GameState.to_dict()
	s.lane_plan[2].boss = 1
	assert_eq(SaveCodec.validate(s, Balance.data), "lane fields", "a non-bool boss")

func test_tier_above_the_top_is_clamped_only_when_its_spots_are_known() -> void:
	Balance.data.tiers.tier_costs = [0, 500]  # setup: a two-tier build (the shipped build now has three), so tier 3 is above its top
	GameState.debug_set_tier(2, 1)
	var s := GameState.to_dict()
	s.tier = 3
	assert_eq(SaveCodec.validate(s, Balance.data), "", "tier 3 is below max_tier: accepted, GameState clamps it")
	var r := _decode(s)
	assert_true(r.ok, r.reason)
	GameState.from_dict(r.state)
	assert_eq(GameState.tier, 2)
	GameState.new_game(20260930)
	var low := GameState.to_dict()  # tier-1 buildings only
	low.tier = 3
	assert_eq(SaveCodec.validate(low, Balance.data), "missing building tower_w")

func test_paid_at_or_above_cost_is_clamped_on_load() -> void:
	var s := GameState.to_dict()
	s.tier_paid = 500
	var r := _decode(s)
	assert_true(r.ok, r.reason)
	GameState.from_dict(r.state)
	assert_eq(GameState.tier_paid, 499)
	assert_false(GameState.boss_pending)

func test_schema_3_fixtures_still_load() -> void:
	for stem in ["night3_start", "night3_closeup", "day3_counter5"]:
		var text := FileAccess.get_file_as_string("res://export/fixtures/%s.save.json" % stem)
		var r := SaveCodec.decode(text, GameState.SCHEMA_VERSION, Balance.data)
		assert_true(r.ok, "%s: %s" % [stem, r.reason])
		assert_eq([r.state.v, r.state.tier], [6, 1])

func test_schema_4_with_a_bad_lane_plan_is_content() -> void:
	var variants := {"erased": null, "null": null, "number": 7, "bad wave": 1}
	for name in variants:
		var s := _v4_state()
		match name:
			"erased": s.erase("lane_plan")
			"null": s.lane_plan = null
			"number": s.lane_plan = 7
			"bad wave": s.lane_plan[0] = 1
		var r := _decode(s)
		assert_false(r.ok, name)
		assert_eq(r.reason, "content", name)

func test_a_tier_above_what_the_build_knows_is_rejected() -> void:
	GameState.debug_set_tier(2, 1)
	var s := GameState.to_dict()
	Balance.data.tiers.tier_costs = [0]  # test-only setup: a build that only knows tier 1
	assert_eq(SaveCodec.validate(s, Balance.data), "building tier tower_w")
