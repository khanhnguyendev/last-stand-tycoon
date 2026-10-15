extends GutTest
## E8 Task 2 (spec 3.1, D-313.2, D-314.14): the ON, OFF and NEUTRAL bench rules as pure functions on synthetic results.
## No simulation runs here; the bench applies these to real runs.

func _r(diner := 0.0, stands := 100.0, hares := 0, fence_left := 0.0, clear := 100.0) -> Dictionary:
	return {"diner_lost": diner, "fence_stands_s": stands, "hares_in_zone": hares, "fence_hp_left": fence_left, "clear_s": clear}

func before_each() -> void:
	Balance.reset()

func test_margins_are_the_fixed_e8_values() -> void:
	var b: BranchBalance = Balance.data.branches
	assert_eq(b.bench_m_on, 0.15)
	assert_eq(b.bench_m_off, 0.10)
	assert_eq(b.bench_m_neu, 0.15)
	assert_eq(b.bench_a_floor, 20.0)

func test_beats_by_margin_default_and_explicit_margin() -> void:
	var o := [["diner_lost", false]]
	assert_true(BranchBench.beats_by_margin(_r(85.0), _r(100.0), o).ok, "default MARGIN 0.15: 85 <= 85")
	assert_false(BranchBench.beats_by_margin(_r(90.0), _r(100.0), o).ok)
	assert_true(BranchBench.beats_by_margin(_r(90.0), _r(100.0), o, 0.10).ok, "explicit 0.10: 90 <= 90")
	assert_false(BranchBench.beats_by_margin(_r(91.0), _r(100.0), o, 0.10).ok)

# ---- ON ----
func test_on_longbow_siege() -> void:
	var o: Array = BranchBench.ORDER_SIEGE_TOWER
	var refs := [_r(200.0), _r(150.0)]
	var ok := BranchBench.on_rule(_r(80.0), refs, o)
	assert_true(ok.ok)
	assert_almost_eq(float(ok.bound), 127.5, 0.001, "0.85 x min(200, 150)")
	assert_false(BranchBench.on_rule(_r(130.0), refs, o).ok)

func test_on_uses_the_better_reference_whatever_the_order() -> void:
	var o: Array = BranchBench.ORDER_SIEGE_TOWER
	assert_almost_eq(float(BranchBench.on_rule(_r(80.0), [_r(150.0), _r(200.0)], o).bound), 127.5, 0.001)

func test_on_longbow_zero_tie_without_a_tiebreaker_fails() -> void:
	var o: Array = BranchBench.ORDER_SIEGE_TOWER
	assert_false(BranchBench.on_rule(_r(0.0, 100.0, 0, 50.0), [_r(0.0, 100.0, 0, 50.0), _r(0.0, 100.0, 0, 50.0)], o).ok, "0 == 0 and nothing separates")

func test_on_tie_on_primary_passes_when_a_tiebreaker_separates_in_favour() -> void:
	var o: Array = BranchBench.ORDER_SIEGE_TOWER
	var spec := _r(0.0, 100.0, 0, 400.0)
	var refs := [_r(0.0, 100.0, 0, 100.0), _r(0.0, 100.0, 0, 100.0)]
	var v := BranchBench.on_rule(spec, refs, o)
	assert_true(v.ok, v.why)
	assert_eq(v.measure, "fence_hp_left")

func test_on_tie_on_primary_fails_when_the_tiebreaker_is_against() -> void:
	var o: Array = BranchBench.ORDER_SIEGE_TOWER
	assert_false(BranchBench.on_rule(_r(0.0, 100.0, 0, 50.0), [_r(0.0, 100.0, 0, 400.0), _r(0.0, 100.0, 0, 400.0)], o).ok)

func test_on_stone_stands() -> void:
	var o: Array = BranchBench.ORDER_STONE_ON
	var refs := [_r(0.0, 30.0), _r(0.0, 40.0)]
	var v := BranchBench.on_rule(_r(0.0, 70.0), refs, o)
	assert_true(v.ok)
	assert_almost_eq(float(v.bound), 46.0, 0.001, "1.15 x max(30, 40)")
	assert_false(BranchBench.on_rule(_r(0.0, 45.0), refs, o).ok)

func test_on_stone_inf_against_inf_fails_with_diner_lost_pinned_equal() -> void:
	var o: Array = BranchBench.ORDER_STONE_ON
	var inf := INF
	assert_false(BranchBench.on_rule(_r(100.0, inf), [_r(100.0, inf), _r(100.0, inf)], o).ok)

func test_on_stone_inf_against_finite_passes() -> void:
	assert_true(BranchBench.on_rule(_r(0.0, INF), [_r(0.0, 30.0), _r(0.0, 40.0)], BranchBench.ORDER_STONE_ON).ok)

func test_on_spike_hares_in_zone_with_tiebreaker() -> void:
	var o: Array = BranchBench.ORDER_SPIKE_ON
	var refs := [_r(0.0, 0.0, 20), _r(0.0, 0.0, 12)]
	assert_true(BranchBench.on_rule(_r(0.0, 0.0, 10), refs, o).ok, "10 <= 0.85 x 12 = 10.2")
	assert_false(BranchBench.on_rule(_r(0.0, 0.0, 11), refs, o).ok)
	# primary ties; diner lost (the first tie-breaker) separates in Spike's favour
	assert_true(BranchBench.on_rule(_r(10.0, 0.0, 12), [_r(100.0, 0.0, 12), _r(100.0, 0.0, 12)], o).ok)

func test_on_reference_is_chosen_over_the_whole_order() -> void:
	# the primary measure ties between the two references; Volley is stronger on the tie-breaker
	assert_false(BranchBench.on_rule(_r(0.0, 100.0, 0, 150.0), [_r(0.0, 100.0, 0, 100.0), _r(0.0, 100.0, 0, 400.0)], BranchBench.ORDER_SIEGE_TOWER).ok)

func test_stone_on_fence_hp_left_is_a_tiebreaker() -> void:
	var o: Array = BranchBench.ORDER_STONE_ON
	assert_true(BranchBench.on_rule(_r(5.0, INF, 0, 400.0), [_r(5.0, INF), _r(5.0, INF)], o).ok)

# ---- OFF ----
func test_off_longbow_hare() -> void:
	var u := _r(1000.0)
	var v := BranchBench.off_rule(_r(1200.0), u, "diner_lost", false)
	assert_true(v.ok)
	assert_almost_eq(float(v.bound), 1120.0, 0.001, "1.1 x 1000 + 20")
	assert_false(BranchBench.off_rule(_r(1100.0), u, "diner_lost", false).ok)
	assert_false(BranchBench.off_rule(_r(0.0), _r(0.0), "diner_lost", false).ok, "0 against 0")

func test_off_spike_siege_stands() -> void:
	var u := _r(0.0, 30.0)
	var v := BranchBench.off_rule(_r(0.0, 20.0), u, "fence_stands_s", true)
	assert_true(v.ok)
	assert_almost_eq(float(v.bound), 27.0, 0.001, "0.9 x 30")
	assert_false(BranchBench.off_rule(_r(0.0, 28.0), u, "fence_stands_s", true).ok)
	assert_false(BranchBench.off_rule(_r(0.0, INF), _r(0.0, INF), "fence_stands_s", true).ok, "INF against INF")
	assert_false(BranchBench.off_rule(_r(0.0, 0.0), _r(0.0, 0.0), "fence_stands_s", true).ok, "0 against 0")

func test_off_spike_stands_inf_against_finite_fails() -> void:
	assert_false(BranchBench.off_rule(_r(0.0, INF), _r(0.0, 30.0), "fence_stands_s", true).ok)

# ---- NEUTRAL ----
func test_neutral() -> void:
	var u := _r(560.0)
	var v := BranchBench.neutral_rule(_r(600.0), u)
	assert_true(v.ok)
	assert_almost_eq(float(v.bound), 664.0, 0.001, "1.15 x 560 + 20")
	assert_false(BranchBench.neutral_rule(_r(700.0), u).ok)
	assert_true(BranchBench.neutral_rule(_r(0.0), _r(0.0)).ok, "0 against 0 passes: one-sided")
	assert_true(BranchBench.neutral_rule(_r(0.0), u).ok, "far better passes")

# ---- RULES ----
func test_rules_table_is_the_eleven_rows_of_spec_3_1() -> void:
	var expected: Array = [
		[&"ON", &"longbow", &"siege", "diner_lost", false, ["-/-", "volley/-"], [["diner_lost", false], ["fence_hp_left", true]]],
		[&"ON", &"volley", &"hare", "diner_lost", false, ["-/-", "longbow/-"], [["diner_lost", false], ["hares_in_zone", false], ["clear_s", false]]],
		[&"ON", &"stone", &"siege", "fence_stands_s", true, ["-/-", "-/spike"], [["fence_stands_s", true], ["diner_lost", false], ["fence_hp_left", true]]],
		[&"ON", &"spike", &"hare", "hares_in_zone", false, ["-/-", "-/stone"], [["hares_in_zone", false], ["diner_lost", false], ["clear_s", false]]],
		[&"OFF", &"longbow", &"hare", "diner_lost", false, ["-/-"], []],
		[&"OFF", &"volley", &"siege", "diner_lost", false, ["-/-"], []],
		[&"OFF", &"spike", &"siege", "fence_stands_s", true, ["-/-"], []],
		[&"NEUTRAL", &"longbow", &"neutral", "diner_lost", false, ["-/-"], []],
		[&"NEUTRAL", &"volley", &"neutral", "diner_lost", false, ["-/-"], []],
		[&"NEUTRAL", &"stone", &"neutral", "diner_lost", false, ["-/-"], []],
		[&"NEUTRAL", &"spike", &"neutral", "diner_lost", false, ["-/-"], []],
	]
	assert_eq(BranchBench.RULES, expected)
