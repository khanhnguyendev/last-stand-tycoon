extends GutTest

var wb: WaveBalance

func before_each() -> void:
	Balance.reset()
	wb = Balance.data.wave

func test_main_only_schedule() -> void:
	var s := WaveSchedule.build({"main": "north", "side": "", "main_count": 3, "side_count": 0, "hp_mult": 1.0}, wb)
	assert_eq(s.size(), 3)
	assert_almost_eq(float(s[0].t), 0.0, 0.0001)
	assert_almost_eq(float(s[1].t), wb.spawn_interval, 0.0001)
	assert_almost_eq(float(s[2].t), 2.0 * wb.spawn_interval, 0.0001)
	for e in s:
		assert_eq(e.lane, "north")
		assert_false(e.side)

func test_side_group_starts_after_delay() -> void:
	var s := WaveSchedule.build({"main": "west", "side": "east", "main_count": 2, "side_count": 2, "hp_mult": 1.0}, wb)
	var side_times: Array = s.filter(func(e): return e.side).map(func(e): return e.t)
	assert_almost_eq(float(side_times[0]), wb.side_group_delay, 0.0001)
	assert_almost_eq(float(side_times[1]), wb.side_group_delay + wb.spawn_interval, 0.0001)
	for i in range(1, s.size()):
		assert_true(s[i - 1].t <= s[i].t, "sorted by time")

func test_clear_rule_requires_all_spawned() -> void:
	# D-044: main group dead before the side group spawns is NOT a clear.
	assert_false(WaveSchedule.is_cleared(6, 4, 0))
	assert_false(WaveSchedule.is_cleared(6, 6, 1))
	assert_true(WaveSchedule.is_cleared(6, 6, 0))

func test_main_first_on_ties() -> void:
	var n := int(ceil(wb.side_group_delay / wb.spawn_interval)) + 4
	var s := WaveSchedule.build({"main": "west", "side": "east", "main_count": n, "side_count": 3, "hp_mult": 1.0}, wb)
	for i in range(1, s.size()):
		assert_true(float(s[i - 1].t) <= float(s[i].t) + 1e-6, "sorted")
		if is_equal_approx(float(s[i - 1].t), float(s[i].t)):
			assert_false(s[i - 1].side and not s[i].side, "main first on tie at %s" % s[i].t)

func _wave(main_n: int, side_n: int, fast_main := 0, fast_side := 0, boss := false) -> Dictionary:
	return {"main": "west", "side": "east" if side_n > 0 else "", "main_count": main_n, "side_count": side_n, "hp_mult": 1.0,
		"fast_main": fast_main, "fast_side": fast_side, "boss": boss}

func test_legacy_wave_without_the_new_keys_is_all_boars() -> void:
	var s := WaveSchedule.build({"main": "north", "side": "", "main_count": 2, "side_count": 0, "hp_mult": 1.0}, wb)
	assert_eq(s.map(func(e): return e.kind), [&"boar", &"boar"])

func test_hares_are_the_last_of_each_group() -> void:
	var s := WaveSchedule.build(_wave(4, 3, 2, 1), wb, Balance.data.tiers)
	var main_kinds: Array = s.filter(func(e): return not e.side).map(func(e): return e.kind)
	var side_kinds: Array = s.filter(func(e): return e.side).map(func(e): return e.kind)
	assert_eq(main_kinds, [&"boar", &"boar", &"hare", &"hare"])
	assert_eq(side_kinds, [&"boar", &"boar", &"hare"])

func test_boss_spawns_first_and_shifts_the_rest() -> void:
	var tb := Balance.data.tiers
	var s := WaveSchedule.build(_wave(3, 2, 0, 0, true), wb, tb)
	assert_eq(s.size(), 6)
	assert_eq(s[0].kind, &"boss")
	assert_almost_eq(float(s[0].t), 0.0, 1e-6)
	assert_eq(s[0].lane, "west")
	assert_false(s[0].side)
	assert_almost_eq(float(s[1].t), tb.boss_lead, 1e-6)
	var side_times: Array = s.filter(func(e): return e.side).map(func(e): return float(e.t))
	assert_almost_eq(side_times[0], tb.boss_lead + wb.side_group_delay, 1e-6)

func test_tier1_schedule_is_unchanged() -> void:
	var old := WaveSchedule.build({"main": "west", "side": "east", "main_count": 5, "side_count": 2, "hp_mult": 1.0}, wb)
	var now := WaveSchedule.build(_wave(5, 2), wb, Balance.data.tiers)
	for i in old.size():
		assert_eq([old[i].t, old[i].lane, old[i].side], [now[i].t, now[i].lane, now[i].side])

# ---- E5 tier 3, Task 6 ----

func test_schedules_without_brutes_equal_the_pre_task_fixture() -> void:
	var f := FileAccess.open("res://tests/fixtures/plans_tier12.json", FileAccess.READ)
	var fx: Dictionary = JSON.parse_string(f.get_as_text())["schedules"]
	var tb := Balance.data.tiers
	for k in fx:
		var c: Dictionary = fx[k]
		var p := LanePlanner.plan(int(c.seed), int(c.day), wb, int(c.tier), int(c.tier_day), tb)
		for w in p.size():
			var got := WaveSchedule.build(p[w], wb, tb)
			var want: Array = c.waves[w]
			assert_eq(got.size(), want.size(), "%s wave %d" % [k, w])
			for i in want.size():
				assert_almost_eq(float(got[i].t), float(want[i].t), 1e-9)
				assert_eq([got[i].lane, got[i].side, String(got[i].kind)], [want[i].lane, want[i].side, want[i].kind], "%s wave %d entry %d" % [k, w, i])

func test_brutes_spawn_after_their_group_with_the_same_spacing() -> void:
	var w := _wave(3, 2, 1, 0)
	w["brute_main"] = 1
	w["brute_side"] = 2
	var s := WaveSchedule.build(w, wb, Balance.data.tiers)
	assert_eq(s.size(), 3 + 1 + 2 + 2)
	var main: Array = s.filter(func(e): return not e.side)
	var side: Array = s.filter(func(e): return e.side)
	assert_eq(main.map(func(e): return e.kind), [&"boar", &"boar", &"hare", &"brute"])
	assert_eq(side.map(func(e): return e.kind), [&"boar", &"boar", &"brute", &"brute"])
	assert_almost_eq(float(main[3].t), 3.0 * wb.spawn_interval, 1e-6)
	assert_eq(main[3].lane, "west")
	assert_almost_eq(float(side[2].t), wb.side_group_delay + 2.0 * wb.spawn_interval, 1e-6)
	assert_almost_eq(float(side[3].t), wb.side_group_delay + 3.0 * wb.spawn_interval, 1e-6)
	assert_eq(side[3].lane, "east")
	for i in range(1, s.size()):
		assert_true(float(s[i - 1].t) <= float(s[i].t) + 1e-6, "sorted")

func test_brutes_shift_with_the_boss_lead() -> void:
	var tb := Balance.data.tiers
	var w := _wave(2, 0, 0, 0, true)
	w["brute_main"] = 1
	var s := WaveSchedule.build(w, wb, tb)
	assert_eq(s.map(func(e): return e.kind), [&"boss", &"boar", &"boar", &"brute"])
	assert_almost_eq(float(s[3].t), tb.boss_lead + 2.0 * wb.spawn_interval, 1e-6)
