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

## The lanes as the pre-E5 planner drew them (one main draw per wave, one side draw from day 2): an oracle independent of LanePlanner.
func _lanes_before_e5(run_seed: int, day: int) -> Array:
	var rng := Rng.stream(run_seed, day, &"lane_plan")
	var out := []
	for w in wb.base_counts.size():
		var main: String = "north" if day == 1 and w == 0 else LanePlanner.LANES[rng.randi_range(0, LanePlanner.LANES.size() - 1)]
		var side := ""
		if day >= 2:
			var others: Array = LanePlanner.LANES.filter(func(l): return l != main)
			side = others[rng.randi_range(0, others.size() - 1)]
		out.append([main, side])
	return out

func test_oracle_reproduces_the_golden() -> void:
	assert_eq(_lanes_before_e5(555, 4), [["north", "east"], ["west", "north"], ["east", "west"]])

func test_tier1_plan_has_no_hares_and_no_boss_and_is_todays() -> void:
	var tb := Balance.data.tiers
	for day in range(1, 8):
		var p := LanePlanner.plan(555, day, wb, 1, 1, tb)
		var lanes := _lanes_before_e5(555, day)
		for w in 3:
			assert_eq([p[w].main, p[w].side], lanes[w], "day %d wave %d lanes" % [day, w])
			var s := WaveMath.split(day, w, wb)
			assert_eq([p[w].main_count, p[w].side_count], [int(s.main), int(s.side)], "day %d wave %d counts" % [day, w])
			assert_almost_eq(float(p[w].hp_mult), WaveMath.hp_mult(day, w, wb), 1e-9)
			assert_eq([p[w].fast_main, p[w].fast_side, p[w].boss], [0, 0, false])

func test_tier1_day8_is_day7_pressure_with_day8_lanes() -> void:
	var tb := Balance.data.tiers
	var p8 := LanePlanner.plan(555, 8, wb, 1, 1, tb)
	var p7 := LanePlanner.plan(555, 7, wb, 1, 1, tb)
	for w in 3:
		assert_eq([p8[w].main_count, p8[w].side_count, p8[w].hp_mult], [p7[w].main_count, p7[w].side_count, p7[w].hp_mult], "wave %d counts at the cap" % w)

func test_lanes_match_the_pre_e5_oracle_at_every_tier() -> void:
	var tb := Balance.data.tiers
	var cases := [[1, 1, 1], [2, 1, 1], [7, 1, 1], [8, 1, 1], [14, 1, 1], [9, 2, 9], [12, 2, 9]]
	for c in cases:
		var p := LanePlanner.plan(555, c[0], wb, c[1], c[2], tb)
		var got := p.map(func(w): return [w.main, w.side])
		assert_eq(got, _lanes_before_e5(555, c[0]), "day %d tier %d lanes" % [c[0], c[1]])

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
	var src := LanePlanner.plan(555, 7, wb, 1, 1, Balance.data.tiers)
	var p := LanePlanner.with_boss(src)
	assert_eq(p.map(func(w): return w.boss), [false, false, true])
	assert_eq(src.map(func(w): return w.boss), [false, false, false], "with_boss returns a copy")

func test_threat_counts_hares_and_the_boss() -> void:
	var tb := Balance.data.tiers
	var plain := LanePlanner.threat_by_lane(LanePlanner.plan(555, 7, wb, 1, 1, tb), Balance.data.enemy.hp)
	var boss := LanePlanner.threat_by_lane(LanePlanner.with_boss(LanePlanner.plan(555, 7, wb, 1, 1, tb)), Balance.data.enemy.hp)
	var lane: String = LanePlanner.plan(555, 7, wb, 1, 1, tb)[2].main
	assert_gt(boss[lane], plain[lane], "the boss raises its lane's threat")

# ---- E5 tier 3, Task 6: four lanes, brutes, compositions ----

const FIXTURE := "res://tests/fixtures/plans_tier12.json"
const OLD_KEYS := ["main", "side", "main_count", "side_count", "hp_mult", "fast_main", "fast_side", "boss"]

func _fixture() -> Dictionary:
	var f := FileAccess.open(FIXTURE, FileAccess.READ)
	assert_not_null(f, "fixture exists")
	return JSON.parse_string(f.get_as_text())

## The oracle is the committed JSON, captured from the code BEFORE this task (tools/make_plans_fixture.gd).
func test_tier1_and_2_plans_equal_the_pre_task_fixture() -> void:
	var fx: Dictionary = _fixture()["plans"]
	assert_eq(fx.size(), 84)
	var tb := Balance.data.tiers
	for key in fx:
		var parts: PackedStringArray = String(key).split(":")
		var tier := int(parts[1])
		var p := LanePlanner.plan(int(parts[0]), int(parts[2]), wb, tier, 1 if tier == 1 else 8, tb)
		var want: Array = fx[key]
		assert_eq(p.size(), want.size(), key)
		for w in want.size():
			for k in OLD_KEYS:
				if k == "hp_mult":
					assert_almost_eq(float(p[w][k]), float(want[w][k]), 1e-9, "%s wave %d hp_mult" % [key, w])
				elif k in ["main", "side"]:
					assert_eq(p[w][k], want[w][k], "%s wave %d %s" % [key, w, k])
				elif k == "boss":
					assert_eq(p[w][k], want[w][k], "%s wave %d boss" % [key, w])
				else:
					assert_eq(int(p[w][k]), int(want[w][k]), "%s wave %d %s" % [key, w, k])
			assert_eq([p[w].get("brute_main", 0), p[w].get("brute_side", 0)], [0, 0], "%s wave %d no brutes below tier 3" % [key, w])
			assert_eq(p[w].keys().size(), OLD_KEYS.size(), "%s wave %d: the same keys as before" % [key, w])

func test_lanes_for_tier() -> void:
	assert_eq(LanePlanner.LANES, ["west", "north", "east"] as Array[String])
	for t in [1, 2]:
		assert_eq(LanePlanner.lanes_for_tier(t), LanePlanner.LANES)
	assert_eq(LanePlanner.lanes_for_tier(3), ["west", "north", "east", "sw"] as Array[String])
	assert_eq(LanePlanner.lanes_for_tier(4), ["west", "north", "east", "sw"] as Array[String])

func test_tier3_plan_uses_four_lanes_and_no_other_stream() -> void:
	var tb := Balance.data.tiers
	var names: Array[StringName] = [&"spawns", &"travelers", &"drops", &"cards"]
	var seen := {}
	var main_seen := {}
	for seed in range(1, 60):
		for day in [22, 23, 26]:
			var before := {}
			for n in names:
				var r := Rng.stream(seed, day, n)
				before[n] = [r.randi(), r.randi(), r.randi()]
			var p := LanePlanner.plan(seed, day, wb, 3, 22, tb)
			for n in names:
				var r := Rng.stream(seed, day, n)
				assert_eq([r.randi(), r.randi(), r.randi()], before[n], "stream %s unchanged (seed %d day %d)" % [n, seed, day])
			for w in p:
				assert_true(w.main in LanePlanner.lanes_for_tier(3))
				assert_ne(w.side, w.main)
				main_seen[w.main] = true
				seen[w.main] = true
				if w.side != "":
					assert_true(w.side in LanePlanner.lanes_for_tier(3))
					seen[w.side] = true
	assert_eq(seen.size(), 4, "sw and the three old lanes all appear")
	assert_true(main_seen.has("sw"))

## The lane_plan stream is consumed with the same call pattern: one main draw per wave, one side draw when it has one.
func test_tier3_lanes_follow_the_four_lane_oracle() -> void:
	var lanes := ["west", "north", "east", "sw"]
	var tb := Balance.data.tiers
	for seed in range(1, 21):
		for day in range(22, 27):
			var p := LanePlanner.plan(seed, day, wb, 3, 22, tb)
			var rng := Rng.stream(seed, day, &"lane_plan")
			for w in p.size():
				var main: String = lanes[rng.randi_range(0, 3)]
				var others: Array = lanes.filter(func(l): return l != main)
				var side: String = others[rng.randi_range(0, others.size() - 1)]
				assert_eq([p[w].main, p[w].side], [main, side], "seed %d day %d wave %d" % [seed, day, w])

## Brute rule (doc comment of TierEffects.brute_counts): d = day - tier_day; the last d + 1 waves carry the cap on their
## main lane until d reaches brute_ramp_days; from then on every wave does, and side lanes get brute_cap_side.
func test_brute_counts_every_day_of_the_ramp() -> void:
	var tb := Balance.data.tiers
	assert_eq([tb.brute_cap_main[3], tb.brute_cap_side[3], tb.brute_ramp_days[3]], [1, 1, 3])
	var main_by_day := {
		22: [0, 0, 1], 23: [0, 1, 1], 24: [1, 1, 1], 25: [1, 1, 1], 30: [1, 1, 1],
	}
	var side_by_day := {22: [0, 0, 0], 23: [0, 0, 0], 24: [0, 0, 0], 25: [1, 1, 1], 30: [1, 1, 1]}
	for day in main_by_day:
		for w in 3:
			var c := TierEffects.brute_counts(day, 3, 22, w, 3, true, tb)
			assert_eq([c.main, c.side], [main_by_day[day][w], side_by_day[day][w]], "day %d wave %d" % [day, w])
			var no_side := TierEffects.brute_counts(day, 3, 22, w, 3, false, tb)
			assert_eq([no_side.main, no_side.side], [main_by_day[day][w], 0], "day %d wave %d without a side lane" % [day, w])

func test_brute_counts_are_zero_below_tier_3() -> void:
	# Non-zero caps at tiers 1 and 2: only the `tier < 3` gate keeps them at zero (mutation: dropping the gate fails this).
	var tb: TierBalance = Balance.data.tiers.duplicate()
	tb.brute_cap_main.assign([0, 4, 4, 1])
	tb.brute_cap_side.assign([0, 3, 3, 1])
	tb.brute_ramp_days.assign([0, 1, 1, 3])
	for tier in [1, 2]:
		for day in range(1, 25):
			for w in 3:
				assert_eq(TierEffects.brute_counts(day, tier, 1, w, 3, true, tb), {"main": 0, "side": 0})
	assert_eq(TierEffects.brute_counts(30, 3, 22, 0, 3, true, tb), {"main": 1, "side": 1}, "the gate opens at tier 3")

func test_tier3_plan_first_night_has_one_brute_on_the_last_main_lane() -> void:
	var tb := Balance.data.tiers
	for seed in [1, 2, 3, 555, 20260930]:
		var p := LanePlanner.plan(seed, 22, wb, 3, 22, tb)
		var total := 0
		for w in p.size():
			total += int(p[w].brute_main) + int(p[w].brute_side)
		assert_eq(total, 1)
		assert_eq([p[0].brute_main, p[1].brute_main, p[2].brute_main], [0, 0, 1])
		assert_eq([p[0].brute_side, p[1].brute_side, p[2].brute_side], [0, 0, 0])
		var full := LanePlanner.plan(seed, 25, wb, 3, 22, tb)
		for w in full.size():
			assert_eq([full[w].brute_main, full[w].brute_side], [1, 1 if full[w].side != "" else 0])
			# brutes are added, not taken out of the groups
			var s := WaveMath.split(WaveMath.pressure(25, 3, 22, tb), w, wb)
			assert_eq([full[w].main_count, full[w].side_count], [int(s.main), int(s.side)])

func test_threat_keys_per_tier_and_brute_hp() -> void:
	var tb := Balance.data.tiers
	var t12 := LanePlanner.threat_by_lane(LanePlanner.plan(555, 7, wb, 1, 1, tb), 30.0)
	assert_eq(t12.keys(), ["west", "north", "east"])
	var plan := [
		{"main": "sw", "side": "west", "main_count": 2, "side_count": 1, "hp_mult": 2.0, "brute_main": 1, "brute_side": 1},
		{"main": "north", "side": "", "main_count": 1, "side_count": 0, "hp_mult": 1.0},
	]
	var bhp: float = Balance.data.monsters.stats(&"brute").hp
	var t := LanePlanner.threat_by_lane(plan, 30.0, 3)
	assert_eq(t.keys().size(), 4)
	assert_almost_eq(float(t.sw), 2 * 60.0 + bhp * 2.0, 0.001)
	assert_almost_eq(float(t.west), 60.0 + bhp * 2.0, 0.001)
	assert_almost_eq(float(t.north), 30.0, 0.001)
	assert_almost_eq(float(t.east), 0.0, 0.001)

func test_composition_by_lane_sums_equal_the_counts() -> void:
	var tb := Balance.data.tiers
	var p := LanePlanner.with_boss(LanePlanner.plan(555, 25, wb, 3, 22, tb))
	var comp := LanePlanner.composition_by_lane(p, 3)
	assert_eq(comp.keys(), ["west", "north", "east", "sw"])
	var want := {"west": [0, 0, 0, 0], "north": [0, 0, 0, 0], "east": [0, 0, 0, 0], "sw": [0, 0, 0, 0]}
	for w in p:
		var m: Array = want[w.main]
		m[0] += int(w.main_count) - int(w.fast_main)
		m[1] += int(w.fast_main)
		m[2] += int(w.brute_main)
		if bool(w.boss):
			m[3] += 1
		if w.side != "":
			var s: Array = want[w.side]
			s[0] += int(w.side_count) - int(w.fast_side)
			s[1] += int(w.fast_side)
			s[2] += int(w.brute_side)
	for lane in comp:
		assert_eq([comp[lane].boar, comp[lane].hare, comp[lane].brute, comp[lane].boss], want[lane], lane)
	var grand := 0
	for lane in comp:
		grand += int(comp[lane].boar) + int(comp[lane].hare) + int(comp[lane].brute) + int(comp[lane].boss)
	var expected := 1
	for w in p:
		expected += int(w.main_count) + int(w.side_count) + int(w.brute_main) + int(w.brute_side)
	assert_eq(grand, expected)
	assert_eq(LanePlanner.composition_by_lane(LanePlanner.plan(555, 7, wb, 1, 1, tb)).keys(), ["west", "north", "east"], "default tier 1: three lanes")

## A hand-written two-wave tier-3 plan: wave 0 is west 5 (2 hares, 1 brute) + north 3 (1 hare, 1 brute); wave 1 is sw 4 with the boss.
func test_composition_by_lane_of_a_hand_written_plan() -> void:
	var plan := [
		{"main": "west", "side": "north", "main_count": 5, "side_count": 3, "hp_mult": 1.0, "fast_main": 2, "fast_side": 1, "brute_main": 1, "brute_side": 1, "boss": false},
		{"main": "sw", "side": "", "main_count": 4, "side_count": 0, "hp_mult": 1.0, "fast_main": 0, "fast_side": 0, "brute_main": 0, "brute_side": 0, "boss": true},
	]
	assert_eq(LanePlanner.composition_by_lane(plan, 3), {
		"west": {"boar": 3, "hare": 2, "brute": 1, "boss": 0},
		"north": {"boar": 2, "hare": 1, "brute": 1, "boss": 0},
		"east": {"boar": 0, "hare": 0, "brute": 0, "boss": 0},
		"sw": {"boar": 4, "hare": 0, "brute": 0, "boss": 1},
	})

## One lane_plan stream draw site in the planner, none in TierEffects (brutes are deterministic: no extra RNG consumption).
func test_only_the_planner_draws_from_the_lane_plan_stream() -> void:
	var planner := FileAccess.get_file_as_string("res://core/lane_planner.gd")
	var effects := FileAccess.get_file_as_string("res://core/tier_effects.gd")
	assert_eq(planner.count("Rng.stream("), 1)
	assert_eq(effects.count("Rng.stream("), 0)
