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
