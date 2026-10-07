extends SceneTree
## Writes tests/fixtures/plans_tier12.json (E5 tier-3 Task 6): the lane plans of tiers 1 and 2 and two wave schedules,
## captured BEFORE the planner learned its fourth lane and the brutes. The identity test compares today's code with it.
## Seeds 20260930, 11, 777; tier 1 (tier_day 1) days 1 to 14; tier 2 (tier_day 8) days 8 to 21.
## Do NOT regenerate after Task 6: the file is the oracle. Run (headless, deterministic):
##   "$GODOT" --headless --path . -s res://tools/make_plans_fixture.gd
## Editor/test only (tools/ is excluded from every web export).
const SEEDS := [20260930, 11, 777]

func _initialize() -> void:
	var bd = load("res://balance/balance.tres")
	var wb: WaveBalance = bd.wave
	var tb: TierBalance = bd.tiers
	var plans := {}
	for s in SEEDS:
		for tier in [1, 2]:
			var tier_day := 1 if tier == 1 else 8
			for day in range(tier_day, tier_day + 14):
				plans["%d:%d:%d" % [s, tier, day]] = load("res://core/lane_planner.gd").plan(s, day, wb, tier, tier_day, tb)
	var sched := {}
	var cases := {"t1": [20260930, 7, 1, 1], "t2": [11, 12, 2, 8]}
	for k in cases:
		var c: Array = cases[k]
		var p: Array = load("res://core/lane_planner.gd").plan(c[0], c[1], wb, c[2], c[3], tb)
		var rows := []
		for wave in p:
			var entries := []
			for e in load("res://core/wave_schedule.gd").build(wave, wb, tb):
				entries.append({"t": e.t, "lane": e.lane, "side": e.side, "kind": String(e.kind)})
			rows.append(entries)
		sched[k] = {"seed": c[0], "day": c[1], "tier": c[2], "tier_day": c[3], "waves": rows}
	var f := FileAccess.open("res://tests/fixtures/plans_tier12.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"plans": plans, "schedules": sched}, "\t", true))
	f.close()
	print("wrote ", plans.size(), " plans")
	quit()
