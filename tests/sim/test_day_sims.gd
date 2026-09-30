extends GutTest
## Spec 13.4 night-2 rows + day loop (D-058, D-103, D-105).

const SEED := 20260930
var h: SimHarness

func before_each() -> void:
	Balance.reset()
	h = SimHarness.new(self)

func after_each() -> void:
	h.finish()

func _night2(bot: GDScript, harness: SimHarness) -> Dictionary:
	harness.start(SEED, bot)
	var n1 := await harness.run_night()
	assert_true(n1.cleared, "night 1 must clear: %s" % n1)
	var d1 := await harness.run_day()
	assert_true(d1.closed, "day 1 must close up")
	var closeup: Dictionary = harness.main.phase_controller.snapshot.duplicate(true)  # taken at close-up
	var plan2: Array = GameState.lane_plan.duplicate(true)  # night 2's plan (dawn replaces it)
	var n2 := await harness.run_night()
	n2["steaks"] = GameState.freezer_steaks + GameState.carried_steaks
	n2["day1_seconds"] = d1.seconds
	n2["closeup"] = closeup
	n2["lane_plan"] = plan2
	return n2

func _side_lane(plan: Array) -> String:
	var side := {"west": 0.0, "north": 0.0, "east": 0.0}
	for w in plan:
		if String(w.side) != "":
			side[w.side] += int(w.side_count) * float(w.hp_mult)
	var best := ""
	for l in LanePlanner.LANES:
		if side[l] > 0.0 and (best == "" or side[l] > side[best]):
			best = l
	return best

func _levels(builds: Dictionary) -> int:
	var total := 0
	for id in builds:
		total += int(builds[id].level)
	return total

func test_night2_naive_unaided_is_hard_and_deterministic() -> void:
	var r1 := await _night2(NaiveBot, h)
	gut.p("night2 naive: %s" % r1)
	assert_true(r1.failed or r1.diner_frac <= Balance.data.sim.night2_unaided_max, "diner %.2f" % r1.diner_frac)
	h.finish()
	await get_tree().process_frame
	Balance.reset()
	var h2 := SimHarness.new(self)
	var r2 := await _night2(NaiveBot, h2)
	h2.finish()
	assert_eq(_levels(r1.closeup.buildings), 0, "the naive bot never builds")
	assert_eq([r1.failed, r1.diner_frac, r1.kills, r1.steaks, r1.lane_plan],
		[r2.failed, r2.diner_frac, r2.kills, r2.steaks, r2.lane_plan],
		"same seed, same outcome")

func test_night2_planner_is_comfortable() -> void:
	var r := await _night2(PlannerBot, h)
	gut.p("night2 planner: %s" % r)
	var b: Dictionary = r.closeup.buildings
	var side_lane := _side_lane(r.lane_plan)
	assert_ne(side_lane, "", "night 2 has a side group")
	var fence: String = MapLayout.LANE_FENCE[side_lane]
	assert_gte(int(b[fence].level), 1, "side-lane fence built at close-up")
	var tower_ok := false
	for t in MapLayout.TOWER_LANES:
		if side_lane in MapLayout.TOWER_LANES[t] and int(b[t].level) >= 1:
			tower_ok = true
	assert_true(tower_ok, "a tower next to the side lane built at close-up")
	assert_lt(int(r.closeup.gold), Balance.data.build.fence_cost, "gold spent down at close-up")
	assert_true(r.cleared, "night 2 must clear")
	assert_true(r.diner_frac >= Balance.data.sim.night2_comfort_min, "diner %.2f" % r.diner_frac)
