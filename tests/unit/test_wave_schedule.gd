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

## A hand-written boss wave with an extra group: every entry after the boss is shifted by boss_lead (tier 1 has a boss), the
## extra group included, so it starts at boss_lead + side_group_delay. The boss itself is at 0.
## Mutation: the extra group is scheduled without the boss lead (it would start at side_group_delay).
func test_an_extra_group_on_a_boss_wave_starts_at_boss_lead_plus_the_side_delay() -> void:
	var tb := Balance.data.tiers
	var w := _extra_wave()
	w["boss"] = true
	var s := WaveSchedule.build(w, wb, tb, 1)
	assert_eq(s[0].kind, &"boss")
	assert_almost_eq(float(s[0].t), 0.0, 1e-6)
	assert_gt(tb.boss_lead, 0.0, "setup: the lead is not zero")
	var ex: Array = s.filter(func(e): return e.get("extra", false))
	assert_eq(ex.size(), 4)
	for i in 4:
		assert_almost_eq(float(ex[i].t), tb.boss_lead + wb.side_group_delay + i * wb.spawn_interval, 1e-6, "extra %d" % i)

## The full order by hand (spawn_interval 0.8, side_group_delay 4.0): five main boars at 0, 0.8, 1.6, 2.4, 3.2; the main brute at
## 5 x 0.8 = 4.0, the same moment as the side boar (4.0 + 0), the main one first; the side brute at 4.0 + 1 x 0.8 = 4.8.
func test_the_full_spawn_order_with_a_brute_on_each_lane() -> void:
	assert_almost_eq(wb.spawn_interval, 0.8, 1e-9)
	assert_almost_eq(wb.side_group_delay, 4.0, 1e-9)
	var w := _wave(5, 1)
	w["brute_main"] = 1
	w["brute_side"] = 1
	var s := WaveSchedule.build(w, wb, Balance.data.tiers)
	var want := [
		[0.0, "west", &"boar"], [0.8, "west", &"boar"], [1.6, "west", &"boar"], [2.4, "west", &"boar"], [3.2, "west", &"boar"],
		[4.0, "west", &"brute"], [4.0, "east", &"boar"], [4.8, "east", &"brute"],
	]
	assert_eq(s.size(), want.size())
	for i in want.size():
		assert_almost_eq(float(s[i].t), float(want[i][0]), 1e-6, "entry %d time" % i)
		assert_eq([s[i].lane, s[i].kind], [want[i][1], want[i][2]], "entry %d" % i)

# --- E6 task 4: extra groups (LaneCharacter.apply, spec 3.2) -----------------------------------------------------------

func _extra_wave() -> Dictionary:
	return {"main": "west", "side": "north", "main_count": 3, "side_count": 2, "hp_mult": 1.0, "fast_main": 1, "fast_side": 0,
		"brute_main": 0, "brute_side": 1, "boss": false, "extra": [{"lane": "sw", "count": 4, "fast": 3}]}

## Mutations: the extra group is not scheduled (size and lane fail); it starts with the main group at 0 (the t check fails);
## its hares are first instead of last; the side group's entries lose their tie to the extra group.
func test_extra_group_starts_at_the_side_delay_with_hares_last() -> void:
	var s := WaveSchedule.build(_extra_wave(), wb)
	assert_eq(s.size(), 3 + 2 + 4 + 1, "main + side + extra + brutes")
	var ex: Array = s.filter(func(e): return e.lane == "sw")
	assert_eq(ex.size(), 4)
	for i in 4:
		assert_almost_eq(float(ex[i].t), wb.side_group_delay + i * wb.spawn_interval, 0.0001, "extra %d" % i)
		assert_true(ex[i].side, "extra entries are side entries (they start with the side group)")
		assert_true(ex[i].extra, "and carry the extra marker")
	assert_eq(ex.map(func(e): return e.kind), [&"boar", &"hare", &"hare", &"hare"], "the last fast entries are hares")
	var side: Array = s.filter(func(e): return e.lane == "north")
	assert_eq(side.size(), 3, "2 side entries and 1 brute")
	assert_eq(side.map(func(e): return e.kind), [&"boar", &"boar", &"brute"])
	assert_false(side[0].has("extra"), "the marker is only on extra entries")

## Ties at one time: main, then side, then extra, whatever the sort's stability (a total order).
func test_ties_break_main_then_side_then_extra() -> void:
	var s := WaveSchedule.build(_extra_wave(), wb)
	for i in range(1, s.size()):
		assert_true(float(s[i - 1].t) <= float(s[i].t) + 1e-6, "sorted")
	var at_delay: Array = s.filter(func(e): return is_equal_approx(float(e.t), wb.side_group_delay))
	assert_eq(at_delay.map(func(e): return e.lane), ["north", "sw"], "side before extra at the same time")
	var at_brute: Array = s.filter(func(e): return is_equal_approx(float(e.t), wb.side_group_delay + 2 * wb.spawn_interval))
	assert_eq(at_brute.map(func(e): return e.kind), [&"brute", &"hare"], "the side brute before the extra hare")
	assert_eq(WaveSchedule.build(_extra_wave(), wb), s, "the same wave builds the same schedule")

## Two extra groups keep their order in wave.extra on ties.
func test_two_extra_groups_tie_in_plan_order() -> void:
	var w := _extra_wave()
	w.extra = [{"lane": "east", "count": 2, "fast": 1}, {"lane": "sw", "count": 2, "fast": 1}]
	var s := WaveSchedule.build(w, wb)
	var at_delay: Array = s.filter(func(e): return is_equal_approx(float(e.t), wb.side_group_delay))
	assert_eq(at_delay.map(func(e): return e.lane), ["north", "east", "sw"])

## A side group with count 0 that carries only brutes schedules only the brutes (apply can produce it).
func test_side_group_of_brutes_only_and_an_extra_group() -> void:
	var w := {"main": "west", "side": "sw", "main_count": 3, "side_count": 0, "hp_mult": 1.0, "fast_main": 0, "fast_side": 0,
		"brute_main": 0, "brute_side": 2, "boss": false, "extra": [{"lane": "east", "count": 2, "fast": 2}]}
	var s := WaveSchedule.build(w, wb)
	assert_eq(s.size(), 3 + 2 + 2)
	var sw: Array = s.filter(func(e): return e.lane == "sw")
	assert_eq(sw.map(func(e): return e.kind), [&"brute", &"brute"])
	assert_almost_eq(float(sw[0].t), wb.side_group_delay, 0.0001)
	assert_almost_eq(float(sw[1].t), wb.side_group_delay + wb.spawn_interval, 0.0001)
	var east: Array = s.filter(func(e): return e.lane == "east")
	assert_eq(east.map(func(e): return e.kind), [&"hare", &"hare"])

## Same with no extra group at all.
func test_side_group_of_brutes_only() -> void:
	var w := {"main": "west", "side": "sw", "main_count": 2, "side_count": 0, "hp_mult": 1.0, "fast_main": 0, "fast_side": 0,
		"brute_main": 0, "brute_side": 2, "boss": false}
	var s := WaveSchedule.build(w, wb)
	assert_eq(s.size(), 4)
	assert_eq(s.filter(func(e): return e.lane == "sw").size(), 2)

## The no-extra output, entry for entry, captured from the code BEFORE this task (wave 5/4 boars+hares, 1+2 brutes). A wave
## with an empty or absent extra list is that exact schedule. Mutation: any change to a wave without extra groups.
const CAPTURED_NO_EXTRA := '[{ "t": 0.0, "lane": "west", "side": false, "kind": &"boar" }, { "t": 0.8, "lane": "west", "side": false, "kind": &"boar" }, { "t": 1.6, "lane": "west", "side": false, "kind": &"boar" }, { "t": 2.4, "lane": "west", "side": false, "kind": &"hare" }, { "t": 3.2, "lane": "west", "side": false, "kind": &"hare" }, { "t": 4.0, "lane": "west", "side": false, "kind": &"brute" }, { "t": 4.0, "lane": "east", "side": true, "kind": &"boar" }, { "t": 4.8, "lane": "east", "side": true, "kind": &"boar" }, { "t": 5.6, "lane": "east", "side": true, "kind": &"boar" }, { "t": 6.4, "lane": "east", "side": true, "kind": &"hare" }, { "t": 7.2, "lane": "east", "side": true, "kind": &"brute" }, { "t": 8.0, "lane": "east", "side": true, "kind": &"brute" }]'

func test_a_wave_without_extra_is_unchanged() -> void:
	var w := {"main": "west", "side": "east", "main_count": 5, "side_count": 4, "hp_mult": 1.0, "fast_main": 2, "fast_side": 1,
		"brute_main": 1, "brute_side": 2, "boss": false}
	assert_eq(str(WaveSchedule.build(w, wb, Balance.data.tiers, 3)), CAPTURED_NO_EXTRA)
	w["extra"] = []
	assert_eq(str(WaveSchedule.build(w, wb, Balance.data.tiers, 3)), CAPTURED_NO_EXTRA, "an empty extra list changes nothing")
