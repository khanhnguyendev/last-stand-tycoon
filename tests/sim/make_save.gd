extends SceneTree
## Writes export/fixtures/night3_start.save.json (resume_phase NIGHT: resume_from enters night 3 at once) and
## night3_closeup.save.json (resume_phase DAY, day-peak reading) from a PlannerBot run (seed 20260930), using the
## close-up snapshot that precedes night 3. Run: "$GODOT" --headless --path . --fixed-fps 60 -s res://tests/sim/make_save.gd -- --fixture=day3_counter5|night3|tier
## `tier` (E5 spec 8.1) runs a TierBot from seed 20260930 to the first boss-night close-up and writes boss_night_tier1,
## boss_only, tier2_night1, tier2_full and tier2_night. `day3_counter5` writes only that fixture. `night3` rewrites the two night3 fixtures at the current schema and must
## not be used while they serve as schema-3 migration tests. No argument (or an unknown one) is a usage error.

var _done := false
var _fixture := ""

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--fixture="):
			_fixture = a.trim_prefix("--fixture=")
	if _fixture != "day3_counter5" and _fixture != "night3" and _fixture != "tier":
		push_error("usage: -- --fixture=day3_counter5|night3|tier")
		quit(2)
		return
	if _fixture == "tier":
		await _run_tier()
		return
	root.get_node("Balance").reset()
	var main = load("res://world/main.gd").create()
	root.add_child(main)
	var bot = load("res://actors/bots/planner_bot.gd").new()
	main.add_child(bot)
	bot.setup(main)
	root.get_node("EventBus").snapshot_taken.connect(_on_snapshot)
	main.phase_controller.start_new_game(20260930)
	for i in 60 * 60 * 30:
		if _done:
			return
		await physics_frame
	push_error("no night-3 close-up within 30 min of game time")
	quit(1)

func _on_snapshot(state: Dictionary) -> void:
	# Night N runs with GameState.day == N (new_game sets 1; advance_day at dawn), so the close-up before
	# night 3 carries day == 3.
	if _done or String(state.resume_phase) != "DAY" or int(state.day) != 3:
		return
	_done = true
	if _fixture == "day3_counter5":
		# E1 perf: day 3 with a level 5 counter (queue_max 9; stocked, so the queue fills once the 42 steaks are sold). The night3_* fixtures stay at schema 3.
		var s5: Dictionary = state.duplicate(true)
		s5.resume_phase = "DAY"
		var sb5 = root.get_node("Balance").data.stations
		s5.stations["counter"] = {"level": sb5.max_level, "paid": 0}
		s5.counter_steaks = sb5.counter_capacity[sb5.max_level]  # stocked: travelers are served, not only queued
		_write("day3_counter5", s5)
		quit(0)
		return
	for pair in [["night3_start", "NIGHT"], ["night3_closeup", "DAY"]]:
		var s: Dictionary = state.duplicate(true)
		s.resume_phase = pair[1]
		_write(pair[0], s)
	quit(0)

func _write(fixture: String, s: Dictionary) -> void:
	var codec = load("res://core/save_codec.gd")
	var path := ProjectSettings.globalize_path("res://export/fixtures/%s.save.json" % fixture)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(codec.encode(s, "fixture", 0))
	f.close()
	print("wrote ", path)

# --- E5 tier fixtures (spec 8.1) -----------------------------------------------------------------------------------

var _base: Dictionary = {}

func _on_tier_snapshot(state: Dictionary) -> void:
	if _base.is_empty() and String(state.resume_phase) == "DAY" and bool(state.boss_pending):
		_base = state.duplicate(true)

func _levels(ids: Array) -> String:
	var gs = root.get_node("GameState")
	var parts: Array = []
	for id in ids:
		if gs.buildings.has(id):
			parts.append("%s:%d" % [id, int(gs.buildings[id].level)])
	return "|".join(parts)

func _run_tier() -> void:
	var gs = root.get_node("GameState")
	root.get_node("Balance").reset()
	var main = load("res://world/main.gd").create()
	root.add_child(main)
	var bot = load("res://actors/bots/tier_bot.gd").new()
	main.add_child(bot)
	bot.setup(main)
	root.get_node("EventBus").snapshot_taken.connect(_on_tier_snapshot)
	main.phase_controller.start_new_game(20260930)
	var last_day := -1
	for i in 60 * 3600 * 4:  # 4 hours of game time
		if not _base.is_empty():
			break
		await physics_frame
		if int(gs.day) != last_day:
			last_day = int(gs.day)
			var sts := []
			for sid in gs.stations:
				sts.append("%s:%d" % [sid, int(gs.stations[sid].level)])
			print("day=%d tier=%d gold=%d tier_paid=%d defense=%s stations=%s fails=%d" % [gs.day, gs.tier, gs.gold,
				gs.tier_paid, _levels(load("res://core/map_layout.gd").ALL_SPOT_IDS), "|".join(sts), gs.night_fails])
	if _base.is_empty():
		push_error("the TierBot never paid the tier in 4 hours of game time: day=%d tier_paid=%d gold=%d stuck=%d tier_ups=%d" % [
			gs.day, gs.tier_paid, gs.gold, bot.stuck_count, bot.tier_ups])
		quit(1)
		return
	print("base: close-up of day %d, tier_ups=%d, boss_nights_won=%d" % [int(_base.day), bot.tier_ups, bot.boss_nights_won])
	# stop the live game so the derivation below can use GameState without side effects
	main.get_parent().remove_child(main)
	main.free()
	root.get_node("EventBus").snapshot_taken.disconnect(_on_tier_snapshot)
	quit(0 if _write_tier_fixtures(_base) else 1)

func _plan(s: Dictionary) -> Array:
	var bd = root.get_node("Balance").data
	return load("res://core/lane_planner.gd").plan(int(s.run_seed), int(s.day), bd.wave, int(s.tier), int(s.tier_day), bd.tiers)

func _common(s: Dictionary) -> void:
	s.gold_pile = 0
	s.carried_steaks = 0
	s.card_offer = []

## Builds all five states, validates every one, and only then writes. False (nothing written) on any failure.
func _write_tier_fixtures(base: Dictionary) -> bool:
	var bd = root.get_node("Balance").data
	var gs = root.get_node("GameState")
	var tb = bd.tiers
	var boss := base.duplicate(true)
	boss.resume_phase = "NIGHT"
	boss.night_fails = 0
	_common(boss)
	var out: Array = [["boss_night_tier1", boss]]

	var only := boss.duplicate(true)
	for id in only.buildings:
		only.buildings[id] = {"level": 0, "paid": 0, "hp": 0.0}
	only.cards = {}
	only.guards = {}
	only.card_offer = []
	for w in only.lane_plan:
		w.main_count = 0
		w.side_count = 0
		w.fast_main = 0
		w.fast_side = 0
		w.side = ""
	only.lane_plan[only.lane_plan.size() - 1].boss = true
	only.boss_pending = true
	out.append(["boss_only", only])

	# tier 2 as the dawn after a won boss night leaves it. Done through a real GameState round trip:
	# from_dict, heal_for_dawn (diner, fences and guards to full HP), to_dict.
	var t2 := base.duplicate(true)
	t2.tier = 2
	t2.boss_pending = false
	t2.tier_paid = 0
	t2.day = int(base.day) + 1
	t2.tier_day = t2.day
	t2.night_fails = 0
	t2.resume_phase = "NIGHT"
	for id in load("res://core/map_layout.gd").TIER_SPOTS[2]:
		t2.buildings[id] = {"level": 0, "paid": 0, "hp": 0.0}
	t2.lane_plan = _plan(t2)
	gs.from_dict(t2)
	gs.heal_for_dawn()
	t2 = gs.to_dict()
	t2.resume_phase = "NIGHT"
	_common(t2)
	out.append(["tier2_night1", t2])

	var full := t2.duplicate(true)
	full.day = int(t2.tier_day) + int(tb.fast_ramp_days[2])
	if load("res://core/wave_math.gd").pressure(int(full.day), 2, int(full.tier_day), tb) != int(tb.tier_cap[2]):
		push_error("tier2_full is not at the pressure cap")
		return false
	var ml: int = bd.build.max_level
	for id in full.buildings:
		full.buildings[id] = {"level": ml, "paid": 0, "hp": gs.fence_max_hp(ml) if load("res://core/map_layout.gd").spot_kind(id) == "fence" else 0.0}
	full.lane_plan = _plan(full)
	out.append(["tier2_full", full])
	out.append(["tier2_night", full])
	var codec = load("res://core/save_codec.gd")
	for pair in out:
		var why: String = codec.validate(pair[1], bd)
		if why != "":
			push_error("fixture %s invalid: %s" % [pair[0], why])
			return false
	for pair in out:
		_write(pair[0], pair[1])
	return true
