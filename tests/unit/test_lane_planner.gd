extends GutTest

var wb: WaveBalance

func before_each() -> void:
	Balance.reset()
	wb = Balance.data.wave

func test_day1_single_lane_and_wave0_north() -> void:
	for seed in [1, 2, 3, 99, 12345]:
		var p := LanePlanner.plan(seed, 1, wb)
		assert_eq(p.size(), wb.base_counts.size())
		assert_eq(p[0].main, "north", "D-095")
		for w in p:
			assert_eq(w.side, "")
			assert_eq(w.side_count, 0)

func test_day2_plus_main_differs_from_side() -> void:
	for seed in range(1, 40):
		for day in [2, 3, 6]:
			for w in LanePlanner.plan(seed, day, wb):
				assert_ne(w.side, "")
				assert_ne(w.main, w.side)
				assert_true(w.main in LanePlanner.LANES)
				assert_true(w.side in LanePlanner.LANES)

func test_counts_match_wave_math() -> void:
	var p := LanePlanner.plan(7, 2, wb)
	for w in p.size():
		var s := WaveMath.split(2, w, wb)
		assert_eq([p[w].main_count, p[w].side_count], [int(s.main), int(s.side)])
		assert_almost_eq(float(p[w].hp_mult), WaveMath.hp_mult(2, w, wb), 0.0001)

func test_all_lanes_and_pairs_reachable() -> void:
	var mains := {}
	var pairs := {}
	var d1 := {}
	for seed in range(1, 200):
		for w in LanePlanner.plan(seed, 2, wb):
			mains[w.main] = true
			pairs[str(w.main, ">", w.side)] = true
		var p1 := LanePlanner.plan(seed, 1, wb)
		for i in range(1, p1.size()):
			d1[p1[i].main] = true
	assert_eq(mains.size(), LanePlanner.LANES.size())
	assert_eq(pairs.size(), 6)
	assert_eq(d1.size(), LanePlanner.LANES.size())

## Golden draw order (captured from GODOT_TAG 4.7.2-stable). A change means the Rng draw order changed: escalate.
func test_plan_golden() -> void:
	var got := []
	for w in LanePlanner.plan(555, 4, wb):
		got.append([w.main, w.side])
	assert_eq(got, [["north", "east"], ["west", "north"], ["east", "west"]])

func test_same_seed_same_plan() -> void:
	assert_eq(LanePlanner.plan(555, 4, wb), LanePlanner.plan(555, 4, wb))

func test_plan_varies_across_seeds() -> void:
	var seen := {}
	for seed in range(1, 30):
		seen[str(LanePlanner.plan(seed, 3, wb))] = true
	assert_gt(seen.size(), 5)

func test_threat_and_marker_scale() -> void:
	var plan := [
		{"main": "north", "side": "west", "main_count": 4, "side_count": 1, "hp_mult": 1.0},
		{"main": "north", "side": "", "main_count": 2, "side_count": 0, "hp_mult": 2.0},
		{"main": "east", "side": "west", "main_count": 1, "side_count": 1, "hp_mult": 1.0},
	]
	var t := LanePlanner.threat_by_lane(plan, 30.0)
	assert_almost_eq(float(t.north), 4 * 30.0 + 2 * 60.0, 0.001)
	assert_almost_eq(float(t.west), 60.0, 0.001)
	assert_almost_eq(float(t.east), 30.0, 0.001)
	assert_eq(LanePlanner.marker_scale(0.0, 240.0, 0.5, 2.0), 0.0)
	assert_almost_eq(LanePlanner.marker_scale(240.0, 240.0, 0.5, 2.0), 2.0, 0.0001)
	assert_almost_eq(LanePlanner.marker_scale(120.0, 240.0, 0.5, 2.0), 1.25, 0.0001)
	assert_eq(LanePlanner.marker_scale(50.0, 0.0, 0.5, 2.0), 0.0)
	assert_almost_eq(LanePlanner.marker_scale(480.0, 240.0, 0.5, 2.0), 2.0, 0.0001)

func test_tier1_plan_has_no_hares_and_no_boss_and_is_todays() -> void:
	var tb := Balance.data.tiers
	for day in [1, 2, 5, 7]:
		var p := LanePlanner.plan(555, day, wb, 1, 1, tb)
		var old := LanePlanner.plan(555, day, wb)
		for w in 3:
			for k in ["main", "side", "main_count", "side_count", "hp_mult"]:
				assert_eq(p[w][k], old[w][k], "day %d wave %d %s" % [day, w, k])
			assert_eq([p[w].fast_main, p[w].fast_side, p[w].boss], [0, 0, false])

func test_tier1_day8_is_day7_pressure_with_day8_lanes() -> void:
	var tb := Balance.data.tiers
	var p8 := LanePlanner.plan(555, 8, wb, 1, 1, tb)
	var p7 := LanePlanner.plan(555, 7, wb, 1, 1, tb)
	for w in 3:
		assert_eq([p8[w].main_count, p8[w].side_count, p8[w].hp_mult], [p7[w].main_count, p7[w].side_count, p7[w].hp_mult], "wave %d counts at the cap" % w)
	# lanes still come from the day-8 stream (a save keeps its own lane_plan stream per day)
	var lanes8 := p8.map(func(w): return [w.main, w.side])
	var old8 := LanePlanner.plan(555, 8, wb).map(func(w): return [w.main, w.side])
	assert_eq(lanes8, old8)

func test_tier2_hares_ramp_and_fit_in_the_groups() -> void:
	var tb := Balance.data.tiers
	var first := LanePlanner.plan(555, 9, wb, 2, 9, tb)
	var later := LanePlanner.plan(555, 12, wb, 2, 9, tb)
	var total_first := 0
	var total_later := 0
	for w in 3:
		for p in [first[w], later[w]]:
			assert_lte(int(p.fast_main), int(p.main_count))
			assert_lte(int(p.fast_side), int(p.side_count))
		total_first += int(first[w].fast_main) + int(first[w].fast_side)
		total_later += int(later[w].fast_main) + int(later[w].fast_side)
	assert_gt(total_first, 0, "hares on the first tier-2 night")
	assert_gt(total_later, total_first, "more hares at the cap")
	var expect := TierEffects.fast_counts(int(first[0].main_count), int(first[0].side_count), TierEffects.fast_share_now(9, 2, 9, tb))
	assert_eq([first[0].fast_main, first[0].fast_side], [expect.fast_main, expect.fast_side])

func test_with_boss_marks_only_the_last_wave() -> void:
	var p := LanePlanner.with_boss(LanePlanner.plan(555, 7, wb, 1, 1, Balance.data.tiers))
	assert_eq(p.map(func(w): return w.boss), [false, false, true])
	var again := LanePlanner.plan(555, 7, wb, 1, 1, Balance.data.tiers)
	assert_false(bool(again[2].boss), "with_boss returns a copy")

func test_threat_counts_hares_and_the_boss() -> void:
	var tb := Balance.data.tiers
	var plain := LanePlanner.threat_by_lane(LanePlanner.plan(555, 7, wb, 1, 1, tb), Balance.data.enemy.hp)
	var boss := LanePlanner.threat_by_lane(LanePlanner.with_boss(LanePlanner.plan(555, 7, wb, 1, 1, tb)), Balance.data.enemy.hp)
	var lane: String = LanePlanner.plan(555, 7, wb, 1, 1, tb)[2].main
	assert_gt(boss[lane], plain[lane], "the boss raises its lane's threat")
