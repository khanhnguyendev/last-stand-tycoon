extends GutTest
## E8 phase 2 Task 4 (spec 4.4, B8): tier-4 waves reach the director, the schedule, the telegraph and the arrows.
## Every expected number is written out by hand from the literal plans below.

var main: Main
var _log: Array = []
var _wd: WaveDirector

func before_each() -> void:
	Balance.reset()
	Tier4Support.open_tier4()
	_log = []

func after_each() -> void:
	for pair in [[EventBus.wave_spawned_out, _on_spawned_out]]:
		if pair[0].is_connected(pair[1]):
			pair[0].disconnect(pair[1])
	Balance.reset()
	GameState.new_game(1)

## Wave 0: west main 5 (2 hares) + 1 brute; north side 3 (1 hare) + 1 brute; east side2 4 (2 hares) + 2 brutes.
## Wave 1: sw main 2; north side 1; east side2 0 (an emptied third group).
func _plan_t4() -> Array:
	return [
		{"main": "west", "side": "north", "side2": "east", "main_count": 5, "side_count": 3, "side2_count": 4, "hp_mult": 1.0,
			"fast_main": 2, "fast_side": 1, "fast_side2": 2, "boss": false, "brute_main": 1, "brute_side": 1, "brute_side2": 2},
		{"main": "sw", "side": "north", "side2": "east", "main_count": 2, "side_count": 1, "side2_count": 0, "hp_mult": 1.0,
			"fast_main": 0, "fast_side": 0, "fast_side2": 0, "boss": false, "brute_main": 0, "brute_side": 0, "brute_side2": 0},
	]

func _on_spawned_out(w: int) -> void:
	for b in _wd.alive_enemies():
		_log.append({"w": w, "lane": b.lane, "kind": b.kind, "spawn": b.spawn_index})
	_wd.debug_kill_all()

# --- the director ---------------------------------------------------------------------------------------------

func test_a_real_night_spawns_exactly_the_planned_counts_per_lane_brutes_and_hares_included() -> void:
	main = Main.create()
	add_child_autofree(main)
	await get_tree().physics_frame
	GameState.new_game(4242)
	GameState.debug_set_tier(4, 3)
	_wd = main.world.wave_director
	EventBus.wave_spawned_out.connect(_on_spawned_out)
	var cleared := [false]
	var on_clear := func(w: int): cleared[0] = w == 1
	EventBus.wave_cleared.connect(on_clear)
	_wd.start_night(_plan_t4())
	var guard := 0
	while not cleared[0] and guard < 4000:
		await get_tree().physics_frame
		guard += 1
	EventBus.wave_cleared.disconnect(on_clear)
	assert_true(cleared[0], "the night ran to the last wave's clear")
	var got := [{}, {}]
	for e in _log:
		var k := "%s/%s" % [e.lane, e.kind]
		got[e.w][k] = int(got[e.w].get(k, 0)) + 1
	assert_eq(got[0], {"west/boar": 3, "west/hare": 2, "west/brute": 1, "north/boar": 2, "north/hare": 1, "north/brute": 1,
		"east/boar": 2, "east/hare": 2, "east/brute": 2})
	assert_eq(got[1], {"sw/boar": 2, "north/boar": 1})

func test_the_third_group_starts_with_the_side_delay() -> void:
	var s := WaveSchedule.build(_plan_t4()[0], Balance.data.wave)
	var wb := Balance.data.wave
	var east: Array = s.filter(func(e): return e.lane == "east")
	assert_eq(east.size(), 6, "4 boars and hares + 2 brutes")
	assert_almost_eq(float(east[0].t), wb.side_group_delay, 0.0001)
	assert_almost_eq(float(east[5].t), wb.side_group_delay + 5.0 * wb.spawn_interval, 0.0001)

# --- the schedule ---------------------------------------------------------------------------------------------

func test_schedule_side2_entries_follow_side_by_build_order_and_carry_side_true() -> void:
	var s := WaveSchedule.build(_plan_t4()[0], Balance.data.wave)
	assert_eq(s.size(), 5 + 1 + 3 + 1 + 4 + 2)
	for i in range(1, s.size()):
		assert_true(float(s[i - 1].t) <= float(s[i].t) + 1e-6, "sorted by time")
	var tie_checked := 0
	for i in range(1, s.size()):
		if is_equal_approx(float(s[i - 1].t), float(s[i].t)) and s[i].lane == "east" and s[i - 1].lane == "north":
			tie_checked += 1
		assert_false(is_equal_approx(float(s[i - 1].t), float(s[i].t)) and s[i - 1].lane == "east" and s[i].lane == "north",
			"on a tie the side entry comes before the side2 entry")
	assert_gt(tie_checked, 0, "the two groups do tie at the same times")
	for e in s.filter(func(e): return e.lane == "east"):
		assert_true(e.side)
		assert_false(e.has("extra"))
	var east_kinds: Array = s.filter(func(e): return e.lane == "east").map(func(e): return e.kind)
	assert_eq(east_kinds, [&"boar", &"boar", &"hare", &"hare", &"brute", &"brute"])

func test_a_wave_without_side2_schedules_entry_for_entry_as_before() -> void:
	var w := {"main": "west", "side": "east", "main_count": 2, "side_count": 2, "hp_mult": 1.0, "fast_main": 1, "fast_side": 0, "brute_main": 0, "brute_side": 1}
	var s := WaveSchedule.build(w, Balance.data.wave)
	var wb := Balance.data.wave
	var d := wb.side_group_delay
	var i := wb.spawn_interval
	# Merged by t; at a tie (t = d never ties with 0 and i here unless d == k*i) the main entry comes first.
	var want: Array = [
		{"t": 0.0, "lane": "west", "side": false, "kind": &"boar"},
		{"t": i, "lane": "west", "side": false, "kind": &"hare"},
		{"t": d, "lane": "east", "side": true, "kind": &"boar"},
		{"t": d + i, "lane": "east", "side": true, "kind": &"boar"},
		{"t": d + 2.0 * i, "lane": "east", "side": true, "kind": &"brute"},
	]
	assert_eq(s.size(), want.size())
	for k in want.size():
		assert_eq(String(s[k].lane), want[k].lane, "entry %d lane" % k)
		assert_eq(s[k].side, want[k].side, "entry %d side" % k)
		assert_eq(s[k].kind, want[k].kind, "entry %d kind" % k)
		assert_almost_eq(float(s[k].t), float(want[k].t), 0.0001, "entry %d t" % k)
		assert_eq(s[k].keys().size(), 4, "t, lane, side, kind only")

# --- the planner's readers, the telegraph ---------------------------------------------------------------------

func test_composition_and_threat_count_the_third_group() -> void:
	var comp := LanePlanner.composition_by_lane(_plan_t4(), 4)
	assert_eq(comp.west, {"boar": 3, "hare": 2, "brute": 1, "boss": 0})
	assert_eq(comp.north, {"boar": 2 + 1, "hare": 1, "brute": 1, "boss": 0}, "wave 0: 2 boars 1 hare 1 brute; wave 1: 1 boar")
	assert_eq(comp.east, {"boar": 2, "hare": 2, "brute": 2, "boss": 0})
	assert_eq(comp.sw, {"boar": 2, "hare": 0, "brute": 0, "boss": 0})
	var base := 10.0
	var bh: float = Balance.data.monsters.stats(&"brute").hp
	var th := LanePlanner.threat_by_lane(_plan_t4(), base, 4)
	assert_almost_eq(float(th.east), 4.0 * base + 2.0 * bh, 0.001)
	assert_almost_eq(float(th.north), 4.0 * base + 1.0 * bh, 0.001)
	var scaled := _plan_t4()
	scaled[0].hp_mult = 1.5
	var ths := LanePlanner.threat_by_lane(scaled, base, 4)
	assert_almost_eq(float(ths.east), 1.5 * (4.0 * base + 2.0 * bh), 0.001, "wave 0's side2 threat scales by its hp_mult")
	assert_almost_eq(float(ths.north), 1.5 * (3.0 * base + 1.0 * bh) + base, 0.001, "wave 1's north boar keeps hp_mult 1")

func test_the_telegraph_shows_three_lanes_counts() -> void:
	main = Main.create()
	add_child_autofree(main)
	main.hero.input.player_control = false
	main.phase_controller.start_new_game(41)
	main.phase_controller.debug_skip_to_day()
	GameState.debug_set_tier(4, 3)
	GameState.lane_plan = _plan_t4()
	for m in main.world.telegraph_markers.values():
		m.refresh()
	var mk := main.world.telegraph_markers
	assert_eq(mk["west"].shown(), {&"boar": 3, &"hare": 2, &"brute": 1})
	assert_eq(mk["north"].shown(), {&"boar": 3, &"hare": 1, &"brute": 1})
	assert_eq(mk["east"].shown(), {&"boar": 2, &"hare": 2, &"brute": 2})
	assert_eq(mk["sw"].shown(), {&"boar": 2})
	assert_gt(mk["east"].target_scale, 0.0, "the side2-only lane's marker is sized")

# --- the arrows -----------------------------------------------------------------------------------------------

func test_three_edge_arrows_for_a_three_group_wave() -> void:
	main = Main.create()
	add_child_autofree(main)
	main.hero.input.player_control = false
	main.phase_controller.start_new_game(81)
	var hud: Hud = main.hud
	GameState.debug_set_tier(4, 3)
	GameState.lane_plan = _plan_t4()
	EventBus.wave_incoming.emit(0, &"west", &"north")
	await get_tree().process_frame
	assert_true(hud.arrows.main.visible)
	assert_true(hud.arrows.side.visible)
	assert_true(hud.arrows.extra.visible, "the third arrow is the side2 lane")
	assert_eq(hud._arrow_lane.extra, "east")
	assert_true(hud.arrows.extra.heavy, "wave 0's side2 group has brutes")
	EventBus.wave_incoming.emit(1, &"sw", &"north")
	await get_tree().process_frame
	assert_true(hud.arrows.side.visible)
	assert_false(hud.arrows.extra.visible, "wave 1's side2 group is empty: no arrow")

# --- hares and saves ------------------------------------------------------------------------------------------

func test_hare_share_counts_fast_side2() -> void:
	# hares: wave 0 west 2, north 1, east 2 (5 in all). The hare lane east holds 2 of 5.
	assert_almost_eq(LaneCharacter.hare_share(_plan_t4(), {"hare": "east"}), 2.0 / 5.0, 0.0001)
	assert_almost_eq(LaneCharacter.hare_share(_plan_t4(), {"hare": "north"}), 1.0 / 5.0, 0.0001)

func test_a_tier4_save_rebuilds_its_plan_with_side2() -> void:
	GameState.new_game(20260930)
	GameState.debug_set_tier(4, 3)
	GameState.day = 6
	GameState.advance_day()
	var want: Array = GameState.lane_plan.duplicate(true)
	assert_true(want[0].has("side2"))
	var d := GameState.to_dict()
	d.lane_plan[0].side2_count += 1  # a tampered save: from_dict rebuilds the plan at tier >= 3, so this is overwritten
	GameState.new_game(5)
	GameState.from_dict(d)
	assert_eq(GameState.lane_plan, want)
