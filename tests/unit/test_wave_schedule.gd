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
