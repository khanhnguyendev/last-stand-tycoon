extends GutTest
## E8 phase 2 Task 3 (spec 4.4, B5 to B7): tier-4 waves in the planner, step b for three groups, the codec, schema 8.

const T3_HASHES := "res://tests/fixtures/plans_tier3_hashes.json"
const V7_FIXTURE := "res://tests/fixtures/v7_tier3_cap_threat.save.json"
const V7_FIXTURE_CHECK := 273485684

var wb: WaveBalance
var tb: TierBalance

func before_each() -> void:
	Balance.reset()
	SaveCodec.MIGRATIONS.clear()
	Tier4Support.open_tier4()
	wb = Balance.data.wave
	tb = Balance.data.tiers

func after_each() -> void:
	Balance.reset()
	GameState.new_game(1)

func _t4_plan(seed: int, day: int) -> Array:
	return LaneCharacter.apply(LanePlanner.plan(seed, day, wb, 4, 20, tb), LaneCharacter.for_run(seed), tb)

# --- identity: tiers 1 to 3 do not change ---------------------------------------------------------------------

## The oracle is the committed table, captured from the code BEFORE this task (plan after LaneCharacter.apply).
## Mutation: tier 4's code runs below tier 4, or a tier-3 wave gains a key.
func test_tier3_plans_after_apply_equal_the_pre_task_hashes() -> void:
	var fx: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(T3_HASHES))
	var td := int(fx.tier_day)
	assert_eq(fx.hashes.size(), 240)
	for s in range(1, 41):
		var ch := LaneCharacter.for_run(s)
		for day in range(td, td + 6):
			var p := LaneCharacter.apply(LanePlanner.plan(s, day, wb, 3, td, tb), ch, tb)
			assert_eq(Rng.fnv1a32(JSON.stringify(p, "", true, true)), int(fx.hashes["%d:%d" % [s, day]]), "seed %d day %d" % [s, day])
			for w in p:
				assert_false(w.has("side2"), "no tier-4 key at tier 3")

# --- the draw (B6) --------------------------------------------------------------------------------------------

## Re-derives a tier-4 wave's lanes by hand from the two streams, as B6 fixes them.
func test_the_order_of_draws_is_pinned_by_hand() -> void:
	var redraws := 0
	for s in [1, 7, 20260930]:
		for day in [20, 23]:
			var ch := LaneCharacter.for_run(s)
			var neutral: Array = LanePlanner.LANES_TIER3.filter(func(l): return l != ch.siege and l != ch.hare)
			var rng := Rng.stream(s, day, &"lane_plan")
			var rng4 := Rng.stream(s, day, &"lane_plan_t4")
			var p := LanePlanner.plan(s, day, wb, 4, 20, tb)
			for w in p.size():
				var main: String = LanePlanner.LANES_TIER3[rng.randi_range(0, 3)]
				var counts := WaveMath.split(WaveMath.pressure(day, 4, 20, tb), w, wb)
				if int(counts.side) > 0:
					var others: Array = LanePlanner.LANES_TIER3.filter(func(l): return l != main)
					rng.randi_range(0, others.size() - 1)
				var rest: String = neutral[rng4.randi_range(0, 1)]
				if main == rest:
					redraws += 1
					var o: Array = LanePlanner.LANES_TIER3.filter(func(l): return l != rest)
					main = o[rng4.randi_range(0, 2)]
				var left: Array = LanePlanner.LANES_TIER3.filter(func(l): return l != main and l != rest)
				assert_eq([p[w].main, p[w].side, p[w].side2], [main, left[0], left[1]], "seed %d day %d wave %d" % [s, day, w])
	assert_gt(redraws, 0, "setup: some waves drew the resting lane as main, so the redraw branch is covered")

func test_tier4_waves_carry_the_four_keys_and_the_splits_add_up() -> void:
	for s in range(1, 41):
		for day in [20, 21, 25]:
			var pressure := WaveMath.pressure(day, 4, 20, tb)
			var p := LanePlanner.plan(s, day, wb, 4, 20, tb)
			for w in p.size():
				var wave: Dictionary = p[w]
				for k in ["side2", "side2_count", "fast_side2", "brute_side2"]:
					assert_true(wave.has(k), k)
				var counts := WaveMath.split(pressure, w, wb)
				assert_eq(int(wave.side_count) + int(wave.side2_count), int(counts.side))
				assert_eq(int(wave.side_count) - int(wave.side2_count), int(counts.side) % 2, "the odd unit to side")
				assert_true(int(wave.fast_side) <= int(wave.side_count) and int(wave.fast_side2) <= int(wave.side2_count))
				assert_eq(int(wave.brute_side) - int(wave.brute_side2), (int(wave.brute_side) + int(wave.brute_side2)) % 2, "brutes: odd to side")
				var resting: Array = LanePlanner.LANES_TIER3.filter(func(l): return l != wave.main and l != wave.side and l != wave.side2)
				var ch := LaneCharacter.for_run(s)
				assert_eq(resting.size(), 1)
				assert_true(resting[0] != ch.siege and resting[0] != ch.hare, "the resting lane is neutral: seed %d day %d wave %d" % [s, day, w])
				assert_eq(Dictionary({wave.main: 1, wave.side: 1, wave.side2: 1}).size(), 3, "three distinct lanes")

func test_the_splits_of_hares_and_brutes_add_up_to_the_unsplit_totals() -> void:
	for s in range(1, 41):
		var day := 21
		var p := LanePlanner.plan(s, day, wb, 4, 20, tb)
		var pressure := WaveMath.pressure(day, 4, 20, tb)
		var share := TierEffects.fast_share_now(day, 4, 20, tb)
		for w in p.size():
			var counts := WaveMath.split(pressure, w, wb)
			var fast := TierEffects.fast_counts(int(counts.main), int(counts.side), share)
			var brutes := TierEffects.brute_counts(day, 4, 20, w, p.size(), true, tb)
			assert_eq(int(p[w].fast_side) + int(p[w].fast_side2), int(fast.fast_side))
			assert_eq(int(p[w].brute_side) + int(p[w].brute_side2), int(brutes.side))
			assert_eq(int(p[w].main_count), int(counts.main))
			assert_eq(int(p[w].fast_main), int(fast.fast_main))
			assert_eq(int(p[w].brute_main), int(brutes.main))

# --- lane character at tier 4 (B7) ----------------------------------------------------------------------------

func test_after_apply_every_wave_holds_the_siege_and_the_hare_lane_in_three_lanes_with_no_extra_group() -> void:
	var tested_brutes := 0
	for s in range(1, 41):
		var ch := LaneCharacter.for_run(s)
		for day in range(20, 26):
			for wave in _t4_plan(s, day):
				var lanes := LaneCharacter.active_lanes(wave)
				assert_eq(lanes.size(), 3, "seed %d day %d" % [s, day])
				assert_true(lanes.has(ch.siege), "siege lane present")
				assert_true(lanes.has(ch.hare), "hare lane present")
				assert_false(wave.has("extra"), "never an extra group")
				assert_false(wave.has("lane_cap_guard"))
				if int(wave.brute_main) + int(wave.brute_side) + int(wave.brute_side2) > 0:
					tested_brutes += 1
					assert_eq(LaneCharacter.brute_lane(wave), ch.siege, "brutes walk the siege lane")
	assert_gt(tested_brutes, 0, "setup: some waves have brutes")

func test_apply_keeps_totals_and_is_idempotent_at_tier_4() -> void:
	for s in range(1, 41):
		var ch := LaneCharacter.for_run(s)
		var raw := LanePlanner.plan(s, 22, wb, 4, 20, tb)
		var once := LaneCharacter.apply(raw, ch, tb)
		assert_eq(LaneCharacter.apply(once, ch, tb), once, "idempotent")
		for w in raw.size():
			assert_eq(int(once[w].main_count) + int(once[w].side_count) + int(once[w].side2_count), int(raw[w].main_count) + int(raw[w].side_count) + int(raw[w].side2_count))
			assert_eq(int(once[w].fast_main) + int(once[w].fast_side) + int(once[w].fast_side2), int(raw[w].fast_main) + int(raw[w].fast_side) + int(raw[w].fast_side2), "hares conserved")
			assert_eq(int(once[w].brute_main) + int(once[w].brute_side) + int(once[w].brute_side2), int(raw[w].brute_main) + int(raw[w].brute_side) + int(raw[w].brute_side2), "brutes conserved")
			for g in [["main_count", "fast_main"], ["side_count", "fast_side"], ["side2_count", "fast_side2"]]:
				assert_true(int(once[w][g[1]]) <= int(once[w][g[0]]), "hares fit their group")

func _wave3(hare_group: String, fast: Array, counts: Array) -> Dictionary:
	return {"main": "west", "side": "north", "side2": "east", "main_count": counts[0], "side_count": counts[1], "side2_count": counts[2],
		"hp_mult": 1.0, "fast_main": fast[0], "fast_side": fast[1], "fast_side2": fast[2], "boss": false,
		"brute_main": 0, "brute_side": 0, "brute_side2": 0}

## The worked example (B7): pressure 14 (the tier-4 cap since E8 phase-2 round 2; the groups and hares are the same as at 15), wave 3, groups 16/7/7, hares 6/3/2, so H = 11 and T = 8. With side as the hare lane
## it takes 7 and 4 stay in main.
func test_step_b_worked_example() -> void:
	var p := LanePlanner.plan(1, 40, wb, 4, 20, tb)
	assert_eq(WaveMath.pressure(40, 4, 20, tb), 14)
	var real: Dictionary = p[2]  # the real planner's third wave (seed 1, day 40), before LaneCharacter.apply
	assert_eq([real.main_count, real.side_count, real.side2_count, real.fast_main, real.fast_side, real.fast_side2], [16, 7, 7, 6, 3, 2], "the example's groups and hares are the planner's")
	var base := _wave3("north", [6, 3, 2], [16, 7, 7])
	var out: Dictionary = LaneCharacter.apply([base], {"siege": "sw", "hare": "north"}, tb)[0]
	assert_eq([out.fast_main, out.fast_side, out.fast_side2], [4, 7, 0])
	assert_eq([out.main_count, out.side_count, out.side2_count], [16, 7, 7], "counts do not move")
	assert_false(out.has("extra"))
	assert_eq(p.size(), 3)

func test_step_b_other_hare_groups() -> void:
	var ch := {"siege": "sw", "hare": "west"}
	var out: Dictionary = LaneCharacter.apply([_wave3("west", [6, 3, 2], [16, 7, 7])], ch, tb)[0]
	assert_eq([out.fast_main, out.fast_side, out.fast_side2], [8, 3, 0], "main takes T = 8; the rest fill side, then side2")
	ch = {"siege": "sw", "hare": "east"}
	out = LaneCharacter.apply([_wave3("east", [6, 3, 2], [16, 7, 7])], ch, tb)[0]
	assert_eq([out.fast_main, out.fast_side, out.fast_side2], [4, 0, 7], "side2 is capped at its count of 7; 4 stay in main")

func test_step_b_leftover_goes_back_to_the_hare_group() -> void:
	# Others cannot hold the rest: counts 10/1/1 with 10 hares in main, hare lane main, T = 7: main takes 7, side 1, side2 1, 1 left to main.
	var out: Dictionary = LaneCharacter.apply([_wave3("west", [10, 0, 0], [10, 1, 1])], {"siege": "sw", "hare": "west"}, tb)[0]
	assert_eq([out.fast_main, out.fast_side, out.fast_side2], [8, 1, 1])
	assert_true(int(out.fast_main) <= int(out.main_count))

func test_step_a_puts_the_brutes_on_whichever_group_is_the_siege_lane() -> void:
	for g in [["west", [3, 0, 0]], ["north", [0, 3, 0]], ["east", [0, 0, 3]]]:
		var wave := _wave3("x", [0, 0, 0], [5, 5, 5])
		wave["brute_main"] = 1
		wave["brute_side"] = 1
		wave["brute_side2"] = 1
		var out: Dictionary = LaneCharacter.apply([wave], {"siege": g[0], "hare": "sw"}, tb)[0]
		assert_eq([out.brute_main, out.brute_side, out.brute_side2], g[1], "siege " + g[0])
		assert_eq(LaneCharacter.brute_lane(out), g[0])

func test_lane_set_counts_side2() -> void:
	var wave := _wave3("x", [0, 0, 0], [0, 0, 0])
	assert_eq(LaneCharacter.active_lanes(wave), [])
	wave["brute_side2"] = 1
	assert_eq(LaneCharacter.active_lanes(wave), ["east"])
	assert_eq(LaneCharacter.brute_lane(wave), "east")
	wave["side2_count"] = 2
	wave["main_count"] = 1
	assert_eq(LaneCharacter.active_lanes(wave), ["west", "east"])

# --- validate (spec 4.4) --------------------------------------------------------------------------------------

func _state_t4() -> Dictionary:
	GameState.new_game(20260930)
	GameState.debug_set_tier(4, 3)
	GameState.day = 6
	GameState.advance_day()
	return GameState.to_dict()

func test_a_tier4_state_validates_and_round_trips() -> void:
	var s := _state_t4()
	assert_eq(int(s.tier), 4)
	assert_true(s.lane_plan[0].has("side2"))
	assert_eq(SaveCodec.validate(s, Balance.data), "")
	var r := SaveCodec.decode(SaveCodec.encode(s, "t", 0), GameState.SCHEMA_VERSION, Balance.data)
	assert_true(r.ok, r.reason)
	GameState.new_game(5)
	GameState.from_dict(r.state)
	assert_eq(GameState.to_dict().lane_plan, s.lane_plan)

func test_validate_rejects_a_missing_or_bad_side2() -> void:
	for k in ["side2", "side2_count", "fast_side2", "brute_side2"]:
		var s := _state_t4()
		s.lane_plan[1].erase(k)
		assert_eq(SaveCodec.validate(s, Balance.data), "lane " + k, "missing " + k)
	var cases := {
		"lane side2": [["side2", "nowhere"], ["side2", 3], ["side2", "@main"]],
		"lane side2_count": [["side2_count", -1], ["side2_count", 1.5], ["side2_count", "x"]],
		"lane brute_side2": [["brute_side2", -1], ["brute_side2", 0.5]],
		"lane fast_side2": [["fast_side2", 999]],
	}
	for why in cases:
		for c in cases[why]:
			var s := _state_t4()
			var v = c[1]
			if typeof(v) == TYPE_STRING and v == "@main":
				v = s.lane_plan[1].main
			s.lane_plan[1][c[0]] = v
			assert_eq(SaveCodec.validate(s, Balance.data), why, "%s %s" % [c[0], str(c[1])])
	var s2 := _state_t4()
	s2.lane_plan[0].side2 = s2.lane_plan[0].side
	assert_eq(SaveCodec.validate(s2, Balance.data), "lane side2", "side2 equals side")
	var s3 := _state_t4()
	s3.lane_plan[0].fast_side2 = int(s3.lane_plan[0].side2_count) + 1
	assert_eq(SaveCodec.validate(s3, Balance.data), "lane fast_side2")

## Mutation: the codec accepts an extra group, or an empty side lane, on a tier-4 wave.
func test_validate_rejects_extra_and_an_empty_side_on_a_tier_4_wave() -> void:
	var s := _state_t4()
	s.lane_plan[0]["extra"] = [{"lane": "west", "count": 1, "fast": 0}]
	assert_eq(SaveCodec.validate(s, Balance.data), "lane extra", "extra on a tier-4 wave")
	var t := _state_t4()
	t.lane_plan[0].side = ""
	assert_eq(SaveCodec.validate(t, Balance.data), "lane side", "an empty side on a tier-4 wave")

func test_validate_rejects_the_tier4_keys_below_tier_4() -> void:
	GameState.new_game(20260930)
	GameState.debug_set_tier(3, 3)
	GameState.day = 6
	GameState.advance_day()
	for k in ["side2", "side2_count", "fast_side2", "brute_side2"]:
		var s := GameState.to_dict()
		assert_eq(SaveCodec.validate(s, Balance.data), "")
		s.lane_plan[0][k] = "west" if k == "side2" else 0
		assert_eq(SaveCodec.validate(s, Balance.data), "lane " + k, "tier 3 rejects " + k)

# --- schema 8 -------------------------------------------------------------------------------------------------

func test_schema_is_8() -> void:
	assert_eq(GameState.SCHEMA_VERSION, 8)
	assert_eq(int(GameState.to_dict().v), 8)

func test_the_committed_v7_fixture_is_the_one_pinned() -> void:
	var env = SaveCodec._parse(FileAccess.get_file_as_string(V7_FIXTURE))
	assert_eq(int(env.check), V7_FIXTURE_CHECK)
	assert_eq(Rng.fnv1a32(env.state_json), V7_FIXTURE_CHECK)
	assert_eq(int(SaveCodec._parse(env.state_json).v), 7)

## The v7 to v8 step adds nothing: only "v" changes. Mutation: the step adds or drops a field.
func test_v7_to_v8_adds_nothing_and_the_save_loads_at_tier_3() -> void:
	var env = SaveCodec._parse(FileAccess.get_file_as_string(V7_FIXTURE))
	var old: Dictionary = SaveCodec._parse(env.state_json)
	var r := SaveCodec.decode(FileAccess.get_file_as_string(V7_FIXTURE), GameState.SCHEMA_VERSION, Balance.data)
	assert_true(r.ok, r.reason)
	var want: Dictionary = old.duplicate(true)
	want.v = 8
	assert_eq(JSON.stringify(r.state, "", true, true), JSON.stringify(want, "", true, true))
	GameState.new_game(3)
	GameState.from_dict(r.state)
	assert_eq(GameState.tier, 3)
	for w in GameState.lane_plan:
		assert_false(w.has("side2"))
	assert_eq(int(GameState.to_dict().v), 8)

func test_a_v7_tier3_save_loads_when_tier_4_is_open_and_stays_tier_3() -> void:
	var r := SaveCodec.decode(FileAccess.get_file_as_string(V7_FIXTURE), GameState.SCHEMA_VERSION, Balance.data)
	assert_true(r.ok, r.reason)
	GameState.new_game(3)
	GameState.from_dict(r.state)
	assert_eq(GameState.tier, 3)
	assert_eq(SaveCodec.validate(GameState.to_dict(), Balance.data), "")
